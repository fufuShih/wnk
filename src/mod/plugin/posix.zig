const std = @import("std");

pub fn readAvailableIntoPending(self: anytype) !void {
    var tmp: [4096]u8 = undefined;
    var fds = [_]std.posix.pollfd{
        .{
            .fd = self.stdout_file.handle,
            .events = std.posix.POLL.IN,
            .revents = 0,
        },
    };

    while (true) {
        fds[0].revents = 0;
        const ready = std.posix.poll(&fds, 0) catch return error.ReadFailed;
        if (ready == 0) return;

        const revents = fds[0].revents;
        if ((revents & std.posix.POLL.NVAL) != 0) return error.ReadFailed;
        if ((revents & std.posix.POLL.ERR) != 0) return error.ReadFailed;
        if ((revents & (std.posix.POLL.IN | std.posix.POLL.HUP)) == 0) return;

        const n = self.stdout_file.read(tmp[0..]) catch |err| switch (err) {
            error.WouldBlock => return,
            else => return error.ReadFailed,
        };
        if (n == 0) return;

        try self.pending_buffer.appendSlice(self.allocator, tmp[0..n]);
    }
}
