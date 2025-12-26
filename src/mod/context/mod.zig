const std = @import("std");
const runtime = @import("runtime");
const selection = @import("selection");

pub const Manager = struct {
    pub fn captureAndSend(_: *Manager, allocator: std.mem.Allocator, host: *runtime.RuntimeHost) void {
        if (!host.isActive()) return;

        var ctx: runtime.HostContext = .{
            .timestampMs = std.time.milliTimestamp(),
        };

        if (selection.capture(allocator) catch null) |sel| {
            defer selection.free(allocator, sel);
            ctx.selectionText = sel.text;
            ctx.selectionSource = selection.sourceTag(sel.source);
        }

        _ = host.sendContext(ctx);
    }
};
