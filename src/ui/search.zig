const std = @import("std");
const dvui = @import("dvui");
const state = @import("state");

pub const SelectedItem = union(enum) {
    plugin: state.PluginResultItem,
    mock: state.SearchResult,
};

fn matchesSearch(result_title: []const u8, result_subtitle: []const u8) bool {
    if (state.search_len == 0) return true;
    const search_text = state.search_buffer[0..state.search_len];
    return std.mem.indexOf(u8, result_title, search_text) != null or
        std.mem.indexOf(u8, result_subtitle, search_text) != null;
}

pub fn getSelectedItem() ?SelectedItem {
    var display_index: usize = 0;

    if (state.plugin_results) |p| {
        for (p.value.items) |item| {
            const title = item.title;
            const subtitle = item.subtitle orelse "";
            if (!matchesSearch(title, subtitle)) continue;

            if (display_index == state.selected_index) {
                return .{ .plugin = item };
            }
            display_index += 1;
        }
    }

    for (state.mock_results) |result| {
        if (!matchesSearch(result.title, result.subtitle)) continue;
        if (display_index == state.selected_index) {
            return .{ .mock = result };
        }
        display_index += 1;
    }

    return null;
}

pub fn renderSearch() !void {
    var search_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 0 },
    });
    defer search_box.deinit();

    // Search icon
    dvui.label(@src(), ">_ ", .{}, .{ .font_style = .title });

    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 10 } });

    // Search input field with auto-focus
    var te = dvui.textEntry(@src(), .{
        .text = .{ .buffer = &state.search_buffer },
        .placeholder = "Search for apps, files, and more...",
    }, .{
        .expand = .horizontal,
        .font_style = .title_4,
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
    var scroll = dvui.scrollArea(@src(), .{}, .{
        .expand = .both,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 20 },
    });
    defer scroll.deinit();

    // Count visible results and limit selection index
    var visible_count: usize = 0;

    if (state.plugin_results) |p| {
        for (p.value.items) |item| {
            const title = item.title;
            const subtitle = item.subtitle orelse "";
            if (matchesSearch(title, subtitle)) visible_count += 1;
        }
    }

    for (state.mock_results) |result| {
        if (matchesSearch(result.title, result.subtitle)) visible_count += 1;
    }

    if (visible_count > 0 and state.selected_index >= visible_count) {
        state.selected_index = visible_count - 1;
    }

    // Filter and display results
    var display_index: usize = 0;

    // Plugin results first
    if (state.plugin_results) |p| {
        for (p.value.items, 0..) |item, i| {
            const title = item.title;
            const subtitle = item.subtitle orelse "";
            if (!matchesSearch(title, subtitle)) continue;

            const is_selected = state.focus_on_results and display_index == state.selected_index;
            const id_extra: usize = 10_000 + i;

            var item_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .horizontal,
                .id_extra = id_extra,
                .background = true,
                .border = if (is_selected) .{ .x = 2, .y = 2, .w = 2, .h = 2 } else .{},
                .corner_radius = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
                .padding = .{ .x = 12, .y = 8, .w = 12, .h = 8 },
                .margin = .{ .x = 0, .y = 4, .w = 0, .h = 4 },
                .color_fill = if (is_selected) .{ .r = 0x3a, .g = 0x3a, .b = 0x5e } else .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
                .color_border = if (is_selected) .{ .r = 0x6a, .g = 0x6a, .b = 0xff } else .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
            });
            defer item_box.deinit();

            display_index += 1;

            const icon = item.icon orelse "=";
            dvui.label(@src(), "{s}", .{icon}, .{ .font_style = .title, .id_extra = id_extra });
            _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 12 }, .id_extra = id_extra });

            var text_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .id_extra = id_extra });
            defer text_box.deinit();

            dvui.label(@src(), "{s}", .{title}, .{ .font_style = .title_4, .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff }, .id_extra = id_extra });
            _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 2 }, .id_extra = id_extra + 1000 });
            dvui.label(@src(), "{s}", .{subtitle}, .{ .font_style = .caption, .color_text = .{ .r = 0x88, .g = 0x88, .b = 0x99 }, .id_extra = id_extra + 2000 });
        }
    }

    // Static mock results
    for (state.mock_results, 0..) |result, i| {
        if (!matchesSearch(result.title, result.subtitle)) continue;

        const is_selected = state.focus_on_results and display_index == state.selected_index;
        const id_extra: usize = 1_000 + i;

        var item_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .id_extra = id_extra,
            .background = true,
            .border = if (is_selected) .{ .x = 2, .y = 2, .w = 2, .h = 2 } else .{},
            .corner_radius = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
            .padding = .{ .x = 12, .y = 8, .w = 12, .h = 8 },
            .margin = .{ .x = 0, .y = 4, .w = 0, .h = 4 },
            .color_fill = if (is_selected) .{ .r = 0x3a, .g = 0x3a, .b = 0x5e } else .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
            .color_border = if (is_selected) .{ .r = 0x6a, .g = 0x6a, .b = 0xff } else .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
        });
        defer item_box.deinit();

        display_index += 1;

        dvui.label(@src(), "{s}", .{result.icon}, .{ .font_style = .title, .id_extra = id_extra });
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 12 }, .id_extra = id_extra });

        var text_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .id_extra = id_extra });
        defer text_box.deinit();

        dvui.label(@src(), "{s}", .{result.title}, .{ .font_style = .title_4, .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff }, .id_extra = id_extra });
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 2 }, .id_extra = id_extra + 1000 });
        dvui.label(@src(), "{s}", .{result.subtitle}, .{ .font_style = .caption, .color_text = .{ .r = 0x88, .g = 0x88, .b = 0x99 }, .id_extra = id_extra + 2000 });
    }
}
