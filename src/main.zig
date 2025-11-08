const std = @import("std");

const State = @import("State.zig");
const Frontend = @import("frontends/Frontend.zig").Frontend;
const Backend = @import("backends/Backend.zig").Backend;
const Args = @import("Args.zig");

pub const std_options: std.Options = .{
    .log_level = .info,
    .log_scope_levels = &[_]std.log.ScopeLevel{
        .{ .scope = .interpreter, .level = .info },
        .{ .scope = .bchip8, .level = .info },
    },
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    var args_it = try std.process.argsWithAllocator(allocator);
    defer args_it.deinit();

    const args = Args.parse(&args_it) catch |err| {
        std.log.info("{s}\n", .{Args.usage});
        std.log.err("{s}", .{@errorName(err)});
        std.process.exit(1);
    };

    var state = try State.init(args.rom_path, .{
        .backend = Backend.initFromArgs(args),
        .tick_rate = args.tick_rate,
        .set_memory_address = args.set_memory_address,
        .set_memory_address_value = args.set_memory_address_value,
    });
    var front = try Frontend.initFromArgs(allocator, args);
    defer front.deinit();

    while (!front.shouldStop()) {
        front.setKeys(&state.keys);
        state.executeNextInstruction();
        try front.draw(state.should_draw, state.display);
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
