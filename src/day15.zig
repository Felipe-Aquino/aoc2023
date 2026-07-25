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

const Lens = struct {
    label: []const u8,
    focal_length: usize,
};

fn find_lens_index_by_label(lenses: []const Lens, label: []const u8) ?usize {
    for (lenses, 0..) |lens, i| {
        if (std.mem.eql(u8, lens.label, label)) {
            return i;
        }
    }

    return null;
}

pub fn part2(gpa: Allocator, content: []const u8) !void {
    const sequence = read_seq: {
        var iter = std.mem.splitSequence(u8, content, "\n");
        break :read_seq iter.next().?;
    };

    var steps_iter = std.mem.splitSequence(u8, sequence, ",");

    var boxes = [_]std.ArrayList(Lens){ .empty } ** 256;

    defer {
        for (&boxes) |*box| {
            box.deinit(gpa);
        }
    }

    while (steps_iter.next()) |step| {
        var step1 = std.mem.trim(u8, step, " ");

        if (std.mem.indexOf(u8, step1, "-")) |idx| {
            const label = step1[0..idx];
            const box_idx = hash_step(label);

            if (find_lens_index_by_label(boxes[box_idx].items, label)) |lens_idx| {
                _ = boxes[box_idx].orderedRemove(lens_idx);
            }
        } else if (std.mem.indexOf(u8, step1, "=")) |idx| {
            const label = step1[0..idx];
            const value = try std.fmt.parseInt(usize, step1[idx + 1..], 10);
            const box_idx = hash_step(label);

            if (find_lens_index_by_label(boxes[box_idx].items, label)) |lens_idx| {
                boxes[box_idx].items[lens_idx].focal_length = value;
            } else {
                const lens = Lens { .label = label, .focal_length = value };
                try boxes[box_idx].append(gpa, lens);
            }
        } else {
            unreachable();
        }
    }

    var focusing_power: usize = 0;

    for (boxes, 0..) |box, i| {
        if (box.items.len > 0) {
            std.debug.print("{}: ", .{ i });
            for (box.items, 1..) |lens, j| {
                std.debug.print("[{s} {}] ", .{ lens.label, lens.focal_length });

                focusing_power += (i + 1) * j * lens.focal_length;
            }
            std.debug.print("\n", .{});
        }
    }

    std.debug.print("focusing power: {}\n", .{ focusing_power });
}
