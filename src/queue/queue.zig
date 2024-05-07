pub const Queue = @import("queueWithLock.zig").LockQueue;

test {
    _ = @import("queueWithLock.zig");
    _ = @import("lockFreeQueue.zig");
}
