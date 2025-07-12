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

    var addr: [15]u8 = undefined;
    var ip: ?[]const u8 = result: {
        var it = request.iterateHeaders();
        while (it.next()) |header| {
            if (std.ascii.eqlIgnoreCase(header.name, "Cf-Connecting-Ip")) {
                break :result header.value;
            }
        }
        break :result null;
    };

    if (ip == null) {
        const inAddr = @as(*const [4]u8, @ptrCast(&connection.address.in.sa.addr));
        const inAddrStr = std.fmt.allocPrint(allocator, "{}.{}.{}.{}", .{ inAddr[0], inAddr[1], inAddr[2], inAddr[3] }) catch return;
        defer allocator.free(inAddrStr);

        for (inAddrStr, 0..) |byte, index| {
            addr[index] = byte;
        }

        ip = addr[0..inAddrStr.len];
    }

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
        \\  <div class="ip-container">{s}</div>
        \\</body>
        \\</html>
    , .{ip.?}) catch return;
    defer allocator.free(html);

    request.respond(html, .{}) catch return;
}
