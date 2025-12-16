const std = @import("std");
const dvui = @import("dvui");
const state = @import("state");
const ui = @import("components.zig");

pub const SelectedItem = union(enum) {
    plugin: state.PluginResultItem,
    mock: state.SearchResult,
};

fn querySlice() []const u8 {
    return state.search_buffer[0..state.search_len];
}

fn toLowerByte(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;

    var i: usize = 0;
    outer: while (i <= haystack.len - needle.len) : (i += 1) {
        for (needle, 0..) |nc, j| {
            if (toLowerByte(haystack[i + j]) != toLowerByte(nc)) {
                continue :outer;
            }
        }
        return true;
    }
    return false;
}

fn matchesSearch(result_title: []const u8, result_subtitle: []const u8, query: []const u8) bool {
    if (query.len == 0) return true;
    return containsIgnoreCase(result_title, query) or
        containsIgnoreCase(result_subtitle, query);
}

fn visibleResultsCount(query: []const u8) usize {
    var visible_count: usize = 0;

    if (state.ipc.plugin_results) |p| {
        for (p.value.items) |item| {
            const title = item.title;
            const subtitle = item.subtitle orelse "";
            if (matchesSearch(title, subtitle, query)) visible_count += 1;
        }
    }

    for (state.example_results) |result| {
        if (matchesSearch(result.title, result.subtitle, query)) visible_count += 1;
    }

    return visible_count;
}

pub fn clampSelectedIndex() void {
    const query = querySlice();
    const visible_count = visibleResultsCount(query);

    if (visible_count == 0) {
        state.selected_index = 0;
        return;
    }

    if (state.selected_index >= visible_count) {
        state.selected_index = visible_count - 1;
    }
}

pub fn getSelectedItem() ?SelectedItem {
    clampSelectedIndex();

    const query = querySlice();
    var display_index: usize = 0;

    if (state.ipc.plugin_results) |p| {
        for (p.value.items) |item| {
            const title = item.title;
            const subtitle = item.subtitle orelse "";
            if (!matchesSearch(title, subtitle, query)) continue;

            if (display_index == state.selected_index) {
                return .{ .plugin = item };
            }
            display_index += 1;
        }
    }

    for (state.example_results) |result| {
        if (!matchesSearch(result.title, result.subtitle, query)) continue;
        if (display_index == state.selected_index) {
            return .{ .mock = result };
        }
        display_index += 1;
    }

    return null;
}

fn renderResultRow(icon: []const u8, title: []const u8, subtitle: []const u8, id_extra: usize, is_selected: bool) void {
    var item_box = ui.beginItemRow(.{ .id_extra = id_extra, .is_selected = is_selected });
    defer item_box.deinit();

    dvui.label(@src(), "{s}", .{icon}, .{ .font = dvui.Font.theme(.title), .id_extra = id_extra });
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 12 }, .id_extra = id_extra + 1000 });

    var text_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .id_extra = id_extra + 2000 });
    defer text_box.deinit();

    dvui.label(@src(), "{s}", .{title}, .{ .font = dvui.Font.theme(.heading), .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff }, .id_extra = id_extra + 3000 });
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 2 }, .id_extra = id_extra + 4000 });
    dvui.label(@src(), "{s}", .{subtitle}, .{ .font = dvui.Font.theme(.body).larger(-3), .color_text = .{ .r = 0x88, .g = 0x88, .b = 0x99 }, .id_extra = id_extra + 5000 });
}

pub fn renderSearch() !void {
    var search_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 0 },
    });
    defer search_box.deinit();

    // Search icon
    dvui.label(@src(), ">_ ", .{}, .{ .font = dvui.Font.theme(.title) });

    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 10 } });

    // Search input field with auto-focus
    var te = dvui.textEntry(@src(), .{
        .text = .{ .buffer = &state.search_buffer },
        .placeholder = "Search for apps, files, and more...",
    }, .{
        .expand = .horizontal,
        .font = dvui.Font.theme(.heading),
        .color_fill = .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
        .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff },
    });
    state.search_len = te.len;

    // Auto-focus on search box if not focusing on results
    if (!state.focus_on_results) {
        dvui.focusWidget(te.wd.id, null, null);
    }

    te.deinit();
}

pub fn renderResults() !void {
    clampSelectedIndex();
    const query = querySlice();

    var scroll = dvui.scrollArea(@src(), .{}, .{
        .expand = .both,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 20 },
    });
    defer scroll.deinit();

    // Filter and display results
    var display_index: usize = 0;

    // Plugin results first
    if (state.ipc.plugin_results) |p| {
        for (p.value.items, 0..) |item, i| {
            const title = item.title;
            const subtitle = item.subtitle orelse "";
            if (!matchesSearch(title, subtitle, query)) continue;

            const is_selected = state.focus_on_results and display_index == state.selected_index;
            const id_extra: usize = 10_000 + i;

            display_index += 1;

            const icon = item.icon orelse "=";
            renderResultRow(icon, title, subtitle, id_extra, is_selected);
        }
    }

    // Static mock results
    for (state.example_results, 0..) |result, i| {
        if (!matchesSearch(result.title, result.subtitle, query)) continue;

        const is_selected = state.focus_on_results and display_index == state.selected_index;
        const id_extra: usize = 1_000 + i;

        display_index += 1;

        renderResultRow(result.icon, result.title, result.subtitle, id_extra, is_selected);
    }
}
