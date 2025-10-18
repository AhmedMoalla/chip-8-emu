const std = @import("std");
const State = @import("../State.zig");
const Backend = @import("Backend.zig");

const pnnn = Backend.pnnn;
const pxkk = Backend.pxkk;
const pxy0 = Backend.pxy0;
const px00 = Backend.px00;

const log = std.log.scoped(.schip);

// https://chip8.gulrak.net/#quirk5: Don't reset VF
pub fn OR(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} OR X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    state.V[instr.x] |= state.V[instr.y];
    state.pc += State.instruction_size;
}

// https://chip8.gulrak.net/#quirk5: Don't reset VF
pub fn AND(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} AND X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    state.V[instr.x] &= state.V[instr.y];
    state.pc += State.instruction_size;
}

// https://chip8.gulrak.net/#quirk5: Don't reset VF
pub fn XOR(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} XOR X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    state.V[instr.x] ^= state.V[instr.y];
    state.pc += State.instruction_size;
}

// https://chip8.gulrak.net/#quirk12: Don't increment I
pub fn LDIVX(_: @This(), instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDIVX X={X}", .{ state.pc, instruction, x });
    const count: usize = @intCast(x);
    for (0..count + 1) |i| {
        state.memory[state.I + i] = state.V[i];
    }
    state.pc += State.instruction_size;
}

// https://chip8.gulrak.net/#quirk12: Don't increment I
pub fn LDVXI(_: @This(), instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDVXI X={X}", .{ state.pc, instruction, x });

    const count: usize = @intCast(x);
    for (0..count + 1) |i| {
        state.V[i] = state.memory[state.I + i];
    }
    state.pc += State.instruction_size;
}

// https://chip8.gulrak.net/#quirk6: don't use VY just shift VX in place
pub fn SHR(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SHR X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    const carry: u8 = state.V[instr.x] & 0x1;
    state.V[instr.x] >>= 1;
    state.pc += State.instruction_size;
    state.V[0xF] = carry;
}

// https://chip8.gulrak.net/#quirk6: don't use VY just shift VX in place
pub fn SHL(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SHL X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    const carry: u8 = (state.V[instr.x] >> 7) & 0x1;
    state.V[instr.x] <<= 1;
    state.pc += State.instruction_size;
    state.V[0xF] = carry;
}

// Becomes Bxnn instead of Bnnn. jumps to xnn + Vx instead of nnn + V0
pub fn JPV(_: @This(), instruction: u16, state: *State) void {
    const nnn = pnnn(instruction);
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} JPV X={X} NNN={X:0>3}", .{ state.pc, instruction, x, nnn });
    state.pc = nnn + state.V[x];
}
