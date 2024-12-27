const std = @import("std");
const testing = std.testing;

const Connection = @import("../Connection.zig");
const QueryMetadata = @import("../metadata/QueryMetadata.zig");
const t = @import("../testing/testing.zig");
const BindValue = @import("./bind.zig").BindValue;

const Self = @This();
const c = @cImport({
    @cInclude("dpi.h");
});
const Error = error{
    PrepareStatementError,
    ExecuteStatementError,
    FetchStatementError,
    StatementConfigError,
    FailedToBindValueByPos,
};

stmt: ?*c.dpiStmt = undefined,
column_count: u32 = 0,
num_rows_fetched: u32 = 0,
sql: []const u8 = "",
found: c_int = 0,

conn: Connection,
allocator: std.mem.Allocator,

pub fn init(conn: Connection, allocator: std.mem.Allocator) Self {
    return Self{
        .stmt = null,
        .conn = conn,
        .allocator = allocator,
    };
}

pub fn setFetchSize(self: *Self, fetch_size: u32) !void {
    if (c.dpiStmt_setFetchArraySize(self.stmt, fetch_size) < 0) {
        std.debug.print("Failed to set fetch array size with error: {s}\n", .{self.conn.getErrorMessage()});
        return error.StatementConfigError;
    }
}

pub fn prepare(self: *Self, sql: []const u8) !void {
    self.sql = sql;
    if (c.dpiConn_prepareStmt(self.conn.handle, 0, self.sql.ptr, @intCast(self.sql.len), null, 0, &self.stmt) < 0) {
        std.debug.print("Failed to prepare statement with error: {s}\n", .{self.conn.getErrorMessage()});
        return error.PrepareStatementError;
    }
}

fn bindValue(value: BindValue, is_null: bool) c.dpiData {
    var data: c.dpiData = undefined;
    data.isNull = if (is_null) 1 else 0;

    switch (value) {
        .String => {
            data.value.asBytes.ptr = value.String.ptr;
            data.value.asBytes.length = @intCast(value.String.len);
        },
        .Double => {
            data.value.asDouble = value.Double;
        },
        .Int => {
            data.value.asInt64 = value.Int;
        },
        .Number => {
            data.value.asDouble = value.Number;
        },
        .Boolean => {
            data.value.asBoolean = if (value.Boolean) 1 else 0;
        },
        .Null => {
            data.isNull = 1;
        },
        .TimeStamp => {
            var ts: c.dpiTimestamp = undefined;
            ts.day = value.TimeStamp.day;
            ts.hour = value.TimeStamp.hour;
            ts.minute = value.TimeStamp.minute;
            ts.month = value.TimeStamp.month;
            ts.second = value.TimeStamp.second;
            ts.year = @intCast(value.TimeStamp.year);
            data.value.asTimestamp = ts;
        },
    }

    return data;
}

pub fn bindValueByPos(self: *Self, value: BindValue, is_null: bool, pos: u32) !void {
    const bind_value = bindValue(value, is_null);
    if (c.dpiStmt_bindValueByPos(self.stmt, pos, value.dpiNativeTypeNum(), @constCast(&bind_value)) < 0) {
        std.debug.print("Failed to bind value by pos with error: {s}\n", .{self.conn.getErrorMessage()});
        return error.FailedToBindValueByPos;
    }
}

pub fn execute(self: *Self) !void {
    if (c.dpiStmt_execute(self.stmt, c.DPI_MODE_EXEC_DEFAULT, &self.column_count) < 0) {
        std.debug.print("Failed to execute statement with error: {s}\n", .{self.conn.getErrorMessage()});
        return error.ExecuteStatementError;
    }
}

pub fn fetchRowsAsString(self: *Self, fetch_size: u32, rows: *[][][]const u8) !void {
    var buffer_row_index: u32 = 0;
    var native_type_num: c.dpiNativeTypeNum = 0;

    rows.* = try self.allocator.alloc([][]const u8, fetch_size);
    var i: usize = 0;

    while (true) {
        if (c.dpiStmt_fetch(self.stmt, &self.found, &buffer_row_index) < 0) {
            std.debug.print("Failed to fetch rows with error: {s}\n", .{self.conn.getErrorMessage()});
            return error.FetchStatementError;
        }
        if (self.found == 0) {
            break;
        }
        rows.*[i] = try self.allocator.alloc([]const u8, self.column_count);
        for (1..self.column_count + 1) |j| {
            var data: ?*c.dpiData = undefined;
            if (c.dpiStmt_getQueryValue(self.stmt, @intCast(j), &native_type_num, &data) < 0) {
                std.debug.print("Failed to get query value with error: {s}\n", .{self.conn.getErrorMessage()});
                return error.FetchStatementError;
            }
            var strval: []const u8 = undefined;
            switch (native_type_num) {
                c.DPI_NATIVE_TYPE_BYTES => {
                    var bytes = data.?.value.asBytes;
                    strval = bytes.ptr[0..bytes.length];
                },
                c.DPI_NATIVE_TYPE_DOUBLE => {
                    var buffer = std.ArrayList(u8).init(self.allocator);
                    try buffer.writer().print("{d}", .{data.?.value.asDouble});
                    strval = buffer.items;
                },
                c.DPI_NATIVE_TYPE_INT64 => {
                    var buffer = std.ArrayList(u8).init(self.allocator);
                    try buffer.writer().print("{d}", .{data.?.value.asInt64});
                    strval = buffer.items;
                },
                c.DPI_NATIVE_TYPE_FLOAT => {
                    var buffer = std.ArrayList(u8).init(self.allocator);
                    try buffer.writer().print("{d}", .{data.?.value.asDouble});
                    strval = buffer.items;
                },
                c.DPI_NATIVE_TYPE_BOOLEAN => {
                    const tf = if (data.?.value.asBoolean > 0) "true" else "false";
                    strval = try self.allocator.dupe(u8, tf);
                },
                c.DPI_NATIVE_TYPE_TIMESTAMP => {
                    const ts = data.?.value.asTimestamp;
                    var buffer = std.ArrayList(u8).init(self.allocator);
                    try buffer.writer().print("{d}-{d}-{d} {d}:{d}:{d}", .{ ts.year, ts.month, ts.day, ts.hour, ts.minute, ts.second });
                    strval = buffer.items;
                },
                else => {
                    std.debug.print("Failed to get query value with error: {s}\n", .{self.conn.getErrorMessage()});
                    return error.FetchStatementError;
                },
            }
            rows.*[i][j - 1] = strval;
        }
        i += 1;
    }
    if (i < fetch_size) {
        rows.* = try self.allocator.realloc(rows.*, i);
    }
}

pub fn queryMetadata(self: *Self) !QueryMetadata {
    return try QueryMetadata.init(self.allocator, self);
}

test "fetchRows single row" {
    // const allocator = std.testing.allocator;
    var arena = std.heap.ArenaAllocator.init(std.testing.allocator);
    defer arena.deinit();
    const sql =
        \\select
        \\1 as A, 2 as B, 'hello' as C, to_date('2020-01-01', 'yyyy-mm-dd') as D
        \\from dual
    ;
    var conn = t.getTestConnection(arena.allocator()) catch unreachable;

    var stmt = try conn.prepareStatement(sql);
    try stmt.execute();
    var rows: []RowData = undefined;
    try stmt.fetchRows(1, &rows);
    try testing.expectEqual(rows.len, 1);
    try testing.expectEqual(rows[0].columnCount(), 4);
    try testing.expectEqual(rows[0].columnValue(0).Double, 1);
    try testing.expectEqual(rows[0].columnValue(1).Double, 2);
    try testing.expectEqualSlices(u8, rows[0].columnValue(2).String, "hello");

    const s = try rows[0].column(3).serialize(false);
    try testing.expectEqualSlices(u8, s, "2020-01-01T00:00:00");
}
