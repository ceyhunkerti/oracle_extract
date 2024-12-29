const std = @import("std");
const testing = std.testing;

pub const Statement = @import("statement/Statement.zig");
const t = @import("testing/testing.zig");

const c = @cImport({
    @cInclude("dpi.h");
});

const Self = @This();

handle: ?*c.dpiConn = null,
dpiContext: ?*c.dpiContext = null,
allocator: std.mem.Allocator,

const ConnectionError = error{
    MissingEnvVar_DPI_MAJOR_VERSION,
    MissingEnvVar_DPI_MINOR_VERSION,
    FailedToCreateContext,
    FailedToReleaseConnection,
    FailedToDestroyContext,
    FailedToInitializeConnCreateParams,
    FailedToCommit,
    FailedToRollback,
};

pub fn init(allocator: std.mem.Allocator) Self {
    return Self{
        .handle = null,
        .dpiContext = null,
        .allocator = allocator,
    };
}

pub fn create_context(self: *Self) !void {
    if (self.dpiContext != null) {
        return;
    }
    var errorInfo: c.dpiErrorInfo = undefined;
    if (c.dpiContext_createWithParams(c.DPI_MAJOR_VERSION, c.DPI_MINOR_VERSION, null, &self.dpiContext, &errorInfo) < 0) {
        std.debug.print("Failed to create context with error: {s}\n", .{errorInfo.message});
        return error.FailedToCreateContext;
    }
}

pub fn deinit(self: *Self) !void {
    if (self.handle != null) {
        if (c.dpiConn_release(self.handle) < 0) {
            std.debug.print("Failed to release connection: {s}\n", .{self.getErrorMessage()});
            return error.FailedToReleaseConnection;
        }
    }
}

fn connCreateParams(self: *Self, auth_mode_int: u32) !c.dpiConnCreateParams {
    var conn_create_params: c.dpiConnCreateParams = undefined;
    if (c.dpiContext_initConnCreateParams(self.dpiContext, &conn_create_params) < 0) {
        std.debug.print("Failed to initialize connection create params\n", .{});
        return error.FailedToInitializeConnCreateParams;
    }
    conn_create_params.authMode = auth_mode_int;

    return conn_create_params;
}

pub fn connect(
    self: *Self,
    username: []const u8,
    password: []const u8,
    connection_string: []const u8,
    auth_mode_int: u32,
) !void {
    try self.create_context();

    var conn_create_params = try self.connCreateParams(auth_mode_int);

    if (c.dpiConn_create(
        self.dpiContext,
        username.ptr,
        @intCast(username.len),
        password.ptr,
        @intCast(password.len),
        connection_string.ptr,
        @intCast(connection_string.len),
        null,
        &conn_create_params,
        &self.handle,
    ) < 0) {
        std.debug.print("Failed to create connection with error: {s}\n", .{self.getErrorMessage()});
        return error.FailedToCreateConnection;
    }
}

pub fn createStatement(self: *Self) Statement {
    return Statement.init(self.allocator, self.*);
}

pub fn prepareStatement(self: *Self, sql: []const u8) !Statement {
    var stmt = self.createStatement();
    try stmt.prepare(sql);
    return stmt;
}

pub fn commit(self: *Self) !void {
    if (c.dpiConn_commit(self.handle) < 0) {
        std.debug.print("Failed to commit with error: {s}\n", .{self.getErrorMessage()});
        return error.FailedToCommit;
    }
}
pub fn rollback(self: *Self) !void {
    if (c.dpiConn_rollback(self.handle) < 0) {
        std.debug.print("Failed to rollback with error: {s}\n", .{self.getErrorMessage()});
        return error.FailedToRollback;
    }
}

pub fn getErrorMessage(self: *Self) []const u8 {
    var errorInfo: c.dpiErrorInfo = undefined;
    c.dpiContext_getError(self.dpiContext, &errorInfo);
    return std.mem.span(errorInfo.message);
}

test "create context" {
    const allocator = std.testing.allocator;
    var connection = Self.init(allocator);
    try connection.create_context();
}

test "connect" {
    var conn = try t.getTestConnection(testing.allocator);
    try conn.deinit();
}

test {
    std.testing.refAllDecls(@This());
}
