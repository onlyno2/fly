const std = @import("std");

const StreamReader = @import("stream_reader.zig").StreamReader;
const Utils = @import("utils.zig");

const CONNACK_BYTE: u8 = 0x20;

pub const PackageType = enum(u4) {
    Reserved = 0,
    CONNECT = 1,
    CONNACK = 2,
    PUBLISH = 3,
    PUBACK = 4,
    PUBREC = 5,
    PUBREL = 6,
    PUBCOMP = 7,
    SUBSCRIBE = 8,
    SUBACK = 9,
    UNSUBSCRIBE = 10,
    UNSUBACK = 11,
    PINGREQ = 12,
    PINGRESP = 13,
    DISCONNECT = 14,
    AUTH = 15,
};

pub const QoSLevel = enum(u2) {
    AT_MOST_ONCE,
    AT_LEAST_ONCE,
    EXACTLY_ONCE,
};

// 1st byte
pub const MqttHeader = packed struct {
    retain: bool,
    qos: QoSLevel,
    dup: bool,
    packet_type: PackageType,
};

pub const MqttPacket = struct {
    header: MqttHeader,
};

pub const MqttConnect = struct {
    header: MqttHeader,
    connectFlags: packed struct {
        reserved: u1,
        clean_session: bool,
        will_flag: bool,
        will_qos: QoSLevel,
        will_retain: bool,
        password_flag: bool,
        username_flag: bool,
    },
    payload: struct {
        keep_alive: u16,
        client_id: []u8,
        username: []u8,
        password: []u8,
        will_topic: []u8,
        will_message: []u8,
    },
};

pub const MqttConnack = struct {
    header: MqttHeader,
    ack_flags: packed struct {
        session_present: bool,
        reserved: u7,
    },
    return_code: u8,
};

pub fn unpack_connect(header: u8, stream_reader: *StreamReader, package: *MqttConnect) !usize {
    // Header byte read before calling this function
    package.*.header = @bitCast(header);

    // Remaining bytes, start from second byte
    const remaining_bytes = try read_remaining_bytes(stream_reader);
    std.log.info("remaining bytes: {d}", .{remaining_bytes});

    // Skip protocol_name_length for now
    _ = try stream_reader.readU16();

    // Protocol name = MQTT
    const protocol_name = try stream_reader.readBytes(4);
    std.log.info("{s}", .{protocol_name});

    // Skip protocol_level for now
    _ = try stream_reader.readU8();

    // Connect flags
    package.*.connectFlags = @bitCast(try stream_reader.readU8());

    // Keep alive
    package.*.payload.keep_alive = try Utils.unpack_u16(try stream_reader.readU16());
    std.log.info("keep_alive: {d}", .{package.payload.keep_alive});

    // Properties, skip for now
    const properties_length = try stream_reader.readU8();
    if (properties_length > 0) {
        _ = try stream_reader.readBytes(properties_length);
    }

    const cid_length = try Utils.unpack_u16(try stream_reader.readU16());
    if (cid_length > 0) {
        package.*.payload.client_id = try stream_reader.readBytes(cid_length);
        std.log.info("client_id: {s}", .{package.payload.client_id});
    }

    // TODO: Will topic and message

    if (package.*.connectFlags.username_flag) {
        const username_length = try Utils.unpack_u16(try stream_reader.readU16());
        package.*.payload.username = try stream_reader.readBytes(username_length);
    }

    if (package.*.connectFlags.password_flag) {
        const password_length = try Utils.unpack_u16(try stream_reader.readU16());
        package.*.payload.password = try stream_reader.readBytes(password_length);
    }

    return remaining_bytes;
}

pub fn get_connack(stream: std.net.Stream, return_code: u8, session_present: u1) MqttConnack {
    _ = stream;
    const ack_flags: u8 = 0 | (session_present & 0x1) << 0;

    return MqttConnack{
        .header = @bitCast(CONNACK_BYTE),
        .ack_flags = @bitCast(ack_flags),
        .return_code = return_code,
    };
}

pub fn read_remaining_bytes(stream_reader: *StreamReader) !usize {
    var remaining_bytes: usize = 0;
    var multiplier: u32 = 1;
    while (true) {
        var byte = try stream_reader.*.readU8();
        remaining_bytes += byte & 127 * multiplier;
        multiplier *= 128;
        if (multiplier > 128 * 128 * 128) {
            std.log.err("malformed remaining bytes", .{});
            return 0;
        }
        if (byte & 128 == 0) {
            break;
        }
    }

    return remaining_bytes;
}
