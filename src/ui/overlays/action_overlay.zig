const dvui = @import("dvui");
const state = @import("state");

const actions = @import("../actions.zig");
const regions = @import("../regions.zig");
const style = @import("../style.zig");

pub fn render() !void {
    // This overlay is not a panel/region; it is rendered on demand when the main selection provides actions.
    if (!state.nav.action_open) return;

    // Defensive: if the context changed while open, close the overlay.
    if (!actions.hasCommand()) {
        state.nav.action_open = false;
        return;
    }

    var anchor = dvui.box(@src(), .{ .dir = .vertical }, .{
        .gravity_x = 1.0,
        .gravity_y = 1.0,
        .margin = style.layout.overlay_margin,
    });
    defer anchor.deinit();

    // A compact, popup-like panel intended to be placed in the bottom-right.
    var panel = dvui.box(@src(), .{ .dir = .vertical }, .{
        .background = true,
        .padding = style.metrics.card_padding,
        .corner_radius = .{ .x = 10, .y = 10, .w = 10, .h = 10 },
        .color_fill = style.colors.surface,
    });
    defer panel.deinit();

    dvui.label(@src(), "Actions", .{}, .{ .font = dvui.Font.theme(.heading), .color_text = style.colors.text_primary });
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 6 } });

    renderActionList(actions.actions());

    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 6 } });
    dvui.label(@src(), "Enter: run  W/S: move  Esc: back", .{}, .{ .font = dvui.Font.theme(.body).larger(-3), .color_text = style.colors.text_hint });
}

fn clampSelection(actions_count: usize) void {
    if (actions_count == 0) {
        state.command_selected_index = 0;
        return;
    }

    if (state.command_selected_index >= actions_count) {
        state.command_selected_index = actions_count - 1;
    }
}

fn renderActionList(list: []const @import("../commands.zig").Command) void {
    clampSelection(list.len);

    for (list, 0..) |cmd, idx| {
        const is_selected = idx == state.command_selected_index;
        const id_extra: usize = 110_000 + idx;

        var row = regions.main.beginOptionRow(id_extra, is_selected);
        defer row.deinit();

        dvui.label(@src(), "{s}", .{cmd.title}, .{
            .font = dvui.Font.theme(.heading),
            .color_text = style.colors.text_primary,
            .id_extra = 120_000 + idx,
        });
    }
}
