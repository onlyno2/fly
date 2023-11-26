pub const ServerConfig = struct {
    port: u16 = 1883,
    max_size: usize = 65536,
    address: []const u8 = "0.0.0.0",
};
