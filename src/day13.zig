const std = @import("std");

const Allocator = std.mem.Allocator;

fn compare_rows(pattern: [][]const u8, r1: usize, r2: usize) bool {
    // std.debug.print("  {}: {s}\n  {}: {s}\n", .{ r1, pattern[r1], r2, pattern[r2] });
    return std.mem.eql(u8, pattern[r1], pattern[r2]);
}

fn compare_columns(pattern: [][]const u8, c1: usize, c2: usize) bool {
    for (0..pattern.len) |i| {
        // std.debug.print("  {}: {s}\n  {}: {s}\n", .{ r1, pattern[r1], r2, pattern[r2] });
        if (pattern[i][c1] != pattern[i][c2]) {
            return false;
        }
    }

    return true;
}

fn perfect_vertical_reflection_count(pattern: [][]const u8) usize {
    const row_count = pattern.len;

    var max_row_dist: usize = 0;
    var max_row_dist_idx: usize = 0;

    for (0..row_count - 1) |i| {
        var match = true;

        const n = @min(i + 1, row_count - i - 1);

        if (max_row_dist > n) {
            continue;
        }

        for (0..n) |k| {
            if (!compare_rows(pattern, i - k, i + k + 1)) {
                match = false;
                break;
            }
        }

        if (match) {
            max_row_dist = n;
            max_row_dist_idx = i;
        }

        // std.debug.print("i = {}, n = {}, max_row_dist = {}, max_row_dist_idx = {} \n", .{
        //     i, n,
        //     max_row_dist,
        //     max_row_dist_idx,
        // });
    }

    // std.debug.print("max_row_dist = {}, max_row_dist_idx = {} \n", .{
    //     max_row_dist,
    //     max_row_dist_idx,
    // });

    return if (max_row_dist > 0) (max_row_dist_idx + 1) else 0;
}

fn perfect_horizontal_reflection_count(pattern: [][]const u8) usize {
    const col_count = pattern[0].len;

    var max_col_dist: usize = 0;
    var max_col_dist_idx: usize = 0;

    for (0..col_count - 1) |i| {
        var match = true;

        const n = @min(i + 1, col_count - i - 1);

        if (max_col_dist > n) {
            continue;
        }

        for (0..n) |k| {
            if (!compare_columns(pattern, i - k, i + k + 1)) {
                match = false;
                break;
            }
        }

        if (match) {
            max_col_dist = n;
            max_col_dist_idx = i;
        }

        // std.debug.print("i = {}, n = {}, max_col_dist = {}, max_col_dist_idx = {} \n", .{
        //     i, n,
        //     max_col_dist,
        //     max_col_dist_idx,
        // });
    }

    // std.debug.print("max_col_dist = {}, max_col_dist_idx = {} \n", .{
    //     max_col_dist,
    //     max_col_dist_idx,
    // });

    return if (max_col_dist > 0) (max_col_dist_idx + 1) else 0;
}

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var pattern: std.ArrayList([]const u8) = .empty;
    defer pattern.deinit(gpa);

    var iter = std.mem.splitSequence(u8, content, "\n");

    var summary_total: usize = 0;

    while (iter.next()) |line| {
        if (line.len == 0) {
            const vertical_count = perfect_vertical_reflection_count(pattern.items);
            const horizontal_count = perfect_horizontal_reflection_count(pattern.items);

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
