const std = @import("std");

const Allocator = std.mem.Allocator;

fn read_f64(s: []const u8) !f64 {
    return std.fmt.parseFloat(f64, std.mem.trim(u8, s, " "));
}

const CrossError = error {
    NotCross,
    CrossedInPast,
};

const Hail = struct {
    position: @Vector(3, f64),
    velocity: @Vector(3, f64),

    fn cross_point(self: Hail, other: Hail) CrossError!@Vector(2, f64) {
        // xa = pxa + vxa * ta
        // xb = pxb + vxb * tb
        //
        // ya = pya + vya * ta
        // yb = pyb + vyb * tb
        //
        // vxa * ta - vxb * tb = pxb - pxa
        // vya * ta - vyb * tb = pyb - pya
        //
        // DET = -(vxa * vyb - vxb * vya)
        //
        // |vxa   -vxb|  -inv-> |-vyb  vxb|
        // |vya   -vyb|         |-vya  vxa|
        //
        // ta = -(vyb*(pxb - pxa) - vxb*(pyb - pya)) / DET
        // tb = -(vya*(pxb - pxa) - vxa*(pyb - pya)) / DET

        const vxa = self.velocity[0];
        const vya = self.velocity[1];
        const vxb = other.velocity[0];
        const vyb = other.velocity[1];

        const dpx = other.position[0] - self.position[0]; // pxb - pxa
        const dpy = other.position[1] - self.position[1]; // pyb - pya

        const det = -(vxa * vyb - vxb * vya);

        if (@abs(det) <= 1e-6) {
            return CrossError.NotCross;
        }

        const ta = -(vyb*dpx - vxb*dpy) / det;
        const tb = -(vya*dpx - vxa*dpy) / det;

        std.debug.print("ta = {}, tb = {}\n", .{ta, tb});

        if (ta <= 0.0 or tb <= 0) {
            return CrossError.CrossedInPast;
        }

        const point: @Vector(2, f64) = .{
            self.position[0] + vxa * ta,
            self.position[1] + vya * ta,
        };

        return point;
    }

    fn cross_point2(self: Hail, other: Hail) ?@Vector(2, f64) {
        // x = pxa + vxa * ta
        // y = pya + vya * ta
        //
        // x = pxb + vxb * tb
        // y = pyb + vyb * tb
        //
        // x * vya - y * vxa = pxa * vya - pya * vxa
        // x * vyb - y * vxb = pxb * vyb - pyb * vxb
        //
        // x * vya + y * (-vxa) = pxa * vya - pya * vxa
        // x * vyb + y * (-vxb) = pxb * vyb - pyb * vxb
        //
        // DET = -vya * vxb + vyb * vxa
        //
        // |vya   -vxa|   -inv->  |-vxb   vxa|
        // |vyb   -vxb|           |-vyb   vya|
        //
        // r1 = pxa * vya - pya * vxa
        // r2 = pxb * vyb - pyb * vxb
        //
        // x = ((-vxb)*r1 + vxa * r2) / DET
        // y = ((-vyb)*r1 + vya * r2) / DET

        const vxa = self.velocity[0];
        const vya = self.velocity[1];
        const vxb = other.velocity[0];
        const vyb = other.velocity[1];

        const det = -vya * vxb + vyb * vxa;

        if (@abs(det) <= 1e-6) {
            return null;
        }

        const pxa = self.position[0];
        const pya = self.position[1];
        const pxb = other.position[0];
        const pyb = other.position[1];

        const r1 = pxa * vya - pya * vxa;
        const r2 = pxb * vyb - pyb * vxb;

        const x = (-vxb * r1 + vxa * r2) / det;
        const y = (-vyb * r1 + vya * r2) / det;

        const point: @Vector(2, f64) = .{ x, y };

        return point;
    }
};

const Rectangle = struct {
    x: f64,
    y: f64,
    w: f64,
    h: f64,

    fn is_inside(self: Rectangle, p: @Vector(2, f64)) bool {
        return (self.x <= p[0] and p[0] <= self.x + self.w) and
               (self.y <= p[1] and p[1] <= self.y + self.h);
    }
};

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var hails: std.ArrayList(Hail) = .empty;
    defer hails.deinit(gpa);

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) continue;
        
        var pos: @Vector(3, f64) = @splat(0);
        var velocity: @Vector(3, f64) = @splat(0);

        var iter2 = std.mem.splitSequence(u8, line, " @ ");
        var iter3 = std.mem.splitSequence(u8, iter2.next().?, ",");
        var i: usize = 0;

        while (iter3.next()) |s| {
            pos[i] = try read_f64(s);
            i += 1;
        }

        iter3 = std.mem.splitSequence(u8, iter2.next().?, ",");
        i = 0;

        while (iter3.next()) |s| {
            velocity[i] = try read_f64(s);
            i += 1;
        }


        const hail = Hail { .position = pos, .velocity = velocity };
        try hails.append(gpa, hail);
    }

    // const rect: Rectangle = .{ .x = 7.0, .y = 7.0, .w = 20.0, .h = 20.0 };
    const rect: Rectangle = .{ .x = 2e14, .y = 2e14, .w = 2e14, .h = 2e14 };
    
    var count: usize = 0;

    for (hails.items, 0..) |h1, i| {
        for (i+1..hails.items.len) |j| {
            const h2 = hails.items[j];

            std.debug.print("{}\n", .{h1});
            std.debug.print("{}\n", .{h2});

            if (h1.cross_point(h2)) |pt| {
                std.debug.print("they cross at {}\n", .{pt});
                if (rect.is_inside(pt)) {
                    std.debug.print("-- inside\n", .{});
                    count += 1;
                } else {
                    std.debug.print("-- outside\n", .{});
                }
            } else |err| {
                if (err == CrossError.NotCross) {
                    std.debug.print("they don't cross\n", .{});
                } else {
                    std.debug.print("they already crossed\n", .{});
                }
            }
            std.debug.print("----\n", .{});
        }
    }

    std.debug.print("\n{} hailstones paths crossed\n", .{count});
}
