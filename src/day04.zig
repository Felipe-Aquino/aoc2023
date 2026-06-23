const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

fn part1(gpa: Allocator, content: []const u8) !void {
    var sum: u64 = 0;

    var iter = std.mem.splitSequence(u8, content, "\n");

    var numbers: std.ArrayList(i32) = .empty;
    var winning_numbers: std.ArrayList(i32) = .empty;

    defer numbers.deinit(gpa);
    defer winning_numbers.deinit(gpa);

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        var iter1 = std.mem.splitSequence(u8, line, ": ");

        _ = iter1.next();
        
        var iter2 = std.mem.splitSequence(u8, iter1.next().?, " | ");

        {
            var iter3 = std.mem.splitSequence(u8, iter2.next().?, " ");

            while (iter3.next()) |value| {
                if (value.len == 0) continue;
                const num = try std.fmt.parseInt(i32, value, 10);
                try winning_numbers.append(gpa, num);
            }
        }

        {
            var iter3 = std.mem.splitSequence(u8, iter2.next().?, " ");

            while (iter3.next()) |value| {
                if (value.len == 0) continue;
                const num = try std.fmt.parseInt(i32, value, 10);
                try numbers.append(gpa, num);
            }
        }

        var value: u64 = 0;

        for (numbers.items) |n| {
            const ok = std.mem.containsAtLeastScalar(i32, winning_numbers.items, 1, n);

            if (ok) {
                if (value == 0) {
                    value = 1;
                } else {
                    value *= 2;
                }
            }
        }

        std.debug.print("| {}\n", .{value});
        sum += value;

        numbers.clearRetainingCapacity();
        winning_numbers.clearRetainingCapacity();
    }

    std.debug.print("sum = {}\n", .{sum});
}

const Game = struct {
    score: u64,
    amount: usize,
};

fn part2(gpa: Allocator, content: []const u8) !void {
    var sum: u64 = 0;

    var iter = std.mem.splitSequence(u8, content, "\n");

    var numbers: std.ArrayList(i32) = .empty;
    var winning_numbers: std.ArrayList(i32) = .empty;
    var games: std.ArrayList(Game) = .empty;

    defer numbers.deinit(gpa);
    defer winning_numbers.deinit(gpa);
    defer games.deinit(gpa);

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        var iter1 = std.mem.splitSequence(u8, line, ": ");

        _ = iter1.next();
        
        var iter2 = std.mem.splitSequence(u8, iter1.next().?, " | ");

        {
            var iter3 = std.mem.splitSequence(u8, iter2.next().?, " ");

            while (iter3.next()) |value| {
                if (value.len == 0) continue;
                const num = try std.fmt.parseInt(i32, value, 10);
                try winning_numbers.append(gpa, num);
            }
        }

        {
            var iter3 = std.mem.splitSequence(u8, iter2.next().?, " ");

            while (iter3.next()) |value| {
                if (value.len == 0) continue;
                const num = try std.fmt.parseInt(i32, value, 10);
                try numbers.append(gpa, num);
            }
        }

        var value: u64 = 0;

        for (numbers.items) |n| {
            const ok = std.mem.containsAtLeastScalar(i32, winning_numbers.items, 1, n);

            if (ok) {
                value += 1;
            }
        }

        const game: Game = .{ .score = value, .amount = 1 };
        try games.append(gpa, game);

        numbers.clearRetainingCapacity();
        winning_numbers.clearRetainingCapacity();
    }

    for (games.items, 0..) |game, i| {
        for (0..game.score) |k| {
            if (k + i + 1 >= games.items.len) {
                break;
            }

            games.items[i + k + 1].amount += game.amount;
        }
    }

    for (games.items, 0..) |game, i| {
        std.debug.print("{}) {}\n", .{i + 1, game.amount});
        sum += game.amount;
    }

    std.debug.print("sum = {}\n", .{sum});
}

pub fn main() !void {
    // const file_path = "./inputs/day04-example.txt";
    const file_path = "./inputs/day04.txt";

    const gpa = std.heap.page_allocator;
    const content = try utils.read_file(gpa, file_path);
    defer gpa.free(content);

    if (utils.is_part1()) {
        try part1(gpa, content);
    } else {
        try part2(gpa, content);
    }
}

