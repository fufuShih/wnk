pub const PanelTop = union(enum) {
    header: Header,

    pub const Header = struct {
        title: []const u8,
        subtitle: ?[]const u8 = null,
    };
};

pub const PanelBottom = union(enum) {
    none,
    info: []const u8,
};

pub const PanelLayout = struct {
    /// "list" (default) or "grid"
    mode: []const u8 = "list",
    columns: ?usize = null,
    gap: ?usize = null,
};

pub const PanelMain = union(enum) {
    list: List,

    pub const List = struct {
        layout: ?PanelLayout = null,
        items: []const PanelItem = &.{},
    };
};

pub const PanelData = struct {
    top: PanelTop,
    main: PanelMain,
    bottom: PanelBottom = .none,
};

pub const PanelItem = struct {
    title: []const u8,
    subtitle: []const u8,
    next_panel: ?*const PanelData = null,
};

pub fn panelHeader(p: *const PanelData) PanelTop.Header {
    return switch (p.top) {
        .header => |h| h,
    };
}

pub fn panelList(p: *const PanelData) ?PanelMain.List {
    return switch (p.main) {
        .list => |l| l,
    };
}

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
    .top = .{ .header = .{ .title = "Code / Settings", .subtitle = "Common toggles" } },
    .main = .{ .list = .{
        .layout = .{ .mode = "list" },
        .items = &.{
            .{ .title = "Toggle Vim Mode", .subtitle = "Editor" },
            .{ .title = "Change Theme", .subtitle = "Appearance" },
            .{ .title = "Open Keybindings", .subtitle = "Keyboard" },
        },
    } },
    .bottom = .{ .info = "W/S: move  Esc: back" },
};

const code_recent_panel = PanelData{
    .top = .{ .header = .{ .title = "Code / Recent", .subtitle = "Pick a project" } },
    .main = .{ .list = .{
        .layout = .{ .mode = "grid", .columns = 2, .gap = 12 },
        .items = &.{
            .{ .title = "wnk", .subtitle = "C:/workspace/projects/wnk" },
            .{ .title = "notes", .subtitle = "C:/workspace/notes" },
            .{ .title = "demo", .subtitle = "C:/workspace/demo" },
            .{ .title = "playground", .subtitle = "C:/workspace/play" },
        },
    } },
    .bottom = .{ .info = "Enter: open  Esc: back" },
};

const code_root_panel = PanelData{
    .top = .{ .header = .{ .title = "Code", .subtitle = "Development" } },
    .main = .{ .list = .{
        .layout = .{ .mode = "list" },
        .items = &.{
            .{ .title = "Recent", .subtitle = "Projects", .next_panel = &code_recent_panel },
            .{ .title = "Settings", .subtitle = "Preferences", .next_panel = &code_settings_panel },
        },
    } },
    .bottom = .{ .info = "Enter: open  Esc: back" },
};

const calendar_root_panel = PanelData{
    .top = .{ .header = .{ .title = "Calendar", .subtitle = "System Preferences" } },
    .main = .{ .list = .{
        .layout = .{ .mode = "list" },
        .items = &.{
            .{ .title = "Today", .subtitle = "Overview" },
            .{ .title = "Upcoming", .subtitle = "Next 7 days" },
        },
    } },
    .bottom = .{ .info = "Esc: back" },
};

/// Minimal example dataset for local UI testing.
pub const example_results = [_]SearchResult{
    .{ .title = "Calendar", .subtitle = "System Preferences", .icon = "C", .next_panel = &calendar_root_panel },
    .{ .title = "Code", .subtitle = "Development", .icon = "#", .next_panel = &code_root_panel },
};

/// Back-compat alias (will be removed later).
pub const mock_results = example_results;
