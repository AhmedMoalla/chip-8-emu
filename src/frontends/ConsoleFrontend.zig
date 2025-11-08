const std = @import("std");

const mibu = @import("mibu");
const events = mibu.events;
const term = mibu.term;
const utils = mibu.utils;
const color = mibu.color;
const cursor = mibu.cursor;

const State = @import("../State.zig");
const f = @import("Frontend.zig");
const FrontendOptions = f.FrontendOptions;

const ConsoleFrontend = @This();
const key_release_timeout = 50 * std.time.ns_per_ms;

raw_term: term.RawTerm,
should_stop: bool = false,
flip_colors: bool = false,

key_releaser: PosixKeyReleaser,

pub fn init(allocator: std.mem.Allocator, _: anytype) !ConsoleFrontend {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    const stdin = std.fs.File.stdin();
    if (!std.posix.isatty(stdin.handle)) {
        try stdout.print("The current file descriptor is not a referring to a terminal.\n", .{});
        return error.StdinNotTTY;
    }

    const raw_term = try term.enableRawMode(stdin.handle);

    try term.enterAlternateScreen(stdout);
    try cursor.hide(stdout);
    try stdout.flush();

    return ConsoleFrontend{
        .raw_term = raw_term,
        .key_releaser = try PosixKeyReleaser.init(allocator, key_release_timeout),
    };
}

pub fn deinit(self: *ConsoleFrontend) void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    self.raw_term.disableRawMode() catch {};
    cursor.show(stdout) catch {};
    term.exitAlternateScreen(stdout) catch {};
    color.resetAll(stdout) catch {};
    stdout.flush() catch {};
    self.key_releaser.deinit();
}

pub fn shouldStop(self: ConsoleFrontend) bool {
    return self.should_stop;
}

pub fn draw(self: *ConsoleFrontend, should_draw: bool, display: [State.display_resolution]u8) !void {
    if (!should_draw) return;

    var stdout_buffer: [50000]u8 = undefined;
    var stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try startBatch(stdout);

    for (0..State.display_height) |y| {
        try cursor.goTo(stdout, 1, y + 1); // Terminal coordinates are 1-based
        for (0..State.display_width) |x| {
            const pixel = display[y * State.display_width + x];
            if (self.flip_colors) {
                try color.bg256(stdout, if (pixel == 1) .black else .white);
                try color.fg256(stdout, if (pixel == 1) .white else .black);
            } else {
                try color.bg256(stdout, if (pixel == 1) .white else .black);
                try color.fg256(stdout, if (pixel == 1) .black else .white);
            }
            try stdout.print(" ", .{});
        }
    }

    try flushBatch(stdout);
    try stdout.flush();
}

pub fn playSound(self: *ConsoleFrontend, sound_timer: u8) void {
    self.flip_colors = sound_timer > 0;
}

const PosixKeyReleaser = struct {
    const KeyReleaseTimeoutHashMap = std.AutoArrayHashMap(u21, u64);

    key_release_timeout: u64,
    key_release_timer: std.time.Timer,
    key_release_timeouts: KeyReleaseTimeoutHashMap,

    pub fn init(allocator: std.mem.Allocator, release_timeout: u64) !PosixKeyReleaser {
        return .{
            .key_release_timeout = release_timeout,
            .key_release_timer = try std.time.Timer.start(),
            .key_release_timeouts = KeyReleaseTimeoutHashMap.init(allocator),
        };
    }

    pub fn deinit(self: *PosixKeyReleaser) void {
        self.key_release_timeouts.deinit();
    }

    pub fn releaseKeysAfterTimeout(self: *PosixKeyReleaser, keys: []bool) void {
        const now = self.key_release_timer.read();

        // Iterate backwards so we can remove items safely during iteration
        var i: usize = self.key_release_timeouts.count();
        const chars = self.key_release_timeouts.keys();
        const values = self.key_release_timeouts.values();
        while (i > 0) {
            i -= 1;
            const char = chars[i];
            const pressed_time = values[i];

            if (now - pressed_time >= self.key_release_timeout) {
                keys[charToKeyIndex(char)] = false;
                _ = self.key_release_timeouts.swapRemove(char);
            }
        }
    }

    pub fn reportKeyPress(self: *PosixKeyReleaser, char: u21) void {
        const result = self.key_release_timeouts.getOrPut(char) catch unreachable;
        if (!result.found_existing) {
            result.value_ptr.* = self.key_release_timer.read();
        }
    }
};

pub fn setKeys(self: *ConsoleFrontend, keys: []bool) void {
    self.key_releaser.releaseKeysAfterTimeout(keys);

    const stdin = std.fs.File.stdin();
    const next = events.nextWithTimeout(stdin, 10) catch unreachable;
    switch (next) {
        .key => |k| switch (k.code) {
            .char => |char| {
                if (k.mods.ctrl and char == 'c') { // Handle Ctrl+C because raw mode consumes all key presses
                    self.should_stop = true;
                    return;
                }

                if (char >= 'a' and char <= 'f') {
                    keys[charToKeyIndex(char)] = true;
                    self.key_releaser.reportKeyPress(char);
                }

                if (char >= '0' and char <= '9') {
                    keys[charToKeyIndex(char)] = true;
                    self.key_releaser.reportKeyPress(char);
                }
            },
            else => {},
        },
        else => {},
    }
}

fn charToKeyIndex(char: u21) usize {
    if (char >= 'a' and char <= 'f') {
        return @intCast(0xA + (char - 'a'));
    }

    if (char >= '0' and char <= '9') {
        return @intCast(char - '0');
    }

    unreachable;
}

fn startBatch(stdout: *std.Io.Writer) !void {
    // Enable synchronized mode
    try stdout.print("{s}", .{utils.comptimeCsi("?2026h", .{})});
}

fn flushBatch(stdout: *std.Io.Writer) !void {
    // Disable synchronized mode
    try stdout.print("{s}", .{utils.comptimeCsi("?2026l", .{})});
}
