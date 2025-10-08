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

pub fn print(self: State, what: struct { registers: bool = false, memory: bool = false }) void {
    std.debug.print("==================================================================================\n", .{});
    if (what.registers) {
        std.debug.print("Registers\n", .{});
        std.debug.print("----------------------------------------------------------------------------------\n", .{});
        self.printRegisters();
    }
    if (what.registers and what.memory) {
        std.debug.print("----------------------------------------------------------------------------------\n", .{});
    }
    if (what.memory) {
        std.debug.print("Memory\n", .{});
        std.debug.print("----------------------------------------------------------------------------------\n", .{});
        self.printMemory();
    }
    std.debug.print("==================================================================================\n", .{});
}

fn printMemory(self: State) void {
    const bytes_per_row = 16;

    // Print header
    std.debug.print("          ", .{});
    for (0..bytes_per_row) |i| {
        std.debug.print("{X:0>2} ", .{i});
    }
    std.debug.print("\n", .{});
    std.debug.print("        ", .{});
    for (0..bytes_per_row) |_| {
        std.debug.print("---", .{});
    }
    std.debug.print("--", .{});
    std.debug.print("\n", .{});

    // Print rows
    var i: usize = 0;
    var skipped = false;
    while (i < self.memory.len) : (i += bytes_per_row) {
        const row_end = @min(i + bytes_per_row, self.memory.len);
        const row = self.memory[i..row_end];

        const is_zero_row = blk: {
            for (row) |b| if (b != 0) break :blk false;
            break :blk true;
        };

        const is_first = (i == 0);
        const is_last = (row_end == self.memory.len);

        if (is_zero_row and !is_first and !is_last) {
            // collapse repeated zero lines
            if (!skipped) {
                std.debug.print("         *\n", .{});
                skipped = true;
            }
            continue;
        }

        skipped = false;
        std.debug.print("{X:0>8}: ", .{i});
        for (row) |b| {
            std.debug.print("{X:0>2} ", .{b});
        }
        std.debug.print("\n", .{});

        // Print underline for PC if in this row
        const pc = self.pc;
        if (pc >= i and pc < row_end) {
            const pc_offset = pc - i;
            const prefix = 10 + pc_offset * 4; // spacing before marker
            var j: usize = 0;
            while (j < prefix) : (j += 1) {
                std.debug.print(" ", .{});
            }
            std.debug.print("^^\n", .{});
        }
    }
}

fn printRegisters(self: State) void {
    std.debug.print("PC    ", .{});
    std.debug.print("I     ", .{});
    std.debug.print("DT  ", .{});
    std.debug.print("ST  ", .{});
    for (0..self.V.len) |i| {
        std.debug.print("V{X}  ", .{i});
    }

    std.debug.print("\n", .{});

    std.debug.print("{X:0>4}  ", .{self.pc});
    std.debug.print("{X:0>4}  ", .{self.I});
    std.debug.print("{X:0>2}  ", .{self.delay_timer});
    std.debug.print("{X:0>2}  ", .{self.sound_timer});
    for (self.V) |value| {
        std.debug.print("{X:0>2}  ", .{value});
    }
    std.debug.print("\n", .{});
}
