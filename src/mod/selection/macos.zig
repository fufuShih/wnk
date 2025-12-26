const std = @import("std");
const builtin = @import("builtin");
const types = @import("types.zig");

const c = @cImport({
    @cInclude("ApplicationServices/ApplicationServices.h");
    @cInclude("CoreFoundation/CoreFoundation.h");
});

const id = *opaque {};
const SEL = *opaque {};
const Class = *opaque {};

extern "c" fn objc_getClass(name: [*:0]const u8) ?Class;
extern "c" fn sel_registerName(name: [*:0]const u8) SEL;
extern "c" fn objc_msgSend() void;
extern "c" fn objc_autoreleasePoolPush() ?*anyopaque;
extern "c" fn objc_autoreleasePoolPop(token: ?*anyopaque) void;

var objc_initialized: bool = false;
var sel_generalPasteboard: SEL = undefined;
var sel_stringForType: SEL = undefined;

fn debugLog(comptime fmt: []const u8, args: anytype) void {
    if (builtin.mode != .Debug) return;
    std.debug.print(fmt, args);
}

inline fn msgSend(comptime ReturnType: type, target: anytype, sel: SEL, args: anytype) ReturnType {
    const target_ptr = switch (@typeInfo(@TypeOf(target))) {
        .optional => target orelse return if (ReturnType == void) {} else null,
        else => target,
    };

    const FnType = switch (args.len) {
        0 => *const fn (@TypeOf(target_ptr), SEL) callconv(.c) ReturnType,
        1 => *const fn (@TypeOf(target_ptr), SEL, @TypeOf(args[0])) callconv(.c) ReturnType,
        2 => *const fn (@TypeOf(target_ptr), SEL, @TypeOf(args[0]), @TypeOf(args[1])) callconv(.c) ReturnType,
        else => @compileError("Too many arguments"),
    };

    const func: FnType = @ptrCast(&objc_msgSend);
    return switch (args.len) {
        0 => func(target_ptr, sel),
        1 => func(target_ptr, sel, args[0]),
        2 => func(target_ptr, sel, args[0], args[1]),
        else => unreachable,
    };
}

fn initObjC() void {
    if (objc_initialized) return;
    sel_generalPasteboard = sel_registerName("generalPasteboard");
    sel_stringForType = sel_registerName("stringForType:");
    objc_initialized = true;
}

fn cfStringToUtf8Alloc(allocator: std.mem.Allocator, cf_str: c.CFStringRef) !?[]u8 {
    if (cf_str == null) return null;
    const length = c.CFStringGetLength(cf_str);
    if (length <= 0) return null;

    var needed: c.CFIndex = 0;
    _ = c.CFStringGetBytes(
        cf_str,
        c.CFRange{ .location = 0, .length = length },
        c.kCFStringEncodingUTF8,
        0,
        0,
        null,
        0,
        &needed,
    );
    if (needed <= 0) return null;

    var buffer = try allocator.alloc(u8, @intCast(needed));
    var written: c.CFIndex = 0;
    const converted = c.CFStringGetBytes(
        cf_str,
        c.CFRange{ .location = 0, .length = length },
        c.kCFStringEncodingUTF8,
        0,
        0,
        buffer.ptr,
        needed,
        &written,
    );
    if (converted == 0 or written <= 0) {
        allocator.free(buffer);
        return null;
    }
    if (written != needed) {
        buffer = try allocator.realloc(buffer, @intCast(written));
    }
    return buffer;
}

fn createCFStringLiteral(lit: []const u8) ?c.CFStringRef {
    return c.CFStringCreateWithBytes(
        c.kCFAllocatorDefault,
        lit.ptr,
        @intCast(lit.len),
        c.kCFStringEncodingUTF8,
        0,
    );
}

fn cfTypeToUtf8Alloc(allocator: std.mem.Allocator, value: c.CFTypeRef) !?[]u8 {
    if (value == null) return null;
    const type_id = c.CFGetTypeID(value);
    if (type_id == c.CFStringGetTypeID()) {
        return try cfStringToUtf8Alloc(allocator, @ptrCast(value));
    }
    if (type_id == c.CFAttributedStringGetTypeID()) {
        const attr: c.CFAttributedStringRef = @ptrCast(value);
        const cf_str = c.CFAttributedStringGetString(attr);
        return try cfStringToUtf8Alloc(allocator, cf_str);
    }
    return null;
}

fn copySelectedTextFromElement(allocator: std.mem.Allocator, element: c.AXUIElementRef) !?[]u8 {
    const selected_text_attr = createCFStringLiteral("AXSelectedText") orelse return null;
    defer c.CFRelease(selected_text_attr);

    var value: c.CFTypeRef = null;
    if (c.AXUIElementCopyAttributeValue(element, selected_text_attr, &value) == c.kAXErrorSuccess and value != null) {
        defer c.CFRelease(value);
        if (try cfTypeToUtf8Alloc(allocator, value)) |text| return text;
    }

    const selected_range_attr = createCFStringLiteral("AXSelectedTextRange") orelse return null;
    defer c.CFRelease(selected_range_attr);

    var range_value: c.CFTypeRef = null;
    if (c.AXUIElementCopyAttributeValue(element, selected_range_attr, &range_value) != c.kAXErrorSuccess or range_value == null) {
        return null;
    }
    defer c.CFRelease(range_value);

    const ax_value: c.AXValueRef = @ptrCast(range_value);
    if (c.AXValueGetType(ax_value) != c.kAXValueCFRangeType) return null;

    var range: c.CFRange = undefined;
    if (c.AXValueGetValue(ax_value, c.kAXValueCFRangeType, &range) == 0) return null;
    if (range.length <= 0) return null;

    const string_for_range_attr = createCFStringLiteral("AXStringForRange") orelse return null;
    defer c.CFRelease(string_for_range_attr);

    var param_value: c.CFTypeRef = null;
    if (c.AXUIElementCopyParameterizedAttributeValue(
        element,
        string_for_range_attr,
        range_value,
        &param_value,
    ) != c.kAXErrorSuccess or param_value == null) {
        return null;
    }
    defer c.CFRelease(param_value);
    return try cfTypeToUtf8Alloc(allocator, param_value);
}

fn readSelectedText(allocator: std.mem.Allocator) !?[]u8 {
    if (c.AXIsProcessTrusted() == 0) {
        debugLog("selection: AX not trusted\n", .{});
        return null;
    }

    const system = c.AXUIElementCreateSystemWide();
    if (system == null) return null;
    defer c.CFRelease(system);

    const focused_attr = createCFStringLiteral("AXFocusedUIElement") orelse return null;
    defer c.CFRelease(focused_attr);

    var focused_value: c.CFTypeRef = null;
    const focus_err = c.AXUIElementCopyAttributeValue(system, focused_attr, &focused_value);
    if (focus_err != c.kAXErrorSuccess or focused_value == null) {
        debugLog("selection: AX focus err={}\n", .{focus_err});
        return null;
    }
    defer c.CFRelease(focused_value);

    const focused: c.AXUIElementRef = @ptrCast(focused_value);
    return try copySelectedTextFromElement(allocator, focused);
}

fn readClipboardText(allocator: std.mem.Allocator) !?[]u8 {
    initObjC();

    const pool = objc_autoreleasePoolPush();
    defer objc_autoreleasePoolPop(pool);

    const NSPasteboard = objc_getClass("NSPasteboard") orelse return null;
    const pasteboard = msgSend(?id, NSPasteboard, sel_generalPasteboard, .{}) orelse return null;

    const type_cf = c.CFStringCreateWithCString(c.kCFAllocatorDefault, "public.utf8-plain-text", c.kCFStringEncodingUTF8) orelse return null;
    defer c.CFRelease(type_cf);

    const type_obj: id = @ptrCast(@constCast(type_cf));
    const text_obj = msgSend(?id, pasteboard, sel_stringForType, .{type_obj}) orelse return null;
    const cf_str: c.CFStringRef = @ptrCast(text_obj);
    return try cfStringToUtf8Alloc(allocator, cf_str);
}

pub fn capture(allocator: std.mem.Allocator) !?types.Selection {
    debugLog("selection: capture start\n", .{});

    if (try readSelectedText(allocator)) |text| {
        debugLog("selection: AX text len={d}\n", .{text.len});
        return .{ .text = text, .source = .os };
    }

    if (try readClipboardText(allocator)) |text| {
        debugLog("selection: clipboard text len={d}\n", .{text.len});
        return .{ .text = text, .source = .clipboard };
    }

    debugLog("selection: done (null)\n", .{});
    return null;
}
