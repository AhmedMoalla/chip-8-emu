const std = @import("std");
const State = @import("../State.zig");
const f = @import("Frontend.zig");
const FrontendOptions = f.FrontendOptions;

const ConsoleFrontend = @This();

const Options = struct {
    allocator: std.mem.Allocator,
};

allocator: std.mem.Allocator,

pub fn init(allocator: std.mem.Allocator, _: anytype) !ConsoleFrontend {
    return ConsoleFrontend{ .allocator = allocator };
}

pub fn shouldStop(_: ConsoleFrontend) bool {
    return false;
}

pub fn draw(_: *ConsoleFrontend, should_draw: bool, display: [State.display_resolution]u8) void {
    if (!should_draw) return;
    std.debug.print("\x1B[2J\x1B[H", .{});
    for (0..State.display_height) |y| {
        for (0..State.display_width) |x| {
            const bit = display[y * State.display_width + x];
            if (bit == 0) {
                std.debug.print("░", .{});
            } else {
                std.debug.print("▓", .{});
            }
        }
        std.debug.print("\n", .{});
    }
}

pub fn setKeys(_: *ConsoleFrontend, _: []bool) void {}
