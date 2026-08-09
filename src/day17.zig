const std = @import("std");
const utils = @import("utils");

const Allocator = std.mem.Allocator;
const INF: usize = 2_000_000_000;

const Position = struct {
    row: usize,
    col: usize,

    fn eql(self: Position, other: Position) bool {
        return self.row == other.row and self.col == other.col;
    }

    fn to_index(self: Position, ncols: usize) usize {
        return self.row * ncols + self.col;
    }

    fn next_in_dir(self: Position, dir: Direction, nrows: usize, ncols: usize) ?Position {
        switch (dir) {
            .Up => {
                if (self.row < 1) return null;
                return .{.row = self.row - 1, .col = self.col}; 
            },
            .Down => {
                if (self.row + 1 >= nrows) return null;
                return .{.row = self.row + 1, .col = self.col}; 
            },
            .Left => {
                if (self.col < 1) return null;
                return .{.row = self.row, .col = self.col - 1 }; 
            },
            .Right => {
                if (self.col + 1 >= ncols) return null;
                return .{.row = self.row, .col = self.col + 1};
            },
            .None => {
                return null;
            }
        }
    }
};

const Direction = enum {
    Up,
    Down,
    Left,
    Right,
    None,

    fn rev(dir: Direction) Direction {
        return switch (dir) {
            .Up => .Down,
            .Down => .Up,
            .Left => .Right,
            .Right => .Left,
            .None => .None,
        };
    }

    fn calc(p1: Position, p2: Position) Direction {
        if (p1.row == p2.row) {
            if (p1.col > p2.col) {
                return .Left;
            } else {
                return .Right;
            }
        } else if (p1.col == p2.col) {
            if (p1.row > p2.row) {
                return .Up;
            } else {
                return .Down;
            }
        } else {
            unreachable();
        }
    }

    fn get_char(self: Direction) u8 {
        return switch (self) {
            .Up => '^',
            .Down => 'v',
            .Left => '<',
            .Right => '>',
            .None => '.'
        };
    }
};

const Cell = struct {
    pos: Position,
    weight: usize,

    distance: usize,
    dir: Direction,
    prev_dir_count: usize,
};

const CellSet = std.AutoHashMap(struct {Position, Direction, usize}, void);

const Run = struct {
    gpa: Allocator,
    path: std.ArrayList(usize),
    queue: std.ArrayList(Cell),
    done: std.ArrayList(Cell),
    cell_set: CellSet,
    cells: []Cell,
    num_cols: usize,
    num_rows: usize,

    fn new(gpa: Allocator, cells: []Cell, num_rows: usize, num_cols: usize) Run {
        return Run {
            .gpa = gpa,
            .path = .empty,
            .queue = .empty,
            .done = .empty,
            .cell_set = .init(gpa),
            .cells = cells,
            .num_cols = num_cols,
            .num_rows = num_rows,
        };
    }

    fn deinit(self: *Run) void {
        self.path.deinit(self.gpa);
        self.queue.deinit(self.gpa);
        self.done.deinit(self.gpa);
        self.cell_set.deinit();
    }

    fn queue_add(self: *Run, cell: Cell) void { 
        const set_item = .{ cell.pos, cell.dir, cell.prev_dir_count };
        if (self.cell_set.get(set_item)) |_| {
            return;
        }

        self.cell_set.put(set_item, {}) catch unreachable();

        var found_pos: usize = 0;
        // Insert-ord
        for (self.queue.items) |other| {
            if (cell.distance >= other.distance) {
                break;
            }
            found_pos += 1;
        }

        self.queue.insert(self.gpa, found_pos, cell) catch unreachable();
    }

    fn solve(self: *Run) void {
        self.cells[0].distance = 0;
        self.queue_add(self.cells[0]);

        const target = self.cells[self.cells.len - 1].pos;

        while (self.queue.pop()) |cell| {
            self.done.append(self.gpa, cell) catch unreachable();

            if (cell.pos.eql(target)) {
                std.debug.print("min dist: {}\n", .{cell.distance});
                break;
            }

            const dirs: [4]Direction = .{.Left, .Right, .Up, .Down};
            for (dirs) |dir| {
                if ((dir == cell.dir and cell.prev_dir_count == 3) or dir == cell.dir.rev()) {
                    continue;
                }

                if (cell.pos.next_in_dir(dir, self.num_rows, self.num_cols)) |next_pos| {
                    const next_idx = self.num_cols * next_pos.row + next_pos.col;
                    var neigh = self.cells[next_idx];

                    neigh.distance = cell.distance + neigh.weight;
                    neigh.dir = dir;
                    neigh.prev_dir_count =
                        if (dir == cell.dir) cell.prev_dir_count + 1 else 1;

                    self.queue_add(neigh);
                }
            }

        }

        // self.output_path();
    }

    fn solve2(self: *Run) void {
        self.cells[0].distance = 0;
        self.queue_add(self.cells[0]);

        const target = self.cells[self.cells.len - 1].pos;

        while (self.queue.pop()) |cell| {
            self.done.append(self.gpa, cell) catch unreachable();

            if (cell.pos.eql(target)) {
                std.debug.print("min dist: {}\n", .{cell.distance});
                break;
            }

            const dirs: [4]Direction = .{.Left, .Right, .Up, .Down};
            for (dirs) |dir| {
                if (cell.prev_dir_count < 4 and dir != cell.dir and cell.dir != .None) {
                    continue;
                }

                if ((dir == cell.dir and cell.prev_dir_count == 10) or dir == cell.dir.rev()) {
                    continue;
                }

                if (cell.pos.next_in_dir(dir, self.num_rows, self.num_cols)) |next_pos| {
                    const next_idx = self.num_cols * next_pos.row + next_pos.col;
                    var neigh = self.cells[next_idx];

                    neigh.distance = cell.distance + neigh.weight;
                    neigh.dir = dir;
                    neigh.prev_dir_count =
                        if (dir == cell.dir) cell.prev_dir_count + 1 else 1;

                    self.queue_add(neigh);
                }
            }

        }

        std.debug.print("done count: {}\n", .{self.done.items.len});
        // self.output_path();
    }

    fn output_path(self: *Run) void {
        self.path.clearRetainingCapacity();

        {
            var start = self.done.getLast();

            while (true) {
                const pos = start.pos;
                const dir = start.dir;
                const idx = pos.to_index(self.num_cols);

                self.cells[idx] = start;
                self.path.insert(self.gpa, 0, idx) catch unreachable();

                if (pos.next_in_dir(dir.rev(), self.num_rows, self.num_cols)) |prev_pos| {
                    var found = false;
                    for (self.done.items) |cell| {
                        if (
                            cell.distance == start.distance - start.weight and
                            prev_pos.eql(cell.pos)
                        ) {
                            start = cell;
                            found = true;
                            break;
                        }
                    }
                    if (!found) {
                        break;
                    }
                } else {
                    break;
                }
            }
        }

        std.debug.print("path = {any}\n", .{self.path.items});

        // var col_count: usize = 0;
        // for (self.cells, 0..) |cell, n| {
        //     if (!cell.visited) {
        //         std.debug.print("{}", .{cell.weight});
        //     } else {
        //         std.debug.print("{c}", .{nodes[n].dir.get_char()});
        //     }

        //     col_count += 1;
        //     if (col_count == self.num_cols) {
        //         std.debug.print("\n", .{});
        //         col_count = 0;
        //     }
        // }

        std.debug.print("----\n\n", .{});

        var col_count: usize = 0;
        std.debug.print("<table>\n", .{});
        std.debug.print("<tr>\n", .{});
        for (self.cells, 0..) |cell, n| {
            if (std.mem.indexOfScalar(usize, self.path.items, n)) |_| {
                std.debug.print("<td style=\"background-color: blue\">\n", .{});
            } else {
                std.debug.print("<td>\n", .{});
            }

            std.debug.print("{}", .{cell.weight});
            std.debug.print("({c})<br>\n", .{cell.dir.get_char()});

            if (cell.distance == INF) {
                std.debug.print("(inf)<br>\n", .{});
            } else {
                std.debug.print("{}<br>\n", .{cell.distance});
            }
            std.debug.print("{}<br>\n", .{n});

            col_count += 1;
            if (col_count == self.num_cols) {
                std.debug.print("</tr>\n", .{});
                col_count = 0;
            }
            std.debug.print("</td>\n", .{});
        }
        std.debug.print("</tr>\n", .{});
        std.debug.print("</table>\n", .{});
    }

    fn get_new_neighbour_dist(self: *Run, idx: usize, neigh_idx: usize) ?struct {usize, Direction, usize} {
        const neigh = self.nodes[neigh_idx];
        const new_dist = self.nodes[idx].distance + self.cells[neigh_idx].weight;

        if (neigh.visited) {
            return null;
        }

        const dir = Direction.calc(idx, neigh_idx, self.num_cols);

        const node = self.nodes[idx];
        const dir_count =
            if (node.dir == dir) node.prev_dir_count + 1 else 1;

        if (dir_count >= 4 or dir.rev() == node.dir) {
            return null;
            // new_dist = INF;
        }

        return .{ new_dist, dir, dir_count };
    }
};

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var cells: std.ArrayList(Cell) = .empty;
    defer cells.deinit(gpa);

    var iter = std.mem.splitSequence(u8, content, "\n");

    var line_num: usize = 0;
    var column_count: usize = 0;

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        column_count = line.len;

        for (line, 0..) |v0, i| {
            const v = @as(usize, @intCast(v0 - '0'));
            const cell: Cell = .{
                .pos = .{ .row = line_num, .col = i },
                .weight = v,
                .distance = INF,
                .dir = .None,
                .prev_dir_count = 0,
            };

            try cells.append(gpa, cell);
        }

        line_num += 1;
        std.debug.print("| {s}\n", .{line});
    }

    // std.debug.print("{any}\n", .{ cells.items });

    var run = Run.new(gpa, cells.items, line_num, column_count);

    defer run.deinit();

    run.solve();
}

pub fn part2(gpa: Allocator, content: []const u8) !void {
    var cells: std.ArrayList(Cell) = .empty;
    defer cells.deinit(gpa);

    var iter = std.mem.splitSequence(u8, content, "\n");

    var line_num: usize = 0;
    var column_count: usize = 0;

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        column_count = line.len;

        for (line, 0..) |v0, i| {
            const v = @as(usize, @intCast(v0 - '0'));
            const cell: Cell = .{
                .pos = .{ .row = line_num, .col = i },
                .weight = v,
                .distance = INF,
                .dir = .None,
                .prev_dir_count = 0,
            };

            try cells.append(gpa, cell);
        }

        line_num += 1;
        std.debug.print("| {s}\n", .{line});
    }

    // std.debug.print("{any}\n", .{ cells.items });

    var run = Run.new(gpa, cells.items, line_num, column_count);

    defer run.deinit();

    run.solve2();
}
