// Private plain-value collection runtime for the bounded macOS ARM64 evaluation.
pub const text =
    \\@sx.live = internal global i64 0
    \\@.sx.bounds = private constant [84 x i8] c"%s:%lld:%lld: runtime error: collection index %lld is out of bounds for count %lld\0A\00"
    \\@.sx.conversion = private constant [57 x i8] c"%s:%lld:%lld: runtime error: invalid numeric conversion\0A\00"
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
;
