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

fn tilt_grid_south(grid: [][]Slot) void {
    const slot_count = grid[0].len;

    var i = grid.len - 1;
    while (i > 0) {
        i -= 1;

        for (0..slot_count) |j| {
            var k = i + 1;

            if (grid[i][j] == .RollRock and grid[k][j] == .Empty) {
                while (k < grid.len - 1 and grid[k + 1][j] == .Empty): (k += 1) {}

                grid[k][j] = .RollRock;
                grid[i][j] = .Empty;
            }
        }
    }
}

fn tilt_grid_west(grid: [][]Slot) void {
    const slot_count = grid[0].len;

    for (1..slot_count) |j| {
        for (0..grid.len) |i| {
            var k = j - 1;

            if (grid[i][j] == .RollRock and grid[i][k] == .Empty) {
                while (k > 0 and grid[i][k - 1] == .Empty): (k -= 1) {}

                grid[i][k] = .RollRock;
                grid[i][j] = .Empty;
            }
        }
    }
}

fn tilt_grid_east(grid: [][]Slot) void {
    const slot_count = grid[0].len;

    var j = slot_count - 1;
    while (j > 0) {
        j -= 1;

        for (0..grid.len) |i| {
            var k = j + 1;

            if (grid[i][j] == .RollRock and grid[i][k] == .Empty) {
                while (k < slot_count - 1 and grid[i][k + 1] == .Empty): (k += 1) {}

                grid[i][k] = .RollRock;
                grid[i][j] = .Empty;
            }
        }
    }
}

fn cicle_grid(grid: [][]Slot) void {
    tilt_grid_north(grid);
    tilt_grid_west(grid);
    tilt_grid_south(grid);
    tilt_grid_east(grid);
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

fn find_repetition(sequence: []const usize, repetitions: usize) ?struct { usize, usize } {
    const max_window_size: usize = sequence.len / repetitions;

    // std.debug.print("max_window_size = {}, sequence_len = {}\n", .{ max_window_size, sequence.len });
    if (max_window_size < repetitions) {
        return null;
    }

    for (2..max_window_size + 1) |window_size| {
        for (0..sequence.len - window_size) |i| {
            const window = sequence[i..i + window_size];
            var count: usize = 1;

            var k = i + window_size;

            // std.debug.print("{} -> {}..{}\n", .{ i, i + window_size, sequence.len - window_size });
            while (k < sequence.len - window_size): (k += window_size) {
                if (std.mem.eql(usize, sequence[k..k + window_size], window)) {
                    count += 1;
                    if (count == repetitions) {
                        return .{i, window_size};
                    }
                } else {
                    break;
                }
            }
        }
    }

    return null;
}

pub fn part2(gpa: Allocator, content: []const u8) !void {
    var grid: std.ArrayList([]Slot) = .empty;
    var sequence: std.ArrayList(usize) = .empty;

    defer {
        for (grid.items) |slots| {
            gpa.free(slots);
        }
        grid.deinit(gpa);
        sequence.deinit(gpa);
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

    // print_grid(grid.items);

    for (1..1000) |iteration| {
        cicle_grid(grid.items);

        // print_grid(grid.items);

        const total_load = get_grid_total_load(grid.items);

        try sequence.append(gpa, total_load);

        if (find_repetition(sequence.items, 10)) |window_info| {
            const pos, const window_size = window_info;
            const window = sequence.items[pos..pos + window_size];

            std.debug.print("iterations  = {}\n", .{ iteration });
            std.debug.print("pos         = {}\n", .{ pos });
            std.debug.print("window_size = {}\n", .{ window_size });
            std.debug.print("window      = {any}\n", .{ window });

            const remaining_iterations: usize = 1_000_000_000 - pos - 1;
            const remainder = @rem(remaining_iterations, window_size);

            std.debug.print("remainder   = {}\n", .{ remainder });
            std.debug.print("total load  = {}\n", .{ window[remainder] });
            break;
        }

        // std.debug.print("total load = {}\n", .{ total_load });
    }
}
