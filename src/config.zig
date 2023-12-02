pub const ServerConfig = struct {
    port: u16 = 1883,
    max_size: usize = 65536,
    address: []const u8 = "0.0.0.0",

    pub fn load() ServerConfig {
        // TODO: Load from config file
        return ServerConfig{
            .port = 1883,
            .max_size = 65536,
            .address = "0.0.0.0",
        };
    }
};
