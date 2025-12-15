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
pub var results_pending: bool = false;
pub var plugin_results_json: ?[]u8 = null;
pub var plugin_results_json_allocator: ?std.mem.Allocator = null;

pub fn updatePluginResults(allocator: std.mem.Allocator, json_str: []const u8) !void {
    const json_copy = try allocator.dupe(u8, json_str);
    errdefer allocator.free(json_copy);

    // Parse only the results messages; ignore other messages.
    var parsed = std.json.parseFromSlice(PluginResultsPayload, allocator, json_copy, .{ .ignore_unknown_fields = true }) catch return;
    errdefer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.type, "results")) {
        parsed.deinit();
        allocator.free(json_copy);
        return;
    }

    if (plugin_results) |*old| {
        old.deinit();
    }
    if (plugin_results_json) |old_json| {
        (plugin_results_json_allocator orelse allocator).free(old_json);
    }
    plugin_results = parsed;
    plugin_results_allocator = allocator;
    plugin_results_json = json_copy;
    plugin_results_json_allocator = allocator;
    results_pending = false;
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

pub const PanelTopPayload = struct {
    /// "header" or "selected"
    type: []const u8 = "header",
    title: ?[]const u8 = null,
    subtitle: ?[]const u8 = null,
};

pub const PanelMainPayload = struct {
    /// "list"
    type: []const u8 = "list",
    layout: ?SubpanelLayout = null,
    items: []SubpanelItem = &.{},
};

pub const PanelBottomPayload = struct {
    /// "none" or "info"
    type: []const u8 = "none",
    text: ?[]const u8 = null,
};

pub const SubpanelPayload = struct {
    type: []const u8,
    /// New structured schema.
    top: ?PanelTopPayload = null,
    main: ?PanelMainPayload = null,
    bottom: ?PanelBottomPayload = null,

    /// Legacy fields (still accepted).
    header: ?[]const u8 = null,
    headerSubtitle: ?[]const u8 = null,
    info: ?[]const u8 = null,
    layout: ?SubpanelLayout = null,
    items: []SubpanelItem = &.{},
};

pub var subpanel_data: ?std.json.Parsed(SubpanelPayload) = null;
pub var subpanel_pending: bool = false;
pub var subpanel_json: ?[]u8 = null;
pub var subpanel_json_allocator: ?std.mem.Allocator = null;

pub const SubpanelView = struct {
    title: []const u8,
    subtitle: []const u8,
    bottom_info: ?[]const u8,
    layout: ?SubpanelLayout,
    items: []const SubpanelItem,
};

pub fn currentSubpanelView() ?SubpanelView {
    const parsed = subpanel_data orelse return null;
    const p = parsed.value;

    const title: []const u8 = if (p.top) |t| blk: {
        if (std.mem.eql(u8, t.type, "header")) break :blk (t.title orelse p.header orelse "");
        break :blk (p.header orelse "");
    } else (p.header orelse "");

    const subtitle: []const u8 = if (p.top) |t| blk: {
        if (std.mem.eql(u8, t.type, "header")) break :blk (t.subtitle orelse p.headerSubtitle orelse "");
        break :blk (p.headerSubtitle orelse "");
    } else (p.headerSubtitle orelse "");

    const bottom_info: ?[]const u8 = if (p.bottom) |b| blk: {
        if (std.mem.eql(u8, b.type, "info")) break :blk (b.text orelse p.info);
        break :blk null;
    } else p.info;

    const layout: ?SubpanelLayout = if (p.main) |m| m.layout orelse p.layout else p.layout;
    const items: []const SubpanelItem = if (p.main) |m| m.items else p.items;

    return .{
        .title = title,
        .subtitle = subtitle,
        .bottom_info = bottom_info,
        .layout = layout,
        .items = items,
    };
}

pub fn updateSubpanelData(allocator: std.mem.Allocator, json_str: []const u8) !void {
    const json_copy = try allocator.dupe(u8, json_str);
    errdefer allocator.free(json_copy);

    var parsed = std.json.parseFromSlice(SubpanelPayload, allocator, json_copy, .{ .ignore_unknown_fields = true }) catch return;
    errdefer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.type, "subpanel")) {
        parsed.deinit();
        allocator.free(json_copy);
        return;
    }

    if (subpanel_data) |*old| {
        old.deinit();
    }
    if (subpanel_json) |old_json| {
        (subpanel_json_allocator orelse allocator).free(old_json);
    }
    subpanel_data = parsed;
    subpanel_json = json_copy;
    subpanel_json_allocator = allocator;
    subpanel_pending = false;
}
