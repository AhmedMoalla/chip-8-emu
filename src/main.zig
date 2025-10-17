const std = @import("std");

const State = @import("State.zig");
const Frontend = @import("frontends.zig").Frontend;
const default_backend = @import("backends/Backend.zig").default_backend;
const Args = @import("Args.zig");

pub const std_options: std.Options = .{
    .log_level = .info,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .bchip8, .level = .info },
    },
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try Args.parse(allocator);

    var state = try State.init(default_backend, args.rom_path, args.tick_rate);
    var front = switch (args.frontend) {
        .raylib => try Frontend.init(.raylib, .{ .allocator = allocator }),
        .console => try Frontend.init(.console, .{}),
    };
    defer front.deinit();

    while (!front.shouldStop()) {
        front.setKeys(&state.keys);
        state.executeNextInstruction();
        front.draw(state.should_draw, state.display);
        state.should_draw = false;
        if (state.sound_timer > 0) {
            front.playSound();
        }
    }
}

test {
    _ = @import("tests/tests.zig");
}
