// Private collection runtime for the bounded macOS ARM64 evaluation.
// Untyped allocations store byte capacity before roots/edges/destruction state.
// Their payload-relative ownership offsets and the typed class ABI stay fixed.
// Match native release semantics: class temporaries may start without a root;
// a zero collection count makes that ownership release a no-op. Never wrap it.
pub const text =
    \\@sx.live = internal global i64 0
    \\@.sx.bounds = private constant [84 x i8] c"%s:%lld:%lld: runtime error: collection index %lld is out of bounds for count %lld\0A\00"
    \\@.sx.conversion = private constant [57 x i8] c"%s:%lld:%lld: runtime error: invalid numeric conversion\0A\00"
    \\@.sx.assert = private constant [48 x i8] c"%s:%lld:%lld: runtime error: assertion failed: \00"
    \\@.sx.panic = private constant [30 x i8] c"%s:%lld:%lld: runtime error: \00"
    \\declare void @free(ptr)
    \\
    \\define internal fastcc ptr @sx_alloc(i64 %bytes) {
    \\entry:
    \\  %size = add i64 %bytes, 32
    \\  %wrapped = icmp ult i64 %size, %bytes
    \\  br i1 %wrapped, label %fail, label %allocate
    \\allocate:
    \\  %header = call ptr @malloc(i64 %size)
    \\  %null = icmp eq ptr %header, null
    \\  br i1 %null, label %fail, label %ready
    \\ready:
    \\  store i64 %bytes, ptr %header
    \\  %roots = getelementptr i8, ptr %header, i64 8
    \\  store i64 1, ptr %roots
    \\  %edges = getelementptr i8, ptr %header, i64 16
    \\  store i64 0, ptr %edges
    \\  %state = getelementptr i8, ptr %header, i64 24
    \\  store i64 0, ptr %state
    \\  %old = atomicrmw add ptr @sx.live, i64 1 monotonic
    \\  %data = getelementptr i8, ptr %header, i64 32
    \\  ret ptr %data
    \\fail:
    \\  call void @exit(i32 1)
    \\  unreachable
    \\}
    \\
    \\define internal fastcc ptr @sx_class_alloc(i64 %bytes) {
    \\entry:
    \\  %size = add i64 %bytes, 32
    \\  %wrapped = icmp ult i64 %size, %bytes
    \\  br i1 %wrapped, label %fail, label %allocate
    \\allocate:
    \\  %header = call ptr @malloc(i64 %size)
    \\  %null = icmp eq ptr %header, null
    \\  br i1 %null, label %fail, label %ready
    \\ready:
    \\  store i64 %bytes, ptr %header
    \\  %roots = getelementptr i8, ptr %header, i64 8
    \\  store i64 0, ptr %roots
    \\  %edges = getelementptr i8, ptr %header, i64 16
    \\  store i64 0, ptr %edges
    \\  %state = getelementptr i8, ptr %header, i64 24
    \\  store i64 0, ptr %state
    \\  %old = atomicrmw add ptr @sx.live, i64 1 monotonic
    \\  %data = getelementptr i8, ptr %header, i64 32
    \\  ret ptr %data
    \\fail:
    \\  call void @exit(i32 1)
    \\  unreachable
    \\}
    \\
    \\define internal fastcc ptr @sx_list_grow(ptr %data, i64 %used, i64 %required, i64 %offset) {
    \\entry:
    \\  %roots.address = getelementptr i8, ptr %data, i64 -24
    \\  %roots = load atomic i64, ptr %roots.address acquire, align 8
    \\  %edges.address = getelementptr i8, ptr %data, i64 -16
    \\  %edges = load atomic i64, ptr %edges.address acquire, align 8
    \\  %owners = add i64 %roots, %edges
    \\  %unique = icmp eq i64 %owners, 1
    \\  %capacity.address = getelementptr i8, ptr %data, i64 -32
    \\  %capacity = load i64, ptr %capacity.address
    \\  %fits = icmp ule i64 %required, %capacity
    \\  %reuse = and i1 %unique, %fits
    \\  br i1 %reuse, label %done, label %grow
    \\grow:
    \\  %double.checked = call { i64, i1 } @llvm.uadd.with.overflow.i64(i64 %capacity, i64 %capacity)
    \\  %double = extractvalue { i64, i1 } %double.checked, 0
    \\  %overflow = extractvalue { i64, i1 } %double.checked, 1
    \\  %too.big = icmp ugt i64 %double, -33
    \\  %invalid = or i1 %overflow, %too.big
    \\  %safe = select i1 %invalid, i64 %required, i64 %double
    \\  %reserve = select i1 %unique, i64 %safe, i64 %required
    \\  %enough = icmp uge i64 %reserve, %required
    \\  %bytes = select i1 %enough, i64 %reserve, i64 %required
    \\  %storage = call fastcc ptr @sx_alloc(i64 %bytes)
    \\  call void @llvm.memcpy.p0.p0.i64(ptr %storage, ptr %data, i64 %used, i1 false)
    \\  %edge = icmp eq i64 %offset, -16
    \\  br i1 %edge, label %transfer, label %release
    \\transfer:
    \\  call fastcc void @sx_retain(ptr %storage, i64 -16)
    \\  call fastcc void @sx_drop(ptr %storage, i64 -24)
    \\  br label %release
    \\release:
    \\  call fastcc void @sx_drop(ptr %data, i64 %offset)
    \\  ret ptr %storage
    \\done:
    \\  ret ptr %data
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
    \\  %old = atomicrmw add ptr @sx.live, i64 1 monotonic
    \\  ret ptr %header
    \\fail:
    \\  call void @exit(i32 1)
    \\  unreachable
    \\}
    \\
    \\define internal fastcc void @sx_typed_class_retain(ptr %data, i64 %offset) {
    \\entry:
    \\  %counter = getelementptr i8, ptr %data, i64 %offset
    \\  %old = atomicrmw add ptr %counter, i64 1 monotonic
    \\  ret void
    \\}
    \\
    \\define internal fastcc i64 @sx_release_count(ptr %counter) {
    \\entry:
    \\  %initial = load atomic i64, ptr %counter acquire, align 8
    \\  br label %retry
    \\retry:
    \\  %old = phi i64 [ %initial, %entry ], [ %observed, %decrement ]
    \\  %zero = icmp eq i64 %old, 0
    \\  br i1 %zero, label %done, label %decrement
    \\decrement:
    \\  %next = sub i64 %old, 1
    \\  %changed = cmpxchg ptr %counter, i64 %old, i64 %next acq_rel acquire
    \\  %observed = extractvalue { i64, i1 } %changed, 0
    \\  %won = extractvalue { i64, i1 } %changed, 1
    \\  br i1 %won, label %done, label %retry
    \\done:
    \\  ret i64 %old
    \\}
    \\
    \\define internal fastcc i1 @sx_typed_class_release(ptr %data, i64 %offset) {
    \\entry:
    \\  %counter = getelementptr i8, ptr %data, i64 %offset
    \\  %old = call fastcc i64 @sx_release_count(ptr %counter)
    \\  %roots.address = getelementptr i8, ptr %data, i64 8
    \\  %roots = load atomic i64, ptr %roots.address acquire, align 8
    \\  %edges.address = getelementptr i8, ptr %data, i64 16
    \\  %edges = load atomic i64, ptr %edges.address acquire, align 8
    \\  %no.roots = icmp eq i64 %roots, 0
    \\  %no.edges = icmp eq i64 %edges, 0
    \\  %unowned = and i1 %no.roots, %no.edges
    \\  br i1 %unowned, label %claim, label %done
    \\claim:
    \\  %state = getelementptr i8, ptr %data, i64 24
    \\  br label %retry
    \\retry:
    \\  %observed = load atomic i64, ptr %state acquire, align 8
    \\  %tracing = icmp eq i64 %observed, 2
    \\  br i1 %tracing, label %retry, label %inspect
    \\inspect:
    \\  %finalized = icmp eq i64 %observed, 1
    \\  br i1 %finalized, label %done, label %commit
    \\commit:
    \\  %claimed = cmpxchg ptr %state, i64 %observed, i64 1 acq_rel acquire
    \\  %won = extractvalue { i64, i1 } %claimed, 1
    \\  br i1 %won, label %ready, label %retry
    \\ready:
    \\  ret i1 true
    \\done:
    \\  ret i1 false
    \\}
    \\
    \\define internal fastcc void @sx_typed_class_free(ptr %data) {
    \\entry:
    \\  call void @free(ptr %data)
    \\  %live = atomicrmw sub ptr @sx.live, i64 1 acq_rel
    \\  ret void
    \\}
    \\
    \\define internal fastcc ptr @sx_unowned_alloc(i64 %bytes) {
    \\entry:
    \\  %data = call fastcc ptr @sx_class_alloc(i64 %bytes)
    \\  ret ptr %data
    \\}
    \\
    \\define internal fastcc void @sx_retain(ptr %data, i64 %offset) {
    \\entry:
    \\  %counter = getelementptr i8, ptr %data, i64 %offset
    \\  %old = atomicrmw add ptr %counter, i64 1 monotonic
    \\  ret void
    \\}
    \\
    \\define internal fastcc void @sx_drop(ptr %data, i64 %offset) {
    \\entry:
    \\  %counter = getelementptr i8, ptr %data, i64 %offset
    \\  %old = call fastcc i64 @sx_release_count(ptr %counter)
    \\  %released = icmp ne i64 %old, 0
    \\  br i1 %released, label %inspect, label %done
    \\inspect:
    \\  %roots.address = getelementptr i8, ptr %data, i64 -24
    \\  %roots = load atomic i64, ptr %roots.address acquire, align 8
    \\  %edges.address = getelementptr i8, ptr %data, i64 -16
    \\  %edges = load atomic i64, ptr %edges.address acquire, align 8
    \\  %no.roots = icmp eq i64 %roots, 0
    \\  %no.edges = icmp eq i64 %edges, 0
    \\  %unowned = and i1 %no.roots, %no.edges
    \\  br i1 %unowned, label %claim, label %done
    \\claim:
    \\  %state = getelementptr i8, ptr %data, i64 -8
    \\  %claimed = cmpxchg ptr %state, i64 0, i64 1 acq_rel acquire
    \\  %won = extractvalue { i64, i1 } %claimed, 1
    \\  br i1 %won, label %release, label %done
    \\release:
    \\  %header = getelementptr i8, ptr %data, i64 -32
    \\  call void @free(ptr %header)
    \\  %live = atomicrmw sub ptr @sx.live, i64 1 acq_rel
    \\  br label %done
    \\done:
    \\  ret void
    \\}
    \\
    \\define internal fastcc void @sx_string_retain(ptr %descriptor, i64 %offset) {
    \\entry:
    \\  %tagged = load i64, ptr %descriptor
    \\  %dynamic = icmp slt i64 %tagged, 0
    \\  br i1 %dynamic, label %retain, label %done
    \\retain:
    \\  call fastcc void @sx_retain(ptr %descriptor, i64 %offset)
    \\  br label %done
    \\done:
    \\  ret void
    \\}
    \\
    \\define internal fastcc void @sx_string_drop(ptr %descriptor, i64 %offset) {
    \\entry:
    \\  %tagged = load i64, ptr %descriptor
    \\  %dynamic = icmp slt i64 %tagged, 0
    \\  br i1 %dynamic, label %drop, label %done
    \\drop:
    \\  call fastcc void @sx_drop(ptr %descriptor, i64 %offset)
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
    \\  %live = load atomic i64, ptr @sx.live acquire, align 8
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
    \\
    \\define internal fastcc void @sx_panic(ptr %file, i64 %line, i64 %column, ptr %message) noreturn {
    \\entry:
    \\  %written.header = call i32 (i32, ptr, ...) @dprintf(i32 2, ptr @.sx.panic, ptr %file, i64 %line, i64 %column)
    \\  %tagged = load i64, ptr %message
    \\  %length = and i64 %tagged, 9223372036854775807
    \\  %bytes = getelementptr i8, ptr %message, i64 8
    \\  %written.message = call i64 @write(i32 2, ptr %bytes, i64 %length)
    \\  %written.newline = call i64 @write(i32 2, ptr @.newline, i64 1)
    \\  call void @exit(i32 1)
    \\  unreachable
    \\}
;
