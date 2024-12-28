const std = @import("std");

const app = @import("argz");
const Command = app.Command;
const Option = app.Option;
const ValueType = app.ValueType;

const Extraction = @import("Extraction.zig");
const Options = @import("Options.zig");

fn getRunOptions(c: Command) !Options {
    var connection_string: []const u8 = undefined;
    var username: []const u8 = undefined;
    var password: []const u8 = undefined;
    var auth_mode: ?[]const u8 = null;
    var sql: []const u8 = undefined;
    var fetch_size: u32 = 1000;
    var output_file: []const u8 = undefined;
    var csv_header: bool = false;
    var csv_delimiter: []const u8 = ",";
    var csv_quote_strings: bool = false;

    if (c.getOption("connection-string")) |o| if (o.stringValue()) |v| {
        connection_string = v;
    };
    if (c.getOption("username")) |o| if (o.stringValue()) |v| {
        username = v;
    };
    if (c.getOption("password")) |o| if (o.stringValue()) |v| {
        password = v;
    };
    if (c.getOption("auth-mode")) |o| if (o.stringValue()) |v| {
        auth_mode = v;
    };
    if (c.getOption("sql")) |o| if (o.stringValue()) |v| {
        sql = v;
    };
    if (c.getOption("fetch-size")) |o| if (o.intValue()) |v| {
        fetch_size = @intCast(v);
    };
    if (c.getOption("output-file")) |o| if (o.stringValue()) |v| {
        output_file = v;
    };
    if (c.getOption("csv-header")) |o| if (o.boolValue()) |v| {
        csv_header = v;
    };
    if (c.getOption("csv-delimiter")) |o| if (o.stringValue()) |v| {
        csv_delimiter = v;
    };
    if (c.getOption("csv-quote-strings")) |o| if (o.boolValue()) |v| {
        csv_quote_strings = v;
    };

    return Options{
        .connection_string = connection_string,
        .username = username,
        .password = password,
        .auth_mode = auth_mode,
        .sql = sql,
        .fetch_size = fetch_size,
        .output_file = output_file,
        .csv_header = csv_header,
        .csv_delimiter = csv_delimiter,
        .csv_quote_strings = csv_quote_strings,
    };
}

fn run(c: *Command) anyerror!void {
    const options = try getRunOptions(c.*);
    var ext = Extraction.init(c.allocator, options);
    _ = try ext.run();
}

pub fn initCli(allocator: std.mem.Allocator) !Command {
    var root = Command.init(allocator, "ox");

    var run_cmd = Command.init(allocator, "run");
    run_cmd.run = run;

    try run_cmd.addOptions(&.{
        Option{
            .type = ValueType.string,
            .names = &.{"connection-string"},
            .default = "localhost:1521/ORCLCDB",
            .required = true,
        },
        Option{
            .type = ValueType.string,
            .names = &.{"username"},
            .required = true,
        },
        Option{
            .type = ValueType.string,
            .names = &.{"password"},
            .required = true,
        },
        Option{
            .type = ValueType.string,
            .names = &.{"auth-mode"},
            .required = false,
        },
        Option{
            .type = ValueType.string,
            .names = &.{"sql"},
            .required = true,
        },
        Option{
            .type = ValueType.int,
            .names = &.{"fetch-size"},
            .default = "10000",
        },
        Option{
            .type = ValueType.string,
            .names = &.{"output-file"},
            .required = true,
        },
        Option{
            .type = ValueType.boolean,
            .names = &.{"csv-header"},
            .default = "true",
        },
        Option{
            .type = ValueType.string,
            .names = &.{"csv-delimiter"},
            .default = ",",
        },
        Option{
            .type = ValueType.boolean,
            .names = &.{"csv-quote-strings"},
            .default = "false",
        },
    });

    try root.addCommand(run_cmd);

    return root;
}
