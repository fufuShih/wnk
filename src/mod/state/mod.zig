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
pub const PanelItem = ipc.PanelItem;
pub const PanelPayload = ipc.PanelPayload;

// Search buffer for the input field
pub var search_buffer: [256]u8 = undefined;
pub var search_len: usize = 0;
pub var search_initialized = false;

pub var nav: nav_mod.Navigation = .{};

pub fn resetPanels() void {
    nav.resetPanels();
    clearDetailsPluginId();
    clearDetailsItemId();
    ipc.clearActionsData();
    action_prompt_active = false;
    action_prompt_close_on_execute = true;
    action_prompt_host_only = false;
    action_prompt_command_name_len = 0;
    action_prompt_title_len = 0;
    action_prompt_placeholder_len = 0;
    @memset(&action_prompt_buffer, 0);
    action_prompt_len = 0;
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

// Action overlay selection/trigger
pub var command_selected_index: usize = 0;
pub var command_execute = false;

// Action overlay prompt mode (optional input before executing a command)
pub var action_prompt_active: bool = false;
pub var action_prompt_close_on_execute: bool = true;
pub var action_prompt_host_only: bool = false;

pub var action_prompt_command_name: [128]u8 = undefined;
pub var action_prompt_command_name_len: usize = 0;

pub var action_prompt_title: [64]u8 = undefined;
pub var action_prompt_title_len: usize = 0;

pub var action_prompt_placeholder: [128]u8 = undefined;
pub var action_prompt_placeholder_len: usize = 0;

pub var action_prompt_buffer: [256]u8 = undefined;
pub var action_prompt_len: usize = 0;

// Selection state
pub var selected_index: usize = 0;
pub var focus_on_results = false;

// Plugin-provided results (via IPC)
// Store selected item info when entering details mode (to avoid dangling pointers)
pub var selected_item_title: [256]u8 = undefined;
pub var selected_item_title_len: usize = 0;
pub var selected_item_subtitle: [256]u8 = undefined;
pub var selected_item_subtitle_len: usize = 0;

// Active plugin id for the current details panel (if any).
pub var details_plugin_id: [64]u8 = undefined;
pub var details_plugin_id_len: usize = 0;

// Active plugin item id for the current details panel (if any).
pub var details_item_id: [256]u8 = undefined;
pub var details_item_id_len: usize = 0;

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

pub fn setDetailsPluginId(plugin_id: []const u8) void {
    const n = @min(plugin_id.len, details_plugin_id.len);
    @memcpy(details_plugin_id[0..n], plugin_id[0..n]);
    details_plugin_id_len = n;
}

pub fn clearDetailsPluginId() void {
    details_plugin_id_len = 0;
}

pub fn getDetailsPluginId() []const u8 {
    return details_plugin_id[0..details_plugin_id_len];
}

pub fn setDetailsItemId(item_id: []const u8) void {
    const n = @min(item_id.len, details_item_id.len);
    @memcpy(details_item_id[0..n], item_id[0..n]);
    details_item_id_len = n;
}

pub fn clearDetailsItemId() void {
    details_item_id_len = 0;
}

pub fn getDetailsItemId() []const u8 {
    return details_item_id[0..details_item_id_len];
}

pub const SearchResult = mock.SearchResult;
pub const MockPanelData = mock.PanelData;
pub const MockPanelHeader = mock.PanelHeader;
pub const MockPanelLink = mock.PanelLink;
pub const example_results = mock.example_results;

pub fn panelHeader(p: *const mock.PanelData) mock.PanelHeader {
    return mock.panelHeader(p);
}
pub fn panelBottomInfo(p: *const mock.PanelData) ?[]const u8 {
    return mock.panelBottomInfo(p);
}

pub fn init(allocator: std.mem.Allocator) void {
    @memset(&search_buffer, 0);
    search_initialized = true;
    ipc.plugin_results_allocator = allocator;
    ipc.results_pending = false;
    ipc.panel_pending = false;
    ipc.actions_pending = false;
    ipc.actions_request_queued = false;

    resetPanels();
    command_selected_index = 0;
    command_execute = false;
    action_prompt_active = false;
    action_prompt_close_on_execute = true;
    action_prompt_host_only = false;
    action_prompt_command_name_len = 0;
    action_prompt_title_len = 0;
    action_prompt_placeholder_len = 0;
    @memset(&action_prompt_buffer, 0);
    action_prompt_len = 0;

    selected_item_title_len = 0;
    selected_item_subtitle_len = 0;
    details_plugin_id_len = 0;
    details_item_id_len = 0;
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
    if (ipc.plugin_results_json) |buf| {
        if (ipc.plugin_results_json_allocator) |a| a.free(buf);
        ipc.plugin_results_json = null;
        ipc.plugin_results_json_allocator = null;
    }
    if (ipc.panel_data) |*s| {
        s.deinit();
        ipc.panel_data = null;
    }
    if (ipc.panel_json) |buf| {
        if (ipc.panel_json_allocator) |a| a.free(buf);
        ipc.panel_json = null;
        ipc.panel_json_allocator = null;
    }
    if (ipc.actions_data) |*a| {
        a.deinit();
        ipc.actions_data = null;
    }
    if (ipc.actions_json) |buf| {
        if (ipc.actions_json_allocator) |a| a.free(buf);
        ipc.actions_json = null;
        ipc.actions_json_allocator = null;
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
        // Keep focus keyboard-driven: results updates should not steal focus from the search input.
        // Reset selection so the first result is ready when the user switches focus to main.
        if (!focus_on_results) selected_index = 0;
        return;
    }

    if (std.mem.eql(u8, type_val.string, "panel")) {
        ipc.updatePanelData(allocator, json_str) catch {};
        // If the action overlay is open in plugin details, refresh actions to reflect updates.
        if (nav.action_open and currentPanel() == .details and details_plugin_id_len > 0) {
            ipc.queueActionsRequest();
        }
        return;
    }

    if (std.mem.eql(u8, type_val.string, "actions")) {
        ipc.updateActionsData(allocator, json_str) catch {};
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
