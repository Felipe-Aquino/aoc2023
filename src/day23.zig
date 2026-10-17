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
    End = 'E',

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

        // if (curr.id == last_node.id) {
        //     std.debug.print("-------------\n", .{});
        //     break;
        // }
    }

    {
        var n: *Node = find_node_by_id(completed.items, last_node.id).?;
        n.in_path = true;

        // var max_iters: usize = 200;

        // while (n.id != first_node.id and max_iters > 1) {
        while (n.id != first_node.id) {
            // std.debug.print("id: {}\n", .{n.id});
            // grid.data.items[n.id] = .Occupied;

            for (completed.items) |*n2| {
                if (n2.id == n.previous) {
                    n2.in_path = true;
                    n = n2;
                    break;
                }
            }

            // max_iters -= 1;
        }

        // grid.data.items[n.id] = .Occupied;

        // grid.data.items[527] = .Occupied;
        // grid.data.items[448] = .End;


        n = find_node_by_id(completed.items, last_node.id).?;
        var max_path_distance: i32 = @intCast(@abs(n.distance));
        var count: i32 = 0;

        // std.debug.print("max_path_distance: {}\n", .{max_path_distance});
        while (n.id != first_node.id) {
            count += 1;

            if (n.previous) |prev| {
                for (completed.items) |c| {
                    if (c.previous != n.id and std.mem.indexOfScalar(usize, c.neighbours, n.id) != null) {
                        if (@abs(c.distance) + @abs(count) > @abs(max_path_distance)) {
                            max_path_distance = @intCast(@abs(c.distance) + @abs(count));
                            // std.debug.print("max_path_distance: {} - {} | c = {}, n = {}\n", .{max_path_distance, count, c.id, n.id});
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

    // for (completed.items) |n| {
    //     std.debug.print("{any}\n", .{n});
    // }

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

fn bfs(gpa: Allocator, nodes: []Node, first_node_id: usize) void {
    var list: std.ArrayList(*Node) = .empty;
    defer list.deinit(gpa);

    const first = find_node_by_id(nodes, first_node_id).?;
    list.append(gpa, first) catch unreachable();

    while (list.items.len > 0) {
        const initial_size = list.items.len;

        const items = list.items;
        for (items) |item| {
            for (item.neighbours) |neigh_id| {
                const neigh = find_node_by_id(nodes, neigh_id).?;

                if (neigh.distance < item.distance + 1 and neigh.previous != item.id) {
                    neigh.distance = item.distance + 1;
                    neigh.previous = item.id;

                    list.append(gpa, neigh) catch unreachable();
                }
            }
        }

        list.replaceRange(gpa, 0, initial_size, &.{}) catch unreachable();
        std.debug.print("{}\n", .{list.items.len});
    }
}
