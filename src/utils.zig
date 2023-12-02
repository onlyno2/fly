const std = @import("std");

const UnpackError = error{
    InvalidBufferLength,
};

pub fn unpack_u16(array: []u8) !u16 {
    if (array.len > 2) {
        return error.InvalidBufferLength;
    }

    return (@as(u16, array[0]) << 8) | @as(u16, array[1]);
}
