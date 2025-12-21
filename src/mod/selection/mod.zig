const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");

pub const SelectionSource = types.SelectionSource;
pub const Selection = types.Selection;

pub fn sourceTag(source: SelectionSource) []const u8 {
    return switch (source) {
        .os => "os",
        .clipboard => "clipboard",
    };
}

pub fn capture(allocator: std.mem.Allocator) !?Selection {
    return switch (builtin.os.tag) {
        .windows => try @import("windows.zig").capture(allocator),
        .macos => try @import("macos.zig").capture(allocator),
        else => null,
    };
}

pub fn free(allocator: std.mem.Allocator, sel: Selection) void {
    allocator.free(sel.text);
}
