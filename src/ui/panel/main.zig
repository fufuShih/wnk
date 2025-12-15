const std = @import("std");
const dvui = @import("dvui");
const state = @import("state");
const search = @import("../search.zig");
const ui = @import("../components.zig");
const cmds = @import("../commands.zig");
const floating_action_panel = @import("../floating_action_panel.zig");

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

fn renderSubpanelItemsListContent(items: []const state.SubpanelItem, selected_index: usize, flat_index: *usize) void {
    for (items) |item| {
        const i = flat_index.*;
        const id_extra: usize = 20_000 + i;
        const is_selected = i == selected_index;
        renderSubpanelItemCard(item, id_extra, is_selected);
        flat_index.* += 1;
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

fn renderSubpanelItemsGridContent(items: []const state.SubpanelItem, selected_index: usize, columns: usize, gap: usize, flat_index: *usize) void {
    const start = flat_index.*;

    const Ctx = struct { items: []const state.SubpanelItem, selected: usize, start: usize };
    const ctx: Ctx = .{ .items = items, .selected = selected_index, .start = start };
    const gap_f: f32 = @floatFromInt(gap);

    // Wrap each grid with a unique parent to avoid dvui ID collisions across sections.
    var grid_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .id_extra = 40_000 + start });
    defer grid_box.deinit();

    ui.grid(Ctx, ctx, items.len, columns, gap_f, struct {
        fn cell(c: Ctx, idx: usize, _id_extra: usize) void {
            _ = _id_extra;
            const flat = c.start + idx;
            const id_extra: usize = 60_000 + flat;
            const is_selected = flat == c.selected;
            renderSubpanelItemCard(c.items[idx], id_extra, is_selected);
        }
    }.cell);

    flat_index.* += items.len;
}

fn renderSubpanelNodeContent(node: state.ipc.PanelNodePayload, selected_index: usize, flat_index: *usize) void {
    if (std.mem.eql(u8, node.type, "box")) {
        const dir: dvui.Direction = if (node.dir) |d|
            if (std.mem.eql(u8, d, "horizontal")) .horizontal else .vertical
        else
            .vertical;

        const gap: usize = node.gap orelse 12;
        const gap_f: f32 = @floatFromInt(gap);

        var box = dvui.box(@src(), .{ .dir = dir }, .{ .expand = .horizontal, .id_extra = 80_000 + flat_index.* });
        defer box.deinit();

        for (node.children, 0..) |child, i| {
            renderSubpanelNodeContent(child, selected_index, flat_index);
            if (i + 1 < node.children.len and gap > 0) {
                _ = dvui.spacer(@src(), .{ .min_size_content = if (dir == .horizontal) .{ .w = gap_f } else .{ .h = gap_f } });
            }
        }
        return;
    }

    const is_grid: bool = blk: {
        if (std.mem.eql(u8, node.type, "grid")) break :blk true;
        if (!std.mem.eql(u8, node.type, "list")) break :blk false;
        const l = node.layout orelse break :blk false;
        break :blk std.mem.eql(u8, l.mode, "grid");
    };

    if (is_grid) {
        const cols: usize = node.columns orelse if (node.layout) |l| (l.columns orelse 2) else 2;
        const gap: usize = node.gap orelse if (node.layout) |l| (l.gap orelse 12) else 12;
        renderSubpanelItemsGridContent(node.items, selected_index, cols, gap, flat_index);
        return;
    }

    renderSubpanelItemsListContent(node.items, selected_index, flat_index);
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

pub fn renderCommand(sel: ?search.SelectedItem) !void {
    _ = sel;

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

            return;
        }
    }

    if (state.ipc.currentSubpanelView()) |v| {
        const selected = if (state.currentDetails()) |d| d.selected_index else 0;
        state.detailsClampSelection();

        var scroll = dvui.scrollArea(@src(), .{}, .{
            .expand = .both,
            .margin = .{ .x = 20, .y = 0, .w = 20, .h = 20 },
        });
        defer scroll.deinit();

        var flat_index: usize = 0;
        renderSubpanelNodeContent(v.main, selected, &flat_index);
    }
}

pub fn renderPanelBody(panel: state.Panel) !void {
    switch (panel) {
        .search => try search.renderResults(),
        .details => try renderDetails(),
        .commands => try renderCommand(null),
    }
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
