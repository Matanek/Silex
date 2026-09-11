; ModuleID = '.zig-cache/optimizer-oracle/Main-raw.ll'
source_filename = ".zig-cache/optimizer-oracle/Main-raw.ll"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

%sx.type.0 = type { double, double }

@.true = private constant [5 x i8] c"true\00"

; Function Attrs: cold noreturn nounwind memory(inaccessiblemem: write)
declare void @llvm.trap() #0

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i64, i1 } @llvm.sadd.with.overflow.i64(i64, i64) #1

; Function Attrs: mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i64, i1 } @llvm.smul.with.overflow.i64(i64, i64) #1

; Function Attrs: nofree nounwind
define void @sx_0() local_unnamed_addr #2 {
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
define double @sx_1(%sx.type.0 %v0, i1 %v1) local_unnamed_addr #3 {
b0:
  %v2 = extractvalue %sx.type.0 %v0, 0
  %v5 = extractvalue %sx.type.0 %v0, 1
  %v6 = fadd double %v2, %v5
  %local0.0 = select i1 %v1, double %v6, double %v2
  %v9 = fadd double %v2, %local0.0
  ret double %v9
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define double @sx_2(%sx.type.0 %v0, i1 %v1) local_unnamed_addr #3 {
b0:
  %v2 = extractvalue %sx.type.0 %v0, 0
  %v4 = fcmp olt double %v2, 0.000000e+00
  %or.cond = select i1 %v1, i1 %v4, i1 false
  %common.ret.op = select i1 %or.cond, double -1.000000e+00, double %v2
  ret double %common.ret.op
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite)
define double @sx_3(ptr readonly captures(none) %v0, ptr writeonly captures(none) initializes((0, 8)) %v1) local_unnamed_addr #4 {
b0:
  %v2.unpack = load double, ptr %v0, align 8
  store double 9.000000e+00, ptr %v1, align 8
  %v13.unpack = load double, ptr %v0, align 8
  %v16 = fadd double %v2.unpack, %v13.unpack
  ret double %v16
}

; Function Attrs: nounwind memory(inaccessiblemem: write)
define i64 @sx_4(i64 %v0, i64 %v1, i1 %v2) local_unnamed_addr #5 {
b0:
  %t0.pair = tail call { i64, i1 } @llvm.smul.with.overflow.i64(i64 %v0, i64 %v1)
  %v3 = extractvalue { i64, i1 } %t0.pair, 0
  %t0.overflow = extractvalue { i64, i1 } %t0.pair, 1
  br i1 %t0.overflow, label %trap, label %b0.cont0

b0.cont0:                                         ; preds = %b0
  br i1 %v2, label %b1, label %b3.cont2

b1:                                               ; preds = %b0.cont0
  %t1.pair = tail call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %v3, i64 %v0)
  %t1.overflow = extractvalue { i64, i1 } %t1.pair, 1
  br i1 %t1.overflow, label %trap, label %b1.cont1

b1.cont1:                                         ; preds = %b1
  %v5 = extractvalue { i64, i1 } %t1.pair, 0
  br label %b3.cont2

b3.cont2:                                         ; preds = %b1.cont1, %b0.cont0
  %local0.0 = phi i64 [ %v5, %b1.cont1 ], [ %v3, %b0.cont0 ]
  %t3.pair = tail call { i64, i1 } @llvm.sadd.with.overflow.i64(i64 %local0.0, i64 %v3)
  %t3.overflow = extractvalue { i64, i1 } %t3.pair, 1
  br i1 %t3.overflow, label %trap, label %b3.cont3

b3.cont3:                                         ; preds = %b3.cont2
  %v8 = extractvalue { i64, i1 } %t3.pair, 0
  ret i64 %v8

trap:                                             ; preds = %b3.cont2, %b1, %b0
  tail call void @llvm.trap()
  unreachable
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define double @sx_5(double %v0, double %v1, i1 %v2) local_unnamed_addr #3 {
b0:
  %v3 = fmul double %v0, %v1
  %v5 = fadd double %v0, %v3
  %spec.select = select i1 %v2, double %v5, double %v3
  %v8 = fadd double %v3, %spec.select
  ret double %v8
}

; Function Attrs: nofree nounwind
define noundef i32 @main() local_unnamed_addr #2 {
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
declare noundef i32 @puts(ptr noundef readonly captures(none)) local_unnamed_addr #2

attributes #0 = { cold noreturn nounwind memory(inaccessiblemem: write) }
attributes #1 = { mustprogress nocallback nofree nosync nounwind speculatable willreturn memory(none) }
attributes #2 = { nofree nounwind }
attributes #3 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) }
attributes #4 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite) }
attributes #5 = { nounwind memory(inaccessiblemem: write) }
