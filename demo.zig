const std = @import("std");

pub fn main() !void {
    std.debug.print("{d:0>2} {c}", .{ 1, 'x' });
}
