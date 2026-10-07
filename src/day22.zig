const std = @import("std");

const Allocator = std.mem.Allocator;

const Point = struct {
    x: i32,
    y: i32,
    z: i32,

    fn read(data: []const u8) !Point {
        var iter = std.mem.splitSequence(u8, data, ",");
        const x = try std.fmt.parseInt(i32, iter.next().?, 10);
        const y = try std.fmt.parseInt(i32, iter.next().?, 10);
        const z = try std.fmt.parseInt(i32, iter.next().?, 10);

        return .{ .x = x, .y = y, .z = z };
    }

    fn diff_sum(self: Point, other: Point) i32 {
        return (self.x - other.x) + (self.y - other.y) + (self.z - other.z);
    }
};

const Brick = struct {
    p1: Point,
    p2: Point,

    fn read(data: []const u8) !Brick {
        var iter = std.mem.splitSequence(u8, data, "~");
        const p1 = try Point.read(iter.next().?);
        const p2 = try Point.read(iter.next().?);

        if (p2.diff_sum(p1) < 0) {
            return .{ .p1 = p2, .p2 = p1 };
        }

        return .{ .p1 = p1, .p2 = p2 };
    }

    fn size(self: Brick) i32 {
        return (self.p2.x - self.p1.x) +
               (self.p2.y - self.p1.y) +
               (self.p2.z - self.p1.z) +
               1;
    }

    fn print(self: Brick) void {
        std.debug.print("[({}, {}, {}), ({}, {}, {})] :: {}\n", .{
            self.p1.x,
            self.p1.y,
            self.p1.z,
            self.p2.x,
            self.p2.y,
            self.p2.z,
            self.size(),
        });
    }

    fn collides(self: Brick, other: Brick) bool {
        return !(self.p2.x < other.p1.x or
                 self.p1.x > other.p2.x or
                 self.p2.y < other.p1.y or
                 self.p1.y > other.p2.y or
                 self.p2.z < other.p1.z or
                 self.p1.z > other.p2.z);
    }

    fn z_compare(self: Brick, other: Brick) bool {
        // if (self.p2.z > self.p1.z) {
        // }
        // if (other.p2.z > other.p1.z) {
        // }

        return self.p1.z > other.p1.z;
    }

    fn fall_once(self: Brick) ?Brick {
        if (self.p1.z == 1) {
            return null;
        }

        var new_brick = self;
        new_brick.p1.z -= 1;
        new_brick.p2.z -= 1;

        return new_brick;
    }
};

fn brick_z_cmp(_: void, lhs: Brick, rhs: Brick) bool {
    return lhs.z_compare(rhs);
}

fn make_bricks_fall(bricks: *[]Brick) void {
    var finished = false;
    const sz = bricks.len;

    while (!finished) {
        finished = true;
        var i = sz;

        while (i >= 1) {
            i -= 1;

            var brick = bricks.*[i];
            var fallen: Brick = undefined;

            if (brick.fall_once()) |b| {
                fallen = b;
            } else {
                continue;
            }

            var can_fall = true;

            // TODO: not loop 'em all
            // for (bricks.*, 0..) |b, j| {
            //     if (j != i and fallen.collides(b)) {
            //         can_fall = false;
            //         break;
            //     }
            // }

            for (i+1..sz) |j| {
                const b = bricks.*[j];
                if (j != i and fallen.collides(b)) {
                    can_fall = false;
                    break;
                }
            }

            if (can_fall) {
                bricks.*[i] = fallen;
                finished = false;
            }
        }
    }
}

const FallDependency = struct {
    brick_idx: usize,
    supported_by: std.ArrayList(usize),
    can_remove: bool,

    fn init(idx: usize) FallDependency {
        return .{
            .brick_idx = idx,
            .supported_by = .empty,
            .can_remove = true,
        };
    }

    fn print(self: FallDependency) void {
        std.debug.print(
            "{}, {any} __ {any}\n",
            .{self.brick_idx, self.supported_by.items, self.can_remove}
        );
    }
};

fn create_fall_dependencies(gpa: Allocator, bricks: []Brick) !std.ArrayList(FallDependency) {
    var dependencies: std.ArrayList(FallDependency) = .empty;

    const sz = bricks.len;

    var i = sz;

    while (i >= 1) {
        i -= 1;

        var dependency = FallDependency.init(i);

        var brick = bricks[i];
        var fallen: Brick = undefined;

        if (brick.fall_once()) |b| {
            fallen = b;
        } else {
            try dependencies.append(gpa, dependency);
            continue;
        }

        // TODO: not loop 'em all
        // for (bricks.*, 0..) |b, j| {
        //     if (j != i and fallen.collides(b)) {
        //         can_fall = false;
        //         break;
        //     }
        // }

        for (i+1..sz) |j| {
            const b = bricks[j];
            if (j != i and fallen.collides(b)) {
                try dependency.supported_by.append(gpa, j);
            }
        }

        try dependencies.append(gpa, dependency);
    }

    for (dependencies.items) |*d1| {
        for (dependencies.items) |d2| {
            if (std.mem.indexOfScalar(usize, d2.supported_by.items, d1.brick_idx)) |_| {
                if (d2.supported_by.items.len == 1) {
                    d1.can_remove = false;
                    break;
                }
            }
        }

    }

    return dependencies;
}

fn fall_dep_cmp(_: void, lhs: FallDependency, rhs: FallDependency) bool {
    return lhs.brick_idx > rhs.brick_idx;
}

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var bricks: std.ArrayList(Brick) = .empty;
    defer bricks.deinit(gpa);

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) continue;
        const brick = try Brick.read(line);

        try bricks.append(gpa, brick);
    }

    std.mem.sort(Brick, bricks.items, {}, brick_z_cmp);

    for (bricks.items) |item| {
        item.print();
    }

    // std.debug.print("----------\n", .{});
    make_bricks_fall(&bricks.items);

    for (bricks.items) |item| {
        item.print();
    }

    var dependencies = try create_fall_dependencies(gpa, bricks.items);
    defer {
        for (dependencies.items) |*d| {
            d.supported_by.deinit(gpa);
        }

        dependencies.deinit(gpa);
    }

    var desintagratable: usize = 0;
    for (dependencies.items) |*d| {
        d.print();

        if (d.can_remove) {
            desintagratable += 1;
        }
    }

    std.debug.print("{} bricks can be disintegrated\n", .{ desintagratable });
}

const Set = struct {
    gpa: Allocator,
    data: std.ArrayList(usize),

    fn init(gpa: Allocator) Set {
        return .{
            .gpa = gpa,
            .data = .empty,
        };
    }

    fn deinit(self: *Set) void {
        self.data.deinit(self.gpa);
    }

    fn put(self: *Set, value: usize) !void {
        if (std.mem.indexOfScalar(usize, self.data.items, value) == null) {
            try self.data.append(self.gpa, value);
        }
    }

    fn count(self: Set) usize {
        return self.data.items.len;
    }

    fn get(self: Set, at: usize) usize {
        return self.data.items[at];
    }
};

pub fn part2(gpa: Allocator, content: []const u8) !void {
    var bricks: std.ArrayList(Brick) = .empty;
    defer bricks.deinit(gpa);

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) continue;
        const brick = try Brick.read(line);

        try bricks.append(gpa, brick);
    }

    std.mem.sort(Brick, bricks.items, {}, brick_z_cmp);

    for (bricks.items) |item| {
        item.print();
    }

    // std.debug.print("----------\n", .{});
    make_bricks_fall(&bricks.items);

    for (bricks.items) |item| {
        item.print();
    }

    var dependencies = try create_fall_dependencies(gpa, bricks.items);
    defer {
        for (dependencies.items) |*d| {
            d.supported_by.deinit(gpa);
        }

        dependencies.deinit(gpa);
    }

    var chains: []Set = try gpa.alloc(Set, bricks.items.len);
    defer {
        for (chains) |*c| {
            c.deinit();
        }
        gpa.free(chains);
    }

    // std.mem.sort(FallDependency, dependencies.items, {}, fall_dep_cmp);
    for (0..bricks.items.len) |i| {
        chains[i] = Set.init(gpa);

        for (dependencies.items) |d| {
            if (d.supported_by.items.len == 1 and std.mem.indexOfScalar(usize, d.supported_by.items, i) != null) {
                try chains[i].put(d.brick_idx);
            }
        }

        try follow_chain(&chains[i], dependencies.items);
    }

    var count: usize = 0;
    for (chains, 0..) |chain, i| {
        // std.debug.print("| {}: {} -- {any}\n", .{i, chain.data.items.len, chain.data.items});
        std.debug.print("| {}: {} -- {any}\n", .{i, chain.data.items.len, chain.data.items});
        count += chain.data.items.len;
    }

    std.debug.print("count = {}\n", .{count});
}

fn intersect_count(a: []usize, b: []usize) usize {
    var count: usize = 0;
    for (b) |e2| {
        for (a) |e1| {
            if (e1 == e2) {
                count += 1;
                break;
            }
        }
    }

    return count;
}

fn follow_chain(chain: *Set, dependencies: []FallDependency) !void {
    var i: usize = 0;

    // std.debug.print("#############\n", .{});
    while (i < chain.count()) : (i += 1) {
        // std.debug.print("{any}\n", .{chain.data.items});
        for (dependencies) |d| {
            const intersections = intersect_count(d.supported_by.items, chain.data.items);
            const remaining = d.supported_by.items.len - intersections;

            if (d.supported_by.items.len > 0 and remaining == 0) {
            // if (std.mem.indexOfScalar(usize, d.supported_by.items, brick_idx)) |_| {
                try chain.put(d.brick_idx);
            }
        }
    }
}

