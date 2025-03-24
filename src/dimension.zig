const fmt = @import("std").fmt;
const mem = @import("std").mem;
const builtin = @import("std").builtin;

const unit = @import("./unit.zig");

const testing = @import("std").testing;
const debug = @import("std").debug;

// Composes many base units into a single type that represents the combination
// of the units. The supplied units will be simplified when possible.
// Simplification will take units that have the same name and base and will
// combine and replace them with a new unit of the same name and unit but with
// the exponents added together.
pub fn Compose(comptime u: []const unit.Unit) type {
    comptime {
        const sortedUnits = sortUnits(u);
        const simplifiedUnits = simplifyUnits(&sortedUnits);
        return arrayToStructType(&simplifiedUnits);
    }
}

// Extends the supplied units with the given list of units. This can be used to
// add more units but also to remove units by canceling them out. The returned
// unit will be the simplified result of adding the supplied units to the
// supplied unit type.
pub fn Extend(comptime t: type, comptime u: []const unit.Unit) type {
    comptime {
        return Compose(structTypeToArray(t) ++ u);
    }
}

// Converts an array of units to a tuple struct of the units
pub fn arrayToStructType(comptime u: []const unit.Unit) type {
    comptime {
        var fields: [u.len]builtin.Type.StructField = undefined;
        for (0..u.len) |i| {
            fields[i] = builtin.Type.StructField{
                .name = fmt.comptimePrint("{}", .{i}),
                .type = unit.Unit,
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
        var rv: [info.fields.len]unit.Unit = undefined;
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
                    if (!mem.eql(
                        u8,
                        iterInfo.name,
                        fmt.comptimePrint("{}", .{i}),
                    )) {
                        @compileError("the supplied type was expected to be a tuple but was not");
                    }
                    if (!iterInfo.is_comptime) {
                        @compileError("all fields of the supplied tuple must be available at comptime. Field " ++ iterInfo.name ++ " is not.");
                    }
                    if (iterInfo.type != unit.Unit) {
                        @compileError("field " ++ iterInfo.name ++ " of the the supplied tuple must be of type " ++ @typeName(unit.Unit) ++ " but it was type " ++ @typeName(iterInfo.type));
                    }
                }

                return [info.fields.len]unit.Unit;
            },
            else => @compileError("the supplied type must be a dimension struct but was " ++ @typeName(T)),
        }
    }
}

// Returns a string representation of the supplied composition
pub fn format(comptime T: type) []const u8 {
    var tUnits = structTypeToArray(T);
    tUnits = simplifyUnits(&tUnits);

    var tStr: []const u8 = "";
    for (tUnits, 0..) |iterL, i| {
        tStr = tStr ++ iterL.comptimePrint();
        if (i + 1 < tUnits.len) {
            tStr = tStr ++ " ";
        }
    }
    return tStr;
}

// Sorts the supplied units by name and by base with units of the same name
pub fn sortUnits(comptime u: []const unit.Unit) [u.len]unit.Unit {
    comptime {
        var unitsCpy: [u.len]unit.Unit = u[0..u.len].*;
        const unitsLt = struct {
            fn lessThan(ctx: anytype, lhs: unit.Unit, rhs: unit.Unit) bool {
                _ = ctx;
                if (mem.lessThan(u8, lhs.name, rhs.name)) return true;
                if (mem.eql(u8, lhs.name, rhs.name) and lhs.base < rhs.base) {
                    return true;
                }
                return false;
            }
        }.lessThan;
        mem.sort(unit.Unit, &unitsCpy, void, unitsLt);
        return unitsCpy;
    }
}

// Combines like units in in the supplied units slice. Units with the same name
// and units will combined into one and their exponents will be added together.
// This function assumes that the units slice is already sorted!
pub fn simplifyUnits(comptime u: []const unit.Unit) simplifyUnitsRetType(u) {
    comptime {
        if (u.len == 0) {
            return [0]unit.Unit{};
        }

        var cntr = 0;
        var curUnit: unit.Unit = u[0];
        var unitsCpy: [u.len]unit.Unit = u[0..u.len].*;
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
fn simplifyUnitsRetType(comptime u: []const unit.Unit) type {
    comptime {
        if (u.len == 0) {
            return [0]unit.Unit;
        }
        var cntr: u64 = 0;
        var curUnit: unit.Unit = u[0];
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

        return [cntr]unit.Unit;
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

        const lStr = format(l);
        const rStr = format(r);
        @compileError("Units did not match.\n" ++ lStr ++ "\ndoes not match\n" ++ rStr);
    }
}

pub fn assertIsDim(comptime T: type) void {
    _ = structTypeToArray(T);
}

pub const Unitless = Compose(&[0]unit.Unit{});

// Scientific units
pub const Meter = Compose(&[_]unit.Unit{unit.meter});
pub const Gram = Compose(&[_]unit.Unit{unit.gram});
pub const Second = Compose(&[_]unit.Unit{unit.second});
pub const Ampere = Compose(&[_]unit.Unit{unit.ampere});
pub const Kelvin = Compose(&[_]unit.Unit{unit.kelvin});
pub const Mole = Compose(&[_]unit.Unit{unit.mole});
pub const Candela = Compose(&[_]unit.Unit{unit.candela});
// Common SI units that are defined for convenience
pub const Kilogram = Compose(&[_]unit.Unit{unit.kilogram});
pub const Newton = Compose(&[_]unit.Unit{
    unit.kilogram, unit.meter, unit.scale(unit.second, -2),
});
pub const Joule = Compose(&[_]unit.Unit{
    unit.kilogram, unit.scale(unit.meter, 2), unit.scale(unit.second, -2),
});

// Comp sci units
pub const Byte2 = Compose(&[_]unit.Unit{unit.byte2});
pub const Byte10 = Compose(&[_]unit.Unit{unit.byte10});

test "array to struct type" {
    const t1 = comptime arrayToStructType(@constCast(&[_]unit.Unit{unit.meter}));
    try testing.expectEqual(@sizeOf(t1), 0);
    try testing.expectEqual(@typeInfo(t1).@"struct".is_tuple, true);
    try testing.expectEqual(@typeInfo(t1).@"struct".fields.len, 1);
    try testing.expectEqual(@typeInfo(t1).@"struct".fields[0].type, unit.Unit);
    try testing.expectEqual(@typeInfo(t1).@"struct".fields[0].name, "0");
    try testing.expectEqual(@typeInfo(t1).@"struct".fields[0].is_comptime, true);
    try testing.expectEqual(
        @typeInfo(t1).@"struct".fields[0].defaultValue(),
        unit.meter,
    );

    const t2 = comptime arrayToStructType(
        @constCast(&[_]unit.Unit{ unit.meter, unit.second }),
    );
    try testing.expectEqual(@sizeOf(t2), 0);
    try testing.expectEqual(@typeInfo(t2).@"struct".is_tuple, true);
    try testing.expectEqual(@typeInfo(t2).@"struct".fields.len, 2);
    try testing.expectEqual(@typeInfo(t2).@"struct".fields[0].type, unit.Unit);
    try testing.expectEqual(@typeInfo(t2).@"struct".fields[0].name, "0");
    try testing.expectEqual(@typeInfo(t2).@"struct".fields[0].is_comptime, true);
    try testing.expectEqual(@typeInfo(t2).@"struct".fields[1].type, unit.Unit);
    try testing.expectEqual(@typeInfo(t2).@"struct".fields[1].name, "1");
    try testing.expectEqual(@typeInfo(t2).@"struct".fields[1].is_comptime, true);
}

test "struct to array" {
    const v1 = comptime structTypeToArray(@TypeOf(.{}));
    try testing.expectEqual(@TypeOf(v1), [0]unit.Unit);
    try testing.expectEqual(v1.len, 0);

    const v2 = comptime structTypeToArray(@TypeOf(.{
        unit.Unit{ .name = "test", .base = 10, .exp = 3 },
    }));
    try testing.expectEqual(@TypeOf(v2), [1]unit.Unit);
    try testing.expectEqual(v2.len, 1);
    try testing.expectEqual(v2[0].name, "test");
    try testing.expectEqual(v2[0].base, 10);
    try testing.expectEqual(v2[0].exp, 3);

    const v3 = comptime structTypeToArray(@TypeOf(.{
        unit.Unit{ .name = "test", .base = 10, .exp = 3 },
        unit.Unit{ .name = "test2", .base = 11, .exp = 4 },
    }));
    try testing.expectEqual(@TypeOf(v3), [2]unit.Unit);
    try testing.expectEqual(v3.len, 2);
    try testing.expectEqual(v3[0].name, "test");
    try testing.expectEqual(v3[0].base, 10);
    try testing.expectEqual(v3[0].exp, 3);
    try testing.expectEqual(v3[1].name, "test2");
    try testing.expectEqual(v3[1].base, 11);
    try testing.expectEqual(v3[1].exp, 4);

    const v4 = comptime structTypeToArray(@TypeOf(.{
        unit.Unit{ .name = "b", .base = 10, .exp = 3 },
        unit.Unit{ .name = "a", .base = 11, .exp = 4 },
    }));
    try testing.expectEqual(@TypeOf(v4), [2]unit.Unit);
    try testing.expectEqual(v4.len, 2);
    try testing.expectEqual(v4[0].name, "a");
    try testing.expectEqual(v4[0].base, 11);
    try testing.expectEqual(v4[0].exp, 4);
    try testing.expectEqual(v4[1].name, "b");
    try testing.expectEqual(v4[1].base, 10);
    try testing.expectEqual(v4[1].exp, 3);

    // Compile error - type of @"0" is not unit.Unit
    // const v5 = comptime structTypeToArray(@TypeOf(.{
    //     "test",
    //     unit.Unit{ .name = "test", .unit = 10, .exp = 3 },
    // }));
    // _ = v5;

    // Compile error - non-tuple argument
    // const v6 = comptime structTypeToArray(@TypeOf(unit.Unit{
    //     .name = "test",
    //     .unit = 10,
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

test "format" {
    const f1 = comptime format(Meter);
    try testing.expectEqualStrings(f1, "m*10^1");

    const f2 = comptime format(Newton);
    try testing.expectEqualStrings(f2, "g*10^3 m*10^1 s*10^-2");
}

test "sort units" {
    const l1 = comptime sortUnits(&[_]unit.Unit{ unit.meter, unit.second });
    try testing.expectEqualSlices(
        unit.Unit,
        &[_]unit.Unit{ unit.meter, unit.second },
        &l1,
    );

    const l2 = comptime sortUnits(&[_]unit.Unit{ unit.second, unit.meter });
    try testing.expectEqualSlices(
        unit.Unit,
        &[_]unit.Unit{ unit.meter, unit.second },
        &l2,
    );

    const l3 = comptime sortUnits(&[_]unit.Unit{
        unit.second,
        unit.meter,
        .{
            .name = unit.meter.name,
            .base = unit.meter.base + 1,
            .exp = unit.meter.exp,
        },
    });
    try testing.expectEqualSlices(
        unit.Unit,
        &[_]unit.Unit{
            unit.meter,
            .{
                .name = unit.meter.name,
                .base = unit.meter.base + 1,
                .exp = unit.meter.exp,
            },
            unit.second,
        },
        &l3,
    );

    const l4 = comptime sortUnits(&[_]unit.Unit{
        unit.second,
        .{
            .name = unit.meter.name,
            .base = unit.meter.base + 1,
            .exp = unit.meter.exp,
        },
        unit.meter,
    });
    try testing.expectEqualSlices(
        unit.Unit,
        &[_]unit.Unit{
            unit.meter,
            .{
                .name = unit.meter.name,
                .base = unit.meter.base + 1,
                .exp = unit.meter.exp,
            },
            unit.second,
        },
        &l4,
    );
}

test "simplify units" {
    const t1 = comptime simplifyUnits(@constCast(&[_]unit.Unit{unit.meter}));
    try testing.expectEqual(t1, [1]unit.Unit{unit.meter});

    const t2 = comptime simplifyUnits(@constCast(
        &[_]unit.Unit{ unit.meter, unit.second },
    ));
    try testing.expectEqual(t2, [2]unit.Unit{ unit.meter, unit.second });

    const t3 = comptime simplifyUnits(@constCast(
        &[_]unit.Unit{ unit.meter, unit.meter },
    ));
    try testing.expectEqual(t3, [1]unit.Unit{
        .{ .name = unit.meter.name, .base = unit.meter.base, .exp = 2 },
    });

    const t4 = comptime simplifyUnits(@constCast(&[_]unit.Unit{
        .{ .name = unit.meter.name, .base = unit.meter.base, .exp = 1 },
        .{ .name = unit.meter.name, .base = unit.meter.base, .exp = -1 },
    }));
    try testing.expectEqual(t4, [0]unit.Unit{});

    // Compile error - same unit different unitss
    // const t5 = comptime simplifyUnits(@constCast(&[_]unit.Unit{
    //     meter,
    //     .{ .name = meter.name, .unit = meter.unit + 1, .exp = 1 },
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
    comptime match(Newton, Compose(&[_]unit.Unit{
        unit.kilogram, unit.meter, unit.scale(unit.second, -2),
    }));

    // Compile error - units do not match
    // comptime match(Newton, Compose(&[_]unit.Unit{
    //     unit.scale(unit.kilogram, 2),
    //     unit.meter,
    //     unit.scale(unit.second, -2),
    // }));
}

test "Compose" {
    const t1 = Compose(&[_]unit.Unit{ unit.meter, unit.second });
    const t2 = Compose(&[_]unit.Unit{ unit.second, unit.meter });
    const t3 = Compose(&[_]unit.Unit{ unit.meter, unit.meter });
    const t4 = Compose(&[_]unit.Unit{ unit.meter, unit.second });
    const t5 = Compose(
        &[_]unit.Unit{
            unit.meter,
            unit.Unit{
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
    try testing.expectEqual(Meter, Compose(&[_]unit.Unit{unit.meter}));
    try testing.expectEqual(t1, Compose(&[_]unit.Unit{
        unit.meter,
        unit.second,
    }));
    try testing.expectEqual(
        Meter == Compose(&[_]unit.Unit{ unit.meter, unit.second }),
        false,
    );
    try testing.expectEqual(
        Meter == Compose(&[_]unit.Unit{ unit.meter, unit.meter }),
        false,
    );
    try testing.expectEqual(
        Compose(&[_]unit.Unit{
            unit.meter,
            unit.second,
        }) == Compose(&[_]unit.Unit{
            unit.meter,
            unit.meter,
        }),
        false,
    );
}

test "Extend" {
    const t1 = Compose(&[_]unit.Unit{ unit.meter, unit.second });
    const t2 = Compose(&[_]unit.Unit{unit.meter});
    const t3 = Extend(t2, &[_]unit.Unit{unit.second});
    const t4 = Extend(t2, &[_]unit.Unit{unit.meter});

    try testing.expectEqual(t1, t3);
    try testing.expectEqual(t1 == t4, false);

    const t5 = Extend(Kilogram, &[_]unit.Unit{
        unit.scale(unit.second, -2),
        unit.meter,
    });
    try testing.expectEqual(Newton, t5);

    const t6 = Extend(t5, &[_]unit.Unit{unit.scale(unit.second, 2)});
    try testing.expectEqual(Newton == t6, false);
}
