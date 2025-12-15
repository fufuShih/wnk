const std = @import("std");
const dvui = @import("dvui");
const state = @import("state");
const search = @import("../search.zig");
const ui = @import("../components.zig");

const HeaderModel = union(enum) {
    /// Root panel header: interactive search box.
    search: void,
    /// Non-root panels: back affordance + info.
    nav: struct {
        title: []const u8,
        subtitle: []const u8 = "",
    },
};

fn singleLineTruncateInto(buf: []u8, text: []const u8, max_bytes: usize) []const u8 {
    if (max_bytes == 0) return "";

    var out_len: usize = 0;
    for (text) |b| {
        if (out_len >= max_bytes) break;
        const c: u8 = switch (b) {
            '\n', '\r', '\t' => ' ',
            else => b,
        };
        buf[out_len] = c;
        out_len += 1;
    }

    if (text.len <= max_bytes) return buf[0..out_len];
    if (out_len < 3) return buf[0..out_len];

    // Replace last 3 bytes with "..." to hint truncation.
    buf[out_len - 3] = '.';
    buf[out_len - 2] = '.';
    buf[out_len - 1] = '.';
    return buf[0..out_len];
}

fn renderNavHeaderCard(title: []const u8, subtitle: []const u8) void {
    var box = ui.beginCard(.{ .margin = .{ .x = 20, .y = 0, .w = 20, .h = 10 } });
    defer box.deinit();

    var row = dvui.box(@src(), .{ .dir = .horizontal }, .{ .expand = .horizontal });
    defer row.deinit();

    var title_buf: [96]u8 = undefined;
    const title_one = singleLineTruncateInto(&title_buf, title, title_buf.len);
    var subtitle_buf: [120]u8 = undefined;
    const subtitle_one = singleLineTruncateInto(&subtitle_buf, subtitle, subtitle_buf.len);

    dvui.label(@src(), "<", .{}, .{ .font_style = .title_3, .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff } });
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 8 } });

    ui.headerTitle(title_one);
    if (subtitle_one.len > 0) {
        _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 12 } });
        ui.headerSubtitle(subtitle_one);
    }
}

fn detailsHeaderInfo() struct { title: []const u8, subtitle: []const u8 } {
    if (state.currentDetails()) |d| {
        if (d.source == .mock) {
            if (d.mock_panel) |p| {
                const h = state.panelHeader(p);
                return .{ .title = h.title, .subtitle = h.subtitle orelse "" };
            }
            return .{ .title = state.getSelectedItemTitle(), .subtitle = state.getSelectedItemSubtitle() };
        }
    }

    if (state.ipc.currentSubpanelView()) |v| {
        return .{ .title = v.title, .subtitle = v.subtitle };
    }
    return .{ .title = state.getSelectedItemTitle(), .subtitle = state.getSelectedItemSubtitle() };
}

fn headerModelForPanel(panel: state.Panel) HeaderModel {
    switch (panel) {
        .search => return .{ .search = {} },
        .details => {
            const h = detailsHeaderInfo();
            return .{ .nav = .{ .title = h.title, .subtitle = h.subtitle } };
        },
        .commands => {
            const subtitle = state.getSelectedItemTitle();
            return .{ .nav = .{ .title = "Commands", .subtitle = subtitle } };
        },
    }
}

fn renderHeader(model: HeaderModel) !void {
    switch (model) {
        .search => try search.renderSearch(),
        .nav => |h| renderNavHeaderCard(h.title, h.subtitle),
    }
}

pub fn renderPanelTop(panel: state.Panel) !void {
    try renderHeader(headerModelForPanel(panel));
}
