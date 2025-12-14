const std = @import("std");
const SDLBackend = @import("sdl-backend");

// Windows API structures and constants
const GUID = extern struct {
    Data1: u32,
    Data2: u16,
    Data3: u16,
    Data4: [8]u8,
};

const NOTIFYICONDATAW = extern struct {
    cbSize: u32,
    hWnd: ?*anyopaque,
    uID: u32,
    uFlags: u32,
    uCallbackMessage: u32,
    hIcon: ?*anyopaque,
    szTip: [128]u16,
    dwState: u32,
    dwStateMask: u32,
    szInfo: [256]u16,
    uTimeout: u32,
    szInfoTitle: [64]u16,
    dwInfoFlags: u32,
    guidItem: GUID,
    hBalloonIcon: ?*anyopaque,
};

// Constants
const NIF_MESSAGE: u32 = 0x00000001;
const NIF_ICON: u32 = 0x00000002;
const NIF_TIP: u32 = 0x00000004;
const NIF_STATE: u32 = 0x00000008;
const NIF_INFO: u32 = 0x00000010;
const NIF_GUID: u32 = 0x00000020;

const NIM_ADD: u32 = 0x00000000;
const NIM_MODIFY: u32 = 0x00000001;
const NIM_DELETE: u32 = 0x00000002;

const WM_APP: u32 = 0x8000;
const WM_TRAYICON: u32 = WM_APP + 1;

const WM_LBUTTONUP: u32 = 0x0202;
const WM_RBUTTONUP: u32 = 0x0205;
const WM_CONTEXTMENU: u32 = 0x007B;
const WM_NULL: u32 = 0x0000;
const WM_CLOSE: u32 = 0x0010;

// Windows API functions
extern "shell32" fn Shell_NotifyIconW(dwMessage: u32, lpData: *NOTIFYICONDATAW) callconv(.{ .x86_64_win = .{} }) i32;
extern "user32" fn LoadIconW(hInstance: ?*anyopaque, lpIconName: [*:0]const u16) callconv(.{ .x86_64_win = .{} }) ?*anyopaque;
extern "user32" fn CreatePopupMenu() callconv(.{ .x86_64_win = .{} }) ?*anyopaque;
extern "user32" fn AppendMenuW(hMenu: ?*anyopaque, uFlags: u32, uIDNewItem: usize, lpNewItem: ?[*:0]const u16) callconv(.{ .x86_64_win = .{} }) i32;
extern "user32" fn TrackPopupMenu(hMenu: ?*anyopaque, uFlags: u32, x: i32, y: i32, nReserved: i32, hWnd: ?*anyopaque, prcRect: ?*anyopaque) callconv(.{ .x86_64_win = .{} }) i32;
extern "user32" fn DestroyMenu(hMenu: ?*anyopaque) callconv(.{ .x86_64_win = .{} }) i32;
extern "user32" fn GetCursorPos(lpPoint: *POINT) callconv(.{ .x86_64_win = .{} }) i32;
extern "user32" fn SetForegroundWindow(hWnd: ?*anyopaque) callconv(.{ .x86_64_win = .{} }) i32;
extern "user32" fn PostMessageW(hWnd: ?*anyopaque, Msg: u32, wParam: usize, lParam: isize) callconv(.{ .x86_64_win = .{} }) i32;
extern "user32" fn PeekMessageW(lpMsg: *MSG, hWnd: ?*anyopaque, wMsgFilterMin: u32, wMsgFilterMax: u32, wRemoveMsg: u32) callconv(.{ .x86_64_win = .{} }) i32;
extern "user32" fn RegisterClassExW(lpWndClass: *const WNDCLASSEXW) callconv(.{ .x86_64_win = .{} }) u16;
extern "user32" fn CreateWindowExW(dwExStyle: u32, lpClassName: [*:0]const u16, lpWindowName: ?[*:0]const u16, dwStyle: u32, X: i32, Y: i32, nWidth: i32, nHeight: i32, hWndParent: ?*anyopaque, hMenu: ?*anyopaque, hInstance: ?*anyopaque, lpParam: ?*anyopaque) callconv(.{ .x86_64_win = .{} }) ?*anyopaque;
extern "user32" fn DestroyWindow(hWnd: ?*anyopaque) callconv(.{ .x86_64_win = .{} }) i32;
extern "user32" fn DefWindowProcW(hWnd: ?*anyopaque, Msg: u32, wParam: usize, lParam: isize) callconv(.{ .x86_64_win = .{} }) isize;
extern "kernel32" fn GetModuleHandleW(lpModuleName: ?[*:0]const u16) callconv(.{ .x86_64_win = .{} }) ?*anyopaque;
extern "kernel32" fn GetLastError() callconv(.{ .x86_64_win = .{} }) u32;

const WndProc = *const fn (hwnd: ?*anyopaque, msg: u32, wParam: usize, lParam: isize) callconv(.{ .x86_64_win = .{} }) isize;

const WNDCLASSEXW = extern struct {
    cbSize: u32,
    style: u32,
    lpfnWndProc: WndProc,
    cbClsExtra: i32,
    cbWndExtra: i32,
    hInstance: ?*anyopaque,
    hIcon: ?*anyopaque,
    hCursor: ?*anyopaque,
    hbrBackground: ?*anyopaque,
    lpszMenuName: ?[*:0]const u16,
    lpszClassName: [*:0]const u16,
    hIconSm: ?*anyopaque,
};

const POINT = extern struct {
    x: i32,
    y: i32,
};

const MSG = extern struct {
    hwnd: ?*anyopaque,
    message: u32,
    wParam: usize,
    lParam: isize,
    time: u32,
    pt: POINT,
    lPrivate: u32,
};

const TPM_BOTTOMALIGN: u32 = 0x0020;
const TPM_LEFTALIGN: u32 = 0x0000;
const TPM_RIGHTBUTTON: u32 = 0x0002;
const TPM_RETURNCMD: u32 = 0x0100;
const MF_STRING: u32 = 0x00000000;
const MF_SEPARATOR: u32 = 0x00000800;
const PM_REMOVE: u32 = 0x0001;

const IDI_APPLICATION: [*:0]const u16 = @ptrFromInt(32512);

// Menu item IDs
const ID_TRAY_SHOW: usize = 1001;
const ID_TRAY_EXIT: usize = 1002;

var g_should_exit: bool = false;
var g_should_show: bool = false;
var g_app_hwnd: ?*anyopaque = null;

pub const TrayIcon = struct {
    nid: NOTIFYICONDATAW,
    /// Dedicated message-only window for tray callbacks.
    msg_hwnd: ?*anyopaque,

    fn showContextMenuFor(hwnd: ?*anyopaque) void {
        const hMenu = CreatePopupMenu() orelse return;
        defer _ = DestroyMenu(hMenu);

        const show_text = std.unicode.utf8ToUtf16LeStringLiteral("顯示視窗");
        const exit_text = std.unicode.utf8ToUtf16LeStringLiteral("結束");

        _ = AppendMenuW(hMenu, MF_STRING, ID_TRAY_SHOW, show_text);
        _ = AppendMenuW(hMenu, MF_SEPARATOR, 0, null);
        _ = AppendMenuW(hMenu, MF_STRING, ID_TRAY_EXIT, exit_text);

        var pt: POINT = undefined;
        _ = GetCursorPos(&pt);

        _ = SetForegroundWindow(hwnd);

        const cmd: u32 = @intCast(TrackPopupMenu(
            hMenu,
            TPM_BOTTOMALIGN | TPM_LEFTALIGN | TPM_RIGHTBUTTON | TPM_RETURNCMD,
            pt.x,
            pt.y,
            0,
            hwnd,
            null,
        ));

        _ = PostMessageW(hwnd, WM_NULL, 0, 0);

        if (cmd == ID_TRAY_SHOW) {
            g_should_show = true;
            if (g_app_hwnd) |app_hwnd| {
                _ = PostMessageW(app_hwnd, WM_NULL, 0, 0);
            }
        } else if (cmd == ID_TRAY_EXIT) {
            g_should_exit = true;
            if (g_app_hwnd) |app_hwnd| {
                _ = PostMessageW(app_hwnd, WM_CLOSE, 0, 0);
            }
        }
    }

    fn trayWndProc(hwnd: ?*anyopaque, msg: u32, wParam: usize, lParam: isize) callconv(.{ .x86_64_win = .{} }) isize {
        if (msg == WM_TRAYICON) {
            const raw: usize = @bitCast(lParam);
            const event: u32 = @intCast(raw & 0xFFFF_FFFF);
            if (event == WM_RBUTTONUP or event == WM_CONTEXTMENU) {
                showContextMenuFor(hwnd);
                return 0;
            }
            if (event == WM_LBUTTONUP) {
                g_should_show = true;
                if (g_app_hwnd) |app_hwnd| {
                    _ = PostMessageW(app_hwnd, WM_NULL, 0, 0);
                }
                return 0;
            }
        }

        return DefWindowProcW(hwnd, msg, wParam, lParam);
    }

    fn ensureTrayClass(hinstance: ?*anyopaque) !void {
        const class_name = std.unicode.utf8ToUtf16LeStringLiteral("wnk_tray_msg_window");
        const wc = WNDCLASSEXW{
            .cbSize = @sizeOf(WNDCLASSEXW),
            .style = 0,
            .lpfnWndProc = trayWndProc,
            .cbClsExtra = 0,
            .cbWndExtra = 0,
            .hInstance = hinstance,
            .hIcon = null,
            .hCursor = null,
            .hbrBackground = null,
            .lpszMenuName = null,
            .lpszClassName = class_name,
            .hIconSm = null,
        };

        if (RegisterClassExW(&wc) == 0) {
            // ERROR_CLASS_ALREADY_EXISTS (1410) is fine.
            const err = GetLastError();
            if (err != 1410) return error.FailedToRegisterTrayWindowClass;
        }
    }

    fn createMessageOnlyWindow(hinstance: ?*anyopaque) !?*anyopaque {
        try ensureTrayClass(hinstance);
        const class_name = std.unicode.utf8ToUtf16LeStringLiteral("wnk_tray_msg_window");
        const window_name = std.unicode.utf8ToUtf16LeStringLiteral("wnk_tray_msg_window");

        // HWND_MESSAGE == (HWND)-3
        const hwnd_message: ?*anyopaque = @ptrFromInt(@as(usize, @bitCast(@as(isize, -3))));

        const hwnd = CreateWindowExW(
            0,
            class_name,
            window_name,
            0,
            0,
            0,
            0,
            0,
            hwnd_message,
            null,
            hinstance,
            null,
        );

        if (hwnd == null) return error.FailedToCreateTrayMessageWindow;
        return hwnd;
    }

    pub fn init(sdl_window: *SDLBackend.c.SDL_Window) !TrayIcon {
        // Keep the SDL main HWND so we can reliably close/show the app.
        const SDL_PROP_WINDOW_WIN32_HWND_POINTER = "SDL.window.win32.hwnd";
        const hwnd_prop = SDLBackend.c.SDL_GetPointerProperty(
            SDLBackend.c.SDL_GetWindowProperties(sdl_window),
            SDL_PROP_WINDOW_WIN32_HWND_POINTER,
            null,
        );
        g_app_hwnd = hwnd_prop;

        const hinstance = GetModuleHandleW(null);
        const msg_hwnd = try createMessageOnlyWindow(hinstance);

        // Load default application icon
        const hIcon = LoadIconW(null, IDI_APPLICATION);

        // Prepare tooltip text
        var szTip: [128]u16 = [_]u16{0} ** 128;
        const tooltip = std.unicode.utf8ToUtf16LeStringLiteral("wnk Launcher");
        @memcpy(szTip[0..tooltip.len], tooltip);

        var nid = NOTIFYICONDATAW{
            .cbSize = @sizeOf(NOTIFYICONDATAW),
            .hWnd = msg_hwnd,
            .uID = 1,
            .uFlags = NIF_ICON | NIF_MESSAGE | NIF_TIP,
            .uCallbackMessage = WM_TRAYICON,
            .hIcon = hIcon,
            .szTip = szTip,
            .dwState = 0,
            .dwStateMask = 0,
            .szInfo = [_]u16{0} ** 256,
            .uTimeout = 0,
            .szInfoTitle = [_]u16{0} ** 64,
            .dwInfoFlags = 0,
            .guidItem = GUID{
                .Data1 = 0,
                .Data2 = 0,
                .Data3 = 0,
                .Data4 = [_]u8{0} ** 8,
            },
            .hBalloonIcon = null,
        };

        // Add tray icon
        if (Shell_NotifyIconW(NIM_ADD, &nid) == 0) {
            return error.FailedToCreateTrayIcon;
        }

        // Reset global flags per init.
        g_should_exit = false;
        g_should_show = false;

        return TrayIcon{
            .nid = nid,
            .msg_hwnd = msg_hwnd,
        };
    }

    pub fn deinit(self: *TrayIcon) void {
        _ = Shell_NotifyIconW(NIM_DELETE, &self.nid);
        if (self.msg_hwnd) |hwnd| {
            _ = DestroyWindow(hwnd);
            self.msg_hwnd = null;
        }
    }

    pub fn showContextMenu(self: *TrayIcon) void {
        showContextMenuFor(self.msg_hwnd);
    }

    pub fn pollEvents(self: *TrayIcon) bool {
        _ = self;
        if (g_should_show) {
            g_should_show = false;
            return true;
        }
        return false;
    }

    pub fn shouldExit(self: *TrayIcon) bool {
        _ = self;
        return g_should_exit;
    }

    pub fn checkTrayMessages(self: *TrayIcon) void {
        // Intentionally empty.
        // SDL's Win32 message pump will DispatchMessageW to our message-only window,
        // and `trayWndProc` handles WM_TRAYICON there.
        _ = self;
    }
};
