const std = @import("std");

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
pub var plugin_results_allocator: ?std.mem.Allocator = null;

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
}

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

