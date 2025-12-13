const dvui = @import("dvui");

pub const CardStyle = struct {
    margin: dvui.Rect = .{},
    padding: dvui.Rect = .{ .x = 12, .y = 10, .w = 12, .h = 10 },
    corner_radius: dvui.Rect = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
    color_fill: dvui.Color = .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
};

pub fn beginCard(style: CardStyle) *dvui.BoxWidget {
    return dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .horizontal,
        .background = true,
        .padding = style.padding,
        .margin = style.margin,
        .corner_radius = style.corner_radius,
        .color_fill = style.color_fill,
    });
}

pub fn heading(text: []const u8) void {
    dvui.label(@src(), "{s}", .{text}, .{ .font_style = .title_3, .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff } });
}

pub fn headerTitle(text: []const u8) void {
    dvui.label(@src(), "{s}", .{text}, .{ .font_style = .title_3, .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff } });
}

pub fn headerSubtitle(text: []const u8) void {
    dvui.label(@src(), "{s}", .{text}, .{ .font_style = .caption, .color_text = .{ .r = 0x88, .g = 0x88, .b = 0x99 } });
}

pub fn optionRow(_label: []const u8, is_selected: bool) *dvui.BoxWidget {
    _ = _label;
    return dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .background = true,
        .padding = .{ .x = 12, .y = 10, .w = 12, .h = 10 },
        .margin = .{ .x = 0, .y = 4, .w = 0, .h = 4 },
        .corner_radius = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
        .border = if (is_selected) .{ .x = 2, .y = 2, .w = 2, .h = 2 } else .{},
        .color_fill = if (is_selected) .{ .r = 0x3a, .g = 0x3a, .b = 0x5e } else .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
        .color_border = if (is_selected) .{ .r = 0x6a, .g = 0x6a, .b = 0xff } else .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
    });
}
