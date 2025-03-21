const mem = @import("std").mem;
const fmt = @import("std").fmt;
const units = @import("./units.zig");
const composition = @import("./composition.zig");

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
    comptime unitComposition: type,
) type {
    comptime {
        checkValueType(backingType);
        composition.isComposition(unitComposition);
    }
    return struct {
        comptime underlyingType: type = getUnderlyingType(backingType),
        comptime units: type = unitComposition,
        value: backingType = undefined,
    };
}

pub fn backingTypeCompileError(comptime T: type) void {
    @compileError("Supplied type was '" ++ @typeName(T) ++ "' but must be one of:\nint, float, array of int, array of float, multi-dimensional array of int, multi-dimensional array of float");
}

pub fn checkValueType(comptime T: type) void {
    topLevel: switch (@typeInfo(T)) {
        .int, .float => {},
        .array => |info| switch (@typeInfo(info.child)) {
            .int, .float, .array => checkValueType(info.child),
            else => continue :topLevel @typeInfo(@TypeOf(void)),
        },
        else => backingTypeCompileError(T),
    }
}

pub fn getUnderlyingType(comptime T: type) type {
    topLevel: switch (@typeInfo(T)) {
        .int, .float => return T,
        .array => |info| switch (@typeInfo(info.child)) {
            .int, .float, .array => return getUnderlyingType(info.child),
            else => continue :topLevel @typeInfo(@TypeOf(void)),
        },
        else => backingTypeCompileError(T),
    }
}

pub fn valueDims(comptime T: type) []const u64 {
    comptime {
        topLevel: switch (@typeInfo(T)) {
            .int, .float => return &[0]u64{},
            .array => |info| switch (@typeInfo(info.child)) {
                .int, .float => return &[1]u64{info.len},
                .array => return [1]u64{info.len} ++ valueDims(info.child),
                else => continue :topLevel @typeInfo(@TypeOf(void)),
            },
            else => backingTypeCompileError(T),
        }
    }
}

pub fn dimsMatch(comptime l: type, comptime r: type) void {
    comptime {
        const lDims = valueDims(l);
        const rDims = valueDims(r);
        if (lDims.len != rDims.len or !mem.eql(u64, lDims, rDims)) {
            @compileError("the dimensions of the given quantities do not match\ntype " ++ @typeName(l) ++ " dims: " ++ fmt.comptimePrint("{any}", .{lDims}) ++ "\ndoes not match\ntype " ++ @typeName(r) ++ " dims: " ++ fmt.comptimePrint("{any}", .{rDims}));
        }
    }
}

// Checks that the quantities match. *Does not* check that the quantities units
// match because operations like multiplication do not require the units to
// exactly match.
pub fn match(comptime l: anytype, comptime r: anytype) void {
    comptime {
        dimsMatch(@TypeOf(l.value), @TypeOf(r.value));
        if (l.underlyingType != r.underlyingType) {
            @compileError("the underlying types of the supplied quantities do not match. " ++ @typeName(l.underlyingType) ++ " does not match " ++ @typeName(r.underlyingType));
        }
    }
}

pub fn isQuantity(comptime T: anytype) void {
    comptime {
        const tTypeInfo = @typeInfo(@TypeOf(T));
        switch (tTypeInfo) {
            .@"struct" => |info| {
                if (info.is_tuple) {
                    @compileError("the supplied type was expected to be a struct and not a tuple");
                }

                var foundUnits = false;
                var foundValue = false;
                var foundUnderlyingType = false;
                var expectedUnderlyingType: type = undefined;
                var allFieldNames: [info.fields.len][]const u8 = undefined;
                for (info.fields, 0..) |iterInfo, i| {
                    allFieldNames[i] = iterInfo.name;

                    if (mem.eql(u8, iterInfo.name, "units")) {
                        foundUnits = true;
                        composition.isComposition(T.units);
                    } else if (mem.eql(u8, iterInfo.name, "value")) {
                        foundValue = true;
                        checkValueType(iterInfo.type);
                        expectedUnderlyingType = getUnderlyingType(@TypeOf(T.value));
                    } else if (mem.eql(u8, iterInfo.name, "underlyingType")) {
                        foundUnderlyingType = true;
                    }
                }

                if (!foundUnits) {
                    @compileError("the supplied value was expected to have a field named 'untis'. Have fields: " ++ fmt.comptimePrint("{s}", .{allFieldNames}));
                }
                if (!foundValue) {
                    @compileError("the supplied value was expected to have a field named 'value'. Have fields: " ++ fmt.comptimePrint("{s}", .{allFieldNames}));
                }
                if (!foundUnderlyingType) {
                    @compileError("the supplied value was expected to have a field named 'underlyingType'. Have fields: " ++ fmt.comptimePrint("{s}", .{allFieldNames}));
                }
                if (T.underlyingType != expectedUnderlyingType) {
                    @compileError("the supplied value did not have the correct value for the underlying type. Expected: " ++ @typeName(expectedUnderlyingType) ++ " Got: " ++ @typeName(T.underlyingType));
                }
            },
            .type => @compileError("the supplied type must be a struct but was a type named " ++ @typeName(T)),
            else => @compileError("the supplied type must be a struct but was " ++ @typeName(@TypeOf(T))),
        }
    }
}

// Scientific quantities
pub inline fn Meter(comptime T: type, value: T) Quantity(T, composition.Meter) {
    return .{ .value = value };
}
pub inline fn Gram(comptime T: type, value: T) Quantity(T, composition.Gram) {
    return .{ .value = value };
}
pub inline fn Second(comptime T: type, value: T) Quantity(T, composition.Second) {
    return .{ .value = value };
}
pub inline fn Ampere(comptime T: type, value: T) Quantity(T, composition.Ampere) {
    return .{ .value = value };
}
pub inline fn Kelvin(comptime T: type, value: T) Quantity(T, composition.Kelvin) {
    return .{ .value = value };
}
pub inline fn Mole(comptime T: type, value: T) Quantity(T, composition.Mole) {
    return .{ .value = value };
}
pub inline fn Candela(
    comptime T: type,
    value: T,
) Quantity(T, composition.Candela) {
    return .{ .value = value };
}
// Common SI units that are defined for convenience
pub inline fn Kilogram(
    comptime T: type,
    value: T,
) Quantity(T, composition.Kilogram) {
    return .{ .value = value };
}
pub inline fn Newton(comptime T: type, value: T) Quantity(T, composition.Newton) {
    return .{ .value = value };
}
pub inline fn Joule(comptime T: type, value: T) Quantity(T, composition.Joule) {
    return .{ .value = value };
}

// Comp sci quantities
pub inline fn Byte2(comptime T: type, value: T) Quantity(T, composition.Byte2) {
    return .{ .value = value };
}
pub inline fn Byte10(comptime T: type, value: T) Quantity(T, composition.Byte10) {
    return .{ .value = value };
}

test "check value type" {
    comptime checkValueType(u8);

    comptime checkValueType([1]u8);

    comptime checkValueType([1][1]u8);

    comptime checkValueType([2][2][1]u8);

    // Compile error - wrong type given
    // comptime checkValueType(bool);

    // Compile error - wrong type given
    // comptime getUnderlyingType([]bool);
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
    // const t5 = comptime getUnderlyingType(bool);
    // _ = t5;

    // Compile error - wrong type given
    // const t6 = comptime getUnderlyingType([]bool);
    // _ = t6;
}

test "value dims" {
    const d1 = comptime valueDims(u8);
    try testing.expectEqualSlices(u64, d1, &[0]u64{});

    const d2 = comptime valueDims([1]u8);
    try testing.expectEqualSlices(u64, d2, &[1]u64{1});

    const d3 = comptime valueDims([2]u8);
    try testing.expectEqualSlices(u64, d3, &[1]u64{2});

    const d4 = comptime valueDims([1][1]u8);
    try testing.expectEqualSlices(u64, d4, &[2]u64{ 1, 1 });

    const d5 = comptime valueDims([1][2]u8);
    try testing.expectEqualSlices(u64, d5, &[2]u64{ 1, 2 });

    const d6 = comptime valueDims([2][1]u8);
    try testing.expectEqualSlices(u64, d6, &[2]u64{ 2, 1 });

    const d7 = comptime valueDims([2][2]u8);
    try testing.expectEqualSlices(u64, d7, &[2]u64{ 2, 2 });

    const d8 = comptime valueDims([2][2][1]u8);
    try testing.expectEqualSlices(u64, d8, &[3]u64{ 2, 2, 1 });

    const d9 = comptime valueDims([2][2][2]u8);
    try testing.expectEqualSlices(u64, d9, &[3]u64{ 2, 2, 2 });

    // Compile error - wrong type given
    // const d10 = comptime valueDims(bool);
    // _ = d10;

    // Compile error - wrong type given
    // const d11 = comptime valueDims([]bool);
    // _ = d11;
}

test "dims match" {
    comptime dimsMatch(u8, u8);
    // comptime dimsMatch(u8, [1]u8);
    comptime dimsMatch([1]u8, [1]u8);
    // comptime dimsMatch([1][1]u8, [1]u8);
    // comptime dimsMatch([2]u8, [1]u8);
    comptime dimsMatch([1][1]u8, [1][1]u8);
    // comptime dimsMatch([1][2]u8, [1][1]u8);
    // comptime dimsMatch([2][1]u8, [1][1]u8);
    // comptime dimsMatch([2][2]u8, [1][1]u8);
}

test "match" {
    comptime match(Meter(u8, 1), Meter(u8, 1));
    // comptime match(Meter(u16, 1), Meter(u8, 1));
    // comptime match(Meter([1]u8, [1]u8{1}), Meter(u8, 1));
}

test "isQuantity" {
    comptime isQuantity(Meter(u8, 1));
    comptime isQuantity(Quantity(u8, composition.Meter){});
    comptime isQuantity(.{
        .units = composition.Compose(&[_]units.Unit{units.meter}),
        .value = [1]u8{1},
        .underlyingType = u8,
        .backingType = [1]u8,
    });

    // Compile error - supplied type instead of value
    // comptime isQuantity(Quantity(u8, composition.Meter));

    // Compile error - supplied a value that is not a struct
    // comptime isQuantity(@as(u8, 1));

    // Compile error - supplied value is a struct but is missing units field
    // comptime isQuantity(.{
    //     .value = @as(u8, 1),
    // });

    // Compile error - supplied value is a struct but is missing value field
    // comptime isQuantity(.{
    //     .units = composition.Meter,
    // });

    // Compile error - supplied value is a struct but is missing backingType field
    // comptime isQuantity(.{
    //     .units = composition.Compose(&[_]units.Unit{units.meter}),
    //     .value = @as(u8, 1),
    //     .underlyingType = [1]u8,
    // });

    // Compile error - supplied value is a struct but is missing underlyingType field
    // comptime isQuantity(.{
    //     .units = composition.Compose(&[_]units.Unit{units.meter}),
    //     .value = @as(u8, 1),
    // });

    // Compile error - supplied value is a struct but it's units field is invalid
    // comptime isQuantity(.{
    //     .units = u8,
    //     .value = @as(u8, 1),
    //     .underlyingType = [1]u8,
    // });

    // Compile error - supplied value is a struct but it's units field is invalid
    // comptime isQuantity(.{
    //     .units = composition.Meter,
    //     .value = "test",
    //     .underlyingType = [1]u8,
    // });

    // Compile error - supplied value is a struct but it's underlying type field
    // is invalid
    // comptime isQuantity(.{
    //     .units = composition.Meter,
    //     .value = @as(u8, 1),
    //     .underlyingType = bool,
    // });

    // Compile error - supplied value is a struct but it's underlying type field
    // does not match the type from the value field
    // comptime isQuantity(.{
    //     .units = composition.Meter,
    //     .value = @as(u8, 1),
    //     .underlyingType = u16,
    // });
}

test "Quantity" {
    _ = Quantity(u8, composition.Meter);
    try testing.expectEqual(@sizeOf(Quantity(u8, composition.Meter)), 1);
    try testing.expectEqual(@sizeOf(Quantity(u16, composition.Meter)), 2);
    try testing.expectEqual(@sizeOf(Quantity(u32, composition.Meter)), 4);
    try testing.expectEqual(@sizeOf(Quantity(u64, composition.Meter)), 8);

    try testing.expectEqual(@sizeOf(Quantity([2]u64, composition.Meter)), 8 * 2);
    try testing.expectEqual(
        @sizeOf(Quantity([2][3]u64, composition.Meter)),
        8 * 2 * 3,
    );
    try testing.expectEqual(
        @sizeOf(Quantity([2][3][4]u64, composition.Meter)),
        8 * 2 * 3 * 4,
    );

    const tmp: Quantity(u8, composition.Meter) = .{ .value = 11 };
    try testing.expectEqual(comptime tmp.underlyingType, u8);
    try testing.expectEqual(tmp.value, 11);

    const tmp2: Quantity([2][3]u8, composition.Meter) = .{ .value = [2][3]u8{
        [3]u8{ 1, 2, 3 }, [3]u8{ 4, 5, 6 },
    } };
    try testing.expectEqual(comptime tmp2.underlyingType, u8);
    try testing.expectEqual(
        tmp2.value,
        [2][3]u8{ [3]u8{ 1, 2, 3 }, [3]u8{ 4, 5, 6 } },
    );

    const v1: Quantity(u8, composition.Newton) = Quantity(
        u8,
        composition.Compose(&[_]units.Unit{
            units.kilogram, units.meter, units.Scale(units.second, -2),
        }),
    ){};
    _ = v1;

    // // Compile error - mismatched units between ret type and defined type
    // const v2: Quantity(u8, composition.Newton) = Quantity(
    //     u8,
    //     composition.Compose(&[_]units.Unit{
    //         units.kilogram, units.meter, units.Scale(units.second, -1),
    //     }),
    // ){};
    // _ = v2;

    // Compile error - supplied type is not valid
    // _ = Quantity(bool, composition.Meter);
}
