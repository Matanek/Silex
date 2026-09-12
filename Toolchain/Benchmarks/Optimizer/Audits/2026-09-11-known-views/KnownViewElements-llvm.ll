; ModuleID = '.zig-cache/optimizer-oracle/KnownViewElements-raw.ll'
source_filename = ".zig-cache/optimizer-oracle/KnownViewElements-raw.ll"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

%sx.type.0 = type { ptr, i64 }

@.true = private constant [5 x i8] c"true\00"

; Function Attrs: cold noreturn nounwind memory(inaccessiblemem: write)
declare void @llvm.trap() #0

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i64, i1 } @llvm.sadd.with.overflow.i64(i64, i64) #1

; Function Attrs: nounwind memory(read, inaccessiblemem: write)
define i64 @sx_0(%sx.type.0 %v0, i64 %v1) local_unnamed_addr #2 {
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

; Function Attrs: nounwind memory(inaccessiblemem: write)
define i64 @sx_1(i64 %v0, i64 %v1) local_unnamed_addr #3 {
b0:
  %t6.pair = tail call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %v1, i64 13)
  %t6.overflow = extractvalue { i64, i1 } %t6.pair, 1
  br i1 %t6.overflow, label %trap, label %sx_0.exit

sx_0.exit:                                        ; preds = %b0
  %v18 = extractvalue { i64, i1 } %t6.pair, 0
  %t7.pair = tail call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %v18, i64 %v18)
  %t7.overflow = extractvalue { i64, i1 } %t7.pair, 1
  br i1 %t7.overflow, label %trap, label %b0.cont7

b0.cont7:                                         ; preds = %sx_0.exit
  %v21 = extractvalue { i64, i1 } %t7.pair, 0
  ret i64 %v21

trap:                                             ; preds = %sx_0.exit, %b0
  tail call void @llvm.trap()
  unreachable
}

; Function Attrs: nounwind memory(inaccessiblemem: write)
define range(i64 -9223372036854775795, -9223372036854775808) i64 @sx_2(i64 %v0, i64 %v1) local_unnamed_addr #3 {
b0:
  %t3.pair = tail call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %v1, i64 13)
  %t3.overflow = extractvalue { i64, i1 } %t3.pair, 1
  br i1 %t3.overflow, label %trap, label %b0.cont4

b0.cont4:                                         ; preds = %b0
  %v9 = extractvalue { i64, i1 } %t3.pair, 0
  %t5.pair = tail call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %v9, i64 %v1)
  %t5.overflow = extractvalue { i64, i1 } %t5.pair, 1
  br i1 %t5.overflow, label %trap, label %b0.cont6

b0.cont6:                                         ; preds = %b0.cont4
  %v12 = extractvalue { i64, i1 } %t5.pair, 0
  %t7.pair = tail call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %v12, i64 13)
  %t7.overflow = extractvalue { i64, i1 } %t7.pair, 1
  br i1 %t7.overflow, label %trap, label %b0.cont7

b0.cont7:                                         ; preds = %b0.cont6
  %v15 = extractvalue { i64, i1 } %t7.pair, 0
  ret i64 %v15

trap:                                             ; preds = %b0.cont6, %b0.cont4, %b0
  tail call void @llvm.trap()
  unreachable
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define noundef i64 @sx_3() local_unnamed_addr #4 {
b0:
  ret i64 0
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define double @sx_4(double %v0) local_unnamed_addr #4 {
b0:
  %v12 = fadd double %v0, 2.500000e+00
  ret double %v12
}

; Function Attrs: nounwind memory(write)
define void @sx_5(%sx.type.0 %v0) local_unnamed_addr #5 {
b0:
  %v0.fca.1.extract = extractvalue %sx.type.0 %v0, 1
  %t0.index.invalid = icmp slt i64 %v0.fca.1.extract, 1
  br i1 %t0.index.invalid, label %trap, label %b0.cont2

b0.cont2:                                         ; preds = %b0
  %v0.fca.0.extract = extractvalue %sx.type.0 %v0, 0
  %0 = getelementptr i64, ptr %v0.fca.0.extract, i64 %v0.fca.1.extract
  %t0.element = getelementptr i8, ptr %0, i64 -8
  store i64 34, ptr %t0.element, align 4
  ret void

trap:                                             ; preds = %b0
  tail call void @llvm.trap()
  unreachable
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define noundef range(i64 -9223372036854775800, -9223372036854775808) i64 @sx_6() local_unnamed_addr #4 {
b0:
  ret i64 42
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define range(i64 5, 22) i64 @sx_7(i1 %v0) local_unnamed_addr #4 {
b0:
  %spec.select = select i1 %v0, i64 21, i64 5
  ret i64 %spec.select
}

; Function Attrs: nofree nounwind
define void @sx_8() local_unnamed_addr #6 {
b0:
  %puts = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts1 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts2 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts3 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts4 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts5 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts6 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  ret void
}

; Function Attrs: nofree nounwind
define noundef i32 @main() local_unnamed_addr #6 {
entry:
  %puts.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts1.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts2.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts3.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts4.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts5.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts6.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  ret i32 0
}

; Function Attrs: nofree nounwind
declare noundef i32 @puts(ptr noundef readonly captures(none)) local_unnamed_addr #6

attributes #0 = { cold noreturn nounwind memory(inaccessiblemem: write) }
attributes #1 = { mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nounwind memory(read, inaccessiblemem: write) }
attributes #3 = { nounwind memory(inaccessiblemem: write) }
attributes #4 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) }
attributes #5 = { nounwind memory(write) }
attributes #6 = { nofree nounwind }
