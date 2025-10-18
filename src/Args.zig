const std = @import("std");
const f = @import("frontends.zig");
const b = @import("backends/Backend.zig");

const Args = @This();

allocator: std.mem.Allocator = undefined,

rom_path: []const u8 = undefined,
tick_rate: u32 = 8, // default = 8 * 60fps = 500Hz

frontend: f.Frontend.Kind = .raylib,
scale: f32 = 8,
target_fps: u32 = 60,

backend: b.Backend.Kind = .chip8,

const ArgsParsingError = error{
    RomPathRequired,
    UnrecognizedFrontend,
    UnrecognizedBackend,
};

pub fn parse(allocator: std.mem.Allocator) ArgsParsingError!Args {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip(); // Program name

    var result = try parseIterator(&args);
    result.allocator = allocator;
    return result;
}

fn parseIterator(it: anytype) ArgsParsingError!Args {
    var rom_path: ?[]const u8 = null;
    var args = Args{};

    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-f")) {
            const frontend_arg = it.next();
            if (frontend_arg) |frontend| {
                if (std.mem.eql(u8, frontend, "raylib")) {
                    args.frontend = .raylib;
                } else if (std.mem.eql(u8, frontend, "console")) {
                    args.frontend = .console;
                } else {
                    return ArgsParsingError.UnrecognizedFrontend;
                }
            } else {
                return ArgsParsingError.UnrecognizedFrontend;
            }
        } else if (std.mem.eql(u8, arg, "-b")) {
            const backend_arg = it.next();
            if (backend_arg) |backend| {
                if (std.mem.eql(u8, backend, "chip8")) {
                    args.backend = .chip8;
                } else if (std.mem.eql(u8, backend, "schip")) {
                    args.backend = .schip;
                } else {
                    return ArgsParsingError.UnrecognizedBackend;
                }
            } else {
                return ArgsParsingError.UnrecognizedBackend;
            }
        } else {
            rom_path = arg;
        }
    }

    if (rom_path) |path| {
        args.rom_path = path;
    } else {
        return ArgsParsingError.RomPathRequired;
    }

    return args;
}

test "parse" {}

fn expectArgs(args_str: []const u8, expected: Args) !void {
    var args_it = std.mem.tokenizeScalar(u8, args_str, ' ');
    const args = try parseIterator(&args_it);
    try std.testing.expectEqualDeep(expected, args);
}

fn expectFails(args_str: []const u8, expected: ArgsParsingError) !void {
    var args_it = std.mem.tokenizeScalar(u8, args_str, ' ');
    const result = parseIterator(&args_it);
    try std.testing.expectError(expected, result);
}

test "parse args" {
    try expectArgs("-f raylib rom_path", Args{
        .rom_path = "rom_path",
        .frontend = .raylib,
    });

    try expectArgs("-f console rom_path", Args{
        .rom_path = "rom_path",
        .frontend = .console,
    });

    try expectArgs("rom_path", Args{
        .rom_path = "rom_path",
        .frontend = .raylib,
    });

    try expectFails("", ArgsParsingError.RomPathRequired);
    try expectFails("-f raylib", ArgsParsingError.RomPathRequired);

    try expectFails("-f rom_path", ArgsParsingError.UnrecognizedFrontend);
    try expectFails("-f", ArgsParsingError.UnrecognizedFrontend);
}
