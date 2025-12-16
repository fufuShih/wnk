const std = @import("std");
const dvui = @import("dvui");
const SDLBackend = @import("sdl-backend");

// Import modules
const state = @import("state");
const keyboard = @import("ui/keyboard.zig");
const search = @import("ui/search.zig");
const panel_top = @import("ui/panel/top.zig");
const panel_main = @import("ui/panel/main.zig");
const panel_bottom = @import("ui/panel/bottom.zig");
const commands = @import("ui/commands.zig");
const plugin = @import("plugin.zig");
const tray = @import("tray");

var last_query_hash: u64 = 0;
var last_query_change_ms: i64 = 0;
var last_panel: state.Panel = state.default_panel;

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
        _ = SDLBackend.c.SDL_RestoreWindow(win);
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

fn currentPanel() state.Panel {
    return state.currentPanel();
}

fn handleTrayFrame() ?dvui.App.Result {
    if (tray_icon) |*icon| {
        icon.checkTrayMessages();

        if (icon.pollEvents()) {
            state.resetPanels();
            state.focus_on_results = false;
            dvui.focusWidget(null, null, null);
            showWindow();
        }
        if (icon.shouldExit()) {
            return .close;
        }
    }
    return null;
}

fn handleKeyboardFrame() !?dvui.App.Result {
    const kb_result = try keyboard.handleEvents();
    if (kb_result == .close) {
        return .close;
    } else if (kb_result == .hide) {
        hideWindow();
        return .ok;
    }
    return null;
}

fn renderTopArea() !void {
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 20 } });

    try panel_top.renderPanelTop(currentPanel());
}

fn textForCommand(sel: ?search.SelectedItem) []const u8 {
    if (sel) |s| switch (s) {
        .plugin => |item| {
            if (item.id) |id| {
                const prefix = "file:";
                if (std.mem.startsWith(u8, id, prefix)) {
                    return id[prefix.len..];
                }
            }
            return item.title;
        },
        .mock => |item| return item.title,
    };
    return state.getSelectedItemTitle();
}

fn handleCommandExecutionFrame() void {
    if (!state.command_execute) return;
    state.command_execute = false;

    // When operating from details/commands panels, rely on stored selected item info.
    const base_sel: ?search.SelectedItem = if (state.currentPanel() == .search) search.getSelectedItem() else null;

    const cmd = commands.getCommand(state.command_selected_index);
    if (cmd != null) {
        const text_for_command = textForCommand(base_sel);

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
                state.resetPanels();
            }
        }
    }

    // Close UI after execution.
    if (state.nav.action_open) {
        state.nav.action_open = false;
    } else if (state.currentPanel() == .commands) {
        state.popPanel();
    }
    dvui.focusWidget(null, null, null);
}

fn sendQueryIfChangedFrame() void {
    if (bun_process) |*proc| {
        const query = state.search_buffer[0..state.search_len];
        const h = std.hash.Wyhash.hash(0, query);
        const now_ms: i64 = std.time.milliTimestamp();
        if (h != last_query_hash) {
            last_query_hash = h;
            last_query_change_ms = now_ms;
            state.ipc.results_pending = true;
        }

        // Debounce to avoid spamming Bun (especially for network-backed plugins).
        const debounce_ms: i64 = 120;
        if (state.ipc.results_pending and (now_ms - last_query_change_ms) >= debounce_ms) {
            proc.sendQuery(query) catch |err| {
                std.debug.print("Failed to send query: {}\n", .{err});
            };
            // Keep results_pending true until we receive a results message.
        }
    }
}

fn enterListModeFrame() void {
    // Clear old subpanel data
    if (state.ipc.subpanel_data) |*s| {
        s.deinit();
        state.ipc.subpanel_data = null;
    }

    // Entering details doesn't always mean we need a Bun subpanel.
    state.ipc.subpanel_pending = false;
    const details = state.currentDetails() orelse return;
    if (details.source != .plugin) return;

    const sel = search.getSelectedItem();
    if (sel) |s| switch (s) {
        .plugin => |item| {
            state.setSelectedItemInfo(item.title, item.subtitle orelse "");
            if (bun_process) |*proc| {
                const item_id: []const u8 = item.id orelse item.title;
                state.ipc.subpanel_pending = true;
                proc.sendGetSubpanel(item.pluginId, item_id) catch |err| {
                    std.debug.print("Failed to request subpanel: {}\n", .{err});
                    state.ipc.subpanel_pending = false;
                };
            }
        },
        // Defensive: plugin details but search selection isn't a plugin item.
        .mock => {},
    };
}

fn leaveListModeFrame() void {
    if (state.ipc.subpanel_data) |*s| {
        s.deinit();
        state.ipc.subpanel_data = null;
    }
    state.ipc.subpanel_pending = false;
}

fn handleDetailsPanelTransitionsFrame() void {
    const now = state.currentPanel();
    if (now == .details and last_panel != .details) {
        enterListModeFrame();
    }
    if (now != .details and last_panel == .details) {
        leaveListModeFrame();
    }
    last_panel = now;
}

fn pollBunMessagesFrame() void {
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
}

fn renderPanelsArea() !void {
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 20 } });
    _ = dvui.separator(@src(), .{ .expand = .horizontal, .margin = .{ .x = 20 } });
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 10 } });

    var over = dvui.overlay(@src(), .{ .expand = .both });
    defer over.deinit();

    try panel_main.renderPanelBody(state.currentPanel());

    panel_bottom.renderPanelBottom(state.currentPanel());
    try panel_main.renderFloatingAction(search.getSelectedItem());
}

// Executed every frame to draw UI
pub fn AppFrame() !dvui.App.Result {
    if (handleTrayFrame()) |res| return res;
    if (try handleKeyboardFrame()) |res| return res;

    // Main container with padding
    var main_box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = true,
        .color_fill = .{ .r = 0x1e, .g = 0x1e, .b = 0x2e },
    });
    defer main_box.deinit();

    handleCommandExecutionFrame();
    handleDetailsPanelTransitionsFrame();
    try renderTopArea();
    sendQueryIfChangedFrame();
    pollBunMessagesFrame();
    try renderPanelsArea();

    return .ok;
}
