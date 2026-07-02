const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var iter = std.mem.splitSequence(u8, content, "\n");

    var values: std.ArrayList(i32) = .empty;
    // var last_values: std.ArrayList(i32) = .empty;

    defer {
        values.deinit(gpa);
        // last_values.deinit(gpa);
    }

    var sum: i32 = 0;
    while (iter.next()) |line| {
        if (line.len == 0) continue;

        std.debug.print("| {s}\n", .{line});
        
        var iter2 = std.mem.splitSequence(u8, line, " ");

        while (iter2.next()) |value_str| {
            const value = try std.fmt.parseInt(i32, value_str, 10);

            try values.append(gpa, value);
        }

        // try last_values.append(gpa, values.getLast());
        var extrapolated = values.getLast();

        var all_equal = false;
        var size = values.items.len;
        // var last: i32 = last_values.getFirst();

        while (!all_equal) {
            all_equal = true;
            var x: ?i32 = null;
            for (0..size - 1) |i| {
                const diff = values.items[i + 1] - values.items[i];
                values.items[i] = diff;

                if (x) |v| {
                    all_equal = all_equal and (v == diff);
                } else {
                    x = diff;
                }
            }

            size -= 1;

            extrapolated += values.items[size - 1];
            // try last_values.append(gpa, values.items[size - 1]);
            // std.debug.print("| {any}\n", .{values.items[0..size]});
        }

        sum += extrapolated;
        std.debug.print("> extrapolated = {}\n", .{extrapolated});

        // std.debug.print("> {any}\n", .{last_values.items});
        values.clearRetainingCapacity();
        // last_values.clearRetainingCapacity();
    }

    std.debug.print("sum of extrapolated = {}\n", .{sum});
}

pub fn part2(gpa: Allocator, content: []const u8) !void {
    _ = gpa;
    _ = content;
}
