const std = @import("std");

const Allocator = std.mem.Allocator;

const Direction = enum {
    North,
    South,
    East,
    West,
};

const Tile = enum(u8) {
    Block = '#',
    Plot = '.',
    Start = 'S',
};

const Grid = struct {
    data: std.ArrayList(Tile),
    nrows: usize,
    ncols: usize,
    allocator: Allocator,

    fn init(allocator: Allocator) Grid {
        return Grid {
            .data = .empty,
            .nrows = 0,
            .ncols = 0,
            .allocator = allocator,
        };
    }

    fn deinit(self: *Grid) void {
        self.nrows = 0;
        self.ncols = 0;
        self.data.deinit(self.allocator);
    }

    fn print(self: Grid) void {
        for (0..self.nrows) |i| {
            for (0..self.ncols) |j| {
                std.debug.print("{c}", .{ @intFromEnum(self.get(i, j)) });
            }

            std.debug.print("\n", .{});
        }

        std.debug.print("\n", .{});
    }

    fn push_row(self: *Grid, row: []const u8) !void {
        if (self.nrows != 0) {
            std.debug.assert(row.len == self.ncols);
        } else {
            self.ncols = row.len;
        }

        self.nrows += 1;

        for (row) |c| {
            const tile: Tile = @enumFromInt(c);
            try self.data.append(self.allocator, tile);
        }
    }

    fn get(self: Grid, i: usize, j: usize) Tile {
        return self.data.items[i * self.nrows + j];
    }

    fn set(self: *Grid, tile: Tile, i: usize, j: usize) void {
        self.data.items[i * self.nrows + j] = tile;
    }
};

const Coord = struct {
    row: usize,
    col: usize,

    fn go(self: Coord, grid: Grid, dir: Direction) ?Coord {
        var coord: ?Coord = null;
        switch (dir) {
            .North => {
                if (self.row > 0) {
                    coord = .{ .row = self.row - 1, .col = self.col };
                }
            },
            .South => {
                if (self.row + 1 < grid.nrows) {
                    coord = .{ .row = self.row + 1, .col = self.col };
                }
            },
            .East => {
                if (self.col + 1 < grid.ncols) {
                    coord = .{ .row = self.row, .col = self.col + 1 };
                }
            },
            .West => {
                if (self.col > 0) {
                    coord = .{ .row = self.row, .col = self.col - 1 };
                }
            }
        }

        if (coord != null and grid.get(coord.?.row, coord.?.col) == .Block) {
            coord = null;
        }

        return coord;
    }
};

const CoordSet = std.AutoHashMap(Coord, void);

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var grid: Grid = .init(gpa);

    var set1: CoordSet = .init(gpa);
    var set2: CoordSet = .init(gpa);

    defer {
        grid.deinit();
        set1.deinit();
        set2.deinit();
    }

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        try grid.push_row(line);
    }

    grid.print();

    for (grid.data.items, 0..) |c, i| {
        if (c == .Start) {
            const row = i / grid.nrows;
            const col = @rem(i, grid.nrows);
            try set1.put(.{ .row = row, .col = col}, {});

            // std.debug.print("({}, {})\n", .{row, col});
            break;
        }
    }

    const dirs: [4]Direction = .{.North, .South, .East, .West};

    const N = 64;
    var current_set = &set1;
    var other_set = &set2;

    for (0..N) |_| {
        var set_iter = current_set.keyIterator();

        while (set_iter.next()) |coord| {
            for (dirs) |dir| {
                if (coord.go(grid, dir)) |new_coord| {
                    try other_set.put(new_coord, {});
                }
            }
        }

        current_set.clearRetainingCapacity();

        const aux = current_set;
        current_set = other_set;
        other_set = aux;
    }

    var total: usize = 0;
    var set_iter = current_set.keyIterator();

    while (set_iter.next()) |coord| {
        std.debug.print("{any}\n", .{coord});
        total += 1;
    }

    std.debug.print("total = {}\n", .{total});
}
