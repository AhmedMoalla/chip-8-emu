const std = @import("std");
const State = @import("State.zig");
const instr = @import("instructions.zig");
const debug = @import("debug.zig");
const rl = @import("raylib");

pub const std_options: std.Options = .{
    // Set the log level to info
    .log_level = .info,
};

pub fn main() !void {
    const args = parseArgs();

    var state = try State.init(args.rom_path);
    // while (state.pc < State.rom_loading_location + state.rom_size) {
    //     const instruction = (@as(u16, state.memory[state.pc]) << 8) | state.memory[state.pc + 1];
    //     instr.execute(instruction, &state);
    //     if (state.should_draw) {
    //         std.debug.print("\x1B[2J\x1B[H", .{});
    //         debug.printDisplay(&state.display);
    //         // debug.print(state, .{ .registers = true, .memory = true, .stack = true });
    //     }
    // }
    const scale = 8;
    const screen_width = State.display_width * scale;
    const screen_height = State.display_height * scale;

    rl.initWindow(screen_width, screen_height, "Chip-8 Emulator");
    defer rl.closeWindow();

    rl.setTargetFPS(60);

    var pixels: [State.display_width * State.display_height * 3]u8 = undefined;
    const image = rl.Image{
        .data = &pixels,
        .width = State.display_width, // Changed from screen_width
        .height = State.display_height, // Changed from screen_height
        .mipmaps = 1,
        .format = rl.PixelFormat.uncompressed_r8g8b8,
    };
    const texture = try rl.loadTextureFromImage(image);
    defer rl.unloadTexture(texture);

    const zero = rl.Vector2.zero();

    while (!rl.windowShouldClose()) {
        const instruction = (@as(u16, state.memory[state.pc]) << 8) | state.memory[state.pc + 1];
        instr.execute(instruction, &state);

        drw: {
            if (!state.should_draw) break :drw;
            rl.beginDrawing();
            defer rl.endDrawing();

            for (state.display, 0..) |pixel, i| {
                const value: u8 = if (pixel == 1) 255 else 0;
                pixels[i * 3 + 0] = value; // R
                pixels[i * 3 + 1] = value; // G
                pixels[i * 3 + 2] = value; // B
            }

            rl.updateTexture(texture, &pixels);
            rl.clearBackground(rl.Color.black);
            rl.drawTextureEx(texture, zero, 0, scale, rl.Color.white);
        }
    }
}

const Args = struct {
    rom_path: []const u8,
};

fn parseArgs() Args {
    var args = std.process.args();
    defer args.deinit();
    _ = args.skip(); // Program name
    const rom_path = args.next();
    if (rom_path == null) {
        std.log.err("One argument is required which is the rom path", .{});
        std.process.exit(1);
    }
    return Args{ .rom_path = rom_path.? };
}

test {
    _ = @import("instructions.zig");
}
