const std = @import("std");
const State = @import("../State.zig");
const Backend = @import("Backend.zig");

const pnnn = Backend.pnnn;
const pxkk = Backend.pxkk;
const pxy0 = Backend.pxy0;
const px00 = Backend.px00;

const log = std.log.scoped(.bchip8);

// 0nnn - SYS addr
// Jump to a machine code routine at nnn.
// This instruction is only used on the old computers on which Chip-8 was originally implemented. It is ignored by modern interpreters.
pub fn SYS(_: @This(), instruction: u16, state: *State) void {
    const nnn = pnnn(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SYS NNN={X:0>3}", .{ state.pc, instruction, nnn });
    state.pc += State.instruction_size;
}

// 00E0 - CLS
// Clear the display.
pub fn CLS(_: @This(), instruction: u16, state: *State) void {
    log.debug("[0x{X:0>4}] {X:0>4} CLS", .{ state.pc, instruction });
    @memset(&state.display, 0);
    state.pc += State.instruction_size;
}

// 00EE - RET
// Return from a subroutine.
// The interpreter sets the program counter to the address at the top of the stack, then subtracts 1 from the stack pointer.
pub fn RET(_: @This(), instruction: u16, state: *State) void {
    log.debug("[0x{X:0>4}] {X:0>4} RET", .{ state.pc, instruction });
    state.sp -= 1;
    state.pc = state.stack[state.sp];
    state.pc += State.instruction_size;
}

// 1nnn - JP addr
// Jump to location nnn.
// The interpreter sets the program counter to nnn.
pub fn JP(_: @This(), instruction: u16, state: *State) void {
    const nnn = pnnn(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} JP NNN={X:0>3}", .{ state.pc, instruction, nnn });
    state.pc = nnn;
}

// 2nnn - CALL addr
// Call subroutine at nnn.
// The interpreter increments the stack pointer, then puts the current PC on the top of the stack. The PC is then set to nnn.
pub fn CALL(_: @This(), instruction: u16, state: *State) void {
    const nnn = pnnn(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} CALL NNN={X:0>3}", .{ state.pc, instruction, nnn });
    state.stack[state.sp] = state.pc;
    state.sp += 1;
    state.pc = nnn;
}

// 3xkk - SE Vx, byte
// Skip next instruction if Vx = kk.
// The interpreter compares register Vx to kk, and if they are equal, increments the program counter by 2.
pub fn SE(_: @This(), instruction: u16, state: *State) void {
    const instr = pxkk(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SE X={X} KK={X:0>2}", .{ state.pc, instruction, instr.x, instr.kk });
    if (state.V[instr.x] == instr.kk) {
        state.pc += (2 * State.instruction_size);
    } else {
        state.pc += State.instruction_size;
    }
}

// 4xkk - SNE Vx, byte
// Skip next instruction if Vx != kk.
// The interpreter compares register Vx to kk, and if they are not equal, increments the program counter by 2.
pub fn SNE(_: @This(), instruction: u16, state: *State) void {
    const instr = pxkk(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SNE X={X} KK={X:0>2}", .{ state.pc, instruction, instr.x, instr.kk });
    if (state.V[instr.x] != instr.kk) {
        state.pc += (2 * State.instruction_size);
    } else {
        state.pc += State.instruction_size;
    }
}

// 5xy0 - SE Vx, Vy
// Skip next instruction if Vx = Vy.
// The interpreter compares register Vx to register Vy, and if they are equal, increments the program counter by 2.
pub fn SEV(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SEV X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    if (state.V[instr.x] == state.V[instr.y]) {
        state.pc += (2 * State.instruction_size);
    } else {
        state.pc += State.instruction_size;
    }
}

// 6xkk - LD Vx, byte
// Set Vx = kk.
// The interpreter puts the value kk into register Vx.
pub fn LD(_: @This(), instruction: u16, state: *State) void {
    const instr = pxkk(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LD X={X} KK={X:0>2}", .{ state.pc, instruction, instr.x, instr.kk });
    state.V[instr.x] = instr.kk;
    state.pc += State.instruction_size;
}

// 7xkk - ADD Vx, byte
// Set Vx = Vx + kk.
// Adds the value kk to the value of register Vx, then stores the result in Vx.
pub fn ADD(_: @This(), instruction: u16, state: *State) void {
    const instr = pxkk(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} ADD X={X} KK={X:0>2}", .{ state.pc, instruction, instr.x, instr.kk });
    state.V[instr.x] = @addWithOverflow(state.V[instr.x], instr.kk).@"0";
    state.pc += State.instruction_size;
}

// 8xy0 - LD Vx, Vy
// Set Vx = Vy.
// Stores the value of register Vy in register Vx.
pub fn LDV(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDV X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    state.V[instr.x] = state.V[instr.y];
    state.pc += State.instruction_size;
}

// 8xy1 - OR Vx, Vy
// Set Vx = Vx OR Vy.
// Performs a bitwise OR on the values of Vx and Vy, then stores the result in Vx.
// A bitwise OR compares the corrseponding bits from two values,
// and if either bit is 1, then the same bit in the result is also 1. Otherwise, it is 0.
pub fn OR(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} OR X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    state.V[instr.x] |= state.V[instr.y];
    state.pc += State.instruction_size;
    state.V[0xF] = 0;
}

// 8xy2 - AND Vx, Vy
// Set Vx = Vx AND Vy.
// Performs a bitwise AND on the values of Vx and Vy, then stores the result in Vx.
// A bitwise AND compares the corrseponding bits from two values,
// and if both bits are 1, then the same bit in the result is also 1. Otherwise, it is 0.
pub fn AND(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} AND X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    state.V[instr.x] &= state.V[instr.y];
    state.pc += State.instruction_size;
    state.V[0xF] = 0;
}

// 8xy3 - XOR Vx, Vy
// Set Vx = Vx XOR Vy.
// Performs a bitwise exclusive OR on the values of Vx and Vy, then stores the result in Vx.
// An exclusive OR compares the corrseponding bits from two values,
// and if the bits are not both the same, then the corresponding bit in the result is set to 1. Otherwise, it is 0.
pub fn XOR(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} XOR X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    state.V[instr.x] ^= state.V[instr.y];
    state.pc += State.instruction_size;
    state.V[0xF] = 0;
}

// 8xy4 - ADD Vx, Vy
// Set Vx = Vx + Vy, set VF = carry.
// The values of Vx and Vy are added together.
// If the result is greater than 8 bits (i.e., > 255,) VF is set to 1, otherwise 0.
// Only the lowest 8 bits of the result are kept, and stored in Vx.
pub fn ADDV(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} ADDV X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    const result = @addWithOverflow(state.V[instr.x], state.V[instr.y]);
    state.V[instr.x] = result.@"0";
    state.V[0xF] = result.@"1";
    state.pc += State.instruction_size;
}

// 8xy5 - SUB Vx, Vy
// Set Vx = Vx - Vy, set VF = NOT borrow.
// If Vx > Vy, then VF is set to 1, otherwise 0. Then Vy is subtracted from Vx, and the results stored in Vx.
pub fn SUB(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SUB X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    const borrow: u8 = if (state.V[instr.x] >= state.V[instr.y]) 1 else 0;
    state.V[instr.x] = @subWithOverflow(state.V[instr.x], state.V[instr.y]).@"0";
    state.pc += State.instruction_size;
    state.V[0xF] = borrow;
}

// 8xy6 - SHR Vx {, Vy}
// Set Vx = Vx SHR 1.
// If the least-significant bit of Vx is 1, then VF is set to 1, otherwise 0. Then Vx is divided by 2.
// In the original interpreter, this instruction shifted Vy and stored the result in Vx.
// In modern interpreters, it shifts Vx instead.
pub fn SHR(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SHR X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    const carry: u8 = state.V[instr.x] & 0x1;
    state.V[instr.x] = state.V[instr.y] >> 1;
    state.pc += State.instruction_size;
    state.V[0xF] = carry;
}

// 8xy7 - SUBN Vx, Vy
// Set Vx = Vy - Vx, set VF = NOT borrow.
// If Vy > Vx, then VF is set to 1, otherwise 0. Then Vx is subtracted from Vy, and the results stored in Vx.
pub fn SUBN(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SUBN X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    const borrow: u8 = if (state.V[instr.y] >= state.V[instr.x]) 1 else 0;
    state.V[instr.x] = @subWithOverflow(state.V[instr.y], state.V[instr.x]).@"0";
    state.pc += State.instruction_size;
    state.V[0xF] = borrow;
}

// 8xyE - SHL Vx {, Vy}
// Set Vx = Vx SHL 1.
// If the most-significant bit of Vx is 1, then VF is set to 1, otherwise to 0. Then Vx is multiplied by 2.
// In the original interpreter, this instruction shifted Vy and stored the result in Vx.
// In modern interpreters, it shifts Vx instead.
pub fn SHL(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SHL X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    const carry: u8 = (state.V[instr.x] >> 7) & 0x1;
    state.V[instr.x] = state.V[instr.y] << 1;
    state.pc += State.instruction_size;
    state.V[0xF] = carry;
}

// 9xy0 - SNE Vx, Vy
// Skip next instruction if Vx != Vy.
// The values of Vx and Vy are compared, and if they are not equal, the program counter is increased by 2.
pub fn SNEV(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SNEV X={X} Y={X}", .{ state.pc, instruction, instr.x, instr.y });
    if (state.V[instr.x] != state.V[instr.y]) {
        state.pc += (2 * State.instruction_size);
    } else {
        state.pc += State.instruction_size;
    }
}

// Annn - LD I, addr
// Set I = nnn.
// The value of register I is set to nnn.
pub fn LDI(_: @This(), instruction: u16, state: *State) void {
    const nnn = pnnn(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDI NNN={X:0>3}", .{ state.pc, instruction, nnn });
    state.I = nnn;
    state.pc += State.instruction_size;
}

// Bnnn - JP V0, addr
// Jump to location nnn + V0.
// The program counter is set to nnn plus the value of V0.
pub fn JPV(_: @This(), instruction: u16, state: *State) void {
    const nnn = pnnn(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} JPV NNN={X:0>3}", .{ state.pc, instruction, nnn });
    state.pc = nnn + state.V[0];
}

// Cxkk - RND Vx, byte
// Set Vx = random byte AND kk.
// The interpreter generates a random number from 0 to 255, which is then ANDed with the value kk.
// The results are stored in Vx. See instruction 8xy2 for more information on AND.
pub fn RND(_: @This(), instruction: u16, state: *State) void {
    const instr = pxkk(instruction);
    const random_byte = state.prng.int(u8);
    log.debug("[0x{X:0>4}] {X:0>4} RND X={X} KK={X:0>2} RND={X}", .{ state.pc, instruction, instr.x, instr.kk, random_byte });
    state.V[instr.x] = random_byte & instr.kk;
    state.pc += State.instruction_size;
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
pub fn DRW(_: @This(), instruction: u16, state: *State) void {
    const instr = pxy0(instruction);
    const n = @as(usize, instruction & 0x000F);
    log.debug("[0x{X:0>4}] {X:0>4} DRW X={X} Y={X} N={X}", .{ state.pc, instruction, instr.x, instr.y, n });

    const sprite_bytes = state.memory[state.I .. state.I + n];

    const start_x = @as(usize, state.V[instr.x]) % State.display_width;
    const start_y = @as(usize, state.V[instr.y]) % State.display_height;

    state.V[0xF] = 0;

    for (sprite_bytes, 0..) |sprite_byte, row| {
        const y = start_y + row;
        if (y >= State.display_height)
            break; // sprite rows beyond screen bottom are clipped

        for (0..8) |bit_idx| {
            const x = start_x + bit_idx;
            if (x >= State.display_width)
                break; // pixels beyond right edge are clipped

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

// Ex9E - SKP Vx
// Skip next instruction if key with the value of Vx is pressed.
// Checks the keyboard, and if the key corresponding to the value of Vx is currently in the down position, PC is increased by 2.
pub fn SKP(_: @This(), instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SKP X={X}", .{ state.pc, instruction, x });
    const key = state.V[x];
    if (state.keys[key]) {
        state.pc += (State.instruction_size * 2);
    } else {
        state.pc += State.instruction_size;
    }
}

// ExA1 - SKNP Vx
// Skip next instruction if key with the value of Vx is not pressed.
// Checks the keyboard, and if the key corresponding to the value of Vx is currently in the up position, PC is increased by 2.
pub fn SKNP(_: @This(), instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} SKNP X={X}", .{ state.pc, instruction, x });
    const key = state.V[x];
    if (!state.keys[key]) {
        state.pc += (State.instruction_size * 2);
    } else {
        state.pc += State.instruction_size;
    }
}

// Fx07 - LD Vx, DT
// Set Vx = delay timer value.
// The value of DT is placed into Vx.
pub fn LDVDT(_: @This(), instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDVDT X={X}", .{ state.pc, instruction, x });
    state.V[x] = state.delay_timer;
    state.pc += State.instruction_size;
}

// Fx0A - LD Vx, K
// Wait for a key press, store the value of the key in Vx.
// All execution stops until a key is pressed, then the value of that key is stored in Vx.
pub fn LDK(_: @This(), instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDK X={X}", .{ state.pc, instruction, x });
    state.register_waiting_for_key = x;
    state.key_pressed = null;
}

// Returns true if the interpreter is waiting for a key to be pressed
pub fn LDK_waiting_for_key(_: @This(), state: *State) bool {
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

// Fx15 - LD DT, Vx
// Set delay timer = Vx.
// DT is set equal to the value of Vx
pub fn LDDTV(_: @This(), instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDDTV X={X}", .{ state.pc, instruction, x });
    state.delay_timer = state.V[x];
    state.pc += State.instruction_size;
}

// Fx18 - LD ST, Vx
// Set sound timer = Vx.
// ST is set equal to the value of Vx.
pub fn LDST(_: @This(), instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDST X={X}", .{ state.pc, instruction, x });
    state.sound_timer = state.V[x];
    state.pc += State.instruction_size;
}

// Fx1E - ADD I, Vx
// Set I = I + Vx.
// The values of I and Vx are added, and the results are stored in I.
pub fn ADDI(_: @This(), instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} ADDI X={X}", .{ state.pc, instruction, x });
    state.I = state.I + state.V[x];
    state.pc += State.instruction_size;
}

// Fx29 - LD F, Vx
// Set I = location of sprite for digit Vx.
// The value of I is set to the location for the hexadecimal sprite corresponding to the value of Vx.
// See section 2.4, Display, for more information on the Chip-8 hexadecimal font.
pub fn LDF(_: @This(), instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDF X={X}", .{ state.pc, instruction, x });
    const sprite_number = state.V[x];
    state.I = sprite_number * State.default_sprites_height;
    state.pc += State.instruction_size;
}

// Fx33 - LD B, Vx
// Store BCD representation of Vx in memory locations I, I+1, and I+2.
// The interpreter takes the decimal value of Vx, and places the hundreds digit in memory at location in I, the tens digit at location I+1, and the ones digit at location I+2.
pub fn LDB(_: @This(), instruction: u16, state: *State) void {
    const x = px00(instruction);
    log.debug("[0x{X:0>4}] {X:0>4} LDB X={X}", .{ state.pc, instruction, x });
    state.memory[state.I] = state.V[x] / 100;
    state.memory[state.I + 1] = (state.V[x] / 10) % 10;
    state.memory[state.I + 2] = state.V[x] % 10;
    state.pc += State.instruction_size;
}

// Fx55 - LD [I], Vx
// Store registers V0 through Vx in memory starting at location I.
// The interpreter copies the values of registers V0 through Vx into memory, starting at the address in I.
pub fn LDIVX(_: @This(), instruction: u16, state: *State) void {
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

// Fx65 - LD Vx, [I]
// Read registers V0 through Vx from memory starting at location I.
// The interpreter reads values from memory starting at location I into registers V0 through Vx.
pub fn LDVXI(_: @This(), instruction: u16, state: *State) void {
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
