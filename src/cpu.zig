const mem = @import("std").mem;
const assert = @import("std").debug.assert;

const unit = @import("./unit.zig");
const quantity = @import("./quantity.zig");
const dim = @import("./dimension.zig");
const dims = @import("./dimensions.zig");

const testing = @import("std").testing;
const debug = @import("std").debug;

pub fn add(l: anytype, r: anytype) @TypeOf(l) {
    // TODO - what about pointer values??? - might not need to since zig does one level auto pointer de-ref
    comptime {
        quantity.assertBackingTypesMatch(@TypeOf(l.value), @TypeOf(r.value));
        quantity.assertUnderlyingTypesMatch(l.underlyingType, r.underlyingType);
        dims.assertCanAdd(l.dims, r.dims);
    }

    switch (@typeInfo(@TypeOf(l.value))) {
        inline .int, .float => return @TypeOf(l){ .value = l.value + r.value },
        // inline .int, .float => switch (@typeInfo(@TypeOf(l))) {
        //     .pointer => |info| return info.child{ .value = l.value + r.value },
        //     else => return @TypeOf(l){ .value = l.value + r.value },
        // },
        .array => |_| {
            // TODO - SIMD???? - must use conditional compilation for benchmarks

            assert(@sizeOf(l.underlyingType) != 0);
            var rv: @TypeOf(l) = .{ .value = undefined };
            const numVals = @sizeOf(@TypeOf(l.value)) / @sizeOf(l.underlyingType);

            const rvRawVal: [*]rv.underlyingType = @as(
                [*]rv.underlyingType,
                @ptrCast(&rv.value),
            );
            const lRawVal: [*]l.underlyingType = @as(
                [*]l.underlyingType,
                @constCast(@ptrCast(&l.value)),
            );
            const rRawVal: [*]r.underlyingType = @as(
                [*]r.underlyingType,
                @constCast(@ptrCast(&r.value)),
            );

            for (0..numVals) |i| {
                rvRawVal[i] = lRawVal[i] + rRawVal[i];
            }
            return rv;
        },
        else => @compileError("TODO"),
    }
}

test "add" {
    const m1 = quantity.Meter(u8, 3);
    const m2 = quantity.Meter(u8, 5);
    const m3 = add(m1, m2);
    try testing.expectEqual(@TypeOf(m3), quantity.Quantity(u8, dim.Meter));
    try testing.expectEqual(m3.value, 8);
    try testing.expectEqual(@sizeOf(@TypeOf(m3)), 1);

    const m4 = quantity.Meter(
        [2][3]u8,
        [2][3]u8{ [3]u8{ 1, 2, 3 }, [3]u8{ 4, 5, 6 } },
    );
    const m5 = quantity.Meter(
        [2][3]u8,
        [2][3]u8{ [3]u8{ 7, 8, 9 }, [3]u8{ 10, 11, 12 } },
    );
    const m6 = add(m4, m5);
    try testing.expectEqual(comptime m6.underlyingType, u8);
    try testing.expectEqual(@TypeOf(m6.value), [2][3]u8);
    try testing.expectEqual(m6.dims, [2][3]type{
        [3]type{ dim.Meter, dim.Meter, dim.Meter },
        [3]type{ dim.Meter, dim.Meter, dim.Meter },
    });
    try testing.expectEqual(
        m6.value,
        [2][3]u8{ [3]u8{ 8, 10, 12 }, [3]u8{ 14, 16, 18 } },
    );
    try testing.expectEqual(@sizeOf(@TypeOf(m6)), 1 * 2 * 3);

    // const m7 = add(&m1, &m2);
    // _ = m7;

    // _ = add(m1, m5);

    // _ = add(
    //     m1,
    //     quantity.Quantity(
    //         u8,
    //         dim.Compose(&[_]unit.Unit{unit.kilo(unit.meter)}),
    //     ){},
    // );

    // _ = add(m1, .{
    //     .value = @as(u8, 1),
    //     .underlyingType = u8,
    //     .dims = dim.Compose(&[_]unit.Unit{unit.kilo(unit.meter)}),
    // });
}
