const dvui = @import("dvui");

const style = @import("style.zig");
const text_utils = @import("utils/text.zig");

/// Region-scoped UI primitives.
/// This file keeps the API separated by region (top/main/bottom) while avoiding excessive file hopping.
pub const top = struct {
    /// Components intended for the panel top region (header/search area).
    /// Keep these APIs isolated so only header-related code depends on them.
    pub const CardStyle = struct {
        margin: dvui.Rect = .{},
        padding: dvui.Rect = style.metrics.card_padding,
        corner_radius: dvui.Rect = style.metrics.card_radius,
        color_fill: dvui.Color = style.colors.surface,
    };

    pub fn beginCard(card: CardStyle) *dvui.BoxWidget {
        return dvui.box(@src(), .{ .dir = .vertical }, .{
            .expand = .horizontal,
            .background = true,
            .padding = card.padding,
            .margin = card.margin,
            .corner_radius = card.corner_radius,
            .color_fill = card.color_fill,
        });
    }

    pub fn headerTitle(text: []const u8) void {
        dvui.label(@src(), "{s}", .{text}, .{ .font = dvui.Font.theme(.heading), .color_text = style.colors.text_primary });
    }

    pub fn headerSubtitle(text: []const u8) void {
        dvui.label(@src(), "{s}", .{text}, .{ .font = dvui.Font.theme(.body).larger(-3), .color_text = style.colors.text_muted });
    }

    /// Header style for non-root panels: a back affordance and context text.
    pub fn renderNavHeader(title: []const u8, subtitle: []const u8) void {
        var box = beginCard(.{ .margin = style.layout.header_margin });
        defer box.deinit();

        var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
        defer row.deinit();

        var title_buf: [96]u8 = undefined;
        const title_one = text_utils.singleLineTruncateInto(&title_buf, title, title_buf.len);
        var subtitle_buf: [120]u8 = undefined;
        const subtitle_one = text_utils.singleLineTruncateInto(&subtitle_buf, subtitle, subtitle_buf.len);

        dvui.label(@src(), "<", .{}, .{ .font = dvui.Font.theme(.heading), .color_text = style.colors.text_primary });
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 8 } });

        headerTitle(title_one);
        if (subtitle_one.len > 0) {
            _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 12 } });
            headerSubtitle(subtitle_one);
        }
    }
};

pub const main = struct {
    /// Components intended for the panel main region (content/layout).
    /// Keep these APIs isolated so only content renderers depend on them.

    // -----------------------------
    // Layout primitives (Box/Flex/Grid)
    // -----------------------------

    /// Flex row container (frontend: `Row`).
    pub fn beginFlexRow(opts: dvui.Options) *dvui.BoxWidget {
        return dvui.box(@src(), .{ .dir = .horizontal }, opts);
    }

    /// Flex column container (frontend: `Column`).
    pub fn beginFlexColumn(opts: dvui.Options) *dvui.BoxWidget {
        return dvui.box(@src(), .{ .dir = .vertical }, opts);
    }

    /// Convenience aliases.
    pub fn beginRow(opts: dvui.Options) *dvui.BoxWidget {
        return beginFlexRow(opts);
    }

    pub fn beginColumn(opts: dvui.Options) *dvui.BoxWidget {
        return beginFlexColumn(opts);
    }

    /// Simple grid renderer built on top of flex rows/columns.
    /// - `columns`: number of columns (>= 1)
    /// - `gap`: spacing in pixels between cells/rows
    /// - `renderCell(ctx, idx, id_extra)`: render one cell
    pub fn grid(comptime Ctx: type, ctx: Ctx, count: usize, columns: usize, gap: f32, comptime renderCell: fn (Ctx, usize, usize) void) void {
        const cols = if (columns == 0) 1 else columns;

        var i: usize = 0;
        while (i < count) : (i += cols) {
            var row = beginFlexRow(.{ .expand = .horizontal, .id_extra = 50_000 + i });
            defer row.deinit();

            var c: usize = 0;
            while (c < cols) : (c += 1) {
                const idx = i + c;
                if (idx < count) {
                    var cell = beginFlexColumn(.{ .expand = .horizontal, .id_extra = 60_000 + idx });
                    defer cell.deinit();
                    renderCell(ctx, idx, 70_000 + idx);
                } else {
                    var empty = beginFlexColumn(.{ .expand = .horizontal, .id_extra = 80_000 + idx });
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
        dvui.label(@src(), "{s}", .{text}, .{ .font = dvui.Font.theme(.heading), .color_text = style.colors.text_primary });
    }

    pub fn beginOptionRow(id_extra: usize, is_selected: bool) *dvui.BoxWidget {
        return dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .id_extra = id_extra,
            .background = true,
            .padding = style.metrics.option_padding,
            .margin = style.metrics.option_margin,
            .corner_radius = style.metrics.card_radius,
            .border = if (is_selected) .{ .x = 2, .y = 2, .w = 2, .h = 2 } else .{},
            .color_fill = if (is_selected) style.colors.surface_selected else style.colors.surface,
            .color_border = if (is_selected) style.colors.border_selected else style.colors.surface,
        });
    }

    pub const ItemRowStyle = struct {
        id_extra: usize = 0,
        is_selected: bool = false,
        padding: dvui.Rect = style.metrics.item_padding,
        margin: dvui.Rect = style.metrics.item_margin,
    };

    pub fn beginItemRow(style_in: ItemRowStyle) *dvui.BoxWidget {
        return dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .id_extra = style_in.id_extra,
            .background = true,
            .border = if (style_in.is_selected) .{ .x = 2, .y = 2, .w = 2, .h = 2 } else .{},
            .corner_radius = style.metrics.card_radius,
            .padding = style_in.padding,
            .margin = style_in.margin,
            .color_fill = if (style_in.is_selected) style.colors.surface_selected else style.colors.surface,
            .color_border = if (style_in.is_selected) style.colors.border_selected else style.colors.surface,
        });
    }
};

pub const bottom = struct {
    /// Components intended for the panel bottom region (hint/help bar).
    /// Keep these APIs isolated so only hint rendering depends on them.
    fn renderHintBar(text: []const u8) void {
        var bar = dvui.box(@src(), .{ .dir = .horizontal }, .{
            .expand = .horizontal,
            .margin = style.layout.content_margin,
            .background = true,
            .padding = .{ .x = 12, .y = 10, .w = 12, .h = 10 },
            .corner_radius = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
            .color_fill = style.colors.surface_muted,
        });
        defer bar.deinit();

        dvui.label(@src(), "{s}", .{text}, .{ .font = dvui.Font.theme(.body).larger(-3), .color_text = style.colors.text_hint });
    }

    /// Pins a hint bar to the bottom of the window.
    pub fn renderBottomHint(text: []const u8) void {
        var anchor = dvui.box(@src(), .{ .dir = .vertical }, .{
            .gravity_x = 0.0,
            .gravity_y = 1.0,
            .expand = .horizontal,
        });
        defer anchor.deinit();

        renderHintBar(text);
    }
};
