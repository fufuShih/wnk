const std = @import("std");

pub const TraySignals = struct {
    show_requested: std.atomic.Value(u8) = std.atomic.Value(u8).init(0),
    should_exit: std.atomic.Value(u8) = std.atomic.Value(u8).init(0),

    pub fn reset(self: *TraySignals) void {
        self.show_requested.store(0, .release);
        self.should_exit.store(0, .release);
    }

    pub fn requestShow(self: *TraySignals) void {
        self.show_requested.store(1, .release);
    }

    pub fn takeShow(self: *TraySignals) bool {
        return self.show_requested.swap(0, .acq_rel) != 0;
    }

    pub fn requestExit(self: *TraySignals) void {
        self.should_exit.store(1, .release);
    }

    pub fn shouldExit(self: *TraySignals) bool {
        return self.should_exit.load(.acquire) != 0;
    }
};

