const std = @import("std");
const State = @import("State.zig");
const FrontendKind = @import("frontends/Frontend.zig").Frontend.Kind;
const BackendKind = @import("backends/Backend.zig").Backend.Kind;

const Args = @This();

rom_path: []const u8 = undefined,
tick_rate: u32 = 8, // -t, --tick-rate | default = 8 * 60fps = 500Hz

frontend: FrontendKind = .raylib, // -f, --frontend
scale: f32 = 8, // -s, --scale
target_fps: u32 = 60, // -p, --target-fps

backend: BackendKind = .chip8, // -b, --backend
set_memory_address: ?usize = null, // -m, --set-memory
set_memory_address_value: ?u8 = null,

const ArgsParsingError = error{
    RomPathRequired,
    UnrecognizedFrontend,
    UnrecognizedBackend,
    InvalidScale,
    InvalidTargetFPS,
    InvalidTickRate,
    InvalidSetMemory,
    InvalidSetMemoryAddress,
    SetMemoryAddressTooHigh,
    InvalidSetMemoryValue,
};

pub const usage =
    \\Usage: chip8-emu [options] [rom_path]
    \\
    \\Options:
    \\  -f,--frontend [console|raylib]      frontend used by the emulator. default: raylib
    \\  -b,--backend [chip8|schip]          backend used by the emulator. default: chip8
    \\  -s,--scale                          scale used by the frontend to render the display. default: 8
    \\  -p,--target-fps                     target FPS to reach by the frontend. default: 60
    \\  -t,--tick-rate                      tick rate at which the emulator runs per frame. default: 8 (8 * 60fps = 500Hz)
    \\  -s,--set-memory [1FF=1]         set a specific memory location (Hexadecimal) to a given (Hexadecimal) value at rom loading time. min_address=0 | max_address=0xFFF
;

pub fn parse(args: *std.process.ArgIterator) ArgsParsingError!Args {
    _ = args.skip(); // Program name

    return parseIterator(args);
}

fn parseIterator(it: anytype) ArgsParsingError!Args {
    var rom_path: ?[]const u8 = null;
    var args = Args{};

    while (it.next()) |arg| {
        if (std.mem.eql(u8, arg, "-f") or std.mem.eql(u8, arg, "--frontend")) {
            const frontend_arg = it.next();
            if (frontend_arg) |frontend| {
                args.frontend = std.meta.stringToEnum(FrontendKind, frontend) orelse
                    return ArgsParsingError.UnrecognizedFrontend;
            } else return ArgsParsingError.UnrecognizedFrontend;
        } else if (std.mem.eql(u8, arg, "-b") or std.mem.eql(u8, arg, "--backend")) {
            const backend_arg = it.next();
            if (backend_arg) |backend| {
                args.backend = std.meta.stringToEnum(BackendKind, backend) orelse
                    return ArgsParsingError.UnrecognizedBackend;
            } else return ArgsParsingError.UnrecognizedBackend;
        } else if (std.mem.eql(u8, arg, "-s") or std.mem.eql(u8, arg, "--scale")) {
            const scale_arg = it.next();
            if (scale_arg) |scale| {
                args.scale = std.fmt.parseFloat(f32, scale) catch return ArgsParsingError.InvalidScale;
            } else return ArgsParsingError.InvalidScale;
        } else if (std.mem.eql(u8, arg, "-p") or std.mem.eql(u8, arg, "--target-fps")) {
            const target_fps_arg = it.next();
            if (target_fps_arg) |target_fps| {
                args.target_fps = std.fmt.parseInt(u32, target_fps, 10) catch return ArgsParsingError.InvalidTargetFPS;
            } else return ArgsParsingError.InvalidTargetFPS;
        } else if (std.mem.eql(u8, arg, "-t") or std.mem.eql(u8, arg, "--tick-rate")) {
            const tick_rate_arg = it.next();
            if (tick_rate_arg) |tick_rate| {
                args.tick_rate = std.fmt.parseInt(u32, tick_rate, 10) catch return ArgsParsingError.InvalidTickRate;
            } else return ArgsParsingError.InvalidTickRate;
        } else if (std.mem.eql(u8, arg, "-m") or std.mem.eql(u8, arg, "--set-memory")) {
            const set_memory_arg = it.next();
            if (set_memory_arg) |set_memory| {
                var set_memory_it = std.mem.splitScalar(u8, set_memory, '=');
                if (set_memory_it.next()) |set_memory_address| {
                    args.set_memory_address = std.fmt.parseInt(usize, set_memory_address, 16) catch return ArgsParsingError.InvalidSetMemoryAddress;
                    if (args.set_memory_address.? > State.memory_size - 1) return ArgsParsingError.SetMemoryAddressTooHigh;
                } else return ArgsParsingError.InvalidSetMemory;

                if (set_memory_it.next()) |set_memory_address_value| {
                    args.set_memory_address_value = std.fmt.parseInt(u8, set_memory_address_value, 16) catch return ArgsParsingError.InvalidSetMemoryValue;
                } else return ArgsParsingError.InvalidSetMemory;
            } else {
                return ArgsParsingError.InvalidSetMemory;
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

    try expectArgs("rom_path -m 1FF=1", Args{
        .rom_path = "rom_path",
        .set_memory_address = 0x1FF,
        .set_memory_address_value = 0x1,
    });

    try expectFails("-m", ArgsParsingError.InvalidSetMemory);
    try expectFails("-m 1FF", ArgsParsingError.InvalidSetMemory);
    try expectFails("-m 1FF=", ArgsParsingError.InvalidSetMemoryValue);
    try expectFails("-m 1FF=Z", ArgsParsingError.InvalidSetMemoryValue);
    try expectFails("-m Z=1", ArgsParsingError.InvalidSetMemoryAddress);
    try expectFails("-m FFFF=1", ArgsParsingError.SetMemoryAddressTooHigh);
}
