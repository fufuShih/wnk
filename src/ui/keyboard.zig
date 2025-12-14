const dvui = @import("dvui");
const state = @import("state");

pub const KeyboardResult = enum {
    ok,
    close,
    hide,
};

pub fn handleEvents() !KeyboardResult {
    const evt = dvui.events();
    for (evt) |*e| {
        if (e.evt == .key and e.evt.key.action == .down) {
            const code = e.evt.key.code;

            // ESC behavior:
            // - action overlay: close overlay
            // - nested panels: pop
            // - root(search): hide to tray
            if (code == .escape) {
                if (state.action_open) {
                    state.action_open = false;
                    dvui.focusWidget(null, null, null);
                    e.handled = true;
                } else if (state.canPopPanel()) {
                    state.popPanel();
                    state.focus_on_results = true;
                    e.handled = true;
                } else {
                    return .hide;
                }
            }

            // Tab to switch focus between search and results (search panel only)
            if (code == .tab and state.currentPanel() == .search and !state.action_open) {
                state.focus_on_results = !state.focus_on_results;
                if (state.focus_on_results) state.selected_index = 0;
                dvui.focusWidget(null, null, null);
                e.handled = true;
            }

            // Enter behavior depends on current panel.
            if (code == .enter) {
                if (state.action_open) {
                    state.command_execute = true;
                    e.handled = true;
                } else {
                    switch (state.currentPanel()) {
                        .search => {
                            // Search input -> results; results -> details.
                            if (!state.focus_on_results) {
                                state.focus_on_results = true;
                                state.selected_index = 0;
                            } else {
                                state.pushPanel(.details);
                                state.command_selected_index = 0;
                            }
                            e.handled = true;
                        },
                        .details => {
                            state.pushPanel(.commands);
                            state.command_selected_index = 0;
                            e.handled = true;
                        },
                        .commands => {
                            state.command_execute = true;
                            e.handled = true;
                        },
                    }
                }
            }

            // 'k' opens the floating action overlay.
            if (code == .k and !state.action_open) {
                if (state.currentPanel() == .search and state.focus_on_results) {
                    state.action_open = true;
                    state.command_selected_index = 0;
                    e.handled = true;
                } else if (state.currentPanel() == .details or state.currentPanel() == .commands) {
                    state.action_open = true;
                    state.command_selected_index = 0;
                    e.handled = true;
                }
            }

            // W/S keys for navigation
            if (code == .w or code == .s) {
                if (state.action_open or state.currentPanel() == .commands) {
                    if (code == .w) {
                        if (state.command_selected_index > 0) state.command_selected_index -= 1;
                    } else {
                        state.command_selected_index += 1;
                    }
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
