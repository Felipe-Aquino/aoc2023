const std = @import("std");

const Allocator = std.mem.Allocator;

const PulseType = enum(u8) {
    High = 'H',
    Low = 'L',
};

const Pulse = struct {
    origin: []const u8,
    destination: []const u8,
    type_: PulseType,
};

const State = enum(u8) {
    On = '1',
    Off = '0',
};

const Input = struct {
    name: []const u8,
    pulse_type: PulseType,
    high_received: usize,
    low_received: usize,

    fn make(name: []const u8) Input {
        return .{
            .name = name,
            .pulse_type = .Low,
            .high_received = 0,
            .low_received = 0,
        };
    }
};

const FlipFlopModule = struct {
    state: State,
    outputs: []const []const u8,
    last_pulse_type: PulseType,
};

const ConjunctionModule = struct {
    inputs: []Input,
    outputs: []const []const u8,
    last_pulse_type: PulseType,

    fn update_input(self: *ConjunctionModule, name: []const u8, pt: PulseType) void {
        for (self.inputs) |*inp| {
            if (std.mem.eql(u8, inp.name, name)) {
                inp.pulse_type = pt;
                if (pt == .High) {
                    inp.high_received += 1;
                } else {
                    inp.low_received += 1;
                }
                break;
            }
        }
    }
};

const BroadcasterModule = struct {
    outputs: []const []const u8,
};

const DeadEndModule = struct {
    last_pulse_type: PulseType,
};

const Module = union(enum) {
    flip_flop: FlipFlopModule,
    conjunction: ConjunctionModule,
    broadcaster: BroadcasterModule,
    dead_end: DeadEndModule,

    fn make_flip_flop(outputs: []const []const u8) Module {
        const ff = FlipFlopModule {
            .state = .Off,
            .outputs = outputs,
            .last_pulse_type = .Low,
        };

        return .{ .flip_flop = ff };
    }

    fn make_conjunction(outputs: []const []const u8) Module {
        const cm = ConjunctionModule {
            .inputs = &.{},
            .outputs = outputs,
            .last_pulse_type = .Low,
        };

        return .{ .conjunction = cm };
    }

    fn make_broadcaster(outputs: []const []const u8) Module {
        const bm = BroadcasterModule {
            .outputs = outputs,
        };

        return .{ .broadcaster = bm };
    }

    fn make_dead_end() Module {
        const de = DeadEndModule {
            .last_pulse_type = .Low,
        };

        return .{ .dead_end = de };
    }

    fn get_outputs(self: Module) []const []const u8 {
        return switch (self) {
            .flip_flop => |ff| ff.outputs,
            .conjunction => |c| c.outputs,
            .broadcaster => |b| b.outputs,
            .dead_end => &.{},
        };
    }

    fn is_last_pulse_high(self: Module) bool {
        return switch (self) {
            .flip_flop => |ff| ff.last_pulse_type == .High,
            .conjunction => |c| c.last_pulse_type == .High,
            .dead_end => |de| de.last_pulse_type == .High,
            else => unreachable(),
        };
    }

    fn last_pulse(self: Module) PulseType {
        return switch (self) {
            .flip_flop => |ff| ff.last_pulse_type,
            .conjunction => |c| c.last_pulse_type,
            .dead_end => |de| de.last_pulse_type,
            else => unreachable(),
        };
    }
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

fn read_module_outputs(arena: Allocator, names: []const u8) ![][]const u8 {
    var result: std.ArrayList([]const u8) = .empty;

    var iter = std.mem.splitSequence(u8, names, ", ");
    while (iter.next()) |name| {
        try result.append(arena, name);
    }

    return result.toOwnedSlice(arena);
}

fn push_button(gpa: Allocator, modules: *std.StringHashMap(Module)) !Count {
    var count = Count { .high_pulses = 0, .low_pulses = 1 };

    var pulse_list: std.ArrayList(Pulse) = .empty;
    defer pulse_list.deinit(gpa);

    const broadcaster_outputs = modules.get("broadcaster").?.get_outputs();

    for (broadcaster_outputs) |name| {
        const pulse: Pulse = .{ .origin = "brc", .destination = name, .type_ = .Low };
        try pulse_list.append(gpa, pulse);
    }

    std.debug.assert(pulse_list.items.len > 0);

    // std.debug.print("\n", .{});

    var current_pulse: usize = 0;

    while (current_pulse < pulse_list.items.len) : (current_pulse += 1) {
        const pulse = pulse_list.items[current_pulse];
        if (pulse.type_ == .High) {
            count.high_pulses += 1;
        } else {
            count.low_pulses += 1;
        }

        // {
        //     for (pulse_list.items, 0..) |p, i| {
        //         if (i != current_pulse) {
        //             std.debug.print("{s}-{c}->{s}, ", .{p.origin, @intFromEnum(p.type_), p.destination});
        //         } else {
        //             std.debug.print("\x1B[31m{s}-{c}->{s}\x1B[0m, ", .{p.origin, @intFromEnum(p.type_), p.destination});
        //         }
        //     }
        //     std.debug.print("\n", .{});
        // }

        const module = modules.getPtr(pulse.destination);

        switch (module.?.*) {
            .flip_flop => |*ff| {
                ff.last_pulse_type = pulse.type_;

                // std.debug.print("{}, {}\n", .{ff.*, pulse.type_});
                if (pulse.type_ == .Low) {
                    const state: State = if (ff.state == .On) .Off else .On;
                    const pulse_type: PulseType = if (state == .On) .High else .Low;

                    for (ff.outputs) |name| {
                        const new_pulse = Pulse {
                            .origin = pulse.destination,
                            .destination = name,
                            .type_ = pulse_type,
                        };
                        try pulse_list.append(gpa, new_pulse);
                    }

                    ff.state = state;
                    try modules.put(pulse.destination, .{ .flip_flop = ff.* });
                }
            },
            .conjunction => |*conj| {
                var all_high = true;

                conj.update_input(pulse.origin, pulse.type_);
                for (conj.inputs) |*inp| {
                    all_high = all_high and inp.pulse_type == .High;
                }

                const pulse_type: PulseType = if (all_high) .Low else .High;

                for (conj.outputs) |name| {
                    const new_pulse = Pulse {
                        .origin = pulse.destination,
                        .destination = name,
                        .type_ = pulse_type,
                    };
                    try pulse_list.append(gpa, new_pulse);
                }

                conj.last_pulse_type = pulse.type_;
                try modules.put(pulse.destination, .{ .conjunction = conj.* });
            },
            .dead_end => |*de| {
                de.last_pulse_type = pulse.type_;
                try modules.put(pulse.destination, .{ .dead_end = de.* });
            },
            .broadcaster => unreachable(),
        }
    }

    return count;
}

pub fn detect_cycle_and_count(gpa: Allocator, modules: *std.StringHashMap(Module), num_button_presses: usize) !void {
    var cycle_total_count: Count = .{ .high_pulses = 0, .low_pulses = 0 };

    var n: usize = 0;

    while (n < num_button_presses) {
        const count = try push_button(gpa, modules);

        cycle_total_count = cycle_total_count.add(count);

        var module_iter = modules.iterator();
        var reached_default_state = true;

        inner: while (module_iter.next()) |entry| {
            switch (entry.value_ptr.*) {
                .flip_flop => |ff| {
                    if (ff.state == .On) {
                        reached_default_state = false;
                        break :inner;
                    }
                },
                .conjunction => |conj| {
                    for (conj.inputs) |inp| {
                        if (inp.pulse_type == .High) {
                            reached_default_state = false;
                            break :inner;
                        }
                    }
                },
                else => {}
            }
        }

        n += 1;

        if (reached_default_state) {
            break;
        }
    }

    std.debug.print("cycle size = {}\n", .{n});

    if (n < num_button_presses) {
        const num_cycles = num_button_presses / n;
        const presses_remaining = @rem(num_button_presses, n);

        cycle_total_count = .{
            .high_pulses = num_cycles * cycle_total_count.high_pulses,
            .low_pulses  = num_cycles * cycle_total_count.low_pulses,
        };
        while (n < presses_remaining) {
            const count = try push_button(gpa, modules);

            cycle_total_count = cycle_total_count.add(count);

            n += 1;
        }
    }

    const result = cycle_total_count.low_pulses * cycle_total_count.high_pulses;

    std.debug.print("low pulse count  = {}\n", .{cycle_total_count.low_pulses});
    std.debug.print("high pulse count = {}\n", .{cycle_total_count.high_pulses});
    std.debug.print("result = {}\n", .{result});
}

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    const arena_allocator = arena.allocator();
    defer arena.deinit();

    var modules: std.StringHashMap(Module) = .init(gpa);
    defer modules.deinit();

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        var iter2 = std.mem.splitSequence(u8, line, " -> ");

        const name = iter2.next().?;
        const module_names = iter2.next().?;

        const outputs = try read_module_outputs(arena_allocator, module_names);

        const module: Module = 
            switch (name[0]) {
                '%' => Module.make_flip_flop(outputs),
                '&' => Module.make_conjunction(outputs),
                else => Module.make_broadcaster(outputs),
            };

        const module_name = 
            if (name[0] == '&' or name[0] == '%')
                name[1..]
            else
                name;

        try modules.put(module_name, module);
    }

    var module_iter = modules.iterator();

    while (module_iter.next()) |entry| {
        std.debug.print("{s} -> ", .{ entry.key_ptr.* });

        for (entry.value_ptr.*.get_outputs()) |name| {
            std.debug.print("{s}, ", .{name});

            if (modules.get(name) == null) {
                try modules.put(name, Module.make_dead_end());
            }
        }

        if (entry.value_ptr.* == .conjunction) {
            const name = entry.key_ptr.*;
            var conj = &entry.value_ptr.*.conjunction;

            var inputs: std.ArrayList(Input) = .empty;
            var iter2 = modules.iterator();

            while (iter2.next()) |entry2| {
                for (entry2.value_ptr.get_outputs()) |out_name| {
                    if (std.mem.eql(u8, name, out_name)) {
                        const input= Input.make(entry2.key_ptr.*);
                        try inputs.append(arena_allocator, input);
                    }
                }
            }

            conj.inputs = try inputs.toOwnedSlice(arena_allocator);

            std.debug.print("$$ ", .{});
            for (conj.inputs) |inp| {
                std.debug.print("{s}, ", .{inp.name});
            }
        }

        std.debug.print("\n", .{});
    }

    try detect_cycle_and_count(gpa, &modules, 1000);
}

const NodeType = enum {
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
    module: NodeType,

    fn init(self: *Node, allocator: Allocator, name: []const u8, mod: NodeType) !void {
        self.name = name;
        self.inputs = try .initCapacity(allocator, 16);
        self.outputs = try .initCapacity(allocator, 16);
        self.state = if (mod == .FlipFlop) .Off else null;
        self.module = mod;
    }
};

const Pulse2 = struct {
    origin: *Node,
    destination: *Node,
    type_: PulseType,
};

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
    var pulse_list: std.ArrayList(Pulse2) = .empty;
    defer pulse_list.deinit(gpa);

    {
        const pulse: Pulse2 = .{ .origin = broadcaster, .destination = node, .type_ = .Low };
        try pulse_list.append(gpa, pulse);
    }

    std.debug.assert(pulse_list.items.len > 0);

    // std.debug.print("\n", .{});

    var current_pulse: usize = 0;

    while (current_pulse < pulse_list.items.len) : (current_pulse += 1) {
        const pulse = pulse_list.items[current_pulse];

        const dest = pulse.destination;

        switch (dest.module) {
            .FlipFlop => {
                // std.debug.print("{}, {}\n", .{ff.*, pulse.type_});
                if (pulse.type_ == .Low) {
                    const state: State = if (dest.state == .On) .Off else .On;
                    const pulse_type: PulseType = if (state == .On) .High else .Low;

                    for (dest.outputs.items) |out| {
                        const new_pulse = Pulse2 {
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
                    const new_pulse = Pulse2 {
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

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        var iter2 = std.mem.splitSequence(u8, line, " -> ");

        const name = iter2.next().?;
        const module_names = iter2.next().?;

        const module: NodeType = 
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
            node.module = module;
            node.state = if (module == .FlipFlop) .Off else null;
        } else {
            node = try arena_allocator.create(Node);
            try node.init(arena_allocator, name, module);

            try modules.put(module_name, node);
        }

        {
            var out_iter = std.mem.splitSequence(u8, module_names, ", ");
            while (out_iter.next()) |out_name| {
                std.debug.print("{s} - on: {s}\n", .{node.name, out_name});

                if (out_name.len == 0) continue;
                if (modules.get(out_name)) |out| {
                    try node.outputs.append(arena_allocator, out);

                    try out.inputs.append(arena_allocator, .{ node, .Low });
                } else {
                    var out = try arena_allocator.create(Node);
                    try out.init(arena_allocator, out_name, .DeadEnd);

                    try node.outputs.append(arena_allocator, out);
                    try out.inputs.append(arena_allocator, .{ node, .Low });

                    try modules.put(out_name, out);
                }
            }
        }
    }

    var mod_iter = modules.valueIterator();

    while (mod_iter.next()) |n0| {
        const n = n0.*;
        std.debug.print("{s} :: {} :: {any}\n", .{n.name, n.module, n.state});

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

    const ql = modules.get("ql").?;
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
