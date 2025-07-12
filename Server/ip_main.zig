//! 0.14.1

const std = @import("std");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();

    const address = try std.net.Address.parseIp4("0.0.0.0", 80);
    var server = try address.listen(.{ .reuse_address = true });
    defer server.deinit();

    while (true) {
        const connection = try server.accept();
        defer connection.stream.close();

        handleConnection(allocator, connection);
    }
}

fn handleConnection(allocator: std.mem.Allocator, connection: std.net.Server.Connection) void {
    var header_buffer: [1024]u8 = undefined;
    var server = std.http.Server.init(connection, &header_buffer);

    var request = server.receiveHead() catch return;

    const ip = @as(*const [4]u8, @ptrCast(&connection.address.in.sa.addr));
    const html = std.fmt.allocPrint(allocator,
        \\<!DOCTYPE html>
        \\<html lang="en">
        \\<head>
        \\  <meta charset="UTF-8">
        \\  <meta name="viewport" content="width=device-width, initial-scale=1.0">
        \\  <title>Your IP Address</title>
        \\  <style>
        \\    body {{
        \\      margin: 0;
        \\      height: 100vh;
        \\      display: flex;
        \\      justify-content: center;
        \\      align-items: center;
        \\      background-color: var(--bg-color);
        \\      transition: background-color 0.5s;
        \\    }}
        \\    .ip-container {{
        \\      font-family: Arial, sans-serif;
        \\      font-size: 3rem;
        \\      color: var(--text-color);
        \\      text-align: center;
        \\    }}
        \\    @media (prefers-color-scheme: dark) {{
        \\      :root {{
        \\        --text-color: #ffffff;
        \\        --bg-color: #121212;
        \\      }}
        \\    }}
        \\    @media (prefers-color-scheme: light) {{
        \\      :root {{
        \\        --text-color: #000000;
        \\        --bg-color: #f0f0f0;
        \\      }}
        \\    }}
        \\  </style>
        \\</head>
        \\<body>
        \\  <div class="ip-container">{}.{}.{}.{}</div>
        \\</body>
        \\</html>
    , .{ ip[0], ip[1], ip[2], ip[3] }) catch return;
    defer allocator.free(html);

    request.respond(html, .{}) catch return;
}
