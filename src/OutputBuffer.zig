const std = @import("std");

const RowData = @import("RowData.zig");

const Self = @This();

size: u64,
rows: std.ArrayList(RowData),
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
        .rows = try std.ArrayList(RowData).initCapacity(allocator, size),
        .allocator = allocator,
        .output_file = output_file,
        .csv_delimiter = csv_delimiter,
        .csv_quote_strings = csv_quote_strings,
    };
}

pub fn output(self: *Self, rows: []RowData) !void {
    if (self.index + rows.len > self.size) {
        try self.flush();
    } else {
        // todo append slice
        for (try self.allocator.dupe(RowData, rows)) |row| {
            try self.rows.append(row);
            self.index += 1;
        }
    }
}

pub fn flush(self: *Self) !void {
    if (self.index > 0) {
        // todo output format
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
    var i: usize = 0;
    var buffer = try std.ArrayList([]u8).initCapacity(self.allocator, self.index);
    while (i < self.index) {
        const s = try self.rows.items[i].toCsvString(self.csv_delimiter, self.csv_quote_strings);
        try buffer.append(s);
        i += 1;
    }
    return try std.mem.join(self.allocator, "\n", buffer.items);
}

pub fn clear(self: *Self) void {
    self.index = 0;
    for (self.rows.items) |row| {
        row.deinit();
    }
    self.rows.clearRetainingCapacity();
}
