const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

const CubeSet = struct {
    red: usize,
    green: usize,
    blue: usize,
};

const Game = struct {
    id: usize,
    cube_sets: std.ArrayList(CubeSet),
};

fn read_games(gpa: Allocator, content: []const u8) !std.ArrayList(Game) {
    var games: std.ArrayList(Game) = .empty;

    var line_iter = std.mem.splitSequence(u8, content, "\n");

    while (line_iter.next()) |line| {
        if (line.len == 0) continue;

        var iter0 = std.mem.splitSequence(u8, line, ": ");

        const game_part = std.mem.trim(u8, iter0.next().?, "Game ");
        const game_id = try std.fmt.parseInt(usize, game_part, 10);
        const sets_part = iter0.next().?;

        var cube_sets: std.ArrayList(CubeSet) = .empty;

        var iter1 = std.mem.splitSequence(u8, sets_part, "; ");

        while (iter1.next()) |set| {
            var iter2 = std.mem.splitSequence(u8, set, ", ");

            var cube_set: CubeSet = .{ .blue = 0, .green = 0, .red = 0 };

            while (iter2.next()) |color_count| {
                if (std.mem.endsWith(u8, color_count, " red")) {
                    cube_set.red = try std.fmt.parseInt(
                        usize,
                        std.mem.trimEnd(u8, color_count, " red"),
                        10
                    );
                }
                else if (std.mem.endsWith(u8, color_count, " green")) {
                    cube_set.green = try std.fmt.parseInt(
                        usize,
                        std.mem.trimEnd(u8, color_count, " green"),
                        10
                    );
                }
                else if (std.mem.endsWith(u8, color_count, " blue")) {
                    cube_set.blue = try std.fmt.parseInt(
                        usize,
                        std.mem.trimEnd(u8, color_count, " blue"),
                        10
                    );
                }
            }

            try cube_sets.append(gpa, cube_set);
        }

        const game: Game = .{ .id = game_id, .cube_sets = cube_sets };
        try games.append(gpa, game);
    }

    return games;
}

fn free_games(gpa: Allocator, games: *std.ArrayList(Game)) void {
    for (games.items) |*game| {
        game.cube_sets.deinit(gpa);
    }
    games.deinit(gpa);
}

pub fn part1(gpa: Allocator, content: []u8) !void {
    var games = try read_games(gpa, content);
    defer free_games(gpa, &games);

    const max_cube_set: CubeSet = .{ .red = 12, .green = 13, .blue = 14 };

    var sum: usize = 0;

    for (games.items) |game| {
        // std.debug.print("id: {}\n", .{game.id});
        // std.debug.print("sets: {}\n", .{game.cube_sets});

        var is_valid = true;
        for (game.cube_sets.items) |set| {
            if (
                set.red > max_cube_set.red or
                set.green > max_cube_set.green or
                set.blue > max_cube_set.blue
            ) {
                is_valid = false;
                break;
            }
        }

        if (is_valid) {
            sum += game.id;
        }
    }

    std.debug.print("id sum: {}\n", .{sum});
}

pub fn part2(gpa: Allocator, content: []u8) !void {
    var games = try read_games(gpa, content);
    defer free_games(gpa, &games);

    var sum: usize = 0;

    for (games.items) |game| {
        var min_cube_set: CubeSet = .{ .red = 0, .green = 0, .blue = 0 };
        for (game.cube_sets.items) |set| {
            min_cube_set.red = @max(min_cube_set.red, set.red);
            min_cube_set.blue = @max(min_cube_set.blue, set.blue);
            min_cube_set.green = @max(min_cube_set.green, set.green);
        }

        const power = min_cube_set.red * min_cube_set.blue * min_cube_set.green;
        sum += power;

        std.debug.print("power of game {}: {}\n", .{game.id, power});
    }

    std.debug.print("power sum: {}\n", .{sum});
}
