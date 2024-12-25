const std = @import("std");
const testing = std.testing;

const Statement = @import("../Statement.zig");
const t = @import("../testing/testing.zig");
const Column = @import("./Column.zig");

const Self = @This();

allocator: std.mem.Allocator,
stmt: *Statement,
columns: []Column,

pub fn init(allocator: std.mem.Allocator, stmt: *Statement) !Self {
    const md = Self{
        .allocator = allocator,
        .stmt = stmt,
        .columns = try allocator.alloc(Column, stmt.column_count),
    };
    var i: usize = 0;
    for (md.columns) |*column| {
        column.* = try Column.init(stmt, @intCast(i));
        i += 1;
    }
    return md;
}
pub fn deinit(self: Self) void {
    self.allocator.free(self.columns);
}
pub fn columnNames(self: Self) ![]const []const u8 {
    var names = try self.allocator.alloc([]const u8, self.columns.len);
    var i: usize = 0;
    for (self.columns) |column| {
        names[i] = column.name;
        i += 1;
    }
    return names;
}

test "init" {
    const allocator = std.testing.allocator;
    const sql = "select 1 as A, 2 as B from dual";

    const conn = try t.getTestConnection(testing.allocator);
    var stmt = Statement.init(conn, allocator);
    try stmt.prepare(sql);
    try stmt.execute();

    const md = try Self.init(allocator, &stmt);
    defer md.deinit();

    try testing.expectEqual(md.columns.len, 2);

    var i: usize = 0;
    for (md.columns) |column| {
        try testing.expect(column.name_length > 0);
        if (i == 0) {
            try testing.expectEqualStrings(column.name, "A");
        } else if (i == 1) {
            try testing.expectEqualStrings(column.name, "B");
        }
        i += 1;
    }

    const names = try md.columnNames();
    defer allocator.free(names);
    try testing.expectEqualStrings(names[0], "A");
    try testing.expectEqualStrings(names[1], "B");
}
