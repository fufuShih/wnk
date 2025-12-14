const std = @import("std");
const dvui = @import("dvui");
const SDLBackend = @import("sdl-backend");

// Import modules
const state = @import("state");
const keyboard = @import("ui/keyboard.zig");
const search = @import("ui/search.zig");
const panels = @import("ui/panels.zig");
const commands = @import("ui/commands.zig");
const floating_action_panel = @import("ui/floating_action_panel.zig");
const plugin = @import("plugin.zig");
const tray = @import("tray/tray.zig");

var last_query_hash: u64 = 0;

// Global plugin process and tray icon
var bun_process: ?plugin.BunProcess = null;
var tray_icon: ?tray.TrayIcon = null;
var sdl_window_ptr: ?*SDLBackend.c.SDL_Window = null;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

// Window visibility functions
fn hideWindow() void {
    if (sdl_window_ptr) |win| {
        _ = SDLBackend.c.SDL_HideWindow(win);
    }
}

fn showWindow() void {
    if (sdl_window_ptr) |win| {
        _ = SDLBackend.c.SDL_ShowWindow(win);
        _ = SDLBackend.c.SDL_RaiseWindow(win);
    }
}

// Declare as dvui App
pub const dvui_app: dvui.App = .{
    .config = .{
        .options = .{
            .size = .{ .w = 700.0, .h = 500.0 },
            .min_size = .{ .w = 600.0, .h = 400.0 },
            .title = "wnk Launcher",
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
    sdl_window_ptr = sdl_window;

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

    // Initialize state
    state.init(allocator);

    // Start Bun plugin process (calculator-only)
    bun_process = plugin.BunProcess.spawn(allocator) catch |err| {
        std.debug.print("Failed to start Bun process: {}\n", .{err});
        return;
    };

    std.debug.print("Bun plugin process started\n", .{});

    // Initialize system tray icon
    tray_icon = tray.TrayIcon.init(sdl_window) catch |err| {
        std.debug.print("Failed to create tray icon: {}\n", .{err});
        return;
    };

    std.debug.print("System tray icon created\n", .{});
}

// Executed before application closes, before dvui.Window.deinit()
pub fn AppDeinit() void {
    // Clean up tray icon
    if (tray_icon) |*icon| {
        icon.deinit();
        tray_icon = null;
    }

    // Clean up plugin process
    if (bun_process) |*proc| {
        proc.deinit();
        bun_process = null;
    }
    state.deinit();
}

// Executed every frame to draw UI
pub fn AppFrame() !dvui.App.Result {
    // Check tray icon messages
    if (tray_icon) |*icon| {
        icon.checkTrayMessages();

        if (icon.pollEvents()) {
            showWindow();
        }
        if (icon.shouldExit()) {
            return .close;
        }
    }

    // Handle keyboard events
    const kb_result = try keyboard.handleEvents();
    if (kb_result == .close) {
        return .close;
    } else if (kb_result == .hide) {
        // Hide window to tray
        hideWindow();
        return .ok;
    }

    // Main container with padding
    var main_box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = true,
        .color_fill = .{ .r = 0x1e, .g = 0x1e, .b = 0x2e },
    });
    defer main_box.deinit();

    // Keep the base wnk layout always visible
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 20 } });
    // The top area is either the search box (main panel) or a panel hint.
    const top_mode: state.PanelMode = if (state.panel_mode == .action) state.prev_panel_mode else state.panel_mode;
    if (top_mode == .main) {
        try search.renderSearch();
    } else {
        panels.renderTop(top_mode, search.getSelectedItem());
    }

    // Execute command selected in command panel (triggered by Enter in keyboard handler).
    if (state.command_execute) {
        state.command_execute = false;

        const sel = search.getSelectedItem();
        const cmd = commands.getCommand(state.command_selected_index);

        if (cmd != null and sel != null) {
            const text_for_command: []const u8 = switch (sel.?) {
                .plugin => |item| blk: {
                    if (item.id) |id| {
                        const prefix = "file:";
                        if (std.mem.startsWith(u8, id, prefix)) {
                            break :blk id[prefix.len..];
                        }
                    }
                    break :blk item.title;
                },
                .mock => |item| item.title,
            };

            // Route action via Bun (command -> effect -> host state update).
            if (bun_process) |*proc| {
                proc.sendCommand(cmd.?.name, text_for_command) catch |err| {
                    std.debug.print("Failed to send command: {}\n", .{err});
                };
            } else {
                // Fallback if Bun isn't running.
                if (std.mem.eql(u8, cmd.?.name, "setSearchText")) {
                    state.setSearchText(text_for_command);
                    state.focus_on_results = false;
                    state.panel_mode = .main;
                }
            }
        }

        // Close command panel regardless.
        state.panel_mode = state.prev_panel_mode;
        dvui.focusWidget(null, null, null);
    }

    // Send query to Bun when search text changes
    if (bun_process) |*proc| {
        const query = state.search_buffer[0..state.search_len];
        const h = std.hash.Wyhash.hash(0, query);
        if (h != last_query_hash) {
            last_query_hash = h;
            proc.sendQuery(query) catch |err| {
                std.debug.print("Failed to send query: {}\n", .{err});
            };
        }
    }

    // Poll Bun process for plugin results (JSON lines)
    if (bun_process) |*proc| {
        while (true) {
            const maybe_line = proc.pollLine() catch |err| {
                std.debug.print("Failed to read from Bun: {}\n", .{err});
                break;
            };
            if (maybe_line) |line| {
                state.handleBunMessage(allocator, line);
                continue;
            }
            break;
        }
    }

    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 20 } });
    _ = dvui.separator(@src(), .{ .expand = .horizontal, .margin = .{ .x = 20 } });
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 10 } });

    // Render the active panel (action panel is a true overlay popout)
    const base_mode: state.PanelMode = if (state.panel_mode == .action) state.prev_panel_mode else state.panel_mode;

    var over = dvui.overlay(@src(), .{ .expand = .both });
    defer over.deinit();

    // Base content
    switch (base_mode) {
        .main => try search.renderResults(),
        .list => try panels.renderList(search.getSelectedItem()),
        .sub => try panels.renderSub(search.getSelectedItem()),
        .command => try panels.renderCommand(search.getSelectedItem()),
        .action => try search.renderResults(),
    }

    // Action panel: bottom-right, above base content.
    if (state.panel_mode == .action) {
        var anchor = dvui.box(@src(), .{ .dir = .vertical }, .{
            .gravity_x = 1.0,
            .gravity_y = 1.0,
            .margin = .{ .x = 0, .y = 0, .w = 20, .h = 20 },
        });
        defer anchor.deinit();

        try floating_action_panel.render(search.getSelectedItem());
    }

    return .ok;
}
