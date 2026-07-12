const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

pub fn solve(data: []const u8, damaged: []usize) usize {
    if (damaged.len == 0) {
        for (data) |c| {
            if (c == '#') {
                return 0;
            }
        }

        // std.debug.print("1.. \n", .{});
        return 1;
    }

    var count: usize = 0;
    var i: usize = 0;

    while (i < data.len): (i += 1) {
        const c = data[i];

        if (c == '#' or c == '?') {
            const d = damaged[0];
            var j: usize = 0;

            while (j < d and i + j < data.len): (j += 1) {
                if (data[i + j] == '.') {
                    break;
                }
            }

            if (j == d) {
                // std.debug.print(">.. {s} - {}, {} -- {}\n", .{data, d, i, count});
                if (i + j == data.len) {
                    if (damaged.len == 1) {
                        count += 1;
                        // std.debug.print("2.. {s} - {} -- {}\n", .{data, d, count});
                        break;
                    }
                } else if (data[i + j] != '#') {
                    count += solve(data[i + j + 1..], damaged[1..]);
                }
            }

            if (c == '#') {
                break;
            }
        }
    }

    return count;
}

const Map = std.AutoHashMap(struct {usize, usize, usize}, usize);

pub fn solve2(map: *Map, data: []const u8, damaged: []usize) usize {
    if (damaged.len == 0) {
        for (data) |c| {
            if (c == '#') {
                return 0;
            }
        }

        // std.debug.print("1.. \n", .{});
        return 1;
    }

    var count: usize = 0;
    var i: usize = 0;

    while (i < data.len): (i += 1) {
        const c = data[i];

        if (c == '#' or c == '?') {
            const d = damaged[0];
            var j: usize = 0;

            while (j < d and i + j < data.len): (j += 1) {
                if (data[i + j] == '.') {
                    break;
                }
            }

            if (j == d) {
                // std.debug.print(">.. {s} - {}, {} -- {}\n", .{data, d, i, count});
                if (i + j == data.len) {
                    if (damaged.len == 1) {
                        count += 1;
                        // std.debug.print("2.. {s} - {} -- {}\n", .{data, d, count});
                        break;
                    }
                } else if (data[i + j] != '#') {
                    if (map.get(.{data.len, i, damaged.len - 1})) |amount| {
                        count += amount;
                    } else {
                        const amount = solve2(map, data[i + j + 1..], damaged[1..]);
                        map.put(.{data.len, i, damaged.len - 1}, amount) catch unreachable();

                        count += amount;
                    }
                }
            }

            if (c == '#') {
                break;
            }
        }
    }

    return count;
}

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var damaged: std.ArrayList(usize) = .empty;
    defer damaged.deinit(gpa);

    var iter = std.mem.splitSequence(u8, content, "\n");

    var arrangement_count: usize = 0;

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        var part_iter = std.mem.splitSequence(u8, line, " ");
        const data = part_iter.next().?;

        const damaged_str = part_iter.next().?;
        var damaged_iter = std.mem.splitSequence(u8, damaged_str, ",");

        while (damaged_iter.next()) |value_str| {
            const value = try std.fmt.parseInt(usize, value_str, 10);

            try damaged.append(gpa, value);
        }

        const count = solve(data, damaged.items);
        arrangement_count += count;

        std.debug.print("{s} | {} | {}\n", .{data, damaged, count});
        damaged.clearRetainingCapacity();
    }

    std.debug.print("arrangement count: {}\n", .{ arrangement_count });
}

pub fn part2(gpa: Allocator, content: []const u8) !void {
    var damaged: std.ArrayList(usize) = .empty;
    var extended: std.ArrayList(u8) = .empty;
    var map: Map = .init(gpa);

    defer {
        damaged.deinit(gpa);
        extended.deinit(gpa);
        map.deinit();
    }

    var iter = std.mem.splitSequence(u8, content, "\n");

    var arrangement_count: usize = 0;

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        var part_iter = std.mem.splitSequence(u8, line, " ");
        const data = part_iter.next().?;

        const damaged_str = part_iter.next().?;
        var damaged_iter = std.mem.splitSequence(u8, damaged_str, ",");

        while (damaged_iter.next()) |value_str| {
            const value = try std.fmt.parseInt(usize, value_str, 10);

            try damaged.append(gpa, value);
        }

        const damaged_size = damaged.items.len;

        try extended.appendSlice(gpa, data);
        for (0..4) |_| {
            try extended.append(gpa, '?');
            try extended.appendSlice(gpa, data);
            try damaged.appendSlice(gpa, damaged.items[0..damaged_size]);
        }

        const count = solve2(&map, extended.items, damaged.items);
        arrangement_count += count;

        std.debug.print("{s} | {} | {}\n", .{data, damaged, count});
        damaged.clearRetainingCapacity();
        extended.clearRetainingCapacity();
        map.clearRetainingCapacity();
    }

    std.debug.print("arrangement count: {}\n", .{ arrangement_count });
}
