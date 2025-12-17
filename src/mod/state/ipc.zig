const std = @import("std");

pub const PluginResultItem = struct {
    pluginId: []const u8 = "",
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
    id: ?[]const u8 = null,
    title: []const u8,
    subtitle: []const u8,
};

pub const ActionItem = struct {
    name: []const u8,
    title: []const u8,
    /// Optional payload string; passed through to Bun as the command `text` field.
    text: ?[]const u8 = null,
    /// Optional behavior override; defaults to true in the host.
    close_on_execute: ?bool = null,
};

pub const ActionsPayload = struct {
    type: []const u8,
    token: u64 = 0,
    pluginId: []const u8 = "",
    items: []ActionItem = &.{},
};

pub var actions_data: ?std.json.Parsed(ActionsPayload) = null;
pub var actions_pending: bool = false;
pub var actions_request_queued: bool = false;
pub var actions_json: ?[]u8 = null;
pub var actions_json_allocator: ?std.mem.Allocator = null;
pub var actions_token_expected: u64 = 0;
var actions_token_counter: u64 = 0;

pub fn nextActionsToken() u64 {
    actions_token_counter +%= 1;
    actions_token_expected = actions_token_counter;
    return actions_token_expected;
}

pub fn clearActionsData() void {
    if (actions_data) |*a| {
        a.deinit();
        actions_data = null;
    }
    if (actions_json) |old_json| {
        if (actions_json_allocator) |a| a.free(old_json);
        actions_json = null;
        actions_json_allocator = null;
    }
    actions_pending = false;
    actions_request_queued = false;
    actions_token_expected = 0;
}

pub fn queueActionsRequest() void {
    actions_request_queued = true;
}

pub fn updateActionsData(allocator: std.mem.Allocator, json_str: []const u8) !void {
    const json_copy = try allocator.dupe(u8, json_str);
    errdefer allocator.free(json_copy);

    var parsed = std.json.parseFromSlice(ActionsPayload, allocator, json_copy, .{ .ignore_unknown_fields = true }) catch return;
    errdefer parsed.deinit();

    if (!std.mem.eql(u8, parsed.value.type, "actions")) {
        parsed.deinit();
        allocator.free(json_copy);
        return;
    }

    // Drop out-of-date responses (e.g., overlay was reopened).
    if (parsed.value.token != actions_token_expected) {
        parsed.deinit();
        allocator.free(json_copy);
        return;
    }

    if (actions_data) |*old| {
        old.deinit();
    }
    if (actions_json) |old_json| {
        (actions_json_allocator orelse allocator).free(old_json);
    }

    actions_data = parsed;
    actions_json = json_copy;
    actions_json_allocator = allocator;
    actions_pending = false;
}

pub const PanelTopPayload = struct {
    /// "header" or "selected"
    type: []const u8 = "header",
    title: ?[]const u8 = null,
    subtitle: ?[]const u8 = null,
};

pub const PanelNodePayload = struct {
    /// "flex", "grid", or "box"
    type: []const u8 = "flex",

    /// Used when `type == "grid"`.
    columns: ?usize = null,
    /// Grid cell gap, or child spacing when `type == "box"`.
    gap: ?usize = null,

    /// Used when `type == "box"`.
    dir: ?[]const u8 = null,
    children: []PanelNodePayload = &.{},

    /// Used when `type == "flex"` or `type == "grid"`.
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
    main: ?PanelNodePayload = null,
    bottom: ?PanelBottomPayload = null,
};

pub var subpanel_data: ?std.json.Parsed(SubpanelPayload) = null;
pub var subpanel_pending: bool = false;
pub var subpanel_json: ?[]u8 = null;
pub var subpanel_json_allocator: ?std.mem.Allocator = null;

pub const SubpanelView = struct {
    title: []const u8,
    subtitle: []const u8,
    bottom_info: ?[]const u8,
    main: PanelNodePayload,
};

pub fn currentSubpanelView() ?SubpanelView {
    const parsed = subpanel_data orelse return null;
    const p = parsed.value;

    const title: []const u8 = if (p.top) |t|
        if (std.mem.eql(u8, t.type, "header")) (t.title orelse "") else ""
    else
        "";

    const subtitle: []const u8 = if (p.top) |t|
        if (std.mem.eql(u8, t.type, "header")) (t.subtitle orelse "") else ""
    else
        "";

    const bottom_info: ?[]const u8 = if (p.bottom) |b|
        if (std.mem.eql(u8, b.type, "info")) b.text else null
    else
        null;

    const main: PanelNodePayload = p.main orelse .{};

    return .{
        .title = title,
        .subtitle = subtitle,
        .bottom_info = bottom_info,
        .main = main,
    };
}

pub fn subpanelItemsCount(node: PanelNodePayload) usize {
    if (std.mem.eql(u8, node.type, "box")) {
        var total: usize = 0;
        for (node.children) |c| total += subpanelItemsCount(c);
        return total;
    }

    if (std.mem.eql(u8, node.type, "flex") or std.mem.eql(u8, node.type, "grid")) {
        return node.items.len;
    }

    // Unsupported node kinds are treated as empty to avoid selection mismatch.
    return 0;
}

/// Returns the item at a given flat index within a PanelNode tree.
/// This mirrors `subpanelItemsCount()` by traversing `box` children in order.
pub fn subpanelItemAtIndex(node: PanelNodePayload, flat_index: usize) ?SubpanelItem {
    if (std.mem.eql(u8, node.type, "box")) {
        var cursor = flat_index;
        for (node.children) |c| {
            const count = subpanelItemsCount(c);
            if (cursor < count) return subpanelItemAtIndex(c, cursor);
            cursor -= count;
        }
        return null;
    }

    if (!(std.mem.eql(u8, node.type, "flex") or std.mem.eql(u8, node.type, "grid"))) {
        return null;
    }

    if (flat_index >= node.items.len) return null;
    return node.items[flat_index];
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
