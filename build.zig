const std = @import("std");

fn parseAttributes(b: *std.Build) ?struct { []const u8, []const u8, bool } {
    const day_opt = b.option([]const u8, "day", "Which day to run: 01, 02, ..., 25");

    const day = day_opt orelse {
        std.debug.print(
            \\
            \\======================================================================
            \\Advent of Code Runner - Please specify a day!
            \\======================================================================
            \\Options:
            \\  -Dday=01         Builds and runs day01.zig (Required)
            \\  -Dpart=2         Builds part 2 of the day (default: 1)
            \\  -Dexample=true   Use ./inputs/dayX-example.txt as input
            \\  -Dexample=false  Use ./inputs/dayX.txt as input (default)
            \\
            \\Example Usage:
            \\  zig build run -Dday=01 -Dpart=2 -Dexample=true
            \\======================================================================
            \\
            \\
        , .{});
        return null;
    };

    if (day.len != 2) {
        @panic("Invalid day number! It should be a number from 01 to 25");
    }

    const day_num = std.fmt.parseInt(u8, day, 10) catch {
        @panic("Invalid day number! It should be a number from 01 to 25");
    };

    if (!(0 < day_num and day_num <= 25)) {
        @panic("Invalid day number! It should be a number from 01 to 25");
    }

    const part = b.option([]const u8, "part", "Which part to run: 1 or 2") orelse "1";
    const part_num = std.fmt.parseInt(u8, part, 10) catch {
        @panic("Invalid part number! It should be 1 or 2");
    };

    if (part_num != 1 and part_num != 2) {
        @panic("Invalid part number! It should be 1 or 2");
    }

    const example = b.option(
        bool,
        "example",
        "Whether should run use input file ./inputs/day<day>.txt or ./inputs/day<day>-example.txt"
    ) orelse true;

    return .{ day, part, example };
}

pub fn build(b: *std.Build) void {
    const attrs = parseAttributes(b);

    if (attrs == null) {
        return;
    }

    const day, const part, const example = attrs.?;

    const example_prefix: []const u8 = if (example) "-example" else "";

    const file_content = std.fmt.allocPrint(
        b.allocator,
        \\const std = @import("std");
        \\const utils = @import("./src/utils.zig");
        \\
        \\const mod = @import("./src/day{0s}.zig");
        \\
        \\pub fn main() !void {{
        \\    const file_path = "./inputs/day{0s}{2s}.txt";
        \\    
        \\    const gpa = std.heap.page_allocator;
        \\    const content = try utils.read_file(gpa, file_path);
        \\    defer gpa.free(content);
        \\    
        \\    try mod.part{1s}(gpa, content);
        \\}}
        , .{ day, part, example_prefix }
    ) catch {
        @panic("Build failed allocating data!");
    };

    defer b.allocator.free(file_content);

    const gen_main_path = "main_generated.zig";
    const file = std.fs.cwd().createFile(gen_main_path, .{ .read = true }) catch {
        @panic("Build failed creating file!");
    };

    defer file.close();

    file.writeAll(file_content) catch {
        @panic("Build failed writing file!");
    };

    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const exe = b.addExecutable(.{
        .name = "aoc2023",
        .root_module = b.createModule(.{
            .target = target,
            .optimize = optimize,
            .root_source_file = b.path(gen_main_path),
        }),
    });

    const run_cmd = b.addRunArtifact(exe);

    // run_cmd.addArgs(b.args);

    b.installArtifact(exe);

    const run_step = b.step("run", "Build and run");
    run_step.dependOn(&run_cmd.step);
}

