const std = @import("std");
const state = @import("state");

const search = @import("search.zig");

pub const CommandInput = struct {
    placeholder: []const u8 = "",
    initial: []const u8 = "",
};

pub const Command = struct {
    // Sent to Bun as { type: "command", name, text }
    name: []const u8,
    title: []const u8,
    /// Optional payload string; sent as the command `text` field.
    text: ?[]const u8 = null,
    close_on_execute: bool = true,
    /// Optional prompt input config; if set, the host will collect text before executing.
    input: ?CommandInput = null,
    /// Whether this command should be executed locally (host-only).
    host_only: bool = false,
};

const default_commands = [_]Command{
    .{ .name = "setSearchText", .title = "Use as query", .host_only = true },
};

var remote_commands: [64]Command = undefined;
var remote_commands_len: usize = 0;

const loading_commands = [_]Command{
    .{ .name = "", .title = "Loading...", .close_on_execute = false },
};

/// Action overlay context helpers.
/// The overlay is not a panel/region by itself; it depends on the *currently focused* main content.
/// Returns whether the main content currently has focus (vs. the top/search input).
pub fn isMainFocused() bool {
    return switch (state.currentPanel()) {
        .search => state.focus_on_results,
        .details => true,
    };
}

/// Whether the current main selection provides actions and can open the overlay.
/// This is equivalent to a `hasCommand` flag for the current selection.
pub fn hasCommand() bool {
    if (!isMainFocused()) return false;
    // Host commands need text; remote commands need plugin context.
    return bunActionsContextOrNull() != null or commandTextOrNull() != null;
}

/// Whether the overlay can be opened *right now* (not already open).
pub fn canOpenOverlay() bool {
    return !state.nav.action_open and hasCommand();
}

/// Opens the action overlay if the current context supports it.
pub fn openOverlay() void {
    if (!canOpenOverlay()) return;
    state.nav.action_open = true;
    state.command_selected_index = 0;
    state.action_prompt_active = false;
    state.action_prompt_close_on_execute = true;
    state.action_prompt_host_only = false;
    state.action_prompt_command_name_len = 0;
    state.action_prompt_title_len = 0;
    state.action_prompt_placeholder_len = 0;
    @memset(&state.action_prompt_buffer, 0);
    state.action_prompt_len = 0;

    // Always clear stale remote actions on open.
    state.ipc.clearActionsData();

    // Request remote actions only when focused selection belongs to a plugin.
    if (bunActionsContextOrNull() != null) {
        state.ipc.queueActionsRequest();
    }
}

/// Returns the text sent to Bun when executing a command.
/// This tries to use the most specific selection in the current panel.
pub fn commandText() []const u8 {
    return commandTextOrNull() orelse state.getSelectedItemTitle();
}

pub fn commandPayload(cmd: Command) []const u8 {
    if (cmd.text) |t| return t;
    if (std.mem.eql(u8, cmd.name, "setSearchText")) return commandText();
    return commandText();
}

/// Returns the action list for the current selection.
/// This is where per-region / per-item actions can be dispatched in the future.
pub fn actions() []const Command {
    if (buildRemoteCommands()) |list| {
        if (list.len > 0) return list;
        // While a plugin action request is queued/in-flight, keep the overlay open with a placeholder.
        if (state.nav.action_open and (state.ipc.actions_request_queued or state.ipc.actions_pending)) {
            return loading_commands[0..];
        }
    } else if (state.nav.action_open and (state.ipc.actions_request_queued or state.ipc.actions_pending)) {
        return loading_commands[0..];
    }

    return default_commands[0..];
}

/// Returns the action at the given index for the current selection.
pub fn commandAt(index: usize) ?Command {
    const list = actions();
    if (index >= list.len) return null;
    return list[index];
}

fn commandTextOrNull() ?[]const u8 {
    return switch (state.currentPanel()) {
        .search => selectedTextFromSearch(),
        .details => selectedTextFromDetails(),
    };
}

pub const BunActionsContext = struct {
    panel: []const u8,
    plugin_id: []const u8,
    item_id: []const u8,
    selected_id: []const u8,
    selected_text: []const u8,
    query: []const u8,
};

/// Returns the current context for requesting plugin-provided actions from Bun.
/// If the selection is not a plugin-owned item, returns null.
pub fn bunActionsContextOrNull() ?BunActionsContext {
    if (!isMainFocused()) return null;

    const query = state.search_buffer[0..state.search_len];

    if (state.currentPanel() == .search) {
        const sel = search.getSelectedItem() orelse return null;
        return switch (sel) {
            .plugin => |item| .{
                .panel = "search",
                .plugin_id = item.pluginId,
                .item_id = item.id orelse item.title,
                .selected_id = item.id orelse item.title,
                .selected_text = item.title,
                .query = query,
            },
            .mock => null,
        };
    }

    // Details panel: only plugin-owned details can provide actions.
    const d = state.currentDetails() orelse return null;
    if (d.source != .plugin) return null;

    const plugin_id = state.getDetailsPluginId();
    if (plugin_id.len == 0) return null;

    const item_id = if (state.getDetailsItemId().len > 0) state.getDetailsItemId() else state.getSelectedItemTitle();

    const v = state.ipc.currentPanelView() orelse return null;
    const it = state.ipc.panelItemAtIndex(v.main, d.selected_index) orelse return null;
    if (!(it.has_actions orelse false)) return null;

    const selected_id: []const u8 = it.id orelse it.title;
    const selected_text: []const u8 = it.title;
    if (selected_text.len == 0) return null;

    return .{
        .panel = "details",
        .plugin_id = plugin_id,
        .item_id = item_id,
        .selected_id = selected_id,
        .selected_text = selected_text,
        .query = query,
    };
}

fn buildRemoteCommands() ?[]const Command {
    const parsed = state.ipc.actions_data orelse return null;

    remote_commands_len = 0;
    const n = @min(parsed.value.items.len, remote_commands.len);
    var i: usize = 0;
    while (i < n) : (i += 1) {
        const it = parsed.value.items[i];
        const input: ?CommandInput = if (it.input) |inp| .{
            .placeholder = inp.placeholder orelse "",
            .initial = inp.initial orelse "",
        } else null;
        remote_commands[i] = .{
            .name = it.name,
            .title = it.title,
            .text = it.text,
            .close_on_execute = it.close_on_execute orelse true,
            .input = input,
            .host_only = it.host_only orelse false,
        };
    }
    remote_commands_len = n;

    return remote_commands[0..remote_commands_len];
}

fn selectedTextFromSearch() ?[]const u8 {
    // Only allow actions when the results list is focused.
    if (!state.focus_on_results) return null;

    const sel = search.getSelectedItem() orelse return null;
    return switch (sel) {
        .plugin => |item| blk: {
            if (item.id) |id| {
                const prefix = "file:";
                if (std.mem.startsWith(u8, id, prefix)) break :blk id[prefix.len..];
            }
            break :blk item.title;
        },
        .mock => |item| item.title,
    };
}

fn selectedTextFromDetails() ?[]const u8 {
    const d = state.currentDetails() orelse return null;
    state.detailsClampSelection();

    if (d.source == .mock) {
        const p = d.mock_panel orelse return state.getSelectedItemTitle();
        const it = state.ipc.panelItemAtIndex(p.main, d.selected_index) orelse return state.getSelectedItemTitle();
        return it.title;
    }

    // Plugin details: prefer the selected IPC item (if loaded).
    if (state.ipc.currentPanelView()) |v| {
        if (state.ipc.panelItemAtIndex(v.main, d.selected_index)) |it| {
            return it.title;
        }
    }

    return null;
}
