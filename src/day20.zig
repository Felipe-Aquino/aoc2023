const std = @import("std");

const Allocator = std.mem.Allocator;

const ModuleType = enum {
    FlipFlop,
    Conjunction,
    Broadcaster,
    DeadEnd,
};

const Node = struct {
    name: []const u8,
    inputs: std.ArrayList(struct{*Node, PulseType}),
    outputs: std.ArrayList(*Node),
    state: ?State,
    module_type: ModuleType,

    fn init(self: *Node, allocator: Allocator, name: []const u8, mod: ModuleType) !void {
        self.name = name;
        self.inputs = try .initCapacity(allocator, 16);
        self.outputs = try .initCapacity(allocator, 16);
        self.state = if (mod == .FlipFlop) .Off else null;
        self.module_type = mod;
    }
};

const PulseType = enum(u8) {
    High = 'H',
    Low = 'L',
};

const Pulse = struct {
    origin: *Node,
    destination: *Node,
    type_: PulseType,
};

const State = enum(u8) {
    On = '1',
    Off = '0',
};

const Count = struct {
    high_pulses: usize,
    low_pulses: usize,

    fn add(self: Count, other: Count) Count {
        return .{
            .high_pulses = self.high_pulses + other.high_pulses,
            .low_pulses = self.low_pulses + other.low_pulses,
        };
    }
};

fn read_nodes(arena: Allocator, modules: *std.StringHashMap(*Node), content: []const u8) !void {
    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        var iter2 = std.mem.splitSequence(u8, line, " -> ");

        const name = iter2.next().?;
        const outputs_names = iter2.next().?;

        const module_type: ModuleType = 
            switch (name[0]) {
                '%' => .FlipFlop,
                '&' => .Conjunction,
                else =>
                    if (std.mem.eql(u8, name, "broadcaster"))
                        .Broadcaster
                    else
                        .DeadEnd
            };

        const module_name: []const u8 = 
            if (std.mem.eql(u8, name, "broadcaster"))
                name
            else
                name[1..];

        var node: *Node = undefined;

        if (modules.get(module_name)) |n| {
            node = n;
            node.name = name;
            node.module_type = module_type;
            node.state = if (module_type == .FlipFlop) .Off else null;
        } else {
            node = try arena.create(Node);
            try node.init(arena, name, module_type);

            try modules.put(module_name, node);
        }

        var out_iter = std.mem.splitSequence(u8, outputs_names, ", ");
        while (out_iter.next()) |out_name| {

            if (out_name.len == 0) continue;
            if (modules.get(out_name)) |out| {
                try node.outputs.append(arena, out);

                try out.inputs.append(arena, .{ node, .Low });
            } else {
                var out = try arena.create(Node);
                try out.init(arena, out_name, .DeadEnd);

                try node.outputs.append(arena, out);
                try out.inputs.append(arena, .{ node, .Low });

                try modules.put(out_name, out);
            }
        }
    }
}

fn push_button(gpa: Allocator, modules: *std.StringHashMap(*Node)) !Count {
    var count = Count { .high_pulses = 0, .low_pulses = 1 };

    var pulse_list: std.ArrayList(Pulse) = .empty;
    defer pulse_list.deinit(gpa);

    const broadcaster = modules.get("broadcaster").?;

    for (broadcaster.outputs.items) |out| {
        const pulse: Pulse = .{ .origin = broadcaster, .destination = out, .type_ = .Low };
        try pulse_list.append(gpa, pulse);
    }

    std.debug.assert(pulse_list.items.len > 0);

    var current_pulse: usize = 0;

    while (current_pulse < pulse_list.items.len) : (current_pulse += 1) {
        const pulse = pulse_list.items[current_pulse];
        if (pulse.type_ == .High) {
            count.high_pulses += 1;
        } else {
            count.low_pulses += 1;
        }

        const dest = pulse.destination;

        switch (dest.module_type) {
            .FlipFlop => {
                if (pulse.type_ == .Low) {
                    const state: State = if (dest.state == .On) .Off else .On;
                    const pulse_type: PulseType = if (state == .On) .High else .Low;

                    for (dest.outputs.items) |out| {
                        const new_pulse = Pulse {
                            .origin = dest,
                            .destination = out,
                            .type_ = pulse_type,
                        };
                        try pulse_list.append(gpa, new_pulse);
                    }

                    dest.state = state;
                }
            },
            .Conjunction => {
                var all_high = true;

                for (dest.inputs.items) |*inp| {
                    if (std.mem.eql(u8, inp[0].name, pulse.origin.name)) {
                        inp[1] = pulse.type_;
                    }

                    all_high = all_high and inp[1] == .High;
                }

                const pulse_type: PulseType = if (all_high) .Low else .High;

                for (dest.outputs.items) |out| {
                    const new_pulse = Pulse {
                        .origin = dest,
                        .destination = out,
                        .type_ = pulse_type,
                    };
                    try pulse_list.append(gpa, new_pulse);
                }
            },
            .DeadEnd => {},
            .Broadcaster => unreachable(),
        }
    }

    return count;
}

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    const arena_allocator = arena.allocator();
    defer arena.deinit();

    var modules: std.StringHashMap(*Node) = .init(gpa);
    defer modules.deinit();

    try read_nodes(arena_allocator, &modules, content);

    var total_count: Count = .{ .high_pulses = 0, .low_pulses = 0 };

    const NUM_BUTTON_PRESSES: usize = 1000;

    for (0..NUM_BUTTON_PRESSES) |_| {
        const count = try push_button(gpa, &modules);

        total_count = total_count.add(count);
    }

    const result = total_count.low_pulses * total_count.high_pulses;

    std.debug.print("low pulse count  = {}\n", .{total_count.low_pulses});
    std.debug.print("high pulse count = {}\n", .{total_count.high_pulses});
    std.debug.print("result = {}\n", .{result});
}


const Marker = struct {
    button_push: usize,
    pulse_count: usize,
    total_pulse_count: usize,
};

fn send_pulse_to_node(
    gpa: Allocator,
    broadcaster: *Node,
    node: *Node,
    end_node: *Node,
    button_push_count: usize,
    total_pulse_count: usize,
    high_pulse_marker: *std.ArrayList(Marker)
) !usize {
    var pulse_list: std.ArrayList(Pulse) = .empty;
    defer pulse_list.deinit(gpa);

    {
        const pulse: Pulse = .{ .origin = broadcaster, .destination = node, .type_ = .Low };
        try pulse_list.append(gpa, pulse);
    }

    std.debug.assert(pulse_list.items.len > 0);

    // std.debug.print("\n", .{});

    var current_pulse: usize = 0;

    while (current_pulse < pulse_list.items.len) : (current_pulse += 1) {
        const pulse = pulse_list.items[current_pulse];

        const dest = pulse.destination;

        switch (dest.module_type) {
            .FlipFlop => {
                // std.debug.print("{}, {}\n", .{ff.*, pulse.type_});
                if (pulse.type_ == .Low) {
                    const state: State = if (dest.state == .On) .Off else .On;
                    const pulse_type: PulseType = if (state == .On) .High else .Low;

                    for (dest.outputs.items) |out| {
                        const new_pulse = Pulse {
                            .origin = dest,
                            .destination = out,
                            .type_ = pulse_type,
                        };
                        try pulse_list.append(gpa, new_pulse);
                    }

                    dest.state = state;
                }
            },
            .Conjunction => {
                var all_high = true;

                for (dest.inputs.items) |*inp| {
                    if (std.mem.eql(u8, inp[0].name, pulse.origin.name)) {
                        inp[1] = pulse.type_;
                    }

                    all_high = all_high and inp[1] == .High;
                }

                const pulse_type: PulseType = if (all_high) .Low else .High;

                for (dest.outputs.items) |out| {
                    const new_pulse = Pulse {
                        .origin = dest,
                        .destination = out,
                        .type_ = pulse_type,
                    };
                    try pulse_list.append(gpa, new_pulse);
                }
            },
            .DeadEnd => {},
            .Broadcaster => unreachable(),
        }

        if (pulse.destination == end_node and pulse.type_ == .High) {
            try high_pulse_marker.append(
                gpa,
                .{
                    .button_push = button_push_count,
                    .pulse_count = current_pulse + 1,
                    .total_pulse_count = total_pulse_count + current_pulse + 1,
                }
            );
        }
    }

    // {
    //     for (pulse_list.items) |p| {
    //         std.debug.print("{s}-{c}->{s}, ", .{p.origin.name, @intFromEnum(p.type_), p.destination.name});
    //     }
    //     std.debug.print("\n", .{});
    // }
    return current_pulse;
}

pub fn part2(gpa: Allocator, content: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    const arena_allocator = arena.allocator();
    defer arena.deinit();

    var modules: std.StringHashMap(*Node) = .init(gpa);
    defer modules.deinit();

    try read_nodes(arena_allocator, &modules, content);

    var mod_iter = modules.valueIterator();

    while (mod_iter.next()) |n0| {
        const n = n0.*;
        std.debug.print("{s} :: {} :: {any}\n", .{n.name, n.module_type, n.state});

        std.debug.print("  inputs: ", .{});
        for (n.inputs.items) |inp| {
            std.debug.print("{s}, ", .{inp[0].name});
        }
        std.debug.print("\n", .{});

        std.debug.print("  outputs: ", .{});
        for (n.outputs.items) |o| {
            std.debug.print("{s}, ", .{o.name});
        }
        std.debug.print("\n", .{});
    }

    const rx = modules.get("rx").?;
    const ql, const _t = rx.inputs.items[0];
    _ = _t;

    const brc = modules.get("broadcaster").?;
    var high_pulse_marker: std.ArrayList(Marker) = .empty;
    var result: usize = 1;

    for (brc.outputs.items) |out| {
        var button_push_count: usize = 0;
        var total_pulse_count: usize = 0;

        while (button_push_count < 10000) {
            button_push_count += 1;

            total_pulse_count += try send_pulse_to_node(
                gpa,
                brc,
                out,
                ql,
                button_push_count,
                total_pulse_count,
                &high_pulse_marker
            );
        }


        std.debug.print("{any}\n", .{high_pulse_marker.items});

        const m = high_pulse_marker.items[0];

        result = std.math.lcm(result, m.button_push);
        high_pulse_marker.clearRetainingCapacity();
    }

    std.debug.print("total = {}\n", .{result});
}
