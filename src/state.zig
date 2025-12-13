const std = @import("std");

// Search buffer for the input field
pub var search_buffer: [256]u8 = undefined;
pub var search_len: usize = 0;
pub var search_initialized = false;

// Selection state
pub var selected_index: usize = 0;
pub var focus_on_results = false;

// Mock search results
pub const SearchResult = struct {
    title: []const u8,
    subtitle: []const u8,
    icon: []const u8,
};

pub const mock_results = [_]SearchResult{
    .{ .title = "Calculator", .subtitle = "Application", .icon = "=" },
    .{ .title = "Calendar", .subtitle = "System Preferences", .icon = "C" },
    .{ .title = "Camera", .subtitle = "Devices", .icon = "O" },
    .{ .title = "Chrome", .subtitle = "Web Browser", .icon = "@" },
    .{ .title = "Code", .subtitle = "Development", .icon = "#" },
};

pub fn init() void {
    @memset(&search_buffer, 0);
    search_initialized = true;
}
