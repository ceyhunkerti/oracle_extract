const std = @import("std");

const ColumnData = @import("./ColumnData.zig");

const Self = @This();

allocator: std.mem.Allocator,
columns: std.ArrayList(ColumnData),

pub fn init(allocator: std.mem.Allocator, column_count: usize) !Self {
    return Self{
        .allocator = allocator,
        .columns = try std.ArrayList(ColumnData).initCapacity(allocator, column_count),
    };
}
pub fn deinit(self: Self) void {
    for (self.columns.items) |col| {
        col.deinit();
    }
    self.columns.deinit();
}

pub fn columnCount(self: Self) usize {
    return self.columns.items.len;
}

pub fn columnValue(self: Self, index: usize) ColumnData.Value {
    return self.columns.items[index].value;
}

pub fn column(self: Self, index: usize) ColumnData {
    return self.columns.items[index];
}

pub fn addColumn(self: *Self, col: ColumnData) !void {
    try self.columns.append(col);
}

pub fn toCsvString(self: Self, csv_delimiter: []const u8, csv_quote_strings: bool) ![]u8 {
    var buffer = std.ArrayList([]u8).init(self.allocator);
    for (self.columns.items) |col| {
        const s = try col.serialize(csv_quote_strings);
        try buffer.append(s);
    }
    defer buffer.deinit();
    return std.mem.join(self.allocator, csv_delimiter, buffer.items);
}
