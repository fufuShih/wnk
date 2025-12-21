/// Search panel renderer (top/main/bottom).
/// Kept in a single file to reduce file hopping while still enforcing region boundaries by API usage.
pub const top = struct {
    const dvui = @import("dvui");
    const state = @import("state");

    const style = @import("../style.zig");

    /// Search panel - top region.
    /// Renders the search input and manages focus between input/results.
    pub fn render() !void {
        var search_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .margin = style.layout.search_margin,
        });
        defer search_box.deinit();

        // Search icon.
        dvui.label(@src(), ">_ ", .{}, .{ .font = dvui.Font.theme(.title), .color_text = style.colors.text_primary });
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 10 } });

        // Search input field with auto-focus.
        var te = dvui.textEntry(@src(), .{
            .text = .{ .buffer = &state.search_buffer },
            .placeholder = "Search for apps, files, and more...",
        }, .{
            .expand = .horizontal,
            .font = dvui.Font.theme(.heading),
            .color_fill = style.colors.surface,
            .color_text = style.colors.text_primary,
        });
        state.search_len = te.len;

        // Auto-focus on search box if not focusing on results.
        if (!state.focus_on_results) {
            dvui.focusWidget(te.wd.id, null, null);
        }

        te.deinit();
    }
};

pub const main = struct {
    const dvui = @import("dvui");
    const state = @import("state");

    const search = @import("../search.zig");
    const regions = @import("../regions.zig");
    const style = @import("../style.zig");

    /// Search panel - main region.
    /// Renders the results list and selection highlight.
    pub fn render() !void {
        search.clampSelectedIndex();

        var scroll = dvui.scrollArea(@src(), .{}, .{
            .expand = .both,
        });
        defer scroll.deinit();

        // Filter and display results.
        var display_index: usize = 0;

        // Plugin results first.
        if (state.ipc.plugin_results) |p| {
            for (p.value.items, 0..) |item, i| {
                const title = item.title;
                const subtitle = item.subtitle orelse "";
                if (!search.matchesCurrentQuery(title, subtitle, item.contextual orelse false)) continue;

                const is_selected = state.focus_on_results and display_index == state.selected_index;
                const id_extra: usize = 10_000 + i;
                display_index += 1;

                const icon = item.icon orelse "=";
                renderResultRow(icon, title, subtitle, id_extra, is_selected);
            }
        }

        // Static mock results.
        for (state.example_results, 0..) |result, i| {
            if (!search.matchesCurrentQuery(result.title, result.subtitle, false)) continue;

            const is_selected = state.focus_on_results and display_index == state.selected_index;
            const id_extra: usize = 1_000 + i;
            display_index += 1;

            renderResultRow(result.icon, result.title, result.subtitle, id_extra, is_selected);
        }
    }

    fn renderResultRow(icon: []const u8, title: []const u8, subtitle: []const u8, id_extra: usize, is_selected: bool) void {
        var item_box = regions.main.beginItemRow(.{ .id_extra = id_extra, .is_selected = is_selected });
        defer item_box.deinit();

        dvui.label(@src(), "{s}", .{icon}, .{ .font = dvui.Font.theme(.title), .id_extra = id_extra });
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 12 }, .id_extra = id_extra + 1000 });

        var text_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .id_extra = id_extra + 2000 });
        defer text_box.deinit();

        dvui.label(@src(), "{s}", .{title}, .{ .font = dvui.Font.theme(.heading), .color_text = style.colors.text_primary, .id_extra = id_extra + 3000 });
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 2 }, .id_extra = id_extra + 4000 });
        dvui.label(@src(), "{s}", .{subtitle}, .{ .font = dvui.Font.theme(.body).larger(-3), .color_text = style.colors.text_muted, .id_extra = id_extra + 5000 });
    }
};

pub const bottom = struct {
    const state = @import("state");

    const actions = @import("../actions.zig");
    const regions = @import("../regions.zig");

    /// Search panel - bottom region.
    /// Shows keyboard hints and current async state (searching vs idle).
    pub fn render() void {
        const show_actions = actions.hasCommand();

        const text: []const u8 = if (state.ipc.results_pending)
            if (show_actions) "Searching…  Tab: focus  Enter: open  k: actions  Esc: hide" else "Searching…  Tab: focus  Enter: open  Esc: hide"
        else if (show_actions)
            "Tab: focus  Enter: open  k: actions  Esc: hide"
        else
            "Tab: focus  Enter: open  Esc: hide";

        regions.bottom.renderBottomHint(text);
    }
};
