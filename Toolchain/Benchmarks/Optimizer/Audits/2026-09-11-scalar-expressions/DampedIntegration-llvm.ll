; ModuleID = '.zig-cache/optimizer-oracle/DampedIntegration-raw.ll'
source_filename = ".zig-cache/optimizer-oracle/DampedIntegration-raw.ll"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

%sx.type.1 = type { float, float, float, float, float, float, float, float }
%sx.type.2 = type { ptr, i64 }
%sx.type.3 = type { ptr, i64 }
%sx.type.0 = type { float, float, float, float, float }

@.true = private constant [5 x i8] c"true\00"

; Function Attrs: cold noreturn nounwind memory(inaccessiblemem: write)
declare void @llvm.trap() #0

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite)
define void @sx_0(ptr captures(none) %v0, %sx.type.1 %v1, float %v2) local_unnamed_addr #1 {
b0:
  %v16 = extractvalue %sx.type.1 %v1, 3
  %v18 = fcmp ogt float %v16, 0.000000e+00
  %v19 = extractvalue %sx.type.1 %v1, 5
  %local0.0 = select i1 %v18, float %v19, float 0.000000e+00
  %v11 = extractvalue %sx.type.1 %v1, 7
  %v12 = fmul float %v2, %v11
  %v13 = fadd float %v12, 1.000000e+00
  %v14 = fdiv float 1.000000e+00, %v13
  %v5 = extractvalue %sx.type.1 %v1, 6
  %v6 = fmul float %v2, %v5
  %v7 = fadd float %v6, 1.000000e+00
  %v8 = fdiv float 1.000000e+00, %v7
  %v20.elt3 = getelementptr inbounds nuw i8, ptr %v0, i64 8
  %v20.unpack4 = load float, ptr %v20.elt3, align 4
  %v23 = fmul float %v2, %v16
  %v24 = extractvalue %sx.type.1 %v1, 0
  %v25 = fmul float %v24, %v23
  %v42 = extractvalue %sx.type.1 %v1, 1
  %v43 = fmul float %v42, %v23
  %v45 = fmul float %v2, %local0.0
  %v48 = fmul float %v45, 1.000000e+01
  %0 = fsub float %v43, %v48
  %v64 = extractvalue %sx.type.1 %v1, 4
  %v65 = fmul float %v2, %v64
  %v66 = extractvalue %sx.type.1 %v1, 2
  %v67 = fmul float %v66, %v65
  %v71 = fmul float %v14, %v20.unpack4
  %v72 = fadd float %v67, %v71
  %1 = load <2 x float>, ptr %v0, align 4
  %2 = insertelement <2 x float> poison, float %v8, i64 0
  %3 = shufflevector <2 x float> %2, <2 x float> poison, <2 x i32> zeroinitializer
  %4 = fmul <2 x float> %3, %1
  %5 = insertelement <2 x float> poison, float %v25, i64 0
  %6 = insertelement <2 x float> %5, float %0, i64 1
  %7 = fadd <2 x float> %6, %4
  store <2 x float> %7, ptr %v0, align 4
  store float %v72, ptr %v20.elt3, align 4
  ret void
}

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite)
define void @sx_1(ptr captures(none) %v0, float %v1) local_unnamed_addr #1 {
b0:
  %v2.elt5 = getelementptr inbounds nuw i8, ptr %v0, i64 12
  %0 = load <2 x float>, ptr %v0, align 4
  %1 = load <2 x float>, ptr %v2.elt5, align 4
  %2 = insertelement <2 x float> poison, float %v1, i64 0
  %3 = shufflevector <2 x float> %2, <2 x float> poison, <2 x i32> zeroinitializer
  %4 = fmul <2 x float> %3, %0
  %5 = fadd <2 x float> %4, %1
  store <2 x float> %5, ptr %v2.elt5, align 4
  ret void
}

; Function Attrs: nounwind memory(readwrite, inaccessiblemem: write)
define void @sx_2(%sx.type.2 %v0, %sx.type.3 %v1, float %v2) local_unnamed_addr #2 {
b0:
  %v0.fca.0.extract = extractvalue %sx.type.2 %v0, 0
  %v0.fca.1.extract = extractvalue %sx.type.2 %v0, 1
  %v735 = icmp sgt i64 %v0.fca.1.extract, 0
  br i1 %v735, label %b2.cont0.lr.ph, label %b6

b2.cont0.lr.ph:                                   ; preds = %b0
  %t1.count = extractvalue %sx.type.3 %v1, 1
  %t1.data = extractvalue %sx.type.3 %v1, 0
  %smax = tail call i64 @llvm.smax.i64(i64 %t1.count, i64 0)
  %0 = add nsw i64 %v0.fca.1.extract, -1
  %umin46 = tail call i64 @llvm.umin.i64(i64 %smax, i64 %0)
  %1 = add nuw nsw i64 %umin46, 1
  %min.iters.check = icmp samesign ult i64 %umin46, 8
  br i1 %min.iters.check, label %b2.cont0.preheader, label %vector.scevcheck

vector.scevcheck:                                 ; preds = %b2.cont0.lr.ph
  %mul = tail call { i64, i1 } @llvm.umul.with.overflow.i64(i64 %umin46, i64 20)
  %mul.result = extractvalue { i64, i1 } %mul, 0
  %mul.overflow = extractvalue { i64, i1 } %mul, 1
  %2 = getelementptr i8, ptr %v0.fca.0.extract, i64 %mul.result
  %3 = icmp ult ptr %2, %v0.fca.0.extract
  %4 = or i1 %3, %mul.overflow
  %mul.result42 = shl i64 %umin46, 5
  %mul.overflow43 = icmp samesign ugt i64 %umin46, 576460752303423487
  %5 = getelementptr i8, ptr %t1.data, i64 %mul.result42
  %6 = icmp ult ptr %5, %t1.data
  %7 = or i1 %6, %mul.overflow43
  %8 = or i1 %4, %7
  br i1 %8, label %b2.cont0.preheader, label %vector.memcheck

vector.memcheck:                                  ; preds = %vector.scevcheck
  %9 = mul nuw i64 %umin46, 20
  %10 = getelementptr i8, ptr %v0.fca.0.extract, i64 %9
  %scevgep = getelementptr i8, ptr %10, i64 12
  %scevgep45 = getelementptr i8, ptr %5, i64 32
  %bound0 = icmp ult ptr %v0.fca.0.extract, %scevgep45
  %bound1 = icmp ult ptr %t1.data, %scevgep
  %found.conflict = and i1 %bound0, %bound1
  br i1 %found.conflict, label %b2.cont0.preheader, label %vector.ph

vector.ph:                                        ; preds = %vector.memcheck
  %n.mod.vf = and i64 %1, 3
  %11 = icmp eq i64 %n.mod.vf, 0
  %12 = select i1 %11, i64 4, i64 %n.mod.vf
  %n.vec = sub nuw nsw i64 %1, %12
  %broadcast.splatinsert = insertelement <4 x float> poison, float %v2, i64 0
  %broadcast.splat = shufflevector <4 x float> %broadcast.splatinsert, <4 x float> poison, <4 x i32> zeroinitializer
  br label %vector.body

vector.body:                                      ; preds = %vector.body, %vector.ph
  %index = phi i64 [ 0, %vector.ph ], [ %index.next, %vector.body ]
  %13 = getelementptr %sx.type.0, ptr %v0.fca.0.extract, i64 %index
  %14 = getelementptr i8, ptr %13, i64 20
  %15 = getelementptr i8, ptr %13, i64 40
  %16 = getelementptr i8, ptr %13, i64 60
  %17 = getelementptr %sx.type.1, ptr %t1.data, i64 %index
  %wide.vec = load <32 x float>, ptr %17, align 4
  %strided.vec = shufflevector <32 x float> %wide.vec, <32 x float> poison, <4 x i32> <i32 0, i32 8, i32 16, i32 24>
  %strided.vec47 = shufflevector <32 x float> %wide.vec, <32 x float> poison, <4 x i32> <i32 1, i32 9, i32 17, i32 25>
  %strided.vec48 = shufflevector <32 x float> %wide.vec, <32 x float> poison, <4 x i32> <i32 2, i32 10, i32 18, i32 26>
  %strided.vec49 = shufflevector <32 x float> %wide.vec, <32 x float> poison, <4 x i32> <i32 3, i32 11, i32 19, i32 27>
  %strided.vec50 = shufflevector <32 x float> %wide.vec, <32 x float> poison, <4 x i32> <i32 4, i32 12, i32 20, i32 28>
  %strided.vec51 = shufflevector <32 x float> %wide.vec, <32 x float> poison, <4 x i32> <i32 5, i32 13, i32 21, i32 29>
  %strided.vec52 = shufflevector <32 x float> %wide.vec, <32 x float> poison, <4 x i32> <i32 6, i32 14, i32 22, i32 30>
  %strided.vec53 = shufflevector <32 x float> %wide.vec, <32 x float> poison, <4 x i32> <i32 7, i32 15, i32 23, i32 31>
  %18 = fcmp ogt <4 x float> %strided.vec49, zeroinitializer
  %19 = select <4 x i1> %18, <4 x float> %strided.vec51, <4 x float> zeroinitializer
  %20 = fmul <4 x float> %broadcast.splat, %strided.vec53
  %21 = fadd <4 x float> %20, splat (float 1.000000e+00)
  %22 = fdiv <4 x float> splat (float 1.000000e+00), %21
  %23 = fmul <4 x float> %broadcast.splat, %strided.vec52
  %24 = fadd <4 x float> %23, splat (float 1.000000e+00)
  %25 = fdiv <4 x float> splat (float 1.000000e+00), %24
  %26 = load float, ptr %13, align 4, !alias.scope !0, !noalias !3
  %27 = load float, ptr %14, align 4, !alias.scope !0, !noalias !3
  %28 = load float, ptr %15, align 4, !alias.scope !0, !noalias !3
  %29 = load float, ptr %16, align 4, !alias.scope !0, !noalias !3
  %30 = insertelement <4 x float> poison, float %26, i64 0
  %31 = insertelement <4 x float> %30, float %27, i64 1
  %32 = insertelement <4 x float> %31, float %28, i64 2
  %33 = insertelement <4 x float> %32, float %29, i64 3
  %34 = getelementptr inbounds nuw i8, ptr %13, i64 4
  %35 = getelementptr i8, ptr %13, i64 24
  %36 = getelementptr i8, ptr %13, i64 44
  %37 = getelementptr i8, ptr %13, i64 64
  %38 = load float, ptr %34, align 4, !alias.scope !0, !noalias !3
  %39 = load float, ptr %35, align 4, !alias.scope !0, !noalias !3
  %40 = load float, ptr %36, align 4, !alias.scope !0, !noalias !3
  %41 = load float, ptr %37, align 4, !alias.scope !0, !noalias !3
  %42 = insertelement <4 x float> poison, float %38, i64 0
  %43 = insertelement <4 x float> %42, float %39, i64 1
  %44 = insertelement <4 x float> %43, float %40, i64 2
  %45 = insertelement <4 x float> %44, float %41, i64 3
  %46 = getelementptr inbounds nuw i8, ptr %13, i64 8
  %47 = getelementptr i8, ptr %13, i64 28
  %48 = getelementptr i8, ptr %13, i64 48
  %49 = getelementptr i8, ptr %13, i64 68
  %50 = load float, ptr %46, align 4, !alias.scope !0, !noalias !3
  %51 = load float, ptr %47, align 4, !alias.scope !0, !noalias !3
  %52 = load float, ptr %48, align 4, !alias.scope !0, !noalias !3
  %53 = load float, ptr %49, align 4, !alias.scope !0, !noalias !3
  %54 = insertelement <4 x float> poison, float %50, i64 0
  %55 = insertelement <4 x float> %54, float %51, i64 1
  %56 = insertelement <4 x float> %55, float %52, i64 2
  %57 = insertelement <4 x float> %56, float %53, i64 3
  %58 = fmul <4 x float> %broadcast.splat, %strided.vec49
  %59 = fmul <4 x float> %strided.vec, %58
  %60 = fmul <4 x float> %33, %25
  %61 = fadd <4 x float> %59, %60
  %62 = fmul <4 x float> %strided.vec47, %58
  %63 = fmul <4 x float> %broadcast.splat, %19
  %64 = fmul <4 x float> %63, splat (float 1.000000e+01)
  %65 = fsub <4 x float> %62, %64
  %66 = fmul <4 x float> %25, %45
  %67 = fadd <4 x float> %65, %66
  %68 = fmul <4 x float> %broadcast.splat, %strided.vec50
  %69 = fmul <4 x float> %strided.vec48, %68
  %70 = fmul <4 x float> %22, %57
  %71 = fadd <4 x float> %69, %70
  %72 = extractelement <4 x float> %61, i64 0
  store float %72, ptr %13, align 4, !alias.scope !0, !noalias !3
  %73 = extractelement <4 x float> %67, i64 0
  store float %73, ptr %34, align 4, !alias.scope !0, !noalias !3
  %74 = shufflevector <4 x float> %61, <4 x float> %67, <2 x i32> <i32 1, i32 5>
  store <2 x float> %74, ptr %14, align 4, !alias.scope !0, !noalias !3
  %75 = shufflevector <4 x float> %61, <4 x float> %67, <2 x i32> <i32 2, i32 6>
  store <2 x float> %75, ptr %15, align 4, !alias.scope !0, !noalias !3
  %76 = shufflevector <4 x float> %61, <4 x float> %67, <2 x i32> <i32 3, i32 7>
  store <2 x float> %76, ptr %16, align 4, !alias.scope !0, !noalias !3
  %77 = extractelement <4 x float> %71, i64 0
  store float %77, ptr %46, align 4, !alias.scope !0, !noalias !3
  %78 = extractelement <4 x float> %71, i64 1
  store float %78, ptr %47, align 4, !alias.scope !0, !noalias !3
  %79 = extractelement <4 x float> %71, i64 2
  store float %79, ptr %48, align 4, !alias.scope !0, !noalias !3
  %80 = extractelement <4 x float> %71, i64 3
  store float %80, ptr %49, align 4, !alias.scope !0, !noalias !3
  %index.next = add nuw i64 %index, 4
  %81 = icmp eq i64 %index.next, %n.vec
  br i1 %81, label %b2.cont0.preheader, label %vector.body, !llvm.loop !5

b2.cont0.preheader:                               ; preds = %vector.body, %vector.memcheck, %vector.scevcheck, %b2.cont0.lr.ph
  %local1.036.ph = phi i64 [ 0, %vector.memcheck ], [ 0, %vector.scevcheck ], [ 0, %b2.cont0.lr.ph ], [ %n.vec, %vector.body ]
  br label %b2.cont0

b2.cont0:                                         ; preds = %b2.cont0.preheader, %b2.cont2
  %local1.036 = phi i64 [ %t3.pair33, %b2.cont2 ], [ %local1.036.ph, %b2.cont0.preheader ]
  %exitcond.not = icmp eq i64 %local1.036, %smax
  br i1 %exitcond.not, label %trap, label %b2.cont2

b2.cont2:                                         ; preds = %b2.cont0
  %t0.element = getelementptr %sx.type.0, ptr %v0.fca.0.extract, i64 %local1.036
  %t1.element = getelementptr %sx.type.1, ptr %t1.data, i64 %local1.036
  %v12.unpack = load float, ptr %t1.element, align 4
  %v12.elt16 = getelementptr inbounds nuw i8, ptr %t1.element, i64 4
  %v12.unpack17 = load float, ptr %v12.elt16, align 4
  %v12.elt18 = getelementptr inbounds nuw i8, ptr %t1.element, i64 8
  %v12.unpack19 = load float, ptr %v12.elt18, align 4
  %v12.elt20 = getelementptr inbounds nuw i8, ptr %t1.element, i64 12
  %v12.unpack21 = load float, ptr %v12.elt20, align 4
  %v12.elt22 = getelementptr inbounds nuw i8, ptr %t1.element, i64 16
  %v12.unpack23 = load float, ptr %v12.elt22, align 4
  %v12.elt24 = getelementptr inbounds nuw i8, ptr %t1.element, i64 20
  %v12.unpack25 = load float, ptr %v12.elt24, align 4
  %v12.elt26 = getelementptr inbounds nuw i8, ptr %t1.element, i64 24
  %v12.unpack27 = load float, ptr %v12.elt26, align 4
  %v12.elt28 = getelementptr inbounds nuw i8, ptr %t1.element, i64 28
  %v12.unpack29 = load float, ptr %v12.elt28, align 4
  %v18.i = fcmp ogt float %v12.unpack21, 0.000000e+00
  %local0.0.i = select i1 %v18.i, float %v12.unpack25, float 0.000000e+00
  %v12.i = fmul float %v2, %v12.unpack29
  %v13.i = fadd float %v12.i, 1.000000e+00
  %v14.i = fdiv float 1.000000e+00, %v13.i
  %v6.i = fmul float %v2, %v12.unpack27
  %v7.i = fadd float %v6.i, 1.000000e+00
  %v8.i = fdiv float 1.000000e+00, %v7.i
  %v20.elt3.i = getelementptr inbounds nuw i8, ptr %t0.element, i64 8
  %v20.unpack4.i = load float, ptr %v20.elt3.i, align 4
  %v23.i = fmul float %v2, %v12.unpack21
  %v25.i = fmul float %v12.unpack, %v23.i
  %v43.i = fmul float %v12.unpack17, %v23.i
  %v45.i = fmul float %v2, %local0.0.i
  %v48.i = fmul float %v45.i, 1.000000e+01
  %82 = fsub float %v43.i, %v48.i
  %v65.i = fmul float %v2, %v12.unpack23
  %v67.i = fmul float %v12.unpack19, %v65.i
  %v71.i = fmul float %v14.i, %v20.unpack4.i
  %v72.i = fadd float %v67.i, %v71.i
  %83 = load <2 x float>, ptr %t0.element, align 4
  %84 = insertelement <2 x float> poison, float %v8.i, i64 0
  %85 = shufflevector <2 x float> %84, <2 x float> poison, <2 x i32> zeroinitializer
  %86 = fmul <2 x float> %83, %85
  %87 = insertelement <2 x float> poison, float %v25.i, i64 0
  %88 = insertelement <2 x float> %87, float %82, i64 1
  %89 = fadd <2 x float> %88, %86
  store <2 x float> %89, ptr %t0.element, align 4
  store float %v72.i, ptr %v20.elt3.i, align 4
  %t3.pair33 = add nuw nsw i64 %local1.036, 1
  %exitcond39.not = icmp eq i64 %t3.pair33, %v0.fca.1.extract
  br i1 %exitcond39.not, label %b5.cont5.preheader, label %b2.cont0, !llvm.loop !8

b5.cont5.preheader:                               ; preds = %b2.cont2
  %90 = insertelement <2 x float> poison, float %v2, i64 0
  %91 = shufflevector <2 x float> %90, <2 x float> poison, <2 x i32> zeroinitializer
  br label %b5.cont5

b5.cont5:                                         ; preds = %b5.cont5.preheader, %b5.cont5
  %local1.138 = phi i64 [ %t6.pair34, %b5.cont5 ], [ 0, %b5.cont5.preheader ]
  %t4.element = getelementptr %sx.type.0, ptr %v0.fca.0.extract, i64 %local1.138
  %v2.elt5.i = getelementptr inbounds nuw i8, ptr %t4.element, i64 12
  %92 = load <2 x float>, ptr %t4.element, align 4
  %93 = load <2 x float>, ptr %v2.elt5.i, align 4
  %94 = fmul <2 x float> %91, %92
  %95 = fadd <2 x float> %94, %93
  store <2 x float> %95, ptr %v2.elt5.i, align 4
  %t6.pair34 = add nuw nsw i64 %local1.138, 1
  %exitcond40.not = icmp eq i64 %t6.pair34, %v0.fca.1.extract
  br i1 %exitcond40.not, label %b6, label %b5.cont5

b6:                                               ; preds = %b5.cont5, %b0
  ret void

trap:                                             ; preds = %b2.cont0
  tail call void @llvm.trap()
  unreachable
}

; Function Attrs: nofree nounwind
define void @sx_3() local_unnamed_addr #3 {
b42:
  %puts = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts74 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts93 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts103 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts122 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts132 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts151 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts161 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts192 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  ret void
}

; Function Attrs: nofree nounwind
define noundef i32 @main() local_unnamed_addr #3 {
entry:
  %puts.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts74.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts93.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts103.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts122.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts132.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts151.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts161.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  %puts192.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  ret i32 0
}

; Function Attrs: nofree nounwind
declare noundef i32 @puts(ptr noundef readonly captures(none)) local_unnamed_addr #3

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.smax.i64(i64, i64) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare i64 @llvm.umin.i64(i64, i64) #4

; Function Attrs: nocallback nofree nosync nounwind speculatable willreturn memory(none)
declare { i64, i1 } @llvm.umul.with.overflow.i64(i64, i64) #4

attributes #0 = { cold noreturn nounwind memory(inaccessiblemem: write) }
attributes #1 = { mustprogress nofree norecurse nosync nounwind willreturn memory(argmem: readwrite) }
attributes #2 = { nounwind memory(readwrite, inaccessiblemem: write) }
attributes #3 = { nofree nounwind }
attributes #4 = { nocallback nofree nosync nounwind speculatable willreturn memory(none) }

!0 = !{!1}
!1 = distinct !{!1, !2}
!2 = distinct !{!2, !"LVerDomain"}
!3 = !{!4}
!4 = distinct !{!4, !2}
!5 = distinct !{!5, !6, !7}
!6 = !{!"llvm.loop.isvectorized", i32 1}
!7 = !{!"llvm.loop.unroll.runtime.disable"}
!8 = distinct !{!8, !6}
