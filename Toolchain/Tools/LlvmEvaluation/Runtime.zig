// Private plain-value collection runtime for the bounded macOS ARM64 evaluation.
pub const text =
    \\@sx.live = internal global i64 0
    \\@.sx.bounds = private constant [84 x i8] c"%s:%lld:%lld: runtime error: collection index %lld is out of bounds for count %lld\0A\00"
    \\@.sx.conversion = private constant [57 x i8] c"%s:%lld:%lld: runtime error: invalid numeric conversion\0A\00"
    \\@.sx.assert = private constant [48 x i8] c"%s:%lld:%lld: runtime error: assertion failed: \00"
    \\declare void @free(ptr)
    \\
    \\define internal fastcc ptr @sx_alloc(i64 %bytes) {
    \\entry:
    \\  %size = add i64 %bytes, 8
    \\  %wrapped = icmp ult i64 %size, %bytes
    \\  br i1 %wrapped, label %fail, label %allocate
    \\allocate:
    \\  %header = call ptr @malloc(i64 %size)
    \\  %null = icmp eq ptr %header, null
    \\  br i1 %null, label %fail, label %ready
    \\ready:
    \\  store i64 1, ptr %header
    \\  %old = load i64, ptr @sx.live
    \\  %next = add i64 %old, 1
    \\  store i64 %next, ptr @sx.live
    \\  %data = getelementptr i8, ptr %header, i64 8
    \\  ret ptr %data
    \\fail:
    \\  call void @exit(i32 1)
    \\  unreachable
    \\}
    \\
    \\define internal fastcc ptr @sx_class_alloc(i64 %bytes) {
    \\entry:
    \\  %size = add i64 %bytes, 8
    \\  %wrapped = icmp ult i64 %size, %bytes
    \\  br i1 %wrapped, label %fail, label %allocate
    \\allocate:
    \\  %header = call ptr @malloc(i64 %size)
    \\  %null = icmp eq ptr %header, null
    \\  br i1 %null, label %fail, label %ready
    \\ready:
    \\  store i64 0, ptr %header
    \\  %old = load i64, ptr @sx.live
    \\  %next = add i64 %old, 1
    \\  store i64 %next, ptr @sx.live
    \\  %data = getelementptr i8, ptr %header, i64 8
    \\  ret ptr %data
    \\fail:
    \\  call void @exit(i32 1)
    \\  unreachable
    \\}
    \\
    \\define internal fastcc ptr @sx_typed_class_alloc(i64 %bytes, i64 %type) {
    \\entry:
    \\  %size = add i64 %bytes, 32
    \\  %wrapped = icmp ult i64 %size, %bytes
    \\  br i1 %wrapped, label %fail, label %allocate
    \\allocate:
    \\  %header = call ptr @malloc(i64 %size)
    \\  %null = icmp eq ptr %header, null
    \\  br i1 %null, label %fail, label %ready
    \\ready:
    \\  store i64 %type, ptr %header
    \\  %roots = getelementptr i8, ptr %header, i64 8
    \\  store i64 0, ptr %roots
    \\  %edges = getelementptr i8, ptr %header, i64 16
    \\  store i64 0, ptr %edges
    \\  %state = getelementptr i8, ptr %header, i64 24
    \\  store i64 0, ptr %state
    \\  %old = load i64, ptr @sx.live
    \\  %next = add i64 %old, 1
    \\  store i64 %next, ptr @sx.live
    \\  ret ptr %header
    \\fail:
    \\  call void @exit(i32 1)
    \\  unreachable
    \\}
    \\
    \\define internal fastcc void @sx_typed_class_retain(ptr %data) {
    \\entry:
    \\  %roots = getelementptr i8, ptr %data, i64 8
    \\  %old = load i64, ptr %roots
    \\  %next = add i64 %old, 1
    \\  store i64 %next, ptr %roots
    \\  ret void
    \\}
    \\
    \\define internal fastcc void @sx_typed_class_drop(ptr %data) {
    \\entry:
    \\  %roots = getelementptr i8, ptr %data, i64 8
    \\  %old = load i64, ptr %roots
    \\  %next = sub i64 %old, 1
    \\  store i64 %next, ptr %roots
    \\  %last = icmp eq i64 %next, 0
    \\  br i1 %last, label %release, label %done
    \\release:
    \\  call void @free(ptr %data)
    \\  %live = load i64, ptr @sx.live
    \\  %remaining = sub i64 %live, 1
    \\  store i64 %remaining, ptr @sx.live
    \\  br label %done
    \\done:
    \\  ret void
    \\}
    \\
    \\define internal fastcc ptr @sx_unowned_alloc(i64 %bytes) {
    \\entry:
    \\  %data = call fastcc ptr @sx_class_alloc(i64 %bytes)
    \\  ret ptr %data
    \\}
    \\
    \\define internal fastcc void @sx_retain(ptr %data) {
    \\entry:
    \\  %header = getelementptr i8, ptr %data, i64 -8
    \\  %old = load i64, ptr %header
    \\  %next = add i64 %old, 1
    \\  store i64 %next, ptr %header
    \\  ret void
    \\}
    \\
    \\define internal fastcc void @sx_drop(ptr %data) {
    \\entry:
    \\  %header = getelementptr i8, ptr %data, i64 -8
    \\  %old = load i64, ptr %header
    \\  %next = sub i64 %old, 1
    \\  store i64 %next, ptr %header
    \\  %last = icmp eq i64 %next, 0
    \\  br i1 %last, label %release, label %done
    \\release:
    \\  call void @free(ptr %header)
    \\  %live = load i64, ptr @sx.live
    \\  %remaining = sub i64 %live, 1
    \\  store i64 %remaining, ptr @sx.live
    \\  br label %done
    \\done:
    \\  ret void
    \\}
    \\
    \\define internal fastcc void @sx_string_retain(ptr %descriptor) {
    \\entry:
    \\  %tagged = load i64, ptr %descriptor
    \\  %dynamic = icmp slt i64 %tagged, 0
    \\  br i1 %dynamic, label %retain, label %done
    \\retain:
    \\  call fastcc void @sx_retain(ptr %descriptor)
    \\  br label %done
    \\done:
    \\  ret void
    \\}
    \\
    \\define internal fastcc void @sx_string_drop(ptr %descriptor) {
    \\entry:
    \\  %tagged = load i64, ptr %descriptor
    \\  %dynamic = icmp slt i64 %tagged, 0
    \\  br i1 %dynamic, label %drop, label %done
    \\drop:
    \\  call fastcc void @sx_drop(ptr %descriptor)
    \\  br label %done
    \\done:
    \\  ret void
    \\}
    \\
    \\define internal fastcc i1 @sx_string_equal(ptr %left, ptr %right) {
    \\entry:
    \\  %left.tagged = load i64, ptr %left
    \\  %right.tagged = load i64, ptr %right
    \\  %left.length = and i64 %left.tagged, 9223372036854775807
    \\  %right.length = and i64 %right.tagged, 9223372036854775807
    \\  %same.length = icmp eq i64 %left.length, %right.length
    \\  br i1 %same.length, label %length.match, label %unequal
    \\length.match:
    \\  %empty = icmp eq i64 %left.length, 0
    \\  br i1 %empty, label %equal, label %compare
    \\compare:
    \\  %index = phi i64 [ 0, %length.match ], [ %next, %advance ]
    \\  %left.offset = add i64 %index, 8
    \\  %right.offset = add i64 %index, 8
    \\  %left.address = getelementptr i8, ptr %left, i64 %left.offset
    \\  %right.address = getelementptr i8, ptr %right, i64 %right.offset
    \\  %left.byte = load i8, ptr %left.address
    \\  %right.byte = load i8, ptr %right.address
    \\  %same.byte = icmp eq i8 %left.byte, %right.byte
    \\  br i1 %same.byte, label %advance, label %unequal
    \\advance:
    \\  %next = add i64 %index, 1
    \\  %finished = icmp eq i64 %next, %left.length
    \\  br i1 %finished, label %equal, label %compare
    \\equal:
    \\  ret i1 true
    \\unequal:
    \\  ret i1 false
    \\}
    \\
    \\define internal fastcc i64 @sx_string_count(ptr %descriptor) {
    \\entry:
    \\  %tagged = load i64, ptr %descriptor
    \\  %length = and i64 %tagged, 9223372036854775807
    \\  %empty = icmp eq i64 %length, 0
    \\  br i1 %empty, label %done.empty, label %scan
    \\scan:
    \\  %index = phi i64 [ 0, %entry ], [ %next, %advance ]
    \\  %count = phi i64 [ 0, %entry ], [ %next.count, %advance ]
    \\  %offset = add i64 %index, 8
    \\  %address = getelementptr i8, ptr %descriptor, i64 %offset
    \\  %byte = load i8, ptr %address
    \\  %prefix = and i8 %byte, -64
    \\  %continuation = icmp eq i8 %prefix, -128
    \\  %increment = select i1 %continuation, i64 0, i64 1
    \\  %next.count = add i64 %count, %increment
    \\  br label %advance
    \\advance:
    \\  %next = add i64 %index, 1
    \\  %finished = icmp eq i64 %next, %length
    \\  br i1 %finished, label %done, label %scan
    \\done:
    \\  ret i64 %next.count
    \\done.empty:
    \\  ret i64 0
    \\}
    \\
    \\define internal fastcc void @sx_finish() {
    \\entry:
    \\  %live = load i64, ptr @sx.live
    \\  %empty = icmp eq i64 %live, 0
    \\  br i1 %empty, label %done, label %fail
    \\fail:
    \\  call void @exit(i32 2)
    \\  unreachable
    \\done:
    \\  ret void
    \\}
    \\
    \\define internal fastcc void @sx_bounds(ptr %file, i64 %line, i64 %column, i64 %index, i64 %count) noreturn {
    \\entry:
    \\  %written = call i32 (i32, ptr, ...) @dprintf(i32 2, ptr @.sx.bounds, ptr %file, i64 %line, i64 %column, i64 %index, i64 %count)
    \\  call void @exit(i32 1)
    \\  unreachable
    \\}
    \\
    \\define internal fastcc void @sx_conversion(ptr %file, i64 %line, i64 %column) noreturn {
    \\entry:
    \\  %written = call i32 (i32, ptr, ...) @dprintf(i32 2, ptr @.sx.conversion, ptr %file, i64 %line, i64 %column)
    \\  call void @exit(i32 1)
    \\  unreachable
    \\}
    \\
    \\define internal fastcc void @sx_assert(ptr %file, i64 %line, i64 %column, ptr %message) noreturn {
    \\entry:
    \\  %written.header = call i32 (i32, ptr, ...) @dprintf(i32 2, ptr @.sx.assert, ptr %file, i64 %line, i64 %column)
    \\  %tagged = load i64, ptr %message
    \\  %length = and i64 %tagged, 9223372036854775807
    \\  %bytes = getelementptr i8, ptr %message, i64 8
    \\  %written.message = call i64 @write(i32 2, ptr %bytes, i64 %length)
    \\  %written.newline = call i64 @write(i32 2, ptr @.newline, i64 1)
    \\  call void @exit(i32 1)
    \\  unreachable
    \\}
;
