const std = @import("std");
const dvui = @import("dvui");
const state = @import("state");
const search = @import("search.zig");
const ui = @import("components.zig");
const cmds = @import("commands.zig");

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

fn renderSubpanelItemCard(item: state.SubpanelItem, id_extra: usize) void {
    var item_box = ui.beginItemRow(.{ .id_extra = id_extra, .is_selected = false });
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
        renderSubpanelItemCard(item, id_extra);
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
            renderSubpanelItemCard(c.items[idx], id_extra);
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
}

pub fn renderPanelBody(panel: state.Panel) !void {
    switch (panel) {
        .search => try search.renderResults(),
        .details => try renderDetails(),
        .commands => try renderCommand(null),
    }
}

pub fn renderCommand(sel: ?search.SelectedItem) !void {
    if (sel != null) {
        renderSelectedHeader(sel);
    } else {
        renderStoredSelectedHeader();
    }

    // Clamp selection
    if (cmds.commands.len > 0 and state.command_selected_index >= cmds.commands.len) {
        state.command_selected_index = cmds.commands.len - 1;
    }

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
    // Render header
    if (state.subpanel_data) |s| {
        renderHeaderCard(s.value.header, s.value.headerSubtitle orelse "");
    } else {
        // Pending/fallback share the same stored header.
        renderStoredSelectedHeader();
    }

    // Render items
    if (state.subpanel_data) |s| {
        const layout = s.value.layout;
        if (layout) |l| {
            if (std.mem.eql(u8, l.mode, "grid")) {
                const cols = l.columns orelse 2;
                const gap = l.gap orelse 12;
                try renderSubpanelItemsGrid(s.value.items, cols, gap);
                return;
            }
        }

        try renderSubpanelItemsList(s.value.items);
    }
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

    const hint: []const u8 = switch (panel) {
        .details => "Enter: commands  k: actions  Esc: back",
        .commands => "Enter: run  W/S: move  Esc: back",
        .search => "",
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

    // Flexible space pushes hint to the far right.
    var flex = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
    defer flex.deinit();

    if (hint.len > 0) {
        dvui.label(@src(), "{s}", .{hint}, .{ .font_style = .caption, .color_text = .{ .r = 0xaa, .g = 0xaa, .b = 0xbb } });
    }
}
