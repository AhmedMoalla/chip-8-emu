const std = @import("std");
const f = @import("frontends.zig");
const b = @import("backends/Backend.zig");

const Args = @This();

rom_path: []const u8 = undefined,
tick_rate: u32 = 8, // -t, --tick-rate | default = 8 * 60fps = 500Hz

frontend: f.Frontend.Kind = .raylib, // -f, --frontend
scale: f32 = 8, // -s, --scale
target_fps: u32 = 60, // -p, --target-fps

backend: b.Backend.Kind = .chip8, // -b, --backend

const ArgsParsingError = error{
    RomPathRequired,
    UnrecognizedFrontend,
    UnrecognizedBackend,
    InvalidScale,
    InvalidTargetFPS,
    InvalidTickRate,
};

pub const usage =
    \\Usage: chip8-emu [options] [rom_path]
    \\
    \\Options:
    \\  -f,--frontend [console|raylib]       frontend used by the emulator. default: raylib
    \\  -b,--backend [chip8|schip]           backend used by the emulator. default: chip8
    \\  -s,--scale                           scale used by the frontend to render the display. default: 8
    \\  -p,--target-fps                      target FPS to reach by the frontend. default: 60
    \\  -t,--tick-rate                       tick rate at which the emulator runs per frame. default: 8 (8 * 60fps = 500Hz)
;

pub fn parse(allocator: std.mem.Allocator) ArgsParsingError!Args {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip(); // Program name

    return parseIterator(&args);
}

fn parseIterator(it: anytype) ArgsParsingError!Args {
    var rom_path: ?[]const u8 = null;
    var args = Args{};

    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--frontend")) {
            const frontend_arg = it.next();
            if (frontend_arg) |frontend| {
                args.frontend = std.meta.stringToEnum(f.Frontend.Kind, frontend) orelse
                    return ArgsParsingError.UnrecognizedFrontend;
            } else {
                return ArgsParsingError.UnrecognizedFrontend;
            }
        } else if (std.mem.eql(u8, arg, "-b") or std.mem.eql(u8, arg, "--backend")) {
            const backend_arg = it.next();
            if (backend_arg) |backend| {
                args.backend = std.meta.stringToEnum(b.Backend.Kind, backend) orelse
                    return ArgsParsingError.UnrecognizedBackend;
            } else {
                return ArgsParsingError.UnrecognizedBackend;
            }
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--scale")) {
            const scale_arg = it.next();
            if (scale_arg) |scale| {
                args.scale = std.fmt.parseFloat(f32, scale) catch return ArgsParsingError.InvalidScale;
            } else {
                return ArgsParsingError.InvalidScale;
            }
        } else if (std.mem.eql(u8, arg, "-p") or std.mem.eql(u8, arg, "--target-fps")) {
            const target_fps_arg = it.next();
            if (target_fps_arg) |target_fps| {
                args.target_fps = std.fmt.parseInt(u32, target_fps, 10) catch return ArgsParsingError.InvalidTargetFPS;
            } else {
                return ArgsParsingError.InvalidTargetFPS;
            }
        } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--tick-rate")) {
            const tick_rate_arg = it.next();
            if (tick_rate_arg) |tick_rate| {
                args.tick_rate = std.fmt.parseInt(u32, tick_rate, 10) catch return ArgsParsingError.InvalidTickRate;
            } else {
                return ArgsParsingError.InvalidTickRate;
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
        .backend = .chip8,
        .scale = 8,
        .target_fps = 60,
        .tick_rate = 8,
    });

    try expectFails("", ArgsParsingError.RomPathRequired);
    try expectFails("-f raylib", ArgsParsingError.RomPathRequired);

    try expectFails("-f rom_path", ArgsParsingError.UnrecognizedFrontend);
    try expectFails("-f", ArgsParsingError.UnrecognizedFrontend);

    try expectArgs("-b chip8 rom_path", Args{
        .rom_path = "rom_path",
        .backend = .chip8,
    });

    try expectArgs("-b schip rom_path", Args{
        .rom_path = "rom_path",
        .backend = .schip,
    });

    try expectFails("-b rom_path", ArgsParsingError.UnrecognizedBackend);
    try expectFails("-b", ArgsParsingError.UnrecognizedBackend);

    try expectArgs("rom_path -s 2.5", Args{
        .rom_path = "rom_path",
        .scale = 2.5,
    });

    try expectFails("-s", ArgsParsingError.InvalidScale);
    try expectFails("-s ab", ArgsParsingError.InvalidScale);

    try expectArgs("rom_path -p 50", Args{
        .rom_path = "rom_path",
        .target_fps = 50,
    });

    try expectFails("-p", ArgsParsingError.InvalidTargetFPS);
    try expectFails("-p 1.2", ArgsParsingError.InvalidTargetFPS);
    try expectFails("-p avaeea", ArgsParsingError.InvalidTargetFPS);

    try expectArgs("rom_path -t 50", Args{
        .rom_path = "rom_path",
        .tick_rate = 50,
    });

    try expectFails("-t", ArgsParsingError.InvalidTickRate);
    try expectFails("-t 1.2", ArgsParsingError.InvalidTickRate);
    try expectFails("-t avaeea", ArgsParsingError.InvalidTickRate);
}
