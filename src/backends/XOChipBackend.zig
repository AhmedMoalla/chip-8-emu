const std = @import("std");
const State = @import("../State.zig");
const Backend = @import("Backend.zig");

const pnnn = Backend.pnnn;
const pxkk = Backend.pxkk;
const pxy0 = Backend.pxy0;
const px00 = Backend.px00;

const log = std.log.scoped(.xochip);

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
