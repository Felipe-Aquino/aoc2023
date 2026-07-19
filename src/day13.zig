const std = @import("std");

const Allocator = std.mem.Allocator;

fn compare_rows(pattern: []const []const u8, r1: usize, r2: usize) usize {
    var count: usize = 0;
    for (0..pattern[0].len) |i| {
        if (pattern[r1][i] != pattern[r2][i]) {
            count += 1;
        }
    }

    return count;
}

fn compare_columns(pattern: []const []const u8, c1: usize, c2: usize) usize {
    var count: usize = 0;
    for (0..pattern.len) |i| {
        if (pattern[i][c1] != pattern[i][c2]) {
            count += 1;
        }
    }

    return count;
}

fn perfect_vertical_reflection_count(pattern: []const []const u8, smudge_count: usize) usize {
    const row_count = pattern.len;

    for (0..row_count - 1) |i| {
        var match: usize = 0;

        const n = @min(i + 1, row_count - i - 1);

        for (0..n) |k| {
            match += compare_rows(pattern, i - k, i + k + 1);
        }

        if (match == smudge_count) {
            return i + 1;
        }
    }

    return 0;
}

fn perfect_horizontal_reflection_count(pattern: []const []const u8, smudge_count: usize) usize {
    const col_count = pattern[0].len;

    for (0..col_count - 1) |i| {
        var match: usize = 0;

        const n = @min(i + 1, col_count - i - 1);

        for (0..n) |k| {
            match += compare_columns(pattern, i - k, i + k + 1);
        }

        if (match == smudge_count) {
            return i + 1;
        }
    }

    return 0;
}

pub fn solve(gpa: Allocator, content: []const u8, smudge_count: usize) !void {
    var pattern: std.ArrayList([]const u8) = .empty;
    defer pattern.deinit(gpa);

    var iter = std.mem.splitSequence(u8, content, "\n");

    var summary_total: usize = 0;

    while (iter.next()) |line| {
        if (line.len == 0) {
            const vertical_count =
                perfect_vertical_reflection_count(pattern.items, smudge_count);
            const horizontal_count =
                perfect_horizontal_reflection_count(pattern.items, smudge_count);

            std.debug.print("vertical_count   = {} \n", .{ vertical_count });
            std.debug.print("horizontal_count = {} \n", .{ horizontal_count });
            std.debug.print("-------\n", .{});

            summary_total += 100 * vertical_count + horizontal_count;
            pattern.clearRetainingCapacity();
        } else {
            try pattern.append(gpa, line);
        }

        // std.debug.print("| {s}\n", .{line});
    }

    std.debug.print("summary total = {}\n", .{ summary_total });
}

pub fn part1(gpa: Allocator, content: []const u8) !void {
    try solve(gpa, content, 0);
}

pub fn part2(gpa: Allocator, content: []const u8) !void {
    try solve(gpa, content, 1);
}
