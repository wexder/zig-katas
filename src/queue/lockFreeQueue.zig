const std = @import("std");
const atomic = std.atomic;

fn Node(comptime T: type) type {
    return struct {
        value: T,
        next: ?*Node(T),
    };
}

pub fn LockFreeQueue(comptime T: type) type {
    return struct {
        const Self = @This();
        const AP = atomic.Value(?*Node(T));
        allocator: std.mem.Allocator,
        head: AP,
        tail: AP,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .head = AP.init(null),
                .tail = AP.init(null),
            };
        }

        pub fn deinit(self: *Self) void {
            const current_head = self.head.load(.monotonic);
            if (current_head == null) {
                return;
            }

            var next = current_head.?.next;
            defer self.allocator.destroy(current_head.?);
            while (next) |h| {
                next = h.next;
                self.allocator.destroy(h);
            }
        }

        pub fn push(self: *Self, v: T) !void {
            const new_node = try self.allocator.create(Node(T));
            new_node.* = .{
                .value = v,
                .next = null,
            };

            var curr = self.tail.load(.monotonic);
            while (true) {
                if (self.tail.cmpxchgWeak(curr, new_node, .monotonic, .monotonic)) |c| {
                    curr = c;
                    continue;
                }
                if (curr) |c| {
                    c.*.next = new_node;
                } else {
                    self.head.store(new_node, .monotonic);
                }
                break;
            }
        }

        pub fn pop(self: *Self) ?T {
            var curr = self.head.load(.monotonic);
            if (curr == null) {
                return null;
            }
            while (true) {
                if (self.head.cmpxchgWeak(curr, curr.?.next, .monotonic, .monotonic)) |c| {
                    curr = c;
                    continue;
                }

                defer self.allocator.destroy(curr.?);
                if (curr.?.next == null) {
                    self.tail.store(null, .monotonic);
                }
                return curr.?.value;
            }
        }
    };
}

test "string lock queue" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var q = LockFreeQueue([]const u8).init(allocator);
    defer q.deinit();

    try q.push("test");
    const v1 = q.pop();

    try testing.expect(v1 != null);
    try testing.expectEqualStrings("test", v1.?);

    const v2 = q.pop();
    try testing.expectEqual(null, v2);

    try q.push("test2");
    try q.push("test3");
    try q.push("test4");
    const v3 = q.pop();

    try testing.expect(v3 != null);
    try testing.expectEqualStrings("test2", v3.?);
}

test "parallel string lock queue" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var q = LockFreeQueue([]const u8).init(allocator);
    defer q.deinit();

    {
        const handle = try std.Thread.spawn(.{}, test_queue_push_n, .{ &q, "test", 10 });
        defer handle.join();

        const handle2 = try std.Thread.spawn(.{}, test_queue_push_n, .{ &q, "test", 10 });
        defer handle2.join();

        const handle3 = try std.Thread.spawn(.{}, test_queue_push_n, .{ &q, "test", 10 });
        defer handle3.join();
    }

    for (0..30) |_| {
        const v = q.pop();
        try testing.expect(v != null);
        try testing.expectEqualStrings("test", v.?);
    }

    try testing.expect(q.pop() == null);
}

fn test_queue_push_n(qp: *LockFreeQueue([]const u8), v: []const u8, n: usize) void {
    for (0..n) |_| {
        qp.push(v) catch unreachable;
    }
}
