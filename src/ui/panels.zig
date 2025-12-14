const dvui = @import("dvui");
const state = @import("state");
const search = @import("search.zig");
const ui = @import("components.zig");
const cmds = @import("commands.zig");

fn renderSelectedHeader(sel: ?search.SelectedItem) void {
    var box = ui.beginCard(.{ .margin = .{ .x = 20, .y = 0, .w = 20, .h = 10 } });
    defer box.deinit();

    const title: []const u8 = if (sel) |s| switch (s) {
        .plugin => |item| item.title,
        .mock => |item| item.header_title orelse item.title,
    } else "(no selection)";

    const subtitle: []const u8 = if (sel) |s| switch (s) {
        .plugin => |item| item.subtitle orelse "",
        .mock => |item| item.header_subtitle orelse item.subtitle,
    } else "";

    ui.headerTitle(title);
    if (subtitle.len > 0) {
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 4 } });
        ui.headerSubtitle(subtitle);
    }
}

pub fn renderSub(sel: ?search.SelectedItem) !void {
    renderSelectedHeader(sel);
}

pub fn renderCommand(sel: ?search.SelectedItem) !void {
    renderSelectedHeader(sel);

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

pub fn renderList(_: ?search.SelectedItem) !void {
    // Render subpanel data if available
    if (state.subpanel_data) |s| {
        // Header card
        var header_box = ui.beginCard(.{ .margin = .{ .x = 20, .y = 0, .w = 20, .h = 10 } });
        defer header_box.deinit();

        ui.headerTitle(s.value.header);
        if (s.value.headerSubtitle) |sub| {
            _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 4 } });
            ui.headerSubtitle(sub);
        }
    } else if (state.subpanel_pending) {
        // Loading state - use stored selected item info
        var box = ui.beginCard(.{ .margin = .{ .x = 20, .y = 0, .w = 20, .h = 10 } });
        defer box.deinit();
        ui.headerTitle(state.getSelectedItemTitle());
        const subtitle = state.getSelectedItemSubtitle();
        if (subtitle.len > 0) {
            _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 4 } });
            ui.headerSubtitle(subtitle);
        }
    } else {
        // Fallback - use stored selected item info
        var box = ui.beginCard(.{ .margin = .{ .x = 20, .y = 0, .w = 20, .h = 10 } });
        defer box.deinit();
        ui.headerTitle(state.getSelectedItemTitle());
        const subtitle = state.getSelectedItemSubtitle();
        if (subtitle.len > 0) {
            _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 4 } });
            ui.headerSubtitle(subtitle);
        }
    }

    // Render subpanel items
    if (state.subpanel_data) |s| {
        var scroll = dvui.scrollArea(@src(), .{}, .{
            .expand = .both,
            .margin = .{ .x = 20, .y = 0, .w = 20, .h = 20 },
        });
        defer scroll.deinit();

        for (s.value.items, 0..) |item, i| {
            const id_extra: usize = 20_000 + i;

            var item_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .horizontal,
                .id_extra = id_extra,
                .background = true,
                .corner_radius = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
                .padding = .{ .x = 12, .y = 8, .w = 12, .h = 8 },
                .margin = .{ .x = 0, .y = 4, .w = 0, .h = 4 },
                .color_fill = .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
            });
            defer item_box.deinit();

            var text_box = dvui.box(@src(), .{ .dir = .vertical }, .{ .expand = .horizontal, .id_extra = id_extra });
            defer text_box.deinit();

            dvui.label(@src(), "{s}", .{item.title}, .{ .font_style = .title_4, .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff }, .id_extra = id_extra });
            _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 2 }, .id_extra = id_extra + 1000 });
            dvui.label(@src(), "{s}", .{item.subtitle}, .{ .font_style = .caption, .color_text = .{ .r = 0x88, .g = 0x88, .b = 0x99 }, .id_extra = id_extra + 2000 });
        }
    }
}

pub fn renderTop(mode: state.PanelMode, sel: ?search.SelectedItem) void {
    if (mode == .main or mode == .action) return;

    const list_title: []const u8 = if (sel) |s| switch (s) {
        .plugin => |item| item.title,
        .mock => |item| item.title,
    } else if (state.getSelectedItemTitle().len > 0) state.getSelectedItemTitle() else "Details";

    const title: []const u8 = switch (mode) {
        .list => list_title,
        .sub => "< Item",
        .command => "< Commands",
        else => "<",
    };

    const hint: []const u8 = switch (mode) {
        .list => "Enter/k: actions  Esc: back",
        .sub => "Enter: commands  k: actions  Esc: back",
        .command => "Enter: run  W/S: move  Esc: back",
        else => "",
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
