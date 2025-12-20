const dvui = @import("dvui");
const state = @import("state");
const search = @import("search.zig");
const actions = @import("actions.zig");

pub const KeyboardResult = enum {
    ok,
    close,
    hide,
};

pub fn handleEvents() !KeyboardResult {
    const evt = dvui.events();
    for (evt) |*e| {
        // This UI is keyboard-driven: ignore all mouse interactions.
        if (e.evt == .mouse) {
            e.handled = true;
            continue;
        }

        if (e.evt == .key and e.evt.key.action == .down) {
            const code = e.evt.key.code;

            // ESC behavior:
            // - action overlay: close overlay
            // - nested panels: pop
            // - root(search): hide to tray
            if (code == .escape) {
                if (state.action_prompt_active) {
                    state.action_prompt_active = false;
                    state.action_prompt_close_on_execute = true;
                    state.action_prompt_host_only = false;
                    state.action_prompt_command_name_len = 0;
                    state.action_prompt_title_len = 0;
                    state.action_prompt_placeholder_len = 0;
                    @memset(&state.action_prompt_buffer, 0);
                    state.action_prompt_len = 0;
                    dvui.focusWidget(null, null, null);
                    e.handled = true;
                } else if (state.nav.action_open) {
                    state.nav.action_open = false;
                    dvui.focusWidget(null, null, null);
                    e.handled = true;
                } else if (state.canPopPanel()) {
                    state.popPanel();
                    // Returning to the root/search panel should focus the main list.
                    if (state.currentPanel() == .search) {
                        state.focus_on_results = true;
                    }
                    dvui.focusWidget(null, null, null);
                    e.handled = true;
                } else {
                    return .hide;
                }
            }

            // Tab to switch focus between search and results (search panel only)
            if (code == .tab and state.currentPanel() == .search and !state.nav.action_open) {
                state.focus_on_results = !state.focus_on_results;
                if (state.focus_on_results) state.selected_index = 0;
                dvui.focusWidget(null, null, null);
                e.handled = true;
            }

            // Enter behavior depends on current panel.
            if (code == .enter) {
                if (state.action_prompt_active) {
                    state.command_execute = true;
                    e.handled = true;
                } else if (state.nav.action_open) {
                    state.command_execute = true;
                    e.handled = true;
                } else {
                    switch (state.currentPanel()) {
                        .search => {
                            // Search input -> results; results -> details.
                            if (!state.focus_on_results) {
                                state.focus_on_results = true;
                                state.selected_index = 0;
                                dvui.focusWidget(null, null, null);
                            } else {
                                const sel = search.getSelectedItem();
                                if (sel) |s| {
                                    switch (s) {
                                        .plugin => |item| {
                                            state.setSelectedItemInfo(item.title, item.subtitle orelse "");
                                            state.openPluginDetails();
                                        },
                                        .mock => |item| {
                                            if (item.next_panel) |p| {
                                                const h = state.panelHeader(p);
                                                state.setSelectedItemInfo(h.title, h.subtitle orelse "");
                                                state.openMockDetails(p);
                                            }
                                        },
                                    }
                                    state.command_selected_index = 0;
                                    dvui.focusWidget(null, null, null);
                                }
                            }
                            e.handled = true;
                        },
                        .details => {
                            if (state.detailsSelectedNextPanel()) |next_panel| {
                                const h = state.panelHeader(next_panel);
                                state.setSelectedItemInfo(h.title, h.subtitle orelse "");
                                state.openMockDetails(next_panel);
                            }
                            state.command_selected_index = 0;
                            dvui.focusWidget(null, null, null);
                            e.handled = true;
                        },
                    }
                }
            }

            // 'k' opens the floating action overlay when the main selection provides actions.
            if (code == .k and !state.action_prompt_active and actions.canOpenOverlay()) {
                actions.openOverlay();
                e.handled = true;
            }

            // W/S keys for navigation
            if (code == .w or code == .s) {
                if (state.nav.action_open) {
                    if (code == .w) {
                        if (state.command_selected_index > 0) state.command_selected_index -= 1;
                    } else {
                        state.command_selected_index += 1;
                    }
                    e.handled = true;
                } else if (state.currentPanel() == .details and !state.action_prompt_active) {
                    if (code == .w) state.detailsMoveSelection(-1) else state.detailsMoveSelection(1);
                    e.handled = true;
                } else if (state.currentPanel() == .search and state.focus_on_results) {
                    if (code == .w) {
                        if (state.selected_index > 0) state.selected_index -= 1;
                    } else {
                        state.selected_index += 1;
                    }
                    e.handled = true;
                }
            }
        }
    }

    return .ok;
}
