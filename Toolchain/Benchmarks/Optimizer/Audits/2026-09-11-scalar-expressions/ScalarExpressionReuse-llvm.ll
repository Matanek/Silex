; ModuleID = '.zig-cache/optimizer-oracle/ScalarExpressionReuse-raw.ll'
source_filename = ".zig-cache/optimizer-oracle/ScalarExpressionReuse-raw.ll"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

@.true = private constant [5 x i8] c"true\00"

; Function Attrs: cold noreturn nounwind memory(inaccessiblemem: write)
declare void @llvm.trap() #0

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i64, i1 } @llvm.sadd.with.overflow.i64(i64, i64) #1

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define double @sx_0(double %v0, double %v1) local_unnamed_addr #2 {
b0:
  %v2 = fmul double %v0, %v1
  ret double %v2
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define double @sx_1(double %v0, double %v1) local_unnamed_addr #2 {
b0:
  %v2 = fmul double %v0, %v1
  %v4 = fadd double %v2, %v2
  ret double %v4
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define double @sx_2(double %v0, double %v1) local_unnamed_addr #2 {
b0:
  %v2.i = fmul double %v0, %v1
  %v4 = fadd double %v2.i, %v2.i
  ret double %v4
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: write)
define void @sx_3(ptr writeonly captures(none) initializes((0, 16)) %v0, double %v1, double %v2) local_unnamed_addr #3 {
b0:
  %v5 = fmul double %v1, %v2
  store double %v5, ptr %v0, align 8
  %v0.repack1 = getelementptr inbounds nuw i8, ptr %v0, i64 8
  store double %v5, ptr %v0.repack1, align 8
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite)
define void @sx_4(ptr captures(none) initializes((8, 16)) %v0, double %v1) local_unnamed_addr #4 {
b0:
  %v2.unpack = load double, ptr %v0, align 8
  %v7 = fmul double %v1, %v2.unpack
  %v17 = fmul double %v1, %v7
  store double %v7, ptr %v0, align 8
  %v0.repack4 = getelementptr inbounds nuw i8, ptr %v0, i64 8
  store double %v17, ptr %v0.repack4, align 8
  ret void
}

; Function Attrs: nounwind memory(inaccessiblemem: write)
define i64 @sx_5(i64 %v0, i64 %v1) local_unnamed_addr #5 {
b0:
  %t0.zero = icmp eq i64 %v1, 0
  %t0.minimum = icmp eq i64 %v0, -9223372036854775808
  %t0.minusone = icmp eq i64 %v1, -1
  %t0.overflow = and i1 %t0.minimum, %t0.minusone
  %t0.invalid = or i1 %t0.zero, %t0.overflow
  br i1 %t0.invalid, label %trap, label %b0.cont1

b0.cont1:                                         ; preds = %b0
  %v2 = sdiv i64 %v0, %v1
  %t2.pair = tail call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %v2, i64 %v2)
  %t2.overflow = extractvalue { i64, i1 } %t2.pair, 1
  br i1 %t2.overflow, label %trap, label %b0.cont2

b0.cont2:                                         ; preds = %b0.cont1
  %v4 = extractvalue { i64, i1 } %t2.pair, 0
  ret i64 %v4

trap:                                             ; preds = %b0.cont1, %b0
  tail call void @llvm.trap()
  unreachable
}

; Function Attrs: nofree nounwind
define void @sx_6() local_unnamed_addr #6 {
b0:
  %puts = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts1 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts2 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts3 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts4 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts5 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts6 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts7 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define double @sx_7(double %v0, double %v1) local_unnamed_addr #2 {
b0:
  %v2 = fmul double %v0, %v1
  %v4 = fadd double %v2, %v2
  ret double %v4
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
  %puts7.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  ret i32 0
}

; Function Attrs: nofree nounwind
declare noundef i32 @puts(ptr noundef readonly captures(none)) local_unnamed_addr #6

attributes #0 = { cold noreturn nounwind memory(inaccessiblemem: write) }
attributes #1 = { mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) }
attributes #3 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: write) }
attributes #4 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite) }
attributes #5 = { nounwind memory(inaccessiblemem: write) }
attributes #6 = { nofree nounwind }
