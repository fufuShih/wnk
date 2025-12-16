const std = @import("std");
const builtin = @import("builtin");
const SDLBackend = @import("sdl-backend");

pub const TrayIcon = switch (builtin.os.tag) {
    .windows => @import("windows.zig").TrayIcon,
    .macos => @import("macos.zig").TrayIcon,
    else => StubTrayIcon,
};

/// Stub implementation for unsupported platforms
const StubTrayIcon = struct {
    pub fn init(_: *SDLBackend.c.SDL_Window) !StubTrayIcon {
        return StubTrayIcon{};
    }

    pub fn deinit(_: *StubTrayIcon) void {}

    pub fn pollEvents(_: *StubTrayIcon) bool {
        return false;
    }

    pub fn shouldExit(_: *StubTrayIcon) bool {
        return false;
    }

    pub fn checkTrayMessages(_: *StubTrayIcon) void {}
};
