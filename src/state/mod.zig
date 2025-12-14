const std = @import("std");

const mock = @import("mock.zig");
pub const ipc = @import("ipc.zig");
const nav_mod = @import("nav.zig");

pub const Panel = nav_mod.Panel;
pub const DetailsSource = nav_mod.DetailsSource;
pub const DetailsPanel = nav_mod.DetailsPanel;
pub const PanelEntry = nav_mod.PanelEntry;
pub const default_panel_entry = nav_mod.default_panel_entry;
pub const default_panel = nav_mod.default_panel;

pub const PluginResultItem = ipc.PluginResultItem;
pub const PluginResultsPayload = ipc.PluginResultsPayload;
pub const SubpanelItem = ipc.SubpanelItem;
pub const SubpanelLayout = ipc.SubpanelLayout;
pub const SubpanelPayload = ipc.SubpanelPayload;

// Search buffer for the input field
pub var search_buffer: [256]u8 = undefined;
pub var search_len: usize = 0;
pub var search_initialized = false;

pub var nav: nav_mod.Navigation = .{};

pub fn resetPanels() void {
    nav.resetPanels();
}

pub fn currentPanel() Panel {
    return nav.currentPanel();
}

pub fn currentDetails() ?*DetailsPanel {
    return nav.currentDetails();
}

pub fn canPopPanel() bool {
    return nav.canPopPanel();
}

pub fn pushPanel(p: PanelEntry) void {
    nav.pushPanel(p);
}

pub fn popPanel() void {
    nav.popPanel();
}

pub fn openPluginDetails() void {
    nav.openPluginDetails();
}

pub fn openMockDetails(panel: *const mock.PanelData) void {
    nav.openMockDetails(panel);
}

pub fn openCommands() void {
    nav.openCommands();
}

pub fn detailsItemsCount() usize {
    return nav.detailsItemsCount();
}

pub fn detailsClampSelection() void {
    nav.detailsClampSelection();
}

pub fn detailsMoveSelection(delta: isize) void {
    nav.detailsMoveSelection(delta);
}

pub fn detailsSelectedNextPanel() ?*const mock.PanelData {
    return nav.detailsSelectedNextPanel();
}

// Command panel selection/trigger
pub var command_selected_index: usize = 0;
pub var command_execute = false;

// Selection state
pub var selected_index: usize = 0;
pub var focus_on_results = false;

// Plugin-provided results (via IPC)
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
pub const MockPanelMain = mock.PanelMain;
pub const MockPanelTop = mock.PanelTop;
pub const MockPanelBottom = mock.PanelBottom;
pub const example_results = mock.example_results;
pub const mock_results = mock.mock_results;

pub fn panelHeader(p: *const mock.PanelData) mock.PanelTop.Header {
    return mock.panelHeader(p);
}

pub fn panelList(p: *const mock.PanelData) ?mock.PanelMain.List {
    return mock.panelList(p);
}

pub fn init(allocator: std.mem.Allocator) void {
    @memset(&search_buffer, 0);
    search_initialized = true;
    ipc.plugin_results_allocator = allocator;

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
    if (ipc.plugin_results) |*p| {
        p.deinit();
        ipc.plugin_results = null;
    }
    if (ipc.subpanel_data) |*s| {
        s.deinit();
        ipc.subpanel_data = null;
    }
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
        ipc.updatePluginResults(allocator, json_str) catch {};
        if (ipc.plugin_results) |p| {
            if (p.value.items.len > 0) {
                focus_on_results = true;
                selected_index = 0;
            }
        }
        return;
    }

    if (std.mem.eql(u8, type_val.string, "subpanel")) {
        ipc.updateSubpanelData(allocator, json_str) catch {};
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
