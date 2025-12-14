const std = @import("std");

const mock = @import("mock.zig");

// Search buffer for the input field
pub var search_buffer: [256]u8 = undefined;
pub var search_len: usize = 0;
pub var search_initialized = false;

pub const Panel = enum {
    search,
    details,
    commands,
};

pub const DetailsSource = enum {
    plugin,
    mock,
};

pub const DetailsPanel = struct {
    source: DetailsSource = .plugin,
    mock_panel: ?*const mock.PanelData = null,
    selected_index: usize = 0,
};

pub const PanelEntry = union(Panel) {
    search: void,
    details: DetailsPanel,
    commands: void,
};

pub var panel_stack: [8]PanelEntry = undefined;
pub var panel_stack_len: usize = 0;

/// Floating action panel overlay (does not affect the panel stack).
pub var action_open: bool = false;

pub fn resetPanels() void {
    panel_stack[0] = .{ .search = {} };
    panel_stack_len = 1;
    action_open = false;
}

pub fn currentPanel() Panel {
    return std.meta.activeTag(panel_stack[panel_stack_len - 1]);
}

pub fn currentDetails() ?*DetailsPanel {
    if (panel_stack[panel_stack_len - 1] == .details) {
        return &panel_stack[panel_stack_len - 1].details;
    }
    return null;
}

pub fn canPopPanel() bool {
    return panel_stack_len > 1;
}

pub fn pushPanel(p: PanelEntry) void {
    if (panel_stack_len >= panel_stack.len) return;
    panel_stack[panel_stack_len] = p;
    panel_stack_len += 1;
}

pub fn popPanel() void {
    if (panel_stack_len > 1) panel_stack_len -= 1;
}

pub fn openPluginDetails() void {
    pushPanel(.{ .details = .{ .source = .plugin, .mock_panel = null, .selected_index = 0 } });
}

pub fn openMockDetails(panel: *const mock.PanelData) void {
    pushPanel(.{ .details = .{ .source = .mock, .mock_panel = panel, .selected_index = 0 } });
}

pub fn openCommands() void {
    pushPanel(.{ .commands = {} });
}

pub fn detailsItemsCount() usize {
    const d = currentDetails() orelse return 0;
    if (d.source == .mock) {
        const p = d.mock_panel orelse return 0;
        return p.items.len;
    }

    // plugin details: only selectable when data exists
    if (subpanel_data) |s| return s.value.items.len;
    return 0;
}

pub fn detailsClampSelection() void {
    const d = currentDetails() orelse return;
    const count = detailsItemsCount();
    if (count == 0) {
        d.selected_index = 0;
        return;
    }
    if (d.selected_index >= count) d.selected_index = count - 1;
}

pub fn detailsMoveSelection(delta: isize) void {
    const d = currentDetails() orelse return;
    const count = detailsItemsCount();
    if (count == 0) return;

    const cur: isize = @intCast(d.selected_index);
    var next: isize = cur + delta;
    if (next < 0) next = 0;
    if (next >= @as(isize, @intCast(count))) next = @as(isize, @intCast(count - 1));
    d.selected_index = @intCast(next);
}

pub fn detailsSelectedNextPanel() ?*const mock.PanelData {
    const d = currentDetails() orelse return null;
    if (d.source != .mock) return null;
    const p = d.mock_panel orelse return null;
    if (p.items.len == 0) return null;
    if (d.selected_index >= p.items.len) return null;
    return p.items[d.selected_index].next_panel;
}

// Command panel selection/trigger
pub var command_selected_index: usize = 0;
pub var command_execute = false;

// Selection state
pub var selected_index: usize = 0;
pub var focus_on_results = false;

// Plugin-provided results (via IPC)
pub const PluginResultItem = struct {
    id: ?[]const u8 = null,
    title: []const u8,
    subtitle: ?[]const u8 = null,
    icon: ?[]const u8 = null,
};

pub const PluginResultsPayload = struct {
    type: []const u8,
    items: []PluginResultItem = &.{},
};

pub var plugin_results: ?std.json.Parsed(PluginResultsPayload) = null;
var plugin_results_allocator: ?std.mem.Allocator = null;

// Subpanel data (for list/detail view)
pub const SubpanelItem = struct {
    title: []const u8,
    subtitle: []const u8,
};

pub const SubpanelLayout = struct {
    /// "list" (default) or "grid"
    mode: []const u8 = "list",
    /// Used when mode == "grid". Defaults handled in UI.
    columns: ?usize = null,
    gap: ?usize = null,
};

pub const SubpanelPayload = struct {
    type: []const u8,
    header: []const u8,
    headerSubtitle: ?[]const u8 = null,
    layout: ?SubpanelLayout = null,
    items: []SubpanelItem = &.{},
};

pub var subpanel_data: ?std.json.Parsed(SubpanelPayload) = null;
pub var subpanel_pending: bool = false;

// Store selected item info when entering list mode (to avoid dangling pointers)
pub var selected_item_title: [256]u8 = undefined;
pub var selected_item_title_len: usize = 0;
pub var selected_item_subtitle: [256]u8 = undefined;
pub var selected_item_subtitle_len: usize = 0;

pub fn setSelectedItemInfo(title: []const u8, subtitle: []const u8) void {
    const t_len = @min(title.len, selected_item_title.len);
    @memcpy(selected_item_title[0..t_len], title[0..t_len]);
    selected_item_title_len = t_len;

    const s_len = @min(subtitle.len, selected_item_subtitle.len);
    @memcpy(selected_item_subtitle[0..s_len], subtitle[0..s_len]);
    selected_item_subtitle_len = s_len;
}

pub fn getSelectedItemTitle() []const u8 {
    return selected_item_title[0..selected_item_title_len];
}

pub fn getSelectedItemSubtitle() []const u8 {
    return selected_item_subtitle[0..selected_item_subtitle_len];
}

pub const SearchResult = mock.SearchResult;
pub const MockPanelData = mock.PanelData;
pub const MockPanelItem = mock.PanelItem;
pub const MockPanelLayout = mock.PanelLayout;
pub const example_results = mock.example_results;
pub const mock_results = mock.mock_results;

pub fn init(allocator: std.mem.Allocator) void {
    @memset(&search_buffer, 0);
    search_initialized = true;
    plugin_results_allocator = allocator;

    resetPanels();
    command_selected_index = 0;
    command_execute = false;

    selected_item_title_len = 0;
    selected_item_subtitle_len = 0;
}

pub fn setSearchText(text: []const u8) void {
    const n: usize = @min(text.len, search_buffer.len);
    @memset(&search_buffer, 0);
    @memcpy(search_buffer[0..n], text[0..n]);
    search_len = n;
}

pub fn deinit() void {
    if (plugin_results) |*p| {
        p.deinit();
        plugin_results = null;
    }
    if (subpanel_data) |*s| {
        s.deinit();
        subpanel_data = null;
    }
}

pub fn updatePluginResults(allocator: std.mem.Allocator, json_str: []const u8) !void {
    // Parse only the results messages; ignore other messages.
    var parsed = std.json.parseFromSlice(PluginResultsPayload, allocator, json_str, .{ .ignore_unknown_fields = true }) catch return;
    errdefer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.type, "results")) {
        parsed.deinit();
        return;
    }

    if (plugin_results) |*old| {
        old.deinit();
    }
    plugin_results = parsed;
    plugin_results_allocator = allocator;

    // Auto-focus on results when plugin returns items
    if (parsed.value.items.len > 0) {
        focus_on_results = true;
        selected_index = 0;
    }
}

pub fn updateSubpanelData(allocator: std.mem.Allocator, json_str: []const u8) !void {
    var parsed = std.json.parseFromSlice(SubpanelPayload, allocator, json_str, .{ .ignore_unknown_fields = true }) catch return;
    errdefer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.type, "subpanel")) {
        parsed.deinit();
        return;
    }

    if (subpanel_data) |*old| {
        old.deinit();
    }
    subpanel_data = parsed;
    subpanel_pending = false;
}

pub fn handleBunMessage(allocator: std.mem.Allocator, json_str: []const u8) void {
    // First parse as generic JSON to inspect message type.
    var parsed_any = std.json.parseFromSlice(std.json.Value, allocator, json_str, .{ .ignore_unknown_fields = true }) catch return;
    defer parsed_any.deinit();

    if (parsed_any.value != .object) return;
    const obj = parsed_any.value.object;
    const type_val = obj.get("type") orelse return;
    if (type_val != .string) return;

    if (std.mem.eql(u8, type_val.string, "results")) {
        updatePluginResults(allocator, json_str) catch {};
        return;
    }

    if (std.mem.eql(u8, type_val.string, "subpanel")) {
        updateSubpanelData(allocator, json_str) catch {};
        return;
    }

    if (!std.mem.eql(u8, type_val.string, "effect")) return;

    const Effect = struct {
        type: []const u8,
        name: []const u8,
        text: ?[]const u8 = null,
    };

    var eff = std.json.parseFromSlice(Effect, allocator, json_str, .{ .ignore_unknown_fields = true }) catch return;
    defer eff.deinit();

    if (std.mem.eql(u8, eff.value.name, "setSearchText")) {
        if (eff.value.text) |t| setSearchText(t);
        resetPanels();
        focus_on_results = false;
        return;
    }
}
