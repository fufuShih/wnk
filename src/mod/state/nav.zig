const std = @import("std");

const mock = @import("mock.zig");
const ipc = @import("ipc.zig");

pub const Panel = enum {
    search,
    details,
    commands,
};

pub const DetailsSource = enum {
    plugin,
    mock,
};

pub const DetailsPanel = struct {
    source: DetailsSource = .plugin,
    mock_panel: ?*const mock.PanelData = null,
    selected_index: usize = 0,
};

pub const PanelEntry = union(Panel) {
    search: void,
    details: DetailsPanel,
    commands: void,
};

pub const default_panel_entry: PanelEntry = .{ .search = {} };
pub const default_panel: Panel = .search;

pub const Navigation = struct {
    panel_stack: [8]PanelEntry = undefined,
    panel_stack_len: usize = 0,

    /// Floating action panel overlay (does not affect the panel stack).
    action_open: bool = false,

    pub fn resetPanels(self: *Navigation) void {
        self.panel_stack[0] = default_panel_entry;
        self.panel_stack_len = 1;
        self.action_open = false;
    }

    pub fn currentPanel(self: *const Navigation) Panel {
        return std.meta.activeTag(self.panel_stack[self.panel_stack_len - 1]);
    }

    pub fn currentDetails(self: *Navigation) ?*DetailsPanel {
        if (self.panel_stack[self.panel_stack_len - 1] == .details) {
            return &self.panel_stack[self.panel_stack_len - 1].details;
        }
        return null;
    }

    pub fn canPopPanel(self: *const Navigation) bool {
        return self.panel_stack_len > 1;
    }

    pub fn pushPanel(self: *Navigation, p: PanelEntry) void {
        if (self.panel_stack_len >= self.panel_stack.len) return;
        self.panel_stack[self.panel_stack_len] = p;
        self.panel_stack_len += 1;
    }

    pub fn popPanel(self: *Navigation) void {
        if (self.panel_stack_len > 1) self.panel_stack_len -= 1;
    }

    pub fn openPluginDetails(self: *Navigation) void {
        self.pushPanel(.{ .details = .{ .source = .plugin, .mock_panel = null, .selected_index = 0 } });
    }

    pub fn openMockDetails(self: *Navigation, panel: *const mock.PanelData) void {
        self.pushPanel(.{ .details = .{ .source = .mock, .mock_panel = panel, .selected_index = 0 } });
    }

    pub fn openCommands(self: *Navigation) void {
        self.pushPanel(.{ .commands = {} });
    }

    pub fn detailsItemsCount(self: *Navigation) usize {
        const d = self.currentDetails() orelse return 0;
        if (d.source == .mock) {
            const p = d.mock_panel orelse return 0;
            const list = mock.panelList(p) orelse return 0;
            return list.items.len;
        }

        // plugin details: only selectable when data exists
        if (ipc.currentSubpanelView()) |v| return v.items.len;
        return 0;
    }

    pub fn detailsClampSelection(self: *Navigation) void {
        const d = self.currentDetails() orelse return;
        const count = self.detailsItemsCount();
        if (count == 0) {
            d.selected_index = 0;
            return;
        }
        if (d.selected_index >= count) d.selected_index = count - 1;
    }

    pub fn detailsMoveSelection(self: *Navigation, delta: isize) void {
        const d = self.currentDetails() orelse return;
        const count = self.detailsItemsCount();
        if (count == 0) return;

        const cur: isize = @intCast(d.selected_index);
        var next: isize = cur + delta;
        if (next < 0) next = 0;
        if (next >= @as(isize, @intCast(count))) next = @as(isize, @intCast(count - 1));
        d.selected_index = @intCast(next);
    }

    pub fn detailsSelectedNextPanel(self: *Navigation) ?*const mock.PanelData {
        const d = self.currentDetails() orelse return null;
        if (d.source != .mock) return null;
        const p = d.mock_panel orelse return null;
        const list = mock.panelList(p) orelse return null;
        if (list.items.len == 0) return null;
        if (d.selected_index >= list.items.len) return null;
        return list.items[d.selected_index].next_panel;
    }
};
