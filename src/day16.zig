const std = @import("std");

const Allocator = std.mem.Allocator;

const TileType = enum(u8) {
    Empty = '.',
    VSplitter = '|',
    HSplitter = '-',
    Mirror1 = '/',
    Mirror2 = '\\',
};

const Tile = struct {
    tile_type: TileType,
    beam_count: usize,
    beam_directions: u8,
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
                std.debug.print("{c}", .{ @intFromEnum(self.get(i, j).tile_type) });
            }

            std.debug.print("\n", .{});
        }

        std.debug.print("\n", .{});
    }

    fn print_filled(self: Grid) void {
        for (0..self.nrows) |i| {
            for (0..self.ncols) |j| {
                if (self.get(i, j).beam_count > 0) {
                    std.debug.print("#", .{});
                } else {
                    std.debug.print(".", .{});
                }
            }

            std.debug.print("\n", .{});
        }

        std.debug.print("\n", .{});
    }

    fn count_energized(self: Grid) usize {
        var count: usize = 0;

        for (self.data.items) |tile| {
            if (tile.beam_count > 0) {
                count += 1;
            }
        }

        return count;
    }

    fn push_row(self: *Grid, row: []const u8) !void {
        if (self.nrows != 0) {
            std.debug.assert(row.len == self.ncols);
        } else {
            self.ncols = row.len;
        }

        self.nrows += 1;

        for (row) |c| {
            const tile: Tile = .{
                .tile_type = @enumFromInt(c),
                .beam_count = 0,
                .beam_directions = 0,
            };

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


const BeamDirection = enum {
    Up,
    Down,
    Left,
    Right,
    None,

    fn to_flag(self: BeamDirection) u8 {
        return switch (self) {
            .Up => 1,
            .Down => 2,
            .Left => 4,
            .Right => 8,
            .None => 0,
        };
    }
};

fn flag_contains_direction(flag: u8, d: BeamDirection) bool {
    return (flag & d.to_flag()) != 0;
}

const Beam = struct {
    row: usize,
    col: usize,
    direction: BeamDirection,

    fn move(self: *Beam, nrows: usize, ncols: usize) void {
        const is_done = switch (self.direction) {
            .Right => self.col + 1 == ncols,
            .Left => self.col == 0,
            .Up => self.row == 0,
            .Down => self.row + 1 == nrows,
            .None => true,
        };

        if (is_done) {
            self.direction = .None;
            return;
        }

        switch (self.direction) {
            .Right => self.col += 1,
            .Left => self.col -= 1,
            .Up => self.row -= 1,
            .Down => self.row += 1,
            .None => {},
        }
    }
};

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var grid = Grid.init(gpa);
    defer grid.deinit();

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        try grid.push_row(line);
    }

    grid.print();

    var beam_stack: std.ArrayList(Beam) = .empty;
    defer beam_stack.deinit(gpa);

    var beam = Beam {
        .row = 0,
        .col = 0,
        .direction = .Right,
    };

    // var iteractions: usize = 0;
    while (true) {
        // iteractions += 1;
        var tile = grid.get(beam.row, beam.col);

        switch (tile.tile_type) {
            .Empty => {},
            .VSplitter => {
                if (beam.direction == .Right or beam.direction == .Left) {
                    if (!flag_contains_direction(tile.beam_directions, beam.direction)) {
                        tile.beam_directions |= beam.direction.to_flag();

                        var beam1 = beam;
                        var beam2 = beam;

                        beam1.direction = .Up;
                        beam2.direction = .Down;

                        beam1.move(grid.nrows, grid.ncols);
                        beam2.move(grid.nrows, grid.ncols);

                        try beam_stack.append(gpa, beam1);
                        try beam_stack.append(gpa, beam2);
                    }

                    beam.direction = .None;
                }
            },
            .HSplitter => {
                if (beam.direction == .Up or beam.direction == .Down) {
                    if (!flag_contains_direction(tile.beam_directions, beam.direction)) {
                        tile.beam_directions |= beam.direction.to_flag();

                        var beam1 = beam;
                        var beam2 = beam;

                        beam1.direction = .Right;
                        beam2.direction = .Left;

                        beam1.move(grid.nrows, grid.ncols);
                        beam2.move(grid.nrows, grid.ncols);

                        try beam_stack.append(gpa, beam1);
                        try beam_stack.append(gpa, beam2);
                    }

                    beam.direction = .None;
                }
            },
            .Mirror1 => {
                beam.direction = switch (beam.direction) {
                    .Right => .Up,
                    .Left => .Down,
                    .Up => .Right,
                    .Down => .Left,
                    .None => .None,
                };
            },
            .Mirror2 => {
                beam.direction = switch (beam.direction) {
                    .Right => .Down,
                    .Left => .Up,
                    .Up => .Left,
                    .Down => .Right,
                    .None => .None,
                };
            },
        }

        tile.beam_count += 1;
        grid.set(tile, beam.row, beam.col);

        beam.move(grid.nrows, grid.ncols);

        // std.debug.print("stack size = {}\n", .{ beam_stack.items.len });
        // grid.print_filled();

        if (beam.direction == .None) {
            if (beam_stack.pop()) |b| {
                beam = b;
            } else {
                break;
            }
        }
    }

    grid.print_filled();

    std.debug.print("energized count = {}\n", .{ grid.count_energized() });
}
