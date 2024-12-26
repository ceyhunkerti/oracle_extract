const std = @import("std");

const RowData = @import("RowData.zig");

const Self = @This();

size: u64,
rows: std.ArrayList([]u8),
allocator: std.mem.Allocator,
index: usize = 0,
output_file: std.fs.File = undefined,
csv_delimiter: []const u8 = ",",
csv_quote_strings: bool = false,

pub fn init(
    allocator: std.mem.Allocator,
    size: usize,
    output_file: std.fs.File,
    csv_delimiter: []const u8,
    csv_quote_strings: bool,
) !Self {
    return Self{
        .size = size,
        .rows = try std.ArrayList([]u8).initCapacity(allocator, size),
        .allocator = allocator,
        .output_file = output_file,
        .csv_delimiter = csv_delimiter,
        .csv_quote_strings = csv_quote_strings,
    };
}

pub fn output(self: *Self, rows: []RowData) !void {
    if (self.index + rows.len > self.size) {
        try self.flush();
    }
    // todo append slice
    for (rows) |row| {
        try self.rows.append(try row.toCsvString(self.csv_delimiter, self.csv_quote_strings));
        self.index += 1;
    }
}

pub fn flush(self: *Self) !void {
    if (self.index > 0) {
        try self.writeCsv();
        self.clear();
    }
}

pub fn writeCsv(self: *Self) !void {
    const buffer = try self.toCsvStringBuffer();
    _ = try self.output_file.write(buffer);
    _ = try self.output_file.write("\n");
    self.allocator.free(buffer);
}

pub fn toCsvStringBuffer(self: *Self) ![]u8 {
    return try std.mem.join(self.allocator, "\n", self.rows.items[0..self.index]);
}

pub fn clear(self: *Self) void {
    self.index = 0;
    self.rows.clearRetainingCapacity();
}
