const rl = @import("raylib");
const std = @import("std");
const builtin = @import("builtin");

const Entity = struct {
    const Self = @This();

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

    const PlayerData = struct {
        health: i32,
        move_speed: f32,
    };

    pub const Data = union(Type) {
        Barrel: void,
        Floor: void,
        Wall: void,
        Player: PlayerData,
        Reaper: void,
        Bullet: void,
    };

    pub fn init(data: Data, position: rl.Vector2) Self {
        return Entity{ .data = data, .position = position, .scale = rl.Vector2.one() };
    }
};

const Core = struct {
    const Self = @This();

    world: std.ArrayList(Entity),

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .world = std.ArrayList(Entity).init(allocator) };
    }

    pub fn deinit(self: *Self) void {
        self.world.deinit();
    }
};

pub fn main() anyerror!void {
    // Initialization
    //--------------------------------------------------------------------------------------
    // Start by setting up an allocator for general use.
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

    var core = Core.init(allocator);
    defer core.deinit();

    const player = Entity.init(Entity.Data{ .Player = .{
        .health = 100,
        .move_speed = 200,
    } }, rl.Vector2.init(50, 50));
    try core.world.append(player);
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

    for (core.world.items) |*entity| {
        updateEntity(dt, entity);
    }

    // Draw
    //----------------------------------------------------------------------------------
    rl.beginDrawing();
    defer rl.endDrawing();

    const bg_color = rl.Color.init(129, 99, 100, 255);
    rl.clearBackground(bg_color);

    rl.drawText("Congrats! You created your first window!", 190, 200, 20, .light_gray);

    for (core.world.items) |*entity| {
        drawEntity(entity);
    }
}

fn drawEntity(entity: *Entity) void {
    switch (entity.data) {
        .Player => rl.drawRectangle(@intFromFloat(entity.position.x), @intFromFloat(entity.position.y), 20, 20, rl.Color.black),
        else => {},
    }
}

fn updateEntity(dt: f32, entity: *Entity) void {
    switch (entity.data) {
        .Player => |*player_data| updatePlayer(dt, entity, player_data),
        else => {},
    }
}

fn updatePlayer(dt: f32, entity: *Entity, player_data: *Entity.PlayerData) void {
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
}
