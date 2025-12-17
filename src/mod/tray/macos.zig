const std = @import("std");
const SDLBackend = @import("sdl-backend");
const signals = @import("signals.zig");

// Objective-C runtime types
const id = *opaque {};
const SEL = *opaque {};
const Class = *opaque {};

// CoreGraphics window level
const CGWindowLevel = i32;
const CGWindowLevelKey = i32;
extern "c" fn CGWindowLevelForKey(key: CGWindowLevelKey) callconv(.c) CGWindowLevel;
const kCGStatusWindowLevelKey: CGWindowLevelKey = 9;

// NSEvent types and constants for global key monitoring
const NSEventMask = u64;
const NSEventModifierFlags = u64;
const NSEventMaskKeyDown: NSEventMask = 1 << 10;
const NSEventModifierFlagDeviceIndependentFlagsMask: NSEventModifierFlags = 0xffff0000;
const NSEventModifierFlagOption: NSEventModifierFlags = 1 << 19;
const NSEventModifierFlagCommand: NSEventModifierFlags = 1 << 20;
const NSEventModifierFlagShift: NSEventModifierFlags = 1 << 17;
const NSEventModifierFlagControl: NSEventModifierFlags = 1 << 18;

// NSWindow collection behavior (matches AppKit's NSWindowCollectionBehavior)
const NSWindowCollectionBehavior = u64;
const NSWindowCollectionBehaviorCanJoinAllSpaces: NSWindowCollectionBehavior = 1 << 0;
const NSWindowCollectionBehaviorTransient: NSWindowCollectionBehavior = 1 << 3;
const NSWindowCollectionBehaviorIgnoresCycle: NSWindowCollectionBehavior = 1 << 6;
const NSWindowCollectionBehaviorFullScreenAuxiliary: NSWindowCollectionBehavior = 1 << 8;

// Key codes
const kVK_Space: u16 = 49;

// Objective-C runtime functions
extern "c" fn objc_getClass(name: [*:0]const u8) ?Class;
extern "c" fn sel_registerName(name: [*:0]const u8) SEL;
extern "c" fn objc_msgSend() void;

// Type-safe message send wrappers
inline fn msgSend(comptime ReturnType: type, target: anytype, sel: SEL, args: anytype) ReturnType {
    const target_ptr = switch (@typeInfo(@TypeOf(target))) {
        .optional => target orelse return if (ReturnType == void) {} else null,
        else => target,
    };

    const FnType = switch (args.len) {
        0 => *const fn (@TypeOf(target_ptr), SEL) callconv(.c) ReturnType,
        1 => *const fn (@TypeOf(target_ptr), SEL, @TypeOf(args[0])) callconv(.c) ReturnType,
        2 => *const fn (@TypeOf(target_ptr), SEL, @TypeOf(args[0]), @TypeOf(args[1])) callconv(.c) ReturnType,
        3 => *const fn (@TypeOf(target_ptr), SEL, @TypeOf(args[0]), @TypeOf(args[1]), @TypeOf(args[2])) callconv(.c) ReturnType,
        else => @compileError("Too many arguments"),
    };

    const func: FnType = @ptrCast(&objc_msgSend);
    return switch (args.len) {
        0 => func(target_ptr, sel),
        1 => func(target_ptr, sel, args[0]),
        2 => func(target_ptr, sel, args[0], args[1]),
        3 => func(target_ptr, sel, args[0], args[1], args[2]),
        else => unreachable,
    };
}

// NSApplication activation policy
const NSApplicationActivationPolicyRegular: i64 = 0;
const NSApplicationActivationPolicyAccessory: i64 = 1;

// NSStatusBar constants - variable length from center
const NSVariableStatusItemLength: f64 = -1.0;

// Global state
var g_signals: signals.TraySignals = .{};
var g_app_window: ?*SDLBackend.c.SDL_Window = null;
var g_app_ns_window: ?id = null;
var g_menu_delegate: ?id = null;
var g_event_monitor: ?id = null;
var g_sdl_wake_event_type: std.atomic.Value(u32) = std.atomic.Value(u32).init(0);

// Selectors (cached)
var sel_sharedApplication: SEL = undefined;
var sel_systemStatusBar: SEL = undefined;
var sel_statusItemWithLength: SEL = undefined;
var sel_setTitle: SEL = undefined;
var sel_setMenu: SEL = undefined;
var sel_setTarget: SEL = undefined;
var sel_alloc: SEL = undefined;
var sel_init: SEL = undefined;
var sel_addItem: SEL = undefined;
var sel_separatorItem: SEL = undefined;
var sel_stringWithUTF8String: SEL = undefined;
var sel_button: SEL = undefined;
var sel_removeStatusItem: SEL = undefined;
var sel_release: SEL = undefined;
var sel_collectionBehavior: SEL = undefined;
var sel_setCollectionBehavior: SEL = undefined;
var sel_setLevel: SEL = undefined;
var sel_orderFrontRegardless: SEL = undefined;
var sel_makeKeyAndOrderFront: SEL = undefined;
var sel_setHidesOnDeactivate: SEL = undefined;

var selectors_initialized: bool = false;

fn initSelectors() void {
    if (selectors_initialized) return;

    sel_sharedApplication = sel_registerName("sharedApplication");
    sel_systemStatusBar = sel_registerName("systemStatusBar");
    sel_statusItemWithLength = sel_registerName("statusItemWithLength:");
    sel_setTitle = sel_registerName("setTitle:");
    sel_setMenu = sel_registerName("setMenu:");
    sel_setTarget = sel_registerName("setTarget:");
    sel_alloc = sel_registerName("alloc");
    sel_init = sel_registerName("init");
    sel_addItem = sel_registerName("addItem:");
    sel_separatorItem = sel_registerName("separatorItem");
    sel_stringWithUTF8String = sel_registerName("stringWithUTF8String:");
    sel_button = sel_registerName("button");
    sel_removeStatusItem = sel_registerName("removeStatusItem:");
    sel_release = sel_registerName("release");
    sel_collectionBehavior = sel_registerName("collectionBehavior");
    sel_setCollectionBehavior = sel_registerName("setCollectionBehavior:");
    sel_setLevel = sel_registerName("setLevel:");
    sel_orderFrontRegardless = sel_registerName("orderFrontRegardless");
    sel_makeKeyAndOrderFront = sel_registerName("makeKeyAndOrderFront:");
    sel_setHidesOnDeactivate = sel_registerName("setHidesOnDeactivate:");

    selectors_initialized = true;
}

fn createNSString(str: [*:0]const u8) ?id {
    const NSString = objc_getClass("NSString") orelse return null;
    return msgSend(?id, NSString, sel_stringWithUTF8String, .{str});
}

fn ensureWakeEventRegistered() void {
    if (g_sdl_wake_event_type.load(.acquire) != 0) return;
    const t: u32 = SDLBackend.c.SDL_RegisterEvents(1);
    if (t != 0) g_sdl_wake_event_type.store(t, .release);
}

fn postWakeEvent() void {
    const t = g_sdl_wake_event_type.load(.acquire);
    if (t == 0) return;
    var evt: SDLBackend.c.SDL_Event = undefined;
    @memset(std.mem.asBytes(&evt), 0);
    evt.type = t;
    _ = SDLBackend.c.SDL_PushEvent(&evt);
}

fn requestShow() void {
    g_signals.requestShow();
    postWakeEvent();
}

fn getCocoaWindowFromSDL(window: *SDLBackend.c.SDL_Window) ?id {
    const SDL_PROP_WINDOW_COCOA_WINDOW_POINTER = "SDL.window.cocoa.window";
    const ptr = SDLBackend.c.SDL_GetPointerProperty(
        SDLBackend.c.SDL_GetWindowProperties(window),
        SDL_PROP_WINDOW_COCOA_WINDOW_POINTER,
        null,
    ) orelse return null;
    return @ptrCast(@alignCast(ptr));
}

fn configureLauncherWindow(ns_window: id) void {
    // Keep the launcher on the current Space (including fullscreen) instead of
    // switching to the Space where the window was last shown.
    const desired_behavior: NSWindowCollectionBehavior =
        NSWindowCollectionBehaviorCanJoinAllSpaces |
        NSWindowCollectionBehaviorFullScreenAuxiliary |
        NSWindowCollectionBehaviorTransient |
        NSWindowCollectionBehaviorIgnoresCycle;

    const current_behavior: NSWindowCollectionBehavior = msgSend(NSWindowCollectionBehavior, ns_window, sel_collectionBehavior, .{});
    msgSend(void, ns_window, sel_setCollectionBehavior, .{current_behavior | desired_behavior});

    // Raise above normal windows (Spotlight/Raycast-like).
    const level: i64 = @intCast(CGWindowLevelForKey(kCGStatusWindowLevelKey));
    msgSend(void, ns_window, sel_setLevel, .{level});

    // Auto-hide when the user clicks away.
    msgSend(void, ns_window, sel_setHidesOnDeactivate, .{true});
}

fn activateAndRaiseWindow() void {
    // Cocoa activation helps ensure the window becomes frontmost after being hidden.
    const NSApplication = objc_getClass("NSApplication") orelse return;
    const app = msgSend(?id, NSApplication, sel_sharedApplication, .{}) orelse return;

    const sel_unhide = sel_registerName("unhide:");
    msgSend(void, app, sel_unhide, .{@as(?id, null)});

    // Show/order the window first. The window is configured to join all spaces,
    // so it appears on the current Space (prevents "Space jumping").
    if (g_app_window) |window| {
        if (g_app_ns_window == null) {
            g_app_ns_window = getCocoaWindowFromSDL(window);
            if (g_app_ns_window) |ns_window| configureLauncherWindow(ns_window);
        }

        _ = SDLBackend.c.SDL_RestoreWindow(window);
        _ = SDLBackend.c.SDL_ShowWindow(window);
        _ = SDLBackend.c.SDL_RaiseWindow(window);
    }

    if (g_app_ns_window) |ns_window| {
        msgSend(void, ns_window, sel_orderFrontRegardless, .{});
    }

    const sel_activate = sel_registerName("activateIgnoringOtherApps:");
    msgSend(void, app, sel_activate, .{true});

    if (g_app_ns_window) |ns_window| {
        msgSend(void, ns_window, sel_makeKeyAndOrderFront, .{@as(?id, null)});
    }
}

pub const TrayIcon = struct {
    status_item: ?id,
    menu: ?id,

    pub fn init(sdl_window: *SDLBackend.c.SDL_Window) !TrayIcon {
        initSelectors();

        g_app_window = sdl_window;
        g_app_ns_window = getCocoaWindowFromSDL(sdl_window);
        if (g_app_ns_window) |ns_window| configureLauncherWindow(ns_window);

        // Make this a menu-bar style app (like Spotlight/Raycast): no Dock icon / Cmd-Tab entry.
        const NSApplication = objc_getClass("NSApplication") orelse return error.FailedToGetNSApplication;
        const app = msgSend(?id, NSApplication, sel_sharedApplication, .{}) orelse return error.FailedToGetNSApplication;
        const sel_setActivationPolicy = sel_registerName("setActivationPolicy:");
        _ = msgSend(bool, app, sel_setActivationPolicy, .{NSApplicationActivationPolicyAccessory});

        g_signals.reset();
        ensureWakeEventRegistered();

        // Get the system status bar
        const NSStatusBar = objc_getClass("NSStatusBar") orelse return error.FailedToGetNSStatusBar;
        const status_bar = msgSend(?id, NSStatusBar, sel_systemStatusBar, .{}) orelse return error.FailedToGetStatusBar;

        // Create a status item with variable length
        const status_item = msgSend(?id, status_bar, sel_statusItemWithLength, .{NSVariableStatusItemLength}) orelse return error.FailedToCreateStatusItem;

        // Set the button title
        const button = msgSend(?id, status_item, sel_button, .{});
        if (button) |btn| {
            const title = createNSString("wnk") orelse return error.FailedToCreateString;
            msgSend(void, btn, sel_setTitle, .{title});
        }

        // Create and set up the menu
        const NSMenu = objc_getClass("NSMenu") orelse return error.FailedToGetNSMenu;
        const menu_alloc = msgSend(?id, NSMenu, sel_alloc, .{}) orelse return error.FailedToAllocMenu;
        const menu = msgSend(?id, menu_alloc, sel_init, .{}) orelse return error.FailedToInitMenu;

        // Add menu items
        const NSMenuItem = objc_getClass("NSMenuItem") orelse return error.FailedToGetNSMenuItem;

        // "Show Window" item
        const show_title = createNSString("顯示視窗") orelse return error.FailedToCreateString;
        const show_key = createNSString("") orelse return error.FailedToCreateString;
        const show_item_alloc = msgSend(?id, NSMenuItem, sel_alloc, .{}) orelse return error.FailedToCreateMenuItem;
        const sel_initWithTitle = sel_registerName("initWithTitle:action:keyEquivalent:");
        const sel_showAction = sel_registerName("trayShowWindow:");
        const show_item = msgSend(?id, show_item_alloc, sel_initWithTitle, .{ show_title, sel_showAction, show_key });
        if (show_item) |item| {
            msgSend(void, menu, sel_addItem, .{item});
        }

        // Separator
        const separator = msgSend(?id, NSMenuItem, sel_separatorItem, .{});
        if (separator) |sep| {
            msgSend(void, menu, sel_addItem, .{sep});
        }

        // "Quit" item
        const quit_title = createNSString("結束") orelse return error.FailedToCreateString;
        const quit_key = createNSString("q") orelse return error.FailedToCreateString;
        const quit_item_alloc = msgSend(?id, NSMenuItem, sel_alloc, .{}) orelse return error.FailedToCreateMenuItem;
        const sel_quitAction = sel_registerName("trayQuit:");
        const quit_item = msgSend(?id, quit_item_alloc, sel_initWithTitle, .{ quit_title, sel_quitAction, quit_key });
        if (quit_item) |item| {
            msgSend(void, menu, sel_addItem, .{item});
        }

        // Set the menu
        msgSend(void, status_item, sel_setMenu, .{menu});

        // Register for menu item callbacks using a delegate
        setupMenuDelegate(menu);

        // Register global hotkey (Option+Space)
        registerGlobalHotkey();

        return TrayIcon{
            .status_item = status_item,
            .menu = menu,
        };
    }

    pub fn deinit(self: *TrayIcon) void {
        // Unregister global hotkey
        unregisterGlobalHotkey();

        if (self.status_item) |status_item| {
            // Remove from status bar
            const NSStatusBar = objc_getClass("NSStatusBar") orelse return;
            const status_bar = msgSend(?id, NSStatusBar, sel_systemStatusBar, .{}) orelse return;
            msgSend(void, status_bar, sel_removeStatusItem, .{status_item});
            self.status_item = null;
        }

        if (self.menu) |menu| {
            msgSend(void, menu, sel_release, .{});
            self.menu = null;
        }

        if (g_menu_delegate) |delegate| {
            msgSend(void, delegate, sel_release, .{});
            g_menu_delegate = null;
        }

        g_app_window = null;
        g_app_ns_window = null;
    }

    pub fn pollEvents(self: *TrayIcon) bool {
        _ = self;
        if (g_signals.takeShow()) {
            activateAndRaiseWindow();
            return true;
        }
        return false;
    }

    pub fn shouldExit(self: *TrayIcon) bool {
        _ = self;
        return g_signals.shouldExit();
    }

    pub fn checkTrayMessages(self: *TrayIcon) void {
        _ = self;
        // macOS handles menu events through the run loop automatically
    }
};

// Menu delegate for handling menu item actions
fn setupMenuDelegate(menu: id) void {
    // The delegate is set up via Objective-C runtime class creation
    // For simplicity, we'll poll the menu state instead
    // Menu item targets are typically handled by NSApplication's delegate
    // or by creating a custom Objective-C class at runtime

    // Create a delegate class dynamically
    const delegate_class = createDelegateClass() orelse {
        std.debug.print("Warning: Failed to create tray menu delegate class\n", .{});
        return;
    };
    const delegate_alloc = msgSend(?id, delegate_class, sel_alloc, .{}) orelse {
        std.debug.print("Warning: Failed to alloc tray menu delegate\n", .{});
        return;
    };
    const delegate = msgSend(?id, delegate_alloc, sel_init, .{}) orelse {
        std.debug.print("Warning: Failed to init tray menu delegate\n", .{});
        return;
    };

    if (g_menu_delegate) |old| {
        msgSend(void, old, sel_release, .{});
    }
    g_menu_delegate = delegate;

    // We need to set the menu item targets to our delegate
    const sel_itemArray = sel_registerName("itemArray");
    const sel_count = sel_registerName("count");
    const sel_objectAtIndex = sel_registerName("objectAtIndex:");

    const items = msgSend(?id, menu, sel_itemArray, .{}) orelse return;
    const count = msgSend(u64, items, sel_count, .{});
    var i: u64 = 0;
    while (i < count) : (i += 1) {
        const item = msgSend(?id, items, sel_objectAtIndex, .{i});
        if (item) |it| {
            // Check if it's not a separator
            const sel_isSeparator = sel_registerName("isSeparatorItem");
            const is_sep = msgSend(bool, it, sel_isSeparator, .{});
            if (!is_sep) {
                msgSend(void, it, sel_setTarget, .{delegate});
            }
        }
    }
}

// Objective-C runtime functions for class creation
extern "c" fn objc_allocateClassPair(superclass: ?Class, name: [*:0]const u8, extraBytes: usize) ?Class;
extern "c" fn objc_registerClassPair(cls: Class) void;
extern "c" fn class_addMethod(cls: Class, name: SEL, imp: *const anyopaque, types: [*:0]const u8) bool;

var delegate_class_created: bool = false;
var cached_delegate_class: ?Class = null;

fn createDelegateClass() ?Class {
    if (delegate_class_created) {
        return cached_delegate_class;
    }

    const NSObject = objc_getClass("NSObject") orelse return null;
    const new_class = objc_allocateClassPair(NSObject, "WnkTrayDelegate", 0) orelse return null;

    // Add the trayShowWindow: method
    const show_sel = sel_registerName("trayShowWindow:");
    _ = class_addMethod(new_class, show_sel, @ptrCast(&trayShowWindowImp), "v@:@");

    // Add the trayQuit: method
    const quit_sel = sel_registerName("trayQuit:");
    _ = class_addMethod(new_class, quit_sel, @ptrCast(&trayQuitImp), "v@:@");

    objc_registerClassPair(new_class);

    delegate_class_created = true;
    cached_delegate_class = new_class;

    return new_class;
}

// Implementation functions for menu actions
fn trayShowWindowImp(self: id, _sel: SEL, sender: id) callconv(.c) void {
    _ = self;
    _ = _sel;
    _ = sender;
    requestShow();
}

fn trayQuitImp(self: id, _sel: SEL, sender: id) callconv(.c) void {
    _ = self;
    _ = _sel;
    _ = sender;

    g_signals.requestExit();

    // Post quit event to SDL
    var quit_event: SDLBackend.c.SDL_Event = undefined;
    quit_event.type = SDLBackend.c.SDL_EVENT_QUIT;
    _ = SDLBackend.c.SDL_PushEvent(&quit_event);
}

// Block type for NSEvent handler
const BlockDescriptor = extern struct {
    reserved: c_ulong,
    size: c_ulong,
};

const BlockLiteral = extern struct {
    isa: ?*anyopaque,
    flags: c_int,
    reserved: c_int,
    invoke: *const fn (*BlockLiteral, id) callconv(.c) void,
    descriptor: *const BlockDescriptor,
};

// Block class reference
extern "c" const _NSConcreteGlobalBlock: anyopaque;

fn hotkeyBlockInvoke(block: *BlockLiteral, event: id) callconv(.c) void {
    _ = block;

    // Get keyCode from NSEvent
    const sel_keyCode = sel_registerName("keyCode");
    const keycode: u16 = @intCast(msgSend(u64, event, sel_keyCode, .{}));

    // Check if it's Space key
    if (keycode != kVK_Space) {
        return;
    }

    // Get modifier flags
    const sel_modifierFlags = sel_registerName("modifierFlags");
    const flags_raw: NSEventModifierFlags = msgSend(NSEventModifierFlags, event, sel_modifierFlags, .{});
    const flags: NSEventModifierFlags = flags_raw & NSEventModifierFlagDeviceIndependentFlagsMask;

    // Option+Space only (ignore CapsLock/Fn/etc).
    const option_pressed = (flags & NSEventModifierFlagOption) != 0;
    const disallowed = NSEventModifierFlagCommand | NSEventModifierFlagControl | NSEventModifierFlagShift;
    const other_mods = (flags & disallowed) != 0;

    if (option_pressed and !other_mods) {
        requestShow();
    }
}

const block_descriptor = BlockDescriptor{
    .reserved = 0,
    .size = @sizeOf(BlockLiteral),
};

var hotkey_block = BlockLiteral{
    .isa = @constCast(&_NSConcreteGlobalBlock),
    .flags = (1 << 28), // BLOCK_IS_GLOBAL
    .reserved = 0,
    .invoke = hotkeyBlockInvoke,
    .descriptor = &block_descriptor,
};

fn registerGlobalHotkey() void {
    const NSEvent = objc_getClass("NSEvent") orelse {
        std.debug.print("Warning: Failed to get NSEvent class\n", .{});
        return;
    };

    // Use addGlobalMonitorForEventsMatchingMask:handler:
    const sel_addGlobalMonitor = sel_registerName("addGlobalMonitorForEventsMatchingMask:handler:");

    const monitor = msgSend(?id, NSEvent, sel_addGlobalMonitor, .{ NSEventMaskKeyDown, &hotkey_block });

    if (monitor == null) {
        std.debug.print("Warning: Failed to create global key monitor. Please grant Input Monitoring (and/or Accessibility) permissions in System Settings > Privacy & Security.\n", .{});
        return;
    }

    g_event_monitor = monitor;
    std.debug.print("Global hotkey (Option+Space) registered successfully\n", .{});
}

fn unregisterGlobalHotkey() void {
    if (g_event_monitor) |monitor| {
        const NSEvent = objc_getClass("NSEvent") orelse return;
        const sel_removeMonitor = sel_registerName("removeMonitor:");
        msgSend(void, NSEvent, sel_removeMonitor, .{monitor});
        g_event_monitor = null;
    }
}
