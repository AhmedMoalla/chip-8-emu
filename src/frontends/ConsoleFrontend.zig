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

const stdin = std.fs.File.stdin();

raw_term: term.RawTerm,
should_stop: bool = false,

pub fn init(_: std.mem.Allocator, _: anytype) !ConsoleFrontend {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    if (!std.posix.isatty(stdin.handle)) {
        try stdout.print("The current file descriptor is not a referring to a terminal.\n", .{});
        return error.StdinNotTTY;
    }

    const raw_term = try term.enableRawMode(stdin.handle);

    try term.enterAlternateScreen(stdout);
    try cursor.hide(stdout);

    return ConsoleFrontend{
        .raw_term = raw_term,
    };
}

pub fn deinit(self: *ConsoleFrontend) void {
    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    cursor.show(stdout) catch {};
    term.exitAlternateScreen(stdout) catch {};
    self.raw_term.disableRawMode() catch {};
}

pub fn shouldStop(self: ConsoleFrontend) bool {
    return self.should_stop;
}

pub fn draw(_: *ConsoleFrontend, should_draw: bool, display: [State.display_resolution]u8) !void {
    if (!should_draw) return;
    // Do double buffering to reduce flickering

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file = std.fs.File.stdout();
    var stdout_writer = stdout_file.writer(&stdout_buffer);
    const stdout = &stdout_writer.interface;

    try startBatch(stdout);

    for (0..State.display_height) |y| {
        for (0..State.display_width) |x| {
            const pixel = display[y * State.display_width + x];
            try cursor.goTo(stdout, x, y);
            try color.bg256(stdout, if (pixel == 1) .white else .black);
            try stdout.print(" ", .{});
        }
    }

    try flushBatch(stdout);
}

pub fn setKeys(self: *ConsoleFrontend, keys: []bool) void {
    const next = events.nextWithTimeout(stdin, 10) catch unreachable;
    switch (next) {
        .key => |k| switch (k.code) {
            .char => |char| {
                if (k.mods.ctrl and char == 'c') { // Handle Ctrl+C because raw mode consumes all key presses
                    self.should_stop = true;
                    return;
                }

                if (char >= 'a' and char <= 'f') {
                    const index: usize = @intCast(0xA + (char - 'a'));
                    keys[index] = true;
                }

                if (char >= '0' and char <= '9') {
                    const index: usize = @intCast(char - '0');
                    keys[index] = true;
                }
            },
            else => {},
        },
        else => {},
    }
}

fn startBatch(stdout: *std.Io.Writer) !void {
    // Enable synchronized mode
    try stdout.print("{s}", .{utils.comptimeCsi("?2026h", .{})});
}

fn flushBatch(stdout: *std.Io.Writer) !void {
    // Disable synchronized mode
    try stdout.print("{s}", .{utils.comptimeCsi("?2026l", .{})});
}

fn stdoutWriter() std.Io.Writer {
    var stdout_buffer: [1]u8 = undefined;
    var stdout_file = std.fs.File.stdout();
    const stdout_writer = stdout_file.writer(&stdout_buffer);
    return stdout_writer.interface;
}
