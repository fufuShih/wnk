const std = @import("std");
const types = @import("types.zig");

pub fn capture(_: std.mem.Allocator) !?types.Selection {
    // TODO: Implement via AXUIElement (Accessibility) to read selected text.
    return null;
}
