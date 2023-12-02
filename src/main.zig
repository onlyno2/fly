const std = @import("std");
const net = std.net;

const Allocator = std.mem.Allocator;
const ServerConfig = @import("config.zig").ServerConfig;
const Mqtt = @import("mqtt.zig");
const StreamReader = @import("stream_reader.zig").StreamReader;

pub fn listen(comptime H: type, allocator: *const Allocator, config: ServerConfig) !void {
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
            const args = .{ H, conn, allocator, &config };
            // Spawn a thread to handle each client
            const thread = try std.Thread.spawn(.{}, clientLoop, args);
            thread.detach();
        } else |err| {
            std.log.err("failed to accept connection {}", .{err});
        }
    }
}

fn clientLoop(comptime H: type, net_conn: net.StreamServer.Connection, allocator: *const std.mem.Allocator, config: *const ServerConfig) !void {
    // TODO: use arena allocator for each client
    _ = config;
    const stream = net_conn.stream;
    defer stream.close();

    var stream_reader = StreamReader{
        .stream = stream,
        .allocator = allocator,
    };
    var handler: H = undefined;
    _ = handler;
    // TODO: implement comptime package handler
    {
        var buffer: [1]u8 = undefined;
        _ = try stream.read(&buffer);
        const mqtt_header: Mqtt.MqttHeader = @bitCast(buffer[0]);
        std.log.info("Outer header: {}", .{mqtt_header});
        if (mqtt_header.packet_type != .CONNECT) {
            std.log.err("Expected CONNECT packet, got {}", .{mqtt_header.packet_type});
            return;
        }
        var mqtt_connect: Mqtt.MqttConnect = undefined;
        _ = try Mqtt.unpack_connect(buffer[0], &stream_reader, &mqtt_connect);
        std.log.info("Outer header: {}", .{mqtt_connect.header});

        // TODO: auth

        // Send CONNACK for now
        var mqtt_connack: Mqtt.MqttConnack = Mqtt.get_connack(stream, 0x00, 1);
        _ = try stream.write(std.mem.asBytes(&mqtt_connack));
    }
}

const Handler = struct {};

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.detectLeaks();
    const allocator = gpa.allocator();
    const config = ServerConfig.load();

    try listen(Handler, &allocator, config);
}
