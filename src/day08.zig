const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

fn id_from_name(name: []const u8) u32 {
    var id: u32 = 0;

    for (0..3) |i| {
        id = (id << 8) | @as(u32, @intCast(name[i]));
    }
    return id;
}

const Node = struct {
    id: u32,
    name: []const u8,
    lhs: ?*Node = null,
    rhs: ?*Node = null,

    fn new(name: []const u8) Node {
        return .{
            .id = id_from_name(name),
            .name = name,
        };
    }

    fn init(self: *Node, name: []const u8) void {
        self.id = id_from_name(name);
        self.name = name;
    }

    fn update(self: *Node, lhs: *Node, rhs: *Node) void {
        self.lhs = lhs;
        self.rhs = rhs;
    }
};

fn is_alnum(c: u8) bool {
    return switch (c) {
        '0'...'9' => true,
        'a'...'z' => true,
        'A'...'Z' => true,
        else =>  false,
    };
}

const LabelIterator = struct {
    pos: usize,
    line: []const u8,

    fn init(line: []const u8) LabelIterator {
        return .{ .pos = 0, .line = line };
    }

    fn next(self: *LabelIterator) ?[]const u8 {
        if (self.pos >= self.line.len) {
            return null;
        }

        var i = self.pos;

        while (i < self.line.len and !is_alnum(self.line[i])) {
            i += 1;
        }

        self.pos = i;

        if (self.pos >= self.line.len) {
            return null;
        }

        while (i < self.line.len and is_alnum(self.line[i])) {
            i += 1;
        }

        const label = self.line[self.pos..i];
        self.pos = i;

        return label;
    }
};

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    var arena_allocator = arena.allocator();
    defer arena.deinit();

    var nodes = std.StringHashMap(*Node).init(gpa);
    defer nodes.deinit();

    var iter = std.mem.splitSequence(u8, content, "\n");

    const instructions = iter.next().?;

    std.debug.print("instructions = {s}\n", .{ instructions });

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        var label_iter = LabelIterator.init(line);
        const name = label_iter.next().?;
        const lhs_name = label_iter.next().?;
        const rhs_name = label_iter.next().?;

        var node = nodes.get(name);
        if (node == null) {
            node = try arena_allocator.create(Node);
            node.?.init(name);
            try nodes.put(name, node.?);
        }

        var lhs = nodes.get(lhs_name);
        if (lhs == null) {
            lhs = try arena_allocator.create(Node);
            lhs.?.init(lhs_name);
            try nodes.put(lhs_name, lhs.?);
        }

        var rhs = nodes.get(rhs_name);
        if (rhs == null) {
            rhs = try arena_allocator.create(Node);
            rhs.?.init(rhs_name);
            try nodes.put(rhs_name, rhs.?);
        }

        // std.debug.print("{s}\n", .{ node.?.name });
        node.?.update(lhs.?, rhs.?);
    }

    // var node_iter = nodes.valueIterator();
    // while (node_iter.next()) |n| {
    //     std.debug.print("{s} -> {s}, {s}\n", .{ n.name, n.lhs.?.name, n.rhs.?.name });
    // }

    const last_id = nodes.get("ZZZ").?.id;
    var current = nodes.get("AAA").?;
    var pos: usize = 0;

    var count: usize = 0;

    while (current.id != last_id) {
        const inst = instructions[pos];
        const next = if (inst == 'L') current.lhs.? else current.rhs.?;

        // std.debug.print("{s} -> {s}\n", .{ current.name, next.name });
        count += 1;

        pos = @mod(pos + 1, instructions.len);
        current = next;
    }

    std.debug.print("total steps = {}\n", .{ count });
}

pub fn part2(gpa: Allocator, content: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    var arena_allocator = arena.allocator();
    defer arena.deinit();

    var nodes = std.StringHashMap(*Node).init(gpa);
    defer nodes.deinit();

    var iter = std.mem.splitSequence(u8, content, "\n");

    const instructions = iter.next().?;

    std.debug.print("instructions = {s}\n", .{ instructions });

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        var label_iter = LabelIterator.init(line);
        const name = label_iter.next().?;
        const lhs_name = label_iter.next().?;
        const rhs_name = label_iter.next().?;

        var node = nodes.get(name);
        if (node == null) {
            node = try arena_allocator.create(Node);
            node.?.init(name);
            try nodes.put(name, node.?);
        }

        var lhs = nodes.get(lhs_name);
        if (lhs == null) {
            lhs = try arena_allocator.create(Node);
            lhs.?.init(lhs_name);
            try nodes.put(lhs_name, lhs.?);
        }

        var rhs = nodes.get(rhs_name);
        if (rhs == null) {
            rhs = try arena_allocator.create(Node);
            rhs.?.init(rhs_name);
            try nodes.put(rhs_name, rhs.?);
        }

        // std.debug.print("{s}\n", .{ node.?.name });
        node.?.update(lhs.?, rhs.?);
    }

    var current: std.ArrayList(*Node) = .empty;
    var last_ids: std.ArrayList(usize) = .empty;
    var periods: std.ArrayList(usize) = .empty;

    defer {
        current.deinit(gpa);
        last_ids.deinit(gpa);
        periods.deinit(gpa);
    }

    var node_iter = nodes.valueIterator();

    while (node_iter.next()) |n| {
        if (n.*.name[2] == 'A') {
            try current.append(gpa, n.*);
        } else if (n.*.name[2] == 'Z') {
            std.debug.print("{s}\n", .{ n.*.name });
            try last_ids.append(gpa, n.*.id);
        }
        // std.debug.print("{s} -> {s}, {s}\n", .{ n.name, n.lhs.?.name, n.rhs.?.name });
    }

    for (0..current.items.len) |i| {
        var count: usize = 0;
        var pos: usize = 0;

        while (true) {
            const inst = instructions[pos];

            const n = current.items[i];
            if (std.mem.indexOfScalar(usize, last_ids.items, n.id)) |_| {
                try periods.append(gpa, count);
                break;
            }

            const next = if (inst == 'L') n.lhs.? else n.rhs.?;

            current.items[i] = next;

            count += 1;
            pos = @mod(pos + 1, instructions.len);
        }
    }


    var total_steps: usize = 1;

    for (periods.items) |p| {
        const gcd = std.math.gcd(total_steps, p);
        total_steps = p * total_steps / gcd; // mcm - minimum common multiple
    }

    std.debug.print("total steps = {}\n", .{ total_steps });
}
