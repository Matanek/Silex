//! LLVM 21's O0 pipeline still canonicalizes loops. Bypass it only for the
//! unannotated, forward-only functions in our emitted unit dialect.
const std = @import("std");

pub fn needsOpt(text: []const u8) bool {
    for ([_][]const u8{
        "alwaysinline", "attributes ", "llvm.coro.",   "instrument-function",
        "annotation",   " asm ",       "blockaddress", "personality",
    }) |special| if (std.mem.indexOf(u8, text, special) != null) return true;

    var cursor: usize = 0;
    var functions: usize = 0;
    while (std.mem.indexOfPos(u8, text, cursor, "define ")) |start| {
        if (start != 0 and text[start - 1] != '\n') return true;
        const header_end = std.mem.indexOfScalarPos(u8, text, start, '\n') orelse return true;
        // Our emitter has no trailing function attributes on eligible functions.
        // Keep opt if a future header adds anything after the parameter list.
        if (!std.mem.endsWith(u8, std.mem.trim(u8, text[start..header_end], " \t\r"), ") {")) return true;
        const end = std.mem.indexOfPos(u8, text, header_end, "\n}") orelse return true;
        if (!forwardOnly(text[header_end + 1 .. end])) return true;
        functions += 1;
        cursor = end + 2;
    }
    return functions == 0;
}

fn forwardOnly(body: []const u8) bool {
    var scratch = std.heap.stackFallback(4096, std.heap.page_allocator);
    const allocator = scratch.get();
    var labels: std.StringHashMapUnmanaged(usize) = .empty;
    defer labels.deinit(allocator);
    var lines = std.mem.splitScalar(u8, body, '\n');
    var offset: usize = 0;
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        if (std.mem.endsWith(u8, trimmed, ":")) {
            const name = trimmed[0 .. trimmed.len - 1];
            if (!validName(name) or labels.contains(name)) return false;
            labels.put(allocator, name, offset) catch return false;
        }
        offset += line.len + 1;
    }
    lines.reset();
    offset = 0;
    while (lines.next()) |line| {
        const trimmed = std.mem.trim(u8, line, " \t\r");
        var tokens = std.mem.tokenizeAny(u8, trimmed, " \t,[]");
        const operation = tokens.next() orelse {
            offset += line.len + 1;
            continue;
        };
        var edges: usize = 0;
        // Include the first token so a malformed bare label operand cannot
        // accidentally qualify. Unknown targets keep the existing pipeline.
        tokens.reset();
        while (tokens.next()) |token| {
            // Value-producing terminators can follow "%result =".
            for ([_][]const u8{
                "invoke",   "callbr",     "indirectbr", "catchswitch", "catchret",
                "catchpad", "cleanuppad", "cleanupret", "resume",
            }) |unknown| if (std.mem.eql(u8, token, unknown)) return false;
            if (std.mem.eql(u8, token, "label")) {
                const target = tokens.next() orelse return false;
                if (target.len < 2 or target[0] != '%' or !validName(target[1..])) return false;
                const position = labels.get(target[1..]) orelse return false;
                if (position <= offset) return false;
                edges += 1;
            }
        }
        if ((std.mem.eql(u8, operation, "br") or std.mem.eql(u8, operation, "switch")) and edges == 0) return false;
        offset += line.len + 1;
    }
    return true;
}

fn validName(name: []const u8) bool {
    if (name.len == 0) return false;
    for (name) |byte| if (!std.ascii.isAlphanumeric(byte) and
        byte != '_' and byte != '.' and byte != '$' and byte != '-') return false;
    return true;
}

test "LLVM Debug bypasses opt for straight lines and forward diamonds" {
    try std.testing.expect(!needsOpt(
        \\define hidden i64 @leaf() {
        \\entry:
        \\  ret i64 7
        \\}
        \\define hidden i64 @diamond(i1 %c) {
        \\entry:
        \\  br i1 %c, label %left, label %right
        \\left:
        \\  br label %end
        \\right:
        \\  br label %end
        \\end:
        \\  %v = phi i64 [ 1, %left ], [ 2, %right ]
        \\  ret i64 %v
        \\}
    ));
}

test "LLVM Debug retains opt for back edges even without phi instructions" {
    try std.testing.expect(needsOpt(
        \\define void @loop() {
        \\entry:
        \\  br label %body
        \\body:
        \\  br label %body
        \\}
    ));
}

test "LLVM Debug checks every function and multiline switch target" {
    try std.testing.expect(needsOpt(
        \\define void @leaf() {
        \\entry:
        \\  ret void
        \\}
        \\define void @loop(i64 %v) {
        \\entry:
        \\  br label %body
        \\body:
        \\  switch i64 %v, label %end [
        \\    i64 1, label %entry
        \\  ]
        \\end:
        \\  ret void
        \\}
    ));
}

test "LLVM Debug conservatively retains backward acyclic branches" {
    try std.testing.expect(needsOpt(
        \\define void @backward() {
        \\entry:
        \\  br label %last
        \\first:
        \\  ret void
        \\last:
        \\  br label %first
        \\}
    ));
}

test "LLVM Debug retains unknown targets terminators and annotations" {
    for ([_][]const u8{
        "define void @f() {\nentry:\n  br label %absent\n}",
        "define void @f() {\nentry:\n  indirectbr ptr null, []\n}",
        "define i32 @f() {\nentry:\n  %v = invoke i32 @g() to label %end unwind label %err\nend:\n  ret i32 %v\nerr:\n  unreachable\n}",
        "define void @f() {\nentry:\n  br label %\"quoted\"\n}",
        "define void @f() alwaysinline {\nentry:\n  ret void\n}",
        "define void @f() presplitcoroutine {\nentry:\n  ret void\n}",
        "declare void @llvm.coro.end()\ndefine void @f() {\n  ret void\n}",
        "attributes #0 = { nounwind }\ndefine void @f() {\n  ret void\n}",
        "declare void @external()",
    }) |text| try std.testing.expect(needsOpt(text));
}

test "LLVM Debug accepts every forward switch target and whitespace" {
    try std.testing.expect(!needsOpt(
        \\define void @select(i64 %value) {
        \\entry:
        \\  switch i64 %value, label %end [
        \\    i64 1, label %first
        \\  ]
        \\first:
        \\  br label %end
        \\end:
        \\  ret void
        \\}
    ));
    try std.testing.expect(!needsOpt("define void @f() {\nentry:\n  br label\t%end\nend:\n  ret void\n}"));
}
