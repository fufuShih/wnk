const std = @import("std");
const dvui = @import("dvui");
const SDLBackend = @import("sdl-backend");

// Import modules
const state = @import("state.zig");
const keyboard = @import("ui/keyboard.zig");
const search = @import("ui/search.zig");
const results = @import("ui/results.zig");
const panels = @import("ui/panels.zig");
const plugin = @import("plugin.zig");

var last_query_hash: u64 = 0;

// Global plugin process
var bun_process: ?plugin.BunProcess = null;
var gpa = std.heap.GeneralPurposeAllocator(.{}){};
const allocator = gpa.allocator();

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

    // Initialize state
    state.init(allocator);

    // Start Bun plugin process (calculator-only)
    bun_process = plugin.BunProcess.spawn(allocator) catch |err| {
        std.debug.print("Failed to start Bun process: {}\n", .{err});
        return;
    };

    std.debug.print("Bun plugin process started\n", .{});
}

// Executed before application closes, before dvui.Window.deinit()
pub fn AppDeinit() void {
    // Clean up plugin process
    if (bun_process) |*proc| {
        proc.deinit();
        bun_process = null;
    }
    state.deinit();
}

// Executed every frame to draw UI
pub fn AppFrame() !dvui.App.Result {
    // Handle keyboard events
    const kb_result = try keyboard.handleEvents();
    if (kb_result == .close) {
        return .close;
    }

    // Main container with padding
    var main_box = dvui.box(@src(), .{ .dir = .vertical }, .{
        .expand = .both,
        .background = true,
        .color_fill = .{ .r = 0x1e, .g = 0x1e, .b = 0x2e },
    });
    defer main_box.deinit();

    // Keep the base Wink layout always visible
    _ = dvui.spacer(@src(), .{ .min_size_content = .{ .h = 20 } });
    try search.render();

    // Execute command selected in command panel (triggered by Enter in keyboard handler).
    if (state.command_execute) {
        state.command_execute = false;

        const sel = results.getSelectedItem();
        const cmd = panels.getCommand(state.command_selected_index);

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

    // Render the active panel
    switch (state.panel_mode) {
        .main => try results.render(),
        .sub => try panels.renderSub(results.getSelectedItem()),
        .command => try panels.renderCommand(results.getSelectedItem()),
    }

    return .ok;
}
