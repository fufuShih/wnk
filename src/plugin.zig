// ============================================
// Plugin Module - Main entry point
// ============================================

pub const ipc = @import("plugin/ipc.zig");

pub const BunProcess = ipc.BunProcess;
pub const IpcError = ipc.IpcError;
