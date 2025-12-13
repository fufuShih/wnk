const dvui = @import("dvui");
const state = @import("../state.zig");
const results = @import("results.zig");

pub const Command = struct {
    // Sent to Bun as { type: "command", name, text }
    name: []const u8,
    title: []const u8,
};

const commands = [_]Command{
    .{ .name = "setSearchText", .title = "Use as query" },
};

pub fn getCommand(idx: usize) ?Command {
    if (idx >= commands.len) return null;
    return commands[idx];
}

fn renderSelectedHeader(sel: ?results.SelectedItem) void {
    var box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .horizontal,
        .background = true,
        .padding = .{ .x = 12, .y = 10, .w = 12, .h = 10 },
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 10 },
        .corner_radius = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
        .color_fill = .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
    });
    defer box.deinit();

    const title: []const u8 = if (sel) |s| switch (s) {
        .plugin => |item| item.title,
        .mock => |item| item.title,
    } else "(no selection)";

    const subtitle: []const u8 = if (sel) |s| switch (s) {
        .plugin => |item| item.subtitle orelse "",
        .mock => |item| item.subtitle,
    } else "";

    dvui.label(@src(), "{s}", .{title}, .{ .font_style = .title_3, .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff } });
    if (subtitle.len > 0) {
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 4 } });
        dvui.label(@src(), "{s}", .{subtitle}, .{ .font_style = .caption, .color_text = .{ .r = 0x88, .g = 0x88, .b = 0x99 } });
    }
}

pub fn renderSub(sel: ?results.SelectedItem) !void {
    renderSelectedHeader(sel);

    var hint = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .horizontal,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 20 },
        .background = true,
        .padding = .{ .x = 12, .y = 10, .w = 12, .h = 10 },
        .corner_radius = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
        .color_fill = .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
    });
    defer hint.deinit();

    dvui.label(@src(), "Enter: commands", .{}, .{ .font_style = .caption, .color_text = .{ .r = 0xaa, .g = 0xaa, .b = 0xbb } });
    dvui.label(@src(), "k: commands", .{}, .{ .font_style = .caption, .color_text = .{ .r = 0xaa, .g = 0xaa, .b = 0xbb } });
    dvui.label(@src(), "Esc: back", .{}, .{ .font_style = .caption, .color_text = .{ .r = 0xaa, .g = 0xaa, .b = 0xbb } });
}

pub fn renderCommand(sel: ?results.SelectedItem) !void {
    renderSelectedHeader(sel);

    // Clamp selection
    if (commands.len > 0 and state.command_selected_index >= commands.len) {
        state.command_selected_index = commands.len - 1;
    }

    var list = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .horizontal,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 20 },
    });
    defer list.deinit();

    for (commands, 0..) |cmd, idx| {
        const is_selected = idx == state.command_selected_index;
        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .background = true,
            .padding = .{ .x = 12, .y = 10, .w = 12, .h = 10 },
            .margin = .{ .x = 0, .y = 4, .w = 0, .h = 4 },
            .corner_radius = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
            .border = if (is_selected) .{ .x = 2, .y = 2, .w = 2, .h = 2 } else .{},
            .color_fill = if (is_selected) .{ .r = 0x3a, .g = 0x3a, .b = 0x5e } else .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
            .color_border = if (is_selected) .{ .r = 0x6a, .g = 0x6a, .b = 0xff } else .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
        });
        defer row.deinit();

        dvui.label(@src(), "{s}", .{cmd.title}, .{ .font_style = .title_4, .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff } });
    }
}
