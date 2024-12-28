const std = @import("std");

pub const bench = @import("./bench/bench.zig");
const cli = @import("./cli.zig");
pub const connection = @import("./Connection.zig");
pub const Extraction = @import("./Extraction.zig");
pub const QueryMetadata = @import("./metadata/QueryMetadata.zig");
pub const Options = @import("./Options.zig");
pub const Statement = @import("./statement/Statement.zig");
const t = @import("./testing/testing.zig");

pub fn main() !void {
    // try bench.run_benchmark_1();

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    const allocator = arena.allocator();

    var app = try cli.initCli(allocator);
    defer app.deinit();

    try app.parseAndStart();
}

test {
    std.testing.refAllDecls(@This());
}
