const std = @import("std");
const net = std.net;

const Allocator = std.mem.Allocator;
const ServerConfig = @import("config.zig").ServerConfig;

pub fn listen(comptime H: type, allocator: Allocator, config: ServerConfig) !void {
    _ = allocator;
    var server = net.StreamServer.init(.{
        .reuse_address = true,
        .kernel_backlog = 1024,
    });
    defer server.deinit();

    const address = try net.Address.parseIp(config.address, config.port);
    try server.listen(address);
    std.log.info("Server listening on {s}:{d}", .{ config.address, config.port });

    while (true) {
        if (server.accept()) |conn| {
            std.log.info("Client connected on port {d}", .{conn.address.getPort()});
            const args = .{ H, conn, &config };
            // Spawn a thread to handle each client
            const thread = try std.Thread.spawn(.{}, clientLoop, args);
            thread.detach();
        } else |err| {
            std.log.err("failed to accept connection {}", .{err});
        }
    }
}

fn clientLoop(comptime H: type, net_conn: net.StreamServer.Connection, config: *const ServerConfig) !void {
    _ = config;
    const stream = net_conn.stream;
    defer stream.close();

    var handler: H = undefined;
    _ = handler;
    // TODO: implement comptime package handler
    {
        var buffer: [1]u8 = undefined;
        const size = try stream.read(&buffer);
        std.log.info("0x{}\n", .{std.fmt.fmtSliceHexLower(&buffer)});
        std.log.info("read {d} bytes", .{size});
    }
}

const Handler = struct {};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.detectLeaks();
    const allocator = gpa.allocator();
    // TODO: load config from file
    const config = ServerConfig{};

    try listen(Handler, allocator, config);
}
