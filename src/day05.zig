const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

const Map = struct {
    src_start: usize,
    dst_start: usize,
    length: usize,

    fn get(self: *const Map, value: usize) struct { bool, usize } {
        if (
            self.src_start <= value and
            value <= self.src_start + self.length
        ) {

            return .{ true, self.dst_start + value - self.src_start };
        }

        return .{ false, value };
    }
};

const LineIter = std.mem.SplitIterator(u8, .sequence);

fn read_maps(line_iter: *LineIter, gpa: Allocator) !std.ArrayList(Map) {
    var maps: std.ArrayList(Map) = .empty;

    while (line_iter.next()) |line| {
        if (line.len == 0) break;

        var num_iter = std.mem.splitSequence(u8, line, " ");

        var map = Map { .src_start = 0, .dst_start = 0, .length = 0 };

        map.dst_start = try std.fmt.parseInt(usize, num_iter.next().?, 10);
        map.src_start = try std.fmt.parseInt(usize, num_iter.next().?, 10);
        map.length = try std.fmt.parseInt(usize, num_iter.next().?, 10);

        try maps.append(gpa, map);
    }

    return maps;
}

fn apply_maps(maps: []Map, value: usize) usize {
    for (maps) |map| {
        const found, const new_value = map.get(value);

        if (found) {
            return new_value;
        }
    }

    return value;
}

fn part1(gpa: Allocator, content: []const u8) !void {
    var seed_soil_maps: std.ArrayList(Map) = .empty;
    var soil_fertilizer_maps: std.ArrayList(Map) = .empty;
    var fertilizer_water_maps: std.ArrayList(Map) = .empty;
    var water_light_maps: std.ArrayList(Map) = .empty;
    var light_temperature_maps: std.ArrayList(Map) = .empty;
    var temperature_humidity_maps: std.ArrayList(Map) = .empty;
    var humidity_location_maps: std.ArrayList(Map) = .empty;

    var seeds: std.ArrayList(usize) = .empty;

    defer {
        seed_soil_maps.deinit(gpa);
        soil_fertilizer_maps.deinit(gpa);
        fertilizer_water_maps.deinit(gpa);
        water_light_maps.deinit(gpa);
        light_temperature_maps.deinit(gpa);
        temperature_humidity_maps.deinit(gpa);
        humidity_location_maps.deinit(gpa);
        seeds.deinit(gpa);
    }

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (std.mem.startsWith(u8, line, "seeds:")) {
            var iter2 = std.mem.splitSequence(u8, line, " ");
            _ = iter2.next();

            while (iter2.next()) |num| {
                const v = try std.fmt.parseInt(usize, num, 10);
                try seeds.append(gpa, v);
            }
        } else if (std.mem.startsWith(u8, line, "seed-to-soil map:")) {
            seed_soil_maps = try read_maps(&iter, gpa);
        } else if (std.mem.startsWith(u8, line, "soil-to-fertilizer map:")) {
            soil_fertilizer_maps = try read_maps(&iter, gpa);
        } else if (std.mem.startsWith(u8, line, "fertilizer-to-water map:")) {
            fertilizer_water_maps = try read_maps(&iter, gpa);
        } else if (std.mem.startsWith(u8, line, "water-to-light map:")) {
            water_light_maps = try read_maps(&iter, gpa);
        } else if (std.mem.startsWith(u8, line, "light-to-temperature map:")) {
            light_temperature_maps = try read_maps(&iter, gpa);
        } else if (std.mem.startsWith(u8, line, "temperature-to-humidity map:")) {
            temperature_humidity_maps = try read_maps(&iter, gpa);
        } else if (std.mem.startsWith(u8, line, "humidity-to-location map:")) {
            humidity_location_maps = try read_maps(&iter, gpa);
        }
    }

    var min_location: ?usize = null;

    for (seeds.items) |seed| {
        var result = seed;
        // std.debug.print("seed = {}, ", .{ result });
        result = apply_maps(seed_soil_maps.items, result);
        // std.debug.print("soil = {}, ", .{ result });
        result = apply_maps(soil_fertilizer_maps.items, result);
        // std.debug.print("fertilizer = {}, ", .{ result });
        result = apply_maps(fertilizer_water_maps.items, result);
        // std.debug.print("water = {}, ", .{ result });
        result = apply_maps(water_light_maps.items, result);
        // std.debug.print("light = {}, ", .{ result });
        result = apply_maps(light_temperature_maps.items, result);
        // std.debug.print("temperature = {}, ", .{ result });
        result = apply_maps(temperature_humidity_maps.items, result);
        // std.debug.print("humidity = {}, ", .{ result });
        result = apply_maps(humidity_location_maps.items, result);
        // std.debug.print("location = {}\n", .{ result });

        std.debug.print("seed = {}, location = {}\n", .{ seed, result });

        if (min_location) |loc| {
            if (loc > result) {
                min_location = result;
            }
        } else {
            min_location = result;
        }
    }

    std.debug.print("min location = {}\n", .{ min_location.? });
}

fn part2(gpa: Allocator, content: []const u8) !void {
    _ = gpa;
    _ = content;
    unreachable();
}

pub fn main() !void {
    // const file_path = "./inputs/day05-example.txt";
    const file_path = "./inputs/day05.txt";

    const gpa = std.heap.page_allocator;
    const content = try utils.read_file(gpa, file_path);
    defer gpa.free(content);

    if (utils.is_part1()) {
        try part1(gpa, content);
    } else {
        try part2(gpa, content);
    }
}
