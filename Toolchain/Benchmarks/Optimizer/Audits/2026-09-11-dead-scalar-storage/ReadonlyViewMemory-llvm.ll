; ModuleID = '.zig-cache/optimizer-oracle/ReadonlyViewMemory-raw.ll'
source_filename = ".zig-cache/optimizer-oracle/ReadonlyViewMemory-raw.ll"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

%sx.type.0 = type { ptr, i64 }

@.fmt.signed = private constant [6 x i8] c"%lld\0A\00"

; Function Attrs: nofree nounwind
declare noundef i32 @printf(ptr noundef readonly captures(none), ...) local_unnamed_addr #0

; Function Attrs: cold noreturn nounwind memory(inaccessiblemem: write)
declare void @llvm.trap() #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i64, i1 } @llvm.sadd.with.overflow.i64(i64, i64) #2

; Function Attrs: nounwind memory(read, inaccessiblemem: write)
define i64 @sx_0(%sx.type.0 %v0, i64 %v1) local_unnamed_addr #3 {
b0:
  %t0.count = extractvalue %sx.type.0 %v0, 1
  %t0.index.negative = icmp slt i64 %v1, 0
  %t0.index.wrapped = select i1 %t0.index.negative, i64 %t0.count, i64 0
  %t0.index = add i64 %t0.index.wrapped, %v1
  %t0.index.low = icmp slt i64 %t0.index, 0
  %t0.index.high = icmp sge i64 %t0.index, %t0.count
  %t0.index.invalid = or i1 %t0.index.low, %t0.index.high
  br i1 %t0.index.invalid, label %trap, label %b0.cont1

b0.cont1:                                         ; preds = %b0
  %t0.data = extractvalue %sx.type.0 %v0, 0
  %t0.element = getelementptr i64, ptr %t0.data, i64 %t0.index
  %v2 = load i64, ptr %t0.element, align 4
  %0 = getelementptr i64, ptr %t0.data, i64 %t0.count
  %t1.element = getelementptr i8, ptr %0, i64 -8
  %v4 = load i64, ptr %t1.element, align 4
  %t2.pair = tail call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %v2, i64 %v4)
  %t2.overflow = extractvalue { i64, i1 } %t2.pair, 1
  br i1 %t2.overflow, label %trap, label %b0.cont2

b0.cont2:                                         ; preds = %b0.cont1
  %v5 = extractvalue { i64, i1 } %t2.pair, 0
  ret i64 %v5

trap:                                             ; preds = %b0.cont1, %b0
  tail call void @llvm.trap()
  unreachable
}

; Function Attrs: nofree nounwind
define void @sx_1() local_unnamed_addr #0 {
b0:
  %t2.print = tail call i32 (ptr, ...) @printf(ptr nonnull dereferenceable(1) @.fmt.signed, i64 18)
  ret void
}

; Function Attrs: nofree nounwind
define noundef i32 @main() local_unnamed_addr #0 {
entry:
  %t2.print.i = tail call i32 (ptr, ...) @printf(ptr nonnull dereferenceable(1) @.fmt.signed, i64 18)
  ret i32 0
}

attributes #0 = { nofree nounwind }
attributes #1 = { cold noreturn nounwind memory(inaccessiblemem: write) }
attributes #2 = { mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #3 = { nounwind memory(read, inaccessiblemem: write) }
