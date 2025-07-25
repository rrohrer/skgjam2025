const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");

// I think normally you wouldn't do this, im aliasing them because this was all originally
// in one file and I don't want to have them by namespaces anymore
const en = @import("entity.zig");
const Entity = en.Entity;
const Core = @import("core.zig").Core;

const al = @import("actionlist.zig");

fn titleScreen(core: *Core) void {
    for (core.world.items) |*e| {
        core.removeEntity(e);
    }

    const welcome = Entity.initText(
        core.allocator,
        "Welcome... your time is limited...",
        rl.Vector2.init(100, 50),
        40,
        .white,
    );

    const wasd = Entity.initText(
        core.allocator,
        "W A S D to move    Arrows to shoot",
        rl.Vector2.init(150, 100),
        30,
        .white,
    );
    const space = Entity.initText(
        core.allocator,
        "Press [space] to start...",
        rl.Vector2.init(200, 150),
        30,
        .white,
    );

    const actions = [_]al.Action{
        al.WaitAction.init(core.allocator, 1),
        al.WaitOnKeypressAction.init(core.allocator, .space),
        en.RemoveEntitiesAction.init(core, &.{
            welcome.id,
            wasd.id,
            space.id,
        }),
        al.FunctionCallAction.init(core, setupGame),
    };
    var list = al.ActionList.init(core.allocator);
    list.appendSlice(&actions);

    core.addEntity(welcome);
    core.addEntity(wasd);
    core.addEntity(space);
    core.addEntity(Entity.initActionList(list));
}

pub fn main() anyerror!void {
    // set up the allocator that is used. There is a bug in zig's wasm and gpa allocator
    // where they crash in emscripten. For now you have to use the C allocator.
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = if (builtin.os.tag == .emscripten) std.heap.c_allocator else gpa.allocator();
    defer {
        if (builtin.os.tag != .emscripten) {
            const deinit_status = gpa.deinit();
            if (deinit_status == .leak) std.testing.expect(false) catch @panic("There were leaks in the program.");
        }
    }

    // window details
    const screenWidth = 800;
    const screenHeight = 450;
    rl.setConfigFlags(.{ .window_highdpi = true, .vsync_hint = true });

    rl.initWindow(screenWidth, screenHeight, "SKG Jam 2025");

    // setup the central parts of the game
    const seed = rl.getTime();
    var prng = std.Random.DefaultPrng.init(@intFromFloat(seed));
    const random = prng.random();
    var core = Core.init(allocator, random);
    defer core.deinit();

    titleScreen(&core);

    // run the game loop, note this is different for wasm or desktop
    switch (builtin.os.tag) {
        .emscripten => std.os.emscripten.emscripten_set_main_loop_arg(mainGameLoop, &core, 60, 1),
        else => {
            defer rl.closeWindow(); // Close window and OpenGL context
            rl.setTargetFPS(60); // Set our game to run at 60 frames-per-second

            while (!rl.windowShouldClose()) { // Detect window close button or ESC key
                mainGameLoop(&core);
            }
        },
    }
}

fn mainGameLoop(input: ?*anyopaque) callconv(.c) void {
    const core: *Core = @ptrCast(@alignCast(input));
    const dt = rl.getFrameTime();
    core.update();

    for (core.world.items) |*entity| {
        updateEntity(dt, core, entity);
    }

    rl.beginDrawing();
    defer rl.endDrawing();

    const bg_color = rl.Color.init(129, 99, 100, 255);
    rl.clearBackground(bg_color);

    for (core.world.items) |*entity| {
        drawEntity(entity);
    }
}

fn setupGame(core: *Core, _: f32) al.Action.Status {
    const player = Entity.init(
        Entity.Data.initPlayer(),
        rl.Vector2.init(200, 200),
        rl.Vector2.init(20, 20),
    );
    core.addEntity(player);

    spawnBarrel(core);

    return .Done;
}

fn drawEntity(entity: *Entity) void {
    switch (entity.data) {
        .Player => |*player_data| rl.drawRectangle(
            @intFromFloat(entity.position.x),
            @intFromFloat(entity.position.y),
            @intFromFloat(entity.scale.x),
            @intFromFloat(entity.scale.y),
            player_data.color,
        ),
        .Bullet => |*bullet_data| rl.drawRectangle(
            @intFromFloat(entity.position.x),
            @intFromFloat(entity.position.y),
            @intFromFloat(entity.scale.x),
            @intFromFloat(entity.scale.y),
            bullet_data.color,
        ),
        .Barrel => rl.drawRectangle(
            @intFromFloat(entity.position.x),
            @intFromFloat(entity.position.y),
            @intFromFloat(entity.scale.x),
            @intFromFloat(entity.scale.y),
            rl.Color.init(191, 133, 101, 255),
        ),
        .Text => |*text| rl.drawText(
            text.text,
            @intFromFloat(entity.position.x),
            @intFromFloat(entity.position.y),
            text.size,
            text.color,
        ),
        else => {},
    }
}

fn updateEntity(dt: f32, core: *Core, entity: *Entity) void {
    switch (entity.data) {
        .Player => |*player_data| updatePlayer(dt, core, entity, player_data),
        .Bullet => |*bullet_data| updateBullet(dt, core, entity, bullet_data),
        .ActionList => |*list| updateActionList(dt, core, entity, list),
        .Barrel => updateBarrel(dt, core, entity),
        else => {},
    }
}

fn updatePlayer(dt: f32, core: *Core, entity: *Entity, player_data: *Entity.PlayerData) void {
    var move_vec = rl.Vector2.zero();

    if (rl.isKeyDown(.a)) {
        move_vec.x -= 1;
    }
    if (rl.isKeyDown(.d)) {
        move_vec.x += 1;
    }
    if (rl.isKeyDown(.w)) {
        move_vec.y -= 1;
    }
    if (rl.isKeyDown(.s)) {
        move_vec.y += 1;
    }

    move_vec = move_vec.normalize();
    move_vec = move_vec.scale(player_data.move_speed * dt);
    entity.position = entity.position.add(move_vec);

    var shoot_vec = rl.Vector2.zero();

    if (rl.isKeyDown(.left)) {
        shoot_vec.x -= 1;
    }
    if (rl.isKeyDown(.right)) {
        shoot_vec.x += 1;
    }
    if (rl.isKeyDown(.up)) {
        shoot_vec.y -= 1;
    }
    if (rl.isKeyDown(.down)) {
        shoot_vec.y += 1;
    }

    player_data.dt_shoot += dt;

    if (shoot_vec.lengthSqr() > 0 and player_data.dt_shoot >= player_data.shoot_speed) {
        shoot_vec = shoot_vec.normalize();
        const b_scale = rl.Vector2.init(10, 10);
        const b_pos = entity.position.add(entity.scale.scale(0.5).subtract(b_scale.scale(0.5))).add(shoot_vec.scale(entity.scale.x * 0.7));
        const bullet = Entity.init(
            Entity.Data.initBullet(shoot_vec),
            b_pos,
            b_scale,
        );
        core.addEntity(bullet);
        player_data.dt_shoot = 0;
    }

    player_data.dt_life += dt;
    if (player_data.dt_life >= 1) {
        player_data.health -= 1;
        player_data.dt_life = 0;
    }

    if (core.score != player_data.last_score) {
        player_data.last_score = core.score;
        player_data.health += 1;
    }

    const health = std.fmt.allocPrintZ(core.allocator, "{d}", .{player_data.health}) catch @panic("Health error");
    defer core.allocator.free(health);
    rl.drawText(health, 20, 20, 30, .white);

    const score = std.fmt.allocPrintZ(core.allocator, "Score: {d}", .{core.score}) catch @panic("score error");
    defer core.allocator.free(score);
    rl.drawText(score, 20, 50, 30, .white);

    if (player_data.health <= 0) {
        titleScreen(core);
        core.score = 0;
    }
}

fn updateBullet(dt: f32, core: *Core, entity: *Entity, bullet_data: *Entity.BulletData) void {
    entity.position = entity.position.add(bullet_data.direction.scale(bullet_data.speed * dt));
    bullet_data.dt += dt;
    if (bullet_data.dt >= bullet_data.lifetime) {
        core.removeEntity(entity);
    }
}

fn updateActionList(dt: f32, core: *Core, entity: *Entity, list: *al.ActionList) void {
    list.update(dt);
    if (list.isComplete()) {
        core.removeEntity(entity);
    }
}

fn collide(a_pos: rl.Vector2, a_size: rl.Vector2, b_pos: rl.Vector2, b_size: rl.Vector2) bool {
    const ax_min = a_pos.x;
    const ax_max = a_pos.x + a_size.x;
    const ay_min = a_pos.y;
    const ay_max = a_pos.y + a_size.y;
    const bx_min = b_pos.x;
    const bx_max = b_pos.x + b_size.x;
    const by_min = b_pos.y;
    const by_max = b_pos.y + b_size.y;

    return ax_min < bx_max and ax_max > bx_min and ay_min < by_max and ay_max > by_min;
}

fn spawnBarrel(core: *Core) void {
    const x = core.random.intRangeAtMost(i32, 30, 770);
    const y = core.random.intRangeAtMost(i32, 30, 420);
    const barrel = Entity.init(
        .Barrel,
        rl.Vector2.init(@floatFromInt(x), @floatFromInt(y)),
        rl.Vector2.init(15, 25),
    );
    core.addEntity(barrel);
}

fn updateBarrel(_: f32, core: *Core, entity: *Entity) void {
    for (core.world.items) |*b_entity| {
        if (b_entity.data == .Bullet) {
            if (collide(entity.position, entity.scale, b_entity.position, b_entity.scale)) {
                core.removeEntity(entity);
                core.removeEntity(b_entity);
                spawnBarrel(core);
                core.score += 1;
                return;
            }
        }
    }
}
