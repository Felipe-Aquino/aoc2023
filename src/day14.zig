const std = @import("std");

const Allocator = std.mem.Allocator;

const Slot = enum(u8) {
    Empty = '.',
    RollRock = 'O',
    FixedRock = '#',
};

fn print_grid(grid: []const []const Slot) void {
    for (grid) |slots| {
        std.debug.print("| ", .{});
        for (slots) |slot| {
            std.debug.print("{c}", .{ @intFromEnum(slot) });
        }
        std.debug.print("\n", .{});
    }
    std.debug.print("\n", .{});
}

fn tilt_grid_north(grid: [][]Slot) void {
    const slot_count = grid[0].len;

    for (1..grid.len) |i| {
        for (0..slot_count) |j| {
            var k = i - 1;

            if (grid[i][j] == .RollRock and grid[k][j] == .Empty) {
                while (k > 0 and grid[k - 1][j] == .Empty): (k -= 1) {}

                grid[k][j] = .RollRock;
                grid[i][j] = .Empty;
            }
        }
    }
}

fn get_grid_total_load(grid: []const []const Slot) usize {
    var total_load: usize = 0;

    for (grid, 0..) |slots, i| {
        var roll_rock_count: usize = 0;

        for (slots) |slot| {
            if (slot == .RollRock) {
                roll_rock_count += 1;
            }
        }

        total_load += roll_rock_count * (grid.len - i);
    }

    return total_load;
}

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var grid: std.ArrayList([]Slot) = .empty;

    defer {
        for (grid.items) |slots| {
            gpa.free(slots);
        }
        grid.deinit(gpa);
    }
    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        // std.debug.print("| {s}\n", .{ line });

        var slots = try gpa.alloc(Slot, line.len);
        for (line, 0..) |c, i| {
            slots[i] = @enumFromInt(c);
        }
        // std.debug.print("| {any}\n", .{ slots });

        try grid.append(gpa, slots);
    }

    print_grid(grid.items);

    tilt_grid_north(grid.items);

    print_grid(grid.items);

    const total_load = get_grid_total_load(grid.items);

    std.debug.print("total load = {}\n", .{ total_load });
}

