const std = @import("std");

const c = @cImport({
    @cInclude("dpi.h");
});
const Self = @This();

connection_string: []const u8,
username: []const u8,
password: []const u8,
auth_mode: ?[]const u8 = null,
sql: []const u8,
fetch_size: u32 = 1000,

output_file: []const u8 = "./output.dat",
parallel: ?u8 = 1,
parallelization_column: ?[]const u8 = null,
parallelization_chunking_method: ?[]const u8 = null,

// csv options
csv_header: bool = false,
csv_delimiter: []const u8 = ",",
csv_quote_strings: bool = false,

pub fn authModeInt(self: Self) u32 {
    var auth_mode_int = @as(u32, c.DPI_MODE_AUTH_DEFAULT);
    if (self.auth_mode != null) {
        if (std.mem.eql(u8, self.auth_mode.?, "SYSDBA")) {
            auth_mode_int = @as(u32, c.DPI_MODE_AUTH_SYSDBA);
        } else if (std.mem.eql(u8, self.auth_mode.?, "SYSOPER")) {
            auth_mode_int = @as(u32, c.DPI_MODE_AUTH_SYSOPER);
        }
    }
    return auth_mode_int;
}
