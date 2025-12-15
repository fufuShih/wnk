const std = @import("std");
const dvui = @import("dvui");
const state = @import("state");
const search = @import("search.zig");
const ui = @import("components.zig");
const cmds = @import("commands.zig");
const floating_action_panel = @import("floating_action_panel.zig");

fn renderHeaderCard(title: []const u8, subtitle: []const u8) void {
    var box = ui.beginCard(.{ .margin = .{ .x = 20, .y = 0, .w = 20, .h = 10 } });
    defer box.deinit();

    ui.headerTitle(title);
    if (subtitle.len > 0) {
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 4 } });
        ui.headerSubtitle(subtitle);
    }
}

fn renderSelectedHeader(sel: ?search.SelectedItem) void {
    const title: []const u8 = if (sel) |s| switch (s) {
        .plugin => |item| item.title,
        .mock => |item| item.header_title orelse item.title,
    } else "(no selection)";

    const subtitle: []const u8 = if (sel) |s| switch (s) {
        .plugin => |item| item.subtitle orelse "",
        .mock => |item| item.header_subtitle orelse item.subtitle,
    } else "";

    renderHeaderCard(title, subtitle);
}

fn renderStoredSelectedHeader() void {
    renderHeaderCard(state.getSelectedItemTitle(), state.getSelectedItemSubtitle());
}

fn renderDetailsHeader() void {
    if (state.currentDetails()) |d| {
        if (d.source == .mock) {
            if (d.mock_panel) |p| {
                const h = state.panelHeader(p);
                renderHeaderCard(h.title, h.subtitle orelse "");
                return;
            }
            renderStoredSelectedHeader();
            return;
        }
    }

    if (state.ipc.currentSubpanelView()) |v| {
        renderHeaderCard(v.title, v.subtitle);
    } else {
        renderStoredSelectedHeader();
    }
}

fn clampCommandSelection() void {
    if (cmds.commands.len > 0 and state.command_selected_index >= cmds.commands.len) {
        state.command_selected_index = cmds.commands.len - 1;
    }
}

fn renderSubpanelItemCard(item: state.SubpanelItem, id_extra: usize, is_selected: bool) void {
    var item_box = ui.beginItemRow(.{ .id_extra = id_extra, .is_selected = is_selected });
    defer item_box.deinit();

    var text_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .id_extra = id_extra });
    defer text_box.deinit();

    dvui.label(@src(), "{s}", .{item.title}, .{ .font_style = .title_4, .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff }, .id_extra = id_extra });
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 2 }, .id_extra = id_extra + 1000 });
    dvui.label(@src(), "{s}", .{item.subtitle}, .{ .font_style = .caption, .color_text = .{ .r = 0x88, .g = 0x88, .b = 0x99 }, .id_extra = id_extra + 2000 });
}

fn renderSubpanelItemsList(items: []const state.SubpanelItem) !void {
    var scroll = dvui.scrollArea(@src(), .{}, .{
        .expand = .both,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 20 },
    });
    defer scroll.deinit();

    for (items, 0..) |item, i| {
        const id_extra: usize = 20_000 + i;
        renderSubpanelItemCard(item, id_extra, false);
    }
}

fn renderSubpanelItemsGrid(items: []const state.SubpanelItem, columns: usize, gap: usize) !void {
    var scroll = dvui.scrollArea(@src(), .{}, .{
        .expand = .both,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 20 },
    });
    defer scroll.deinit();

    const Ctx = struct { items: []const state.SubpanelItem };
    const ctx: Ctx = .{ .items = items };
    const gap_f: f32 = @floatFromInt(gap);

    ui.grid(Ctx, ctx, items.len, columns, gap_f, struct {
        fn cell(c: Ctx, idx: usize, id_extra: usize) void {
            renderSubpanelItemCard(c.items[idx], id_extra, false);
        }
    }.cell);
}

fn renderMockItemsList(items: []const state.MockPanelItem, selected_index: usize) !void {
    var scroll = dvui.scrollArea(@src(), .{}, .{
        .expand = .both,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 20 },
    });
    defer scroll.deinit();

    for (items, 0..) |it, i| {
        const id_extra: usize = 90_000 + i;
        const is_selected = i == selected_index;
        renderSubpanelItemCard(.{ .title = it.title, .subtitle = it.subtitle }, id_extra, is_selected);
    }
}

fn renderMockItemsGrid(items: []const state.MockPanelItem, selected_index: usize, columns: usize, gap: usize) !void {
    var scroll = dvui.scrollArea(@src(), .{}, .{
        .expand = .both,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 20 },
    });
    defer scroll.deinit();

    const Ctx = struct { items: []const state.MockPanelItem, selected: usize };
    const ctx: Ctx = .{ .items = items, .selected = selected_index };
    const gap_f: f32 = @floatFromInt(gap);

    ui.grid(Ctx, ctx, items.len, columns, gap_f, struct {
        fn cell(c: Ctx, idx: usize, id_extra: usize) void {
            const is_selected = idx == c.selected;
            renderSubpanelItemCard(.{ .title = c.items[idx].title, .subtitle = c.items[idx].subtitle }, id_extra, is_selected);
        }
    }.cell);
}

pub fn renderSub(sel: ?search.SelectedItem) !void {
    renderSelectedHeader(sel);
}

pub fn renderPanelTop(panel: state.Panel) !void {
    if (panel == .search) {
        try search.renderSearch();
        return;
    }

    // Non-search panels show the nav/hint bar.
    const top_sel: ?search.SelectedItem = if (panel == .details) null else search.getSelectedItem();
    renderTop(panel, top_sel);

    if (panel == .details) {
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 12 } });
        renderDetailsHeader();
        return;
    }

    if (panel == .commands) {
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 12 } });
        renderStoredSelectedHeader();
        return;
    }
}

pub fn renderPanelBody(panel: state.Panel) !void {
    switch (panel) {
        .search => try search.renderResults(),
        .details => try renderDetails(),
        .commands => try renderCommand(null),
    }
}

pub fn renderCommand(sel: ?search.SelectedItem) !void {
    _ = sel;

    // Clamp selection
    clampCommandSelection();

    var list = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .horizontal,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 20 },
    });
    defer list.deinit();

    for (cmds.commands, 0..) |cmd, idx| {
        const is_selected = idx == state.command_selected_index;
        var row = ui.optionRow(cmd.title, is_selected);
        defer row.deinit();

        dvui.label(@src(), "{s}", .{cmd.title}, .{ .font_style = .title_4, .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff } });
    }
}

pub fn renderDetails() !void {
    if (state.currentDetails()) |d| {
        if (d.source == .mock) {
            if (d.mock_panel) |p| {
                const list = state.panelList(p) orelse return;
                const selected = d.selected_index;
                const layout = list.layout;
                if (layout) |l| {
                    if (std.mem.eql(u8, l.mode, "grid")) {
                        try renderMockItemsGrid(list.items, selected, l.columns orelse 2, l.gap orelse 12);
                        return;
                    }
                }

                try renderMockItemsList(list.items, selected);
                return;
            }

            // No panel data: show stored header only.
            return;
        }
    }

    if (state.ipc.currentSubpanelView()) |v| {
        const layout = v.layout;
        if (layout) |l| {
            if (std.mem.eql(u8, l.mode, "grid")) {
                try renderSubpanelItemsGrid(v.items, l.columns orelse 2, l.gap orelse 12);
                return;
            }
        }
        try renderSubpanelItemsList(v.items);
    }
}

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

    dvui.label(@src(), "{s}", .{text}, .{ .font_style = .caption, .color_text = .{ .r = 0xaa, .g = 0xaa, .b = 0xbb } });
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

pub fn renderFloatingAction(sel: ?search.SelectedItem) !void {
    if (!state.nav.action_open) return;

    var anchor = dvui.box(@src(), .{ .dir = .vertical }, .{
        .gravity_x = 1.0,
        .gravity_y = 1.0,
        .margin = .{ .x = 0, .y = 0, .w = 20, .h = 20 },
    });
    defer anchor.deinit();

    try floating_action_panel.render(sel);
}

pub fn renderTop(panel: state.Panel, sel: ?search.SelectedItem) void {
    if (panel == .search) return;

    const list_title: []const u8 = if (sel) |s| switch (s) {
        .plugin => |item| item.title,
        .mock => |item| item.title,
    } else if (state.getSelectedItemTitle().len > 0) state.getSelectedItemTitle() else "Details";

    const title: []const u8 = switch (panel) {
        .details => list_title,
        .commands => "< Commands",
        .search => "<",
    };

    var header = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 0 },
        .background = true,
        .padding = .{ .x = 12, .y = 10, .w = 12, .h = 10 },
        .corner_radius = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
        .color_fill = .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
    });
    defer header.deinit();

    dvui.label(@src(), "< {s}", .{title}, .{ .font_style = .title_4, .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff } });
}
