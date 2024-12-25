const std = @import("std");

const zdt = @import("zdt");

const Self = @This();
const c = @cImport({
    @cInclude("dpi.h");
});

pub const Value = union(enum) {
    String: []u8,
    Int: i64,
    Double: f64,
    TimeStamp: zdt.Datetime,
    Number: f64,
    Boolean: bool,
    Null: u1,

    pub fn dpiNativeTypeNum(self: Value) c.dpiNativeTypeNum {
        return switch (self) {
            .String => c.DPI_NATIVE_TYPE_BYTES,
            .Int => c.DPI_NATIVE_TYPE_INT64,
            .Double => c.DPI_NATIVE_TYPE_DOUBLE,
            .TimeStamp => c.DPI_NATIVE_TYPE_TIMESTAMP,
            .Number => c.DPI_NATIVE_TYPE_FLOAT,
            .Boolean => c.DPI_NATIVE_TYPE_BOOLEAN,
            .Null => c.DPI_NATIVE_TYPE_NULL,
        };
    }
};

native_type_num: c.dpiNativeTypeNum = undefined,
value: Value,
allocator: std.mem.Allocator,

pub fn serialize(self: Self, csv_quote_strings: bool) ![]u8 {
    return ser: switch (self.value) {
        .String => |s| {
            if (csv_quote_strings) {
                break :ser try std.fmt.allocPrint(self.allocator, "\"{s}\"", .{s});
            }
            break :ser try std.heap.page_allocator.dupe(u8, s);
        },
        .Int => |i| {
            break :ser try std.fmt.allocPrint(self.allocator, "{d}", .{i});
        },
        .Double => |d| {
            break :ser try std.fmt.allocPrint(self.allocator, "{d}", .{d});
        },
        .Number => |n| {
            break :ser try std.fmt.allocPrint(self.allocator, "{d}", .{n});
        },
        .TimeStamp => |t| {
            var buffer = std.ArrayList(u8).init(self.allocator);
            try t.toString(zdt.Formats.RFC3339, buffer.writer());
            break :ser buffer.items;
        },
        .Boolean => |b| {
            const tf = if (b) "true" else "false";
            break :ser try std.heap.page_allocator.dupe(u8, tf);
        },
        .Null => {
            break :ser "";
        },
    };
}

pub fn init(allocator: std.mem.Allocator, data: ?*c.dpiData, native_type_num: c.dpiNativeTypeNum) !Self {
    var value = Value{ .Null = 1 };

    switch (native_type_num) {
        c.DPI_NATIVE_TYPE_BYTES => {
            var bytes = c.dpiData_getBytes(data).*;
            const b = try allocator.dupe(u8, bytes.ptr[0..bytes.length]);
            value = Value{ .String = b };
        },
        c.DPI_NATIVE_TYPE_DOUBLE => {
            value = Value{ .Double = c.dpiData_getDouble(data) };
        },
        c.DPI_NATIVE_TYPE_INT64 => {
            value = Value{ .Int = c.dpiData_getInt64(data) };
        },
        c.DPI_NATIVE_TYPE_FLOAT => {
            value = Value{ .Number = c.dpiData_getFloat(data) };
        },
        c.DPI_NATIVE_TYPE_BOOLEAN => {
            value = Value{ .Boolean = c.dpiData_getBool(data) > 0 };
        },
        c.DPI_NATIVE_TYPE_TIMESTAMP => {
            const ts = c.dpiData_getTimestamp(data).*;
            const dt = zdt.Datetime{
                .day = ts.day,
                .hour = ts.hour,
                .minute = ts.minute,
                .second = ts.second,
                .month = ts.month,
                .year = @intCast(ts.year),
            };
            value = Value{ .TimeStamp = dt };
        },
        else => {
            std.debug.print("native_type_num: {d}\n", .{native_type_num});
            unreachable;
        },
    }

    return Self{ .native_type_num = native_type_num, .value = value, .allocator = allocator };
}

pub fn deinit(self: Self) void {
    switch (self.value) {
        .String => {
            self.allocator.free(self.value.String);
        },
        else => {},
    }
}
