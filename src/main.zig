const std = @import("std");

pub const Bench = @import("./bench/Bench.zig");
pub const connection = @import("./Connection.zig");
pub const Extraction = @import("./Extraction.zig");
pub const QueryMetadata = @import("./metadata/QueryMetadata.zig");
pub const Options = @import("./Options.zig");
pub const Statement = @import("./statement/Statement.zig");
const t = @import("./testing/testing.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();
    // var conn = try t.getTestConnection(arena.allocator());
    // const bench = Bench{};
    // // Bench.table1_record_count = 2;
    // Bench.progress = true;
    // try bench.init_tables(&conn);
    // try conn.commit();
    // try conn.deinit();

    const allocator = arena.allocator();
    const params = try t.getTestConnectionParams();
    const output_dir = try std.fs.cwd().realpathAlloc(allocator, "./tmpdir");

    const sql = "SELECT * FROM sys.table1";

    const options = Options{
        .auth_mode = params.auth_mode,
        .connection_string = params.connection_string,
        .password = params.password,
        .username = params.username,
        .sql = sql,
        .output_dir = output_dir,
        .output_file = "output.csv",
        .csv_header = true,
        .fetch_size = 10_000,
        .batch_write_size = 10_000_000,
        .csv_quote_strings = true,
    };
    try options.validate();
    try Bench.run_extraction(allocator, options);
}

test {
    std.testing.refAllDecls(@This());
}
