const std = @import("std");
const json = std.json;

const FrontendKind = enum { raylib, console };
const BackendKind = enum { chip8, schip, xochip };

const Task = struct {
    label: []const u8,
    command: []const u8 = "zig build run",
    args: [][]const u8,
    use_new_terminal: bool = false,
    allow_concurrent_runs: bool = false,
    reveal: []const u8 = "no_focus",
    reveal_target: []const u8 = "dock",
    hide: []const u8 = "never",
    shell: []const u8 = "system",
    show_summary: bool = true,
    show_command: bool = true,
};

// Generate tasks for every ROM / Frontend combination
pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const roms = try std.fs.cwd().realpathAlloc(allocator, "../roms");
    var roms_dir = try std.fs.openDirAbsolute(roms, .{ .iterate = true });
    defer roms_dir.close();

    var allocating = std.Io.Writer.Allocating.init(allocator);
    defer allocating.deinit();

    var stringify = json.Stringify{
        // .indent_level = 1,
        .writer = &allocating.writer,
    };

    try stringify.beginArray();
    var it = roms_dir.iterateAssumeFirstIteration();
    while (try it.next()) |rom| {
        inline for (@typeInfo(FrontendKind).@"enum".fields) |frontend| {
            inline for (@typeInfo(BackendKind).@"enum".fields) |backend| {
                try stringify.write(Task{
                    .label = try std.fmt.allocPrint(allocator, "Run {s} {s} ({s})", .{ frontend.name, rom.name, backend.name }),
                    .args = @constCast(&[_][]const u8{
                        "--",
                        "--frontend",
                        frontend.name,
                        "--backend",
                        backend.name,
                        try std.fmt.allocPrint(allocator, "roms/{s}", .{rom.name}),
                    }),
                });
            }
        }
    }
    try stringify.endArray();

    std.debug.print("{s}\n", .{allocating.writer.buffered()});
}
