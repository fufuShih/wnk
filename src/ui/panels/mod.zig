const dvui = @import("dvui");
const state = @import("state");

const style = @import("../style.zig");

const search_panel = @import("search.zig");
const details_panel = @import("details.zig");
const action_overlay = @import("../overlays/action_overlay.zig");

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
    try action_overlay.render();
}
