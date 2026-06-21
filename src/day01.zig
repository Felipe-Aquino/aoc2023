const std = @import("std");

fn read_file(gpa: std.mem.Allocator, path: []const u8) ![]u8 {
    const MAX_FILE_SIZE: usize = 10 * 1024 * 1024;
    return std.fs.cwd().readFileAlloc(gpa, path, MAX_FILE_SIZE);
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

pub fn main() !void {
    // const file_path = "./inputs/day01-example.txt";
    const file_path = "./inputs/day01.txt";

    const gpa = std.heap.page_allocator;
    const content = try read_file(gpa, file_path);
    defer gpa.free(content);

    try part1(content);
}
