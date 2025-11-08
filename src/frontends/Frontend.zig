const std = @import("std");
const State = @import("../State.zig");
const ConsoleFrontend = @import("ConsoleFrontend.zig");
const RaylibFrontend = @import("RaylibFrontend.zig");

pub const Frontend = union(enum) {
    console: ConsoleFrontend,
    raylib: RaylibFrontend,

    pub const Kind = @typeInfo(Frontend).@"union".tag_type.?;

    pub fn initFromArgs(allocator: std.mem.Allocator, opts: anytype) !Frontend {
        return switch (opts.frontend) {
            inline else => |tag| {
                const field_name = @tagName(tag);
                const FieldType = @FieldType(Frontend, field_name);
                const impl = try FieldType.init(allocator, opts);
                return @unionInit(Frontend, field_name, impl);
            },
        };
    }

    pub fn deinit(self: *Frontend) void {
        switch (self.*) {
            inline else => |*impl| {
                if (@hasDecl(@TypeOf(impl.*), "deinit")) {
                    impl.deinit();
                }
            },
        }
    }

    pub fn shouldStop(self: Frontend) bool {
        return switch (self) {
            inline else => |impl| return impl.shouldStop(),
        };
    }

    pub fn draw(self: *Frontend, should_draw: bool, display: [State.display_resolution]u8) !void {
        switch (self.*) {
            inline else => |*impl| try impl.draw(should_draw, display),
        }
    }

    pub fn playSound(self: *Frontend, sound_timer: u8) void {
        switch (self.*) {
            inline else => |*impl| {
                if (@hasDecl(@TypeOf(impl.*), "playSound")) {
                    impl.playSound(sound_timer);
                }
            },
        }
    }

    pub fn setKeys(self: *Frontend, keys: []bool) void {
        switch (self.*) {
            inline else => |*impl| impl.setKeys(keys),
        }
    }
};
