const std = @import("std");

const Allocator = std.mem.Allocator;

const INF: i32 = 2_000_000;

const Tile = enum(u8) {
    Tree = '#',
    Path = '.',
    Up = '^',
    Down = 'v',
    Left = '<',
    Right = '>',
    Occupied = '0',

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

const Node = struct {
    id: usize,
    neighbours: []usize,
    previous: ?usize,
    distance: i64,
    in_path: bool,
};

fn find_node_by_id(nodes: []Node, id: usize) ?*Node {
    for (nodes) |*n| {
        if (n.id == id) {
            return n;
        }
    }

    return null;
}

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var grid: Grid(Tile) = .init(gpa);
    defer grid.deinit();

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        try grid.push_row(line, Tile.from_u8);
    }

    print_tile_grid(grid);

    var arena: std.heap.ArenaAllocator = .init(gpa);
    var arena_alloc = arena.allocator();
    defer arena.deinit();

    var nodes: std.ArrayList(Node) = .empty;
    var completed: std.ArrayList(Node) = .empty;
    defer {
        nodes.deinit(gpa);
        completed.deinit(gpa);
    }

    var neighs: [4]usize = .{0, 0, 0, 0};
    var neigh_count: usize = 0;
    for (grid.data.items, 0..) |tile, i| {
        if (tile == .Tree) continue;

        neigh_count = 0;

        const row = i / grid.nrows;
        const col = @mod(i, grid.nrows);

        if ((tile == .Up or tile == .Path) and row > 1) {
            const n = grid.get(row - 1, col);

            if (n != .Tree and n != .Down) {
                neighs[neigh_count] = (row - 1) * grid.nrows + col;
                neigh_count += 1;
            }
        }

        if ((tile == .Down or tile == .Path) and row < grid.nrows - 1) {
            const n = grid.get(row + 1, col);

            if (n != .Tree and n != .Up) {
                neighs[neigh_count] = (row + 1) * grid.nrows + col;
                neigh_count += 1;
            }
        }

        if ((tile == .Left or tile == .Path) and col > 1) {
            const n = grid.get(row, col - 1);

            if (n != .Tree and n != .Right) {
                neighs[neigh_count] = row * grid.nrows + col - 1;
                neigh_count += 1;
            }
        }

        if ((tile == .Right or tile == .Path) and col < grid.ncols - 1) {
            const n = grid.get(row, col + 1);

            if (n != .Tree and n != .Left) {
                neighs[neigh_count] = row * grid.nrows + col + 1;
                neigh_count += 1;
            }
        }

        if (neigh_count == 0) {
            continue;
        }

        const node: Node = .{
            .id = i,
            .neighbours = try arena_alloc.dupe(usize, neighs[0..neigh_count]),
            .previous = null,
            .distance = if (i == 1) 0 else INF,
            .in_path = false,
        };

        try nodes.append(gpa, node);
    }

    const last_node = nodes.getLast();
    const first_node = nodes.orderedRemove(0);
    var current_node: ?Node = first_node;

    while (current_node) |*curr| {
        for (curr.neighbours) |neigh_idx| {
            const neigh = find_node_by_id(nodes.items, neigh_idx);

            if (neigh) |n2| {
                if (n2.distance > curr.distance - 1) {
                    n2.distance = curr.distance - 1;
                    n2.previous = curr.id;
                }
            }
        }

        try completed.append(gpa, curr.*);

        var min_distance: i64 = INF;
        var min_distance_id: ?usize = null;
        for (nodes.items, 0..) |node, i| {
            if (min_distance > node.distance) {
                min_distance = node.distance;
                min_distance_id = i;
            }
        }

        if (min_distance_id) |id| {
            current_node = nodes.orderedRemove(id);
        } else if (nodes.items.len > 0) {
            current_node = nodes.orderedRemove(0);
        } else {
            current_node = null;
        }
    }

    {
        var n: *Node = find_node_by_id(completed.items, last_node.id).?;
        n.in_path = true;

        while (n.id != first_node.id) {
            // grid.data.items[n.id] = .Occupied;

            for (completed.items) |*n2| {
                if (n2.id == n.previous) {
                    n2.in_path = true;
                    n = n2;
                    break;
                }
            }
        }

        // grid.data.items[n.id] = .Occupied;


        n = find_node_by_id(completed.items, last_node.id).?;
        var max_path_distance: i32 = @intCast(@abs(n.distance));
        var count: i32 = 0;

        while (n.id != first_node.id) {
            count += 1;

            if (n.previous) |prev| {
                for (completed.items) |c| {
                    if (c.previous != n.id and std.mem.indexOfScalar(usize, c.neighbours, n.id) != null) {
                        if (@abs(c.distance) + @abs(count) > @abs(max_path_distance)) {
                            max_path_distance = @intCast(@abs(c.distance) + @abs(count));
                            std.debug.print("max_path_distance: {} - {} | c = {}, n = {}\n", .{max_path_distance, count, c.id, n.id});
                        }
                    }
                }

                n = find_node_by_id(completed.items, prev).?;
            }
        }

        std.debug.print("max_path_distance: {}\n", .{max_path_distance});
    }

    // print_tile_grid(grid);

    // try output_path("out.html", grid, completed.items);

    std.debug.print("start: {}\n", .{first_node.id});
    std.debug.print("end: {}\n", .{last_node.id});
    std.debug.print("sz: {}\n", .{completed.items.len});
}

fn parse_dir(src: usize, dst: usize) u8 {
    if (src < dst) {
        if (dst - src == 1) {
            return '>';
        } else {
            return 'v';
        }
    } else {
        if (src - dst == 1) {
            return '<';
        } else {
            return '^';
        }
    }
}

fn output_path(filename: []const u8, grid: Grid(Tile), nodes: []Node) !void {
    const file = try std.fs.cwd().createFile(
        filename,
        .{ .read = true, .truncate = true },
    );
    defer file.close();

    var buffer: [1024]u8 = undefined;

    var col_count: usize = 0;
    _ = try file.write(
\\<html>
\\    <header>
\\    <style>
\\       table, th, td {
\\         border: 1px solid black;
\\       }
\\       td {
\\         padding: 3px;
\\       }
\\    </style>
\\    </header>
\\<body>
\\
    );
    _ = try file.write("<table>\n");
    _ = try file.write("<tr>\n");

    for (grid.data.items, 0..) |cell, n| {
        var found: ?Node = null;

        for (nodes) |item| {
            if (item.id == n) {
                found = item;
                break;
            }
        }

        if (found != null and found.?.in_path) {
            _ = try file.write("<td style=\"background-color: blue\">\n");
        } else {
            _ = try file.write("<td>\n");
        }

        {
            var v = try std.fmt.bufPrint(buffer[0..], "{c}<br>\n", .{@intFromEnum(cell)});
            _ = try file.write(v);
            if (found) |f| {
                v = try std.fmt.bufPrint(buffer[0..], "{}<br>\n", .{f.id});
                _ = try file.write(v);

                v = try std.fmt.bufPrint(buffer[0..], "{}\n", .{f.distance});
                _ = try file.write(v);

                if (f.previous) |prev| {
                    v = try std.fmt.bufPrint(buffer[0..], "({c})<br>\n", .{parse_dir(prev, f.id)});
                    _ = try file.write(v);
                }
            }
        }

        col_count += 1;
        if (col_count == grid.ncols) {
            _ = try file.write("</tr>\n");
            col_count = 0;
        }
        _ = try file.write("</td>\n");
    }
    _ = try file.write("</tr>\n");
    _ = try file.write("</table>\n");
    _ = try file.write("</body>\n</html>\n");
}

const Segment = struct {
    start: usize,
    end: usize,
    count: usize,

    fn eql(self: Segment, other: Segment) bool {
        return (self.start == other.start and self.end == other.end) or
               (self.start == other.end and self.end == other.start);
    }
};

const Junction = struct {
    id: usize,
    segments: [4]Segment,
    // junctions: [4]*Junction,
    neighbours_count: usize,

    fn segments_slice(self: *Junction) []const Segment {
        if (self.neighbours_count == 0) return &.{};
        return self.segments[0..self.neighbours_count];
    }
};

fn read_junction_from_nodes(gpa: Allocator, nodes: []Node) !std.ArrayList(Junction) {
    var junctions: std.ArrayList(Junction) = .empty;

    for (nodes) |node| {
        if (node.neighbours.len != 2) {
            const segments: [4]Segment = [1]Segment{ .{ .start = 0, .end = 0, .count = 0 } } ** 4;

            var junc = Junction {
                .id = node.id,
                .segments = segments,
                .neighbours_count = 0,
            };

            for (node.neighbours) |neigh_id| {
                var seg: Segment = .{
                    .start = node.id,
                    .end = node.id,
                    .count = 0,
                };

                var neigh = find_node_by_id(nodes, neigh_id).?;

                while (true) {
                    if (neigh.neighbours.len == 2) {
                        const next_id =
                            if (neigh.neighbours[0] != seg.end) neigh.neighbours[0]
                            else neigh.neighbours[1];

                        seg.end = neigh.id;
                        seg.count += 1;
                        neigh = find_node_by_id(nodes, next_id).?;
                    } else {
                        seg.end = neigh.id;
                        seg.count += 1;
                        break;
                    }
                }

                junc.segments[junc.neighbours_count] = seg;
                junc.neighbours_count += 1;
            }

            try junctions.append(gpa, junc);
        }
    }

    return junctions;
}


fn find_junction_by_id(junctions: []Junction, id: usize) ?Junction {
    for (junctions) |j| {
        if (j.id == id) {
            return j;
        }
    }

    return null;
}

fn dfs(
    gpa: Allocator,
    junctions: []Junction,
    end_junction_id: usize,
    path: *std.ArrayList(usize),
    path_distance: *usize,
    max_path_distance: *usize,
) void {
    const last_id = path.getLast();

    if (last_id == end_junction_id or path.items.len == 0) {
        if (path_distance.* > max_path_distance.*) {
            std.debug.print("last = {}, size = {}, max = {}\n", .{last_id, path_distance.*, max_path_distance.*});
            max_path_distance.* = path_distance.*;
        }

        return;
    }

    const last = find_junction_by_id(junctions, last_id).?;

    for (0..last.neighbours_count) |i| {
        const s = last.segments[i];
        if (std.mem.indexOfScalar(usize, path.items, s.end) == null) {
            path.append(gpa, s.end) catch unreachable();

            path_distance.* = path_distance.* + s.count;

            dfs(gpa, junctions, end_junction_id, path, path_distance, max_path_distance);

            path_distance.* = path_distance.* - s.count;
            _ = path.pop();
        }
    }
}

pub fn part2(gpa: Allocator, content: []const u8) !void {
    var grid: Grid(Tile) = .init(gpa);
    defer grid.deinit();

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        try grid.push_row(line, Tile.from_u8);
    }

    print_tile_grid(grid);

    var arena: std.heap.ArenaAllocator = .init(gpa);
    var arena_alloc = arena.allocator();
    defer arena.deinit();

    var nodes: std.ArrayList(Node) = .empty;
    var completed: std.ArrayList(Node) = .empty;
    defer {
        nodes.deinit(gpa);
        completed.deinit(gpa);
    }

    var neighs: [4]usize = .{0, 0, 0, 0};
    var neigh_count: usize = 0;
    for (grid.data.items, 0..) |tile, i| {
        if (tile == .Tree) continue;

        neigh_count = 0;

        const row = @divFloor(i, grid.nrows);
        const col = @mod(i, grid.nrows);

        if (row >= 1) {
            const n = grid.get(row - 1, col);

            if (n != .Tree) {
                neighs[neigh_count] = (row - 1) * grid.nrows + col;
                neigh_count += 1;
            }
        }

        if (row < grid.nrows - 1) {
            const n = grid.get(row + 1, col);

            if (n != .Tree) {
                neighs[neigh_count] = (row + 1) * grid.nrows + col;
                neigh_count += 1;
            }
        }

        if (col > 1) {
            const n = grid.get(row, col - 1);

            if (n != .Tree) {
                neighs[neigh_count] = row * grid.nrows + col - 1;
                neigh_count += 1;
            }
        }

        if (col < grid.ncols - 1) {
            const n = grid.get(row, col + 1);

            if (n != .Tree) {
                neighs[neigh_count] = row * grid.nrows + col + 1;
                neigh_count += 1;
            }
        }

        if (neigh_count == 0) {
            continue;
        }

        const node: Node = .{
            .id = i,
            .neighbours = try arena_alloc.dupe(usize, neighs[0..neigh_count]),
            .previous = null,
            .distance = if (i == 1) 0 else INF,
            .in_path = false,
        };

        try nodes.append(gpa, node);
    }

    var junctions = try read_junction_from_nodes(gpa, nodes.items);
    defer junctions.deinit(gpa);

    for (junctions.items) |junc| {
        std.debug.print("[{}]: \n", .{ junc.id, });
        for (0..junc.neighbours_count) |i| {
            // std.debug.print("- {} => {}\n", .{ junc.junctions[i].id, junc.segments[i] });
            std.debug.print("- {}\n", .{ junc.segments[i] });
        }
    }

    var path: std.ArrayList(usize) = .empty;
    defer path.deinit(gpa);

    try path.append(gpa, junctions.items[0].id);

    const last_node = nodes.getLast();

    var path_distance: usize = 0;
    var max_path_distance: usize = 0;

    std.debug.print("junctions count = {}\n", .{junctions.items.len});

    dfs(gpa, junctions.items, last_node.id, &path, &path_distance, &max_path_distance);

    std.debug.print("max_path_distance = {}\n", .{max_path_distance});
}
