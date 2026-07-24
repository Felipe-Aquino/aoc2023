const std = @import("std");

const Allocator = std.mem.Allocator;

fn hash_step(step: []const u8) usize {
    var current_value: usize = 0;

    for (step) |c| {
        current_value = @rem(17 * (current_value + @as(usize, @intCast(c))), 256);
    }

    return current_value;
}

pub fn part1(gpa: Allocator, content: []const u8) !void {
    _ = gpa;

    const sequence = read_seq: {
        var iter = std.mem.splitSequence(u8, content, "\n");
        break :read_seq iter.next().?;
    };

    var steps_iter = std.mem.splitSequence(u8, sequence, ",");
    var total: usize = 0;

    while (steps_iter.next()) |step| {
        const v = hash_step(step);
        std.debug.print(">> {s} :: {}\n", .{ step, v });

        total += v;
    }


    std.debug.print("sum of results = {}\n", .{ total });
}
