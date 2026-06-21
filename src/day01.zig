const std = @import("std");

const MAX_FILE_SIZE: usize = 10 * 1024 * 1024;

fn part1() !void {
    const gpa = std.heap.page_allocator;
    const file_path = "./inputs/day01-example.txt";
    const content = try std.fs.cwd().readFileAlloc(gpa, file_path, MAX_FILE_SIZE);
    defer gpa.free(content);

    std.debug.print("Hellow!\n", .{});
    std.debug.print("File content: {s}!\n{s}", .{file_path, content});
}

pub fn main() !void {
    try part1();
}
