pub const Command = struct {
    // Sent to Bun as { type: "command", name, text }
    name: []const u8,
    title: []const u8,
};

pub const commands = [_]Command{
    .{ .name = "setSearchText", .title = "Use as query" },
};

pub fn getCommand(idx: usize) ?Command {
    if (idx >= commands.len) return null;
    return commands[idx];
}
