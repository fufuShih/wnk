const std = @import("std");
const SDLBackend = @import("sdl-backend");

// Objective-C runtime types
const id = *opaque {};
const SEL = *opaque {};
const Class = *opaque {};

// Carbon Events types for global hotkeys
const EventHotKeyRef = *opaque {};
const EventHotKeyID = extern struct {
    signature: u32,
    id: u32,
};
const EventTypeSpec = extern struct {
    eventClass: u32,
    eventKind: u32,
};
const EventHandlerRef = *opaque {};
const EventTargetRef = *opaque {};
const EventRef = *opaque {};
const EventHandlerProcPtr = *const fn (EventHandlerRef, EventRef, ?*anyopaque) callconv(.c) i32;

// Carbon constants
const kEventClassKeyboard: u32 = 0x6b657962; // 'keyb'
const kEventHotKeyPressed: u32 = 5;
const optionKey: u32 = 0x0800; // Option/Alt modifier
const cmdKey: u32 = 0x0100; // Command modifier
const kVK_Space: u32 = 49; // Space key virtual key code
const noErr: i32 = 0;
const HOTKEY_SIGNATURE: u32 = 0x776e6b21; // 'wnk!'
const HOTKEY_ID_SHOW: u32 = 1;

// Carbon Events API
extern "c" fn GetApplicationEventTarget() EventTargetRef;
extern "c" fn InstallEventHandler(
    inTarget: EventTargetRef,
    inHandler: EventHandlerProcPtr,
    inNumTypes: u32,
    inList: [*]const EventTypeSpec,
    inUserData: ?*anyopaque,
    outRef: ?*EventHandlerRef,
) callconv(.c) i32;
extern "c" fn RegisterEventHotKey(
    inHotKeyCode: u32,
    inHotKeyModifiers: u32,
    inHotKeyID: EventHotKeyID,
    inTarget: EventTargetRef,
    inOptions: u32,
    outRef: *EventHotKeyRef,
) callconv(.c) i32;
extern "c" fn UnregisterEventHotKey(inHotKey: EventHotKeyRef) callconv(.c) i32;

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

// NSStatusBar constants - variable length from center
const NSVariableStatusItemLength: f64 = -1.0;

// Global state
var g_should_exit: bool = false;
var g_should_show: bool = false;
var g_status_item: ?id = null;
var g_app_window: ?*SDLBackend.c.SDL_Window = null;
var g_hotkey_ref: ?EventHotKeyRef = null;
var g_event_handler_ref: ?EventHandlerRef = null;

// Selectors (cached)
var sel_sharedApplication: SEL = undefined;
var sel_systemStatusBar: SEL = undefined;
var sel_statusItemWithLength: SEL = undefined;
var sel_setTitle: SEL = undefined;
var sel_setMenu: SEL = undefined;
var sel_setAction: SEL = undefined;
var sel_setTarget: SEL = undefined;
var sel_alloc: SEL = undefined;
var sel_init: SEL = undefined;
var sel_addItem: SEL = undefined;
var sel_addItemWithTitle: SEL = undefined;
var sel_separatorItem: SEL = undefined;
var sel_stringWithUTF8String: SEL = undefined;
var sel_button: SEL = undefined;
var sel_removeStatusItem: SEL = undefined;
var sel_release: SEL = undefined;

var selectors_initialized: bool = false;

fn initSelectors() void {
    if (selectors_initialized) return;

    sel_sharedApplication = sel_registerName("sharedApplication");
    sel_systemStatusBar = sel_registerName("systemStatusBar");
    sel_statusItemWithLength = sel_registerName("statusItemWithLength:");
    sel_setTitle = sel_registerName("setTitle:");
    sel_setMenu = sel_registerName("setMenu:");
    sel_setAction = sel_registerName("setAction:");
    sel_setTarget = sel_registerName("setTarget:");
    sel_alloc = sel_registerName("alloc");
    sel_init = sel_registerName("init");
    sel_addItem = sel_registerName("addItem:");
    sel_addItemWithTitle = sel_registerName("addItemWithTitle:action:keyEquivalent:");
    sel_separatorItem = sel_registerName("separatorItem");
    sel_stringWithUTF8String = sel_registerName("stringWithUTF8String:");
    sel_button = sel_registerName("button");
    sel_removeStatusItem = sel_registerName("removeStatusItem:");
    sel_release = sel_registerName("release");

    selectors_initialized = true;
}

fn createNSString(str: [*:0]const u8) ?id {
    const NSString = objc_getClass("NSString") orelse return null;
    return msgSend(?id, NSString, sel_stringWithUTF8String, .{str});
}

pub const TrayIcon = struct {
    status_item: ?id,
    menu: ?id,

    pub fn init(sdl_window: *SDLBackend.c.SDL_Window) !TrayIcon {
        initSelectors();

        g_app_window = sdl_window;
        g_should_exit = false;
        g_should_show = false;

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

        // Store globally for callback access
        g_status_item = status_item;

        // Register for menu item callbacks using a delegate
        try setupMenuDelegate(menu);

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

        g_status_item = null;
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
        _ = self;
        // macOS handles menu events through the run loop automatically
    }
};

// Menu delegate for handling menu item actions
fn setupMenuDelegate(menu: ?id) !void {
    _ = menu;
    // The delegate is set up via Objective-C runtime class creation
    // For simplicity, we'll poll the menu state instead
    // Menu item targets are typically handled by NSApplication's delegate
    // or by creating a custom Objective-C class at runtime

    // Create a delegate class dynamically
    const delegate_class = createDelegateClass() orelse return;
    const delegate_alloc = msgSend(?id, delegate_class, sel_alloc, .{}) orelse return;
    const delegate = msgSend(?id, delegate_alloc, sel_init, .{}) orelse return;

    // Set the delegate as the application delegate for menu actions
    const NSApplication = objc_getClass("NSApplication") orelse return;
    const app = msgSend(?id, NSApplication, sel_sharedApplication, .{}) orelse return;

    // We need to set the menu item targets to our delegate
    const sel_itemArray = sel_registerName("itemArray");
    const sel_count = sel_registerName("count");
    const sel_objectAtIndex = sel_registerName("objectAtIndex:");

    if (g_status_item) |status_item| {
        const inner_menu = msgSend(?id, status_item, sel_registerName("menu"), .{});
        if (inner_menu) |m| {
            const items = msgSend(?id, m, sel_itemArray, .{});
            if (items) |arr| {
                const count = msgSend(u64, arr, sel_count, .{});
                var i: u64 = 0;
                while (i < count) : (i += 1) {
                    const item = msgSend(?id, arr, sel_objectAtIndex, .{i});
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
        }
    }

    _ = app;
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

    g_should_show = true;

    // Bring app to front
    if (g_app_window) |window| {
        _ = SDLBackend.c.SDL_RaiseWindow(window);
    }
}

fn trayQuitImp(self: id, _sel: SEL, sender: id) callconv(.c) void {
    _ = self;
    _ = _sel;
    _ = sender;

    g_should_exit = true;

    // Post quit event to SDL
    var quit_event: SDLBackend.c.SDL_Event = undefined;
    quit_event.type = SDLBackend.c.SDL_EVENT_QUIT;
    _ = SDLBackend.c.SDL_PushEvent(&quit_event);
}

// Global hotkey handler
fn hotkeyHandler(nextHandler: EventHandlerRef, theEvent: EventRef, userData: ?*anyopaque) callconv(.c) i32 {
    _ = nextHandler;
    _ = theEvent;
    _ = userData;

    g_should_show = true;

    // Bring app to front
    if (g_app_window) |window| {
        _ = SDLBackend.c.SDL_RaiseWindow(window);
    }

    // Also activate the application
    const NSApplication = objc_getClass("NSApplication");
    if (NSApplication) |cls| {
        const app = msgSend(?id, cls, sel_sharedApplication, .{});
        if (app) |a| {
            const sel_activateIgnoringOtherApps = sel_registerName("activateIgnoringOtherApps:");
            msgSend(void, a, sel_activateIgnoringOtherApps, .{true});
        }
    }

    return noErr;
}

fn registerGlobalHotkey() void {
    // Install event handler for hotkey events
    const eventTypes = [_]EventTypeSpec{
        .{ .eventClass = kEventClassKeyboard, .eventKind = kEventHotKeyPressed },
    };

    var handler_ref: EventHandlerRef = undefined;
    const result = InstallEventHandler(
        GetApplicationEventTarget(),
        hotkeyHandler,
        1,
        &eventTypes,
        null,
        &handler_ref,
    );

    if (result != noErr) {
        std.debug.print("Warning: Failed to install hotkey event handler (error: {})\n", .{result});
        return;
    }
    g_event_handler_ref = handler_ref;

    // Register Option+Space hotkey
    const hotkeyID = EventHotKeyID{
        .signature = HOTKEY_SIGNATURE,
        .id = HOTKEY_ID_SHOW,
    };

    var hotkey_ref: EventHotKeyRef = undefined;
    const reg_result = RegisterEventHotKey(
        kVK_Space,
        optionKey,
        hotkeyID,
        GetApplicationEventTarget(),
        0,
        &hotkey_ref,
    );

    if (reg_result != noErr) {
        std.debug.print("Warning: Option+Space hotkey registration failed (error: {}), trying Cmd+Option+Space\n", .{reg_result});

        // Try Cmd+Option+Space as fallback
        const fallback_result = RegisterEventHotKey(
            kVK_Space,
            optionKey | cmdKey,
            hotkeyID,
            GetApplicationEventTarget(),
            0,
            &hotkey_ref,
        );

        if (fallback_result != noErr) {
            std.debug.print("Warning: Cmd+Option+Space also failed (error: {})\n", .{fallback_result});
            return;
        }
    }

    g_hotkey_ref = hotkey_ref;
    std.debug.print("Global hotkey registered successfully\n", .{});
}

fn unregisterGlobalHotkey() void {
    if (g_hotkey_ref) |ref| {
        _ = UnregisterEventHotKey(ref);
        g_hotkey_ref = null;
    }
}
