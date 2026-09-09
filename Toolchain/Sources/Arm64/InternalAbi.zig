const Machine = @import("Machine.zig");

/// Small aggregate arguments use consecutive general-purpose registers when
/// the complete flattened argument list fits the native register window.
/// Larger signatures retain the pointer-per-aggregate convention so stack
/// argument layout remains unchanged.
pub fn flattensSmallAggregates(arguments: []const Machine.Span) bool {
    var flattened_count: usize = 0;
    var has_small_aggregate = false;
    for (arguments) |argument| {
        if (isSmallAggregate(argument)) {
            flattened_count += argument.width;
            has_small_aggregate = true;
        } else flattened_count += 1;
    }
    return has_small_aggregate and flattened_count <= Machine.max_register_arguments;
}

pub fn registerArgumentCount(arguments: []const Machine.Span) usize {
    if (!flattensSmallAggregates(arguments)) return arguments.len;
    var count: usize = 0;
    for (arguments) |argument| count += registerWidth(argument, true);
    return count;
}

pub fn registerWidth(argument: Machine.Span, flattened: bool) usize {
    return if (flattened and isSmallAggregate(argument)) argument.width else 1;
}

pub fn isDirectAggregate(argument: Machine.Span, flattened: bool) bool {
    return flattened and isSmallAggregate(argument);
}

fn isSmallAggregate(argument: Machine.Span) bool {
    return argument.aggregate and argument.width > 0 and argument.width <= 2;
}

test "flatten only complete small aggregate register signatures" {
    const small = Machine.Span{ .start = 0, .width = 2, .aggregate = true };
    const scalar = Machine.Span{ .start = 2, .width = 1, .aggregate = false };
    const large = Machine.Span{ .start = 3, .width = 3, .aggregate = true };
    try @import("std").testing.expect(flattensSmallAggregates(&.{ small, scalar }));
    try @import("std").testing.expectEqual(@as(usize, 3), registerArgumentCount(&.{ small, scalar }));
    try @import("std").testing.expect(!flattensSmallAggregates(&.{ large, scalar }));
    try @import("std").testing.expect(!flattensSmallAggregates(&.{ small, scalar, scalar, scalar, scalar, scalar, scalar, scalar }));
}
