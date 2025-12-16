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

// -----------------------------
// Layout primitives
// -----------------------------

pub fn beginRow(opts: dvui.Options) *dvui.BoxWidget {
    return dvui.box(@src(), .{ .dir = .horizontal }, opts);
}

pub fn beginColumn(opts: dvui.Options) *dvui.BoxWidget {
    return dvui.box(@src(), .{ .dir = .vertical }, opts);
}

/// Simple grid renderer built on top of flex rows.
/// - `columns`: number of columns (>= 1)
/// - `gap`: spacing in pixels between cells/rows
/// - `renderCell(ctx, idx, id_extra)`: render one cell
pub fn grid(comptime Ctx: type, ctx: Ctx, count: usize, columns: usize, gap: f32, comptime renderCell: fn (Ctx, usize, usize) void) void {
    const cols = if (columns == 0) 1 else columns;

    var i: usize = 0;
    while (i < count) : (i += cols) {
        var row = beginRow(.{ .expand = .horizontal, .id_extra = 50_000 + i });
        defer row.deinit();

        var c: usize = 0;
        while (c < cols) : (c += 1) {
            const idx = i + c;
            if (idx < count) {
                var cell = beginColumn(.{ .expand = .horizontal, .id_extra = 60_000 + idx });
                defer cell.deinit();
                renderCell(ctx, idx, 70_000 + idx);
            } else {
                var empty = beginColumn(.{ .expand = .horizontal, .id_extra = 80_000 + idx });
                defer empty.deinit();
            }

            if (c + 1 < cols and gap > 0) {
                _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = gap } });
            }
        }

        if (gap > 0) {
            _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = gap } });
        }
    }
}

pub fn heading(text: []const u8) void {
    dvui.label(@src(), "{s}", .{text}, .{ .font = dvui.Font.theme(.heading), .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff } });
}

pub fn headerTitle(text: []const u8) void {
    dvui.label(@src(), "{s}", .{text}, .{ .font = dvui.Font.theme(.heading), .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff } });
}

pub fn headerSubtitle(text: []const u8) void {
    dvui.label(@src(), "{s}", .{text}, .{ .font = dvui.Font.theme(.body).larger(-3), .color_text = .{ .r = 0x88, .g = 0x88, .b = 0x99 } });
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

pub const ItemRowStyle = struct {
    id_extra: usize = 0,
    is_selected: bool = false,
    padding: dvui.Rect = .{ .x = 12, .y = 8, .w = 12, .h = 8 },
    margin: dvui.Rect = .{ .x = 0, .y = 4, .w = 0, .h = 4 },
};

pub fn beginItemRow(style: ItemRowStyle) *dvui.BoxWidget {
    return dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .id_extra = style.id_extra,
        .background = true,
        .border = if (style.is_selected) .{ .x = 2, .y = 2, .w = 2, .h = 2 } else .{},
        .corner_radius = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
        .padding = style.padding,
        .margin = style.margin,
        .color_fill = if (style.is_selected) .{ .r = 0x3a, .g = 0x3a, .b = 0x5e } else .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
        .color_border = if (style.is_selected) .{ .r = 0x6a, .g = 0x6a, .b = 0xff } else .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
    });
}
