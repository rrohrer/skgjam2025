const std = @import("std");
const rl = @import("raylib");
const Core = @import("core.zig").Core;

// Even an anti OO extremist like me can admit that sometimes I want a vtable.
pub const Action = struct {
    const Self = @This();

    userdata: *anyopaque,
    vtable: *const VTable,
    allocator: std.mem.Allocator,

    pub const Status = enum {
        Done,
        Running,
    };

    pub const VTable = struct {
        update: *const fn (userdata: *anyopaque, dt: f32) Status,
        deinit: *const fn (userdata: *anyopaque, allocator: std.mem.Allocator) void,
    };

    pub fn deinit(self: *Self) void {
        self.vtable.deinit(self.userdata, self.allocator);
    }

    pub fn update(self: *Self, dt: f32) Status {
        return self.vtable.update(self.userdata, dt);
    }
};

pub const ActionList = struct {
    const Self = @This();

    list: std.ArrayList(Action),
    current_action: usize,

    pub fn init(allocator: std.mem.Allocator) Self {
        return Self{ .list = std.ArrayList(Action).init(allocator), .current_action = 0 };
    }

    pub fn append(self: *Self, action: Action) void {
        self.list.append(action) catch @panic("ran out of memory appending to action list");
    }

    pub fn appendSlice(self: *Self, actions: []const Action) void {
        self.list.appendSlice(actions) catch @panic("Ran out of memory appending actions to list");
    }

    pub fn deinit(self: *Self) void {
        for (self.list.items) |*action| {
            action.deinit();
        }

        self.list.deinit();
    }

    pub fn update(self: *Self, dt: f32) void {
        if (self.current_action >= self.list.items.len) {
            return;
        }

        switch (self.list.items[self.current_action].update(dt)) {
            .Done => self.current_action += 1,
            .Running => {},
        }
    }

    pub fn isComplete(self: *Self) bool {
        return self.current_action >= self.list.items.len;
    }
};

pub const WaitAction = struct {
    dt: f32,
    wait_time: f32,

    fn update(userdata: *anyopaque, dt: f32) Action.Status {
        const self: *WaitAction = @ptrCast(@alignCast(userdata));
        self.dt += dt;

        return if (self.dt >= self.wait_time) .Done else .Running;
    }

    fn deinit(userdata: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *WaitAction = @ptrCast(@alignCast(userdata));
        allocator.destroy(self);
    }

    pub fn init(allocator: std.mem.Allocator, wait_time: f32) Action {
        const wait = allocator.create(WaitAction) catch @panic("Ran out of memory creating WaitAction");
        wait.* = .{ .dt = 0, .wait_time = wait_time };
        return Action{
            .userdata = wait,
            .allocator = allocator,
            .vtable = &.{
                .update = update,
                .deinit = deinit,
            },
        };
    }
};

pub const WaitOnKeypressAction = struct {
    key: rl.KeyboardKey,

    fn update(userdata: *anyopaque, _: f32) Action.Status {
        const self: *WaitOnKeypressAction = @ptrCast(@alignCast(userdata));
        return if (rl.isKeyDown(self.key)) .Done else .Running;
    }

    fn deinit(userdata: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *WaitOnKeypressAction = @ptrCast(@alignCast(userdata));
        allocator.destroy(self);
    }

    pub fn init(allocator: std.mem.Allocator, key: rl.KeyboardKey) Action {
        const wait = allocator.create(WaitOnKeypressAction) catch @panic("Ran out of memory initializing wait on keypress");
        wait.* = .{ .key = key };
        return Action{
            .userdata = wait,
            .allocator = allocator,
            .vtable = &.{ .update = update, .deinit = deinit },
        };
    }
};

pub const FunctionCallAction = struct {
    func: *const fn (core: *Core, dt: f32) Action.Status,
    core: *Core,

    fn update(userdata: *anyopaque, dt: f32) Action.Status {
        const self: *FunctionCallAction = @ptrCast(@alignCast(userdata));
        return self.func(self.core, dt);
    }

    fn deinit(userdata: *anyopaque, allocator: std.mem.Allocator) void {
        const self: *FunctionCallAction = @ptrCast(@alignCast(userdata));
        allocator.destroy(self);
    }

    pub fn init(core: *Core, func: *const fn (core: *Core, dt: f32) Action.Status) Action {
        const f = core.allocator.create(FunctionCallAction) catch @panic("Ran out of memory initializing func action");
        f.* = .{
            .func = func,
            .core = core,
        };
        return Action{
            .userdata = f,
            .allocator = core.allocator,
            .vtable = &.{
                .update = update,
                .deinit = deinit,
            },
        };
    }
};
