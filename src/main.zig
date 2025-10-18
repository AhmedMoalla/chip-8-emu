const std = @import("std");

const State = @import("State.zig");
const Frontend = @import("frontends.zig").Frontend;
const Backend = @import("backends/Backend.zig").Backend;
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

    const args = Args.parse(allocator) catch |err| {
        std.log.info("{s}\n", .{Args.usage});
        std.log.err("{s}", .{@errorName(err)});
        std.process.exit(1);
    };

    const back = Backend.initFromArgs(args);
    var state = try State.init(back, args.rom_path, args.tick_rate);
    var front = try Frontend.initFromArgs(allocator, args);
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
    _ = @import("Args.zig");
}
