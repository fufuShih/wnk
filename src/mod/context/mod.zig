const std = @import("std");
const runtime = @import("runtime");
const selection = @import("selection");

pub const Manager = struct {
    pub fn captureAndSend(_: *Manager, allocator: std.mem.Allocator, host: *runtime.RuntimeHost) void {
        if (!host.isActive()) return;

        var ctx: runtime.HostContext = .{
            .timestampMs = std.time.milliTimestamp(),
        };

        const sel_opt = selection.capture(allocator) catch null;
        defer {
            if (sel_opt) |sel| selection.free(allocator, sel);
        }

        if (sel_opt) |sel| {
            ctx.selectionText = sel.text;
            ctx.selectionSource = selection.sourceTag(sel.source);
        }

        _ = host.sendContext(ctx);
    }
};
