const std = @import("std");

const Allocator = std.mem.Allocator;

const Point = struct {
    x: isize,
    y: isize,

    fn eql(self: Point, other: Point) bool {
        return self.x == other.x and self.y == other.y;
    }
};

const Segment = struct {
    start: Point,
    end: Point,

    fn split(self: *Segment, y: isize) ?Segment {
        if (self.start.y < y and y < self.end.y) {
            const s = Segment {
                .start = .{
                    .x = self.start.x,
                    // .y = y + 1,
                    .y = y,
                },
                .end = self.end,
            };

            self.end.y = y;

            return s;
        }

        return null;
    }
};

const SegmentSet = std.AutoHashMap(Segment, void);

fn v_segment_cmp(_: void, lhs: Segment, rhs: Segment) bool {
    if (lhs.start.y == rhs.start.y) {
        return lhs.start.x < rhs.start.x;
    }
    return lhs.start.y < rhs.start.y;
}

fn h_segment_cmp(_: void, lhs: Segment, rhs: Segment) bool {
    if (lhs.start.x == rhs.start.x) {
        return lhs.start.y < rhs.start.y;
    }
    return lhs.start.x < rhs.start.x;
}

fn join_hsegments(s1: Segment, s2: Segment) ?Segment {
    if (s1.start.y != s2.start.y or s1.start.x > s2.end.x or s1.end.x < s2.start.x) {
        return null;
    }

    if (s1.start.x > s2.start.x) {
        if (s1.end.x >= s2.end.x) {
            return Segment { .start = s2.start, .end = s1.end };
        } else {
            return s2;
        }
    } else {
        if (s1.end.x < s2.end.x) {
            return Segment { .start = s1.start, .end = s2.end };
        } else {
            return s1;
        }
    }
}

// fn join_segments(s1: Segment, s2: Segment) ?Segment {
//     if (s1.end.eql(s2.start)) {
//         const s: Segment = .{
//             .start = s1.start,
//             .end = s2.end,
//         };
// 
//         return s;
//     }
// 
//     return null;
// }

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var path: std.ArrayList(Point) = .empty;

    var iter = std.mem.splitSequence(u8, content, "\n");
    var point: Point = .{ .x = 0, .y = 0 };

    try path.append(gpa, point);

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        var column_iter = std.mem.splitSequence(u8, line, " ");
        const dir = column_iter.next().?;
        const amount = try std.fmt.parseInt(isize, column_iter.next().?, 10);

        switch (dir[0]) {
            'D' => {
                point.y += amount;
            },
            'U' => {
                point.y -= amount;
            },
            'L' => {
                point.x -= amount;
            },
            'R' => {
                point.x += amount;
            },
            else => unreachable(),
        }

        try path.append(gpa, point);
    }

    // std.debug.print("{any}\n", .{ path.items });

    std.debug.assert(path.items[0].eql(path.getLast()));

    var hsegments: std.ArrayList(Segment) = .empty;
    var vsegments: std.ArrayList(Segment) = .empty;
    defer {
        hsegments.deinit(gpa);
        vsegments.deinit(gpa);
    }

    for (0..path.items.len - 1) |i| {
        const p1 = path.items[i];
        const p2 = path.items[i + 1];
        var s = Segment {
            .start = p1,
            .end = p2,
        };

        if (s.start.x == s.end.x) {
            if (s.start.y > s.end.y) {
                std.mem.swap(isize, &s.start.y, &s.end.y);
            }
            try vsegments.append(gpa, s);
        } else {
            if (s.start.x > s.end.x) {
                std.mem.swap(isize, &s.start.x, &s.end.x);
            }
            try hsegments.append(gpa, s);
        }
    }

    var minx: isize = 1_000_000;
    var miny: isize = 1_000_000;
    var maxx: isize = -1_000_000;
    var maxy: isize = -1_000_000;
    for (vsegments.items) |vs| {
        // std.debug.print("{}\n", .{vs});

        minx = @min(minx, @min(minx, vs.start.x));
        maxx = @max(maxx, @max(maxx, vs.end.x));
        miny = @min(miny, @min(miny, vs.start.y));
        maxy = @max(maxy, @max(maxy, vs.end.y));
    }

    std.debug.print("--\n", .{});
    for (hsegments.items) |vs| {
        // std.debug.print("{}\n", .{vs});

        minx = @min(minx, @min(minx, vs.start.x));
        maxx = @max(maxx, @max(maxx, vs.end.x));
        miny = @min(miny, @min(miny, vs.start.y));
        maxy = @max(maxy, @max(maxy, vs.end.y));
    }
    std.debug.print("minx = {}\n", .{minx});
    std.debug.print("maxx = {}\n", .{maxx});
    std.debug.print("miny = {}\n", .{miny});
    std.debug.print("maxy = {}\n", .{maxy});
    std.debug.print("--\n", .{});

    // {
    //     const grid_ncols = maxx - minx + 2;
    //     const grid_nrows = maxy - miny + 2;
    //     const total: usize = @intCast(grid_ncols * grid_nrows);

    //     var grid = try gpa.alloc(u8, total);
    //     defer gpa.free(grid);

    //     for (0..total) |k| {
    //         grid[k] = '.';
    //     }

    //     var k: usize = 0;
    //     while (k < path.items.len - 1) : (k += 1) {
    //         var pt1 = path.items[k];
    //         var pt2 = path.items[k + 1];

    //         if (pt1.x == pt2.x) {
    //             if (pt1.y > pt2.y) {
    //                 std.mem.swap(Point, &pt1, &pt2);
    //             }
    //             var y = pt1.y;
    //             while (y <= pt2.y) : (y += 1) {
    //                 const idx: usize = @intCast(grid_ncols * (y - miny) + pt1.x - minx);
    //                 grid[idx] = '#';
    //             }
    //         } else {
    //             if (pt1.x > pt2.x) {
    //                 std.mem.swap(Point, &pt1, &pt2);
    //             }
    //             var x = pt1.x;
    //             while (x <= pt2.x) : (x += 1) {
    //                 const idx: usize = @intCast(grid_ncols * (pt1.y - miny) + x - minx);
    //                 grid[idx] = '#';
    //             }
    //         }
    //     }

    //     k = 0;
    //     for (grid) |c| {
    //         std.debug.print("{c}", .{c});
    //         k += 1;
    //         if (k == grid_ncols) {
    //             std.debug.print("\n", .{});
    //             k = 0;
    //         }
    //     }
    // }
    // std.mem.sort(Segment, vsegments.items, {}, v_segment_cmp);

    for (hsegments.items) |hs| {
        const vs_count = vsegments.items.len;
        for (0..vs_count) |i| {
            const vs = &vsegments.items[i];
            
            if (vs.split(hs.start.y)) |s| {
                try vsegments.append(gpa, s);
            }
        }
    }

    std.mem.sort(Segment, vsegments.items, {}, v_segment_cmp);

    hsegments.clearRetainingCapacity();

    var i: usize = 0;
    while (i < vsegments.items.len) : (i += 2) {
        // std.debug.print("{}\n", .{vs});

        const hs1: Segment = .{
            .start = vsegments.items[i].start,
            .end = vsegments.items[i + 1].start,
        };
        const hs2: Segment = .{
            .start = vsegments.items[i].end,
            .end = vsegments.items[i + 1].end,
        };

        try hsegments.append(gpa, hs1);
        try hsegments.append(gpa, hs2);
    }

    i = 0;
    while (i < hsegments.items.len) {
        const hs0 = hsegments.items[i];

        var swapped = false;
        var j: usize = i + 1;
        
        while (j < hsegments.items.len) {
            const hs1 = hsegments.items[j];

            if (join_hsegments(hs0, hs1)) |s| {
                hsegments.items[i] = s;
                _ = hsegments.swapRemove(j);
                swapped = true;
            } else {
                j += 1;
            }
        }

        if (!swapped) {
            i += 1;
        }
    }

    // std.debug.print("new hs --\n", .{});
    // for (hsegments.items) |hs| {
    //     std.debug.print("{}\n", .{hs});
    // }

    var area: isize = 0;

    i = 0;
    while (i < vsegments.items.len) : (i += 2) {
        const vs1 = vsegments.items[i];
        const vs2 = vsegments.items[i + 1];
        area += (vs1.end.y - vs1.start.y - 1) * (vs2.start.x - vs1.start.x + 1);
    }

    for (hsegments.items) |hs| {
        area += hs.end.x - hs.start.x + 1;
    }

    std.debug.print("\narea = {}\n", .{area});

    // {
    //     const grid_ncols = maxx - minx + 2;
    //     const grid_nrows = maxy - miny + 2;
    //     const total: usize = @intCast(grid_ncols * grid_nrows);

    //     var grid = try gpa.alloc(u8, total);
    //     defer gpa.free(grid);

    //     for (0..total) |k| {
    //         // grid[k] = '.';
    //         grid[k] = '0';
    //     }

    //     i = 0;
    //     // while (i < vsegments.items.len) : (i += 2) {
    //     //     const vs1 = vsegments.items[i];
    //     //     const vs2 = vsegments.items[i + 1];
    //     //     // std.debug.print("{} -> {}\n", .{vs1, vs2});
    //     //     var y = vs1.start.y + 1;
    //     //     while (y < vs1.end.y) : (y += 1) {
    //     //         var x = vs1.start.x;
    //     //         while (x < vs2.start.x + 1) : (x += 1) {
    //     //             const idx: usize = @intCast(grid_ncols * (y - miny) + x - minx);
    //     //             // grid[idx] = '#';
    //     //             grid[idx] += 1;
    //     //         }
    //     //     }
    //     // }

    //     for (hsegments.items) |hs| {
    //         var x = hs.start.x;
    //         while (x < hs.end.x + 1) : (x += 1) {
    //             const idx: usize = @intCast(grid_ncols * (hs.start.y - miny) + x - minx);
    //             // grid[idx] = '#';
    //             grid[idx] += 1;
    //         }
    //     }

    //     var k: usize = 0;
    //     // while (k < path.items.len - 1) : (k += 1) {
    //     //     var pt1 = path.items[k];
    //     //     var pt2 = path.items[k + 1];

    //     //     if (pt1.x == pt2.x) {
    //     //         if (pt1.y > pt2.y) {
    //     //             std.mem.swap(Point, &pt1, &pt2);
    //     //         }
    //     //         var y = pt1.y;
    //     //         while (y <= pt2.y) : (y += 1) {
    //     //             const idx: usize = @intCast(grid_ncols * (y - miny) + pt1.x - minx);
    //     //             // grid[idx] = '@';
    //     //             // grid[idx] = '#';
    //     //             grid[idx] += 1;
    //     //         }
    //     //     } else {
    //     //         if (pt1.x > pt2.x) {
    //     //             std.mem.swap(Point, &pt1, &pt2);
    //     //         }
    //     //         var x = pt1.x;
    //     //         while (x <= pt2.x) : (x += 1) {
    //     //             const idx: usize = @intCast(grid_ncols * (pt1.y - miny) + x - minx);
    //     //             // grid[idx] = '@';
    //     //             // grid[idx] = '#';
    //     //             grid[idx] += 1;
    //     //         }
    //     //     }
    //     // }

    //     var count: usize = 0;
    //     var count1: usize = 0;
    //     var count2: usize = 0;
    //     var count3: usize = 0;
    //     var count4: usize = 0;
    //     var count5: usize = 0;
    //     var count6: usize = 0;
    //     var count7: usize = 0;
    //     k = 0;
    //     // var k: usize = 0;
    //     for (grid) |c| {
    //         std.debug.print("{c}", .{c});
    //         k += 1;
    //         if (k == grid_ncols) {
    //             std.debug.print("\n", .{});
    //             k = 0;
    //         }
    //         if (c != '0') {
    //             count += 1;
    //         }
    //         if (c == '1') {
    //             count1 += 1;
    //         }
    //         if (c == '2') {
    //             count2 += 1;
    //         }
    //         if (c == '3') {
    //             count3 += 1;
    //         }
    //         if (c == '4') {
    //             count4 += 1;
    //         }
    //         if (c == '5') {
    //             count5 += 1;
    //         }
    //         if (c == '6') {
    //             count6 += 1;
    //         }
    //         if (c == '7') {
    //             count7 += 1;
    //         }
    //     }

    //     std.debug.print("\ncount = {}\n", .{count});
    //     std.debug.print("count1 = {}\n", .{count1});
    //     std.debug.print("count2 = {}\n", .{count2});
    //     std.debug.print("count3 = {}\n", .{count3});
    //     std.debug.print("count4 = {}\n", .{count4});
    //     std.debug.print("count5 = {}\n", .{count5});
    //     std.debug.print("count6 = {}\n", .{count6});
    //     std.debug.print("count7 = {}\n", .{count7});
    // }
}
