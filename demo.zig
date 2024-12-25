const std = @import("std");

pub fn main() !void {
    var file = try std.fs.cwd().openFile(
        "/home/ceyhun/projects/oracle_extract/.uncommitted/demo.txt",
        .{ .mode = .read_only },
    );
    defer file.close();
    const allocator = std.heap.page_allocator;
    const file_size = try file.getEndPos();
    const buffer = try allocator.alloc(u8, file_size);
    defer allocator.free(buffer);
    _ = try file.readAll(buffer);
    std.debug.print("{s}", .{buffer});
}
