// ============================================
// Plugin Module - Main entry point
// ============================================

const std = @import("std");
const builtin = @import("builtin");

pub const IpcError = error{
    ReadFailed,
    WriteFailed,
    EndOfStream,
};

const platform = switch (builtin.os.tag) {
    .windows => @import("windows.zig"),
    else => @import("posix.zig"),
};

pub const BunProcess = struct {
    process: std.process.Child,
    stdout_file: std.fs.File,
    stdin_file: std.fs.File,
    allocator: std.mem.Allocator,

    // Returns are backed by this buffer (valid until next pollLine call).
    read_buffer: std.ArrayListUnmanaged(u8),
    // Accumulates stdout bytes across frames so pollLine can be non-blocking.
    pending_buffer: std.ArrayListUnmanaged(u8),

    pub fn spawn(allocator: std.mem.Allocator) !BunProcess {
        const argv = [_][]const u8{ "bun", "run", "runtime-bun/runtime.tsx" };

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

    fn readAvailableIntoPending(self: *BunProcess) !void {
        platform.readAvailableIntoPending(self) catch |err| switch (err) {
            error.OutOfMemory => return err,
            error.EndOfStream => return IpcError.EndOfStream,
            else => return IpcError.ReadFailed,
        };
    }

    fn popLineFromPending(self: *BunProcess) !?[]const u8 {
        const pending = self.pending_buffer.items;
        const idx = std.mem.indexOfScalar(u8, pending, '\n') orelse return null;

        const line = pending[0..idx];
        const trimmed = if (line.len > 0 and line[line.len - 1] == '\r') line[0 .. line.len - 1] else line;

        self.read_buffer.clearRetainingCapacity();
        if (trimmed.len > 0) {
            try self.read_buffer.appendSlice(self.allocator, trimmed);
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

    /// Poll a single complete line from Bun stdout without blocking.
    pub fn pollLine(self: *BunProcess) !?[]const u8 {
        try self.readAvailableIntoPending();
        return try self.popLineFromPending();
    }

    pub fn sendEvent(self: *BunProcess, event_json: []const u8) !void {
        _ = self.stdin_file.write(event_json) catch return IpcError.WriteFailed;
        _ = self.stdin_file.write("\n") catch return IpcError.WriteFailed;
    }

    pub const QueryMsg = struct {
        type: []const u8 = "query",
        text: []const u8,
    };

    pub const CommandMsg = struct {
        type: []const u8 = "command",
        name: []const u8,
        text: []const u8,
    };

    pub const GetPanelMsg = struct {
        type: []const u8 = "getPanel",
        pluginId: []const u8,
        itemId: []const u8,
    };

    pub const ContextMsg = struct {
        type: []const u8 = "context",
        selectionText: ?[]const u8 = null,
        selectionSource: ?[]const u8 = null,
        windowTitle: ?[]const u8 = null,
        appId: ?[]const u8 = null,
        timestampMs: ?i64 = null,
    };

    pub const GetActionsMsg = struct {
        type: []const u8 = "getActions",
        token: u64,
        /// "search" or "details"
        panel: []const u8,
        pluginId: []const u8,
        /// Selected plugin result id (search) or root details item id (details).
        itemId: []const u8,
        /// Currently selected panel item id (details) when available.
        selectedId: []const u8,
        /// Human-readable selected text.
        selectedText: []const u8,
        /// Current query buffer (search input).
        query: []const u8,
    };

    pub const HostMessage = union(enum) {
        query: QueryMsg,
        command: CommandMsg,
        getPanel: GetPanelMsg,
        context: ContextMsg,
        getActions: GetActionsMsg,
    };

    pub fn sendMessage(self: *BunProcess, msg: HostMessage) !void {
        const json_line = switch (msg) {
            inline else => |m| try std.json.Stringify.valueAlloc(self.allocator, m, .{}),
        };
        defer self.allocator.free(json_line);
        try self.sendEvent(json_line);
    }

    pub fn sendQuery(self: *BunProcess, query: []const u8) !void {
        try self.sendMessage(.{ .query = .{ .text = query } });
    }

    pub fn sendCommand(self: *BunProcess, name: []const u8, text: []const u8) !void {
        try self.sendMessage(.{ .command = .{ .name = name, .text = text } });
    }

    pub fn sendGetPanel(self: *BunProcess, plugin_id: []const u8, item_id: []const u8) !void {
        try self.sendMessage(.{ .getPanel = .{ .pluginId = plugin_id, .itemId = item_id } });
    }

    pub fn sendContext(self: *BunProcess, msg: ContextMsg) !void {
        try self.sendMessage(.{ .context = msg });
    }

    pub fn sendGetActions(
        self: *BunProcess,
        token: u64,
        panel: []const u8,
        plugin_id: []const u8,
        item_id: []const u8,
        selected_id: []const u8,
        selected_text: []const u8,
        query: []const u8,
    ) !void {
        try self.sendMessage(.{ .getActions = .{
            .token = token,
            .panel = panel,
            .pluginId = plugin_id,
            .itemId = item_id,
            .selectedId = selected_id,
            .selectedText = selected_text,
            .query = query,
        } });
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
