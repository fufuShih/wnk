const std = @import("std");
const ipc = @import("ipc.zig");

pub const LayoutKind = enum { flex, grid, box };

pub const LayoutSpec = struct {
    kind: LayoutKind = .flex,
    dir: ?[]const u8 = null,
    columns: ?usize = null,
    gap: ?usize = null,
};

pub fn header(title: []const u8, subtitle: ?[]const u8) ipc.PanelTopPayload {
    return .{
        .type = "header",
        .title = title,
        .subtitle = subtitle,
    };
}

pub fn bottomInfo(text: []const u8) ipc.PanelBottomPayload {
    return .{
        .type = "info",
        .text = text,
    };
}

pub fn bottomNone() ipc.PanelBottomPayload {
    return .{
        .type = "none",
        .text = null,
    };
}

pub fn item(title: []const u8, subtitle: []const u8, id: ?[]const u8, has_actions: ?bool) ipc.PanelItem {
    return .{
        .id = id,
        .title = title,
        .subtitle = subtitle,
        .has_actions = has_actions,
    };
}

pub fn listFromSpec(spec: []const u8, items: []const ipc.PanelItem) ipc.PanelNodePayload {
    const layout = parseLayoutSpec(spec);
    if (layout.kind == .grid) {
        return .{
            .type = "box",
            .layout = "grid",
            .columns = layout.columns,
            .gap = layout.gap,
            .items = items,
        };
    }
    return .{
        .type = "box",
        .layout = "flex",
        .items = items,
    };
}

pub fn boxFromSpec(spec: []const u8, children: []const ipc.PanelNodePayload) ipc.PanelNodePayload {
    const layout = parseLayoutSpec(spec);
    return .{
        .type = "box",
        .layout = switch (layout.kind) {
            .grid => "grid",
            .flex => "flex",
            .box => null,
        },
        .columns = layout.columns,
        .dir = layout.dir,
        .gap = layout.gap,
        .children = children,
    };
}

fn parseLayoutSpec(spec: []const u8) LayoutSpec {
    var it = std.mem.tokenizeAny(u8, spec, " \t\r\n");
    const first = it.next() orelse return .{ .kind = .flex };

    if (std.mem.eql(u8, first, "grid")) {
        var out: LayoutSpec = .{ .kind = .grid };
        if (it.next()) |tok| {
            out.columns = parseOptionalUsize(tok);
        }
        if (it.next()) |tok| {
            out.gap = parseOptionalUsize(tok);
        }
        return out;
    }

    if (std.mem.eql(u8, first, "flex")) {
        var out: LayoutSpec = .{ .kind = .flex };
        parseDirAndGap(&it, &out);
        return out;
    }

    if (std.mem.eql(u8, first, "box")) {
        var out: LayoutSpec = .{ .kind = .box };
        parseDirAndGap(&it, &out);
        return out;
    }

    return .{ .kind = .flex };
}

fn parseDirAndGap(it: anytype, out: *LayoutSpec) void {
    if (it.next()) |tok| {
        if (std.mem.eql(u8, tok, "horizontal") or std.mem.eql(u8, tok, "vertical")) {
            out.dir = tok;
        } else {
            out.gap = parseOptionalUsize(tok);
        }
    }
    if (it.next()) |tok| {
        out.gap = parseOptionalUsize(tok) orelse out.gap;
    }
}

fn parseOptionalUsize(value: []const u8) ?usize {
    return std.fmt.parseInt(usize, value, 10) catch null;
}
