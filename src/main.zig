const std = @import("std");
const State = @import("State.zig");
const instr = @import("instructions.zig");
const Frontend = @import("frontends.zig").Frontend;

pub const std_options: std.Options = .{
    .log_level = .info,
};

pub fn main() !void {
    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const args = try parseArgs(allocator);

    var state = try State.init(args.rom_path);
    var front = switch (args.frontend) {
        .raylib => try Frontend.init(.raylib, .{ .allocator = allocator }),
        .console => try Frontend.init(.console, .{}),
    };
    defer front.deinit();

    while (!front.shouldStop()) {
        const instruction = (@as(u16, state.memory[state.pc]) << 8) | state.memory[state.pc + 1];
        instr.execute(instruction, &state);
        if (state.should_draw) {
            // TODO: should_draw should also be false if previous display content = new display content.
            // i.e.: if buffer didn't change don't bother with calling draw()
            front.draw(state.display);
            state.should_draw = false;
        }
    }
}

const Args = struct {
    rom_path: []const u8,
    frontend: Frontend.Kind,
};

fn parseArgs(allocator: std.mem.Allocator) !Args {
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

            break :blk .console;
        },
    };
}

test {
    _ = @import("instructions.zig");
}
