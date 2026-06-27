const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

const Record = struct {
    time: f64,
    distance: f64,
};

fn part1(gpa: Allocator, content: []const u8) !void {
    var records: std.ArrayList(Record) = .empty;
    defer records.deinit(gpa);

    var iter = std.mem.splitSequence(u8, content, "\n");

    const time_line = std.mem.trimStart(u8, iter.next().?, "Time:");
    const dist_line = std.mem.trimStart(u8, iter.next().?, "Distance:");

    var times_iter = std.mem.splitSequence(u8, time_line, " ");
    var dists_iter = std.mem.splitSequence(u8, dist_line, " ");

    while (times_iter.next()) |time_str| {
        if (time_str.len == 0) continue;

        while (dists_iter.next()) |dist_str| {
            if (dist_str.len == 0) continue;

            const time = try std.fmt.parseFloat(f64, time_str);
            const dist = try std.fmt.parseFloat(f64, dist_str);

            const record: Record = . { .time = time, .distance = dist };

            try records.append(gpa, record);

            break;
        }
    }

    std.debug.print("records = {}\n", .{ records });

    var number_of_ways: f64 = 1;

    for (records.items) |record| {
        // -t**2 + record.time*t - record.distance = 0
        var low_time = @ceil(
            (record.time - @sqrt(record.time * record.time - 4 * record.distance)) / 2.0
        );

        const low_dist = low_time * (record.time - low_time);
        if (low_dist == record.distance) {
            low_time += 1;
        }

        // -2*t + record.time = 0
        // t = record.time / 2
        const peak_time = @floor(record.time / 2.0);

        const diff = peak_time - low_time;
        const count =
            if (@rem(record.time, 2.0) == 0.0)
                2 * diff + 1
            else
                2 * (diff + 1);

        // std.debug.print("low_time = {}\n", .{ low_time });
        // std.debug.print("peak_time = {}\n", .{ peak_time });
        // std.debug.print("count = {}\n", .{ count });

        number_of_ways *= count;
    }

    std.debug.print("number of ways = {}\n", .{ number_of_ways });
}

fn part2(gpa: Allocator, content: []const u8) !void {
    _ = gpa;
    _ = content;
    unreachable();
}

pub fn main() !void {
    // const file_path = "./inputs/day06-example.txt";
    const file_path = "./inputs/day06.txt";

    const gpa = std.heap.page_allocator;
    const content = try utils.read_file(gpa, file_path);
    defer gpa.free(content);

    if (utils.is_part1()) {
        try part1(gpa, content);
    } else {
        try part2(gpa, content);
    }
}
