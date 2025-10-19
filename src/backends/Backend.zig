const State = @import("../State.zig");
const Chip8Backend = @import("Chip8Backend.zig");
const SuperChipBackend = @import("SuperChipBackend.zig");
const XOChipBackend = @import("XOChipBackend.zig");

pub const default_backend: Backend = .{ .chip8 = Chip8Backend{} };

pub const Backend = union(enum) {
    chip8: Chip8Backend,
    schip: SuperChipBackend,
    xochip: XOChipBackend,

    pub const Kind = @typeInfo(Backend).@"union".tag_type.?;

    pub fn initFromArgs(opts: anytype) @This() {
        switch (opts.backend) {
            inline else => |b| {
                const field_name = @tagName(b);
                const FieldType = @FieldType(@This(), field_name);
                return @unionInit(@This(), field_name, FieldType{});
            },
        }
    }

    // 0nnn - SYS addr
    // Jump to a machine code routine at nnn.
    // This instruction is only used on the old computers on which Chip-8 was originally implemented. It is ignored by modern interpreters.
    pub fn SYS(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "SYS")) impl.SYS(instruction, state) else default_backend.SYS(instruction, state),
        }
    }

    // 00E0 - CLS
    // Clear the display.
    pub fn CLS(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "CLS")) impl.CLS(instruction, state) else default_backend.CLS(instruction, state),
        }
    }

    // 00EE - RET
    // Return from a subroutine.
    // The interpreter sets the program counter to the address at the top of the stack, then subtracts 1 from the stack pointer.
    pub fn RET(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "RET")) impl.RET(instruction, state) else default_backend.RET(instruction, state),
        }
    }

    // 1nnn - JP addr
    // Jump to location nnn.
    // The interpreter sets the program counter to nnn.
    pub fn JP(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "JP")) impl.JP(instruction, state) else default_backend.JP(instruction, state),
        }
    }

    // 2nnn - CALL addr
    // Call subroutine at nnn.
    // The interpreter increments the stack pointer, then puts the current PC on the top of the stack. The PC is then set to nnn.
    pub fn CALL(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "CALL")) impl.CALL(instruction, state) else default_backend.CALL(instruction, state),
        }
    }

    // 3xkk - SE Vx, byte
    // Skip next instruction if Vx = kk.
    // The interpreter compares register Vx to kk, and if they are equal, increments the program counter by 2.
    pub fn SE(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "SE")) impl.SE(instruction, state) else default_backend.SE(instruction, state),
        }
    }

    // 4xkk - SNE Vx, byte
    // Skip next instruction if Vx != kk.
    // The interpreter compares register Vx to kk, and if they are not equal, increments the program counter by 2.
    pub fn SNE(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "SNE")) impl.SNE(instruction, state) else default_backend.SNE(instruction, state),
        }
    }

    // 5xy0 - SE Vx, Vy
    // Skip next instruction if Vx = Vy.
    // The interpreter compares register Vx to register Vy, and if they are equal, increments the program counter by 2.
    pub fn SEV(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "SEV")) impl.SEV(instruction, state) else default_backend.SEV(instruction, state),
        }
    }

    // 6xkk - LD Vx, byte
    // Set Vx = kk.
    // The interpreter puts the value kk into register Vx.
    pub fn LD(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "LD")) impl.LD(instruction, state) else default_backend.LD(instruction, state),
        }
    }

    // 7xkk - ADD Vx, byte
    // Set Vx = Vx + kk.
    // Adds the value kk to the value of register Vx, then stores the result in Vx.
    pub fn ADD(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "ADD")) impl.ADD(instruction, state) else default_backend.ADD(instruction, state),
        }
    }

    // 8xy0 - LD Vx, Vy
    // Set Vx = Vy.
    // Stores the value of register Vy in register Vx.
    pub fn LDV(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "LDV")) impl.LDV(instruction, state) else default_backend.LDV(instruction, state),
        }
    }

    // 8xy1 - OR Vx, Vy
    // Set Vx = Vx OR Vy.
    // Performs a bitwise OR on the values of Vx and Vy, then stores the result in Vx.
    // A bitwise OR compares the corrseponding bits from two values,
    // and if either bit is 1, then the same bit in the result is also 1. Otherwise, it is 0.
    pub fn OR(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "OR")) impl.OR(instruction, state) else default_backend.OR(instruction, state),
        }
    }

    // 8xy2 - AND Vx, Vy
    // Set Vx = Vx AND Vy.
    // Performs a bitwise AND on the values of Vx and Vy, then stores the result in Vx.
    // A bitwise AND compares the corrseponding bits from two values,
    // and if both bits are 1, then the same bit in the result is also 1. Otherwise, it is 0.
    pub fn AND(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "AND")) impl.AND(instruction, state) else default_backend.AND(instruction, state),
        }
    }

    // 8xy3 - XOR Vx, Vy
    // Set Vx = Vx XOR Vy.
    // Performs a bitwise exclusive OR on the values of Vx and Vy, then stores the result in Vx.
    // An exclusive OR compares the corrseponding bits from two values,
    // and if the bits are not both the same, then the corresponding bit in the result is set to 1. Otherwise, it is 0.
    pub fn XOR(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "XOR")) impl.XOR(instruction, state) else default_backend.XOR(instruction, state),
        }
    }

    // 8xy4 - ADD Vx, Vy
    // Set Vx = Vx + Vy, set VF = carry.
    // The values of Vx and Vy are added together.
    // If the result is greater than 8 bits (i.e., > 255,) VF is set to 1, otherwise 0.
    // Only the lowest 8 bits of the result are kept, and stored in Vx.
    pub fn ADDV(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "ADDV")) impl.ADDV(instruction, state) else default_backend.ADDV(instruction, state),
        }
    }

    // 8xy5 - SUB Vx, Vy
    // Set Vx = Vx - Vy, set VF = NOT borrow.
    // If Vx > Vy, then VF is set to 1, otherwise 0. Then Vy is subtracted from Vx, and the results stored in Vx.
    pub fn SUB(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "SUB")) impl.SUB(instruction, state) else default_backend.SUB(instruction, state),
        }
    }

    // 8xy6 - SHR Vx {, Vy}
    // Set Vx = Vx SHR 1.
    // If the least-significant bit of Vx is 1, then VF is set to 1, otherwise 0. Then Vx is divided by 2.
    // In the original interpreter, this instruction shifted Vy and stored the result in Vx.
    // In modern interpreters, it shifts Vx instead.
    pub fn SHR(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "SHR")) impl.SHR(instruction, state) else default_backend.SHR(instruction, state),
        }
    }

    // 8xy7 - SUBN Vx, Vy
    // Set Vx = Vy - Vx, set VF = NOT borrow.
    // If Vy > Vx, then VF is set to 1, otherwise 0. Then Vx is subtracted from Vy, and the results stored in Vx.
    pub fn SUBN(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "SUBN")) impl.SUBN(instruction, state) else default_backend.SUBN(instruction, state),
        }
    }

    // 8xyE - SHL Vx {, Vy}
    // Set Vx = Vx SHL 1.
    // If the most-significant bit of Vx is 1, then VF is set to 1, otherwise to 0. Then Vx is multiplied by 2.
    // In the original interpreter, this instruction shifted Vy and stored the result in Vx.
    // In modern interpreters, it shifts Vx instead.
    pub fn SHL(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "SHL")) impl.SHL(instruction, state) else default_backend.SHL(instruction, state),
        }
    }

    // 9xy0 - SNE Vx, Vy
    // Skip next instruction if Vx != Vy.
    // The values of Vx and Vy are compared, and if they are not equal, the program counter is increased by 2.
    pub fn SNEV(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "SNEV")) impl.SNEV(instruction, state) else default_backend.SNEV(instruction, state),
        }
    }

    // Annn - LD I, addr
    // Set I = nnn.
    // The value of register I is set to nnn.
    pub fn LDI(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "LDI")) impl.LDI(instruction, state) else default_backend.LDI(instruction, state),
        }
    }

    // Bnnn - JP V0, addr
    // Jump to location nnn + V0.
    // The program counter is set to nnn plus the value of V0.
    pub fn JPV(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "JPV")) impl.JPV(instruction, state) else default_backend.JPV(instruction, state),
        }
    }

    // Cxkk - RND Vx, byte
    // Set Vx = random byte AND kk.
    // The interpreter generates a random number from 0 to 255, which is then ANDed with the value kk.
    // The results are stored in Vx. See instruction 8xy2 for more information on AND.
    pub fn RND(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "RND")) impl.RND(instruction, state) else default_backend.RND(instruction, state),
        }
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
    pub fn DRW(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "DRW")) impl.DRW(instruction, state) else default_backend.DRW(instruction, state),
        }
    }

    // Ex9E - SKP Vx
    // Skip next instruction if key with the value of Vx is pressed.
    // Checks the keyboard, and if the key corresponding to the value of Vx is currently in the down position, PC is increased by 2.
    pub fn SKP(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "SKP")) impl.SKP(instruction, state) else default_backend.SKP(instruction, state),
        }
    }

    // ExA1 - SKNP Vx
    // Skip next instruction if key with the value of Vx is not pressed.
    // Checks the keyboard, and if the key corresponding to the value of Vx is currently in the up position, PC is increased by 2.
    pub fn SKNP(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "SKNP")) impl.SKNP(instruction, state) else default_backend.SKNP(instruction, state),
        }
    }

    // Fx07 - LD Vx, DT
    // Set Vx = delay timer value.
    // The value of DT is placed into Vx.
    pub fn LDVDT(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "LDVDT")) impl.LDVDT(instruction, state) else default_backend.LDVDT(instruction, state),
        }
    }

    // Fx0A - LD Vx, K
    // Wait for a key press, store the value of the key in Vx.
    // All execution stops until a key is pressed, then the value of that key is stored in Vx.
    pub fn LDK(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "LDK")) impl.LDK(instruction, state) else default_backend.LDK(instruction, state),
        }
    }

    // Returns true if the interpreter is waiting for a key to be pressed
    pub fn LDK_waiting_for_key(self: @This(), state: *State) bool {
        return switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "LDK_waiting_for_key")) impl.LDK_waiting_for_key(state) else default_backend.LDK_waiting_for_key(state),
        };
    }

    // Fx15 - LD DT, Vx
    // Set delay timer = Vx.
    // DT is set equal to the value of Vx
    pub fn LDDTV(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "LDDTV")) impl.LDDTV(instruction, state) else default_backend.LDDTV(instruction, state),
        }
    }

    // Fx18 - LD ST, Vx
    // Set sound timer = Vx.
    // ST is set equal to the value of Vx.
    pub fn LDST(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "LDST")) impl.LDST(instruction, state) else default_backend.LDST(instruction, state),
        }
    }

    // Fx1E - ADD I, Vx
    // Set I = I + Vx.
    // The values of I and Vx are added, and the results are stored in I.
    pub fn ADDI(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "ADDI")) impl.ADDI(instruction, state) else default_backend.ADDI(instruction, state),
        }
    }

    // Fx29 - LD F, Vx
    // Set I = location of sprite for digit Vx.
    // The value of I is set to the location for the hexadecimal sprite corresponding to the value of Vx.
    // See section 2.4, Display, for more information on the Chip-8 hexadecimal font.
    pub fn LDF(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "LDF")) impl.LDF(instruction, state) else default_backend.LDF(instruction, state),
        }
    }

    // Fx33 - LD B, Vx
    // Store BCD representation of Vx in memory locations I, I+1, and I+2.
    // The interpreter takes the decimal value of Vx, and places the hundreds digit in memory at location in I, the tens digit at location I+1, and the ones digit at location I+2.
    pub fn LDB(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "LDB")) impl.LDB(instruction, state) else default_backend.LDB(instruction, state),
        }
    }

    // Fx55 - LD [I], Vx
    // Store registers V0 through Vx in memory starting at location I.
    // The interpreter copies the values of registers V0 through Vx into memory, starting at the address in I.
    pub fn LDIVX(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "LDIVX")) impl.LDIVX(instruction, state) else default_backend.LDIVX(instruction, state),
        }
    }

    // Fx65 - LD Vx, [I]
    // Read registers V0 through Vx from memory starting at location I.
    // The interpreter reads values from memory starting at location I into registers V0 through Vx.
    pub fn LDVXI(self: @This(), instruction: u16, state: *State) void {
        switch (self) {
            inline else => |impl| if (@hasDecl(@TypeOf(impl), "LDVXI")) impl.LDVXI(instruction, state) else default_backend.LDVXI(instruction, state),
        }
    }
};

// For instruction in format PNNN returns NNN
pub fn pnnn(instruction: u16) u16 {
    return instruction & 0xFFF;
}

// For instruction in format PXKK returns X and KK
pub fn pxkk(instruction: u16) struct { x: usize, kk: u8 } {
    return .{
        .x = (instruction & 0x0F00) >> 8,
        .kk = @intCast(instruction & 0xFF),
    };
}

// For instruction in format PXY0 return X and Y
pub fn pxy0(instruction: u16) struct { x: usize, y: usize } {
    return .{ .x = (instruction & 0x0F00) >> 8, .y = (instruction & 0x00F0) >> 4 };
}

// For instruction in format PX00 return X
pub fn px00(instruction: u16) u4 {
    return @intCast((instruction & 0x0F00) >> 8);
}

test "helper functions" {
    const std = @import("std");
    const expectEqual = std.testing.expectEqual;

    try expectEqual(0x123, pnnn(0xA123));
    const result1 = pxkk(0xA123);
    try expectEqual(1, result1.x);
    try expectEqual(0x23, result1.kk);
    const result2 = pxy0(0xA123);
    try expectEqual(1, result2.x);
    try expectEqual(2, result2.y);
    try expectEqual(1, px00(0xA123));
}
