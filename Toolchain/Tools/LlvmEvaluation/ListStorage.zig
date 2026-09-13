const Ir = @import("silex_optimizer_api").Ir;

// Preserve the owner's value semantics before lending mutable element storage.
// Both a single-element reference and a collection view use this same COW path.
// The writer receives %tN.data and %tN.count at the continuation block.
pub fn detach(
    self: anytype,
    serial: usize,
    type_name: []const u8,
    element_name: []const u8,
    reference: Ir.ValueId,
    ownership: Ir.Ownership,
) error{OutOfMemory}!void {
    try self.write("  %t{d}.source = load {s}, ptr %v{d}\n", .{ serial, type_name, reference });
    try self.write("  %t{d}.old.data = extractvalue {s} %t{d}.source, 0\n", .{ serial, type_name, serial });
    try self.write("  %t{d}.count = extractvalue {s} %t{d}.source, 1\n", .{ serial, type_name, serial });
    try self.write("  %t{d}.roots.address = getelementptr i8, ptr %t{d}.old.data, i64 -24\n", .{ serial, serial });
    try self.write("  %t{d}.roots = load atomic i64, ptr %t{d}.roots.address acquire, align 8\n", .{ serial, serial });
    try self.write("  %t{d}.edges.address = getelementptr i8, ptr %t{d}.old.data, i64 -16\n", .{ serial, serial });
    try self.write("  %t{d}.edges = load atomic i64, ptr %t{d}.edges.address acquire, align 8\n", .{ serial, serial });
    try self.write("  %t{d}.owners = add i64 %t{d}.roots, %t{d}.edges\n", .{ serial, serial, serial });
    try self.write("  %t{d}.shared = icmp ne i64 %t{d}.owners, 1\n", .{ serial, serial });
    try self.write("  br i1 %t{d}.shared, label %collection.detach{d}, label %collection.unique{d}\n", .{ serial, serial, serial });
    try self.write("collection.detach{d}:\n", .{serial});
    try self.write("  %t{d}.storage.end = getelementptr {s}, ptr null, i64 %t{d}.count\n", .{ serial, element_name, serial });
    try self.write("  %t{d}.bytes = ptrtoint ptr %t{d}.storage.end to i64\n", .{ serial, serial });
    try self.write("  %t{d}.storage = call fastcc ptr @sx_alloc(i64 %t{d}.bytes)\n", .{ serial, serial });
    if (ownership == .edge) {
        try self.write("  call fastcc void @sx_retain(ptr %t{d}.storage, i64 -16)\n", .{serial});
        try self.write("  call fastcc void @sx_drop(ptr %t{d}.storage, i64 -24)\n", .{serial});
    }
    try self.write("  call void @llvm.memcpy.p0.p0.i64(ptr %t{d}.storage, ptr %t{d}.old.data, i64 %t{d}.bytes, i1 false)\n", .{ serial, serial, serial });
    try self.write("  %t{d}.detached.data = insertvalue {s} %t{d}.source, ptr %t{d}.storage, 0\n", .{ serial, type_name, serial, serial });
    try self.write("  store {s} %t{d}.detached.data, ptr %v{d}\n", .{ type_name, serial, reference });
    try self.write("  call fastcc void @sx_drop(ptr %t{d}.old.data, i64 {d})\n", .{
        serial,
        if (ownership == .root) @as(i8, -24) else -16,
    });
    try self.write("  br label %collection.ready{d}\n", .{serial});
    try self.write("collection.unique{d}:\n", .{serial});
    try self.write("  br label %collection.ready{d}\n", .{serial});
    try self.write("collection.ready{d}:\n", .{serial});
    try self.write("  %t{d}.data = phi ptr [ %t{d}.storage, %collection.detach{d} ], [ %t{d}.old.data, %collection.unique{d} ]\n", .{
        serial,
        serial,
        serial,
        serial,
        serial,
    });
}
