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
}

pub fn part2(gpa: Allocator, content: []const u8) !void {
    var path: std.ArrayList(Point) = .empty;

    var iter = std.mem.splitSequence(u8, content, "\n");
    var point: Point = .{ .x = 0, .y = 0 };

    try path.append(gpa, point);

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        var column_iter = std.mem.splitSequence(u8, line, " ");
        _ = column_iter.next().?;
        _ = column_iter.next().?;
        const encoded = std.mem.trim(u8, column_iter.next().?, "()#");
        const dir = encoded[5..];
        const amount_str = encoded[0..5];
        const amount = try std.fmt.parseInt(isize, amount_str, 16);

        std.debug.print("{s} :: {s} ({})\n", .{ dir, amount_str, amount });
        switch (dir[0]) {
            '1' => {
                point.y += amount;
            },
            '3' => {
                point.y -= amount;
            },
            '2' => {
                point.x -= amount;
            },
            '0' => {
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
}
