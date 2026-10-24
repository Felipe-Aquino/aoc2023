const std = @import("std");

const Allocator = std.mem.Allocator;

fn read_f64(s: []const u8) !f64 {
    return std.fmt.parseFloat(f64, std.mem.trim(u8, s, " "));
}

const CrossError = error {
    NotCross,
    CrossedInPast,
};


// pxa + vxa * t = pxb + vxb * t
// pxa - pxb = (vxb - vxa) * t
//
// -(pxb - pxa) = (vxb - vxa) * t
// -(pyb - pya) = (vyb - vya) * t
// -(pzb - pza) = (vzb - vza) * t
//
// (pxb - pxa) * (vyb - vya) * (vzb - vza) = (pyb - pya) * (vxb - vxa)* (vzb - vza) =  (pzb - pza) * (vxb - vxa)* (vyb - vya)

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

    // x = x0 + vx(z - z0)/vz
    // y = y0 + vy(z - z0)/vz

    // (x - x0)*vz = vx(z - z0)
    // (y - y0)*vz = vy(z - z0)
    // (x - x0 + y - y0)*vz = (vx + vz)*(z - z0)

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

const Matrix = struct {
    data: []f128,
    ncols: usize,
    nrows: usize,

    fn init(gpa: Allocator, nrows: usize, ncols: usize) !Matrix {
        const data = try gpa.alloc(f128, ncols * nrows);

        return .{
            .data = data,
            .ncols = ncols,
            .nrows = nrows,
        };
    }
    fn zeros(gpa: Allocator, nrows: usize, ncols: usize) !Matrix {
        var data = try gpa.alloc(f128, ncols * nrows);
        for (0..data.len) |i| {
            data[i] = 0.0;
        }

        return .{
            .data = data,
            .ncols = ncols,
            .nrows = nrows,
        };
    }
    
    fn deinit(self: Matrix, gpa: Allocator) void {
        gpa.free(self.data);
    }

    fn get(self: Matrix, i: usize, j: usize) f128 {
        return self.data[self.ncols * i + j];
    }

    fn set(self: Matrix, i: usize, j: usize, value: f128) void {
        self.data[self.ncols * i + j] = value;
    }

    fn mult(self: Matrix, other: Matrix, gpa: Allocator) !Matrix {
        std.debug.assert(self.ncols == other.nrows);

        var result = try Matrix.init(gpa, self.nrows, other.ncols);

        for (0..self.nrows) |i| {
            for (0..other.ncols) |j| {
                var total: f128 = 0;
                for (0..self.ncols) |k| {
                    total += self.get(i, k) * other.get(k, j);
                }

                result.set(i, j, total);
            }
        }

        return result;
    }

    fn print(self: Matrix) void {
        for (0..self.nrows) |i| {
            for (0..self.ncols) |j| {
                std.debug.print("{}, ", .{self.get(i, j)});
            }
            std.debug.print("\n", .{});
        }

        std.debug.print("\n", .{});
    }

    fn transpose(self: Matrix, gpa: Allocator) !Matrix {
        var result = try Matrix.init(gpa, self.ncols, self.nrows);

        for (0..self.nrows) |i| {
            for (0..self.ncols) |j| {
                result.set(j, i, self.get(i, j));
            }
        }

        return result;
    }

    fn swap_rows(self: *Matrix, i_1: usize, i_2: usize) void {
        for (0..self.ncols) |j| {
            const aux = self.get(i_1, j);
            self.set(i_1, j, self.get(i_2, j));
            self.set(i_2, j, aux);
        }
    }

    fn reduce(self: Matrix, gpa: Allocator) !Matrix {
        var result = try Matrix.init(gpa, self.nrows, self.ncols);

        std.mem.copyForwards(f128, result.data, self.data);
        
        for (0..result.nrows) |i| {
            {
                const pivot_value = result.get(i, i);
                var pivot_idx = i;
                for (i+1..result.nrows) |k| {
                    if (pivot_value < result.get(k, i)) {
                        pivot_idx = k;
                    }
                }

                if (pivot_idx != i) {
                    result.swap_rows(pivot_idx, i);
                }
            }

            {
                const pivot_value = result.get(i, i);

                for (0..result.ncols) |j| {
                    const v = result.get(i, j);
                    result.set(i, j, v / pivot_value);
                }
            }

            for (i+1..result.nrows) |k| {
                const leading_value = result.get(k, i);

                for (i..result.ncols) |j| {
                    const v = result.get(k, j) - result.get(i, j) * leading_value;
                    result.set(k, j, v);
                }
            }

            result.print();
        }

        return result;
    }

    fn reduce2(A: *Matrix, b: *Matrix) void {
        for (0..A.nrows) |i| {
            {
                const pivot_value = A.get(i, i);
                var pivot_idx = i;
                for (i+1..A.nrows) |k| {
                    if (pivot_value < A.get(k, i)) {
                        pivot_idx = k;
                    }
                }

                if (pivot_idx != i) {
                    A.swap_rows(pivot_idx, i);
                    b.swap_rows(pivot_idx, i);
                }
            }

            {
                const pivot_value = A.get(i, i);

                for (0..A.ncols) |j| {
                    const v = A.get(i, j);
                    A.set(i, j, v / pivot_value);
                }

                for (0..b.ncols) |j| {
                    const bv = b.get(i, j);
                    b.set(i, j, bv / pivot_value);
                }
            }

            for (i+1..A.nrows) |k| {
                const leading_value = A.get(k, i);

                for (i..A.ncols) |j| {
                    const v = A.get(k, j) - A.get(i, j) * leading_value;
                    A.set(k, j, v);
                }

                for (0..b.ncols) |j| {
                    const v = b.get(k, j) - b.get(i, j) * leading_value;
                    b.set(k, j, v);
                }
            }

            // A.print();
            // b.print();
            // std.debug.print("-----------\n", .{});
        }
    }

    fn solveAxb(self: Matrix, b: Matrix, gpa: Allocator) !Matrix {
        var result = try Matrix.init(gpa, self.nrows, b.ncols);
        var aux = try Matrix.init(gpa, self.nrows, self.ncols);

        std.mem.copyForwards(f128, aux.data, self.data);
        std.mem.copyForwards(f128, result.data, b.data);

        aux.reduce2(&result);

        for (0..result.ncols) |j| {
            for (1..result.nrows) |i_0| {
                const i: usize = result.nrows - i_0 - 1;

                var v: f128 = result.get(i, j);

                for (i+1..result.nrows) |k| {
                    v -= aux.get(i, k) * result.get(k, j);
                }

                result.set(i, j, v);
            }
        }
        
        aux.deinit(gpa);

        return result;
    }
};

pub fn part2(gpa: Allocator, content: []const u8) !void {
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

    // vi = (ai, bi, ci)
    //
    // (x1 - x) / (a1 - a) = (y1 - y) / (b1 - b)
    // (x1 - x) / (a1 - a) = (z1 - z) / (c1 - c)
    //
    // x*b - a*y - x1*b - x*b1 + a*y1 + a1*y = a1*y1 - x1*b1 = t1
    // x*b - a*y - x2*b - x*b2 + a*y2 + a2*y = a2*y2 - x1*b2 = t2
    //
    // b*(x2 - x1) + x*(b2 - b1) + a*(y1 - y2) + y*(a1 - a2) = t1 - t2
    // x*(b2 - b1) + y*(a1 - a2) + a*(y1 - y2) + b*(x2 - x1) = t1 - t2
    //
    // x*(b2 - b1) + y*(a1 - a2) + a*(y1 - y2) + b*(x2 - x1) = t1 - t2
    // x*(b3 - b2) + y*(a2 - a3) + a*(y2 - y3) + b*(x3 - x2) = t2 - t3
    // x*(b4 - b3) + y*(a3 - a4) + a*(y3 - y4) + b*(x4 - x3) = t3 - t4
    // ...
    //
    // | (b2 - b1) (a1 - a2) (y1 - y2) (x2 - x1) |   |x| = | t1 - t2 |
    // | (b3 - b2) (a2 - a3) (y2 - y3) (x3 - x2) | * |y|   | t2 - t3 |
    // | (b4 - b3) (a3 - a4) (y3 - y4) (x4 - x3) |   |a|   | t3 - t4 |
    // | ...                                     |   |b|   | ...     |
    //
    //            M                                  x   =  r

    const N = hails.items.len / 2;
    var M = try Matrix.zeros(gpa, N, 4);
    var r = try Matrix.zeros(gpa, N, 1);
    var M2 = try Matrix.zeros(gpa, N, 4);
    var r2 = try Matrix.zeros(gpa, N, 1);

    defer {
        M.deinit(gpa);
        r.deinit(gpa);
        M2.deinit(gpa);
        r2.deinit(gpa);
    }
    
    {
        var k: usize = 0;
        while (k < hails.items.len - 1): (k += 2) {
            // xyab
            const h1 = hails.items[k];
            const h2 = hails.items[k + 1];
            const row = k / 2;

            M.set(row, 0, (h2.velocity[1] - h1.velocity[1]));
            M.set(row, 1, (h1.velocity[0] - h2.velocity[0]));
            M.set(row, 2, (h1.position[1] - h2.position[1]));
            M.set(row, 3, (h2.position[0] - h1.position[0]));

            var t1 = h1.velocity[0]*h1.position[1] - h1.position[0]*h1.velocity[1];
            var t2 = h2.velocity[0]*h2.position[1] - h2.position[0]*h2.velocity[1];

            r.set(row, 0, t1 - t2);

            // xzac
            M2.set(row, 0, (h2.velocity[2] - h1.velocity[2]));
            M2.set(row, 1, (h1.velocity[0] - h2.velocity[0]));
            M2.set(row, 2, (h1.position[2] - h2.position[2]));
            M2.set(row, 3, (h2.position[0] - h1.position[0]));

            t1 = h1.velocity[0]*h1.position[2] - h1.position[0]*h1.velocity[2];
            t2 = h2.velocity[0]*h2.position[2] - h2.position[0]*h2.velocity[2];

            r2.set(row, 0, t1 - t2);
        }
    }
    
    var Mt = try M.transpose(gpa);
    var Mpseudo = try Mt.mult(M, gpa);
    var rpseudo = try Mt.mult(r, gpa);

    // Mpseudo.print();
    // rpseudo.print();

    // M*x = b
    // (M'*M)*x = (M'b)
    // x' = inv(M'*M) * (M'b)
    //
    const xyab = try Mpseudo.solveAxb(rpseudo, gpa);
    defer xyab.deinit(gpa);

    std.debug.print("xyab =\n", .{});
    xyab.print();

    Mt.deinit(gpa);
    Mpseudo.deinit(gpa);
    rpseudo.deinit(gpa);

    Mt = try M2.transpose(gpa);
    Mpseudo = try Mt.mult(M2, gpa);
    rpseudo = try Mt.mult(r2, gpa);

    const xzac = try Mpseudo.solveAxb(rpseudo, gpa);
    defer xzac.deinit(gpa);

    std.debug.print("xzac =\n", .{});
    xzac.print();

    const x = @round(xyab.get(0, 0));
    const y = @round(xyab.get(1, 0));
    const z = @round(xzac.get(1, 0));

    std.debug.print("total = {} + {} + {} = {}\n", .{x, y, z, x + y + z});
}
