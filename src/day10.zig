const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

const Direction = enum(u2) {
    North,
    South,
    East,
    West
};

const Pipe = struct {
    symbol: u8,
    visited: bool,
    pos: struct { usize, usize },
    n1: ?*Pipe, // Neighbour 1
    n2: ?*Pipe, // Neighbour 2

    fn init(self: *Pipe, symbol: u8, i: usize, j: usize) void {
        self.symbol = symbol;
        self.visited = false;
        self.pos = .{ i, j };
        self.n1 = null;
        self.n2 = null;
    }

    fn add_neighbour(self: *Pipe, n: *Pipe) void {
        if (self.n1 == null) {
            self.n1 = n;
        } else if (self.n2 == null) {
            self.n2 = n;
        } else {
            unreachable();
        }
    }
};

const PipeHashMap = std.AutoHashMap(struct {usize, usize}, *Pipe);

fn is_connected(pipe1: u8, pipe2: u8, dir: Direction) bool {
    return switch (dir) {
        .North =>
            (pipe1 == '|' or pipe1 == 'L' or pipe1 == 'J' or pipe1 == 'S') and
            (pipe2 == 'F' or pipe2 == '|' or pipe2 == '7' or pipe2 == 'S'),
        .South =>
            (pipe1 == 'F' or pipe1 == '|' or pipe1 == '7' or pipe1 == 'S') and
            (pipe2 == '|' or pipe2 == 'L' or pipe2 == 'J' or pipe2 == 'S'),
        .East =>
            (pipe1 == 'F' or pipe1 == '-' or pipe1 == 'L' or pipe1 == 'S') and
            (pipe2 == '-' or pipe2 == 'J' or pipe2 == '7' or pipe2 == 'S'),
        .West =>
            (pipe1 == 'J' or pipe1 == '-' or pipe1 == '7' or pipe1 == 'S') and
            (pipe2 == '-' or pipe2 == 'L' or pipe2 == 'F' or pipe2 == 'S'),
    };
}

fn get_or_add_pipe(arena: Allocator, pipes: *PipeHashMap, i: usize, j: usize, symbol: u8) !*Pipe {
    var pipe: *Pipe = undefined;

    if (pipes.get(.{i, j})) |p| {
        pipe = p;
    } else {
        pipe = try arena.create(Pipe);
        pipe.init(symbol, i, j);
        try pipes.put(.{i, j}, pipe);
    }

    return pipe;
}

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    const arena_allocator = arena.allocator();

    var grid: std.ArrayList([]const u8) = .empty;
    var pipes = PipeHashMap.init(gpa);

    defer {
        grid.deinit(gpa);
        arena.deinit();
    }

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len > 0) {
            try grid.append(gpa, line);
        }
    }

    var start_pipe: *Pipe = undefined;

    for (grid.items, 0..) |line, i| {
        for (line, 0..) |c, j| {
            if (c == '.') continue; 

            var pipe = try get_or_add_pipe(arena_allocator, &pipes, i, j, c);

            if (c == 'S') {
                start_pipe = pipe;
            }
            if (i > 0) {
                const above = grid.items[i - 1][j];
                if (is_connected(c, above, .North)) {
                    const n = try get_or_add_pipe(arena_allocator, &pipes, i - 1, j, above);
                    pipe.add_neighbour(n);
                }
            }

            if (i + 1 < grid.items.len) {
                const bellow = grid.items[i + 1][j];
                if (is_connected(c, bellow, .South)) {
                    const n = try get_or_add_pipe(arena_allocator, &pipes, i + 1, j, bellow);
                    pipe.add_neighbour(n);
                }
            }

            if (j > 0) {
                const before = grid.items[i][j - 1];
                if (is_connected(c, before, .West)) {
                    const n = try get_or_add_pipe(arena_allocator, &pipes, i, j - 1, before);
                    pipe.add_neighbour(n);
                }
            }

            if (j + 1 < line.len) {
                const after = grid.items[i][j + 1];
                if (is_connected(c, after, .East)) {
                    const n = try get_or_add_pipe(arena_allocator, &pipes, i, j + 1, after);
                    pipe.add_neighbour(n);
                }
            }
        }
    }

    // var pipe_iter = pipes.valueIterator();
    // while (pipe_iter.next()) |p| {
    //     const s1 = if (p.*.n1 != null) p.*.n1.?.symbol else '*';
    //     const s2 = if (p.*.n2 != null) p.*.n2.?.symbol else '*';

    //     std.debug.print("{c}: {}-> {c}, {c}\n", .{ p.*.symbol, p.*.pos, s1, s2 });
    // }

    // {
    //     const s1 = if (start_pipe.n1 != null) start_pipe.n1.?.symbol else '*';
    //     const s2 = if (start_pipe.n2 != null) start_pipe.n2.?.symbol else '*';

    //     std.debug.print("{c}: {}-> {c}, {c}\n", .{ start_pipe.symbol, start_pipe.pos, s1, s2 });
    // }

    var path: std.ArrayList(*Pipe) = .empty;
    defer path.deinit(gpa);

    start_pipe.visited = true;
    try path.append(gpa, start_pipe);

    var next = start_pipe.n1.?;
    while (true) {
        next.visited = true;
        try path.append(gpa, next);

        if (next.n1) |n1| {
            if (!n1.visited) {
                next = n1;
            } else if (next.n2) |n2| {
                next = n2;
                if (n2.visited) {
                    try path.append(gpa, next);
                    break;
                }
            } else {
                break;
            }
        } else {
            unreachable();
        }
    }

    std.debug.print("------------\n", .{});
    for (path.items) |p| {
        std.debug.print("{c}: {}\n", .{ p.symbol, p.pos });
    }

    std.debug.print("step count = {}\n", .{ path.items.len / 2 });
}

const Point = struct {
    x: usize,
    y: usize,

    fn eql(self: Point, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }
};
const Segment = struct {
    start: Point,
    end: Point,
};

const SegmentSet = std.AutoHashMap(Segment, void);

fn int_cast(comptime T: type, v: anytype) T {
    return @as(T, @intCast(v));
}

fn v_segment_cmp(_: void, lhs: Segment, rhs: Segment) bool {
    if (lhs.start.y == rhs.start.y) {
        return lhs.start.x < rhs.start.x;
    }
    return lhs.start.y < rhs.start.y;
}

fn h_segment_cmp(_: void, lhs: Segment, rhs: Segment) bool {
    if (lhs.start.x == rhs.start.x) {
        return lhs.start.y < rhs.start.y;
    }
    return lhs.start.x < rhs.start.x;
}

fn join_segments(s1: Segment, s2: Segment) ?Segment {
    if (s1.end.eql(s2.start)) {
        const s: Segment = .{
            .start = s1.start,
            .end = s2.end,
        };

        return s;
    }

    return null;
}

pub fn part2(gpa: Allocator, content: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    const arena_allocator = arena.allocator();

    var grid: std.ArrayList([]const u8) = .empty;
    var pipes = PipeHashMap.init(gpa);

    defer {
        grid.deinit(gpa);
        arena.deinit();
    }

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len > 0) {
            try grid.append(gpa, line);
        }
    }

    var start_pipe: *Pipe = undefined;

    for (grid.items, 0..) |line, i| {
        for (line, 0..) |c, j| {
            if (c == '.') continue; 

            var pipe = try get_or_add_pipe(arena_allocator, &pipes, i, j, c);

            if (c == 'S') {
                start_pipe = pipe;
            }
            if (i > 0) {
                const above = grid.items[i - 1][j];
                if (is_connected(c, above, .North)) {
                    const n = try get_or_add_pipe(arena_allocator, &pipes, i - 1, j, above);
                    pipe.add_neighbour(n);
                }
            }

            if (i + 1 < grid.items.len) {
                const bellow = grid.items[i + 1][j];
                if (is_connected(c, bellow, .South)) {
                    const n = try get_or_add_pipe(arena_allocator, &pipes, i + 1, j, bellow);
                    pipe.add_neighbour(n);
                }
            }

            if (j > 0) {
                const before = grid.items[i][j - 1];
                if (is_connected(c, before, .West)) {
                    const n = try get_or_add_pipe(arena_allocator, &pipes, i, j - 1, before);
                    pipe.add_neighbour(n);
                }
            }

            if (j + 1 < line.len) {
                const after = grid.items[i][j + 1];
                if (is_connected(c, after, .East)) {
                    const n = try get_or_add_pipe(arena_allocator, &pipes, i, j + 1, after);
                    pipe.add_neighbour(n);
                }
            }
        }
    }

    var path: std.ArrayList(*Pipe) = .empty;
    defer path.deinit(gpa);

    {
        start_pipe.visited = true;
        try path.append(gpa, start_pipe);

        var next = start_pipe.n1.?;
        while (true) {
            next.visited = true;
            try path.append(gpa, next);

            if (next.n1) |n1| {
                if (!n1.visited) {
                    next = n1;
                } else if (next.n2) |n2| {
                    next = n2;
                    if (n2.visited) {
                        try path.append(gpa, next);
                        break;
                    }
                } else {
                    break;
                }
            } else {
                unreachable();
            }
        }
    }

    // SOLUTION:
    // The idea here, is to break is to break the polygon of the path into a list of
    // horizontal segments and then count the points between the segment bounds

    // for (path.items) |p| {
    //     std.debug.print("{c}: {}\n", .{ p.symbol, p.pos });
    // }
    // std.debug.print("------------\n", .{});

    var hsegments: std.ArrayList(Segment) = .empty;
    var vsegments: std.ArrayList(Segment) = .empty;
    defer {
        hsegments.deinit(gpa);
        vsegments.deinit(gpa);
    }

    for (0..path.items.len - 1) |i| {
        const p1 = path.items[i];
        const p2 = path.items[i + 1];
        var s = Segment {
            .start = .{ .x = p1.pos[1], .y = p1.pos[0] },
            .end = .{ .x = p2.pos[1], .y = p2.pos[0] },
        };

        if (s.start.x == s.end.x) {
            if (s.start.y > s.end.y) {
                std.mem.swap(usize, &s.start.y, &s.end.y);
            }
            try vsegments.append(gpa, s);
        } else {
            if (s.start.x > s.end.x) {
                std.mem.swap(usize, &s.start.x, &s.end.x);
            }
            try hsegments.append(gpa, s);
        }
    }

    std.mem.sort(Segment, vsegments.items, {}, v_segment_cmp);
    // for (vsegments.items) |s| {
    //     std.debug.print("{}\n", .{s});
    // }

    var segment_set: SegmentSet = .init(gpa);
    defer segment_set.deinit(); 

    var j: usize = 0;
    while (j < vsegments.items.len) {
        const s1 = vsegments.items[j];
        const s2 = vsegments.items[j + 1];
        for (s1.start.x..s2.start.x) |x| {
            var s: Segment = .{
                .start = .{ .x = x, .y = 0 },
                .end = .{ .x = x + 1, .y = 0 },
            };

            s.start.y = s1.start.y;
            s.end.y = s1.start.y;
            try segment_set.put(s, {});

            s.start.y = s1.end.y;
            s.end.y = s1.end.y;
            try segment_set.put(s, {});
        }

        j += 2;
    }

    // std.debug.print("------------------\n", .{});
    // var s_iter = segment_set.keyIterator();
    // while (s_iter.next()) |s| {
    //     std.debug.print("{}\n", .{s.*});
    // }


    for (hsegments.items) |s| {
        _ = segment_set.remove(s);
    }

    hsegments.clearRetainingCapacity();

    // std.debug.print("------------------\n", .{});
    var s_iter = segment_set.keyIterator();
    while (s_iter.next()) |s| {
        // std.debug.print("{}\n", .{s.*});
        try hsegments.append(gpa, s.*);
    }

    std.mem.sort(Segment, hsegments.items, {}, v_segment_cmp);

    // std.debug.print("------------------\n", .{});
    // for (hsegments.items) |s| {
    //     std.debug.print("{}\n", .{s});
    // }

    var size = hsegments.items.len;
    j = 0;
    while (j + 1 < size) {
        const s1 = hsegments.items[j];
        const s2 = hsegments.items[j + 1];

        // std.debug.print("> \n", .{});
        // std.debug.print("{}, {} \n", .{s1.end, s2.start});
        if (join_segments(s1, s2)) |s| {
            hsegments.items[j] = s;
            _ = hsegments.orderedRemove(j + 1);
            size -= 1;
        } else {
            j += 1;
        }
    }

    std.debug.print("------------------\n", .{});
    var tile_count: usize = 0;
    for (hsegments.items) |s| {
        tile_count += s.end.x - s.start.x - 1;
        // std.debug.print("{} - {}\n", .{s, s.end.x - s.start.x - 1});
    }
    std.debug.print("tile count: {}\n", .{tile_count});
}
