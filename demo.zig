const std = @import("std");

pub fn main() !void {
    var strval: []const u8 = undefined;
    strval = "";
    std.debug.print("{s}", .{strval});
}
