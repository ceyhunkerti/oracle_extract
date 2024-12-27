const std = @import("std");

const Statement = @import("../statement/Statement.zig");

const c = @cImport({
    @cInclude("dpi.h");
});

const Self = @This();
const Error = error{
    FailedToGetQueryInfo,
};

name: []const u8,
name_length: u32,
column_index: u32,
null_ok: bool,
type_info: c.dpiDataTypeInfo,

pub fn init(stmt: *Statement, column_index: u32) !Self {
    var query_info: c.dpiQueryInfo = undefined;

    if (c.dpiStmt_getQueryInfo(stmt.stmt, column_index + 1, &query_info) < 0) {
        std.debug.print("Failed to get query info with error: {s}\n", .{stmt.conn.getErrorMessage()});
        return error.FailedToGetQueryInfo;
    }
    return Self{
        .column_index = column_index,
        .name = std.mem.span(query_info.name),
        .name_length = query_info.nameLength,
        .null_ok = query_info.nullOk > 0,
        .type_info = query_info.typeInfo,
    };
}
