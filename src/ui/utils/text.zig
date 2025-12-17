const std = @import("std");

/// Text helpers shared across UI renderers and selection logic.
/// Keep these functions dependency-free (no dvui/state imports) so they are easy to reuse.

pub fn toLowerByte(c: u8) u8 {
    return if (c >= 'A' and c <= 'Z') c + 32 else c;
}

pub fn containsIgnoreCase(haystack: []const u8, needle: []const u8) bool {
    if (needle.len == 0) return true;
    if (needle.len > haystack.len) return false;

    var i: usize = 0;
    outer: while (i <= haystack.len - needle.len) : (i += 1) {
        for (needle, 0..) |nc, j| {
            if (toLowerByte(haystack[i + j]) != toLowerByte(nc)) {
                continue :outer;
            }
        }
        return true;
    }
    return false;
}

/// Copies `text` into `buf` as a single line (whitespace normalized) and truncates with "...".
/// Returns a slice into `buf`.
pub fn singleLineTruncateInto(buf: []u8, text: []const u8, max_bytes: usize) []const u8 {
    if (max_bytes == 0) return "";

    var out_len: usize = 0;
    for (text) |b| {
        if (out_len >= max_bytes) break;
        const c: u8 = switch (b) {
            '\n', '\r', '\t' => ' ',
            else => b,
        };
        buf[out_len] = c;
        out_len += 1;
    }

    if (text.len <= max_bytes) return buf[0..out_len];
    if (out_len < 3) return buf[0..out_len];

    // Replace last 3 bytes with "..." to hint truncation.
    buf[out_len - 3] = '.';
    buf[out_len - 2] = '.';
    buf[out_len - 1] = '.';
    return buf[0..out_len];
}

