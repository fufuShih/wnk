pub const SelectionSource = enum {
    os,
    clipboard,
};

pub const Selection = struct {
    text: []const u8,
    source: SelectionSource,
};
