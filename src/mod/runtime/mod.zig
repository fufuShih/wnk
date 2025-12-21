const std = @import("std");
const plugin = @import("plugin");

pub const Backend = enum {
    bun,
};

pub const Error = error{
    ReadFailed,
    WriteFailed,
    EndOfStream,
    OutOfMemory,
};

pub const PollResult = enum { ok, closed };
pub const MessageHandler = *const fn (allocator: std.mem.Allocator, line: []const u8) void;

pub const HostContext = struct {
    selectionText: ?[]const u8 = null,
    selectionSource: ?[]const u8 = null,
    windowTitle: ?[]const u8 = null,
    appId: ?[]const u8 = null,
    timestampMs: ?i64 = null,
};

pub const RuntimeProcess = struct {
    backend: Backend,
    inner: union(Backend) {
        bun: plugin.BunProcess,
    },

    pub fn spawn(allocator: std.mem.Allocator, backend: Backend) !RuntimeProcess {
        return switch (backend) {
            .bun => .{
                .backend = .bun,
                .inner = .{ .bun = try plugin.BunProcess.spawn(allocator) },
            },
        };
    }

    pub fn deinit(self: *RuntimeProcess) void {
        switch (self.inner) {
            .bun => |*p| p.deinit(),
        }
    }

    pub fn pollMessages(
        self: *RuntimeProcess,
        allocator: std.mem.Allocator,
        handler: MessageHandler,
    ) Error!PollResult {
        while (true) {
            const maybe_line = self.pollLine() catch |err| {
                if (err == Error.EndOfStream) return .closed;
                return err;
            };
            if (maybe_line) |line| {
                handler(allocator, line);
                continue;
            }
            break;
        }
        return .ok;
    }

    pub fn pollLine(self: *RuntimeProcess) Error!?[]const u8 {
        switch (self.inner) {
            .bun => |*p| {
                return p.pollLine() catch |err| return mapError(err);
            },
        }
    }

    pub fn sendQuery(self: *RuntimeProcess, query: []const u8) Error!void {
        switch (self.inner) {
            .bun => |*p| {
                p.sendQuery(query) catch |err| return mapError(err);
            },
        }
    }

    pub fn sendCommand(self: *RuntimeProcess, name: []const u8, text: []const u8) Error!void {
        switch (self.inner) {
            .bun => |*p| {
                p.sendCommand(name, text) catch |err| return mapError(err);
            },
        }
    }

    pub fn sendGetPanel(self: *RuntimeProcess, plugin_id: []const u8, item_id: []const u8) Error!void {
        switch (self.inner) {
            .bun => |*p| {
                p.sendGetPanel(plugin_id, item_id) catch |err| return mapError(err);
            },
        }
    }

    pub fn sendContext(self: *RuntimeProcess, ctx: HostContext) Error!void {
        switch (self.inner) {
            .bun => |*p| {
                p.sendContext(.{
                    .selectionText = ctx.selectionText,
                    .selectionSource = ctx.selectionSource,
                    .windowTitle = ctx.windowTitle,
                    .appId = ctx.appId,
                    .timestampMs = ctx.timestampMs,
                }) catch |err| return mapError(err);
            },
        }
    }

    pub fn sendGetActions(
        self: *RuntimeProcess,
        token: u64,
        panel: []const u8,
        plugin_id: []const u8,
        item_id: []const u8,
        selected_id: []const u8,
        selected_text: []const u8,
        query: []const u8,
    ) Error!void {
        switch (self.inner) {
            .bun => |*p| {
                p.sendGetActions(token, panel, plugin_id, item_id, selected_id, selected_text, query) catch |err| {
                    return mapError(err);
                };
            },
        }
    }
};

pub const RuntimeHost = struct {
    process: ?RuntimeProcess = null,
    backend: Backend = .bun,

    pub fn start(self: *RuntimeHost, allocator: std.mem.Allocator, backend: Backend) void {
        if (self.process != null) return;
        self.backend = backend;
        self.process = RuntimeProcess.spawn(allocator, backend) catch |err| {
            std.debug.print("Failed to start runtime process ({s}): {}\n", .{ backendName(backend), err });
            self.process = null;
            return;
        };
        std.debug.print("Runtime process started ({s})\n", .{backendName(backend)});
    }

    pub fn deinit(self: *RuntimeHost) void {
        if (self.process) |*p| p.deinit();
        self.process = null;
    }

    pub fn isActive(self: *const RuntimeHost) bool {
        return self.process != null;
    }

    pub fn pollMessages(self: *RuntimeHost, allocator: std.mem.Allocator, handler: MessageHandler) void {
        if (self.process) |*p| {
            const res = p.pollMessages(allocator, handler) catch |err| {
                if (err == Error.EndOfStream) {
                    std.debug.print("Runtime process closed its pipe; disabling plugins.\n", .{});
                    p.deinit();
                    self.process = null;
                    return;
                }
                std.debug.print("Failed to read from runtime: {}\n", .{err});
                return;
            };
            if (res == .closed) {
                std.debug.print("Runtime process closed its pipe; disabling plugins.\n", .{});
                p.deinit();
                self.process = null;
            }
        }
    }

    pub fn sendQuery(self: *RuntimeHost, query: []const u8) bool {
        if (self.process) |*p| {
            p.sendQuery(query) catch |err| {
                logSendError("send query", err);
                return false;
            };
            return true;
        }
        return false;
    }

    pub fn sendCommand(self: *RuntimeHost, name: []const u8, text: []const u8) bool {
        if (self.process) |*p| {
            p.sendCommand(name, text) catch |err| {
                logSendError("send command", err);
                return false;
            };
            return true;
        }
        return false;
    }

    pub fn sendGetPanel(self: *RuntimeHost, plugin_id: []const u8, item_id: []const u8) bool {
        if (self.process) |*p| {
            p.sendGetPanel(plugin_id, item_id) catch |err| {
                logSendError("request panel", err);
                return false;
            };
            return true;
        }
        return false;
    }

    pub fn sendContext(self: *RuntimeHost, ctx: HostContext) bool {
        if (self.process) |*p| {
            p.sendContext(ctx) catch |err| {
                logSendError("send context", err);
                return false;
            };
            return true;
        }
        return false;
    }

    pub fn sendGetActions(
        self: *RuntimeHost,
        token: u64,
        panel: []const u8,
        plugin_id: []const u8,
        item_id: []const u8,
        selected_id: []const u8,
        selected_text: []const u8,
        query: []const u8,
    ) bool {
        if (self.process) |*p| {
            p.sendGetActions(token, panel, plugin_id, item_id, selected_id, selected_text, query) catch |err| {
                logSendError("request actions", err);
                return false;
            };
            return true;
        }
        return false;
    }
};

pub fn backendName(backend: Backend) []const u8 {
    return switch (backend) {
        .bun => "bun",
    };
}

fn logSendError(action: []const u8, err: Error) void {
    std.debug.print("Failed to {s}: {}\n", .{ action, err });
}

fn mapError(err: anyerror) Error {
    return switch (err) {
        plugin.IpcError.ReadFailed => Error.ReadFailed,
        plugin.IpcError.WriteFailed => Error.WriteFailed,
        plugin.IpcError.EndOfStream => Error.EndOfStream,
        error.OutOfMemory => Error.OutOfMemory,
        else => Error.ReadFailed,
    };
}
