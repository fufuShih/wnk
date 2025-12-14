// ============================================
// Plugin Module - Main entry point
// ============================================

const std = @import("std");
const builtin = @import("builtin");

const windows = std.os.windows;

extern "kernel32" fn PeekNamedPipe(
    hNamedPipe: windows.HANDLE,
    lpBuffer: ?*anyopaque,
    nBufferSize: u32,
    lpBytesRead: ?*u32,
    lpTotalBytesAvail: ?*u32,
    lpBytesLeftThisMessage: ?*u32,
) callconv(.winapi) windows.BOOL;

pub const BunProcess = struct {
    process: std.process.Child,
    stdout_file: std.fs.File,
    stdin_file: std.fs.File,
    allocator: std.mem.Allocator,

    // Returns are backed by this buffer (valid until next pollLine call).
    read_buffer: std.ArrayListUnmanaged(u8),
    // Accumulates stdout bytes across frames so pollLine can be non-blocking.
    pending_buffer: std.ArrayListUnmanaged(u8),

    // Spawn a new BunProcess
    pub fn spawn(allocator: std.mem.Allocator) !BunProcess {
        const argv = [_][]const u8{ "bun", "run", "core/runtime.tsx" };

        var child = std.process.Child.init(&argv, allocator);
        child.stdin_behavior = .Pipe;
        child.stdout_behavior = .Pipe;
        child.stderr_behavior = .Inherit;
        try child.spawn();

        // We take ownership of the pipe File handles below. Prevent std.process.Child
        // from attempting to close them again during wait()/kill() cleanup.
        const stdout_file = child.stdout.?;
        child.stdout = null;
        const stdin_file = child.stdin.?;
        child.stdin = null;

        return .{
            .process = child,
            .stdout_file = stdout_file,
            .stdin_file = stdin_file,
            .allocator = allocator,
            .read_buffer = .{},
            .pending_buffer = .{},
        };
    }

    fn windowsBytesAvailable(self: *BunProcess) !u32 {
        var available: u32 = 0;
        const ok = PeekNamedPipe(self.stdout_file.handle, null, 0, null, &available, null);
        if (ok == 0) return IpcError.ReadFailed;
        return available;
    }

    fn readAvailableIntoPending(self: *BunProcess) !void {
        if (builtin.os.tag != .windows) return;

        var available = try self.windowsBytesAvailable();
        var tmp: [4096]u8 = undefined;

        while (available > 0) {
            const to_read: usize = @min(tmp.len, available);
            const n = self.stdout_file.read(tmp[0..to_read]) catch |err| {
                if (err == error.EndOfStream) return;
                return IpcError.ReadFailed;
            };
            if (n == 0) return;

            try self.pending_buffer.appendSlice(self.allocator, tmp[0..n]);
            available -= @intCast(n);

            if (available == 0) {
                // More may have arrived while we were reading.
                available = try self.windowsBytesAvailable();
            }
        }
    }

    fn popLineFromPending(self: *BunProcess) !?[]const u8 {
        const pending = self.pending_buffer.items;
        const idx_opt = std.mem.indexOfScalar(u8, pending, '\n');
        if (idx_opt == null) return null;
        const idx = idx_opt.?;

        self.read_buffer.clearRetainingCapacity();
        if (idx > 0) {
            var end = idx;
            if (end > 0 and pending[end - 1] == '\r') end -= 1;
            try self.read_buffer.appendSlice(self.allocator, pending[0..end]);
        }

        const consume = idx + 1;
        const remaining = pending.len - consume;
        if (remaining > 0) {
            std.mem.copyForwards(u8, self.pending_buffer.items[0..remaining], pending[consume..]);
        }
        self.pending_buffer.items.len = remaining;

        if (self.read_buffer.items.len == 0) return null;
        return self.read_buffer.items;
    }

    /// Poll a single complete line from Bun stdout without blocking (Windows).
    pub fn pollLine(self: *BunProcess) !?[]const u8 {
        try self.readAvailableIntoPending();
        return try self.popLineFromPending();
    }

    pub fn sendEvent(self: *BunProcess, event_json: []const u8) !void {
        _ = self.stdin_file.write(event_json) catch return IpcError.WriteFailed;
        _ = self.stdin_file.write("\n") catch return IpcError.WriteFailed;
    }

    pub fn sendQuery(self: *BunProcess, query: []const u8) !void {
        const Msg = struct {
            type: []const u8 = "query",
            text: []const u8,
        };

        const json_line = try std.json.Stringify.valueAlloc(self.allocator, Msg{ .text = query }, .{});
        defer self.allocator.free(json_line);
        try self.sendEvent(json_line);
    }

    pub fn sendCommand(self: *BunProcess, name: []const u8, text: []const u8) !void {
        const Msg = struct {
            type: []const u8 = "command",
            name: []const u8,
            text: []const u8,
        };

        const json_line = try std.json.Stringify.valueAlloc(self.allocator, Msg{ .name = name, .text = text }, .{});
        defer self.allocator.free(json_line);
        try self.sendEvent(json_line);
    }

    pub fn deinit(self: *BunProcess) void {
        self.stdin_file.close();
        self.stdout_file.close();
        // Child no longer owns stdin/stdout handles (we nulled them in spawn), so
        // it is safe to wait/kill without double-closing.
        _ = self.process.kill() catch {};
        _ = self.process.wait() catch {};

        self.read_buffer.deinit(self.allocator);
        self.pending_buffer.deinit(self.allocator);
    }
};

pub const IpcError = error{
    ReadFailed,
    WriteFailed,
};
