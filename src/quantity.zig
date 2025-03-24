const mem = @import("std").mem;
const fmt = @import("std").fmt;
const builtin = @import("std").builtin;

const unit = @import("./unit.zig");
const dim = @import("./dimension.zig");
const dims = @import("./dimensions.zig");

const testing = @import("std").testing;
const debug = @import("std").debug;

// Creates a quantity definition type that all the other quantity defs are
// specializations of. The underlying type and dimensions will be calculated
// from the supplied value. The supplied value must be one of:
//  - int
//  - float
//  - array of ints
//  - array of floats
//  - multi-dimensional array of ints
//  - multi-dimensional array of floats
pub fn Quantity(
    comptime backingType: type,
    comptime _dims: getDimType(backingType),
) type {
    comptime {
        // Don't need to check the backing type, that is implicitly done by the
        // getDimType funciton.
        dims.assertAreDims(_dims);
    }
    return struct {
        comptime underlyingType: type = getUnderlyingType(backingType),
        comptime dims: @TypeOf(_dims) = _dims,
        value: backingType = undefined,
    };
}

fn backingTypeCompileError(comptime T: type) void {
    @compileError("supplied value was '" ++ @typeName(T) ++ "' but must be one of:\nint, float, array of int, array of float, multi-dimensional array of int, multi-dimensional array of float");
}

fn getDimType(comptime T: type) type {
    topLevel: switch (@typeInfo(T)) {
        .int, .float => return type,
        .array => |info| switch (@typeInfo(info.child)) {
            .int, .float => return @Type(builtin.Type{ .array = .{
                .len = info.len,
                .child = type,
                .sentinel_ptr = null,
            } }),
            .array => return @Type(builtin.Type{ .array = .{
                .len = info.len,
                .child = getDimType(info.child),
                .sentinel_ptr = null,
            } }),
            else => continue :topLevel @typeInfo(@TypeOf(void)),
        },
        else => backingTypeCompileError(T),
    }
}

fn getUnderlyingType(comptime T: type) type {
    topLevel: switch (@typeInfo(T)) {
        .int, .float => return T,
        .array => |info| switch (@typeInfo(info.child)) {
            .int, .float, .array => return getUnderlyingType(info.child),
            else => continue :topLevel @typeInfo(@TypeOf(void)),
        },
        else => backingTypeCompileError(T),
    }
}

// // TODO - remove fn when assertRank restriction is removed
// fn getRank(comptime T: type) u64 {
//     topLevel: switch (@typeInfo(T)) {
//         .int, .float => return 1,
//         .array => |info| switch (@typeInfo(info.child)) {
//             .int, .float => return 1,
//             .array => return 1 + getRank(info.child),
//             else => continue :topLevel @typeInfo(@TypeOf(void)),
//         },
//         else => backingTypeCompileError(T),
//     }
// }
// fn assertRank(comptime T: type) void {
//     if (getRank(T) > 3) {
//         @compileError("only tensors up to rank 3 are supported due to my current skill issues");
//     }
// }

pub fn assertBackingTypesMatch(comptime l: type, comptime r: type) void {
    comptime {
        if (l != r) {
            @compileError("the dimensions of the underlying values do not match. Type " ++ @typeName(l) ++ " does not match type " ++ @typeName(r));
        }
    }
}

pub fn assertUnderlyingTypesMatch(comptime l: type, comptime r: type) void {
    comptime {
        if (l != r) {
            @compileError("the underlying types of the supplied quantities do not match. " ++ @typeName(l) ++ " does not match " ++ @typeName(r));
        }
    }
}

pub inline fn Unitless(comptime T: type, value: T) Quantity(
    T,
    dims.Fill(getDimType(T), dim.Unitless),
) {
    return .{ .value = value };
}

// Scientific quantities
pub inline fn Meter(comptime T: type, value: T) Quantity(
    T,
    dims.fill(getDimType(T), dim.Meter),
) {
    return .{ .value = value };
}
pub inline fn Gram(comptime T: type, value: T) Quantity(
    T,
    dims.fill(getDimType(T), dim.Gram),
) {
    return .{ .value = value };
}
pub inline fn Second(comptime T: type, value: T) Quantity(
    T,
    dims.fill(getDimType(T), dim.Second),
) {
    return .{ .value = value };
}
pub inline fn Ampere(comptime T: type, value: T) Quantity(
    T,
    dims.fill(getDimType(T), dim.Ampere),
) {
    return .{ .value = value };
}
pub inline fn Kelvin(comptime T: type, value: T) Quantity(
    T,
    dims.fill(getDimType(T), dim.Kelvin),
) {
    return .{ .value = value };
}
pub inline fn Mole(comptime T: type, value: T) Quantity(
    T,
    dims.fill(getDimType(T), dim.Mole),
) {
    return .{ .value = value };
}
pub inline fn Candela(comptime T: type, value: T) Quantity(
    T,
    dims.fill(getDimType(T), dim.Candela),
) {
    return .{ .value = value };
}
// Common SI dims that are defined for convenience
pub inline fn Kilogram(comptime T: type, value: T) Quantity(
    T,
    dims.fill(getDimType(T), dim.Kilogram),
) {
    return .{ .value = value };
}
pub inline fn Newton(comptime T: type, value: T) Quantity(
    T,
    dims.fill(getDimType(T), dim.Newton),
) {
    return .{ .value = value };
}
pub inline fn Joule(comptime T: type, value: T) Quantity(
    T,
    dims.fill(getDimType(T), dim.Joule),
) {
    return .{ .value = value };
}

// Comp sci quantities
pub inline fn Byte2(comptime T: type, value: T) Quantity(
    T,
    dims.fill(getDimType(T), dim.Byte2),
) {
    return .{ .value = value };
}
pub inline fn Byte10(comptime T: type, value: T) Quantity(
    T,
    dims.fill(getDimType(T), dim.Byte10),
) {
    return .{ .value = value };
}

test "get dim type" {
    const t1 = comptime getDimType(u8);
    try testing.expectEqual(t1, type);

    const t2 = comptime getDimType([1]u8);
    try testing.expectEqual(t2, [1]type);

    const t3 = comptime getDimType([2]u8);
    try testing.expectEqual(t3, [2]type);

    const t4 = comptime getDimType([2][2]u8);
    try testing.expectEqual(t4, [2][2]type);

    // Compile errors - wrong underlying type for backing type
    // _ = comptime getDimType(bool);
    // _ = comptime getDimType([]bool);
}

test "get underlying type" {
    const t1 = comptime getUnderlyingType(u8);
    try testing.expectEqual(t1, u8);

    const t2 = comptime getUnderlyingType([1]u8);
    try testing.expectEqual(t2, u8);

    const t3 = comptime getUnderlyingType([1][1]u8);
    try testing.expectEqual(t3, u8);

    const t4 = comptime getUnderlyingType([2][2][1]u8);
    try testing.expectEqual(t4, u8);

    // Compile error - wrong type given
    // _ = comptime getUnderlyingType(bool);

    // Compile error - wrong type given
    // _ = comptime getUnderlyingType([]bool);
}

test "assert underlying types match" {
    comptime assertUnderlyingTypesMatch(
        Meter(u8, 1).underlyingType,
        Meter(u8, 1).underlyingType,
    );
    // comptime assertUnderlyingTypesMatch(
    //     Meter(u16, 1).underlyingType,
    //     Meter(u8, 1).underlyingType,
    // );
    // TODO - re-enable and fix meter func ret type
    // comptime assertUnderlyingTypesMatch(
    //     Meter([1]u8, [1]u8{1}).underlyingType,
    //     Meter(u8, 1).underlyingType,
    // );
}

test "Quantity" {
    _ = Quantity(u8, dim.Meter);
    try testing.expectEqual(@sizeOf(Quantity(u8, dim.Meter)), 1);
    try testing.expectEqual(@sizeOf(Quantity(u16, dim.Meter)), 2);
    try testing.expectEqual(@sizeOf(Quantity(u32, dim.Meter)), 4);
    try testing.expectEqual(@sizeOf(Quantity(u64, dim.Meter)), 8);

    try testing.expectEqual(@sizeOf(Quantity(
        [2]u64,
        [2]type{ dim.Meter, dim.Meter },
    )), 8 * 2);
    try testing.expectEqual(
        @sizeOf(Quantity([2][3]u64, dims.fill([2][3]type, dim.Meter))),
        8 * 2 * 3,
    );
    try testing.expectEqual(
        @sizeOf(Quantity(
            [2][3][4]u64,
            dims.fill([2][3][4]type, dim.Meter),
        )),
        8 * 2 * 3 * 4,
    );

    const tmp: Quantity(u8, dim.Meter) = .{ .value = 11 };
    try testing.expectEqual(comptime tmp.underlyingType, u8);
    try testing.expectEqual(tmp.value, 11);

    const tmp2: Quantity(
        [2][3]u8,
        dims.fill([2][3]type, dim.Meter),
    ) = .{ .value = [2][3]u8{
        [3]u8{ 1, 2, 3 }, [3]u8{ 4, 5, 6 },
    } };
    try testing.expectEqual(comptime tmp2.underlyingType, u8);
    try testing.expectEqual(
        tmp2.value,
        [2][3]u8{ [3]u8{ 1, 2, 3 }, [3]u8{ 4, 5, 6 } },
    );

    const v1: Quantity(u8, dim.Newton) = Quantity(
        u8,
        dim.Compose(&[_]unit.Unit{
            unit.kilogram, unit.meter, unit.scale(unit.second, -2),
        }),
    ){};
    _ = v1;

    // Compile error - mismatched dims between ret type and defined type
    // const v2: Quantity(u8, dim.Newton) = Quantity(
    //     u8,
    //     dim.Compose(&[_]unit.Unit{
    //         unit.kilogram, unit.meter, unit.scale(unit.second, -1),
    //     }),
    // ){};
    // _ = v2;

    // Compile error - mismatched dims between ret type and defined type
    // const v3: Quantity(
    //     [2]u8,
    //     [2]type{ dim.Meter, dim.Second },
    // ) = Quantity(
    //     [2]u8,
    //     [2]type{ dim.Meter, dim.Meter },
    // ){};
    // _ = v3;

    // Compile error - supplied type is not valid
    // _ = Quantity(bool, dim.Meter);
}
