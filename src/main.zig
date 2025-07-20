const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");

const Entity = struct {
    const Self = @This();
    const Id = usize;

    // gloabal counter of entities so that the are always unique.
    var current_id: Id = 0;

    id: Id,
    data: Data,
    position: rl.Vector2,
    scale: rl.Vector2,

    pub const Type = enum {
        Barrel,
        Floor,
        Wall,
        Player,
        Reaper,
        Bullet,
    };

    const BulletData = struct {
        damage: i32,
        direction: rl.Vector2,
        speed: f32,
        color: rl.Color,
        lifetime: f32,
        dt: f32,

        pub fn init(direction: rl.Vector2) BulletData {
            return BulletData{
                .damage = 10,
                .direction = direction,
                .speed = 400,
                .color = rl.Color.init(255, 72, 73, 255),
                .lifetime = 0.5,
                .dt = 0,
            };
        }
    };

    const PlayerData = struct {
        health: i32,
        move_speed: f32,
        dt_shoot: f32,
        shoot_speed: f32,
        color: rl.Color,

        pub fn init() PlayerData {
            const shoot_speed = 0.05;
            return PlayerData{
                .health = 100,
                .move_speed = 200,
                .dt_shoot = shoot_speed,
                .shoot_speed = shoot_speed,
                .color = rl.Color.init(72, 255, 185, 255),
            };
        }
    };

    pub const Data = union(Type) {
        Barrel: void,
        Floor: void,
        Wall: void,
        Player: PlayerData,
        Reaper: void,
        Bullet: BulletData,

        pub fn initPlayer() Data {
            return Data{ .Player = PlayerData.init() };
        }

        pub fn initBullet(direction: rl.Vector2) Data {
            return Data{ .Bullet = BulletData.init(direction) };
        }
    };

    pub fn init(data: Data, position: rl.Vector2, scale: rl.Vector2) Self {
        const id = current_id;
        current_id += 1;
        return Entity{ .data = data, .position = position, .scale = scale, .id = id };
    }
};

const Core = struct {
    const Self = @This();

    world: std.ArrayList(Entity),
    additions: std.ArrayList(Entity),
    removals: std.ArrayList(usize),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{
            .world = std.ArrayList(Entity).init(allocator),
            .additions = std.ArrayList(Entity).init(allocator),
            .removals = std.ArrayList(usize).init(allocator),
        };
    }

    pub fn deinit(self: *Self) void {
        self.world.deinit();
        self.removals.deinit();
        self.additions.deinit();
    }

    pub fn addEntity(self: *Self, entity: Entity) void {
        self.additions.append(entity) catch @panic("Ran out of memory trying to add an entity");
    }

    pub fn removeEntity(self: *Self, entity: *Entity) void {
        const index = self.getEntityIndex(entity);
        self.removals.append(index) catch @panic("Ran out of memory trying to remove and entity");
    }

    pub fn update(self: *Self) void {
        for (self.removals.items) |index| {
            _ = self.world.swapRemove(index);
        }

        self.world.appendSlice(self.additions.items) catch @panic("Ran out of memory moving entity to world.");

        self.removals.clearRetainingCapacity();
        self.additions.clearRetainingCapacity();
    }

    fn getEntityIndex(self: *const Core, entity: *const Entity) usize {
        return entity - &self.world.items[0];
    }
};

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
    var core = Core.init(allocator);
    defer core.deinit();

    const player = Entity.init(
        Entity.Data.initPlayer(),
        rl.Vector2.init(50, 50),
        rl.Vector2.init(20, 20),
    );
    core.addEntity(player);

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
        else => {},
    }
}

fn updateEntity(dt: f32, core: *Core, entity: *Entity) void {
    switch (entity.data) {
        .Player => |*player_data| updatePlayer(dt, core, entity, player_data),
        .Bullet => |*bullet_data| updateBullet(dt, core, entity, bullet_data),
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
}

fn updateBullet(dt: f32, core: *Core, entity: *Entity, bullet_data: *Entity.BulletData) void {
    entity.position = entity.position.add(bullet_data.direction.scale(bullet_data.speed * dt));
    bullet_data.dt += dt;
    if (bullet_data.dt >= bullet_data.lifetime) {
        core.removeEntity(entity);
    }
}
