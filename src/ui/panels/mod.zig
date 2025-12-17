const dvui = @import("dvui");
const state = @import("state");

const actions = @import("../actions.zig");
const regions = @import("../regions.zig");
const style = @import("../style.zig");

const search_panel = @import("search.zig");
const details_panel = @import("details.zig");

/// UI panel dispatcher.
/// Panels are split into top/main/bottom regions, but each panel keeps its regions in a single file.
pub fn renderTop(panel: state.Panel) !void {
    switch (panel) {
        .search => try search_panel.top.render(),
        .details => try details_panel.top.render(),
    }
}

pub fn renderMain(panel: state.Panel) !void {
    const main_id_extra: usize = switch (panel) {
        .search => 10,
        .details => 20,
    };

    var main_box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .id_extra = main_id_extra,
        .padding = style.layout.content_margin,
    });
    defer main_box.deinit();

    // Keep actual dvui focus aligned with the logical "main focused" state.
    const want_focus = switch (panel) {
        .search => state.focus_on_results,
        .details => true,
    };
    if (want_focus and dvui.focusedWidgetId() != main_box.wd.id) {
        dvui.focusWidget(main_box.wd.id, null, null);
    }

    switch (panel) {
        .search => try search_panel.main.render(),
        .details => try details_panel.main.render(),
    }
}

pub fn renderBottom(panel: state.Panel) void {
    switch (panel) {
        .search => search_panel.bottom.render(),
        .details => details_panel.bottom.render(),
    }
}

/// Renders overlays that are not part of any panel region (e.g., action overlay).
pub fn renderOverlays() !void {
    try renderActionOverlay();
}

fn renderActionOverlay() !void {
    // This overlay is not a panel/region; it is rendered on demand when the main selection provides actions.
    if (!state.nav.action_open) return;

    // Defensive: if the context changed while open, close the overlay.
    if (!actions.hasCommand()) {
        state.nav.action_open = false;
        return;
    }

    var anchor = dvui.box(@src(), .{ .dir = .vertical }, .{
        .gravity_x = 1.0,
        .gravity_y = 1.0,
        .margin = style.layout.overlay_margin,
    });
    defer anchor.deinit();

    // A compact, popup-like panel intended to be placed in the bottom-right.
    var panel = dvui.box(@src(), .{ .dir = .vertical }, .{
        .background = true,
        .padding = style.metrics.card_padding,
        .corner_radius = .{ .x = 10, .y = 10, .w = 10, .h = 10 },
        .color_fill = style.colors.surface,
    });
    defer panel.deinit();

    dvui.label(@src(), "Actions", .{}, .{ .font = dvui.Font.theme(.heading), .color_text = style.colors.text_primary });
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 6 } });

    renderActionList(actions.actions());

    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 6 } });
    dvui.label(@src(), "Enter: run  W/S: move  Esc: back", .{}, .{ .font = dvui.Font.theme(.body).larger(-3), .color_text = style.colors.text_hint });
}

fn clampActionSelection(actions_count: usize) void {
    if (actions_count == 0) {
        state.command_selected_index = 0;
        return;
    }

    if (state.command_selected_index >= actions_count) {
        state.command_selected_index = actions_count - 1;
    }
}

fn renderActionList(list: []const actions.Command) void {
    clampActionSelection(list.len);

    for (list, 0..) |cmd, idx| {
        const is_selected = idx == state.command_selected_index;
        const id_extra: usize = 110_000 + idx;

        var row = regions.main.beginOptionRow(id_extra, is_selected);
        defer row.deinit();

        dvui.label(@src(), "{s}", .{cmd.title}, .{
            .font = dvui.Font.theme(.heading),
            .color_text = style.colors.text_primary,
            .id_extra = 120_000 + idx,
        });
    }
}
