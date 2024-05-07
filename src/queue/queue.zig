pub const Queue = @import("queueWithLock.zig").Queue;
pub const LockFreeQueue = @import("lockFreeQueue.zig").LockFreeQueue;

test {
    _ = @import("queueWithLock.zig");
    _ = @import("lockFreeQueue.zig");
}
