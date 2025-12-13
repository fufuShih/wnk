const std = @import("std");

// Search buffer for the input field
pub var search_buffer: [256]u8 = undefined;
pub var search_len: usize = 0;
pub var search_initialized = false;

pub const PanelMode = enum {
    main,
    list,
    sub,
    command,
    action,
};

pub var panel_mode: PanelMode = .main;
pub var prev_panel_mode: PanelMode = .main;

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

// Mock search results
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

pub fn init(allocator: std.mem.Allocator) void {
    @memset(&search_buffer, 0);
    search_initialized = true;
    plugin_results_allocator = allocator;

    panel_mode = .main;
    prev_panel_mode = .main;
    command_selected_index = 0;
    command_execute = false;
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
        panel_mode = .main;
        focus_on_results = false;
        return;
    }
}
