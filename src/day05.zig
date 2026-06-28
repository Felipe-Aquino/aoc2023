const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

const Range = struct {
    start: usize = 0,
    end: usize = 0,
};

const RangeDiv = struct {
    ranges: [3]Range,
    count: u8,
};

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

    fn get2(self: *const Map, value: usize) usize {
        if (
            self.src_start <= value and
            value <= self.src_start + self.length
        ) {

            return self.dst_start + value - self.src_start;
        }

        return value;
    }

    fn div(self: *const Map, range: Range) RangeDiv {
        var rdiv: RangeDiv = .{ .ranges = .{ .{}, .{}, .{} }, .count = 1 };

        if (range.start > self.src_start + self.length) {
            rdiv.count = 0;
            // div.ranges[0] = range;
        } else if (range.end < self.src_start) {
            rdiv.count = 0;
            // div.ranges[0] = range;
        } else if (range.end <= self.src_start + self.length) {
            if (range.start >= self.src_start) {
                // |----------------------------------|
                //     |--------------|
                //     1111111111111111
                const s1 = self.get2(range.start);
                const e1 = self.get2(range.end);

                rdiv.ranges[0].start = s1;
                rdiv.ranges[0].end = e1;
            } else {
                //     |----------------------------------|
                // |--------------|
                // 1111222222222222
                const s1 = range.start;
                const e1 = self.src_start - 1;
                const s2 = self.get2(self.src_start);
                const e2 = self.get2(range.end);

                rdiv.ranges[0].start = s1;
                rdiv.ranges[0].end = e1;
                rdiv.ranges[1].start = s2;
                rdiv.ranges[1].end = e2;
                rdiv.count = 2;
            }
        } else {
            if (range.start >= self.src_start) {
                // |----------------------------------|
                //                            |--------------|
                //                            2222222221111111
                const s1 = self.src_start + self.length + 1;
                const e1 = range.end;
                const s2 = self.get2(range.start);
                const e2 = self.get2(self.src_start + self.length);

                rdiv.ranges[0].start = s1;
                rdiv.ranges[0].end = e1;
                rdiv.ranges[1].start = s2;
                rdiv.ranges[1].end = e2;
                rdiv.count = 2;
            } else {
                //           |-----------------------------|
                //    |--------------------------------------------|
                //    2222222111111111111111111111111111111133333333
                const s1 = self.get2(self.src_start);
                const e1 = self.get2(self.src_start + self.length);
                const s2 = range.start;
                const e2 = self.src_start - 1;
                const s3 = self.src_start + self.length + 1;
                const e3 = range.end;

                rdiv.ranges[0].start = s1;
                rdiv.ranges[0].end = e1;
                rdiv.ranges[1].start = s2;
                rdiv.ranges[1].end = e2;
                rdiv.ranges[2].start = s3;
                rdiv.ranges[2].end = e3;
                rdiv.count = 3;
            }
        }

        return rdiv;
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

pub fn part1(gpa: Allocator, content: []const u8) !void {
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

fn sliceContains(comptime T: type, slice: []const T, value: T) bool {
  for (slice) |element| {
      if (std.meta.eql(value, element)) return true;
  }
  
  return false;
}

fn apply_maps2(gpa: Allocator, maps: []Map, ranges: *std.ArrayList(Range), result: *std.ArrayList(Range)) !void {
    var k: usize = 0;
    while (k < ranges.items.len) {
        var range = &ranges.items[k];
        k += 1;

        var matched = false;

        for (maps) |map| {
            const div = map.div(range.*);

            if (div.count == 1) {
                // std.debug.print("1. {} -> {} | (idx = {}, map = {})\n", .{ range.*, div.ranges[0], k, i });

                if (!sliceContains(Range, result.items, div.ranges[0])) {
                    try result.append(gpa, div.ranges[0]);
                }
                
                matched = true;
                break;
            } else if (div.count == 2) {
                // std.debug.print("2. {} -> {}, {} | (idx = {}, map = {})\n", .{ range.*, div.ranges[0], div.ranges[1], k, i });

                range.start = div.ranges[0].start;
                range.end = div.ranges[0].end;
                if (!sliceContains(Range, result.items, div.ranges[1])) {
                    try result.append(gpa, div.ranges[1]);
                }
            } else if (div.count == 3) {
                // std.debug.print("3. {} -> {}, {}, {} | (idx = {}, map = {})\n", .{ range.*, div.ranges[0], div.ranges[1], div.ranges[2], k, i });

                if (!sliceContains(Range, result.items, div.ranges[0])) {
                    try result.append(gpa, div.ranges[0]);
                }

                range.start = div.ranges[1].start;
                range.end = div.ranges[1].end;

                try ranges.append(gpa, div.ranges[2]);
            }
        }

        if (!matched) {
            // std.debug.print("4. {} | (idx = {})\n", .{ range.*, k });

            if (!sliceContains(Range, result.items, range.*)) {
                try result.append(gpa, range.*);
            }
        }
    }
    // std.debug.print("------------------- \n", .{});
}

fn swapLists(a: *std.ArrayList(Range), b: *std.ArrayList(Range)) void {
    const tmp = a.*;
    a.* = b.*;
    b.* = tmp;
}

pub fn part2(gpa: Allocator, content: []const u8) !void {
    var maps_array = [7]std.ArrayList(Map) { .empty, .empty, .empty, .empty, .empty, .empty, .empty };
    var seed_ranges: std.ArrayList(Range) = .empty;

    defer {
        for (&maps_array) |*m| {
            m.deinit(gpa);
        }
    }

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (std.mem.startsWith(u8, line, "seeds:")) {
            var iter2 = std.mem.splitSequence(u8, line, " ");
            _ = iter2.next();

            var seeds: std.ArrayList(usize) = .empty;

            while (iter2.next()) |num| {
                const v = try std.fmt.parseInt(usize, num, 10);
                try seeds.append(gpa, v);
            }

            var i: usize = 0;
            while (i < seeds.items.len) {
                const r = Range {
                    .start = seeds.items[i],
                    .end = seeds.items[i] + seeds.items[i + 1], 
                };

                try seed_ranges.append(gpa, r);
                i += 2;
            }

            seeds.deinit(gpa);
        } else if (std.mem.startsWith(u8, line, "seed-to-soil map:")) {
            maps_array[0] = try read_maps(&iter, gpa);
        } else if (std.mem.startsWith(u8, line, "soil-to-fertilizer map:")) {
            maps_array[1] = try read_maps(&iter, gpa);
        } else if (std.mem.startsWith(u8, line, "fertilizer-to-water map:")) {
            maps_array[2] = try read_maps(&iter, gpa);
        } else if (std.mem.startsWith(u8, line, "water-to-light map:")) {
            maps_array[3] = try read_maps(&iter, gpa);
        } else if (std.mem.startsWith(u8, line, "light-to-temperature map:")) {
            maps_array[4] = try read_maps(&iter, gpa);
        } else if (std.mem.startsWith(u8, line, "temperature-to-humidity map:")) {
            maps_array[5] = try read_maps(&iter, gpa);
        } else if (std.mem.startsWith(u8, line, "humidity-to-location map:")) {
            maps_array[6] = try read_maps(&iter, gpa);
        }
    }

    std.debug.print("seeds = {}\n", .{ seed_ranges });

    var r1: std.ArrayList(Range) = seed_ranges;
    var r2: std.ArrayList(Range) = .empty;

    defer {
        r1.deinit(gpa);
        r2.deinit(gpa);
    }

    for (maps_array) |maps| {
        // std.debug.print("r1 = {}\n", .{ r1 });
        // std.debug.print("r2 = {}\n", .{ r2 });
        try apply_maps2(gpa, maps.items, &r1, &r2);

        swapLists(&r1, &r2);
        // std.mem.swap(std.ArrayList(Range), &r1, &r2);
        r2.clearRetainingCapacity();
        // std.debug.print("({}) r1 = {}\n", .{ i, r1 });
    }

    var min_location: ?usize = null;

    for (r1.items) |range| {
        if (min_location) |loc| {
            if (loc > range.start) {
                min_location = range.start;
            }
        } else {
            min_location = range.start;
        }
    }

    std.debug.print("min location = {}\n", .{ min_location.? });
}
