const dvui = @import("dvui");
const state = @import("../state.zig");

pub fn handleEvents() !dvui.App.Result {
    const evt = dvui.events();
    for (evt) |*e| {
        if (e.evt == .key and e.evt.key.action == .down) {
            // ESC behavior:
            // - command panel: back to previous panel
            // - sub panel: back to main
            // - main: close window
            if (e.evt.key.code == .escape) {
                switch (state.panel_mode) {
                    .command => {
                        state.panel_mode = state.prev_panel_mode;
                        e.handled = true;
                    },
                    .sub => {
                        state.panel_mode = .main;
                        state.focus_on_results = true;
                        e.handled = true;
                    },
                    .main => return .close,
                }
            }

            // Tab to switch focus between search and results (main panel only)
            if (e.evt.key.code == .tab and state.panel_mode == .main) {
                state.focus_on_results = !state.focus_on_results;
                if (state.focus_on_results) state.selected_index = 0;
                dvui.focusWidget(null, null, null);
                e.handled = true;
            }

            // Enter behavior depends on current panel.
            if (e.evt.key.code == .enter) {
                switch (state.panel_mode) {
                    .main => {
                        // Search -> results; Results -> sub panel.
                        if (!state.focus_on_results) {
                            state.focus_on_results = true;
                            state.selected_index = 0;
                        } else {
                            state.panel_mode = .sub;
                        }
                        e.handled = true;
                    },
                    .sub => {
                        // In sub panel, Enter opens command panel.
                        state.prev_panel_mode = .sub;
                        state.panel_mode = .command;
                        state.command_selected_index = 0;
                        e.handled = true;
                    },
                    .command => {
                        state.command_execute = true;
                        e.handled = true;
                    },
                }
            }

            // 'k' opens command panel from main(sub) when applicable.
            if (e.evt.key.code == .k) {
                if (state.panel_mode == .main and state.focus_on_results) {
                    state.prev_panel_mode = .main;
                    state.panel_mode = .command;
                    state.command_selected_index = 0;
                    e.handled = true;
                } else if (state.panel_mode == .sub) {
                    state.prev_panel_mode = .sub;
                    state.panel_mode = .command;
                    state.command_selected_index = 0;
                    e.handled = true;
                }
            }

            // W/S keys for navigation
            if (e.evt.key.code == .w or e.evt.key.code == .s) {
                if (state.panel_mode == .command) {
                    if (e.evt.key.code == .w) {
                        if (state.command_selected_index > 0) state.command_selected_index -= 1;
                    } else {
                        state.command_selected_index += 1;
                    }
                    e.handled = true;
                } else if (state.panel_mode == .main and state.focus_on_results) {
                    if (e.evt.key.code == .w) {
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
