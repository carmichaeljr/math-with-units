const fs = @import("std").fs;
const mem = @import("std").mem;

const dim = @import("./dimension.zig");
const dims = @import("./dimensions.zig");
const quantity = @import("./quantity.zig");
const cpu = @import("./cpu.zig");

const testing = @import("std").testing;
const zbench = @import("zbench");

fn AddScalarsBenchmark() type {
    return struct {
        s1: quantity.Quantity(u64, dim.Meter),
        s2: quantity.Quantity(u64, dim.Meter),

        fn init() @This() {
            return .{
                .s1 = quantity.Meter(u64, 3),
                .s2 = quantity.Meter(u64, 5),
            };
        }

        pub fn run(self: @This(), _: mem.Allocator) void {
            const s3 = cpu.add(self.s1, self.s2);
            _ = s3;
        }
    };
}

fn AddVectorBenchmark(comptime len: u64) type {
    return struct {
        v1: quantity.Quantity([len]u64, dims.fill([len]type, dim.Meter)),
        v2: quantity.Quantity([len]u64, dims.fill([len]type, dim.Meter)),

        fn init() @This() {
            var vals1: [len]u64 = undefined;
            var vals2: [len]u64 = undefined;
            for (0..len) |i| {
                vals1[i] = i;
                vals2[i] = i + len;
            }

            return .{
                .v1 = quantity.Meter([len]u64, vals1),
                .v2 = quantity.Meter([len]u64, vals2),
            };
        }

        pub fn run(self: @This(), _: mem.Allocator) void {
            const v3 = cpu.add(self.v1, self.v2);
            _ = v3;
        }
    };
}

test "bench add" {
    var tmp = try fs.cwd().createFile(
        "junk_file2.txt",
        .{ .read = true },
    );
    defer tmp.close();

    const stdout = tmp.writer();

    var bench = zbench.Benchmark.init(testing.allocator, .{});
    defer bench.deinit();

    try bench.addParam("scalar add", &AddScalarsBenchmark().init(), .{});
    try bench.addParam("vector add 4", &AddVectorBenchmark(4).init(), .{});
    try bench.addParam("vector add 8", &AddVectorBenchmark(8).init(), .{});
    try bench.addParam("vector add 16", &AddVectorBenchmark(16).init(), .{});
    try bench.addParam("vector add 32", &AddVectorBenchmark(32).init(), .{});
    try bench.addParam("vector add 64", &AddVectorBenchmark(64).init(), .{});
    try bench.addParam("vector add 128", &AddVectorBenchmark(128).init(), .{});

    try bench.run(stdout);
}
