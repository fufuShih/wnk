pub const SearchResult = struct {
    title: []const u8,
    subtitle: []const u8,
    icon: []const u8,

    /// Optional overrides for the header shown when this item is selected.
    /// If null, defaults to title/subtitle.
    header_title: ?[]const u8 = null,
    header_subtitle: ?[]const u8 = null,
};

pub const mock_results = [_]SearchResult{
    .{ .title = "Calendar", .subtitle = "System Preferences", .icon = "C" },
    .{ .title = "Camera", .subtitle = "Devices", .icon = "O" },
    .{ .title = "Chrome", .subtitle = "Web Browser", .icon = "@" },
    .{ .title = "Code", .subtitle = "Development", .icon = "#" },
};
