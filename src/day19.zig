const std = @import("std");

const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

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
