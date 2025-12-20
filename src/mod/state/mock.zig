const std = @import("std");
const ipc = @import("ipc.zig");
const builder = @import("panel_builder.zig");

pub const PanelLink = struct {
    id: []const u8,
    next_panel: *const PanelData,
};

pub const PanelData = struct {
    top: ipc.PanelTopPayload,
    main: ipc.PanelNodePayload,
    bottom: ipc.PanelBottomPayload = .{},
    links: []const PanelLink = &.{},
};

pub const PanelHeader = struct {
    title: []const u8,
    subtitle: ?[]const u8 = null,
};

pub fn panelHeader(p: *const PanelData) PanelHeader {
    if (std.mem.eql(u8, p.top.type, "header")) {
        return .{
            .title = p.top.title orelse "",
            .subtitle = p.top.subtitle,
        };
    }
    return .{ .title = "", .subtitle = null };
}

pub fn panelBottomInfo(p: *const PanelData) ?[]const u8 {
    if (std.mem.eql(u8, p.bottom.type, "info")) return p.bottom.text;
    return null;
}

pub fn panelNextPanel(p: *const PanelData, item_id: []const u8) ?*const PanelData {
    for (p.links) |link| {
        if (std.mem.eql(u8, link.id, item_id)) return link.next_panel;
    }
    return null;
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
    .top = builder.header("Code / Settings", "Common toggles"),
    .main = builder.boxFromSpec("box vertical 12", &.{
        builder.listFromSpec("flex", &.{
            builder.item("Toggle Vim Mode", "Editor", null, null),
            builder.item("Change Theme", "Appearance", null, null),
            builder.item("Open Keybindings", "Keyboard", null, null),
        }),
    }),
    .bottom = builder.bottomInfo("W/S: move  Esc: back"),
};

const code_recent_panel = PanelData{
    .top = builder.header("Code / Recent", "Pick a project"),
    .main = builder.boxFromSpec("box vertical 12", &.{
        builder.listFromSpec("grid 2 12", &.{
            builder.item("wnk", "C:/workspace/projects/wnk", null, null),
            builder.item("notes", "C:/workspace/notes", null, null),
            builder.item("demo", "C:/workspace/demo", null, null),
            builder.item("playground", "C:/workspace/play", null, null),
        }),
    }),
    .bottom = builder.bottomInfo("Enter: open  Esc: back"),
};

const code_root_panel = PanelData{
    .top = builder.header("Code", "Development"),
    .main = builder.boxFromSpec("box vertical 12", &.{
        builder.listFromSpec("flex", &.{
            builder.item("Recent", "Projects", "recent", null),
            builder.item("Settings", "Preferences", "settings", null),
        }),
    }),
    .links = &.{
        .{ .id = "recent", .next_panel = &code_recent_panel },
        .{ .id = "settings", .next_panel = &code_settings_panel },
    },
    .bottom = builder.bottomInfo("Enter: open  Esc: back"),
};

const calendar_root_panel = PanelData{
    .top = builder.header("Calendar", "System Preferences"),
    .main = builder.boxFromSpec("box vertical 12", &.{
        builder.listFromSpec("flex", &.{
            builder.item("Today", "Overview", null, null),
            builder.item("Upcoming", "Next 7 days", null, null),
            builder.item("Object", "No actions", null, false),
        }),
    }),
    .bottom = builder.bottomInfo("Esc: back"),
};

/// Minimal example dataset for local UI testing.
pub const example_results = [_]SearchResult{
    .{ .title = "Calendar", .subtitle = "System Preferences", .icon = "C", .next_panel = &calendar_root_panel },
    .{ .title = "Code", .subtitle = "Development", .icon = "#", .next_panel = &code_root_panel },
};
