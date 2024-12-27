const std = @import("std");

pub const bench = @import("./bench/bench.zig");
pub const connection = @import("./Connection.zig");
pub const Extraction = @import("./Extraction.zig");
pub const QueryMetadata = @import("./metadata/QueryMetadata.zig");
pub const Options = @import("./Options.zig");
pub const Statement = @import("./statement/Statement.zig");
const t = @import("./testing/testing.zig");

pub fn main() !void {
    try bench.run_benchmark_1();
}

test {
    std.testing.refAllDecls(@This());
}
