const dvui = @import("dvui");
const state = @import("../state.zig");

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
            // - command panel: back to previous panel
            // - action panel: back to previous panel
            // - list/sub: back to main
            // - sub panel: back to main
            // - main: hide to tray
            if (code == .escape) {
                switch (state.panel_mode) {
                    .command => {
                        state.panel_mode = state.prev_panel_mode;
                        e.handled = true;
                    },
                    .action => {
                        state.panel_mode = state.prev_panel_mode;
                        dvui.focusWidget(null, null, null);
                        e.handled = true;
                    },
                    .sub, .list => {
                        state.panel_mode = .main;
                        state.focus_on_results = true;
                        e.handled = true;
                    },
                    .main => return .hide,
                }
            }

            // Tab to switch focus between search and results (main panel only)
            if (code == .tab and state.panel_mode == .main) {
                state.focus_on_results = !state.focus_on_results;
                if (state.focus_on_results) state.selected_index = 0;
                dvui.focusWidget(null, null, null);
                e.handled = true;
            }

            // Enter behavior depends on current panel.
            if (code == .enter) {
                switch (state.panel_mode) {
                    .main => {
                        // Search -> results; Results -> list panel.
                        if (!state.focus_on_results) {
                            state.focus_on_results = true;
                            state.selected_index = 0;
                        } else {
                            state.panel_mode = .list;
                            state.command_selected_index = 0;
                        }
                        e.handled = true;
                    },
                    .list => {
                        // Open floating actions from the list panel.
                        state.prev_panel_mode = .list;
                        state.panel_mode = .action;
                        state.command_selected_index = 0;
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
                    .action => {
                        state.command_execute = true;
                        e.handled = true;
                    },
                }
            }

            // 'k' opens action panel from main/sub when applicable.
            if (code == .k) {
                if (state.panel_mode == .main and state.focus_on_results) {
                    state.prev_panel_mode = .main;
                    state.panel_mode = .action;
                    state.command_selected_index = 0;
                    e.handled = true;
                } else if (state.panel_mode == .sub) {
                    state.prev_panel_mode = .sub;
                    state.panel_mode = .action;
                    state.command_selected_index = 0;
                    e.handled = true;
                } else if (state.panel_mode == .list) {
                    state.prev_panel_mode = .list;
                    state.panel_mode = .action;
                    state.command_selected_index = 0;
                    e.handled = true;
                }
            }

            // W/S keys for navigation
            if (code == .w or code == .s) {
                if (state.panel_mode == .command or state.panel_mode == .action) {
                    if (code == .w) {
                        if (state.command_selected_index > 0) state.command_selected_index -= 1;
                    } else {
                        state.command_selected_index += 1;
                    }
                    e.handled = true;
                } else if (state.panel_mode == .main and state.focus_on_results) {
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
