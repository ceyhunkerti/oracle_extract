const std = @import("std");

const Extraction = @import("../Extraction.zig");
const Options = @import("../Options.zig");
const t = @import("../testing/testing.zig");

pub fn run_benchmark_1() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    var arena = std.heap.ArenaAllocator.init(gpa.allocator());
    defer arena.deinit();

    const params = try t.getTestConnectionParams();

    const sql = "SELECT * FROM sys.table1";

    const options = Options{
        .auth_mode = params.auth_mode,
        .connection_string = params.connection_string,
        .password = params.password,
        .username = params.username,
        .sql = sql,
        .output_file = "tmpdir/benchmark_1.csv",
        .csv_header = true,
        .fetch_size = 10_000,
        .csv_quote_strings = true,
    };
    const allocator = arena.allocator();
    var extraction = Extraction.init(allocator, options);
    _ = try extraction.run();
}
