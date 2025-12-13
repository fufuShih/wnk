const std = @import("std");
const dvui = @import("dvui");
const state = @import("../state.zig");

pub fn render() !void {
    var scroll = dvui.scrollArea(@src(), .{}, .{
        .expand = .both,
        .margin = .{ .x = 20, .y = 0, .w = 20, .h = 20 },
    });
    defer scroll.deinit();

    // Count visible results and limit selection index
    var visible_count: usize = 0;
    for (state.mock_results) |result| {
        const should_show = if (state.search_len == 0)
            true
        else blk: {
            const search_text = state.search_buffer[0..state.search_len];
            break :blk std.mem.indexOf(u8, result.title, search_text) != null or
                std.mem.indexOf(u8, result.subtitle, search_text) != null;
        };
        if (should_show) visible_count += 1;
    }

    if (visible_count > 0 and state.selected_index >= visible_count) {
        state.selected_index = visible_count - 1;
    }

    // Filter and display results
    var display_index: usize = 0;
    for (state.mock_results, 0..) |result, i| {
        // Simple filter based on search text
        const should_show = if (state.search_len == 0)
            true
        else blk: {
            const search_text = state.search_buffer[0..state.search_len];
            // Simple contains check
            break :blk std.mem.indexOf(u8, result.title, search_text) != null or
                std.mem.indexOf(u8, result.subtitle, search_text) != null;
        };

        if (should_show) {
            const is_selected = state.focus_on_results and display_index == state.selected_index;

            // Result item with selection highlight
            var item_box = dvui.box(@src(), .{ .dir = .horizontal }, .{
                .expand = .horizontal,
                .id_extra = i,
                .background = true,
                .border = if (is_selected) .{ .x = 2, .y = 2, .w = 2, .h = 2 } else .{},
                .corner_radius = .{ .x = 8, .y = 8, .w = 8, .h = 8 },
                .padding = .{ .x = 12, .y = 8, .w = 12, .h = 8 },
                .margin = .{ .x = 0, .y = 4, .w = 0, .h = 4 },
                .color_fill = if (is_selected) .{ .r = 0x3a, .g = 0x3a, .b = 0x5e } else .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
                .color_border = if (is_selected) .{ .r = 0x6a, .g = 0x6a, .b = 0xff } else .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
            });
            defer item_box.deinit();

            display_index += 1;

            // Icon
            dvui.label(@src(), "{s}", .{result.icon}, .{
                .font_style = .title,
                .id_extra = i,
            });

            _ = dvui.spacer(@src(), .{ .min_size_content = .{ .w = 12 }, .id_extra = i });

            // Text content
            {
                var text_box = dvui.box(@src(), .{ .dir = .vertical }, .{
                    .expand = .horizontal,
                    .id_extra = i,
                });
                defer text_box.deinit();

                dvui.label(@src(), "{s}", .{result.title}, .{
                    .font_style = .title_4,
                    .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff },
                    .id_extra = i,
                });

                _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 2 }, .id_extra = i + 1000 });

                dvui.label(@src(), "{s}", .{result.subtitle}, .{
                    .font_style = .caption,
                    .color_text = .{ .r = 0x88, .g = 0x88, .b = 0x99 },
                    .id_extra = i * 100,
                });
            }
        }
    }
}
