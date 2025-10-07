const std = @import("std");
const State = @import("State.zig");
const instr = @import("instructions.zig");

pub fn main() !void {
    const args = parseArgs();

    var state = try State.init(args.rom_path);
    while (state.pc < State.rom_loading_location + state.rom_size) : (state.pc += 2) {
        const instruction = (@as(u16, state.memory[state.pc]) << 8) | state.memory[state.pc + 1];
        instr.execute(instruction, &state);
    }
}

const Args = struct {
    rom_path: []const u8,
};

fn parseArgs() Args {
    var args = std.process.args();
    defer args.deinit();
    _ = args.skip(); // Program name
    const rom_path = args.next();
    if (rom_path == null) {
        std.log.err("One argument is required which is the rom path", .{});
        std.process.exit(1);
    }
    return Args{ .rom_path = rom_path.? };
}

test {
    _ = @import("instructions.zig");
}
