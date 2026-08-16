const std = @import("std");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

inline fn xor(a: bool, b: bool) bool {
    return (a and !b) or (!a and b);
}

const VarName = enum(usize) {
    a = 0,
    m = 1,
    s = 2,
    x = 3,

    fn index(vn: VarName) usize {
        return @intFromEnum(vn);
    }

    fn from_u8(c: u8) VarName {
        return switch (c) {
            'a' => .a,
            'm' => .m,
            's' => .s,
            'x' => .x,
            else => unreachable(),
        };
    }

    fn to_u8(self: VarName) u8 {
        return switch (self) {
            .a => 'a',
            .m => 'm',
            .s => 's',
            .x => 'x',
        };
    }
};

const Operator = enum(u8) {
    LessThan = '<',
    GreaterThan = '>',
};

const EndState = enum(u8) {
    Accepted = 'A',
    Rejected = 'R',
};

const Then = union(enum) {
    goto_workflow: []const u8,
    end_state: EndState,
};

const Comparison = struct {
    variable: VarName,
    operator: Operator,
    value: usize,
    then: Then,

    fn eval(self: Comparison, value: usize) bool {
        return switch (self.operator) {
            .LessThan => value < self.value,
            .GreaterThan => value > self.value,
        };
    }

    fn print(self: Comparison) void {
        std.debug.print("{} {} {}\n", .{self.variable, self.operator, self.value});
        return switch (self.then) {
            .goto_workflow => |gt| {
                std.debug.print("  -> {s}\n", .{gt});
            },
            .end_state => |es| {
                std.debug.print("  -> {}\n", .{es});
            },
        };
    }
};

const Rule = union(enum) {
    comparison: Comparison,
    goto_workflow: []const u8,
    end_state: EndState,

    fn from_then(then: Then) Rule {
        return switch (then) {
            .goto_workflow => |gt| .{ .goto_workflow = gt },
            .end_state => |es| .{ .end_state = es },
        };
    }

    fn print(self: Rule) void {
        return switch (self) {
            .comparison => |c| c.print(),
            .goto_workflow => |gt| {
                std.debug.print("{s}\n", .{gt});
            },
            .end_state => |es| {
                std.debug.print("{}\n", .{es});
            },
        };
    }
};

const Workflows = std.StringHashMap([]Rule);

pub fn part1(gpa: Allocator, content: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    var arena_allocator = arena.allocator();
    defer arena.deinit();

    var workflows: Workflows = .init(gpa);
    defer workflows.deinit();

    var ratings: std.ArrayList([4]usize) = .empty;
    defer ratings.deinit(gpa);

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) break;

        const marker_idx = std.mem.indexOfScalar(u8, line, '{').?;

        const workflow_name = line[0..marker_idx];
        const workflow_rules = std.mem.trim(u8, line[marker_idx..], "{}");

        var iter2 = std.mem.splitSequence(u8, workflow_rules, ",");

        var rule_buffer: [10]Rule = undefined;
        var rule_count: usize = 0;

        while (iter2.next()) |rule_str| {
            if (rule_str.len == 0) continue;

            var rule: Rule = undefined;

            if (rule_str[0] == 'A' or rule_str[0] == 'R') { 
                rule = .{ .end_state = @enumFromInt(rule_str[0]) };
            } else if (rule_str[1] == '>' or rule_str[1] == '<') {
                const var_name = rule_str[0];
                const operator: Operator = @enumFromInt(rule_str[1]);

                const collon_idx = std.mem.indexOfScalar(u8, rule_str, ':').?;
                const value =
                    try std.fmt.parseInt(usize, rule_str[2..collon_idx], 10);

                const rule_str_then = rule_str[collon_idx + 1..];
                const rule_then: Then =
                    if (rule_str_then[0] == 'R' or rule_str_then[0] == 'A')
                        .{ .end_state = @enumFromInt(rule_str_then[0]) }
                    else
                        .{ .goto_workflow = rule_str_then }
                    ;

                rule = .{
                    .comparison = .{
                        .variable = VarName.from_u8(var_name),
                        .operator = operator,
                        .value = value,
                        .then = rule_then,
                    },
                };
            } else {
                rule = .{ .goto_workflow = rule_str };
            }

            rule_buffer[rule_count] = rule;
            rule_count += 1;

        }

        const rules2 = try arena_allocator.dupe(Rule, rule_buffer[0..rule_count]);
        try workflows.put(workflow_name, rules2);

        for (0..rule_count) |i| {
            // switch (rule_buffer[i]) {
            //     .comparison => 
            // }
            std.debug.print("{any}\n", .{rule_buffer[i]});
        }
        std.debug.print("------\n", .{});
    }

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        const ratings_str = std.mem.trim(u8, line, "{}");
        var iter2 = std.mem.splitSequence(u8, ratings_str, ",");

        var rating: []usize = try arena_allocator.alloc(usize, 4);
        for (0..rating.len) |i| {
            rating[i] = 0;
        }

        while (iter2.next()) |rating_str| {
            const var_name = VarName.from_u8(rating_str[0]);
            assert(rating_str[1] == '=');

            const value = try std.fmt.parseInt(usize, rating_str[2..], 10);
            
            rating[var_name.index()] = value;
        }

        try ratings.append(gpa, rating[0..4].*);
    }

    var total: usize = 0;

    for (ratings.items) |rating| {
        var rules = workflows.get("in").?;
        var rule_idx: usize = 0;
        var rule = rules[rule_idx];
        var finished = false;

        while (!finished) {
            rule.print();
            switch (rule) {
                .comparison => |cmp| {
                    const value = rating[cmp.variable.index()];
                    if (cmp.eval(value)) {
                        // rule = cmp.then;
                        rule = Rule.from_then(cmp.then);
                    } else {
                        rule_idx += 1;
                        rule = rules[rule_idx];
                    }
                },
                .goto_workflow => |gtw| {
                    rules = workflows.get(gtw).?;
                    rule_idx = 0;
                    rule = rules[rule_idx];
                },
                .end_state => |es| {
                    if (es == .Accepted) {
                        for (rating) |r| {
                            total += r;
                        }
                    }

                    finished = true;
                },
            }
        }
        std.debug.print("############# \n", .{});
    }

    std.debug.print("total = {}\n", .{total});
}

const GraphItemIndex = struct {
    value: usize,
    negated: bool,

    fn make(value: usize, neg: bool) GraphItemIndex {
        return .{ .value = value, .negated = neg };
    }
};

const GraphItem = union(enum) {
    node: struct {
        workflow: []const u8,
        rule: *Rule,
        lhs_idx: ?GraphItemIndex,
        rhs_idx: ?GraphItemIndex,
        removed: bool,
    },
    leaf: EndState,

    fn has_workflow_eql(self: GraphItem, wf: []const u8) bool {
        return switch (self) {
            .leaf => false,
            .node => |n| std.mem.eql(u8, n.workflow, wf),
        };
    }
};

fn dump(items: std.ArrayList(GraphItem), filename: []const u8) !void {
    const file = try std.fs.cwd().createFile(
        filename,
        .{ .read = true, .truncate = true },
    );
    defer file.close();

    _ = try file.write(
    \\digraph day19 {
    \\fontname="Helvetica,Arial,sans-serif"
    \\node [fontname="Helvetica,Arial,sans-serif"]
    \\edge [fontname="Helvetica,Arial,sans-serif"]
    \\
    );
    
    var buffer: [1024]u8 = undefined;

    for (items.items, 0..) |item, i| {
        switch (item) {
            .node => |node| {
                if (node.removed) continue;

                var v = try std.fmt.bufPrint(buffer[0..], "n{} [label=\"{s}|", .{i, node.workflow});
                _ = try file.write(v);

                switch (node.rule.*) {
                    .comparison => |c| {
                        const op: u8 = @intFromEnum(c.operator);
                        v = try std.fmt.bufPrint(buffer[0..], "{c}{c}{}\"];\n", .{
                            c.variable.to_u8(),
                            op,
                            c.value,
                        });
                    },
                    .goto_workflow => |gt| {
                        v = try std.fmt.bufPrint(buffer[0..], "{s}\"];\n", .{gt});
                    },
                    .end_state => |es| {
                        const c: u8 = @intFromEnum(es);
                        v = try std.fmt.bufPrint(buffer[0..], "{c}\"];\n", .{c});
                    },
                }
                _ = try file.write(v);
            },
            .leaf => |l| {
                const c: u8 = @intFromEnum(l);
                const v = try std.fmt.bufPrint(buffer[0..], "n{} [label=\"({c})\"]\n", .{i, c});
                _ = try file.write(v);
            }
        }
    }

    for (items.items, 0..) |item, i| {
        switch (item) {
            .node => |node| {
                if (node.removed) continue;

                if (node.lhs_idx) |idx| {
                    if (idx.negated) {
                        const v = try std.fmt.bufPrint(buffer[0..], "n{} -> n{} [arrowhead=\"onormal\"];\n", .{i, idx.value});
                        _ = try file.write(v);
                    } else {
                        const v = try std.fmt.bufPrint(buffer[0..], "n{} -> n{};\n", .{i, idx.value});
                        _ = try file.write(v);
                    }
                }
                if (node.rhs_idx) |idx| {
                    if (idx.negated) {
                        const v = try std.fmt.bufPrint(buffer[0..], "n{} -> n{} [arrowhead=\"onormal\"];\n", .{i, idx.value});
                        _ = try file.write(v);
                    } else {
                        const v = try std.fmt.bufPrint(buffer[0..], "n{} -> n{};\n", .{i, idx.value});
                        _ = try file.write(v);
                    }
                }
            },
            .leaf => {}
        }
    }

    _ = try file.write("}");
}

const Range = struct {
    start: usize,
    end: usize,

    fn eql(self: Range, other: Range) bool {
        return self.start == other.start and self.end == other.end;
    }

    fn split(self: *Range, v: usize) ?Range {
        if (v <= self.start or self.end <= v) return null;

        const other = Range { .start = v + 1, .end = self.end };
        self.end = v;

        return other;
    }
};

pub fn part2(gpa: Allocator, content: []const u8) !void {
    var arena: std.heap.ArenaAllocator = .init(gpa);
    var arena_allocator = arena.allocator();
    defer arena.deinit();

    var workflows: Workflows = .init(gpa);
    defer workflows.deinit();

    var items: std.ArrayList(GraphItem) = .empty;
    defer items.deinit(gpa);

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) break;

        const marker_idx = std.mem.indexOfScalar(u8, line, '{').?;

        const workflow_name = line[0..marker_idx];
        const workflow_rules = std.mem.trim(u8, line[marker_idx..], "{}");

        var iter2 = std.mem.splitSequence(u8, workflow_rules, ",");

        var rule_buffer: [10]Rule = undefined;
        var rule_count: usize = 0;

        while (iter2.next()) |rule_str| {
            if (rule_str.len == 0) continue;

            var rule: Rule = undefined;

            if (rule_str[0] == 'A' or rule_str[0] == 'R') { 
                rule = .{ .end_state = @enumFromInt(rule_str[0]) };
            } else if (rule_str[1] == '>' or rule_str[1] == '<') {
                const var_name = rule_str[0];
                const operator: Operator = @enumFromInt(rule_str[1]);

                const collon_idx = std.mem.indexOfScalar(u8, rule_str, ':').?;
                const value =
                    try std.fmt.parseInt(usize, rule_str[2..collon_idx], 10);

                const rule_str_then = rule_str[collon_idx + 1..];
                const rule_then: Then =
                    if (rule_str_then[0] == 'R' or rule_str_then[0] == 'A')
                        .{ .end_state = @enumFromInt(rule_str_then[0]) }
                    else
                        .{ .goto_workflow = rule_str_then }
                    ;

                rule = .{
                    .comparison = .{
                        .variable = VarName.from_u8(var_name),
                        .operator = operator,
                        .value = value,
                        .then = rule_then,
                    },
                };
            } else {
                rule = .{ .goto_workflow = rule_str };
            }

            rule_buffer[rule_count] = rule;
            rule_count += 1;

        }

        const rules2 = try arena_allocator.dupe(Rule, rule_buffer[0..rule_count]);
        try workflows.put(workflow_name, rules2);

        for (0..rule_count) |i| {
            // switch (rule_buffer[i]) {
            //     .comparison => 
            // }
            std.debug.print("{any}\n", .{rule_buffer[i]});
        }
        std.debug.print("------\n", .{});
    }

    {
        const leaf_accepted = GraphItem { .leaf = .Accepted };
        const leaf_rejected = GraphItem { .leaf = .Rejected };

        try items.append(gpa, leaf_accepted);
        try items.append(gpa, leaf_rejected);
    }

    var ws_iter = workflows.iterator();
    var k: usize = items.items.len;

    while (ws_iter.next()) |entry| {
        for (entry.value_ptr.*) |*rule| {
            const item = GraphItem {
                .node = .{
                    .workflow = entry.key_ptr.*,
                    .rule = rule,
                    .lhs_idx = null,
                    .rhs_idx = .make(k + 1, true),
                    .removed = false,
                },
            };

            try items.append(gpa, item);

            k += 1;
        }
    }

    for (items.items) |*item| {
        switch (item.*) {
            .leaf => {
                continue;
            },
            else => {},
        }

        var node = &item.node;
        switch (node.rule.*) {
            .comparison => |c| {
                switch (c.then) {
                    .goto_workflow => |gtw| {
                        for (items.items, 0..) |item2, i| {
                            if (item2.has_workflow_eql(gtw)) {
                                node.lhs_idx = .make(i, false);
                                break;
                            }
                        }
                    },
                    .end_state => |es| {
                        switch (es) {
                            .Accepted => {
                                node.lhs_idx = .make(0, false);
                            },
                            .Rejected => {
                                node.lhs_idx = .make(1, false);
                            }
                        }
                    },
                }
            },
            .goto_workflow => |gtw| {
                for (items.items, 0..) |item2, i| {
                    if (item2.has_workflow_eql(gtw)) {
                        node.lhs_idx = null;
                        node.rhs_idx = .make(i, true);
                        break;
                    }
                }
            },
            .end_state => |es| {
                switch (es) {
                    .Accepted => {
                        node.lhs_idx = .make(0, false);
                        node.rhs_idx = null;
                    },
                    .Rejected => {
                        node.lhs_idx = .make(1, false);
                        node.rhs_idx = null;
                    }
                }
            },
        }
    }

    var changed = true;
    while (changed) {
        changed = false;
        for (items.items) |*item| {
            switch (item.*) {
                .leaf => {
                    continue;
                },
                else => {},
            }

            var node = &item.node;
            if (node.lhs_idx) |lhs_idx| {
                const next = items.items[lhs_idx.value];
                if (next == .node) {
                    switch (next.node.rule.*) {
                        .comparison => {},
                        .goto_workflow => {
                            node.lhs_idx = next.node.rhs_idx;
                            changed = true;
                        },
                        .end_state => |es| {
                            changed = true;
                            switch (es) {
                                .Accepted => {
                                    node.lhs_idx = .make(0, lhs_idx.negated);
                                    // node.rhs_idx = null;
                                },
                                .Rejected => {
                                    node.lhs_idx = .make(1, lhs_idx.negated);
                                    // node.rhs_idx = null;
                                }
                            }
                        },
                    }
                }
            }

            if (node.rhs_idx) |rhs_idx| {
                const next = items.items[rhs_idx.value];
                if (next == .node) {
                    switch (next.node.rule.*) {
                        .comparison => {},
                        .goto_workflow => {
                            node.rhs_idx = next.node.rhs_idx;
                            changed = true;
                        },
                        .end_state => |es| {
                            changed = true;
                            switch (es) {
                                .Accepted => {
                                    node.rhs_idx = .make(0, rhs_idx.negated);
                                },
                                .Rejected => {
                                    node.rhs_idx = .make(1, rhs_idx.negated);
                                }
                            }
                        },
                    }
                }
            }
        }
    }

    k = 0;
    while (k < items.items.len) {
        if (items.items[k] == .node) {
            if (items.items[k].node.rule.* != .comparison) {
                items.items[k].node.removed = true;
            }
        }

        k += 1;
    }

    // graphviz build: dot -Tpng test.dot > test.png
    // try dump(items, "test.dot");

    var start_idx: usize = 0;

    for (items.items, 0..) |item, i| {
        if (item.has_workflow_eql("in")) {
            start_idx = i;
            break;
        }
    }

    const ranges: [4]Range = [1]Range{ Range{ .start = 1, .end = 4000 }} ** 4;
    var range_groups: std.ArrayList([4]Range) = .empty;
    defer range_groups.deinit(gpa);

    dfs(gpa, start_idx, ranges, &range_groups, items.items);

    // for (range_groups.items) |r| {
    //     std.debug.print("{any}\n", .{r});
    // }

    // std.debug.print("@@@@@@@@@@@@@@@@@@@\n", .{});

    k = 0;
    while (k < range_groups.items.len) {
        var increment = true;
        for (range_groups.items[k]) |r| {
            if (r.start > r.end) {
                _ = range_groups.swapRemove(k);
                increment = false;
                break;
            }
        }

        if (increment) {
            k += 1;
        }
    }

    // for (range_groups.items) |r| {
    //     std.debug.print("{any}\n", .{r});
    // }

    var total: usize = 0;
    for (range_groups.items) |g| {
        var v: usize = 1;
        for (g) |r| {
            v *= r.end - r.start + 1;
        }
        total += v;
    }

    std.debug.print("total = {}\n", .{total});
}

fn dfs(gpa: Allocator, start_idx: usize, ranges: [4]Range, found: *std.ArrayList([4]Range), items: []GraphItem) void {
    const item = items[start_idx];
    switch (item) {
        .leaf => |es| {
            switch (es) {
                .Accepted => {
                    found.append(gpa, ranges) catch unreachable();
                },
                .Rejected => {}
            }
        },
        .node => |node| {
            if (node.rule.* == .comparison) {
                const comparison = node.rule.comparison;

                if (node.lhs_idx) |idx| {
                    const r = update_range_for_comparison(
                        ranges[comparison.variable.index()],
                        comparison,
                        idx.negated
                    );

                    var other = ranges;
                    other[comparison.variable.index()] = r;

                    dfs(gpa, idx.value, other, found, items);
                }
                if (node.rhs_idx) |idx| {
                    const r = update_range_for_comparison(
                        ranges[comparison.variable.index()],
                        comparison,
                        idx.negated
                    );

                    var other = ranges;
                    other[comparison.variable.index()] = r;

                    dfs(gpa, idx.value, other, found, items);
                }
            }
        }
    }
}

fn update_range_for_comparison(range: Range, comparison: Comparison, negated: bool) Range {
    var r = range;

    if (!negated) {
        if (comparison.operator == .LessThan) {
            if (r.end > comparison.value - 1) {
                r.end = comparison.value - 1;
            }
        } else {
            if (r.start < comparison.value + 1) {
                r.start = comparison.value + 1;
            }
        }
    } else {
        if (comparison.operator == .LessThan) {
            if (r.start < comparison.value) {
                r.start = comparison.value;
            }
        } else {
            if (r.end > comparison.value) {
                r.end = comparison.value;
            }
        }
    }

    return r;
}
