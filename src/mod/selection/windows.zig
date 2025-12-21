const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");
const Selection = types.Selection;
const SelectionSource = types.SelectionSource;

const INPUT_KEYBOARD: u32 = 1;
const KEYEVENTF_KEYUP: u32 = 0x0002;

const VK_CONTROL: u16 = 0x11;
const VK_C: u16 = 0x43;
const VK_MENU: i32 = 0x12;

const CF_UNICODETEXT: u32 = 13;
const GMEM_MOVEABLE: u32 = 0x0002;
const WM_COPY: u32 = 0x0301;
const SMTO_ABORTIFHUNG: u32 = 0x0002;

const KEYBDINPUT = extern struct {
    wVk: u16,
    wScan: u16,
    dwFlags: u32,
    time: u32,
    dwExtraInfo: usize,
};

const MOUSEINPUT = extern struct {
    dx: i32,
    dy: i32,
    mouseData: u32,
    dwFlags: u32,
    time: u32,
    dwExtraInfo: usize,
};

const HARDWAREINPUT = extern struct {
    uMsg: u32,
    wParamL: u16,
    wParamH: u16,
};

const INPUT_UNION = extern union {
    mi: MOUSEINPUT,
    ki: KEYBDINPUT,
    hi: HARDWAREINPUT,
};

const INPUT = extern struct {
    type: u32,
    u: INPUT_UNION,
};

const RECT = extern struct {
    left: i32,
    top: i32,
    right: i32,
    bottom: i32,
};

const GUITHREADINFO = extern struct {
    cbSize: u32,
    flags: u32,
    hwndActive: ?*anyopaque,
    hwndFocus: ?*anyopaque,
    hwndCapture: ?*anyopaque,
    hwndMenuOwner: ?*anyopaque,
    hwndMoveSize: ?*anyopaque,
    hwndCaret: ?*anyopaque,
    rcCaret: RECT,
};

extern "user32" fn OpenClipboard(hWndNewOwner: ?*anyopaque) callconv(.{ .x86_64_win = .{} }) i32;
extern "user32" fn CloseClipboard() callconv(.{ .x86_64_win = .{} }) i32;
extern "user32" fn GetClipboardData(uFormat: u32) callconv(.{ .x86_64_win = .{} }) ?*anyopaque;
extern "user32" fn SetClipboardData(uFormat: u32, hMem: ?*anyopaque) callconv(.{ .x86_64_win = .{} }) ?*anyopaque;
extern "user32" fn EmptyClipboard() callconv(.{ .x86_64_win = .{} }) i32;
extern "user32" fn EnumClipboardFormats(uFormat: u32) callconv(.{ .x86_64_win = .{} }) u32;
extern "user32" fn IsClipboardFormatAvailable(uFormat: u32) callconv(.{ .x86_64_win = .{} }) i32;
extern "user32" fn GetClipboardSequenceNumber() callconv(.{ .x86_64_win = .{} }) u32;
extern "user32" fn SendInput(cInputs: u32, pInputs: [*]const INPUT, cbSize: i32) callconv(.{ .x86_64_win = .{} }) u32;
extern "user32" fn GetForegroundWindow() callconv(.{ .x86_64_win = .{} }) ?*anyopaque;
extern "user32" fn GetWindowThreadProcessId(hWnd: ?*anyopaque, lpdwProcessId: *u32) callconv(.{ .x86_64_win = .{} }) u32;
extern "user32" fn GetAsyncKeyState(vKey: i32) callconv(.{ .x86_64_win = .{} }) i16;
extern "user32" fn GetGUIThreadInfo(idThread: u32, lpgui: *GUITHREADINFO) callconv(.{ .x86_64_win = .{} }) i32;
extern "user32" fn SendMessageTimeoutW(hWnd: ?*anyopaque, Msg: u32, wParam: usize, lParam: isize, fuFlags: u32, uTimeout: u32, lpdwResult: *usize) callconv(.{ .x86_64_win = .{} }) usize;

extern "kernel32" fn GlobalAlloc(uFlags: u32, dwBytes: usize) callconv(.{ .x86_64_win = .{} }) ?*anyopaque;
extern "kernel32" fn GlobalLock(hMem: ?*anyopaque) callconv(.{ .x86_64_win = .{} }) ?*anyopaque;
extern "kernel32" fn GlobalUnlock(hMem: ?*anyopaque) callconv(.{ .x86_64_win = .{} }) i32;
extern "kernel32" fn GlobalSize(hMem: ?*anyopaque) callconv(.{ .x86_64_win = .{} }) usize;
extern "kernel32" fn GlobalFree(hMem: ?*anyopaque) callconv(.{ .x86_64_win = .{} }) ?*anyopaque;
extern "kernel32" fn GetLastError() callconv(.{ .x86_64_win = .{} }) u32;
extern "kernel32" fn SetLastError(dwErrCode: u32) callconv(.{ .x86_64_win = .{} }) void;
extern "kernel32" fn GetCurrentProcessId() callconv(.{ .x86_64_win = .{} }) u32;
extern "kernel32" fn GetConsoleWindow() callconv(.{ .x86_64_win = .{} }) ?*anyopaque;

const ClipboardItem = struct {
    format: u32,
    data: []u8,
};

const ClipboardSnapshot = struct {
    items: []ClipboardItem,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *ClipboardSnapshot) void {
        for (self.items) |it| self.allocator.free(it.data);
        self.allocator.free(self.items);
    }
};

fn debugLog(comptime fmt: []const u8, args: anytype) void {
    if (builtin.mode != .Debug) return;
    std.debug.print(fmt, args);
}

fn openClipboardWithRetry() bool {
    var attempts: usize = 0;
    while (attempts < 20) : (attempts += 1) {
        if (OpenClipboard(null) != 0) return true;
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }
    return false;
}

fn snapshotClipboard(allocator: std.mem.Allocator) !ClipboardSnapshot {
    if (!openClipboardWithRetry()) return error.ClipboardUnavailable;
    defer _ = CloseClipboard();

    var list: std.ArrayList(ClipboardItem) = .empty;
    errdefer {
        for (list.items) |it| allocator.free(it.data);
        list.deinit(allocator);
    }

    var format: u32 = 0;
    while (true) {
        SetLastError(0);
        format = EnumClipboardFormats(format);
        if (format == 0) {
            if (GetLastError() != 0) return error.ClipboardEnumFailed;
            break;
        }

        const handle = GetClipboardData(format);
        if (handle == null) continue;

        const size = GlobalSize(handle);
        if (size == 0) continue;

        const ptr = GlobalLock(handle) orelse continue;
        defer _ = GlobalUnlock(handle);

        const src = @as([*]const u8, @ptrCast(ptr))[0..size];
        const copy = try allocator.alloc(u8, size);
        std.mem.copyForwards(u8, copy, src);
        try list.append(allocator, .{ .format = format, .data = copy });
    }

    return ClipboardSnapshot{
        .items = try list.toOwnedSlice(allocator),
        .allocator = allocator,
    };
}

fn restoreClipboard(snapshot: ClipboardSnapshot) !void {
    if (!openClipboardWithRetry()) return error.ClipboardUnavailable;
    defer _ = CloseClipboard();

    if (EmptyClipboard() == 0) return error.ClipboardWriteFailed;

    if (snapshot.items.len == 0) return;

    for (snapshot.items) |it| {
        if (it.data.len == 0) continue;
        const hmem = GlobalAlloc(GMEM_MOVEABLE, it.data.len) orelse return error.ClipboardWriteFailed;
        const ptr = GlobalLock(hmem) orelse {
            _ = GlobalFree(hmem);
            return error.ClipboardWriteFailed;
        };

        std.mem.copyForwards(u8, @as([*]u8, @ptrCast(ptr))[0..it.data.len], it.data);
        _ = GlobalUnlock(hmem);

        if (SetClipboardData(it.format, hmem) == null) {
            _ = GlobalFree(hmem);
            return error.ClipboardWriteFailed;
        }
    }
}

fn readClipboardUnicodeText(allocator: std.mem.Allocator) !?[]u8 {
    if (!openClipboardWithRetry()) return error.ClipboardUnavailable;
    defer _ = CloseClipboard();

    if (IsClipboardFormatAvailable(CF_UNICODETEXT) == 0) return null;

    const handle = GetClipboardData(CF_UNICODETEXT);
    if (handle == null) return error.ClipboardReadFailed;

    const size = GlobalSize(handle);
    if (size < 2) return null;

    const ptr = GlobalLock(handle) orelse return error.ClipboardReadFailed;
    defer _ = GlobalUnlock(handle);

    const max_chars = size / 2;
    const aligned_ptr: *align(2) const anyopaque = @alignCast(ptr);
    const utf16 = @as([*]const u16, @ptrCast(aligned_ptr))[0..max_chars];
    var len: usize = 0;
    while (len < utf16.len and utf16[len] != 0) : (len += 1) {}
    if (len == 0) return null;

    return try std.unicode.utf16LeToUtf8Alloc(allocator, utf16[0..len]);
}

fn sendCopyShortcut() void {
    var inputs = [_]INPUT{
        .{ .type = INPUT_KEYBOARD, .u = .{ .ki = .{ .wVk = VK_CONTROL, .wScan = 0, .dwFlags = 0, .time = 0, .dwExtraInfo = 0 } } },
        .{ .type = INPUT_KEYBOARD, .u = .{ .ki = .{ .wVk = VK_C, .wScan = 0, .dwFlags = 0, .time = 0, .dwExtraInfo = 0 } } },
        .{ .type = INPUT_KEYBOARD, .u = .{ .ki = .{ .wVk = VK_C, .wScan = 0, .dwFlags = KEYEVENTF_KEYUP, .time = 0, .dwExtraInfo = 0 } } },
        .{ .type = INPUT_KEYBOARD, .u = .{ .ki = .{ .wVk = VK_CONTROL, .wScan = 0, .dwFlags = KEYEVENTF_KEYUP, .time = 0, .dwExtraInfo = 0 } } },
    };
    const count: u32 = @intCast(inputs.len);
    const sent = SendInput(count, inputs[0..].ptr, @intCast(@sizeOf(INPUT)));
    debugLog("selection: SendInput sent {d}/{d}\n", .{ sent, count });
    if (sent != count) {
        debugLog("selection: SendInput error={d}\n", .{GetLastError()});
    }
}

fn waitForAltRelease() void {
    const deadline_ms = std.time.milliTimestamp() + 250;
    while (std.time.milliTimestamp() < deadline_ms) {
        if (GetAsyncKeyState(VK_MENU) >= 0) return;
        std.Thread.sleep(5 * std.time.ns_per_ms);
    }
}

fn foregroundCopyTarget() ?*anyopaque {
    const fg = GetForegroundWindow() orelse return null;
    var pid: u32 = 0;
    const tid = GetWindowThreadProcessId(fg, &pid);

    var info: GUITHREADINFO = std.mem.zeroes(GUITHREADINFO);
    info.cbSize = @sizeOf(GUITHREADINFO);
    if (GetGUIThreadInfo(tid, &info) != 0) {
        if (info.hwndFocus) |hwnd| return hwnd;
        if (info.hwndActive) |hwnd| return hwnd;
    }
    return fg;
}

fn requestCopyFromForegroundWindow() void {
    const hwnd = foregroundCopyTarget() orelse return;
    var result: usize = 0;
    _ = SendMessageTimeoutW(hwnd, WM_COPY, 0, 0, SMTO_ABORTIFHUNG, 120, &result);
}

fn waitForClipboardText(allocator: std.mem.Allocator, before_seq: u32, deadline_ms: i64) ?[]u8 {
    var saw_change = false;
    while (std.time.milliTimestamp() < deadline_ms) {
        if (GetClipboardSequenceNumber() != before_seq) saw_change = true;
        if (saw_change) {
            if (readClipboardUnicodeText(allocator) catch null) |text| return text;
        }
        std.Thread.sleep(10 * std.time.ns_per_ms);
    }
    return null;
}

fn shouldSendCopyShortcut() bool {
    const fg = GetForegroundWindow() orelse return true;
    const console = GetConsoleWindow();
    if (console != null and fg == console) return false;

    var pid: u32 = 0;
    _ = GetWindowThreadProcessId(fg, &pid);
    if (pid != 0 and pid == GetCurrentProcessId()) return false;

    return true;
}

pub fn capture(allocator: std.mem.Allocator) !?Selection {
    debugLog("selection: capture start\n", .{});
    if (!shouldSendCopyShortcut()) {
        const text = readClipboardUnicodeText(allocator) catch null;
        debugLog("selection: clipboard-only text={}\n", .{text != null});
        if (text) |t| return .{ .text = t, .source = .clipboard };
        return null;
    }

    // Snapshot the clipboard so we can restore it after sending Ctrl+C.
    var snapshot_opt = snapshotClipboard(allocator) catch null;
    if (snapshot_opt == null) {
        const text = readClipboardUnicodeText(allocator) catch null;
        debugLog("selection: snapshot unavailable; clipboard-only text={}\n", .{text != null});
        if (text) |t| return .{ .text = t, .source = .clipboard };
        return null;
    }
    defer {
        if (snapshot_opt) |*snap| snap.deinit();
    }

    waitForAltRelease();
    std.Thread.sleep(10 * std.time.ns_per_ms);
    var text: ?[]u8 = null;
    var source: SelectionSource = .os;

    const before_seq = GetClipboardSequenceNumber();
    requestCopyFromForegroundWindow();
    text = waitForClipboardText(allocator, before_seq, std.time.milliTimestamp() + 320);
    debugLog("selection: WM_COPY before_seq={d} got_text={}\n", .{ before_seq, text != null });

    if (text == null) {
        const before_seq_ctrl = GetClipboardSequenceNumber();
        sendCopyShortcut();
        text = waitForClipboardText(allocator, before_seq_ctrl, std.time.milliTimestamp() + 550);
        debugLog("selection: Ctrl+C before_seq={d} got_text={}\n", .{ before_seq_ctrl, text != null });
    }

    if (text == null) {
        text = readClipboardUnicodeText(allocator) catch null;
        source = .clipboard;
        debugLog("selection: fallback clipboard text={}\n", .{text != null});
    }

    if (snapshot_opt) |snap| {
        restoreClipboard(snap) catch {};
    }
    if (text) |t| {
        debugLog("selection: done len={d}\n", .{t.len});
        return .{ .text = t, .source = source };
    } else {
        debugLog("selection: done (null)\n", .{});
    }
    return null;
}
