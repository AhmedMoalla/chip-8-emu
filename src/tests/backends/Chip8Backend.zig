const std = @import("std");
const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

const State = @import("../../State.zig");
const interpreter = @import("../../interpreter.zig");

const Backend = @import("../../backends/Backend.zig").Backend;
const Chip8Backend = @import("../../backends/Chip8Backend.zig");

const instance: Backend = .{ .chip8 = Chip8Backend{} };

test "CLS" {
    var state = State{};
    state.display[100] = 1;
    interpreter.execute(instance, 0x00E0, &state);
    try expectEqual(0, state.display[100]);
}

test "RET" {
    var state = State{ .sp = 2 };
    state.stack[0] = 0x1;
    state.stack[1] = 0xBEEF;
    state.stack[2] = 0x2;

    interpreter.execute(instance, 0x00EE, &state);
    try expectEqual(1, state.sp);
    try expectEqual(state.stack[1] + State.instruction_size, state.pc);
}

test "JP" {
    var state = State{};
    interpreter.execute(instance, 0x1005, &state);
    try expectEqual(5, state.pc);
}

test "CALL" {
    var state = State{};
    state.pc = 0x234;
    interpreter.execute(instance, 0x2123, &state);
    try expectEqual(0x234, state.stack[state.sp - 1]);
    try expectEqual(1, state.sp);
    try expectEqual(0x123, state.pc);
}
test "SE" {
    var state = State{};
    const initial_pc = state.pc;
    state.V[1] = 0x23;
    interpreter.execute(instance, 0x3123, &state);
    try expectEqual(initial_pc + (2 * State.instruction_size), state.pc);
}

test "SNE" {
    var state = State{};
    const initial_pc = state.pc;
    state.V[1] = 0x24;
    interpreter.execute(instance, 0x4123, &state);
    try expectEqual(initial_pc + (2 * State.instruction_size), state.pc);
}

test "SEV" {
    var state = State{};
    const initial_pc = state.pc;
    state.V[1] = 0x24;
    state.V[2] = state.V[1];
    interpreter.execute(instance, 0x5120, &state);
    try expectEqual(initial_pc + (2 * State.instruction_size), state.pc);
}

test "LD" {
    var state = State{};
    interpreter.execute(instance, 0x6123, &state);
    try expectEqual(0x23, state.V[1]);
}

test "ADD" {
    var state = State{};
    const initial_value = 5;
    state.V[1] = initial_value;
    interpreter.execute(instance, 0x7123, &state);
    try expectEqual(initial_value + 0x23, state.V[1]);

    // Overflow should wrap
    state.V[1] = 255;
    interpreter.execute(instance, 0x7102, &state);
    try expectEqual(1, state.V[1]);
}

test "LDV" {
    var state = State{};
    state.V[2] = 10;
    interpreter.execute(instance, 0x8120, &state);
    try expectEqual(state.V[2], state.V[1]);
}

test "OR" {
    var state = State{};
    const initial_value = 5;
    state.V[0xA] = initial_value;
    state.V[0xD] = 9;
    state.V[0xF] = 4;
    interpreter.execute(instance, 0x8AD1, &state);
    try expectEqual(initial_value | state.V[0xD], state.V[0xA]);
    try expectEqual(0, state.V[0xF]); // https://chip8.gulrak.net/#quirk5
}

test "AND" {
    var state = State{};
    const initial_value = 5;
    state.V[0xA] = initial_value;
    state.V[0xD] = 9;
    state.V[0xF] = 4;
    interpreter.execute(instance, 0x8AD2, &state);
    try expectEqual(initial_value & state.V[0xD], state.V[0xA]);
    try expectEqual(0, state.V[0xF]); // https://chip8.gulrak.net/#quirk5
}

test "XOR" {
    var state = State{};
    const initial_value = 5;
    state.V[0xA] = initial_value;
    state.V[0xD] = 9;
    state.V[0xF] = 4;
    interpreter.execute(instance, 0x8AD3, &state);
    try expectEqual(initial_value ^ state.V[0xD], state.V[0xA]);
    try expectEqual(0, state.V[0xF]); // https://chip8.gulrak.net/#quirk5
}

test "ADDV" {
    var state = State{};
    state.V[0xA] = 255;
    state.V[0xD] = 1;
    interpreter.execute(instance, 0x8AD4, &state);
    try expectEqual(0, state.V[0xA]);
    try expectEqual(1, state.V[0xF]);

    state.V[0xA] = 100;
    state.V[0xD] = 1;
    interpreter.execute(instance, 0x8AD4, &state);
    try expectEqual(101, state.V[0xA]);
    try expectEqual(0, state.V[0xF]);
}

test "SUB" {
    var state = State{};
    state.V[0xA] = 100;
    state.V[0xD] = 1;
    interpreter.execute(instance, 0x8AD5, &state);
    try expectEqual(99, state.V[0xA]);
    try expectEqual(1, state.V[0xF]);

    state.V[0xA] = 20;
    state.V[0xD] = 80;
    interpreter.execute(instance, 0x8AD5, &state);
    try expectEqual(196, state.V[0xA]);
    try expectEqual(0, state.V[0xF]);
}

test "SHR" {
    var state = State{};
    state.V[0xA] = 241;
    state.V[0xD] = 123;
    interpreter.execute(instance, 0x8AD6, &state);
    try expectEqual(state.V[0xD] >> 1, state.V[0xA]);
    try expectEqual(1, state.V[0xF]);

    state.V[0xA] = 240;
    state.V[0xD] = 0xF;
    interpreter.execute(instance, 0x8AD6, &state);
    try expectEqual(state.V[0xD] >> 1, state.V[0xA]);
    try expectEqual(0, state.V[0xF]);
}

test "SUBN" {
    var state = State{};
    state.V[0xA] = 1;
    state.V[0xD] = 100;
    interpreter.execute(instance, 0x8AD7, &state);
    try expectEqual(99, state.V[0xA]);
    try expectEqual(1, state.V[0xF]);

    state.V[0xA] = 80;
    state.V[0xD] = 20;
    interpreter.execute(instance, 0x8AD7, &state);
    try expectEqual(196, state.V[0xA]);
    try expectEqual(0, state.V[0xF]);
}

test "SHL" {
    var state = State{};
    state.V[0xA] = 240;
    state.V[0xD] = 123;
    interpreter.execute(instance, 0x8ADE, &state);
    try expectEqual(state.V[0xD] << 1, state.V[0xA]);
    try expectEqual(1, state.V[0xF]);

    state.V[0xA] = 1;
    state.V[0xD] = 123;
    interpreter.execute(instance, 0x8ADE, &state);
    try expectEqual(state.V[0xD] << 1, state.V[0xA]);
    try expectEqual(0, state.V[0xF]);
}

test "SNEV" {
    var state = State{};
    const initial_pc = state.pc;
    state.V[0xA] = 0x24;
    state.V[0xB] = 0x25;
    interpreter.execute(instance, 0x9AB0, &state);
    try expectEqual(initial_pc + (2 * State.instruction_size), state.pc);
}

test "LDI" {
    var state = State{};
    interpreter.execute(instance, 0xA123, &state);
    try expectEqual(0x123, state.I);
}

test "JPV" {
    var state = State{};
    state.V[0] = 5;
    interpreter.execute(instance, 0xB023, &state);
    try expectEqual(@as(u16, 0x23) + state.V[0], state.pc);
}

test "RND" {
    var state = State{
        .prng = rnd: {
            var prng = std.Random.DefaultPrng.init(0x12fe3dab36);
            break :rnd prng.random();
        },
    };
    interpreter.execute(instance, 0xCA12, &state);
    const seed_first_random_value: u8 = 169;
    try expectEqual(seed_first_random_value & 0x12, state.V[0xA]);
}

pub fn makeSprite(state: *State, bytes: []const u8) void {
    @memcpy(state.memory[state.I..][0..bytes.len], bytes);
}

test "DRW: normal draw within screen, no wrapping or clipping" {
    var state = State{};
    state.I = 0;
    state.V[0] = 10; // X
    state.V[1] = 5; // Y
    makeSprite(&state, &.{0b11110000});
    interpreter.execute(instance, 0xD011, &state);

    try expect(state.display[5 * 64 + 10] == 1);
    try expect(state.display[5 * 64 + 13] == 1);
    try expect(state.V[0xF] == 0);
}

test "DRW: pixels beyond right edge are clipped (no wrapping)" {
    var state = State{};
    state.I = 0;
    state.V[0] = 62; // starts near right edge
    state.V[1] = 0;
    makeSprite(&state, &.{0b11111111});
    interpreter.execute(instance, 0xD011, &state);

    // pixels at x=62 and 63 are drawn, rest clipped
    try expect(state.display[0 * 64 + 62] == 1);
    try expect(state.display[0 * 64 + 63] == 1);
    // ensure wrap did NOT occur
    try expect(state.display[0 * 64 + 0] == 0);
}

test "DRW: sprite rows beyond bottom edge are clipped (no wrapping)" {
    var state = State{};
    state.I = 0;
    state.V[0] = 0;
    state.V[1] = 31; // bottom-most visible row
    makeSprite(&state, &.{ 0xFF, 0xFF }); // height 2, one row should clip
    interpreter.execute(instance, 0xD012, &state);

    // First row visible (y=31)
    for (0..8) |x| {
        try expect(state.display[31 * 64 + x] == 1);
    }

    // Rest of that row (x ≥ 8) should be 0
    for (8..64) |x| {
        try expect(state.display[31 * 64 + x] == 0);
    }

    // Second sprite row is clipped (off-screen)
    // Confirm that no pixels in wrapped area are drawn
    for (0..64) |x| {
        try expect(state.display[x] == 0);
    }
}

test "DRW: coordinates wrap but sprite clips" {
    var state = State{};
    state.I = 0;
    state.V[0] = 64; // wraps to x=0
    state.V[1] = 32; // wraps to y=0
    makeSprite(&state, &.{0b11110000});
    interpreter.execute(instance, 0xD011, &state);

    // effectively drawn at top-left corner
    try expect(state.display[0 * 64 + 0] == 1);
    try expect(state.display[0 * 64 + 3] == 1);
    try expect(state.V[0xF] == 0);
}

test "DRW: collision sets VF to 1 when pixel erased" {
    var state = State{};
    state.I = 0;
    state.V[0] = 0;
    state.V[1] = 0;
    makeSprite(&state, &.{0b11110000});
    interpreter.execute(instance, 0xD011, &state); // draw once
    interpreter.execute(instance, 0xD011, &state); // draw again (should erase same pixels)
    try expectEqual(@as(u8, 1), state.V[0xF]);
}

test "DRW: entirely off-screen sprite (coordinates wrap) draws correctly" {
    var state = State{};
    state.I = 0;
    state.V[0] = 128; // wraps twice -> 0
    state.V[1] = 64; // wraps twice -> 0
    makeSprite(&state, &.{0b10000000});
    interpreter.execute(instance, 0xD011, &state);
    try expect(state.display[0] == 1);
}

test "SKP" {
    var state = State{};
    const initial_pc = state.pc;
    state.keys[5] = true;
    state.V[0xA] = 5;
    interpreter.execute(instance, 0xEA9E, &state);
    var next_pc_value = initial_pc + (State.instruction_size * 2);
    try expectEqual(next_pc_value, state.pc);

    state.keys[5] = false;
    state.V[0xA] = 5;
    interpreter.execute(instance, 0xEA9E, &state);
    next_pc_value += State.instruction_size;
    try expectEqual(next_pc_value, state.pc);
}

test "SKNP" {
    var state = State{};
    const initial_pc = state.pc;
    state.keys[5] = false;
    state.V[0xA] = 5;
    interpreter.execute(instance, 0xEAA1, &state);
    var next_pc_value = initial_pc + (State.instruction_size * 2);

    try expectEqual(next_pc_value, state.pc);

    state.keys[5] = true;
    state.V[0xA] = 5;
    interpreter.execute(instance, 0xEAA1, &state);
    next_pc_value += State.instruction_size;
    try expectEqual(next_pc_value, state.pc);
}

test "LDVDT" {
    var state = State{};
    state.delay_timer = 0x12;
    interpreter.execute(instance, 0xFB07, &state);
    try expectEqual(state.delay_timer, state.V[0xB]);
}

test "LDK" {
    var state = State{};
    const initial_pc = state.pc;
    interpreter.execute(instance, 0xF50A, &state);
    interpreter.execute(instance, 0xA123, &state); // LDI

    // Nothing should have changed as execute becomes no-op when waiting for key to be pressed
    try expectEqual(initial_pc, state.pc);

    // Press key 'A'
    state.keys[0xA] = true;

    interpreter.execute(instance, 0xA123, &state); // LDI
    // Nothing should have changed as execute becomes no-op when waiting for key to be released
    try expectEqual(initial_pc, state.pc);

    // Release key 'A'
    state.keys[0xA] = false;

    // Execution resumed and LDK should finish executing
    interpreter.execute(instance, 0xA123, &state); // LDI
    try expectEqual(initial_pc + State.instruction_size, state.pc);

    // Execution resumed and pc should advance
    interpreter.execute(instance, 0xA123, &state); // LDI
    try expectEqual(initial_pc + (State.instruction_size * 2), state.pc);

    // Key is stored in register
    try expectEqual(0xA, state.V[5]);
}

test "LDK_waiting_for_key" {
    var state = State{};

    const initial_pc = state.pc;
    // By default we are not waiting
    try std.testing.expect(!instance.LDK_waiting_for_key(&state));

    // After calling LDK we are waiting
    interpreter.execute(instance, 0xF50A, &state);
    try std.testing.expect(instance.LDK_waiting_for_key(&state));

    // After pressing a key we are waiting for it to be released
    state.keys[0xA] = true;
    try std.testing.expect(instance.LDK_waiting_for_key(&state));

    // Key is released we are still waiting for 1 more cycle
    state.keys[0xA] = false;
    try std.testing.expect(instance.LDK_waiting_for_key(&state));

    // We are no longer waiting and we should store key in register Vx
    try std.testing.expect(!instance.LDK_waiting_for_key(&state));
    try expectEqual(0xA, state.V[5]);
    try expectEqual(null, state.register_waiting_for_key);
    try expectEqual(initial_pc + State.instruction_size, state.pc);
}

test "LDDTV" {
    var state = State{};
    state.V[0xB] = 0x13;
    interpreter.execute(instance, 0xFB15, &state);
    try expectEqual(state.V[0xB], state.delay_timer);

    state.V[0xA] = 0x15;
    interpreter.execute(instance, 0xFA15, &state);
    try expectEqual(state.V[0xA], state.delay_timer);
}

test "LDST" {
    var state = State{};
    state.V[0xB] = 0x13;
    interpreter.execute(instance, 0xFB18, &state);
    try expectEqual(state.V[0xB], state.sound_timer);

    state.V[0xA] = 0x20;
    interpreter.execute(instance, 0xFA18, &state);
    try expectEqual(state.V[0xA], state.sound_timer);
}

test "ADDI" {
    var state = State{};
    state.I = 5;
    state.V[0xC] = 5;
    interpreter.execute(instance, 0xFC1E, &state);
    try expectEqual(10, state.I);
}

test "LDF" {
    var state = State{};
    state.V[0xC] = 5;
    interpreter.execute(instance, 0xFC29, &state);
    try expectEqual(state.V[0xC] * State.default_sprites_height, state.I);
}

test "LDB" {
    var state = State{};
    state.I = 50;
    state.V[0xC] = 123;
    interpreter.execute(instance, 0xFC33, &state);
    try expectEqual(1, state.memory[state.I]);
    try expectEqual(2, state.memory[state.I + 1]);
    try expectEqual(3, state.memory[state.I + 2]);
}

test "LDIVX" {
    var state = State{};
    const initial_I = state.I;
    for (0..0xF + 1) |i| {
        state.V[i] = @intCast(i);
    }
    interpreter.execute(instance, 0xFF55, &state);
    for (0..0xF + 1) |i| {
        const asu8: u8 = @intCast(i);
        try expectEqual(asu8, state.memory[initial_I + i]);
    }
    try expectEqual(initial_I + 0xF + 1, state.I);
}

test "LDVXI" {
    var state = State{};
    const initial_I = state.I;
    for (0..0xF + 1) |i| {
        state.memory[state.I + i] = @intCast(i);
    }
    interpreter.execute(instance, 0xFF65, &state);
    for (0..0xF + 1) |i| {
        const asu8: u8 = @intCast(i);
        try expectEqual(asu8, state.V[i]);
    }
    try expectEqual(initial_I + 0xF + 1, state.I);
}
