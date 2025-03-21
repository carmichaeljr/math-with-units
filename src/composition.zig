const fmt = @import("std").fmt;
const mem = @import("std").mem;
const builtin = @import("std").builtin;
const units = @import("./units.zig");

const testing = @import("std").testing;
const debug = @import("std").debug;

// Composes many base units into a single type that represents the combination
// of the units. The supplied units will be simplified when possible.
// Simplification will take units that have the same name and base and will
// combine and replace them with a new unit of the same name and unit but with
// the exponents added together.
pub fn Compose(comptime u: []const units.Unit) type {
    comptime {
        const sortedUnits = sortUnits(u);
        const simplifiedUnits = simplifyUnits(&sortedUnits);
        return arrayToStructType(&simplifiedUnits);
    }
}

pub fn Extend(comptime t: type, comptime u: []const units.Unit) type {
    comptime {
        return Compose(structTypeToArray(t) ++ u);
    }
}

// Converts an array of units to a tuple struct of the units
pub fn arrayToStructType(comptime u: []const units.Unit) type {
    comptime {
        var fields: [u.len]builtin.Type.StructField = undefined;
        for (0..u.len) |i| {
            fields[i] = builtin.Type.StructField{
                .name = fmt.comptimePrint("{}", .{i}),
                .type = units.Unit,
                .is_comptime = true,
                .default_value_ptr = &u[i],
                .alignment = 8,
            };
        }

        const retType = builtin.Type{
            .@"struct" = .{
                .fields = &fields,
                .layout = builtin.Type.ContainerLayout.auto,
                .decls = &[0]builtin.Type.Declaration{},
                .is_tuple = true,
            },
        };
        return @Type(retType);
    }
}

// Converts the supplied tuple struct to an array of units
pub fn structTypeToArray(comptime T: type) structTypeToArrayRetType(T) {
    comptime {
        const info = @typeInfo(T).@"struct";
        var rv: [info.fields.len]units.Unit = undefined;
        for (info.fields, 0..) |iterInfo, i| {
            // This is _kinda_ a hack. All comptime fields must have a default
            // initialization value (enforced by the compiler). So by using the
            // default field value we are essentially requiring the field to be
            // a comptime field. The structTypeToArrayRetType checks that the
            // supplied struct is a tuple and that all it's fields are available
            // at comptime.
            rv[i] = iterInfo.defaultValue().?;
        }
        return sortUnits(&rv);
    }
}

fn structTypeToArrayRetType(comptime T: type) type {
    comptime {
        const tTypeInfo = @typeInfo(T);
        switch (tTypeInfo) {
            .@"struct" => |info| {
                if (!info.is_tuple) {
                    @compileError("the supplied type was expected to be a tuple but was not");
                }
                for (info.fields, 0..) |iterInfo, i| {
                    if (!mem.eql(u8, iterInfo.name, fmt.comptimePrint("{}", .{i}))) {
                        @compileError("the supplied type was expected to be a tuple but was not");
                    }
                    if (!iterInfo.is_comptime) {
                        @compileError("all fields of the supplied tuple must be available at comptime. Field " ++ iterInfo.name ++ " is not.");
                    }
                    if (iterInfo.type != units.Unit) {
                        @compileError("field " ++ iterInfo.name ++ " of the the supplied tuple must be of type " ++ @typeName(units.Unit) ++ " but it was type " ++ @typeName(iterInfo.type));
                    }
                }

                return [info.fields.len]units.Unit;
            },
            else => @compileError("the supplied type must be a struct but was " ++ @typeName(T)),
        }
    }
}

pub fn sortUnits(comptime u: []const units.Unit) [u.len]units.Unit {
    comptime {
        var unitsCpy: [u.len]units.Unit = u[0..u.len].*;
        const unitsLt = struct {
            fn lessThan(ctx: anytype, lhs: units.Unit, rhs: units.Unit) bool {
                _ = ctx;
                if (mem.lessThan(u8, lhs.name, rhs.name)) return true;
                if (mem.eql(u8, lhs.name, rhs.name) and lhs.base < rhs.base) {
                    return true;
                }
                return false;
            }
        }.lessThan;
        mem.sort(units.Unit, &unitsCpy, void, unitsLt);
        return unitsCpy;
    }
}

// Combines like units in in the supplied units slice. Units with the same name
// and units will combined into one and their exponents will be added together.
// This function assumes that the units slice is already sorted!
pub fn simplifyUnits(comptime u: []const units.Unit) simplifyUnitsRetType(u) {
    comptime {
        if (u.len == 0) {
            return [0]units.Unit{};
        }

        var cntr = 0;
        var curUnit: units.Unit = u[0];
        var unitsCpy: [u.len]units.Unit = u[0..u.len].*;
        for (u[1..]) |iterUnit| {
            if (!mem.eql(u8, curUnit.name, iterUnit.name)) {
                // If the exponent is 0 then the units "canceled out" and the
                // unit no longer needs to be recorded.
                if (unitsCpy[cntr].exp != 0) {
                    cntr += 1;
                }
                unitsCpy[cntr] = iterUnit;
                curUnit = iterUnit;
            } else {
                unitsCpy[cntr].exp += iterUnit.exp;
            }
        }
        if (unitsCpy[cntr].exp != 0) {
            cntr += 1;
        }

        return unitsCpy[0..cntr].*;
    }
}

// This function assumes that the units slice is already sorted!
fn simplifyUnitsRetType(comptime u: []const units.Unit) type {
    comptime {
        if (u.len == 0) {
            return [0]units.Unit;
        }
        var cntr: u64 = 0;
        var curUnit: units.Unit = u[0];
        var runningExp: i64 = curUnit.exp;
        for (u[1..]) |iterUnit| {
            if (!mem.eql(u8, curUnit.name, iterUnit.name)) {
                // If the exponent is 0 then the units "canceled out" and the
                // unit no longer needs to be recorded.
                if (runningExp != 0) {
                    cntr += 1;
                }
                curUnit = iterUnit;
                runningExp = curUnit.exp;
                continue;
            }

            // Names matched, we are the same unit, check that the unitss match
            if (curUnit.base != iterUnit.base) {
                @compileError("cannot reconcile difference in unitss of the same unit. Got '" ++ curUnit.comptimePrint() ++ "' and '" ++ iterUnit.comptimePrint() ++ "'");
            }

            runningExp += iterUnit.exp;
        }
        if (runningExp != 0) {
            cntr += 1;
        }

        return [cntr]units.Unit;
    }
}

// TODO - is this even needed???
// pub fn combineUnits(comptime T: anytype, comptime U: anytype) []units.Unit {}

// Checks that the supplied unit compositions are exactly equal after
// simplifying units.
pub fn match(comptime l: type, comptime r: type) void {
    comptime {
        // Unitless compositions match every unit type
        if (l == Unitless or r == Unitless) {
            return;
        }

        var lUnits = structTypeToArray(l);
        var rUnits = structTypeToArray(r);
        lUnits = simplifyUnits(&lUnits);
        rUnits = simplifyUnits(&rUnits);
        if (l == r) {
            return;
        }

        var lStr: []const u8 = "";
        var rStr: []const u8 = "";
        for (lUnits) |iterL| {
            lStr = lStr ++ iterL.comptimePrint() ++ " ";
        }
        for (rUnits) |iterR| {
            rStr = rStr ++ iterR.comptimePrint() ++ " ";
        }
        @compileError("Units did not match.\n" ++ lStr ++ "\ndoes not match\n" ++ rStr);
    }
}

pub fn isComposition(comptime T: type) void {
    _ = structTypeToArray(T);
}

pub const Unitless = Compose(&[0]units.Unit{});

// Scientific units
pub const Meter = Compose(&[_]units.Unit{units.meter});
pub const Gram = Compose(&[_]units.Unit{units.gram});
pub const Second = Compose(&[_]units.Unit{units.second});
pub const Ampere = Compose(&[_]units.Unit{units.ampere});
pub const Kelvin = Compose(&[_]units.Unit{units.kelvin});
pub const Mole = Compose(&[_]units.Unit{units.mole});
pub const Candela = Compose(&[_]units.Unit{units.candela});
// Common SI units that are defined for convenience
pub const Kilogram = Compose(&[_]units.Unit{units.kilogram});
pub const Newton = Compose(&[_]units.Unit{
    units.kilogram, units.meter, units.Scale(units.second, -2),
});
pub const Joule = Compose(&[_]units.Unit{
    units.kilogram, units.Scale(units.meter, 2), units.Scale(units.second, -2),
});

// Comp sci units
pub const Byte2 = Compose(&[_]units.Unit{units.byte2});
pub const Byte10 = Compose(&[_]units.Unit{units.byte10});

test "array to struct type" {
    const t1 = comptime arrayToStructType(@constCast(&[_]units.Unit{units.meter}));
    try testing.expectEqual(@sizeOf(t1), 0);
    try testing.expectEqual(@typeInfo(t1).@"struct".is_tuple, true);
    try testing.expectEqual(@typeInfo(t1).@"struct".fields.len, 1);
    try testing.expectEqual(@typeInfo(t1).@"struct".fields[0].type, units.Unit);
    try testing.expectEqual(@typeInfo(t1).@"struct".fields[0].name, "0");
    try testing.expectEqual(@typeInfo(t1).@"struct".fields[0].is_comptime, true);
    try testing.expectEqual(
        @typeInfo(t1).@"struct".fields[0].defaultValue(),
        units.meter,
    );

    const t2 = comptime arrayToStructType(
        @constCast(&[_]units.Unit{ units.meter, units.second }),
    );
    try testing.expectEqual(@sizeOf(t2), 0);
    try testing.expectEqual(@typeInfo(t2).@"struct".is_tuple, true);
    try testing.expectEqual(@typeInfo(t2).@"struct".fields.len, 2);
    try testing.expectEqual(@typeInfo(t2).@"struct".fields[0].type, units.Unit);
    try testing.expectEqual(@typeInfo(t2).@"struct".fields[0].name, "0");
    try testing.expectEqual(@typeInfo(t2).@"struct".fields[0].is_comptime, true);
    try testing.expectEqual(@typeInfo(t2).@"struct".fields[1].type, units.Unit);
    try testing.expectEqual(@typeInfo(t2).@"struct".fields[1].name, "1");
    try testing.expectEqual(@typeInfo(t2).@"struct".fields[1].is_comptime, true);
}

test "struct to array" {
    const v1 = comptime structTypeToArray(@TypeOf(.{}));
    try testing.expectEqual(@TypeOf(v1), [0]units.Unit);
    try testing.expectEqual(v1.len, 0);

    const v2 = comptime structTypeToArray(@TypeOf(.{
        units.Unit{ .name = "test", .base = 10, .exp = 3 },
    }));
    try testing.expectEqual(@TypeOf(v2), [1]units.Unit);
    try testing.expectEqual(v2.len, 1);
    try testing.expectEqual(v2[0].name, "test");
    try testing.expectEqual(v2[0].base, 10);
    try testing.expectEqual(v2[0].exp, 3);

    const v3 = comptime structTypeToArray(@TypeOf(.{
        units.Unit{ .name = "test", .base = 10, .exp = 3 },
        units.Unit{ .name = "test2", .base = 11, .exp = 4 },
    }));
    try testing.expectEqual(@TypeOf(v3), [2]units.Unit);
    try testing.expectEqual(v3.len, 2);
    try testing.expectEqual(v3[0].name, "test");
    try testing.expectEqual(v3[0].base, 10);
    try testing.expectEqual(v3[0].exp, 3);
    try testing.expectEqual(v3[1].name, "test2");
    try testing.expectEqual(v3[1].base, 11);
    try testing.expectEqual(v3[1].exp, 4);

    const v4 = comptime structTypeToArray(@TypeOf(.{
        units.Unit{ .name = "b", .base = 10, .exp = 3 },
        units.Unit{ .name = "a", .base = 11, .exp = 4 },
    }));
    try testing.expectEqual(@TypeOf(v4), [2]units.Unit);
    try testing.expectEqual(v4.len, 2);
    try testing.expectEqual(v4[0].name, "a");
    try testing.expectEqual(v4[0].base, 11);
    try testing.expectEqual(v4[0].exp, 4);
    try testing.expectEqual(v4[1].name, "b");
    try testing.expectEqual(v4[1].base, 10);
    try testing.expectEqual(v4[1].exp, 3);

    // Compile error - type of @"0" is not units.Unit
    // const v5 = comptime structTypeToArray(@TypeOf(.{
    //     "test",
    //     units.Unit{ .name = "test", .units = 10, .exp = 3 },
    // }));
    // _ = v5;

    // Compile error - non-tuple argument
    // const v6 = comptime structTypeToArray(@TypeOf(units.Unit{
    //     .name = "test",
    //     .units = 10,
    //     .exp = 3,
    // }));
    // _ = v6;

    // Compile error - non struct type
    // const v7 = comptime structTypeToArray([4]u8);
    // _ = v7;

    // Compile error - non struct type (again)
    // const v8 = comptime structTypeToArray(u8);
    // _ = v8;
}

test "simplify units" {
    const t1 = comptime simplifyUnits(@constCast(&[_]units.Unit{units.meter}));
    try testing.expectEqual(t1, [1]units.Unit{units.meter});

    const t2 = comptime simplifyUnits(@constCast(
        &[_]units.Unit{ units.meter, units.second },
    ));
    try testing.expectEqual(t2, [2]units.Unit{ units.meter, units.second });

    const t3 = comptime simplifyUnits(@constCast(
        &[_]units.Unit{ units.meter, units.meter },
    ));
    try testing.expectEqual(t3, [1]units.Unit{
        .{ .name = units.meter.name, .base = units.meter.base, .exp = 2 },
    });

    const t4 = comptime simplifyUnits(@constCast(&[_]units.Unit{
        .{ .name = units.meter.name, .base = units.meter.base, .exp = 1 },
        .{ .name = units.meter.name, .base = units.meter.base, .exp = -1 },
    }));
    try testing.expectEqual(t4, [0]units.Unit{});

    // Compile error - same unit different unitss
    // const t5 = comptime simplifyUnits(@constCast(&[_]units.Unit{
    //     meter,
    //     .{ .name = meter.name, .units = meter.units + 1, .exp = 1 },
    // }));
    // _ = t5;
}

test "match" {
    comptime match(Unitless, Unitless);
    comptime match(Unitless, Meter);
    comptime match(Meter, Unitless);
    comptime match(Meter, Meter);

    // Compile error - units do not match
    // comptime match(Meter, Second);

    comptime match(Newton, Newton);
    comptime match(Newton, Compose(&[_]units.Unit{
        units.kilogram, units.meter, units.Scale(units.second, -2),
    }));

    // Compile error - units do not match
    // comptime match(Newton, Compose(&[_]units.Unit{
    //     units.Scale(units.kilogram, 2),
    //     units.meter,
    //     units.Scale(units.second, -2),
    // }));
}

test "Compose" {
    const t1 = Compose(&[_]units.Unit{ units.meter, units.second });
    const t2 = Compose(&[_]units.Unit{ units.second, units.meter });
    const t3 = Compose(&[_]units.Unit{ units.meter, units.meter });
    const t4 = Compose(&[_]units.Unit{ units.meter, units.second });
    const t5 = Compose(
        &[_]units.Unit{
            units.meter,
            units.Unit{
                .name = "s",
                .base = 10,
                .exp = 1,
            },
        },
    );

    try testing.expectEqual(@sizeOf(Unitless), 0);
    try testing.expectEqual(@sizeOf(t1), 0);
    try testing.expectEqual(@sizeOf(t2), 0);
    try testing.expectEqual(@sizeOf(t3), 0);
    try testing.expectEqual(@sizeOf(t4), 0);
    try testing.expectEqual(@sizeOf(t5), 0);

    try testing.expectEqual(t1, t1);
    try testing.expectEqual(t2, t2);
    try testing.expectEqual(t1, t2);
    try testing.expectEqual(t1 == t3, false);
    try testing.expectEqual(t2 == t3, false);
    try testing.expectEqual(t1, t4);
    try testing.expectEqual(t1, t5);
    try testing.expectEqual(Meter, Compose(&[_]units.Unit{units.meter}));
    try testing.expectEqual(t1, Compose(&[_]units.Unit{
        units.meter,
        units.second,
    }));
    try testing.expectEqual(
        Meter == Compose(&[_]units.Unit{ units.meter, units.second }),
        false,
    );
    try testing.expectEqual(
        Meter == Compose(&[_]units.Unit{ units.meter, units.meter }),
        false,
    );
    try testing.expectEqual(
        Compose(&[_]units.Unit{
            units.meter,
            units.second,
        }) == Compose(&[_]units.Unit{
            units.meter,
            units.meter,
        }),
        false,
    );
}

test "Extend" {
    const t1 = Compose(&[_]units.Unit{ units.meter, units.second });
    const t2 = Compose(&[_]units.Unit{units.meter});
    const t3 = Extend(t2, &[_]units.Unit{units.second});
    const t4 = Extend(t2, &[_]units.Unit{units.meter});

    try testing.expectEqual(t1, t3);
    try testing.expectEqual(t1 == t4, false);

    const t5 = Extend(Kilogram, &[_]units.Unit{
        units.Scale(units.second, -2),
        units.meter,
    });
    try testing.expectEqual(Newton, t5);

    const t6 = Extend(t5, &[_]units.Unit{units.Scale(units.second, 2)});
    try testing.expectEqual(Newton == t6, false);
}
