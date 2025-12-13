const dvui = @import("dvui");
const state = @import("../state.zig");

pub fn render() !void {
    var search_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
        .expand = .horizontal,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 0 },
    });
    defer search_box.deinit();

    // Search icon
    dvui.label(@src(), "[>", .{}, .{ .font_style = .title });

    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 10 } });

    // Search input field with auto-focus
    var te = dvui.textEntry(@src(), .{
        .text = .{ .buffer = &state.search_buffer },
        .placeholder = "Search for apps, files, and more...",
    }, .{
        .expand = .horizontal,
        .font_style = .title_4,
        .color_fill = .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
        .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff },
    });
    state.search_len = te.len;

    // Auto-focus on search box if not focusing on results
    if (!state.focus_on_results) {
        dvui.focusWidget(te.wd.id, null, null);
    }

    te.deinit();
}
