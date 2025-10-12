const std = @import("std");
const State = @import("State.zig");

pub fn FrontendOptions(kind: Frontend.Kind) type {
    return switch (kind) {
        .console => struct {},
        .raylib => struct {
            scale: f32 = 8,
            target_fps: u32 = 60,
            allocator: std.mem.Allocator,
        },
    };
}

pub const Frontend = union(enum) {
    console: ConsoleFrontend,
    raylib: RaylibFrontend,

    pub const Kind = @typeInfo(Frontend).@"union".tag_type.?;

    pub fn init(comptime kind: Frontend.Kind, opts: FrontendOptions(kind)) !@This() {
        return switch (kind) {
            .console => .{ .console = ConsoleFrontend{} },
            .raylib => .{ .raylib = try RaylibFrontend.init(opts) },
        };
    }

    pub fn deinit(self: @This()) void {
        return switch (self) {
            inline else => |impl| {
                if (@hasDecl(@TypeOf(impl), "deinit")) {
                    impl.deinit();
                }
            },
        };
    }

    pub fn shouldStop(self: @This()) bool {
        return switch (self) {
            inline else => |impl| return impl.shouldStop(),
        };
    }

    pub fn draw(self: *@This(), display: [State.display_resolution]u8) void {
        switch (self.*) {
            .console => |*impl| impl.draw(display),
            .raylib => |*impl| impl.draw(display),
        }
    }

    pub fn setKeys(self: *@This(), keys: []bool) void {
        switch (self.*) {
            .console => |*impl| impl.setKeys(keys),
            .raylib => |*impl| impl.setKeys(keys),
        }
    }
};

const ConsoleFrontend = struct {
    pub fn shouldStop(_: @This()) bool {
        return false;
    }

    pub fn draw(_: *@This(), display: [State.display_resolution]u8) void {
        std.debug.print("\x1B[2J\x1B[H", .{});
        for (0..State.display_height) |y| {
            for (0..State.display_width) |x| {
                const bit = display[y * State.display_width + x];
                if (bit == 0) {
                    std.debug.print("░", .{});
                } else {
                    std.debug.print("▓", .{});
                }
            }
            std.debug.print("\n", .{});
        }
    }

    pub fn setKeys(_: *@This(), _: []bool) void {}
};

// We don't want to do draw calls when the display has not changed.
// Therefore we don't call beginDrawing() and endDrawing() every frame.
// This causes issues because pollInputEvents() is called in endDrawing().
// So in the frames where we do not draw, we miss input events.
// Raylib can give you control on the draw call behaviour by enabling SUPPORT_CUSTOM_FRAME_CONTROL.
// Enabling SUPPORT_CUSTOM_FRAME_CONTROL means we must manually manage input event polling, screen buffer swapping and frame time control.
// NOTE: we are using SUPPORT_CUSTOM_FRAME_CONTROL so calling these functions in invalid:
// - GetFrameTime()
// - SetTargetFPS()
// - GetFPS()
const RaylibFrontend = struct {
    const rl = @import("raylib");

    allocator: std.mem.Allocator,
    scale: f32,
    pixels: []u8,
    texture: rl.Texture = undefined,

    // Frame time control. We need to manage frame timing because we use SUPPORT_CUSTOM_FRAME_CONTROL
    previous_time: f64, // Previous time measure
    current_time: f64 = 0, // Current time measure
    update_draw_time: f64 = 0, // Update + Draw time
    wait_time: f64 = 0, // Wait time (if target fps required)
    target_fps: f64, // Our initial target fps

    screenshot_counter: u8 = 0,

    const zero = rl.Vector2{ .x = 0, .y = 0 };

    pub fn init(opts: FrontendOptions(.raylib)) !@This() {
        var fe = RaylibFrontend{
            .allocator = opts.allocator,
            .scale = opts.scale,
            .target_fps = @floatFromInt(opts.target_fps),
            .pixels = try opts.allocator.alloc(u8, State.display_width * State.display_height * 3),
            .previous_time = rl.getTime(),
        };

        const screen_width = State.display_width * opts.scale;
        const screen_height = State.display_height * opts.scale;
        rl.initWindow(@intFromFloat(screen_width), @intFromFloat(screen_height), "Chip-8 Emulator");

        const image = rl.Image{
            .data = fe.pixels.ptr,
            .width = State.display_width,
            .height = State.display_height,
            .mipmaps = 1,
            .format = rl.PixelFormat.uncompressed_r8g8b8,
        };
        fe.texture = try rl.loadTextureFromImage(image);

        return fe;
    }

    pub fn deinit(self: @This()) void {
        rl.unloadTexture(self.texture);
        self.allocator.free(self.pixels);
        rl.closeWindow();
    }

    pub fn shouldStop(_: @This()) bool {
        return rl.windowShouldClose();
    }

    pub fn draw(self: *@This(), display: [State.display_resolution]u8) void {
        rl.beginDrawing();
        defer {
            rl.endDrawing();
            rl.swapScreenBuffer();
            self.keepTargetFPS();
        }

        for (display, 0..) |pixel, i| {
            const value: u8 = if (pixel == 1) 255 else 0;
            self.pixels[i * 3 + 0] = value; // R
            self.pixels[i * 3 + 1] = value; // G
            self.pixels[i * 3 + 2] = value; // B
        }

        rl.updateTexture(self.texture, self.pixels.ptr);
        rl.clearBackground(rl.Color.black);
        rl.drawTextureEx(self.texture, zero, 0, self.scale, rl.Color.white);
    }

    fn keepTargetFPS(self: *@This()) void {
        self.current_time = rl.getTime();
        self.update_draw_time = self.current_time - self.previous_time;

        self.wait_time = (1 / self.target_fps) - self.update_draw_time;
        if (self.wait_time > 0.0) {
            rl.waitTime(self.wait_time);
            self.current_time = rl.getTime();
        }

        self.previous_time = self.current_time;
    }

    pub fn setKeys(self: *@This(), keys: []bool) void {
        rl.pollInputEvents();

        setKeysFromKeyEvent(keys, rl.isKeyDown, true);
        setKeysFromKeyEvent(keys, rl.isKeyUp, false);

        if (rl.isKeyPressed(rl.KeyboardKey.f12)) {
            self.takeScreenshot();
        }
    }

    fn takeScreenshot(self: *@This()) void {
        var buffer: ["screenshot_000.png".len + 1]u8 = undefined;
        const out = std.fmt.bufPrintZ(&buffer, "screenshot_{d:0>3}.png", .{self.screenshot_counter}) catch |err| {
            std.log.err("Error occurred while formating screenshot filename: {}", .{err});
            return;
        };
        rl.takeScreenshot(out);
        self.screenshot_counter += 1;
    }

    const number_keys: [10]rl.KeyboardKey = .{ .kp_0, .kp_1, .kp_2, .kp_3, .kp_4, .kp_5, .kp_6, .kp_7, .kp_8, .kp_9 };
    const letter_keys: [5]rl.KeyboardKey = .{ .b, .c, .d, .e, .f };

    fn setKeysFromKeyEvent(keys: []bool, isKeyEvent: fn (rl.KeyboardKey) bool, key_value: bool) void {
        for (number_keys) |k| {
            if (isKeyEvent(k)) {
                const iusize: usize = @intCast(@intFromEnum(k) - @intFromEnum(rl.KeyboardKey.kp_0));
                keys[iusize] = key_value;
            }
        }

        for (letter_keys) |k| {
            if (isKeyEvent(k)) {
                const iusize: usize = @intCast(0xA + (@intFromEnum(k) - @intFromEnum(rl.KeyboardKey.a)));
                keys[iusize] = key_value;
            }
        }

        if (isKeyEvent(.q)) {
            keys[0xA] = key_value;
        }
    }
};
