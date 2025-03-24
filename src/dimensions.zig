const fmt = @import("std").fmt;
const mem = @import("std").mem;

const dim = @import("./dimension.zig");

const testing = @import("std").testing;
const debug = @import("std").debug;

fn dimTypeCompileError(comptime T: type) void {
    @compileError("the supplied value was not a valid dimension specification. Got type " ++ @typeName(T) ++ " but must be one of:\na dimension type\nan array of dimension types\na multi-dimensional array of dimension types");
}

// Asserts that the supplyed value is a valid dimension or collection of
// dimensions. The input is considered valid if it is:
//  - a type that is a dimension
//  - a list of types that are all dimensions
//  - a multi-dimensional array of types that are all dimensions
pub fn assertAreDims(comptime T: anytype) void {
    topLevel: switch (@typeInfo(@TypeOf(T))) {
        .type => dim.assertIsDim(T),
        .array => |info| switch (@typeInfo(info.child)) {
            .type => {
                for (0..info.len) |i| {
                    dim.assertIsDim(T[i]);
                }
            },
            .array => {
                for (0..info.len) |i| {
                    assertAreDims(T[i]);
                }
            },
            else => continue :topLevel @typeInfo(@TypeOf(void)),
        },
        else => dimTypeCompileError(T),
    }
}

// Returns a dim collection filled entirely with the dimimension U
pub fn fill(comptime dimType: type, comptime _dim: type) dimType {
    switch (@typeInfo(dimType)) {
        .type => return _dim,
        .array => |info| switch (@typeInfo(info.child)) {
            .type => return [1]type{_dim} ** info.len,
            .array => {
                const row = fill(info.child, _dim);
                return [1]@TypeOf(row){row} ** info.len;
            },
            else => dimTypeCompileError(dimType),
        },
        else => dimTypeCompileError(dimType),
    }
}

// Takes the supplied collection of dimensions and flattens them out to a single
// slice of dimensions.
fn flattenDimsRowMajor(comptime T: anytype) []const type {
    comptime {
        topLevel: switch (@typeInfo(@TypeOf(T))) {
            .type => return &[1]type{T},
            .array => |info| switch (@typeInfo(info.child)) {
                .type => return &T,
                .array => {
                    var rv: []const type = &[0]type{};
                    for (0..info.len) |i| {
                        rv = rv ++ flattenDimsRowMajor(T[i]);
                    }
                    return rv;
                },
                else => continue :topLevel @typeInfo(@TypeOf(void)),
            },
            else => dimTypeCompileError(T),
        }
    }
}

// Formats the collection of dimensions following a row-major order
fn formatDimsRowMajor(comptime T: anytype) []const []const u8 {
    comptime {
        topLevel: switch (@typeInfo(@TypeOf(T))) {
            .type => return &[1][]const u8{dim.format(T)},
            .array => |info| switch (@typeInfo(info.child)) {
                .type => {
                    var rv: []const []const u8 = &[0][]const u8{};
                    for (0..info.len) |i| {
                        const iterComp = dim.format(T[i]);
                        const iterCompIdx = fmt.comptimePrint("[{}] ", .{i}) ++ iterComp;
                        rv = rv ++ [1][]const u8{iterCompIdx};
                    }
                    return rv;
                },
                .array => {
                    var rv: []const []const u8 = &[0][]const u8{};
                    for (0..info.len) |i| {
                        const iterVals = formatDimsRowMajor(T[i]);
                        for (0..iterVals.len) |j| {
                            const iterCompIdx = fmt.comptimePrint("[{}]", .{i}) ++ iterVals[j];
                            rv = rv ++ [1][]const u8{iterCompIdx};
                        }
                    }
                    return rv;
                },
                else => continue :topLevel @typeInfo(@TypeOf(void)),
            },
            else => dimTypeCompileError(T),
        }
    }
}

pub fn assertCanAdd(comptime l: anytype, comptime r: anytype) void {
    comptime {
        // Make sure we are actually dealing with dimensions
        assertAreDims(l);
        assertAreDims(r);

        const lDims = flattenDimsRowMajor(l);
        const rDims = flattenDimsRowMajor(r);
        if (lDims.len == rDims.len and mem.eql(type, lDims, rDims)) {
            return;
        }

        const strLDims = formatDimsRowMajor(l);
        const strRDims = formatDimsRowMajor(r);
        var errMessage: []const u8 = "Dimensions do not match\n";
        for (0..@max(strLDims.len, strRDims.len)) |i| {
            if (i < strLDims.len and i < strRDims.len and !mem.eql(u8, strLDims[i], strRDims[i])) {
                errMessage = errMessage ++ "-> ";
            } else if (i >= strLDims.len or i >= strRDims.len) {
                errMessage = errMessage ++ "-> ";
            } else {
                errMessage = errMessage ++ "   ";
            }

            if (i < strLDims.len) {
                errMessage = errMessage ++ fmt.comptimePrint("{s:<20}", .{strLDims[i]}) ++ "\t";
            } else {
                errMessage = errMessage ++ (" " ** 20) ++ "\t";
            }
            if (i < strRDims.len) {
                errMessage = errMessage ++ strRDims[i];
            }
            errMessage = errMessage ++ "\n";
        }

        @compileError(errMessage);
    }
}

test "assert are dims" {
    comptime assertAreDims(dim.Meter);
    comptime assertAreDims([1]type{dim.Meter});
    comptime assertAreDims([2]type{ dim.Meter, dim.Second });
    comptime assertAreDims([1][2]type{
        [2]type{ dim.Meter, dim.Second },
    });
    comptime assertAreDims([2][2]type{
        [2]type{ dim.Meter, dim.Second },
        [2]type{ dim.Joule, dim.Newton },
    });

    // Compile errors - wrong type given in type array/matrix
    // comptime assertAreDims(u8);
    // comptime assertAreDims([1]type{u8});
    // comptime assertAreDims([2]type{
    //     dim.Meter, @TypeOf(.{u8}),
    // });
    // comptime assertAreDims([1][2]type{
    //     [2]type{ dim.Meter, u8 },
    // });
    // comptime assertAreDims([2][2]type{
    //     [2]type{ dim.Meter, dim.Second },
    //     [2]type{ dim.Joule, bool },
    // });
}

test "fill" {
    const d1 = comptime fill(type, dim.Meter);
    try testing.expectEqual(d1, dim.Meter);

    const d2 = comptime fill([1]type, dim.Meter);
    try testing.expectEqual(d2, [1]type{dim.Meter});

    const d3 = comptime fill([2]type, dim.Meter);
    try testing.expectEqual(d3, [2]type{ dim.Meter, dim.Meter });

    const d4 = comptime fill([1][2]type, dim.Meter);
    try testing.expectEqual(d4, [1][2]type{
        [2]type{ dim.Meter, dim.Meter },
    });

    const d5 = comptime fill([2][2]type, dim.Meter);
    try testing.expectEqual(d5, [2][2]type{
        [2]type{ dim.Meter, dim.Meter },
        [2]type{ dim.Meter, dim.Meter },
    });
}

test "flatten dims row major" {
    const f1 = comptime flattenDimsRowMajor(dim.Meter);
    try testing.expectEqual(f1, &[1]type{dim.Meter});

    const f2 = comptime flattenDimsRowMajor([1]type{dim.Meter});
    try testing.expectEqual(f2, &[1]type{dim.Meter});

    const f3 = comptime flattenDimsRowMajor([2]type{ dim.Meter, dim.Second });
    try testing.expectEqual(f3, &[2]type{ dim.Meter, dim.Second });

    const f4 = comptime flattenDimsRowMajor([1][2]type{
        [2]type{ dim.Meter, dim.Second },
    });
    try testing.expectEqual(f4, &[2]type{ dim.Meter, dim.Second });

    const f5 = comptime flattenDimsRowMajor([2][2]type{
        [2]type{ dim.Meter, dim.Second },
        [2]type{ dim.Joule, dim.Newton },
    });
    try testing.expectEqual(f5, &[4]type{
        dim.Meter, dim.Second,
        dim.Joule, dim.Newton,
    });
}

test "format dims row major" {
    const s1 = comptime formatDimsRowMajor(dim.Meter);
    try testing.expectEqualSlices([]const u8, s1, &[_][]const u8{"m*10^1"});

    const s2 = comptime formatDimsRowMajor([1]type{dim.Meter});
    try testing.expectEqualSlices(
        []const u8,
        s2,
        &[_][]const u8{"[0] m*10^1"},
    );

    const s3 = comptime formatDimsRowMajor([2]type{ dim.Meter, dim.Second });
    try testing.expectEqualSlices(
        []const u8,
        s3,
        &[_][]const u8{ "[0] m*10^1", "[1] s*10^1" },
    );

    const s4 = comptime formatDimsRowMajor([1][2]type{
        [2]type{ dim.Meter, dim.Second },
    });
    try testing.expectEqualSlices(
        []const u8,
        s4,
        &[_][]const u8{ "[0][0] m*10^1", "[0][1] s*10^1" },
    );

    const s5 = comptime formatDimsRowMajor([2][2]type{
        [2]type{ dim.Meter, dim.Second },
        [2]type{ dim.Gram, dim.Ampere },
    });
    try testing.expectEqualSlices(
        []const u8,
        s5,
        &[_][]const u8{
            "[0][0] m*10^1",
            "[0][1] s*10^1",
            "[1][0] g*10^1",
            "[1][1] A*10^1",
        },
    );
}

test "can add" {
    comptime assertCanAdd(dim.Meter, dim.Meter);
    // comptime assertCanAdd(dim.Meter, dim.Second);
    comptime assertCanAdd([1]type{dim.Meter}, [1]type{dim.Meter});
    // comptime assertCanAdd([1]type{dim.Meter}, [1]type{dim.Second});
    comptime assertCanAdd(
        [2]type{ dim.Meter, dim.Second },
        [2]type{ dim.Meter, dim.Second },
    );
    // comptime assertCanAdd(
    //     [2]type{ dim.Meter, dim.Second },
    //     [2]type{ dim.Meter, dim.Joule },
    // );
    comptime assertCanAdd(
        [1][2]type{[2]type{ dim.Meter, dim.Second }},
        [1][2]type{[2]type{ dim.Meter, dim.Second }},
    );
    // comptime assertCanAdd(
    //     [1][2]type{[2]type{ dim.Meter, dim.Second }},
    //     [1][2]type{[2]type{ dim.Meter, dim.Joule }},
    // );
    comptime assertCanAdd(
        [2][2]type{
            [2]type{ dim.Meter, dim.Second },
            [2]type{ dim.Gram, dim.Ampere },
        },
        [2][2]type{
            [2]type{ dim.Meter, dim.Second },
            [2]type{ dim.Gram, dim.Ampere },
        },
    );
    // comptime assertCanAdd(
    //     [2][2]type{
    //         [2]type{ dim.Meter, dim.Second },
    //         [2]type{ dim.Gram, dim.Ampere },
    //     },
    //     [2][2]type{
    //         [2]type{ dim.Meter, dim.Second },
    //         [2]type{ dim.Joule, dim.Ampere },
    //     },
    // );

    comptime assertCanAdd(dim.Meter, [1]type{dim.Meter});
    // comptime assertCanAdd(dim.Meter, [2]type{ dim.Meter, dim.Second });
    // comptime assertCanAdd([2]type{ dim.Meter, dim.Second }, dim.Second);
}
