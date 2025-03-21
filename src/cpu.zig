const mem = @import("std").mem;
const testing = @import("std").testing;
const assert = @import("std").debug.assert;
const units = @import("./units.zig");
const quantity = @import("./quantities.zig");
const composition = @import("./composition.zig");

const debug = @import("std").debug;

pub fn add(l: anytype, r: anytype) @TypeOf(l) {
    comptime {
        quantity.isQuantity(l);
        quantity.isQuantity(r);
        quantity.match(l, r);
        composition.match(l.units, r.units);
    }

    switch (@typeInfo(@TypeOf(l.value))) {
        inline .int, .float => return @TypeOf(l){ .value = l.value + r.value },
        .array => |_| {
            // TODO - SIMD????

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
        else => quantity.valueTypeCompileError(@TypeOf(l.value)),
    }
}

test "Add SIQuantity" {
    const m1 = quantity.Meter(u8, 3);
    const m2 = quantity.Meter(u8, 5);
    const m3 = add(m1, m2);
    try testing.expectEqual(@TypeOf(m3), quantity.Quantity(u8, composition.Meter));
    try testing.expectEqual(m3.value, 8);
    try testing.expectEqual(@sizeOf(@TypeOf(m3)), 1);

    // const m4 = values.Meter(
    //     [2][3]u8,
    //     [2][3]u8{ [3]u8{ 1, 2, 3 }, [3]u8{ 4, 5, 6 } },
    // );
    // const m5 = values.Meter(
    //     [2][3]u8,
    //     [2][3]u8{ [3]u8{ 7, 8, 9 }, [3]u8{ 10, 11, 12 } },
    // );
    // const m6 = add(m4, m5);
    // try testing.expectEqual(comptime m6.underlyingType, u8);
    // try testing.expectEqual(comptime m6.valueType, [2][3]u8);
    // try testing.expectEqual(comptime m6.units, units.SIMeter);
    // try testing.expectEqual(
    //     m6.value,
    //     [2][3]u8{ [3]u8{ 8, 10, 12 }, [3]u8{ 14, 16, 18 } },
    // );
    // try testing.expectEqual(@sizeOf(@TypeOf(m6)), 1 * 2 * 3);
    // debug.print("{}\n", .{m6});

    // const m1 = quantityDefs.Meter(i8, 3);
    // const m2 = quantityDefs.Meter(i8, 4);
    // const m3 = Add(m1, m2);
    // try testing.expectEqual(m3.value, [_]i8{7});

    // // const m5 = quantityDefs.Kilometer(i8, 5);
    // // Add(m1, m5);
    // // const m6 = Add(m1, .{ .value = 1, .units = unitDefs.SIKilometers });
    // // _ = m6;

    // // const m7 = Add(.{ .value = 1, .units = unitDefs.SIMeter }, m1);
    // // _ = m7;

    // // const m8 = Add(.{ .value = 1, .units = unitDefs.SIMeter }, .{ .value = 1, .units = unitDefs.SIMeter });
    // // _ = m8;

    // // const tmp = struct { value: i8, comptime units: unitDefs.SIUnit = .{} };
    // // const m9 = Add(tmp{ .value = 1, .units = unitDefs.SIUnit{} }, tmp{ .value = 2, .units = unitDefs.SIUnit{} });
    // // _ = m9;

    // const customMeters = quantityDefs.SIQuantity(i8, unitDefs.SIMeter, &dims.Scalar);
    // const m10 = Add(m1, customMeters{ .value = [_]i8{1} });
    // _ = m10;

    // // const customMeters2 = quantityDefs.SIQuantity(i16, unitDefs.SIMeter, &dims.Scalar);
    // // const m11 = Add(m1, customMeters2{ .value = 1 });
    // // _ = m11;
}
