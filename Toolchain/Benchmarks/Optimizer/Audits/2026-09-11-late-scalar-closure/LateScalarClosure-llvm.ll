; ModuleID = '.zig-cache/optimizer-oracle/LateScalarClosure-raw.ll'
source_filename = ".zig-cache/optimizer-oracle/LateScalarClosure-raw.ll"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

%sx.type.0 = type { ptr, i64 }

@.true = private constant [5 x i8] c"true\00"
@.false = private constant [6 x i8] c"false\00"

; Function Attrs: cold noreturn nounwind memory(inaccessiblemem: write)
declare void @llvm.trap() #0

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i64, i1 } @llvm.sadd.with.overflow.i64(i64, i64) #1

; Function Attrs: nounwind memory(read, inaccessiblemem: write)
define i64 @sx_0(%sx.type.0 %v0) local_unnamed_addr #2 {
b0:
  %t0.count = extractvalue %sx.type.0 %v0, 1
  %t0.index.high = icmp slt i64 %t0.count, 1
  br i1 %t0.index.high, label %trap, label %b0.cont1

b0.cont1:                                         ; preds = %b0
  %t0.data = extractvalue %sx.type.0 %v0, 0
  %v2 = load i64, ptr %t0.data, align 4
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
define range(i64 -9223372036854775801, -9223372036854775808) i64 @sx_1(i64 %v0) local_unnamed_addr #3 {
b0:
  %t0.overflow = icmp eq i64 %v0, 9223372036854775807
  br i1 %t0.overflow, label %trap, label %b0.cont0

b0.cont0:                                         ; preds = %b0
  %t2.pair.i = tail call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %v0, i64 7)
  %t2.overflow.i = extractvalue { i64, i1 } %t2.pair.i, 1
  br i1 %t2.overflow.i, label %trap.i, label %sx_0.exit

trap.i:                                           ; preds = %b0.cont0
  tail call void @llvm.trap()
  unreachable

sx_0.exit:                                        ; preds = %b0.cont0
  %v5.i = extractvalue { i64, i1 } %t2.pair.i, 0
  ret i64 %v5.i

trap:                                             ; preds = %b0
  tail call void @llvm.trap()
  unreachable
}

; Function Attrs: nofree nounwind
define void @sx_2() local_unnamed_addr #4 {
b0:
  br label %sx_1.exit

sx_1.exit:                                        ; preds = %b0, %sx_1.exit
  %local1.05 = phi i64 [ 0, %b0 ], [ %v11, %sx_1.exit ]
  %local0.04 = phi i64 [ 1, %b0 ], [ %t2.pair.i.i3, %sx_1.exit ]
  %v7 = srem i64 %local0.04, 997
  %t2.pair.i.i3 = add nsw i64 %v7, 7
  %v11 = add nuw nsw i64 %local1.05, 1
  %exitcond.not = icmp eq i64 %v11, 5000
  br i1 %exitcond.not, label %b3, label %sx_1.exit

b3:                                               ; preds = %sx_1.exit
  %v14 = icmp eq i64 %t2.pair.i.i3, 106
  %t2.text = select i1 %v14, ptr @.true, ptr @.false
  %puts = tail call i32 @puts(ptr nonnull dereferenceable(1) %t2.text)
  ret void
}

; Function Attrs: nofree nounwind
define noundef i32 @main() local_unnamed_addr #4 {
entry:
  br label %sx_1.exit.i

sx_1.exit.i:                                      ; preds = %sx_1.exit.i, %entry
  %local1.05.i = phi i64 [ 0, %entry ], [ %v11.i, %sx_1.exit.i ]
  %local0.04.i = phi i64 [ 1, %entry ], [ %t2.pair.i.i3.i, %sx_1.exit.i ]
  %v7.i = srem i64 %local0.04.i, 997
  %t2.pair.i.i3.i = add nsw i64 %v7.i, 7
  %v11.i = add nuw nsw i64 %local1.05.i, 1
  %exitcond.not.i = icmp eq i64 %v11.i, 5000
  br i1 %exitcond.not.i, label %sx_2.exit, label %sx_1.exit.i

sx_2.exit:                                        ; preds = %sx_1.exit.i
  %v14.i = icmp eq i64 %t2.pair.i.i3.i, 106
  %t2.text.i = select i1 %v14.i, ptr @.true, ptr @.false
  %puts.i = tail call i32 @puts(ptr nonnull dereferenceable(1) %t2.text.i)
  ret i32 0
}

; Function Attrs: nofree nounwind
declare noundef i32 @puts(ptr noundef readonly captures(none)) local_unnamed_addr #4

attributes #0 = { cold noreturn nounwind memory(inaccessiblemem: write) }
attributes #1 = { mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nounwind memory(read, inaccessiblemem: write) }
attributes #3 = { nounwind memory(inaccessiblemem: write) }
attributes #4 = { nofree nounwind }
