const std = @import("std");
const State = @import("State.zig");

const InstructionFn = fn (instruction: u16, state: *State) void;

const log = std.log.scoped(.instr);

pub fn execute(instruction: u16, state: *State) void {
    if (LDK_waiting_for_key(state)) {
        return;
    }

    const instruction_fn: *const InstructionFn = switch (instruction) {
        0xE0 => CLS,
        0xEE => RET,
        else => switch ((instruction & 0xF000) >> 12) {
            0 => SYS,
            1 => JP,
            2 => CALL,
            3 => SE,
            4 => SNE,
            5 => SEV,
            6 => LD,
            7 => ADD,
            8 => switch (instruction & 0xF) {
                0 => LDV,
                1 => OR,
                2 => AND,
                3 => XOR,
                4 => ADDV,
                5 => SUB,
                6 => SHR,
                7 => SUBN,
                0xE => SHL,
                else => unhandled,
            },
            9 => SNEV,
            0xA => LDI,
            0xB => JPV,
            0xC => RND,
            0xD => DRW,
            0xE => switch (instruction & 0xFF) {
                0x9E => SKP,
                0xA1 => SKNP,
                else => unhandled,
            },
            0xF => switch (instruction & 0xFF) {
                0x07 => LDVDT,
                0x0A => LDK,
                0x15 => LDDTV,
                0x18 => LDST,
                0x1E => ADDI,
                0x29 => LDF,
                0x33 => LDB,
                0x55 => LDIVX,
                0x65 => LDVXI,
                else => unhandled,
            },
            else => unhandled,
        },
    };
    @call(.auto, instruction_fn, .{ instruction, state });
}

fn unhandled(instruction: u16, state: *State) void {
    log.debug("[0x{X:0>4}] {X:0>4} Unhandled", .{ state.pc, instruction });
}

// For instruction in format PNNN returns NNN
fn pnnn(instruction: u16) u16 {
    return instruction & 0xFFF;
}

// For instruction in format PXKK returns X and KK
fn pxkk(instruction: u16) struct { x: usize, kk: u8 } {
    return .{
        .x = (instruction & 0x0F00) >> 8,
        .kk = @intCast(instruction & 0xFF),
    };
}

// For instruction in format PXY0 return X and Y
fn pxy0(instruction: u16) struct { x: usize, y: usize } {
    return .{ .x = (instruction & 0x0F00) >> 8, .y = (instruction & 0x00F0) >> 4 };
}

// For instruction in format PX00 return X
fn px00(instruction: u16) u4 {
    return @intCast((instruction & 0x0F00) >> 8);
}

test "helper functions" {
    try std.testing.expectEqual(0x123, pnnn(0xA123));
    const result1 = pxkk(0xA123);
    try std.testing.expectEqual(1, result1.x);
    try std.testing.expectEqual(0x23, result1.kk);
    const result2 = pxy0(0xA123);
    try std.testing.expectEqual(1, result2.x);
    try std.testing.expectEqual(2, result2.y);
    try std.testing.expectEqual(1, px00(0xA123));
}

// 0nnn - SYS addr
// Jump to a machine code routine at nnn.
// This instruction is only used on the old computers on which Chip-8 was originally implemented. It is ignored by modern interpreters.
fn SYS(instruction: u16, state: *State) void {
    const nnn = pnnn(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SYS NNN={X:0>3}", .{ state.pc, instruction, nnn });
    state.pc += State.instruction_size;
}

// 00E0 - CLS
// Clear the display.
fn CLS(instruction: u16, state: *State) void {
    log.debug("[0x{X:0>4}] {X:0>4} CLS", .{ state.pc, instruction });
    @memset(&state.display, 0);
    state.pc += State.instruction_size;
}

test "CLS" {
    var state = State{};
    state.display[100] = 1;
    execute(0x00E0, &state);
    try std.testing.expectEqual(0, state.display[100]);
}

// 00EE - RET
// Return from a subroutine.
// The interpreter sets the program counter to the address at the top of the stack, then subtracts 1 from the stack pointer.
fn RET(instruction: u16, state: *State) void {
    log.debug("[0x{X:0>4}] {X:0>4} RET", .{ state.pc, instruction });
    state.sp -= 1;
    state.pc = state.stack[state.sp];
    state.pc += State.instruction_size;
}

test "RET" {
    var state = State{ .sp = 2 };
    state.stack[0] = 0x1;
    state.stack[1] = 0xBEEF;
    state.stack[2] = 0x2;

    execute(0x00EE, &state);
    try std.testing.expectEqual(1, state.sp);
    try std.testing.expectEqual(state.stack[1] + State.instruction_size, state.pc);
}

// 1nnn - JP addr
// Jump to location nnn.
// The interpreter sets the program counter to nnn.
fn JP(instruction: u16, state: *State) void {
    const nnn = pnnn(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} JP NNN={X:0>3}", .{ state.pc, instruction, nnn });
    state.pc = nnn;
}

test "JP" {
    var state = State{};
    execute(0x1005, &state);
    try std.testing.expectEqual(5, state.pc);
}

// 2nnn - CALL addr
// Call subroutine at nnn.
// The interpreter increments the stack pointer, then puts the current PC on the top of the stack. The PC is then set to nnn.
fn CALL(instruction: u16, state: *State) void {
    const nnn = pnnn(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} CALL NNN={X:0>3}", .{ state.pc, instruction, nnn });
    state.stack[state.sp] = state.pc;
    state.sp += 1;
    state.pc = nnn;
}

test "CALL" {
    var state = State{};
    state.pc = 0x234;
    execute(0x2123, &state);
    try std.testing.expectEqual(0x234, state.stack[state.sp - 1]);
    try std.testing.expectEqual(1, state.sp);
    try std.testing.expectEqual(0x123, state.pc);
}

// 3xkk - SE Vx, byte
// Skip next instruction if Vx = kk.
// The interpreter compares register Vx to kk, and if they are equal, increments the program counter by 2.
fn SE(instruction: u16, state: *State) void {
    const instr = pxkk(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SE X={X} KK={X:0>2}", .{ state.pc, instruction, instr.x, instr.kk });
    if (state.V[instr.x] == instr.kk) {
        state.pc += (2 * State.instruction_size);
    } else {
        state.pc += State.instruction_size;
    }
}

test "SE" {
    var state = State{};
    const initial_pc = state.pc;
    state.V[1] = 0x23;
    execute(0x3123, &state);
    try std.testing.expectEqual(initial_pc + (2 * State.instruction_size), state.pc);
}

// 4xkk - SNE Vx, byte
// Skip next instruction if Vx != kk.
// The interpreter compares register Vx to kk, and if they are not equal, increments the program counter by 2.
fn SNE(instruction: u16, state: *State) void {
    const instr = pxkk(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SNE X={X} KK={X:0>2}", .{ state.pc, instruction, instr.x, instr.kk });
    if (state.V[instr.x] != instr.kk) {
        state.pc += (2 * State.instruction_size);
    } else {
        state.pc += State.instruction_size;
    }
}

test "SNE" {
    var state = State{};
    const initial_pc = state.pc;
    state.V[1] = 0x24;
    execute(0x4123, &state);
    try std.testing.expectEqual(initial_pc + (2 * State.instruction_size), state.pc);
}

// 5xy0 - SE Vx, Vy
// Skip next instruction if Vx = Vy.
// The interpreter compares register Vx to register Vy, and if they are equal, increments the program counter by 2.
fn SEV(instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SEV X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    if (state.V[instr.x] == state.V[instr.y]) {
        state.pc += (2 * State.instruction_size);
    } else {
        state.pc += State.instruction_size;
    }
}

test "SEV" {
    var state = State{};
    const initial_pc = state.pc;
    state.V[1] = 0x24;
    state.V[2] = state.V[1];
    execute(0x5120, &state);
    try std.testing.expectEqual(initial_pc + (2 * State.instruction_size), state.pc);
}

// 6xkk - LD Vx, byte
// Set Vx = kk.
// The interpreter puts the value kk into register Vx.
fn LD(instruction: u16, state: *State) void {
    const instr = pxkk(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LD X={X} KK={X:0>2}", .{ state.pc, instruction, instr.x, instr.kk });
    state.V[instr.x] = instr.kk;
    state.pc += State.instruction_size;
}

test "LD" {
    var state = State{};
    execute(0x6123, &state);
    try std.testing.expectEqual(0x23, state.V[1]);
}

// 7xkk - ADD Vx, byte
// Set Vx = Vx + kk.
// Adds the value kk to the value of register Vx, then stores the result in Vx.
fn ADD(instruction: u16, state: *State) void {
    const instr = pxkk(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} ADD X={X} KK={X:0>2}", .{ state.pc, instruction, instr.x, instr.kk });
    state.V[instr.x] = @addWithOverflow(state.V[instr.x], instr.kk).@"0";
    state.pc += State.instruction_size;
}

test "ADD" {
    var state = State{};
    const initial_value = 5;
    state.V[1] = initial_value;
    execute(0x7123, &state);
    try std.testing.expectEqual(initial_value + 0x23, state.V[1]);

    // Overflow should wrap
    state.V[1] = 255;
    execute(0x7102, &state);
    try std.testing.expectEqual(1, state.V[1]);
}

// 8xy0 - LD Vx, Vy
// Set Vx = Vy.
// Stores the value of register Vy in register Vx.
fn LDV(instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDV X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    state.V[instr.x] = state.V[instr.y];
    state.pc += State.instruction_size;
}

test "LDV" {
    var state = State{};
    state.V[2] = 10;
    execute(0x8120, &state);
    try std.testing.expectEqual(state.V[2], state.V[1]);
}

// 8xy1 - OR Vx, Vy
// Set Vx = Vx OR Vy.
// Performs a bitwise OR on the values of Vx and Vy, then stores the result in Vx.
// A bitwise OR compares the corrseponding bits from two values,
// and if either bit is 1, then the same bit in the result is also 1. Otherwise, it is 0.
fn OR(instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} OR X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    state.V[instr.x] |= state.V[instr.y];
    state.pc += State.instruction_size;
}

test "OR" {
    var state = State{};
    const initial_value = 5;
    state.V[0xA] = initial_value;
    state.V[0xD] = 9;
    execute(0x8AD1, &state);
    try std.testing.expectEqual(initial_value | state.V[0xD], state.V[0xA]);
}

// 8xy2 - AND Vx, Vy
// Set Vx = Vx AND Vy.
// Performs a bitwise AND on the values of Vx and Vy, then stores the result in Vx.
// A bitwise AND compares the corrseponding bits from two values,
// and if both bits are 1, then the same bit in the result is also 1. Otherwise, it is 0.
fn AND(instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} AND X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    state.V[instr.x] &= state.V[instr.y];
    state.pc += State.instruction_size;
}

test "AND" {
    var state = State{};
    const initial_value = 5;
    state.V[0xA] = initial_value;
    state.V[0xD] = 9;
    execute(0x8AD2, &state);
    try std.testing.expectEqual(initial_value & state.V[0xD], state.V[0xA]);
}

// 8xy3 - XOR Vx, Vy
// Set Vx = Vx XOR Vy.
// Performs a bitwise exclusive OR on the values of Vx and Vy, then stores the result in Vx.
// An exclusive OR compares the corrseponding bits from two values,
// and if the bits are not both the same, then the corresponding bit in the result is set to 1. Otherwise, it is 0.
fn XOR(instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} XOR X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    state.V[instr.x] ^= state.V[instr.y];
    state.pc += State.instruction_size;
}

test "XOR" {
    var state = State{};
    const initial_value = 5;
    state.V[0xA] = initial_value;
    state.V[0xD] = 9;
    execute(0x8AD3, &state);
    try std.testing.expectEqual(initial_value ^ state.V[0xD], state.V[0xA]);
}

// 8xy4 - ADD Vx, Vy
// Set Vx = Vx + Vy, set VF = carry.
// The values of Vx and Vy are added together.
// If the result is greater than 8 bits (i.e., > 255,) VF is set to 1, otherwise 0.
// Only the lowest 8 bits of the result are kept, and stored in Vx.
fn ADDV(instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} ADDV X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    const result = @addWithOverflow(state.V[instr.x], state.V[instr.y]);
    state.V[instr.x] = result.@"0";
    state.V[0xF] = result.@"1";
    state.pc += State.instruction_size;
}

test "ADDV" {
    var state = State{};
    state.V[0xA] = 255;
    state.V[0xD] = 1;
    execute(0x8AD4, &state);
    try std.testing.expectEqual(0, state.V[0xA]);
    try std.testing.expectEqual(1, state.V[0xF]);

    state.V[0xA] = 100;
    state.V[0xD] = 1;
    execute(0x8AD4, &state);
    try std.testing.expectEqual(101, state.V[0xA]);
    try std.testing.expectEqual(0, state.V[0xF]);
}

// 8xy5 - SUB Vx, Vy
// Set Vx = Vx - Vy, set VF = NOT borrow.
// If Vx > Vy, then VF is set to 1, otherwise 0. Then Vy is subtracted from Vx, and the results stored in Vx.
fn SUB(instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SUB X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    const borrow: u8 = if (state.V[instr.x] >= state.V[instr.y]) 1 else 0;
    state.V[instr.x] = @subWithOverflow(state.V[instr.x], state.V[instr.y]).@"0";
    state.pc += State.instruction_size;
    state.V[0xF] = borrow;
}

test "SUB" {
    var state = State{};
    state.V[0xA] = 100;
    state.V[0xD] = 1;
    execute(0x8AD5, &state);
    try std.testing.expectEqual(99, state.V[0xA]);
    try std.testing.expectEqual(1, state.V[0xF]);

    state.V[0xA] = 20;
    state.V[0xD] = 80;
    execute(0x8AD5, &state);
    try std.testing.expectEqual(196, state.V[0xA]);
    try std.testing.expectEqual(0, state.V[0xF]);
}

// 8xy6 - SHR Vx {, Vy}
// Set Vx = Vx SHR 1.
// If the least-significant bit of Vx is 1, then VF is set to 1, otherwise 0. Then Vx is divided by 2.
// In the original interpreter, this instruction shifted Vy and stored the result in Vx.
// In modern interpreters, it shifts Vx instead.
fn SHR(instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SHR X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    const carry: u8 = state.V[instr.x] & 0x1;
    state.V[instr.x] >>= 1;
    state.pc += State.instruction_size;
    state.V[0xF] = carry;
}

test "SHR" {
    var state = State{};
    var initial_value: u8 = 0xF;
    state.V[0xA] = initial_value;
    execute(0x8AD6, &state);
    try std.testing.expectEqual(initial_value >> 1, state.V[0xA]);
    try std.testing.expectEqual(1, state.V[0xF]);

    initial_value = 0x8;
    state.V[0xA] = initial_value;
    execute(0x8AD6, &state);
    try std.testing.expectEqual(initial_value >> 1, state.V[0xA]);
    try std.testing.expectEqual(0, state.V[0xF]);
}

// 8xy7 - SUBN Vx, Vy
// Set Vx = Vy - Vx, set VF = NOT borrow.
// If Vy > Vx, then VF is set to 1, otherwise 0. Then Vx is subtracted from Vy, and the results stored in Vx.
fn SUBN(instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SUBN X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    const borrow: u8 = if (state.V[instr.y] >= state.V[instr.x]) 1 else 0;
    state.V[instr.x] = @subWithOverflow(state.V[instr.y], state.V[instr.x]).@"0";
    state.pc += State.instruction_size;
    state.V[0xF] = borrow;
}

test "SUBN" {
    var state = State{};
    state.V[0xA] = 1;
    state.V[0xD] = 100;
    execute(0x8AD7, &state);
    try std.testing.expectEqual(99, state.V[0xA]);
    try std.testing.expectEqual(1, state.V[0xF]);

    state.V[0xA] = 80;
    state.V[0xD] = 20;
    execute(0x8AD7, &state);
    try std.testing.expectEqual(196, state.V[0xA]);
    try std.testing.expectEqual(0, state.V[0xF]);
}

// 8xyE - SHL Vx {, Vy}
// Set Vx = Vx SHL 1.
// If the most-significant bit of Vx is 1, then VF is set to 1, otherwise to 0. Then Vx is multiplied by 2.
// In the original interpreter, this instruction shifted Vy and stored the result in Vx.
// In modern interpreters, it shifts Vx instead.
fn SHL(instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SHL X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    const carry: u8 = (state.V[instr.x] >> 7) & 0x1;
    state.V[instr.x] <<= 1;
    state.pc += State.instruction_size;
    state.V[0xF] = carry;
}

test "SHL" {
    var state = State{};
    const initial_value: u8 = 240;
    state.V[0xA] = initial_value;
    execute(0x8ADE, &state);
    try std.testing.expectEqual(initial_value << 1, state.V[0xA]);
    try std.testing.expectEqual(1, state.V[0xF]);
}

// 9xy0 - SNE Vx, Vy
// Skip next instruction if Vx != Vy.
// The values of Vx and Vy are compared, and if they are not equal, the program counter is increased by 2.
fn SNEV(instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SNEV X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    if (state.V[instr.x] != state.V[instr.y]) {
        state.pc += (2 * State.instruction_size);
    } else {
        state.pc += State.instruction_size;
    }
}

test "SNEV" {
    var state = State{};
    const initial_pc = state.pc;
    state.V[0xA] = 0x24;
    state.V[0xB] = 0x25;
    execute(0x9AB0, &state);
    try std.testing.expectEqual(initial_pc + (2 * State.instruction_size), state.pc);
}

// Annn - LD I, addr
// Set I = nnn.
// The value of register I is set to nnn.
fn LDI(instruction: u16, state: *State) void {
    const nnn = pnnn(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDI NNN={X:0>3}", .{ state.pc, instruction, nnn });
    state.I = nnn;
    state.pc += State.instruction_size;
}

test "LDI" {
    var state = State{};
    execute(0xA123, &state);
    try std.testing.expectEqual(0x123, state.I);
}

// Bnnn - JP V0, addr
// Jump to location nnn + V0.
// The program counter is set to nnn plus the value of V0.
fn JPV(instruction: u16, state: *State) void {
    const nnn = pnnn(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} JPV NNN={X:0>3}", .{ state.pc, instruction, nnn });
    state.pc = nnn + state.V[0];
}

test "JPV" {
    var state = State{};
    state.V[0] = 5;
    execute(0xB023, &state);
    try std.testing.expectEqual(@as(u16, 0x23) + state.V[0], state.pc);
}

// Cxkk - RND Vx, byte
// Set Vx = random byte AND kk.
// The interpreter generates a random number from 0 to 255, which is then ANDed with the value kk.
// The results are stored in Vx. See instruction 8xy2 for more information on AND.
fn RND(instruction: u16, state: *State) void {
    const instr = pxkk(instruction);
    const random_byte = state.prng.int(u8);
    log.debug("[0x{X:0>4}] {X:0>4} RND X={X} KK={X:0>2} RND={X}", .{ state.pc, instruction, instr.x, instr.kk, random_byte });
    state.V[instr.x] = random_byte & instr.kk;
    state.pc += State.instruction_size;
}

test "RND" {
    var state = State{
        .prng = rnd: {
            var prng = std.Random.DefaultPrng.init(0x12fe3dab36);
            break :rnd prng.random();
        },
    };
    execute(0xCA12, &state);
    const seed_first_random_value: u8 = 169;
    try std.testing.expectEqual(seed_first_random_value & 0x12, state.V[0xA]);
}

// Dxyn - DRW Vx, Vy, nibble
// Display n-byte sprite starting at memory location I at (Vx, Vy), set VF = collision.
// The interpreter reads n bytes from memory, starting at the address stored in I.
// These bytes are then displayed as sprites on screen at coordinates (Vx, Vy).
// Sprites are XORed onto the existing screen.
// If this causes any pixels to be erased, VF is set to 1, otherwise it is set to 0.
// If the sprite is positioned so part of it is outside the coordinates of the display,
// it wraps around to the opposite side of the screen.
// See instruction 8xy3 for more information on XOR, and section 2.4, Display,
// for more information on the Chip-8 screen and sprites.
fn DRW(instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    const n = instruction & 0x000F;
    log.debug("[0x{X:0>4}] {X:0>4} DRW X={X} Y={X} N={X}", .{ state.pc, instruction, instr.x, instr.y, n });

    const sprite_bytes = state.memory[state.I .. state.I + n];
    const starting_x = @as(usize, state.V[instr.x]);
    const starting_y = @as(usize, state.V[instr.y]);
    const sprite_height = sprite_bytes.len;

    state.V[0xF] = 0;

    for (0..sprite_height) |sprite_y| {
        const y = (starting_y + sprite_y) % State.display_height;
        const sprite_byte = sprite_bytes[sprite_y];

        for (0..8) |sprite_x| {
            const x = (starting_x + sprite_x) % State.display_width;
            const sprite_bit = (sprite_byte & (@as(u8, 0x80) >> @intCast(sprite_x))) != 0;
            const display_idx = y * State.display_width + x;

            const old_pixel = state.display[display_idx];
            state.display[display_idx] ^= @intFromBool(sprite_bit);

            if (old_pixel == 1 and state.display[display_idx] == 0) {
                state.V[0xF] = 1;
            }
        }
    }
    state.pc += State.instruction_size;
    state.should_draw = true;
}

test "DRW" {
    var state = State{};
    state.I = 0; // Location of the sprite of a "0"
    const x: usize = 10;
    var y: usize = 15;
    const width = State.display_width;
    state.V[0] = x;
    state.V[1] = @intCast(y);
    execute(0xD015, &state);

    try std.testing.expectEqual(0, state.V[0xF]);
    try std.testing.expectEqual(true, state.should_draw);

    try std.testing.expectEqual(1, state.display[y * width + x]);
    try std.testing.expectEqual(1, state.display[y * width + x + 1]);
    try std.testing.expectEqual(1, state.display[y * width + x + 2]);
    try std.testing.expectEqual(1, state.display[y * width + x + 3]);

    y += 1;
    try std.testing.expectEqual(1, state.display[y * width + x]);
    try std.testing.expectEqual(0, state.display[y * width + x + 1]);
    try std.testing.expectEqual(0, state.display[y * width + x + 2]);
    try std.testing.expectEqual(1, state.display[y * width + x + 3]);

    y += 1;
    try std.testing.expectEqual(1, state.display[y * width + x]);
    try std.testing.expectEqual(0, state.display[y * width + x + 1]);
    try std.testing.expectEqual(0, state.display[y * width + x + 2]);
    try std.testing.expectEqual(1, state.display[y * width + x + 3]);

    y += 1;
    try std.testing.expectEqual(1, state.display[y * width + x]);
    try std.testing.expectEqual(0, state.display[y * width + x + 1]);
    try std.testing.expectEqual(0, state.display[y * width + x + 2]);
    try std.testing.expectEqual(1, state.display[y * width + x + 3]);

    y += 1;
    try std.testing.expectEqual(1, state.display[y * width + x]);
    try std.testing.expectEqual(1, state.display[y * width + x + 1]);
    try std.testing.expectEqual(1, state.display[y * width + x + 2]);
    try std.testing.expectEqual(1, state.display[y * width + x + 3]);
}

test "DRW collision" {
    var state = State{};
    state.I = 0; // Location of the sprite of a "0"
    const x: usize = 10;
    const y: usize = 15;
    const width = State.display_width;
    state.V[0] = x;
    state.V[1] = @intCast(y);

    // Draw sprite first time
    execute(0xD015, &state);
    try std.testing.expectEqual(0, state.V[0xF]); // No collision first time

    // Draw same sprite in same location
    execute(0xD015, &state);
    try std.testing.expectEqual(1, state.V[0xF]); // Should detect collision
    try std.testing.expectEqual(0, state.display[y * width + x]); // Pixels should be XORed to 0
}

// Ex9E - SKP Vx
// Skip next instruction if key with the value of Vx is pressed.
// Checks the keyboard, and if the key corresponding to the value of Vx is currently in the down position, PC is increased by 2.
fn SKP(instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SKP X={X}", .{ state.pc, instruction, x });
    const key = state.V[x];
    if (state.keys[key]) {
        state.pc += (State.instruction_size * 2);
    } else {
        state.pc += State.instruction_size;
    }
}

test "SKP" {
    var state = State{};
    const initial_pc = state.pc;
    state.keys[5] = true;
    state.V[0xA] = 5;
    execute(0xEA9E, &state);
    var next_pc_value = initial_pc + (State.instruction_size * 2);
    try std.testing.expectEqual(next_pc_value, state.pc);

    state.keys[5] = false;
    state.V[0xA] = 5;
    execute(0xEA9E, &state);
    next_pc_value += State.instruction_size;
    try std.testing.expectEqual(next_pc_value, state.pc);
}

// ExA1 - SKNP Vx
// Skip next instruction if key with the value of Vx is not pressed.
// Checks the keyboard, and if the key corresponding to the value of Vx is currently in the up position, PC is increased by 2.
fn SKNP(instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SKNP X={X}", .{ state.pc, instruction, x });
    const key = state.V[x];
    if (!state.keys[key]) {
        state.pc += (State.instruction_size * 2);
    } else {
        state.pc += State.instruction_size;
    }
}

test "SKNP" {
    var state = State{};
    const initial_pc = state.pc;
    state.keys[5] = false;
    state.V[0xA] = 5;
    execute(0xEAA1, &state);
    var next_pc_value = initial_pc + (State.instruction_size * 2);

    try std.testing.expectEqual(next_pc_value, state.pc);

    state.keys[5] = true;
    state.V[0xA] = 5;
    execute(0xEAA1, &state);
    next_pc_value += State.instruction_size;
    try std.testing.expectEqual(next_pc_value, state.pc);
}

// Fx07 - LD Vx, DT
// Set Vx = delay timer value.
// The value of DT is placed into Vx.
fn LDVDT(instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDVDT X={X}", .{ state.pc, instruction, x });
    state.V[x] = state.delay_timer;
    state.pc += State.instruction_size;
}

test "LDVDT" {
    var state = State{};
    state.delay_timer = 0x12;
    execute(0xFB07, &state);
    try std.testing.expectEqual(state.delay_timer, state.V[0xB]);
}

// Fx0A - LD Vx, K
// Wait for a key press, store the value of the key in Vx.
// All execution stops until a key is pressed, then the value of that key is stored in Vx.
fn LDK(instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDK X={X}", .{ state.pc, instruction, x });
    state.register_waiting_for_key = x;
    state.key_pressed = null;
}

test "LDK" {
    var state = State{};
    const initial_pc = state.pc;
    execute(0xF50A, &state);
    execute(0xA123, &state); // LDI

    // Nothing should have changed as execute becomes no-op when waiting for
    try std.testing.expectEqual(initial_pc, state.pc);

    // Press key 'A'
    state.keys[0xA] = true;

    // Execution resumed and pc should advance
    execute(0xA123, &state); // LDI
    try std.testing.expectEqual(initial_pc + (State.instruction_size * 2), state.pc);

    // Key is stored in register
    try std.testing.expectEqual(0xA, state.V[5]);
}

// Returns true if the interpreter is waiting for a key to be pressed
fn LDK_waiting_for_key(state: *State) bool {
    if (state.register_waiting_for_key) |register| {
        if (state.key_pressed) |key| {
            // A key is pressed but not yet released => Wait
            if (!state.keys[key]) {
                // A key that was pressed got released => :)
                state.V[register] = key;
                state.register_waiting_for_key = null;
                state.key_pressed = null;
                state.pc += State.instruction_size;
            }
            return true;
        }

        for (state.keys, 0..) |key, i| {
            if (key) {
                state.key_pressed = @intCast(i);
                return true;
            }
        }
        return true;
    }
    return false;
}

test "LDK_waiting_for_key" {
    var state = State{};

    const initial_pc = state.pc;
    // By default we are not waiting
    try std.testing.expect(!LDK_waiting_for_key(&state));

    // After calling LDK we are waiting
    LDK(0xF50A, &state);
    try std.testing.expect(LDK_waiting_for_key(&state));

    // After pressing a key we are no longer waiting and we finish executing LDK by storing the key in the register
    state.keys[0xA] = true;
    try std.testing.expect(!LDK_waiting_for_key(&state));
    try std.testing.expectEqual(0xA, state.V[5]);
    try std.testing.expectEqual(null, state.register_waiting_for_key);
    try std.testing.expectEqual(initial_pc + State.instruction_size, state.pc);
}

// Fx15 - LD DT, Vx
// Set delay timer = Vx.
// DT is set equal to the value of Vx
fn LDDTV(instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDDTV X={X}", .{ state.pc, instruction, x });
    state.delay_timer = state.V[0xB];
    state.pc += State.instruction_size;
}

test "LDDTV" {
    var state = State{};
    state.V[0xB] = 0x13;
    execute(0xFB15, &state);
    try std.testing.expectEqual(state.V[0xB], state.delay_timer);
}

// Fx18 - LD ST, Vx
// Set sound timer = Vx.
// ST is set equal to the value of Vx.
fn LDST(instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDST X={X}", .{ state.pc, instruction, x });
    state.sound_timer = state.V[0xB];
    state.pc += State.instruction_size;
}

test "LDST" {
    var state = State{};
    state.V[0xB] = 0x13;
    execute(0xFB18, &state);
    try std.testing.expectEqual(state.V[0xB], state.sound_timer);
}

// Fx1E - ADD I, Vx
// Set I = I + Vx.
// The values of I and Vx are added, and the results are stored in I.
fn ADDI(instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} ADDI X={X}", .{ state.pc, instruction, x });
    state.I = state.I + state.V[x];
    state.pc += State.instruction_size;
}

test "ADDI" {
    var state = State{};
    state.I = 5;
    state.V[0xC] = 5;
    execute(0xFC1E, &state);
    try std.testing.expectEqual(10, state.I);
}

// Fx29 - LD F, Vx
// Set I = location of sprite for digit Vx.
// The value of I is set to the location for the hexadecimal sprite corresponding to the value of Vx.
// See section 2.4, Display, for more information on the Chip-8 hexadecimal font.
fn LDF(instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDF X={X}", .{ state.pc, instruction, x });
    const sprite_number = state.V[x];
    state.I = sprite_number * State.default_sprites_height;
    state.pc += State.instruction_size;
}

test "LDF" {
    var state = State{};
    state.V[0xC] = 5;
    execute(0xFC29, &state);
    try std.testing.expectEqual(state.V[0xC] * State.default_sprites_height, state.I);
}

// Fx33 - LD B, Vx
// Store BCD representation of Vx in memory locations I, I+1, and I+2.
// The interpreter takes the decimal value of Vx, and places the hundreds digit in memory at location in I, the tens digit at location I+1, and the ones digit at location I+2.
fn LDB(instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDB X={X}", .{ state.pc, instruction, x });
    state.memory[state.I] = state.V[x] / 100;
    state.memory[state.I + 1] = (state.V[x] / 10) % 10;
    state.memory[state.I + 2] = state.V[x] % 10;
    state.pc += State.instruction_size;
}

test "LDB" {
    var state = State{};
    state.I = 50;
    state.V[0xC] = 123;
    execute(0xFC33, &state);
    try std.testing.expectEqual(1, state.memory[state.I]);
    try std.testing.expectEqual(2, state.memory[state.I + 1]);
    try std.testing.expectEqual(3, state.memory[state.I + 2]);
}

// Fx55 - LD [I], Vx
// Store registers V0 through Vx in memory starting at location I.
// The interpreter copies the values of registers V0 through Vx into memory, starting at the address in I.
fn LDIVX(instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDIVX X={X}", .{ state.pc, instruction, x });
    const count: usize = @intCast(x);
    for (0..count + 1) |i| {
        state.memory[state.I + i] = state.V[i];
    }
    const xu16: u16 = @intCast(x);
    state.I += xu16 + 1;
    state.pc += State.instruction_size;
}

test "LDIVX" {
    var state = State{};
    const initial_I = state.I;
    for (0..0xF + 1) |i| {
        state.V[i] = @intCast(i);
    }
    execute(0xFF55, &state);
    for (0..0xF + 1) |i| {
        const asu8: u8 = @intCast(i);
        try std.testing.expectEqual(asu8, state.memory[initial_I + i]);
    }
    try std.testing.expectEqual(initial_I + 0xF + 1, state.I);
}

// Fx65 - LD Vx, [I]
// Read registers V0 through Vx from memory starting at location I.
// The interpreter reads values from memory starting at location I into registers V0 through Vx.
fn LDVXI(instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDVXI X={X}", .{ state.pc, instruction, x });

    const count: usize = @intCast(x);
    for (0..count + 1) |i| {
        state.V[i] = state.memory[state.I + i];
    }
    const xu16: u16 = @intCast(x);
    state.I += xu16 + 1;
    state.pc += State.instruction_size;
}

test "LDVXI" {
    var state = State{};
    const initial_I = state.I;
    for (0..0xF + 1) |i| {
        state.memory[state.I + i] = @intCast(i);
    }
    execute(0xFF65, &state);
    for (0..0xF + 1) |i| {
        const asu8: u8 = @intCast(i);
        try std.testing.expectEqual(asu8, state.V[i]);
    }
    try std.testing.expectEqual(initial_I + 0xF + 1, state.I);
}
