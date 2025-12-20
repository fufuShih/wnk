const std = @import("std");
const dvui = @import("dvui");
const SDLBackend = @import("sdl-backend");

// Import modules
const state = @import("state");
const runtime = @import("runtime");
const tray = @import("tray");

const keyboard = @import("ui/keyboard.zig");
const search = @import("ui/search.zig");
const actions = @import("ui/actions.zig");
const panels = @import("ui/panels/mod.zig");
const style = @import("ui/style.zig");

var last_query_hash: u64 = 0;
var last_query_change_ms: i64 = 0;
var last_panel: state.Panel = state.default_panel;

// Global runtime process and tray icon
var runtime_host: runtime.RuntimeHost = .{};
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

    // Start plugin runtime process (default: Bun)
    runtime_host.start(allocator, .bun);

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

    // Clean up runtime process
    runtime_host.deinit();
    state.deinit();
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

fn handleCommandExecutionFrame() void {
    if (!state.command_execute) return;
    state.command_execute = false;

    const handleHostCommand = struct {
        fn run(name: []const u8, text: []const u8) bool {
            if (std.mem.eql(u8, name, "setSearchText")) {
                state.setSearchText(text);
                state.focus_on_results = false;
                state.resetPanels();
                return true;
            }
            return false;
        }
    }.run;

    // Top input mode: submit user text as the command payload.
    if (state.action_prompt_active) {
        const name = state.action_prompt_command_name[0..state.action_prompt_command_name_len];
        const text = state.action_prompt_buffer[0..state.action_prompt_len];
        if (name.len == 0) return;

        if (state.action_prompt_host_only or !runtime_host.isActive()) {
            _ = handleHostCommand(name, text);
        } else {
            _ = runtime_host.sendCommand(name, text);
        }

        if (state.action_prompt_close_on_execute) {
            state.action_prompt_active = false;
            state.action_prompt_close_on_execute = true;
            state.action_prompt_host_only = false;
            state.action_prompt_command_name_len = 0;
            state.action_prompt_title_len = 0;
            state.action_prompt_placeholder_len = 0;
            @memset(&state.action_prompt_buffer, 0);
            state.action_prompt_len = 0;
            dvui.focusWidget(null, null, null);
        } else {
            // Keep input mode open for repeated use (e.g., add multiple items).
            @memset(&state.action_prompt_buffer, 0);
            state.action_prompt_len = 0;
        }
        return;
    }

    const cmd = actions.commandAt(state.command_selected_index);
    if (cmd) |command| {
        if (command.name.len == 0) return;

        // Input action: switch the panel top into input mode (keep the overlay simple).
        if (command.input) |inp| {
            state.action_prompt_active = true;
            state.action_prompt_close_on_execute = command.close_on_execute;
            state.action_prompt_host_only = command.host_only;

            const name_len = @min(command.name.len, state.action_prompt_command_name.len);
            @memcpy(state.action_prompt_command_name[0..name_len], command.name[0..name_len]);
            state.action_prompt_command_name_len = name_len;

            const title_len = @min(command.title.len, state.action_prompt_title.len);
            @memcpy(state.action_prompt_title[0..title_len], command.title[0..title_len]);
            state.action_prompt_title_len = title_len;

            const placeholder_len = @min(inp.placeholder.len, state.action_prompt_placeholder.len);
            @memcpy(state.action_prompt_placeholder[0..placeholder_len], inp.placeholder[0..placeholder_len]);
            state.action_prompt_placeholder_len = placeholder_len;

            @memset(&state.action_prompt_buffer, 0);
            const init_len = @min(inp.initial.len, state.action_prompt_buffer.len);
            @memcpy(state.action_prompt_buffer[0..init_len], inp.initial[0..init_len]);
            state.action_prompt_len = init_len;

            // Close overlay immediately; user types in the top panel area.
            if (state.nav.action_open) {
                state.nav.action_open = false;
                state.ipc.clearActionsData();
                dvui.focusWidget(null, null, null);
            }
            return;
        }

        const text_for_command = actions.commandPayload(command);

        // Route action either locally or via Bun.
        if (command.host_only or !runtime_host.isActive()) {
            _ = handleHostCommand(command.name, text_for_command);
        } else {
            _ = runtime_host.sendCommand(command.name, text_for_command);
        }

        // Close overlay after execution.
        if (command.close_on_execute and state.nav.action_open) {
            state.nav.action_open = false;
            state.ipc.clearActionsData();
            dvui.focusWidget(null, null, null);
        }
    }
}

fn sendActionsIfQueuedFrame() void {
    // Clear any cached actions when the overlay is closed.
    if (!state.nav.action_open) {
        if (state.ipc.actions_data != null or state.ipc.actions_pending or state.ipc.actions_request_queued) {
            state.ipc.clearActionsData();
        }
        return;
    }

    // Only send one request at a time.
    if (state.ipc.actions_pending) return;
    if (!state.ipc.actions_request_queued) return;
    state.ipc.actions_request_queued = false;

    // Remote actions require a running runtime process and a plugin-owned selection context.
    const ctx = actions.bunActionsContextOrNull() orelse return;
    if (!runtime_host.isActive()) return;

    const token = state.ipc.nextActionsToken();
    state.ipc.actions_pending = true;
    if (!runtime_host.sendGetActions(token, ctx.panel, ctx.plugin_id, ctx.item_id, ctx.selected_id, ctx.selected_text, ctx.query)) {
        state.ipc.actions_pending = false;
    }
}

fn sendQueryIfChangedFrame() void {
    if (!runtime_host.isActive()) return;

    const query = state.search_buffer[0..state.search_len];
    const h = std.hash.Wyhash.hash(0, query);
    const now_ms: i64 = std.time.milliTimestamp();
    if (h != last_query_hash) {
        last_query_hash = h;
        last_query_change_ms = now_ms;
        state.ipc.results_pending = true;
    }

    // Debounce to avoid spamming the runtime (especially for network-backed plugins).
    const debounce_ms: i64 = 120;
    if (state.ipc.results_pending and (now_ms - last_query_change_ms) >= debounce_ms) {
        _ = runtime_host.sendQuery(query);
        // Keep results_pending true until we receive a results message.
    }
}

fn enterDetailsPanelFrame() void {
    // Clear old panel data
    if (state.ipc.panel_data) |*s| {
        s.deinit();
        state.ipc.panel_data = null;
    }

    state.clearDetailsPluginId();
    state.clearDetailsItemId();

    // Entering details doesn't always mean we need a Bun panel.
    state.ipc.panel_pending = false;
    const details = state.currentDetails() orelse return;
    if (details.source != .plugin) return;

    const sel = search.getSelectedItem();
    if (sel) |s| switch (s) {
        .plugin => |item| {
            state.setDetailsPluginId(item.pluginId);
            const item_id: []const u8 = item.id orelse item.title;
            state.setDetailsItemId(item_id);
            state.setSelectedItemInfo(item.title, item.subtitle orelse "");
            if (runtime_host.isActive()) {
                state.ipc.panel_pending = true;
                if (!runtime_host.sendGetPanel(item.pluginId, item_id)) {
                    state.ipc.panel_pending = false;
                }
            }
        },
        // Defensive: plugin details but search selection isn't a plugin item.
        .mock => {},
    };
}

fn leaveDetailsPanelFrame() void {
    if (state.ipc.panel_data) |*s| {
        s.deinit();
        state.ipc.panel_data = null;
    }
    state.ipc.panel_pending = false;
    state.clearDetailsPluginId();
    state.clearDetailsItemId();
}

fn handleDetailsPanelTransitionsFrame() void {
    const now = state.currentPanel();
    if (now == .details and last_panel != .details) {
        enterDetailsPanelFrame();
    }
    if (now != .details and last_panel == .details) {
        leaveDetailsPanelFrame();
    }
    last_panel = now;
}

// Executed every frame to draw UI
pub fn AppFrame() !dvui.App.Result {
    if (handleTrayFrame()) |res| return res;
    if (try handleKeyboardFrame()) |res| return res;

    // Main container with padding
    var main_box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = true,
        .color_fill = style.colors.app_background,
    });
    defer main_box.deinit();

    handleCommandExecutionFrame();
    sendActionsIfQueuedFrame();
    handleDetailsPanelTransitionsFrame();
    try panels.renderTopArea(state.currentPanel());
    sendQueryIfChangedFrame();
    runtime_host.pollMessages(allocator, state.handleBunMessage);
    try panels.renderPanelsArea(state.currentPanel());

    return .ok;
}
