const std = @import("std");
const State = @import("State.zig");

const log = std.log.scoped(.interpreter);

const Backend = @import("backends/Backend.zig").Backend;
const InstructionFnBack = fn (backend: Backend, instruction: u16, state: *State) void;

pub fn execute(backend: Backend, instruction: u16, state: *State) void {
    if (backend.LDK_waiting_for_key(state)) {
        return;
    }

    const instruction_fn: *const InstructionFnBack = switch (instruction) {
        0xE0 => Backend.CLS,
        0xEE => Backend.RET,
        else => switch ((instruction & 0xF000) >> 12) {
            0 => Backend.SYS,
            1 => Backend.JP,
            2 => Backend.CALL,
            3 => Backend.SE,
            4 => Backend.SNE,
            5 => Backend.SEV,
            6 => Backend.LD,
            7 => Backend.ADD,
            8 => switch (instruction & 0xF) {
                0 => Backend.LDV,
                1 => Backend.OR,
                2 => Backend.AND,
                3 => Backend.XOR,
                4 => Backend.ADDV,
                5 => Backend.SUB,
                6 => Backend.SHR,
                7 => Backend.SUBN,
                0xE => Backend.SHL,
                else => unhandled,
            },
            9 => Backend.SNEV,
            0xA => Backend.LDI,
            0xB => Backend.JPV,
            0xC => Backend.RND,
            0xD => Backend.DRW,
            0xE => switch (instruction & 0xFF) {
                0x9E => Backend.SKP,
                0xA1 => Backend.SKNP,
                else => unhandled,
            },
            0xF => switch (instruction & 0xFF) {
                0x07 => Backend.LDVDT,
                0x0A => Backend.LDK,
                0x15 => Backend.LDDTV,
                0x18 => Backend.LDST,
                0x1E => Backend.ADDI,
                0x29 => Backend.LDF,
                0x33 => Backend.LDB,
                0x55 => Backend.LDIVX,
                0x65 => Backend.LDVXI,
                else => unhandled,
            },
            else => unhandled,
        },
    };

    @call(.auto, instruction_fn, .{ backend, instruction, state });
}

fn unhandled(_: Backend, instruction: u16, state: *State) void {
    log.err("[0x{X:0>4}] {X:0>4} Unhandled", .{ state.pc, instruction });
}
