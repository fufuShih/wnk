const std = @import("std");
const state = @import("state");

pub const SelectedItem = union(enum) {
    plugin: state.PluginResultItem,
    mock: state.SearchResult,
};

/// Returns the active query slice from the global search buffer.
pub fn currentQuery() []const u8 {
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

/// Convenience helper for renderers: checks whether an item matches the current query.
pub fn matchesCurrentQuery(result_title: []const u8, result_subtitle: []const u8) bool {
    return matchesSearch(result_title, result_subtitle, currentQuery());
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
    const query = currentQuery();
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

    const query = currentQuery();
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
