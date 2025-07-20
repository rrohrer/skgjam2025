const std = @import("std");

const Entity = @import("entity.zig").Entity;

pub const Core = struct {
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
