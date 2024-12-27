const std = @import("std");
const testing = std.testing;

const Connection = @import("../Connection.zig");
const BindValue = @import("../statement/bind.zig").BindValue;
const t = @import("../testing/testing.zig");

const Self = @This();
const c = @cImport({
    @cInclude("dpi.h");
});

allocator: std.mem.Allocator = undefined,
conn: *Connection = undefined,
table_name: []const u8 = "",
create_sql: []const u8 = "",
insert_sql: []const u8 = "",
bind_index: bool = false,
record_count: u64 = 0,
progress: u32 = 0,

pub fn init(
    allocator: std.mem.Allocator,
    conn: *Connection,
    table_name: []const u8,
    create_sql: []const u8,
    insert_sql: []const u8,
    bind_index: bool,
    record_count: u64,
    progress: u32,
) Self {
    return Self{
        .allocator = allocator,
        .conn = conn,
        .table_name = table_name,
        .create_sql = create_sql,
        .insert_sql = insert_sql,
        .bind_index = bind_index,
        .record_count = record_count,
        .progress = progress,
    };
}

pub fn create(self: Self) !void {
    var stmt = try self.conn.prepareStatement(self.create_sql);
    stmt.execute() catch |err| {
        if (std.mem.containsAtLeast(u8, stmt.conn.getErrorMessage(), 1, "ORA-00955")) {
            std.debug.print("Table {s} already exists dropping and recreating...\n", .{self.table_name});
            try self.drop();
            try self.create();
        } else {
            return err;
        }
    };
}

pub fn drop(self: Self) !void {
    const sql = try std.fmt.allocPrint(self.allocator, "DROP TABLE {s}", .{self.table_name});
    defer self.allocator.free(sql);
    var stmt = try self.conn.prepareStatement(sql);
    _ = try stmt.execute();
}

pub fn load(self: Self) anyerror!void {
    var stmt = try self.conn.prepareStatement(self.insert_sql);

    for (0..self.record_count) |i| {
        if (self.bind_index) {
            const bv = BindValue{ .Int = @intCast(i) };
            try stmt.bindValueByPos(bv, false, 1);
        }
        _ = try stmt.execute();
        if (self.progress > 0) {
            if (i % self.progress == 0) std.debug.print("Loaded row {d}\n", .{i});
        }
    }
    std.debug.print("Loaded {d} rows\n", .{self.record_count});
}
