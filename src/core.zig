const std = @import("std");

const Entity = @import("entity.zig").Entity;

pub const Core = struct {
    const Self = @This();

    allocator: std.mem.Allocator,
    world: std.ArrayList(Entity),
    additions: std.ArrayList(Entity),
    removals: std.ArrayList(usize),
    random: std.Random,
    score: i32,

    pub fn init(allocator: std.mem.Allocator, random: std.Random) Self {
        return Self{
            .allocator = allocator,
            .world = std.ArrayList(Entity).init(allocator),
            .additions = std.ArrayList(Entity).init(allocator),
            .removals = std.ArrayList(usize).init(allocator),
            .random = random,
            .score = 0,
        };
    }

    pub fn deinit(self: *Self) void {
        for (self.world.items) |*e| {
            e.deinit();
        }
        for (self.additions.items) |*e| {
            e.deinit();
        }
        self.world.deinit();
        self.removals.deinit();
        self.additions.deinit();
    }

    pub fn addEntity(self: *Self, entity: Entity) void {
        self.additions.append(entity) catch @panic("Ran out of memory trying to add an entity");
    }

    pub fn removeEntity(self: *Self, entity: *Entity) void {
        self.removals.append(entity.id) catch @panic("Ran out of memory trying to remove and entity");
    }

    pub fn update(self: *Self) void {
        for (self.removals.items) |id| {
            const e = self.getEntity(id) orelse continue;
            const index = self.getEntityIndex(e);
            var entity = self.world.swapRemove(index);
            entity.deinit();
        }

        self.world.appendSlice(self.additions.items) catch @panic("Ran out of memory moving entity to world.");

        self.removals.clearRetainingCapacity();
        self.additions.clearRetainingCapacity();
    }

    fn getEntityIndex(self: *const Core, entity: *const Entity) usize {
        return entity - &self.world.items[0];
    }

    pub fn getEntity(self: *Self, id: Entity.Id) ?*Entity {
        for (self.world.items) |*entity| {
            if (entity.id == id) return entity;
        }
        return null;
    }
};
