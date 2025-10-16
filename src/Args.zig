const std = @import("std");
const f = @import("frontends.zig");

const Args = @This();

rom_path: []const u8,
tick_rate: u32 = 8, // default = 8 * 60fps = 500Hz

frontend: f.Frontend.Kind,

pub fn parse(allocator: std.mem.Allocator) !Args {
    var args = try std.process.argsWithAllocator(allocator);
    defer args.deinit();
    _ = args.skip(); // Program name

    return Args{
        .rom_path = blk: {
            const rom_path_arg = args.next();
            if (rom_path_arg) |rom_path| {
                break :blk rom_path;
            } else {
                std.log.err("One argument is required which is the rom path", .{});
                std.process.exit(1);
            }
        },
        .frontend = blk: {
            const frontend_arg = args.next();
            if (frontend_arg) |frontend| {
                if (std.mem.eql(u8, frontend, "raylib")) {
                    break :blk .raylib;
                } else if (std.mem.eql(u8, frontend, "console")) {
                    break :blk .console;
                }
                std.log.err("unrecognized frontend : '{s}'", .{frontend});
                return error.UnrecognizedFrontend;
            }

            break :blk .raylib;
        },
    };
}
