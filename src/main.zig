const std = @import("std");

pub fn main() !void {
    std.debug.print("All your {s} are belong to us.\n", .{"katas"});
}

test {
    _ = @import("queue/queue.zig");
}
