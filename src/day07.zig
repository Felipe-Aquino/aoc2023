const std = @import("std");
const utils = @import("utils.zig");

const Allocator = std.mem.Allocator;

const HandKind = enum(i8) {
    FiveOfAKind = 0,
    FourOfAKind = 1,
    FullHouse = 2,
    ThreeOfAKind = 3,
    TwoPair = 4,
    OnePair = 5,
    HighCard = 6,

    fn cmp(self: HandKind, other: HandKind) i8 {
        return @intFromEnum(other) - @intFromEnum(self);
    }
};

fn card_value(c: u8, j_is_wild: bool) i8 {
    return switch (c) {
        '2'...'9' => @as(i8, @intCast(c - '0')),
        'T' => 10,
        'J' => if (j_is_wild) 0 else 11,
        'Q' => 12,
        'K' => 13,
        'A' => 14,
        else => unreachable(),
    };
}

const Hand = struct {
    kind: HandKind,
    cards: []const u8,
    bid: usize,

    fn cmp(self: Hand, other: Hand, j_is_wild: bool) i8 {
        const dk = self.kind.cmp(other.kind);
        if (dk != 0) {
            return dk;
        }

        for (0..5) |i| {
            const d =
                card_value(self.cards[i], j_is_wild) -
                card_value(other.cards[i], j_is_wild);

            if (d != 0) {
                return d;
            }
        }

        return 0;
    }
};

fn detect_hand_kind(hand_str: []const u8, j_is_wild: bool) HandKind {
    var cards = [_]u4{0} ** 13;

    for (hand_str) |c| {
        switch (c) {
            'A' => { cards[0] += 1; },
            '2'...'9' => {
                const idx = @as(usize, @intCast(c - '1'));
                cards[idx] += 1;
            },
            'T' => { cards[9] += 1; },
            'J' => { cards[10] += 1; },
            'Q' => { cards[11] += 1; },
            'K' => { cards[12] += 1; },
            else => unreachable(),
        }
    }

    if (j_is_wild) {
        const j_value = cards[10];
        cards[10] = 0;
        const idx = std.mem.indexOfMax(u4, cards[0..]);
        cards[idx] += j_value;
    }

    // Bubbles down 2 times
    for (0..2) |k| {
        for (1..cards.len - k) |i| {
            const j = cards.len - i;
            if (cards[j] > cards[j - 1]) {
                const aux = cards[j];
                cards[j] = cards[j - 1];
                cards[j - 1] = aux;
            }
        }
    }

    const result: HandKind =
        if (cards[0] == 5)
            .FiveOfAKind
        else if (cards[0] == 4)
            .FourOfAKind
        else if (cards[0] == 3 and cards[1] == 2)
            .FullHouse
        else if (cards[0] == 3 and cards[1] == 1)
            .ThreeOfAKind
        else if (cards[0] == 2 and cards[1] == 2)
            .TwoPair
        else if (cards[0] == 2 and cards[1] == 1)
            .OnePair
        else
            .HighCard
        ;

    return result;
}

fn lessThanFn(comptime T: type) fn (bool, T, T) bool {
    return struct {
        pub fn inner(j_is_wild: bool, lhs: T, rhs: T) bool { 
            return lhs.cmp(rhs, j_is_wild) <= 0;
        }
    }.inner;
}

fn solve(gpa: Allocator, content: []const u8, j_is_wild: bool) !void {
    var hands: std.ArrayList(Hand) = .empty;
    defer hands.deinit(gpa);

    var iter = std.mem.splitSequence(u8, content, "\n");

    while (iter.next()) |line| {
        if (line.len == 0) continue;

        var iter2 = std.mem.splitSequence(u8, line, " ");

        const cards = iter2.next().?;
        const bid_str = iter2.next().?;
        const kind = detect_hand_kind(cards, j_is_wild);

        const hand = Hand {
            .kind = kind,
            .cards = cards,
            .bid = try std.fmt.parseInt(usize, bid_str, 10),
        };

        try hands.append(gpa, hand);
    }

    // for (hands.items) |hand| {
    //     std.debug.print("{s}, {}, {}\n", .{hand.cards, hand.bid, hand.kind});
    // }

    // std.debug.print("-----\n", .{});

    var total_winnings: usize = 0;

    std.mem.sort(Hand, hands.items, j_is_wild, comptime lessThanFn(Hand));
    for (hands.items, 0..) |hand, rank| {
        std.debug.print("{s}, {}, {}\n", .{hand.cards, hand.bid, hand.kind});

        total_winnings += (rank + 1) * hand.bid;
    }

    std.debug.print("total winnings = {}\n", .{total_winnings});
}

fn part1(gpa: Allocator, content: []const u8) !void {
    try solve(gpa, content, false);
}

fn part2(gpa: Allocator, content: []const u8) !void {
    try solve(gpa, content, true);
}

pub fn main() !void {
    // const file_path = "./inputs/day07-example.txt";
    const file_path = "./inputs/day07.txt";

    const gpa = std.heap.page_allocator;
    const content = try utils.read_file(gpa, file_path);
    defer gpa.free(content);

    if (utils.is_part1()) {
        try part1(gpa, content);
    } else {
        try part2(gpa, content);
    }
}

