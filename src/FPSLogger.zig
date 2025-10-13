const std = @import("std");

const FPSLogger = @This();

timer: std.time.Timer,
counter: usize = 0,
last_report: u64,

pub fn init() !FPSLogger {
    var timer = try std.time.Timer.start();
    return FPSLogger{
        .timer = timer,
        .last_report = timer.read(),
    };
}

pub fn logFPS(self: *FPSLogger) void {
    self.counter += 1;
    const current_time = self.timer.read();
    if (current_time - self.last_report >= std.time.ns_per_s) {
        std.log.info("FPS: {d}", .{self.counter});
        self.counter = 0;
        self.last_report = current_time;
    }
}
