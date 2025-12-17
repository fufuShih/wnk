const std = @import("std");

const windows = std.os.windows;

extern "kernel32" fn PeekNamedPipe(
    hNamedPipe: windows.HANDLE,
    lpBuffer: ?*anyopaque,
    nBufferSize: u32,
    lpBytesRead: ?*u32,
    lpTotalBytesAvail: ?*u32,
    lpBytesLeftThisMessage: ?*u32,
) callconv(.winapi) windows.BOOL;

fn bytesAvailable(handle: windows.HANDLE) !u32 {
    var available: u32 = 0;
    const ok = PeekNamedPipe(handle, null, 0, null, &available, null);
    if (ok == 0) return error.ReadFailed;
    return available;
}

pub fn readAvailableIntoPending(self: anytype) !void {
    var available = try bytesAvailable(self.stdout_file.handle);
    var tmp: [4096]u8 = undefined;

    while (available > 0) {
        const to_read: usize = @min(tmp.len, available);
        const n = self.stdout_file.read(tmp[0..to_read]) catch return error.ReadFailed;
        if (n == 0) return;

        try self.pending_buffer.appendSlice(self.allocator, tmp[0..n]);
        available -= @intCast(n);

        if (available == 0) {
            // More may have arrived while we were reading.
            available = try bytesAvailable(self.stdout_file.handle);
        }
    }
}
