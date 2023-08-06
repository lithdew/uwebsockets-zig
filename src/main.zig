const std = @import("std");
const c = @cImport({
    @cInclude("libusockets.h");
    @cInclude("libuwebsockets.h");
});

pub const Response = opaque {
    pub fn write(self: *Response, data: []const u8) bool {
        c.uws_res_write(0, @ptrCast(self), data.ptr, data.len);
    }

    pub fn writeHeader(self: *Response, key: []const u8, value: []const u8) void {
        c.uws_res_write_header(0, @ptrCast(self), key.ptr, key.len, value.ptr, value.len);
    }

    pub fn writeStatus(self: *Response, status: []const u8) void {
        c.uws_res_write_status(0, @ptrCast(self), status.ptr, status.len);
    }

    pub fn end(self: *Response, data: []const u8, close_connection: bool) void {
        c.uws_res_end(0, @ptrCast(self), data.ptr, data.len, close_connection);
    }

    pub fn endWithoutBody(self: *Response, close_connection: bool) void {
        c.uws_res_end_without_body(0, @ptrCast(self), close_connection);
    }
};

pub const App = opaque {
    pub fn init() !*App {
        const opts = std.mem.zeroes(c.us_socket_context_options_t);
        const app = c.uws_create_app(0, opts) orelse return error.OutOfMemory;
        return @ptrCast(app);
    }

    pub fn listen(self: *App, port: u16, user_data: anytype, comptime handler: fn(@TypeOf(user_data), ?*c.us_listen_socket_t) void) void {
        const Handler = struct {
            fn handle(s: ?*c.us_listen_socket_t, config: c.uws_app_listen_config_t, raw_user_data: ?*anyopaque) callconv(.C) void {
                _ = config;
                if (comptime @TypeOf(user_data) == void) {
                    handler({}, s);
                } else {
                    handler(@ptrCast(raw_user_data), s);
                }
            }
        };
        c.uws_app_listen(0, @ptrCast(self), @intCast(port), Handler.handle, @ptrCast(@alignCast(user_data)));
    }

    pub fn get(self: *App, pattern: [:0]const u8, user_data: anytype, comptime handler: fn(@TypeOf(user_data), *Response, *c.uws_req_t) void) void {
        const Handler = struct {
            fn handle(res: ?*c.uws_res_t, req: ?*c.uws_req_t, raw_user_data: ?*anyopaque) callconv(.C) void {
                if (comptime @TypeOf(user_data) == void) {
                    handler({}, @ptrCast(res.?), req.?);
                } else {
                    handler(@ptrCast(raw_user_data), @ptrCast(res.?), req.?);
                }
            }
        };
        c.uws_app_get(0, @ptrCast(self), pattern, Handler.handle, @ptrCast(@alignCast(user_data)));
    }

    pub fn run(self: *App) void{
        c.uws_app_run(0, @ptrCast(self));
    }
};

test "uws: basic app" {
    const Context = struct {
        fn get(_: *@This(), res: *Response, _: *c.uws_req_t) void {
            res.writeStatus("OK");
            res.writeHeader("Server", "uWebSockets-Zig");
            res.end("Hello Zig!", false);
        }

        fn listen(_: *@This(), s: ?*c.us_listen_socket_t) void {
            if (s != null) {
                const port = c.us_socket_local_port(0, @ptrCast(s));
                std.debug.print("\nListening on port http://localhost:{d} now\n", .{port});
            }
        }
    };

    var ctx: Context = .{};

    const app = try App.init();
    app.get("/*", &ctx, Context.get);
    app.listen(0, &ctx, Context.listen);
    app.run();
    

    // const opts = std.mem.zeroes(c.us_socket_context_options_t);

    // const Context = struct {
    //     fn get(res: ?*c.uws_res_t, req: ?*c.uws_req_t, user_data: ?*anyopaque) callconv(.C) void {
    //         _ = req;
    //         _ = user_data;

    //         const text = "Hello Zig!";
    //         c.uws_res_end(0, res, text, text.len, false);
    //     }

    //     fn listen(s: ?*c.us_listen_socket_t, config: c.uws_app_listen_config_t, user_data: ?*anyopaque) callconv(.C) void {
    //         _ = config;
    //         _ = user_data;
    //         if (s != null) {
    //             const port = c.us_socket_local_port(0, @ptrCast(s));
    //             std.debug.print("\nListening on port http://localhost:{d} now\n", .{port});
    //         }
    //     }
    // };
    

    // const app = c.uws_create_app(0, opts);
    // c.uws_app_get(0, app, "/*", Context.get, null);
    // c.uws_app_listen(0, app, 0, Context.listen, null);
    // c.uws_app_run(0, app);
}
