const std = @import("std");

fn read_file(gpa: std.mem.Allocator, path: []const u8) ![]u8 {
    const MAX_FILE_SIZE: usize = 10 * 1024 * 1024;
    return std.fs.cwd().readFileAlloc(gpa, path, MAX_FILE_SIZE);
}

fn is_part1() bool {
    return std.os.argv.len < 2 or !std.mem.eql(u8, std.mem.span(std.os.argv[1]), "2");
}

fn part1(content: []u8) !void {
    var iter = std.mem.splitSequence(u8, content, "\n");

    var sum: usize = 0;

    while (iter.next()) |line| {
        if (line.len > 0) { 
            const idx1 = std.mem.indexOfAny(u8, line, "0123456789").?;
            const idx2 = std.mem.lastIndexOfAny(u8, line, "0123456789").?;

            const n = 10 * @as(usize, @intCast(line[idx1] - '0'))
                         + @as(usize, @intCast(line[idx2] - '0'));

            std.debug.print("'{s}' -> {}\n", .{line, n});
            sum += n;
        }
    }

    std.debug.print("sum = {}\n", .{sum});
}

fn find_first_number(line: []const u8, reverse: bool) usize { 
    const numbers: [18][]const u8 = .{"1", "2", "3", "4", "5", "6", "7", "8", "9", "one", "two", "three", "four", "five", "six", "seven", "eight", "nine" };

    var idx: usize = 0;
    var value: usize = 0;

    if (!reverse) {
        idx = line.len;

        for (numbers, 0..) |name, i| {
            if (std.mem.indexOf(u8, line, name)) |idx_left| {
                if (idx_left <= idx) {
                    idx = idx_left;
                    value = @mod(i, 9) + 1;
                }
            }
        }
    } else {
        for (numbers, 0..) |name, i| {
            if (std.mem.lastIndexOf(u8, line, name)) |idx_right| {
                if (idx_right >= idx) {
                    idx = idx_right;
                    value = @mod(i, 9) + 1;
                }
            }
        }
    }

    return value;
}

fn part2(content: []u8) !void {
    var iter = std.mem.splitSequence(u8, content, "\n");

    var sum: usize = 0;

    while (iter.next()) |line| {
        if (line.len > 0) { 
            const n1 = find_first_number(line, false);
            const n2 = find_first_number(line, true);

            const n = 10 * n1 + n2;

            std.debug.print("'{s}' -> {}\n", .{line, n});
            sum += n;
        }
    }

    std.debug.print("sum = {}\n", .{sum});
}

pub fn main() !void {
    // const file_path = "./inputs/day01-example.txt";
    // const file_path = "./inputs/day01-example2.txt";
    const file_path = "./inputs/day01.txt";

    const gpa = std.heap.page_allocator;
    const content = try read_file(gpa, file_path);
    defer gpa.free(content);

    if (is_part1()) {
        try part1(content);
    } else {
        try part2(content);
    }
}
