const std = @import("std");

const State = @This();

pub const instruction_size = 2;
pub const stack_size = 16;
pub const memory_size = 4096;
pub const rom_loading_location = 0x200;

// Available to instructions
memory: [memory_size]u8 = [_]u8{0} ** memory_size,
V: [16]u8 = [_]u8{0} ** 16, // V0..VF
I: u16 = 0,
delay_timer: u8 = 0,
sound_timer: u8 = 0,

// For flow control
pc: u16 = rom_loading_location,
sp: u8 = 0,
stack: [stack_size]u16 = [_]u16{0} ** stack_size,

// Populated after initialization
rom_size: usize = 0,

// Used by RND instruction
prng: std.Random = undefined,

pub fn init(rom_path: []const u8) !State {
    var state = State{
        .prng = rnd: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            var prng = std.Random.DefaultPrng.init(seed);
            break :rnd prng.random();
        },
    };
    state.rom_size = loadROM(rom_path, &state.memory) catch |err| switch (err) {
        error.FileNotFound => {
            std.log.err("Rom at '{s}' was not found", .{rom_path});
            std.process.exit(1);
        },
        else => return err,
    };
    return state;
}

fn loadROM(path: []const u8, memory: *[memory_size]u8) !usize {
    const file = try std.fs.cwd().openFile(path, .{});
    const bytes_read = try file.read(memory[rom_loading_location..memory.len]);
    std.log.debug("Read {} bytes to memory location 0x{X} from rom at '{s}'", .{
        bytes_read,
        rom_loading_location,
        path,
    });
    return bytes_read;
}

test "loadROM" {
    const rom_path = "roms/ibm-logo.ch8";
    const rom_file = try std.fs.cwd().openFile(rom_path, .{});
    var expected_memory = [_]u8{0} ** memory_size;
    _ = try rom_file.read(expected_memory[rom_loading_location..expected_memory.len]);

    var memory = [_]u8{0} ** memory_size;
    const bytes_read = try loadROM(rom_path, &memory);
    try std.testing.expectEqualSlices(u8, &expected_memory, &memory);
    try std.testing.expectEqual(132, bytes_read);
}
