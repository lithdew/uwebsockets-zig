const std = @import("std");
const c = @cImport({
    @cInclude("libusockets.h");
    @cInclude("libuwebsockets.h");
});

pub const Response = opaque {
    pub fn write(self: *Response, data: []const u8) bool {
        return c.uws_res_write(0, @ptrCast(self), data.ptr, data.len);
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

    pub fn getRemoteAddress(self: *Response) []const u8 {
        var ptr: [*c]const u8 = undefined;
        return ptr[0..c.uws_res_get_remote_address(0, @ptrCast(self), &ptr)];
    }

    pub fn getRemoteAddressAsText(self: *Response) []const u8 {
        var ptr: [*c]const u8 = undefined;
        return ptr[0..c.uws_res_get_remote_address_as_text(0, @ptrCast(self), &ptr)];
    }
};

pub const Request = opaque {
    pub fn url(self: *Request) []const u8 {
        var ptr: [*]const u8 = undefined;
        return ptr[0..c.uws_req_get_url(@ptrCast(self), &ptr)];
    }

    pub fn fullUrl(self: *Request) []const u8 {
        var ptr: [*c]const u8 = undefined;
        return ptr[0..c.uws_req_get_full_url(@ptrCast(self), &ptr)];
    }

    pub fn method(self: *Request) []const u8 {
        var ptr: [*c]const u8 = undefined;
        return ptr[0..c.uws_req_get_method(@ptrCast(self), &ptr)];
    }

    pub fn caseSensitiveMethod(self: *Request) []const u8 {
        var ptr: [*c]const u8 = undefined;
        return ptr[0..c.uws_req_get_case_sensitive_method(@ptrCast(self), &ptr)];
    }

    pub fn query(self: *Request, key: []const u8) []const u8 {
        var ptr: [*c]const u8 = undefined;
        return ptr[0..c.uws_req_get_query(@ptrCast(self), key.ptr, key.len, &ptr)];
    }

    pub fn param(self: *Request, index: u16) []const u8 {
        var ptr: [*c]const u8 = undefined;
        return ptr[0..c.uws_req_get_param(@ptrCast(self), index, &ptr)];
    }

    pub fn header(self: *Request, lower_cased_header_name: []const u8) []const u8 {
        var ptr: [*c]const u8 = undefined;
        return ptr[0..c.uws_req_get_header(
            @ptrCast(self),
            lower_cased_header_name.ptr,
            lower_cased_header_name.len,
            &ptr,
        )];
    }
};

pub const App = opaque {
    pub fn init() !*App {
        const opts = std.mem.zeroes(c.us_socket_context_options_t);
        const app = c.uws_create_app(0, opts) orelse return error.OutOfMemory;
        return @ptrCast(app);
    }

    pub fn listen(self: *App, port: u16, user_data: anytype, comptime handler: fn (@TypeOf(user_data), ?*c.us_listen_socket_t) void) void {
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

    pub fn get(self: *App, pattern: [:0]const u8, user_data: anytype, comptime handler: fn (@TypeOf(user_data), *Response, *Request) void) void {
        const Handler = struct {
            fn handle(res: ?*c.uws_res_t, req: ?*c.uws_req_t, raw_user_data: ?*anyopaque) callconv(.C) void {
                if (comptime @TypeOf(user_data) == void) {
                    handler({}, @ptrCast(res.?), @ptrCast(req.?));
                } else {
                    handler(@ptrCast(raw_user_data), @ptrCast(res.?), @ptrCast(req.?));
                }
            }
        };
        c.uws_app_get(0, @ptrCast(self), pattern, Handler.handle, @ptrCast(@alignCast(user_data)));
    }

    pub fn run(self: *App) void {
        c.uws_app_run(0, @ptrCast(self));
    }
};

test "uws: basic app" {
    const Context = struct {
        fn get(_: *@This(), res: *Response, req: *Request) void {
            res.writeStatus("OK");
            res.writeHeader("Server", "uWebSockets-Zig");
            _ = res.write(req.method());
            _ = res.write(" ");
            _ = res.write(req.fullUrl());
            _ = res.write("\n");
            res.end(res.getRemoteAddressAsText(), false);
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
