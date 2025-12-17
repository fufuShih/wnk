const state = @import("state");

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
