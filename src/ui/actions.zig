const std = @import("std");
const state = @import("state");

const search = @import("search.zig");

pub const Command = struct {
    // Sent to Bun as { type: "command", name, text }
    name: []const u8,
    title: []const u8,
};

const action_commands = [_]Command{
    .{ .name = "setSearchText", .title = "Use as query" },
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
    if (actions().len == 0) return false;
    return commandTextOrNull() != null;
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
}

/// Returns the text sent to Bun when executing a command.
/// This tries to use the most specific selection in the current panel.
pub fn commandText() []const u8 {
    return commandTextOrNull() orelse state.getSelectedItemTitle();
}

/// Returns the action list for the current selection.
/// This is where per-region / per-item actions can be dispatched in the future.
pub fn actions() []const Command {
    return action_commands[0..];
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
        const list = state.panelList(p) orelse return state.getSelectedItemTitle();
        if (list.items.len == 0) return null;
        if (d.selected_index >= list.items.len) return null;
        return list.items[d.selected_index].title;
    }

    // Plugin details: prefer the selected IPC item (if loaded).
    if (state.ipc.currentSubpanelView()) |v| {
        if (state.ipc.subpanelItemAtIndex(v.main, d.selected_index)) |it| {
            return it.title;
        }
    }

    // Fallback to the stored root selection (e.g., while loading).
    return state.getSelectedItemTitle();
}
