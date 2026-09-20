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
    Step = 'o',

    fn from_u8(c: u8) Tile {
        return @enumFromInt(c);
    }
};

fn Grid(comptime T: type) type {
    return struct {
        const Self = @This();

        data: std.ArrayList(T),
        nrows: usize,
        ncols: usize,
        allocator: Allocator,

        fn init(allocator: Allocator) Self {
            return .{
                .data = .empty,
                .nrows = 0,
                .ncols = 0,
                .allocator = allocator,
            };
        }

        fn deinit(self: *Self) void {
            self.nrows = 0;
            self.ncols = 0;
            self.data.deinit(self.allocator);
        }

        // fn print(self: Grid) void {
        //     for (0..self.nrows) |i| {
        //         for (0..self.ncols) |j| {
        //             std.debug.print("{c}", .{ @intFromEnum(self.get(i, j)) });
        //         }

        //         std.debug.print("\n", .{});
        //     }

        //     std.debug.print("\n", .{});
        // }

        fn push_row(self: *Self, row: []const u8, transform: fn (u8) T) !void {
            if (self.nrows != 0) {
                std.debug.assert(row.len == self.ncols);
            } else {
                self.ncols = row.len;
            }

            self.nrows += 1;

            for (row) |c| {
                const tile: T = transform(c);
                try self.data.append(self.allocator, tile);
            }
        }

        fn get(self: Self, i: usize, j: usize) T {
            return self.data.items[i * self.nrows + j];
        }

        fn get2(self: Self, i: i64, j: i64) T {
            const i_2: usize = @intCast(@mod(i, @as(i64, @intCast(self.nrows))));
            const j_2: usize = @intCast(@mod(j, @as(i64, @intCast(self.ncols))));
            return self.data.items[i_2 * self.nrows + j_2];
        }

        fn set(self: *Self, tile: T, i: usize, j: usize) void {
            self.data.items[i * self.nrows + j] = tile;
        }

        fn copy_from(self: *Self, other: Self) void {
            std.debug.assert(self.nrows == other.nrows);
            std.debug.assert(self.ncols == other.ncols);

            std.mem.copyFowards(self.data.item, other.data.items);
        }
    };
}

fn print_tile_grid(grid: Grid(Tile)) void {
    for (0..grid.nrows) |i| {
        for (0..grid.ncols) |j| {
            std.debug.print("{c}", .{ @intFromEnum(grid.get(i, j)) });
        }

        std.debug.print("\n", .{});
    }

    std.debug.print("\n", .{});
}


const Coord = struct {
    row: i64,
    col: i64,

    fn go(self: Coord, grid: Grid(Tile), dir: Direction) ?Coord {
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

        if (coord != null and grid.get2(coord.?.row, coord.?.col) == .Block) {
            coord = null;
        }

        return coord;
    }
};

const Coord0 = struct {
    row: usize,
    col: usize,

    fn go(self: Coord0, grid: Grid(Tile), dir: Direction) ?Coord0 {
        var coord: ?Coord0 = null;
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
const CoordSet2 = std.AutoHashMap(Coord, Coord);
const GridStepMap = std.AutoHashMap(Coord, []Coord);

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var grid: Grid(Tile) = .init(gpa);

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

        try grid.push_row(line, Tile.from_u8);
    }

    // grid.print();

    for (grid.data.items, 0..) |c, i| {
        if (c == .Start) {
            const row: i64 = @intCast(i / grid.nrows);
            const col: i64 = @intCast(@rem(i, grid.nrows));
            try set1.put(.{ .row = row, .col = col}, {});

            // std.debug.print("({}, {})\n", .{row, col});
            break;
        }
    }

    const dirs: [4]Direction = .{.North, .South, .East, .West};

    // const N = 64;
    const N = 6;
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

fn as_zero(c: u8) u64 {
    _ = c;
    return 0;
}

pub fn part3(gpa: Allocator, content: []const u8) !void {
    var grid: Grid(Tile) = .init(gpa);

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

        try grid.push_row(line, Tile.from_u8);
    }

    // grid.print();

    for (grid.data.items, 0..) |c, i| {
        if (c == .Start) {
            const row: i64 = @intCast(i / grid.nrows);
            const col: i64 = @intCast(@rem(i, grid.nrows));
            try set1.put(.{ .row = row, .col = col}, {});

            // std.debug.print("({}, {})\n", .{row, col});
            break;
        }
    }

    const steps: [4]struct{i64, i64} = .{.{1, 0}, .{-1, 0}, .{0, -1}, .{0, 1}};

    // const N = 64;
    const N = 100;
    var current_set = &set1;
    var other_set = &set2;

    for (0..N) |_| {
        var set_iter = current_set.keyIterator();

        while (set_iter.next()) |coord| {
            for (steps) |step| {
                const new_coord: Coord = .{
                    .row = coord.row + step[0],
                    .col = coord.col + step[1],
                };
                if (grid.get2(new_coord.row, new_coord.col) != .Block) {
                    try other_set.put(new_coord, {});
                }
            }
        }

        current_set.clearRetainingCapacity();

        const aux = current_set;
        current_set = other_set;
        other_set = aux;
    }

    {
        var buckets: std.AutoHashMap(Coord, usize) = .init(gpa);
        defer buckets.deinit();

        var set_iter = current_set.keyIterator();

        while (set_iter.next()) |coord| {
            // std.debug.print("{any}\n", .{coord});
            const grid_i = @divFloor(coord.row, @as(i64, @intCast(grid.nrows)));
            const grid_j = @divFloor(coord.col, @as(i64, @intCast(grid.ncols)));
            const bucket = Coord { .row = grid_i, .col = grid_j };

            if (buckets.get(bucket)) |v| {
                try buckets.put(bucket, v + 1);
            } else {
                try buckets.put(bucket, 1);
            }
        }

        // var bucket_iter = buckets.iterator();
        // while (bucket_iter.next()) |entry| {
        //     const coord = entry.key_ptr.*;
        //     const count = entry.value_ptr.*;

        //     std.debug.print("({},{}): {}\n", .{coord.row, coord.col, count});
        // }
    }

    const total: usize = current_set.count();
    // var set_iter = current_set.keyIterator();

    // while (set_iter.next()) |coord| {
    //     std.debug.print("{any}\n", .{coord});
    //     total += 1;
    // }

    std.debug.print("total = {}\n", .{total});
}

fn calculate_max_plot_fillings(grid: Grid(Tile)) struct { usize, usize } {
    const num_line_plots1: usize = @divFloor(grid.ncols + 1, 2);
    const num_line_plots2: usize = grid.ncols - num_line_plots1;

    const max_grid_plots1 =
        @divFloor(grid.nrows, 2) * grid.ncols + @rem(grid.nrows, 2) * num_line_plots1;
    const max_grid_plots2 =
        @divFloor(grid.nrows, 2) * grid.ncols + @rem(grid.nrows, 2) * num_line_plots2;

    var odd_count: usize = 0;
    var even_count: usize = 0;

    for (0..grid.nrows) |i| {
        for (0..grid.ncols) |j| {
            if (grid.get(i, j) == .Block) {
                if (@rem(i + j, 2) == 1) {
                    odd_count += 1;
                } else {
                    even_count += 1;
                }
            }
        }
    }

    // std.debug.print("even_count = {}\n", .{even_count});
    // std.debug.print("odd_count = {}\n", .{odd_count});
    // std.debug.print("max_grid_plots1 = {}\n", .{max_grid_plots1});
    // std.debug.print("max_grid_plots2 = {}\n", .{max_grid_plots2});

    var result: struct { usize, usize } = .{
        max_grid_plots2 - odd_count,
        max_grid_plots1 - even_count,
    };

    if (result[0] > result[1]) {
        const aux = result[0];
        result[0] = result[1];
        result[1] = aux;
    }

    return result;
}

fn extend_grid(grid: Grid(Tile), dimension: usize) Grid(Tile) {
    const mid = @divFloor(dimension, 2);
    var result: Grid(Tile) = .init(grid.allocator);

    result.nrows = grid.nrows * dimension;
    result.ncols = grid.ncols * dimension;
    const data = grid.allocator.alloc(Tile, result.nrows * result.ncols) catch unreachable();
    result.data = std.ArrayList(Tile).fromOwnedSlice(data);

    for (0..dimension) |k| {
        for (0..grid.nrows) |i| {
            const i_2 = i + k * grid.nrows;

            for (0..dimension) |l| {
                for (0..grid.ncols) |j| {
                    const j_2 = j + l * grid.ncols;

                    const tile = grid.get(i, j);

                    if (tile == .Step and (l != mid or k != mid)) {
                        result.set(.Plot, i_2, j_2);
                    } else {
                        result.set(tile, i_2, j_2);
                    }
                }
            }
        }
    }

    return result;
}

fn clear_grid(grid: *Grid(Tile)) void {
    for (0..grid.data.items.len) |i| {
        const tile = grid.data.items[i];
        if (tile != .Block) {
            grid.data.items[i] = .Plot;
        }
    }
}

fn grid_step(grid1: Grid(Tile), grid2: *Grid(Tile)) void {
    const dirs: [4]Direction = .{.North, .South, .East, .West};

    for (0..grid1.nrows) |i| {
        for (0..grid1.ncols) |j| {
            const tile = grid1.get(i, j);
            if (tile == .Step) {
                const coord: Coord0 = .{ .row = i, .col = j };
                for (dirs) |dir| {
                    if (coord.go(grid1, dir)) |new_coord| {
                        grid2.set(.Step, new_coord.row, new_coord.col);
                    }
                }
            }
        }
    }
}

const Counting = struct {
    const Key = struct{usize, usize};
    data: std.AutoHashMap(Key, std.ArrayList(usize)),
    allocator: Allocator,

    fn init(gpa: Allocator) Counting {
        return .{
            .data = .init(gpa),
            .allocator = gpa,
        };
    }

    fn deinit(self: *Counting) void {
        var iter = self.data.valueIterator();
        while (iter.next()) |list| {
            list.deinit(self.allocator);
        }
        self.data.deinit();
    }

    fn put(self: *Counting, key: Key, value: usize) void {
        if (self.data.getPtr(key)) |list| {
            list.append(self.allocator, value) catch unreachable();
        } else {
            var list: std.ArrayList(usize) = .empty;
            list.append(self.allocator, value) catch unreachable();

            self.data.put(key, list) catch unreachable();
        }
    }
};

fn count_per_quadrant(grid: Grid(Tile), dimension: usize, counting: *Counting) void {
    const nrows = @divFloor(grid.nrows, dimension);
    const ncols = @divFloor(grid.ncols, dimension);
    for (0..dimension) |k| {
        for (0..dimension) |l| {
            var count: usize = 0;

            for (0..nrows) |i| {
                const i_2 = i + k * nrows;
                for (0..ncols) |j| {
                    const j_2 = j + l * ncols;

                    if (grid.get(i_2, j_2) == .Step) {
                        count += 1;
                    }
                }
            }

            counting.put(.{k, l}, count);
        }
    }
}

const Metric = struct {
    key: Counting.Key,
    first_step_idx: usize,
    first_repeat_idx: usize,
    sequence: []usize,
    original_seq: []usize,

    fn deinit(self: *Metric, gpa: Allocator) void {
        gpa.free(self.original_seq);
    }
};

const ReadMetricsError = error {
    FillingNotFound,
};

fn read_metrics(
    gpa: Allocator,
    counting: Counting,
    filling: *struct{usize,usize}
) !std.ArrayList(Metric) {
    var metrics: std.ArrayList(Metric) = .empty;

    var sequences: std.ArrayList([]usize) = .empty;
    defer sequences.deinit(gpa);

    var cnt_iter = counting.data.iterator();
    while (cnt_iter.next()) |entry| {
        const key = entry.key_ptr.*;
        const list = entry.value_ptr;

        var first_step_idx: ?usize = null;
        var first_repeat_idx: ?usize = null;

        for (0..list.items.len - 1) |i| {
            const v1 = list.items[i];
            const v2 = list.items[i + 1];

            if (first_step_idx == null and v1 != 0) {
                first_step_idx = i;
            }

            if (first_repeat_idx == null) {
                // const ok = (v1 == filling[0] and v2 == filling[1]) or 
                //            (v1 == filling[1] and v2 == filling[0]);
                const ok = (v1 == filling[0] and v2 == filling[1]);
                          
                if (ok) {
                    // if (v1 == filling[1] and v2 == filling[0]) {
                    //     const aux = filling[0];
                    //     filling[0] = filling[1];
                    //     filling[1] = aux;
                    // }

                    first_repeat_idx = i;
                    break;
                }
            }
        }

        if (first_step_idx == null or first_repeat_idx == null) {
            std.debug.print("?? {}, {}, {any}\n", .{key, filling, list.items});
            return ReadMetricsError.FillingNotFound;
            // continue;
        }

        var list_slice = try list.toOwnedSlice(gpa);

        const seq = seq_slice: {
            const start: usize = @intCast(first_step_idx.?);
            const end: usize = @intCast(first_repeat_idx.? + 1);
            break :seq_slice list_slice[start..end];
        };

        var seq_found: bool = false;

        for (sequences.items) |s| {
            if (s.len != seq.len) continue;

            if (std.mem.eql(usize, seq, s)) {
                seq_found = true;
                break;
            }
        }

        if (!seq_found) {
            try sequences.append(gpa, list_slice);
        }

        try metrics.append(gpa, .{
            .key = key,
            .first_step_idx = first_step_idx.?,
            .first_repeat_idx = first_repeat_idx.?,
            .sequence = seq,
            .original_seq = list_slice,
        });
    }

    return metrics;
}

fn find_metric(metrics: []const Metric, key: Counting.Key) Metric {
    for (metrics) |m| {
        if (m.key[0] == key[0] and m.key[1] == key[1]) {
            return m;
        }
    }

    unreachable();
}

fn get_count(
    sequence: []usize,
    filling: struct{usize, usize},
    total_steps: usize,
    step_idx: usize,
    repeat_idx: usize
) usize {
    if (step_idx < total_steps) {
        const idx = total_steps - (step_idx + 1);

        if (repeat_idx + 1 > total_steps) {
            return sequence[idx];
        } else {
            const idx2 = total_steps - (repeat_idx + 1);

            return if (idx2 % 2 == 0) filling[0] else filling[1];
        }
    }

    return 0;
}

pub fn number_of_plots(
    grid: Grid(Tile),
    total_steps: usize,
    dimension: usize,
    metrics: []const Metric,
    filling: struct{usize, usize}
) void {
    const mid: isize = @intCast(@divFloor(dimension, 2));

    const step_diff: usize = grid.nrows;

    var plots_count: usize = 0;

    {
        const positions: [4]struct{isize, isize} = .{.{-1, -1}, .{-1, 1}, .{1, -1}, .{1, 1}};

        for (positions) |p| {
            const key: struct {usize, usize} = .{
                @as(usize, @intCast(mid + p[0])),
                @as(usize, @intCast(mid + p[1])),
            };

            const metric = find_metric(metrics, key);
            const num_iterations =
                1 + @divFloor(total_steps - metric.first_step_idx, step_diff);

            // var total_: usize = 0;
            for (0..num_iterations) |i| {
                for (0..num_iterations) |j| {
                    const step_idx = metric.first_step_idx + (i + j) * step_diff;
                    const repeat_idx = metric.first_repeat_idx + (i + j) * step_diff;

                    plots_count += get_count(metric.sequence, filling, total_steps, step_idx, repeat_idx);
                    // const x = get_count(metric.sequence, filling, total_steps, step_idx, repeat_idx);
                    // plots_count += x;
                    // total_ += x;
                }
            }

            // std.debug.print("({},{}): {}\n", .{key[0], key[1], total_});
        }
    }

    const Y: isize = 3;
    const positions2: [4]struct{isize, isize} = .{.{0, -1}, .{0, 1}, .{-1, 0}, .{1, 0}};

    {
        // var total_: usize = 0;

        for (positions2) |p| {
            const key: struct {usize, usize} = .{
                @as(usize, @intCast(mid + Y * p[0])),
                @as(usize, @intCast(mid + Y * p[1])),
            };
            const metric = find_metric(metrics, key);
            const num_iterations =
                1 + @divFloor(total_steps - metric.first_step_idx, step_diff);

            for (0..num_iterations) |i| {
                const step_idx = metric.first_step_idx + i * step_diff;
                const repeat_idx = metric.first_repeat_idx + i * step_diff;

                plots_count += get_count(metric.sequence, filling, total_steps, step_idx, repeat_idx);
                // const x = get_count(metric.sequence, filling, total_steps, step_idx, repeat_idx);
                // plots_count += x;
                // total_ += x;
            }

            // std.debug.print("({},{}): {}\n", .{key[0], key[1], total_});
        }
    }

    {
        const S = @as(usize, @intCast(Y));
        var positions3: [4*S - 3]struct{isize, isize} = undefined;
        var k: usize = 1;

        positions3[0] = .{0, 0};
        for (1..S) |i| {
            for (positions2) |p| {
                const j: isize = @intCast(i);
                positions3[k] = .{p[0] * j, p[1] * j};
                k += 1;
            }
        }

        for (positions3) |p| {
            const key: struct {usize, usize} = .{
                @as(usize, @intCast(mid + p[0])),
                @as(usize, @intCast(mid + p[1])),
            };
            const metric = find_metric(metrics, key);

            const step_idx = metric.first_step_idx;
            const repeat_idx = metric.first_repeat_idx;

            plots_count += get_count(metric.sequence, filling, total_steps, step_idx, repeat_idx);
            // const x = get_count(metric.sequence, filling, total_steps, step_idx, repeat_idx);
            // plots_count += x;

            // std.debug.print("({},{}): {}\n", .{key[0], key[1], x});
        }

    }

    std.debug.print("plots = {}\n", .{plots_count});
}

fn grid_fill_unreachable(grid: *Grid(Tile)) void {
    for (1..grid.nrows - 1) |i| {
        for (1..grid.ncols - 1) |j| {
            if (grid.get(i, j) == .Plot) {
                const fill = 
                    grid.get(i + 1, j) == .Block and
                    grid.get(i - 1, j) == .Block and
                    grid.get(i, j + 1) == .Block and
                    grid.get(i, j - 1) == .Block;

                if (fill) {
                    grid.set(.Block, i, j);
                }
            }
        }
    }
}

pub fn part2(gpa: Allocator, content: []const u8) !void {
    var grid: Grid(Tile) = .init(gpa);

    defer {
        grid.deinit();
    }

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        try grid.push_row(line, Tile.from_u8);
    }

    // grid.print();

    for (grid.data.items, 0..) |c, i| {
        if (c == .Start) {
            grid.data.items[i] = .Step;
            break;
        }
    }

    grid_fill_unreachable(&grid);

    const base_dim: usize = 7;
    var extended1 = extend_grid(grid, base_dim);
    var extended2 = extend_grid(grid, base_dim);
    defer {
        extended1.deinit();
        extended2.deinit();
    }

    clear_grid(&extended2);

    // print_tile_grid(extended1);

    var counting = Counting.init(gpa);
    defer counting.deinit();

    var current_grid = &extended1;
    var other_grid = &extended2;

    for (0..1000) |_| {
        grid_step(current_grid.*, other_grid);

        count_per_quadrant(other_grid.*, base_dim, &counting);

        const aux = current_grid;
        current_grid = other_grid;
        other_grid = aux;

        clear_grid(other_grid);
    }

    var filling = calculate_max_plot_fillings(grid);

    // std.debug.print("filling = {}\n", .{filling});

    var metrics = try read_metrics(gpa, counting, &filling);
    defer {
        for (metrics.items) |*m| {
            // std.debug.print("({},{}): {any}\n", .{m.key[0], m.key[1], m.sequence});
            m.deinit(gpa);
        }
        metrics.deinit(gpa);
    }

    const TOTAL_STEPS: usize = 26501365;
    number_of_plots(grid, TOTAL_STEPS, base_dim, metrics.items, filling);
}
