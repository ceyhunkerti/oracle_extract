const std = @import("std");
const testing = std.testing;

const Connection = @import("Connection.zig");
const QueryMetadata = @import("metadata/QueryMetadata.zig");
const Options = @import("Options.zig");
const Statement = @import("statement/Statement.zig");
const t = @import("testing/testing.zig");
const writer = @import("writer.zig");

const c = @cImport({
    @cInclude("dpi.h");
});

allocator: std.mem.Allocator,
options: Options,
conn: ?*Connection = null,
qmd: QueryMetadata = undefined,
stmt: Statement = undefined,
sql: []const u8,

const Self = @This();

pub fn init(allocator: std.mem.Allocator, options: Options) Self {
    return Self{
        .options = options,
        .conn = null,
        .sql = options.sql,
        .allocator = allocator,
    };
}

fn connect(self: *Self) !void {
    var conn = Connection.init(self.allocator);
    self.conn = &conn;
    try self.conn.?.connect(
        self.options.username,
        self.options.password,
        self.options.connection_string,
        self.options.authModeInt(),
    );
}

fn execute(self: *Self) !void {
    try self.connect();
    self.stmt = try self.conn.?.prepareStatement(self.sql);
    try self.stmt.setFetchSize(self.options.fetch_size);
    try self.stmt.execute();
    self.qmd = try self.stmt.queryMetadata();
}

fn writeHeader(self: Self, bw: anytype) !void {
    const column_names = try self.qmd.columnNames();
    var header = try std.mem.join(self.allocator, self.options.csv_delimiter, column_names);
    header = try self.allocator.realloc(header, header.len + 1);
    header[header.len - 1] = '\n';
    _ = try bw.write(header);
    self.allocator.free(header);
}

inline fn writeRows(bw: anytype, rows: [][][]const u8, delimiter: []const u8) !void {
    for (rows) |row| {
        for (row, 0..) |cell, cell_index| {
            _ = try bw.write(cell);
            if (cell_index < row.len - 1) {
                // do not write delimiter for last cell
                _ = try bw.write(delimiter);
            }
        }
        _ = try bw.write("\n");
    }
}

fn outputFile(self: *Self) !std.fs.File {
    // method reserved for future use to support options in file name.

    if (!std.mem.startsWith(u8, self.options.output_file, "/")) {
        return try std.fs.cwd().createFile(self.options.output_file, .{});
    }
    return try std.fs.createFileAbsolute(self.options.output_file, .{});
}

pub fn run(self: *Self) !u64 {
    var outfile = try self.outputFile();
    var bw = writer.bufferedWriter(outfile.writer());
    defer outfile.close();

    try self.execute();

    if (self.options.csv_header) {
        try self.writeHeader(&bw);
    }

    const serialization_options = self.options.serializationOptions();
    var total_rows: u64 = 0;
    var rows: [][][]const u8 = undefined;
    while (true) {
        try self.stmt.fetchRowsAsString(&rows, serialization_options);
        if (rows.len == 0) {
            break;
        }
        total_rows += rows.len;
        try writeRows(&bw, rows, self.options.csv_delimiter);
        self.allocator.free(rows);
    }
    try bw.flush();
    return total_rows;
}

test "Simple Extraction from query" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const params = try t.getTestConnectionParams();

    const options = Options{
        .auth_mode = params.auth_mode,
        .connection_string = params.connection_string,
        .password = params.password,
        .username = params.username,
        .sql = "SELECT 1 as A, 2 as B FROM DUAL",
        .output_file = "tmpdir/output.csv",
    };

    var extraction = Self.init(allocator, options);
    const total_rows = try extraction.run();

    try testing.expectEqual(total_rows, 1);

    const fd = try std.fs.cwd().openFile(options.output_file, .{});
    defer fd.close();

    const expected = "1,2\n";
    const actual = try allocator.alloc(u8, expected.len);
    _ = try fd.readAll(actual);
    try testing.expectEqualSlices(u8, actual, expected);

    try std.fs.cwd().deleteFile(options.output_file);
}

test "All data types extraction" {
    const sql =
        \\select * from (
        \\select
        \\cast(1  as number) as A,
        \\cast(2.1 as number) as B,
        \\cast('hello' as varchar2(5)) as C,
        \\to_date('2020-01-01', 'yyyy-mm-dd') as D,
        \\cast(1.1 as float) as E,
        \\to_timestamp('2020-01-01 00:00:00', 'yyyy-mm-dd hh24:mi:ss') as F
        \\from dual
        \\union all
        \\select
        \\cast(2 as number) as A,
        \\cast(3.1 as number) as B,
        \\cast('world' as varchar2(5)) as C,
        \\to_date('2020-01-02', 'yyyy-mm-dd') as D,
        \\cast(2.1 as float) as E,
        \\to_timestamp('2020-01-02 00:00:00', 'yyyy-mm-dd hh24:mi:ss') as F
        \\from dual
        \\) order by A
    ;

    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const params = try t.getTestConnectionParams();

    const options = Options{
        .auth_mode = params.auth_mode,
        .connection_string = params.connection_string,
        .password = params.password,
        .username = params.username,
        .sql = sql,
        .output_file = "tmpdir/output.csv",
        .csv_header = true,
        .fetch_size = 1,
        .csv_quote_strings = true,
    };

    var extraction = Self.init(allocator, options);
    const total_rows = try extraction.run();

    try testing.expectEqual(total_rows, 2);

    const fd = try std.fs.cwd().openFile(options.output_file, .{});
    defer fd.close();

    const expected =
        \\A,B,C,D,E,F
        \\1,2.1,"hello",2020-1-1 0:0:0,1.1,2020-1-1 0:0:0
        \\2,3.1,"world",2020-1-2 0:0:0,2.1,2020-1-2 0:0:0
    ;
    const actual = try allocator.alloc(u8, expected.len);
    _ = try fd.readAll(actual);
    try testing.expectEqualSlices(u8, actual[0..expected.len], expected);

    try std.fs.cwd().deleteFile("tmpdir/output.csv");
}
