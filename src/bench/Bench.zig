const std = @import("std");
const testing = std.testing;

const Connection = @import("../Connection.zig");
const Extraction = @import("../Extraction.zig");
const Options = @import("../Options.zig");
const BindValue = @import("../statement/bind.zig").BindValue;
const t = @import("../testing/testing.zig");

const Self = @This();
const c = @cImport({
    @cInclude("dpi.h");
});

pub var table1_record_count: u64 = 10_000_000;
pub var progress: bool = false;

fn loadTable1(conn: *Connection) anyerror!void {
    const sql =
        \\insert into table1 (A, B, C, D, E)
        \\values (
        \\  :1,
        \\  :2,
        \\  :3,
        \\  to_date('2000-01-01', 'yyyy-mm-dd') + mod(:1, 1000),
        \\  to_timestamp('2001-01-01 00:00:00', 'yyyy-mm-dd hh24:mi:ss') + mod(:1, 1000)
        \\)
    ;
    var stmt = try conn.prepareStatement(sql);

    for (0..table1_record_count) |i| {
        const v1 = BindValue{ .Int = @intCast(i) };
        const v2 = BindValue{ .String = try std.fmt.allocPrint(conn.allocator, "hello_{d}", .{i}) };
        const v3 = BindValue{ .String = @constCast("a") };
        try stmt.bindValueByPos(v1, false, 1);

        try stmt.bindValueByPos(v2, false, 2);
        try stmt.bindValueByPos(v3, false, 3);
        _ = try stmt.execute();
        if (progress) {
            if (i % 100_000 == 0) std.debug.print("Loaded row {d}\n", .{i});
        }
    }
    if (progress) std.debug.print("Loaded {d} rows\n", .{table1_record_count});
}

pub const Table = struct {
    table_name: []const u8,
    create_sql: []const u8,
    load_fn: *const fn (*Connection) anyerror!void,

    pub fn init(
        table_name: []const u8,
        create_sql: []const u8,
        load_fn: *const fn (*Connection) anyerror!void,
    ) Table {
        return Table{
            .table_name = table_name,
            .create_sql = create_sql,
            .load_fn = load_fn,
        };
    }

    pub fn create_and_load(self: Table, conn: *Connection) !void {
        try self.create(conn);
        _ = try self.load(conn);
    }

    pub fn create(self: Table, conn: *Connection) !void {
        var stmt = try conn.prepareStatement(self.create_sql);
        stmt.execute() catch |err| {
            if (std.mem.containsAtLeast(u8, stmt.conn.getErrorMessage(), 1, "ORA-00955")) {
                std.debug.print("Table {s} already exists dropping and recreating...\n", .{self.table_name});
                try self.drop(conn);
                try self.create(conn);
            } else {
                return err;
            }
        };
    }

    pub fn drop(self: Table, conn: *Connection) !void {
        const sql = try std.fmt.allocPrint(conn.allocator, "DROP TABLE {s}", .{self.table_name});
        defer conn.allocator.free(sql);

        var stmt = try conn.prepareStatement(sql);
        _ = try stmt.execute();
    }

    pub fn load(self: Table, conn: *Connection) !void {
        return try self.load_fn(conn);
    }
};

tables: [1]Table = [_]Table{
    Table.init(
        "table1",
        \\CREATE TABLE table1 (
        \\  A number,
        \\  B varchar2(1000),
        \\  C char(1),
        \\  D date,
        \\  E timestamp
        \\)
    ,
        loadTable1,
    ),
},

pub fn run(self: Self, conn: *Connection) anyerror!void {
    for (self.tables) |table| {
        try table.create_and_load(conn);
        // todo
        try table.drop(conn);
    }
}

pub fn init_tables(self: Self, conn: *Connection) !void {
    for (self.tables) |table| {
        try table.create_and_load(conn);
    }
}
pub fn load_tables(self: Self, conn: *Connection) !void {
    for (self.tables) |table| {
        try table.load(conn);
    }
}
pub fn drop_tables(self: Self, conn: *Connection) !void {
    for (self.tables) |table| {
        try table.drop(conn);
    }
}

pub fn run_extraction(allocator: std.mem.Allocator, options: Options) !void {
    var extraction = Extraction.init(allocator, options);
    _ = try extraction.run2();
}
