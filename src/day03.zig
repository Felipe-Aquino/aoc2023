const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

fn is_digit(v: u8) bool {
    return switch (v) {
        '0'...'9' => true,
        else => false
    };
}

fn to_digit(v: u8) usize {
    return @as(usize, @intCast(v - '0'));
}

fn as_isize(value: usize) isize {
    return @as(isize, @intCast(value));
}

fn as_usize(value: isize) usize {
    return @as(usize, @intCast(value));
}

fn look_around_for_symbols(grid: std.ArrayList([]const u8), i: usize, j: usize) bool {
    const positions: [8]struct { isize, isize } = .{
        .{-1, -1}, .{ -1, 0 }, .{ -1, 1 },
        .{0, -1}, .{ 0, 1 },
        .{1, -1}, .{ 1, 0 }, .{ 1, 1 }
    };

    const lines_count = as_isize(grid.items.len);

    for (positions) |pos| {
        const ni = as_isize(i) + pos[0];
        const nj = as_isize(j) + pos[1];

        if (ni >= 0 and ni < lines_count) {
            const line = grid.items[as_usize(ni)];

            if (nj > 0 and nj < line.len) {
                const c = line[as_usize(nj)];
                if (!is_digit(c) and c != '.') {
                    return true;
                }
            }
        }
    }

    return false;
}

fn part1(gpa: Allocator, content: []u8) !void {
    var grid: std.ArrayList([]const u8) = .empty;

    var sum: usize = 0;

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len > 0) {
            try grid.append(gpa, line);
        }
    }

    for (grid.items, 0..) |line, i| {
        var part_number: usize = 0;
        var is_adjacent_to_symbol: bool = false;
        var is_parsing = false;

        for (line, 0..) |c, j| {
            if (is_parsing) {
                if (is_digit(c)) {
                    part_number = 10 * part_number + to_digit(c);

                    if (!is_adjacent_to_symbol) {
                        is_adjacent_to_symbol = look_around_for_symbols(grid, i, j);
                    }
                } else {
                    if (is_adjacent_to_symbol) {
                        std.debug.print("| {}\n", .{part_number});
                        sum += part_number;
                    }

                    is_parsing = false;
                    part_number = 0;
                }
            } else if (is_digit(c)) {
                is_parsing = true;
                part_number = to_digit(c);

                is_adjacent_to_symbol = look_around_for_symbols(grid, i, j);
            }
        }

        if (is_parsing and is_adjacent_to_symbol) {
            std.debug.print("| {}\n", .{part_number});
            sum += part_number;
        }
    }

    std.debug.print("sum = {}\n", .{sum});
}

fn part2(gpa: Allocator, content: []u8) !void {
    _ = gpa;
    _ = content;
    unreachable();
}

pub fn main() !void {
    // const file_path = "./inputs/day03-example.txt";
    const file_path = "./inputs/day03.txt";

    const gpa = std.heap.page_allocator;
    const content = try utils.read_file(gpa, file_path);
    defer gpa.free(content);

    if (utils.is_part1()) {
        try part1(gpa, content);
    } else {
        try part2(gpa, content);
    }
}

