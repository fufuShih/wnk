/// Details panel renderer (top/main/bottom).
/// Kept in a single file to reduce file hopping while still enforcing region boundaries by API usage.
pub const top = struct {
    const state = @import("state");

    const regions = @import("../regions.zig");

    /// Details panel - top region.
    /// Shows a navigation-style header that reflects the current details context.
    pub fn render() !void {
        const h = headerInfo();
        regions.top.renderNavHeader(h.title, h.subtitle);
    }

    fn headerInfo() struct { title: []const u8, subtitle: []const u8 } {
        // Mock details: header comes from the current mock panel (if available).
        if (state.currentDetails()) |d| {
            if (d.source == .mock) {
                if (d.mock_panel) |p| {
                    const h = state.panelHeader(p);
                    return .{ .title = h.title, .subtitle = h.subtitle orelse "" };
                }
                return .{ .title = state.getSelectedItemTitle(), .subtitle = state.getSelectedItemSubtitle() };
            }
        }

        // Plugin details: prefer the IPC-provided header if available.
        if (state.ipc.currentPanelView()) |v| {
            const title = if (v.title.len > 0) v.title else state.getSelectedItemTitle();
            const subtitle = if (v.subtitle.len > 0) v.subtitle else state.getSelectedItemSubtitle();
            return .{ .title = title, .subtitle = subtitle };
        }

        // Fallback to the stored selected item info.
        return .{ .title = state.getSelectedItemTitle(), .subtitle = state.getSelectedItemSubtitle() };
    }
};

pub const main = struct {
    const std = @import("std");
    const dvui = @import("dvui");
    const state = @import("state");

    const regions = @import("../regions.zig");
    const style = @import("../style.zig");

    /// Details panel - main region.
    /// Renders either:
    /// - mock panel trees (local test data), or
    /// - plugin-driven panels (IPC schema: flex/grid/box nodes).
    pub fn render() !void {
        if (state.currentDetails()) |d| {
            if (d.source == .mock) {
                try renderMockDetails(d);
                return;
            }
        }

        try renderPluginDetails();
    }

    fn renderTextItemCard(title: []const u8, subtitle: []const u8, id_extra: usize, is_selected: bool) void {
        var item_box = regions.main.beginItemRow(.{ .id_extra = id_extra, .is_selected = is_selected });
        defer item_box.deinit();

        var text_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .id_extra = id_extra });
        defer text_box.deinit();

        dvui.label(@src(), "{s}", .{title}, .{ .font = dvui.Font.theme(.heading), .color_text = style.colors.text_primary, .id_extra = id_extra });
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 2 }, .id_extra = id_extra + 1000 });
        dvui.label(@src(), "{s}", .{subtitle}, .{ .font = dvui.Font.theme(.body).larger(-3), .color_text = style.colors.text_muted, .id_extra = id_extra + 2000 });
    }

    fn renderPanelItemsFlexContent(items: []const state.PanelItem, selected_index: usize, flat_index: *usize) void {
        // Flex selection uses a flat cursor across the whole (possibly nested) node tree.
        for (items) |item| {
            const i = flat_index.*;
            const id_extra: usize = 20_000 + i;
            const is_selected = i == selected_index;
            renderTextItemCard(item.title, item.subtitle, id_extra, is_selected);
            flat_index.* += 1;
        }
    }

    fn renderPanelItemsGridContent(node_id: usize, items: []const state.PanelItem, selected_index: usize, columns: usize, gap: usize, flat_index: *usize) void {
        const start = flat_index.*;

        const Ctx = struct { items: []const state.PanelItem, selected: usize, start: usize };
        const ctx: Ctx = .{ .items = items, .selected = selected_index, .start = start };
        const gap_f: f32 = @floatFromInt(gap);

        // Wrap each grid with a unique parent to avoid dvui ID collisions across sections.
        var grid_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .id_extra = 40_000 + node_id });
        defer grid_box.deinit();

        regions.main.grid(Ctx, ctx, items.len, columns, gap_f, struct {
            fn cell(c: Ctx, idx: usize, _id_extra: usize) void {
                _ = _id_extra;
                const flat = c.start + idx;
                const id_extra: usize = 60_000 + flat;
                const is_selected = flat == c.selected;
                renderTextItemCard(c.items[idx].title, c.items[idx].subtitle, id_extra, is_selected);
            }
        }.cell);

        flat_index.* += items.len;
    }

    fn renderPanelNodeContent(node: state.ipc.PanelNodePayload, selected_index: usize, flat_index: *usize, node_serial: *usize) void {
        // NOTE: The IPC schema uses stringly-typed node kinds for flexibility.
        // Keep parsing here local to the details panel to avoid leaking UI concerns into state.
        const node_id = node_serial.*;
        node_serial.* += 1;

        if (std.mem.eql(u8, node.type, "box")) {
            const is_horizontal = if (node.dir) |d| std.mem.eql(u8, d, "horizontal") else false;

            const gap: usize = node.gap orelse 12;
            const gap_f: f32 = @floatFromInt(gap);

            var box = dvui.box(@src(), .{ .dir = if (is_horizontal) .horizontal else .vertical }, .{
                .expand = .horizontal,
                .id_extra = 80_000 + node_id,
            });
            defer box.deinit();

            for (node.children, 0..) |child, i| {
                renderPanelNodeContent(child, selected_index, flat_index, node_serial);
                if (i + 1 < node.children.len and gap > 0) {
                    _ = dvui.spacer(@src(), .{ .min_size_content = if (is_horizontal) .{ .w = gap_f } else .{ .h = gap_f } });
                }
            }
            return;
        }

        if (std.mem.eql(u8, node.type, "grid")) {
            const cols: usize = node.columns orelse 2;
            const gap: usize = node.gap orelse 12;
            renderPanelItemsGridContent(node_id, node.items, selected_index, cols, gap, flat_index);
            return;
        }

        if (std.mem.eql(u8, node.type, "flex")) {
            renderPanelItemsFlexContent(node.items, selected_index, flat_index);
        }
    }

    fn renderMockItemsList(items: []const state.MockPanelItem, selected_index: usize) !void {
        var scroll = dvui.scrollArea(@src(), .{}, .{
            .expand = .both,
        });
        defer scroll.deinit();

        for (items, 0..) |it, i| {
            const id_extra: usize = 90_000 + i;
            const is_selected = i == selected_index;
            renderTextItemCard(it.title, it.subtitle, id_extra, is_selected);
        }
    }

    fn renderMockItemsGrid(items: []const state.MockPanelItem, selected_index: usize, columns: usize, gap: usize) !void {
        var scroll = dvui.scrollArea(@src(), .{}, .{
            .expand = .both,
        });
        defer scroll.deinit();

        const Ctx = struct { items: []const state.MockPanelItem, selected: usize };
        const ctx: Ctx = .{ .items = items, .selected = selected_index };
        const gap_f: f32 = @floatFromInt(gap);

        regions.main.grid(Ctx, ctx, items.len, columns, gap_f, struct {
            fn cell(c: Ctx, idx: usize, id_extra: usize) void {
                const is_selected = idx == c.selected;
                renderTextItemCard(c.items[idx].title, c.items[idx].subtitle, id_extra, is_selected);
            }
        }.cell);
    }

    fn renderMockDetails(d: *state.DetailsPanel) !void {
        const p = d.mock_panel orelse return;
        const list = state.panelList(p) orelse return;

        state.detailsClampSelection();
        const selected = d.selected_index;

        if (list.layout) |l| {
            if (std.mem.eql(u8, l.mode, "grid")) {
                try renderMockItemsGrid(list.items, selected, l.columns orelse 2, l.gap orelse 12);
                return;
            }
        }

        try renderMockItemsList(list.items, selected);
    }

    fn renderPluginDetails() !void {
        const v = state.ipc.currentPanelView() orelse return;

        state.detailsClampSelection();
        const selected = if (state.currentDetails()) |d| d.selected_index else 0;

        var scroll = dvui.scrollArea(@src(), .{}, .{
            .expand = .both,
        });
        defer scroll.deinit();

        var flat_index: usize = 0;
        var node_serial: usize = 0;
        renderPanelNodeContent(v.main, selected, &flat_index, &node_serial);
    }
};

pub const bottom = struct {
    const state = @import("state");

    const actions = @import("../actions.zig");
    const regions = @import("../regions.zig");

    /// Details panel - bottom region.
    /// Uses plugin-provided hint text when available, otherwise shows defaults.
    pub fn render() void {
        const text = textForDetails() orelse return;
        regions.bottom.renderBottomHint(text);
    }

    fn defaultHint() []const u8 {
        // Only show the action hint when the current main selection can actually open the overlay.
        return if (actions.hasCommand())
            "Enter: open  W/S: move  k: actions  Esc: back"
        else
            "Enter: open  W/S: move  Esc: back";
    }

    fn textForDetails() ?[]const u8 {
        if (state.currentDetails()) |d| {
            if (d.source == .mock) {
                const p = d.mock_panel orelse return null;
                return switch (p.bottom) {
                    .none => defaultHint(),
                    .info => |txt| txt,
                };
            }
        }

        if (state.ipc.panel_pending) return "Loading…";
        if (state.ipc.currentPanelView()) |v| return v.bottom_info orelse defaultHint();
        return defaultHint();
    }
};
