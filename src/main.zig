const std = @import("std");
const c = @cImport({
    @cInclude("libusockets.h");
    @cInclude("libuwebsockets.h");
});

test "uws: basic app" {
    const opts = std.mem.zeroes(c.us_socket_context_options_t);

    const App = struct {
        fn get(res: ?*c.uws_res_t, req: ?*c.uws_req_t, user_data: ?*anyopaque) callconv(.C) void {
            _ = req;
            _ = user_data;

            const text = "Hello Zig!";
            c.uws_res_end(0, res, text, text.len, false);
        }

        fn listen(s: ?*c.us_listen_socket_t, config: c.uws_app_listen_config_t, user_data: ?*anyopaque) callconv(.C) void {
            _ = config;
            _ = user_data;
            if (s != null) {
                const port = c.us_socket_local_port(0, @ptrCast(s));
                std.debug.print("\nListening on port http://localhost:{d} now\n", .{port});
            }
        }
    };

    const app = c.uws_create_app(0, opts);
    c.uws_app_get(0, app, "/*", App.get, null);
    c.uws_app_listen(0, app, 0, App.listen, null);
    c.uws_app_run(0, app);
}
