const dvui = @import("dvui");

/// Shared UI styling constants.
/// Keep these values centralized so panels/components stay visually consistent.
pub const layout = struct {
    /// Default horizontal inset for most panel content.
    pub const content_margin: dvui.Rect = .{ .x = 20, .y = 0, .w = 20, .h = 20 };

    /// Header card inset (slightly tighter bottom padding).
    pub const header_margin: dvui.Rect = .{ .x = 20, .y = 0, .w = 20, .h = 10 };

    /// Search input row inset (no bottom margin; main area owns spacing).
    pub const search_margin: dvui.Rect = .{ .x = 20, .y = 0, .w = 20, .h = 0 };

    /// Overlay anchor inset (keeps popups off the window edge).
    pub const overlay_margin: dvui.Rect = .{ .x = 0, .y = 0, .w = 20, .h = 20 };
};

pub const colors = struct {
    pub const app_background: dvui.Color = .{ .r = 0x1e, .g = 0x1e, .b = 0x2e };

    pub const surface: dvui.Color = .{ .r = 0x2a, .g = 0x2a, .b = 0x3e };
    pub const surface_muted: dvui.Color = .{ .r = 0x24, .g = 0x24, .b = 0x34 };
    pub const surface_selected: dvui.Color = .{ .r = 0x3a, .g = 0x3a, .b = 0x5e };
    pub const border_selected: dvui.Color = .{ .r = 0x6a, .g = 0x6a, .b = 0xff };

    pub const text_primary: dvui.Color = .{ .r = 0xff, .g = 0xff, .b = 0xff };
    pub const text_muted: dvui.Color = .{ .r = 0x88, .g = 0x88, .b = 0x99 };
    pub const text_hint: dvui.Color = .{ .r = 0xaa, .g = 0xaa, .b = 0xbb };
};

pub const metrics = struct {
    /// Standard card padding used in headers and popups.
    pub const card_padding: dvui.Rect = .{ .x = 12, .y = 10, .w = 12, .h = 10 };
    pub const card_radius: dvui.Rect = .{ .x = 8, .y = 8, .w = 8, .h = 8 };

    /// Standard list item paddings.
    pub const option_padding: dvui.Rect = .{ .x = 12, .y = 10, .w = 12, .h = 10 };
    pub const option_margin: dvui.Rect = .{ .x = 0, .y = 4, .w = 0, .h = 4 };

    pub const item_padding: dvui.Rect = .{ .x = 12, .y = 8, .w = 12, .h = 8 };
    pub const item_margin: dvui.Rect = .{ .x = 0, .y = 4, .w = 0, .h = 4 };
};
