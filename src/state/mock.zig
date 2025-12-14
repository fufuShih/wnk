pub const PanelLayout = struct {
    /// "list" (default) or "grid"
    mode: []const u8 = "list",
    columns: ?usize = null,
    gap: ?usize = null,
};

pub const PanelData = struct {
    header: []const u8,
    header_subtitle: ?[]const u8 = null,
    layout: ?PanelLayout = null,
    items: []const PanelItem = &.{},
};

pub const PanelItem = struct {
    title: []const u8,
    subtitle: []const u8,
    next_panel: ?*const PanelData = null,
};

pub const SearchResult = struct {
    title: []const u8,
    subtitle: []const u8,
    icon: []const u8,

    /// Optional overrides for the header shown when this item is selected.
    /// If null, defaults to title/subtitle.
    header_title: ?[]const u8 = null,
    header_subtitle: ?[]const u8 = null,

    /// Optional panel tree root for this item.
    /// If present, Enter on this result opens the panel and allows navigating deeper.
    next_panel: ?*const PanelData = null,
};

// Example panel tree for mock results.
// Deepest nodes first to allow pointers.

const code_settings_panel = PanelData{
    .header = "Code / Settings",
    .header_subtitle = "Common toggles",
    .layout = .{ .mode = "list" },
    .items = &.{
        .{ .title = "Toggle Vim Mode", .subtitle = "Editor" },
        .{ .title = "Change Theme", .subtitle = "Appearance" },
        .{ .title = "Open Keybindings", .subtitle = "Keyboard" },
    },
};

const code_recent_panel = PanelData{
    .header = "Code / Recent",
    .header_subtitle = "Pick a project",
    .layout = .{ .mode = "grid", .columns = 2, .gap = 12 },
    .items = &.{
        .{ .title = "wnk", .subtitle = "C:/workspace/projects/wnk" },
        .{ .title = "notes", .subtitle = "C:/workspace/notes" },
        .{ .title = "demo", .subtitle = "C:/workspace/demo" },
        .{ .title = "playground", .subtitle = "C:/workspace/play" },
    },
};

const code_root_panel = PanelData{
    .header = "Code",
    .header_subtitle = "Development",
    .layout = .{ .mode = "list" },
    .items = &.{
        .{ .title = "Recent", .subtitle = "Projects", .next_panel = &code_recent_panel },
        .{ .title = "Settings", .subtitle = "Preferences", .next_panel = &code_settings_panel },
    },
};

const calendar_root_panel = PanelData{
    .header = "Calendar",
    .header_subtitle = "System Preferences",
    .layout = .{ .mode = "list" },
    .items = &.{
        .{ .title = "Today", .subtitle = "Overview" },
        .{ .title = "Upcoming", .subtitle = "Next 7 days" },
    },
};

/// Minimal example dataset for local UI testing.
pub const example_results = [_]SearchResult{
    .{ .title = "Calendar", .subtitle = "System Preferences", .icon = "C", .next_panel = &calendar_root_panel },
    .{ .title = "Code", .subtitle = "Development", .icon = "#", .next_panel = &code_root_panel },
};

/// Back-compat alias (will be removed later).
pub const mock_results = example_results;
