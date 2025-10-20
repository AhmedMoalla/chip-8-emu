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

pub fn DRW(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    const n = @as(usize, instruction & 0x000F);
    log.debug("[0x{X:0>4}] {X:0>4} DRW X={X} Y={X} N={X}", .{ state.pc, instruction, instr.x, instr.y, n });

    const sprite_bytes = state.memory[state.I .. state.I + n];

    const start_x = @as(usize, state.V[instr.x]) % State.display_width;
    const start_y = @as(usize, state.V[instr.y]) % State.display_height;

    state.V[0xF] = 0;

    for (sprite_bytes, 0..) |sprite_byte, row| {
        const y = (start_y + row) % State.display_height;

        for (0..8) |bit_idx| {
            const x = (start_x + bit_idx) % State.display_width;

            const bit_set = (sprite_byte & (@as(u8, 0x80) >> @intCast(bit_idx))) != 0;
            if (!bit_set) continue;

            const idx = y * State.display_width + x;
            const old_pixel = state.display[idx];
            const new_pixel = old_pixel ^ 1;
            state.display[idx] = new_pixel;

            if (old_pixel == 1 and new_pixel == 0) {
                state.V[0xF] = 1;
            }
        }
    }

    state.pc += State.instruction_size;
    state.should_draw = true;
}
