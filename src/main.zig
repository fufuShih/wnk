const std = @import("std");
const dvui = @import("dvui");
const SDLBackend = @import("sdl-backend");

// Search buffer for the input field
var search_buffer: [256]u8 = undefined;
var search_len: usize = 0;
var search_initialized = false;

// Selection state
var selected_index: usize = 0;
var focus_on_results = false;

// Mock search results
const SearchResult = struct {
    title: []const u8,
    subtitle: []const u8,
    icon: []const u8,
};

const mock_results = [_]SearchResult{
    .{ .title = "Calculator", .subtitle = "Application", .icon = "=" },
    .{ .title = "Calendar", .subtitle = "System Preferences", .icon = "C" },
    .{ .title = "Camera", .subtitle = "Devices", .icon = "O" },
    .{ .title = "Chrome", .subtitle = "Web Browser", .icon = "@" },
    .{ .title = "Code", .subtitle = "Development", .icon = "#" },
};

// Declare as dvui App
pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .size = .{ .w = 700.0, .h = 500.0 },
            .min_size = .{ .w = 600.0, .h = 400.0 },
            .title = "Wink Launcher",
            .window_init_options = .{},
        },
    },
    .frameFn = AppFrame,
    .initFn = AppInit,
    .deinitFn = AppDeinit,
};

// Use the main function provided by dvui.App
pub const main = dvui.App.main;
pub const panic = dvui.App.panic;
pub const std_options: std.Options = .{
    .logFn = dvui.App.logFn,
};

// Executed before the first frame, after backend and dvui.Window.init()
pub fn AppInit(win: *dvui.Window) !void {
    // Get the SDL window directly from backend.impl
    const sdl_window = win.backend.impl.window;

    // Set borderless window (no title bar or window frame)
    _ = SDLBackend.c.SDL_SetWindowBordered(sdl_window, false);

    // Set window to always stay on top
    _ = SDLBackend.c.SDL_SetWindowAlwaysOnTop(sdl_window, true);

    // Set window opacity (0.0 = fully transparent, 1.0 = fully opaque)
    // 0.95 gives a subtle transparency effect like Raycast
    _ = SDLBackend.c.SDL_SetWindowOpacity(sdl_window, 0.95);

    // Center the window on screen
    _ = SDLBackend.c.SDL_SetWindowPosition(
        sdl_window,
        SDLBackend.c.SDL_WINDOWPOS_CENTERED,
        SDLBackend.c.SDL_WINDOWPOS_CENTERED,
    );

    // Initialize search buffer
    @memset(&search_buffer, 0);
    search_initialized = true;
}

// Executed before application closes, before dvui.Window.deinit()
pub fn AppDeinit() void {
    // Clean up resources
}

// Executed every frame to draw UI
pub fn AppFrame() !dvui.App.Result {
    // Handle keyboard shortcuts
    const evt = dvui.events();
    for (evt) |*e| {
        if (e.evt == .key and e.evt.key.action == .down) {
            // ESC to close window
            if (e.evt.key.code == .escape) {
                return .close;
            }

            // Tab to switch focus between search and results
            if (e.evt.key.code == .tab) {
                focus_on_results = !focus_on_results;
                if (focus_on_results) {
                    selected_index = 0;
                }
                dvui.focusWidget(null, null, null);
                e.handled = true;
            }

            // W/S keys for navigation when focus is on results
            if (focus_on_results) {
                if (e.evt.key.code == .w) {
                    if (selected_index > 0) {
                        selected_index -= 1;
                    }
                    e.handled = true;
                } else if (e.evt.key.code == .s) {
                    selected_index += 1;
                    e.handled = true;
                }
            }
        }
    }

    // Main container with padding
    var main_box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = true,
        .color_fill = .{ .r = 0x1e, .g = 0x1e, .b = 0x2e },
    });
    defer main_box.deinit();

    // Top spacing
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 20 } });

    // Search bar container
    {
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
            .text = .{ .buffer = &search_buffer },
            .placeholder = "Search for apps, files, and more...",
        }, .{
            .expand = .horizontal,
            .font_style = .title_4,
            .color_fill = .{ .r = 0x2a, .g = 0x2a, .b = 0x3e },
            .color_text = .{ .r = 0xff, .g = 0xff, .b = 0xff },
        });
        search_len = te.len;

        // Auto-focus on search box if not focusing on results
        if (!focus_on_results) {
            dvui.focusWidget(te.wd.id, null, null);
        }

        te.deinit();
    }

    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 20 } });

    // Divider
    _ = dvui.separator(@src(), .{ .expand = .horizontal, .margin = .{ .x = 20 } });

    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 10 } });

    // Results panel with scroll
    {
        var scroll = dvui.scrollArea(@src(), .{}, .{
            .expand = .both,
            .margin = .{ .x = 20, .y = 0, .w = 20, .h = 20 },
        });
        defer scroll.deinit();

        // Count visible results and limit selection index
        var visible_count: usize = 0;
        for (mock_results) |result| {
            const should_show = if (search_len == 0)
                true
            else blk: {
                const search_text = search_buffer[0..search_len];
                break :blk std.mem.indexOf(u8, result.title, search_text) != null or
                    std.mem.indexOf(u8, result.subtitle, search_text) != null;
            };
            if (should_show) visible_count += 1;
        }

        if (visible_count > 0 and selected_index >= visible_count) {
            selected_index = visible_count - 1;
        }

        // Filter and display results
        var display_index: usize = 0;
        for (mock_results, 0..) |result, i| {
            // Simple filter based on search text
            const should_show = if (search_len == 0)
                true
            else blk: {
                const search_text = search_buffer[0..search_len];
                // Simple contains check
                break :blk std.mem.indexOf(u8, result.title, search_text) != null or
                    std.mem.indexOf(u8, result.subtitle, search_text) != null;
            };

            if (should_show) {
                const is_selected = focus_on_results and display_index == selected_index;

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

    return .ok;
}
