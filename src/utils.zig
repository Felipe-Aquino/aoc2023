const std = @import("std");

pub fn read_file(gpa: std.mem.Allocator, path: []const u8) ![]u8 {
    const MAX_FILE_SIZE: usize = 10 * 1024 * 1024;
    return std.fs.cwd().readFileAlloc(gpa, path, MAX_FILE_SIZE);
}

pub fn is_part1() bool {
    return std.os.argv.len < 2 or !std.mem.eql(u8, std.mem.span(std.os.argv[1]), "2");
}

