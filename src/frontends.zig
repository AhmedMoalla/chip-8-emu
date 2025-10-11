const std = @import("std");
const State = @import("State.zig");

pub fn FrontendOptions(kind: Frontend.Kind) type {
    return switch (kind) {
        .console => struct {},
        .raylib => struct {
            scale: f32 = 8,
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
            .raylib => .{ .raylib = try RaylibFrontend.init(opts.allocator, opts.scale) },
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

    pub fn setKeys(self: @This(), keys: []bool) void {
        return switch (self) {
            inline else => |impl| impl.setKeys(keys),
        };
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

    pub fn setKeys(_: @This(), _: []bool) void {}
};

const RaylibFrontend = struct {
    const rl = @import("raylib");

    allocator: std.mem.Allocator = undefined,
    scale: f32,
    pixels: []u8 = undefined,
    texture: rl.Texture = undefined,

    const zero = rl.Vector2{ .x = 0, .y = 0 };

    pub fn init(allocator: std.mem.Allocator, scale: f32) !@This() {
        var fe = RaylibFrontend{
            .allocator = allocator,
            .scale = scale,
            .pixels = try allocator.alloc(u8, State.display_width * State.display_height * 3),
        };

        const screen_width = State.display_width * scale;
        const screen_height = State.display_height * scale;
        rl.initWindow(@intFromFloat(screen_width), @intFromFloat(screen_height), "Chip-8 Emulator");

        rl.setTargetFPS(60);

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
        defer rl.endDrawing();

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

    const number_keys: [10]rl.KeyboardKey = .{ .kp_0, .kp_1, .kp_2, .kp_3, .kp_4, .kp_5, .kp_6, .kp_7, .kp_8, .kp_9 };
    const letter_keys: [5]rl.KeyboardKey = .{ .b, .c, .d, .e, .f };

    pub fn setKeys(_: @This(), keys: []bool) void {
        rl.pollInputEvents();

        for (number_keys) |k| {
            if (rl.isKeyDown(k)) {
                const iusize: usize = @intCast(@intFromEnum(k) - @intFromEnum(rl.KeyboardKey.kp_0));
                keys[iusize] = true;
                return;
            }
        }

        for (letter_keys) |k| {
            if (rl.isKeyDown(k)) {
                const iusize: usize = @intCast(0xA + (@intFromEnum(k) - @intFromEnum(rl.KeyboardKey.a)));
                keys[iusize] = true;
                return;
            }
        }

        if (rl.isKeyDown(.q)) {
            keys[0xA] = true;
        }
    }
};
