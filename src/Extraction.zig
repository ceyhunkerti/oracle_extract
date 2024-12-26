const std = @import("std");
const testing = std.testing;

const Connection = @import("Connection.zig");
const QueryMetadata = @import("metadata/QueryMetadata.zig");
const Options = @import("Options.zig");
const OutputBuffer = @import("OutputBuffer.zig");
const RowData = @import("RowData.zig");
const Statement = @import("Statement.zig");
const t = @import("testing/testing.zig");

const c = @cImport({
    @cInclude("dpi.h");
});

allocator: std.mem.Allocator,
options: Options,
conn: ?*Connection = null,
sql: []const u8,
qmd: QueryMetadata = undefined,
stmt: Statement = undefined,
output_buffer: OutputBuffer = undefined,

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

pub fn run(self: *Self) !u64 {
    var output_file = try self.outputFile();
    defer output_file.close();

    try self.execute();

    var output_buffer = try OutputBuffer.init(
        self.allocator,
        self.options.batch_write_size,
        output_file,
        self.options.csv_delimiter,
        self.options.csv_quote_strings,
    );

    if (self.options.csv_header) {
        const column_names = try self.qmd.columnNames();
        var header = try std.mem.join(self.allocator, self.options.csv_delimiter, column_names);
        header = try self.allocator.realloc(header, header.len + 1);
        header[header.len - 1] = '\n';
        _ = try output_file.write(header);
        self.allocator.free(header);
    }

    var rows: []RowData = undefined;
    try self.stmt.fetchRows(self.options.fetch_size, &rows);
    var total_rows: u64 = rows.len;
    try output_buffer.output(rows);
    self.allocator.free(rows);

    while (self.stmt.has_next) {
        try self.stmt.fetchRows(self.options.fetch_size, &rows);
        try output_buffer.output(rows);
        self.allocator.free(rows);
        total_rows += rows.len;
    }
    try output_buffer.flush();

    return total_rows;
}

pub fn run2(self: *Self) !u64 {
    var output_file = try self.outputFile();
    defer output_file.close();

    try self.execute();

    // var output_buffer = try OutputBuffer.init(
    //     self.allocator,
    //     self.options.batch_write_size,
    //     output_file,
    //     self.options.csv_delimiter,
    //     self.options.csv_quote_strings,
    // );

    if (self.options.csv_header) {
        const column_names = try self.qmd.columnNames();
        var header = try std.mem.join(self.allocator, self.options.csv_delimiter, column_names);
        header = try self.allocator.realloc(header, header.len + 1);
        header[header.len - 1] = '\n';
        _ = try output_file.write(header);
        self.allocator.free(header);
    }

    var bw = std.io.bufferedWriter(output_file.writer());

    var rows: [][][]const u8 = undefined;
    try self.stmt.fetchRowsAsString(self.options.fetch_size, &rows);
    for (rows) |row| {
        var x: usize = 0;
        for (row) |cell| {
            _ = try bw.write(cell);
            x += 1;
            if (x < row.len) {
                _ = try bw.write(",");
            }
        }
        _ = try bw.write("\n");
    }

    // var total_rows: u64 = rows.len;
    // try output_buffer.output(rows);
    self.allocator.free(rows);

    while (self.stmt.has_next) {
        try self.stmt.fetchRowsAsString(self.options.fetch_size, &rows);
        // try output_buffer.output(rows);

        for (rows) |row| {
            var x: usize = 0;
            for (row) |cell| {
                _ = try bw.write(cell);
                x += 1;
                if (x < row.len) {
                    _ = try bw.write(",");
                }
                _ = try bw.write(",");
                // _ = try bw.writer().print("{},", .{cell});
            }
            // _ = try bw.writer().print("\n", .{});
            // const line = try std.mem.join(self.allocator, ",", row);
            // _ = try bw.write(line);
            _ = try bw.write("\n");
        }
        self.allocator.free(rows);
        // total_rows += rows.len;
    }
    try bw.flush();
    // try output_buffer.flush();

    return 0;
}

pub fn outputFile(self: *Self) !std.fs.File {
    return try std.fs.createFileAbsolute(
        try std.fs.path.join(self.allocator, &.{
            self.options.output_dir,
            self.options.output_file,
        }),
        .{},
    );
}

pub fn writeCsvChunk(_: Self, file: std.fs.File, chunk: []u8) !void {
    _ = try file.write(chunk);
    _ = try file.write("\n");
}

test "Simple Extraction from query" {
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const allocator = arena.allocator();

    const params = try t.getTestConnectionParams();
    const output_dir = try std.fs.cwd().realpathAlloc(allocator, "./tmpdir");

    const options = Options{
        .auth_mode = params.auth_mode,
        .connection_string = params.connection_string,
        .password = params.password,
        .username = params.username,
        .sql = "SELECT 1 as A, 2 as B FROM DUAL",
        .output_dir = output_dir,
        .output_file = "output.csv",
    };

    var extraction = Self.init(allocator, options);
    const total_rows = try extraction.run();

    try testing.expectEqual(total_rows, 1);

    const fd = try std.fs.cwd().openFile("./tmpdir/output.csv", .{});
    defer fd.close();

    const expected = "1,2\n";
    const actual = try allocator.alloc(u8, expected.len);
    _ = try fd.readAll(actual);
    try testing.expectEqualSlices(u8, actual, expected);

    try std.fs.cwd().deleteFile("./tmpdir/output.csv");
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
    const output_dir = try std.fs.cwd().realpathAlloc(allocator, "./tmpdir");

    const options = Options{
        .auth_mode = params.auth_mode,
        .connection_string = params.connection_string,
        .password = params.password,
        .username = params.username,
        .sql = sql,
        .output_dir = output_dir,
        .output_file = "output.csv",
        .csv_header = true,
        .fetch_size = 1,
        .batch_write_size = 2,
        .csv_quote_strings = true,
    };
    try options.validate();

    var extraction = Self.init(allocator, options);
    const total_rows = try extraction.run();

    try testing.expectEqual(total_rows, 2);

    const fd = try std.fs.cwd().openFile("./tmpdir/output.csv", .{});
    defer fd.close();

    const expected =
        \\A,B,C,D,E,F
        \\1,2.1,"hello",2020-01-01T00:00:00,1.1,2020-01-01T00:00:00
        \\2,3.1,"world",2020-01-02T00:00:00,2.1,2020-01-02T00:00:00
    ;
    const actual = try allocator.alloc(u8, expected.len);
    _ = try fd.readAll(actual);
    try testing.expectEqualSlices(u8, actual, expected);

    try std.fs.cwd().deleteFile("./tmpdir/output.csv");
}
