const rl = @import("raylib");
const std = @import("std");

const al = @import("actionlist.zig");
const ActionList = al.ActionList;
const Action = al.Action;

const Core = @import("core.zig").Core;

pub const Entity = struct {
    const Self = @This();
    pub const Id = usize;

    // gloabal counter of entities so that the are always unique.
    var current_id: Id = 0;

    id: Id,
    data: Data,
    position: rl.Vector2,
    scale: rl.Vector2,

    pub const Type = enum {
        Barrel,
        Text,
        ActionList,
        Player,
        Reaper,
        Bullet,
    };

    pub const TextData = struct {
        text: [:0]const u8,
        allocator: std.mem.Allocator,
        color: rl.Color,
        size: i32,

        pub fn deinit(self: *TextData) void {
            self.allocator.free(self.text);
        }
    };

    pub const BulletData = struct {
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

    pub const PlayerData = struct {
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
        Text: TextData,
        ActionList: ActionList,
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

    pub fn initActionList(list: ActionList) Self {
        return Self.init(Data{ .ActionList = list }, rl.Vector2.zero(), rl.Vector2.zero());
    }

    pub fn initText(
        allocator: std.mem.Allocator,
        text: [:0]const u8,
        position: rl.Vector2,
        size: i32,
        color: rl.Color,
    ) Self {
        const ctext = allocator.dupeZ(u8, text) catch @panic("Ran out of memory creating text");

        const text_data = TextData{
            .text = ctext,
            .allocator = allocator,
            .size = size,
            .color = color,
        };
        return Self.init(
            Data{ .Text = text_data },
            position,
            rl.Vector2.zero(),
        );
    }

    pub fn deinit(self: *Self) void {
        switch (self.data) {
            .Text => |*t| t.deinit(),
            .ActionList => |*a| a.deinit(),
            else => {},
        }
    }
};

pub const RemoveEntitiesAction = struct {
    list: std.ArrayList(Entity.Id),
    core: *Core,

    fn update(userdata: *anyopaque, _: f32) Action.Status {
        const self: *RemoveEntitiesAction = @ptrCast(@alignCast(userdata));

        for (self.list.items) |id| {
            const entity = self.core.getEntity(id) orelse continue;
            self.core.removeEntity(entity);
        }

        return .Done;
    }

    fn deinit(userdata: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *RemoveEntitiesAction = @ptrCast(@alignCast(userdata));
        self.list.deinit();
        allocator.destroy(self);
    }

    pub fn init(core: *Core, entities: []const Entity.Id) Action {
        const remove = core.allocator.create(RemoveEntitiesAction) catch @panic("Ran out of memory creating RemoveEntitiesAction");
        remove.* = .{ .list = std.ArrayList(Entity.Id).init(core.allocator), .core = core };
        remove.list.appendSlice(entities) catch @panic("Ran out of memory adding entities to list");
        return Action{
            .userdata = remove,
            .allocator = core.allocator,
            .vtable = &.{
                .update = update,
                .deinit = deinit,
            },
        };
    }
};
