const std = @import("std");

fn Node(comptime T: type) type {
    return struct {
        value: T,
        next: ?*Node(T),
    };
}

pub fn LockQueue(comptime T: type) type {
    return struct {
        const Self = @This();
        allocator: std.mem.Allocator,
        head: ?*Node(T),
        tail: ?*Node(T),
        lock: std.Thread.Mutex,

        pub fn init(allocator: std.mem.Allocator) Self {
            return .{
                .allocator = allocator,
                .head = null,
                .tail = null,
                .lock = std.Thread.Mutex{},
            };
        }

        pub fn deinit(self: *Self) void {
            if (self.head == null) {
                return;
            }

            var next = self.head.?.next;
            defer self.allocator.destroy(self.head.?);
            while (next) |h| {
                next = h.next;
                self.allocator.destroy(h);
            }
        }

        pub fn push(self: *Self, v: T) !void {
            self.lock.lock();
            defer self.lock.unlock();

            const new_node = try self.allocator.create(Node(T));
            new_node.* = .{
                .value = v,
                .next = null,
            };

            if (self.tail) |h| {
                h.*.next = new_node;
                self.tail = new_node;
            } else {
                self.tail = new_node;
                self.head = new_node;
            }
        }

        pub fn pop(self: *Self) ?T {
            self.lock.lock();
            defer self.lock.unlock();

            if (self.head) |t| {
                defer self.allocator.destroy(t);

                self.head = t.next;
                if (self.head == null) {
                    self.tail = null;
                }
                return t.value;
            }
            return null;
        }

        pub fn hasNext(self: *Self) bool {
            return self.head != null;
        }
    };
}

test "string lock queue" {
    const testing = std.testing;
    const allocator = testing.allocator;

    var q = LockQueue([]const u8).init(allocator);
    defer q.deinit();

    try q.push("test");
    const v1 = q.pop();

    try testing.expect(v1 != null);
    try testing.expectEqualStrings("test", v1.?);

    const v2 = q.pop();
    try testing.expectEqual(null, v2);
    try testing.expectEqual(false, q.hasNext());

    try q.push("test2");
    try q.push("test3");
    try q.push("test4");
    const v3 = q.pop();

    try testing.expect(v3 != null);
    try testing.expectEqualStrings("test2", v3.?);
    try testing.expectEqual(true, q.hasNext());
}
