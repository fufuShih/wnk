const dvui = @import("dvui");
const state = @import("state");

fn panelBottomInfo(panel: state.Panel) ?[]const u8 {
    switch (panel) {
        .search => {
            if (state.ipc.results_pending) return "Searching…  Tab: focus  Enter: open  Esc: hide";
            return "Tab: focus  Enter: open  Esc: hide";
        },
        .commands => return "Enter: run  W/S: move  Esc: back",
        .details => {},
    }

    if (state.currentDetails()) |d| {
        if (d.source == .mock) {
            const p = d.mock_panel orelse return null;
            return switch (p.bottom) {
                .none => "Enter: open  W/S: move  k: actions  Esc: back",
                .info => |txt| txt,
            };
        }
    }

    if (state.ipc.subpanel_pending) return "Loading…";
    if (state.ipc.currentSubpanelView()) |v| return v.bottom_info orelse "Enter: open  W/S: move  k: actions  Esc: back";
    return "Enter: open  W/S: move  k: actions  Esc: back";
}

fn renderBottomBar(text: []const u8) void {
    var bar = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 20 },
        .background = true,
        .padding = .{ .x = 12, .y = 10, .w = 12, .h = 10 },
        .corner_radius = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
        .color_fill = .{ .r = 0x24, .g = 0x24, .b = 0x34 },
    });
    defer bar.deinit();

    dvui.label(@src(), "{s}", .{text}, .{ .font = dvui.Font.theme(.body).larger(-3), .color_text = .{ .r = 0xaa, .g = 0xaa, .b = 0xbb } });
}

pub fn renderPanelBottom(panel: state.Panel) void {
    const text = panelBottomInfo(panel) orelse return;

    var anchor = dvui.box(@src(), .{ .dir = .vertical }, .{
        .gravity_x = 0.0,
        .gravity_y = 1.0,
        .expand = .horizontal,
    });
    defer anchor.deinit();

    renderBottomBar(text);
}

