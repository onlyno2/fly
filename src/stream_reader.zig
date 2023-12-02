const std = @import("std");
const net = std.net;

pub const StreamReader = struct {
    stream: net.Stream,
    allocator: *const std.mem.Allocator,

    pub fn readBytes(self: *StreamReader, size: usize) ![]u8 {
        var buffer = try self.allocator.alloc(u8, size);
        _ = try self.stream.read(buffer);

        return buffer;
    }

    pub fn readU8(self: *StreamReader) !u8 {
        const buffer = try self.readBytes(1);

        return buffer[0];
    }

    pub fn readU16(self: *StreamReader) ![]u8 {
        return self.readBytes(2);
    }

    pub fn readU32(self: *StreamReader) ![]u8 {
        return self.readBytes(4);
    }
};
