const dvui = @import("dvui");
const state = @import("state");
const search = @import("search.zig");
const ui = @import("components.zig");
const cmds = @import("commands.zig");

pub fn render(sel: ?search.SelectedItem) !void {
    // Clamp selection
    if (cmds.commands.len > 0 and state.command_selected_index >= cmds.commands.len) {
        state.command_selected_index = cmds.commands.len - 1;
    }

    // A compact, popup-like panel intended to be placed in the bottom-right.
    var panel = dvui.box(@src(), .{ .dir = .vertical }, .{
        .background = true,
        .padding = .{ .x = 12, .y = 10, .w = 12, .h = 10 },
        .corner_radius = .{ .x = 10, .y = 10, .w = 10, .h = 10 },
        .color_fill = .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
    });
    defer panel.deinit();

    const title: []const u8 = if (sel) |_| "Actions" else "Actions";

    dvui.label(@src(), "{s}", .{title}, .{ .font_style = .title_4, .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff } });
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 6 } });

    for (cmds.commands, 0..) |cmd, idx| {
        const is_selected = idx == state.command_selected_index;
        var row = ui.optionRow(cmd.title, is_selected);
        defer row.deinit();

        dvui.label(@src(), "{s}", .{cmd.title}, .{ .font_style = .title_4, .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff } });
    }

    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 6 } });
    dvui.label(@src(), "Enter: run  W/S: move  Esc: back", .{}, .{ .font_style = .caption, .color_text = .{ .r = 0xaa, .g = 0xaa, .b = 0xbb } });
}
