const dvui = @import("dvui");
const state = @import("../state.zig");

pub fn handleEvents() !dvui.App.Result {
    const evt = dvui.events();
    for (evt) |*e| {
        if (e.evt == .key and e.evt.key.action == .down) {
            // ESC to close window
            if (e.evt.key.code == .escape) {
                return .close;
            }

            // Tab to switch focus between search and results
            if (e.evt.key.code == .tab) {
                state.focus_on_results = !state.focus_on_results;
                if (state.focus_on_results) {
                    state.selected_index = 0;
                }
                dvui.focusWidget(null, null, null);
                e.handled = true;
            }

            // W/S keys for navigation when focus is on results
            if (state.focus_on_results) {
                if (e.evt.key.code == .w) {
                    if (state.selected_index > 0) {
                        state.selected_index -= 1;
                    }
                    e.handled = true;
                } else if (e.evt.key.code == .s) {
                    state.selected_index += 1;
                    e.handled = true;
                }
            }
        }
    }

    return .ok;
}
