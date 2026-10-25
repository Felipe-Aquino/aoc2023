const std = @import("std");

const Allocator = std.mem.Allocator;

const FreeEdgeSet = struct {
    gpa: Allocator,
    rand: std.Random,

    capacity: usize,
    size: usize,
    data: []usize,
    
    fn init(gpa: Allocator) FreeEdgeSet {
        return .{
            .gpa = gpa,
            .rand = std.crypto.random,
            .capacity = 0,
            .size = 0,
            .data = &.{},
        };
    }

    fn set_capacity(self: *FreeEdgeSet, capacity: usize) void {
        self.capacity = capacity;
        self.size = capacity;
        self.data = self.gpa.alloc(usize, capacity) catch unreachable();

        for (0..capacity) |i| {
            self.data[i] = i;
        }
    }

    fn deinit(self: *FreeEdgeSet) void {
        self.capacity = 0;
        self.size = 0;
        self.gpa.free(self.data);
    }

    fn reset(self: *FreeEdgeSet) void {
        self.size = self.capacity;

        for (0..self.capacity) |i| {
            self.data[i] = i;
        }
    }

    fn remove(self: *FreeEdgeSet, value: usize) void {
        if (std.mem.indexOfScalar(usize, self.data[0..self.size], value)) |idx| {
            const last = self.data[self.size - 1];
            self.data[self.size - 1] = value;
            self.data[idx] = last;

            self.size -= 1;
        }
    }

    fn get_random(self: FreeEdgeSet) usize {
        const idx = self.rand.intRangeAtMost(usize, 0, self.size - 1);

        return self.data[idx];
    }
};

const Edge = struct {
    vertex1: usize, 
    vertex2: usize, 
    removed: bool,

    fn eql(self: Edge, v1: usize, v2: usize) bool {
        return (self.vertex1 == v1 and self.vertex2 == v2) or
               (self.vertex1 == v2 and self.vertex2 == v1);
    }
};

const Vertex = struct {
    edges: std.ArrayList(usize),
    origin: ?Edge,
    count: usize,
    removed: bool,
};

const Graph = struct {
    gpa: Allocator,
    vertices: std.ArrayList(Vertex),
    edges: std.ArrayList(Edge),
    vertex_map: std.StringHashMap(usize),
    free_edges: FreeEdgeSet,

    fn read(gpa: Allocator, content: []const u8) !Graph {
        var graph: Graph = .{
            .gpa = gpa,
            .vertices = .empty,
            .edges = .empty,
            .vertex_map = .init(gpa),
            .free_edges = .init(gpa),
        };

        var iter = std.mem.splitSequence(u8, content, "\n");

        while (iter.next()) |line| {
            if (line.len == 0) continue;

            var iter2 = std.mem.splitSequence(u8, line, ": ");

            const name = iter2.next().?;
            const next_list = iter2.next().?;

            const vertex_idx: usize = try graph.find_or_add_vertex(name) ;

            var iter3 = std.mem.splitSequence(u8, next_list, " ");

            while (iter3.next()) |next_name| {
                const next_vertex_idx: usize = try graph.find_or_add_vertex(next_name);

                var found = false;

                for (graph.edges.items) |e| {
                    found = e.eql(vertex_idx, next_vertex_idx);

                    if (found) {
                        break;
                    }
                }

                if (!found) {
                    const edge = Edge{ .vertex1 = vertex_idx, .vertex2 = next_vertex_idx, .removed = false };
                    try graph.edges.append(gpa, edge);
                }
            }
        }

        for (graph.edges.items, 0..) |e, k| {
            var v = &graph.vertices.items[e.vertex1];
            try v.edges.append(gpa, k);

            v = &graph.vertices.items[e.vertex2];
            try v.edges.append(gpa, k);
        }

        graph.free_edges.set_capacity(graph.edges.items.len);

        return graph;
    }

    fn deinit(self: *Graph) void {
        for (self.vertices.items) |*v| {
            v.edges.deinit(self.gpa);
        }

        self.vertices.deinit(self.gpa);
        self.edges.deinit(self.gpa);

        self.vertex_map.deinit();
        self.free_edges.deinit();
    }

    fn find_or_add_vertex(self: *Graph, name: []const u8) !usize {
        if (self.vertex_map.get(name)) |idx| {
            return idx;
        }

        const new_vertex: Vertex = .{
            .edges = .empty, // .initCapacity(self.gpa, 6),
            .origin = null,
            .count = 1,
            .removed = false,
        };

        try self.vertices.append(self.gpa, new_vertex);

        const vertex_idx = self.vertices.items.len - 1;

        try self.vertex_map.put(name, vertex_idx);

        return vertex_idx;
    }

    fn contraction(self: *Graph, edge_idx: usize) !void {
        _ = self.free_edges.remove(edge_idx);

        var edge = &self.edges.items[edge_idx];
        edge.removed = true;

        const v1 = &self.vertices.items[edge.vertex1];
        const v2 = &self.vertices.items[edge.vertex2];

        v1.removed = true;
        v2.removed = true;

        var new_vertex: Vertex = .{
            .edges = .empty, // .initCapacity(gpa, 6),
            .origin = edge.*,
            .count = v1.count + v2.count,
            .removed = false,
        };

        const new_vertex_idx = self.vertices.items.len;

        for (v1.edges.items) |eidx| {
            if (eidx == edge_idx) continue;

            var e = &self.edges.items[eidx];

            if (e.eql(edge.vertex1, edge.vertex2)) {
                e.removed = true;
                _ = self.free_edges.remove(eidx);
                continue;
            }

            try new_vertex.edges.append(self.gpa, eidx);

            if (e.vertex1 == edge.vertex1) {
                e.vertex1 = new_vertex_idx;
            } else {
                e.vertex2 = new_vertex_idx;
            }
        }

        for (v2.edges.items) |eidx| {
            if (eidx == edge_idx) continue;

            var e = &self.edges.items[eidx];

            if (e.eql(edge.vertex1, edge.vertex2)) {
                e.removed = true;
                _ = self.free_edges.remove(eidx);
                continue;
            }

            try new_vertex.edges.append(self.gpa, eidx);

            if (e.vertex1 == edge.vertex2) {
                e.vertex1 = new_vertex_idx;
            } else {
                e.vertex2 = new_vertex_idx;
            }
        }

        try self.vertices.append(self.gpa, new_vertex);
    }

    fn print(self: Graph) void {
        std.debug.print("vertices\n", .{});
        for (self.vertices.items, 0..) |v, i| {
            if (!v.removed) {
                std.debug.print("[{}], {}, {any}: ", .{i, v.count, v.origin});
                for (v.edges.items) |e| {
                    std.debug.print("{}, ", .{e});
                }
                std.debug.print("\n", .{});
            }
        }

        std.debug.print("edges\n", .{});
        for (self.edges.items, 0..) |e, i| {
            if (!e.removed) {
                std.debug.print("[{}]: ({}, {})\n", .{i, e.vertex1, e.vertex2 });
            }
        }
    }
};

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var graph = try Graph.read(gpa, content);
    defer graph.deinit();

    var vertices_backup = try graph.vertices.clone(graph.gpa);
    var edges_backup = try graph.edges.clone(graph.gpa);
    defer {
        vertices_backup.deinit(graph.gpa);
        edges_backup.deinit(graph.gpa);
    }

    graph.free_edges.reset();

    const N: f64 = @floatFromInt(graph.vertices.items.len);
    
    const attempts: usize = @intFromFloat(N * (N - 1) * @log(N) / 2.0);
    var k: usize = 0;

    while (k < attempts): (k += 1) {
        var vertex_count = graph.vertices.items.len;
        while (vertex_count > 2) {
            const edge_idx = graph.free_edges.get_random();

            // std.debug.print("-- {} -- remove = {}\n", .{vertex_count, edge_idx});
            // graph.print();

            try graph.contraction(edge_idx);

            vertex_count -= 1;
        }

        // std.debug.print("-- {} -- \n", .{vertex_count});
        // graph.print();

        // const edge = graph.edges.getLast();
        const edge_idx = graph.free_edges.get_random();
        const edge = graph.edges.items[edge_idx];

        // const cut_count = graph.vertices.items[edge.vertex1].edges.items.len;
        const cut_count = graph.free_edges.size;

        const v1 = graph.vertices.items[edge.vertex1];
        const v2 = graph.vertices.items[edge.vertex2];

        if (cut_count == 3) {
            std.debug.print("[DONE] - {}: cut = 3, v1 = {}, v2 = {}\n", .{k, v1.count, v2.count});
            std.debug.print("result = {}\n", .{v1.count * v2.count});
            break;
        } else {
            std.debug.print("[NOT DONE] - {}: cut = {}, v1 = {}, v2 = {}\n", .{k, cut_count, v1.count, v2.count});

            for (vertices_backup.items.len..graph.vertices.items.len) |i| {
                var v = &graph.vertices.items[i];
                v.edges.deinit(graph.gpa);
            }
            graph.vertices.deinit(graph.gpa);
            graph.edges.deinit(graph.gpa);

            graph.vertices = try vertices_backup.clone(graph.gpa);
            graph.edges = try edges_backup.clone(graph.gpa);

            graph.free_edges.reset();
        }
    }
}
