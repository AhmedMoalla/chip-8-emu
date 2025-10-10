const std = @import("std");

const instr = @import("instructions.zig");
const State = @import("State.zig");

pub fn print(state: State, what: struct {
    registers: bool = true,
    memory: bool = false,
    stack: bool = false,
}) void {
    std.debug.print("==================================================================================\n", .{});
    if (what.registers) {
        std.debug.print("Registers\n", .{});
        std.debug.print("----------------------------------------------------------------------------------\n", .{});
        printRegisters(state);
        std.debug.print("----------------------------------------------------------------------------------\n", .{});
    }

    if (what.memory) {
        std.debug.print("Memory\n", .{});
        std.debug.print("----------------------------------------------------------------------------------\n", .{});
        printMemory(state);
        std.debug.print("----------------------------------------------------------------------------------\n", .{});
    }

    if (what.stack) {
        std.debug.print("Stack\n", .{});
        std.debug.print("----------------------------------------------------------------------------------\n", .{});
        printStack(state);
        std.debug.print("----------------------------------------------------------------------------------\n", .{});
    }
    std.debug.print("==================================================================================\n", .{});
}

fn printMemory(state: State) void {
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
    while (i < state.memory.len) : (i += bytes_per_row) {
        const row_end = @min(i + bytes_per_row, state.memory.len);
        const row = state.memory[i..row_end];

        const is_zero_row = blk: {
            for (row) |b| if (b != 0) break :blk false;
            break :blk true;
        };

        const is_first = (i == 0);
        const is_last = (row_end == state.memory.len);

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
        const pc = state.pc;
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

fn printRegisters(state: State) void {
    std.debug.print("PC    ", .{});
    std.debug.print("I     ", .{});
    std.debug.print("DT  ", .{});
    std.debug.print("ST  ", .{});
    for (0..state.V.len) |i| {
        std.debug.print("V{X}  ", .{i});
    }

    std.debug.print("\n", .{});

    std.debug.print("{X:0>4}  ", .{state.pc});
    std.debug.print("{X:0>4}  ", .{state.I});
    std.debug.print("{X:0>2}  ", .{state.delay_timer});
    std.debug.print("{X:0>2}  ", .{state.sound_timer});
    for (state.V) |value| {
        std.debug.print("{X:0>2}  ", .{value});
    }
    std.debug.print("\n", .{});
}

fn printStack(state: State) void {
    for (state.stack, 0..) |value, i| {
        if (i == state.sp) {
            std.debug.print(">", .{});
        } else {
            std.debug.print(" ", .{});
        }
        std.debug.print("{:2}: (0x{X:0>4})\n", .{ i, value });
    }
}

pub fn printROM(rom_path: []const u8) void {
    std.debug.print("==================================================================================\n", .{});
    std.debug.print("ROM\n", .{});
    std.debug.print("----------------------------------------------------------------------------------\n", .{});
    var state = State.init(rom_path) catch unreachable;
    state.sp = 10;
    while (state.pc < State.rom_loading_location + state.rom_size) : (state.pc += State.instruction_size) {
        const initial_pc = state.pc;
        const instruction = (@as(u16, state.memory[state.pc]) << 8) | state.memory[state.pc + 1];
        instr.execute(instruction, &state);
        state.pc = initial_pc;
    }
    std.debug.print("==================================================================================\n", .{});
}
