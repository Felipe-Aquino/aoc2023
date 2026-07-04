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
const PairSet = std.AutoHashMap(struct {usize, usize}, void);

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

pub fn part2(gpa: Allocator, content: []const u8) !void {
    _ = gpa;
    _ = content;
    unreachable();
}

