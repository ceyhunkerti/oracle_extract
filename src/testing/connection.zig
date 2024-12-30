const std = @import("std");

const c = @import("../c.zig").c;
const Connection = @import("../Connection.zig");

const TestConnectionError = error{MissingTestEnvironmentVariable};

pub const TestConnectionParams = struct {
    username: []const u8,
    password: []const u8,
    connection_string: []const u8,
    auth_mode: []const u8,

    pub fn init(
        username: []const u8,
        password: []const u8,
        connection_string: []const u8,
        auth_mode: []const u8,
    ) TestConnectionParams {
        return .{
            .username = username,
            .password = password,
            .connection_string = connection_string,
            .auth_mode = auth_mode,
        };
    }
};

pub fn getTestConnectionParams() !TestConnectionParams {
    const username = std.posix.getenv("ORACLE_TEST_USERNAME") orelse {
        std.debug.print("Missing ORACLE_TEST_USERNAME environment variable\n", .{});
        return TestConnectionError.MissingTestEnvironmentVariable;
    };
    const password = std.posix.getenv("ORACLE_TEST_PASSWORD") orelse {
        std.debug.print("Missing ORACLE_TEST_PASSWORD environment variable\n", .{});
        return TestConnectionError.MissingTestEnvironmentVariable;
    };
    const connection_string = std.posix.getenv("ORACLE_TEST_CONNECTION_STRING") orelse {
        std.debug.print("Missing ORACLE_TEST_CONNECTION_STRING environment variable\n", .{});
        return TestConnectionError.MissingTestEnvironmentVariable;
    };
    const auth_mode = std.posix.getenv("ORACLE_TEST_AUTH_MODE") orelse {
        std.debug.print("Missing ORACLE_TEST_AUTH_MODE environment variable\n", .{});
        return TestConnectionError.MissingTestEnvironmentVariable;
    };

    return TestConnectionParams.init(username, password, connection_string, auth_mode);
}

pub fn getTestConnection(allocator: std.mem.Allocator) !Connection {
    const params = try getTestConnectionParams();
    var connection = Connection.init(allocator);

    try connection.create_context();
    try connection.connect(
        params.username,
        params.password,
        params.connection_string,
        @intCast(c.DPI_MODE_AUTH_SYSDBA),
    );
    return connection;
}
