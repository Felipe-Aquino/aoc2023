const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

const Coord = struct {
    row: usize,
    col: usize,
};

fn slice_sum(s: []usize) usize {
    var total: usize = 0;
    for (s) |v| {
        total += v;
    }

    return total;
}

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var star_coords: std.ArrayList(Coord) = .empty;
    var line_heights: std.ArrayList(usize) = .empty;
    var col_widths: std.ArrayList(usize) = .empty;
    
    defer {
        star_coords.deinit(gpa);
        line_heights.deinit(gpa);
        col_widths.deinit(gpa);
    }

    var iter = std.mem.splitSequence(u8, content, "\n");
    var i: usize = 0;

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        if (i == 0) {
             try col_widths.appendNTimes(gpa, 2, line.len);
        }

        var line_is_empty = true;
        for (line, 0..) |c, j| {
            if (c == '#') {
                try star_coords.append(gpa, .{ .row = i, .col = j });
                line_is_empty = false;

                if (col_widths.items[j] == 2) {
                    col_widths.items[j] = 1;
                }
            }
        }

        const line_height: usize = if (line_is_empty) 2 else 1;
        try line_heights.append(gpa, line_height);

        i += 1;
    }


    // std.debug.print("{}\n", .{ star_coords });
    // std.debug.print("{}\n", .{ line_heights });
    // std.debug.print("{}\n", .{ col_widths });

    var result: usize = 0;

    for (0..star_coords.items.len) |j| {
        const coord1 = star_coords.items[j];
        for (j+1..star_coords.items.len) |k| {
            const coord2 = star_coords.items[k];
            const col1 = @min(coord1.col, coord2.col);
            const col2 = coord1.col + coord2.col - col1;

            const cols = col_widths.items[col1..col2];


            const row1 = @min(coord1.row, coord2.row);
            const row2 = coord1.row + coord2.row - row1;

            const lines = line_heights.items[row1..row2];

            const total = slice_sum(cols) + slice_sum(lines);
            result += total;

            // std.debug.print("{} -> {}: {}\n", .{ coord1, coord2, total });
        }
    }

    std.debug.print("result = {}\n", .{result});
}

pub fn part2(gpa: Allocator, content: []const u8) !void {
    _ = gpa;
    _ = content;
    unreachable();
}
