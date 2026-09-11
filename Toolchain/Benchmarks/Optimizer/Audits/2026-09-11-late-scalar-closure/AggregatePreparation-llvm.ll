; ModuleID = '.zig-cache/optimizer-oracle/AggregatePreparation-raw.ll'
source_filename = ".zig-cache/optimizer-oracle/AggregatePreparation-raw.ll"
target datalayout = "e-m:o-p270:32:32-p271:32:32-p272:64:64-i64:64-i128:128-n32:64-S128-Fn32"
target triple = "arm64-apple-macosx26.0.0"

%sx.type.1 = type { float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float }
%sx.type.0 = type { float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float, float }

@.true = private constant [5 x i8] c"true\00"
@.false = private constant [6 x i8] c"false\00"

; Function Attrs: mustprogress nofree norecurse nosync nounwind willreturn memory(none)
define %sx.type.1 @sx_0(%sx.type.0 %v0, i1 %v1) local_unnamed_addr #0 {
b0:
  %spec.select = select i1 %v1, float 1.000000e+00, float 0.000000e+00
  %v34 = extractvalue %sx.type.0 %v0, 8
  %v35 = extractvalue %sx.type.0 %v0, 6
  %v37 = extractvalue %sx.type.0 %v0, 4
  %v39 = extractvalue %sx.type.0 %v0, 9
  %v40 = extractvalue %sx.type.0 %v0, 7
  %v42 = extractvalue %sx.type.0 %v0, 5
  %v88 = extractvalue %sx.type.0 %v0, 0
  %v89 = extractvalue %sx.type.0 %v0, 1
  %v90 = fadd float %v88, %v89
  %v91 = extractvalue %sx.type.0 %v0, 2
  %v95 = extractvalue %sx.type.0 %v0, 3
  %v135 = fneg float %v37
  %0 = insertelement <2 x float> poison, float %v35, i64 0
  %1 = shufflevector <2 x float> %0, <2 x float> poison, <2 x i32> zeroinitializer
  %2 = insertelement <2 x float> poison, float %v135, i64 0
  %3 = insertelement <2 x float> %2, float %v42, i64 1
  %4 = fmul <2 x float> %1, %3
  %5 = insertelement <2 x float> poison, float %v40, i64 0
  %6 = shufflevector <2 x float> %5, <2 x float> poison, <2 x i32> zeroinitializer
  %7 = insertelement <2 x float> poison, float %v42, i64 0
  %8 = insertelement <2 x float> %7, float %v37, i64 1
  %9 = fmul <2 x float> %6, %8
  %10 = fsub <2 x float> %4, %9
  %11 = insertelement <2 x float> poison, float %v34, i64 0
  %12 = shufflevector <2 x float> %11, <2 x float> poison, <2 x i32> zeroinitializer
  %13 = fmul <2 x float> %12, %3
  %14 = insertelement <2 x float> poison, float %v39, i64 0
  %15 = shufflevector <2 x float> %14, <2 x float> poison, <2 x i32> zeroinitializer
  %16 = fmul <2 x float> %15, %8
  %17 = fsub <2 x float> %13, %16
  %18 = insertelement <2 x float> poison, float %v91, i64 0
  %19 = shufflevector <2 x float> %18, <2 x float> poison, <2 x i32> zeroinitializer
  %20 = fmul <2 x float> %19, %10
  %21 = fmul <2 x float> %10, %20
  %22 = insertelement <2 x float> poison, float %v90, i64 0
  %23 = shufflevector <2 x float> %22, <2 x float> poison, <2 x i32> zeroinitializer
  %24 = fadd <2 x float> %23, %21
  %25 = insertelement <2 x float> poison, float %v95, i64 0
  %26 = shufflevector <2 x float> %25, <2 x float> poison, <2 x i32> zeroinitializer
  %27 = fmul <2 x float> %26, %17
  %28 = fmul <2 x float> %17, %27
  %29 = fadd <2 x float> %28, %24
  %30 = extractelement <2 x float> %29, i64 1
  %v104 = fdiv float 1.000000e+00, %30
  %31 = fcmp ogt <2 x float> %29, zeroinitializer
  %32 = extractelement <2 x i1> %31, i64 1
  %local0.sroa.86.0 = select i1 %32, float %v104, float 0.000000e+00
  %33 = extractelement <2 x float> %29, i64 0
  %v162 = fdiv float 1.000000e+00, %33
  %34 = extractelement <2 x i1> %31, i64 0
  %local0.sroa.172.1 = select i1 %34, float %v162, float 0.000000e+00
  %v193 = fadd float %v91, %v95
  %v195 = fcmp ogt float %v193, 0.000000e+00
  %v199 = fdiv float 1.000000e+00, %v193
  %local0.sroa.344.2 = select i1 %v195, float %v199, float 0.000000e+00
  %v228 = extractvalue %sx.type.0 %v0, 11
  %v230 = extractvalue %sx.type.0 %v0, 12
  %v232 = extractvalue %sx.type.0 %v0, 13
  %v234 = extractvalue %sx.type.0 %v0, 14
  %v236 = extractvalue %sx.type.0 %v0, 15
  %v238 = extractvalue %sx.type.0 %v0, 16
  %v242 = fcmp oeq float %v88, 0.000000e+00
  %local2.0 = select i1 %v242, float 0.000000e+00, float %v228
  %local3.0 = select i1 %v242, float 0.000000e+00, float %v230
  %local4.0 = select i1 %v242, float 0.000000e+00, float %v232
  %v248 = fcmp oeq float %v89, 0.000000e+00
  %local5.0 = select i1 %v248, float 0.000000e+00, float %v234
  %local6.0 = select i1 %v248, float 0.000000e+00, float %v236
  %local7.0 = select i1 %v248, float 0.000000e+00, float %v238
  %local8.0 = select i1 %v242, i1 true, i1 %v248
  %local0.sroa.1204.3 = select i1 %local8.0, float 1.250000e-01, float 2.500000e-01
  %local0.sroa.1118.3 = select i1 %local8.0, float 8.750000e-01, float 7.500000e-01
  %local0.sroa.1032.3 = select i1 %local8.0, float 2.400000e+01, float 1.200000e+01
  %v33 = extractvalue %sx.type.0 %v0, 10
  %v36 = fsub float %v34, %v35
  %v38 = fmul float %v37, %v36
  %v41 = fsub float %v39, %v40
  %v43 = fmul float %v42, %v41
  %v44 = fadd float %v38, %v43
  %v45 = fsub float %v33, %v44
  %t1.aggregate0 = insertvalue %sx.type.1 poison, float %v45, 0
  %v252.fca.1.insert = insertvalue %sx.type.1 %t1.aggregate0, float %local0.sroa.86.0, 1
  %v252.fca.2.insert = insertvalue %sx.type.1 %v252.fca.1.insert, float %local0.sroa.172.1, 2
  %v258 = fmul float %v39, %local7.0
  %v259 = fsub float %local5.0, %v258
  %v263 = fmul float %v40, %local4.0
  %v264 = fsub float %local2.0, %v263
  %v265 = fsub float %v259, %v264
  %v266 = fmul float %v37, %v265
  %v271 = fmul float %v34, %local7.0
  %v272 = fadd float %local6.0, %v271
  %v276 = fmul float %v35, %local4.0
  %v277 = fadd float %local3.0, %v276
  %v278 = fsub float %v272, %v277
  %v279 = fmul float %v42, %v278
  %v280 = fadd float %v266, %v279
  %t5.aggregate3 = insertvalue %sx.type.1 %v252.fca.2.insert, float %v280, 3
  %t5.aggregate4 = insertvalue %sx.type.1 %t5.aggregate3, float %local0.sroa.344.2, 4
  %v312 = extractvalue %sx.type.0 %v0, 17
  %v313 = fmul float %v312, %spec.select
  %t6.aggregate5 = insertvalue %sx.type.1 %t5.aggregate4, float %v313, 5
  %v345 = extractvalue %sx.type.0 %v0, 18
  %v346 = fmul float %v345, %spec.select
  %t7.aggregate6 = insertvalue %sx.type.1 %t6.aggregate5, float %v346, 6
  %v378 = extractvalue %sx.type.0 %v0, 19
  %v379 = fmul float %v378, %spec.select
  %t8.aggregate7 = insertvalue %sx.type.1 %t7.aggregate6, float %v379, 7
  %v603 = extractvalue %sx.type.0 %v0, 20
  %t15.aggregate8 = insertvalue %sx.type.1 %t8.aggregate7, float %v603, 8
  %v634 = extractvalue %sx.type.0 %v0, 21
  %t16.aggregate9 = insertvalue %sx.type.1 %t15.aggregate8, float %v634, 9
  %v665 = extractvalue %sx.type.0 %v0, 22
  %t17.aggregate10 = insertvalue %sx.type.1 %t16.aggregate9, float %v665, 10
  %v696 = extractvalue %sx.type.0 %v0, 23
  %t18.aggregate11 = insertvalue %sx.type.1 %t17.aggregate10, float %v696, 11
  %t18.aggregate12 = insertvalue %sx.type.1 %t18.aggregate11, float %local0.sroa.1032.3, 12
  %t18.aggregate13 = insertvalue %sx.type.1 %t18.aggregate12, float %local0.sroa.1118.3, 13
  %t18.aggregate14 = insertvalue %sx.type.1 %t18.aggregate13, float %local0.sroa.1204.3, 14
  %t19.aggregate15 = insertvalue %sx.type.1 %t18.aggregate14, float %v37, 15
  %t20.aggregate16 = insertvalue %sx.type.1 %t19.aggregate15, float %v42, 16
  %t21.aggregate17 = insertvalue %sx.type.1 %t20.aggregate16, float %v35, 17
  %t22.aggregate18 = insertvalue %sx.type.1 %t21.aggregate17, float %v40, 18
  %t23.aggregate19 = insertvalue %sx.type.1 %t22.aggregate18, float %v34, 19
  %t24.aggregate20 = insertvalue %sx.type.1 %t23.aggregate19, float %v39, 20
  %t25.aggregate21 = insertvalue %sx.type.1 %t24.aggregate20, float %v88, 21
  %t26.aggregate22 = insertvalue %sx.type.1 %t25.aggregate21, float %v89, 22
  %t27.aggregate23 = insertvalue %sx.type.1 %t26.aggregate22, float %v91, 23
  %t28.aggregate24 = insertvalue %sx.type.1 %t27.aggregate23, float %v95, 24
  %v1034 = insertvalue %sx.type.1 %t28.aggregate24, float 0.000000e+00, 25
  ret %sx.type.1 %v1034
}

; Function Attrs: nofree nounwind
define void @sx_1(%sx.type.1 %v0, %sx.type.1 %v1) local_unnamed_addr #1 {
b0:
  %v0.fca.0.extract = extractvalue %sx.type.1 %v0, 0
  %v0.fca.1.extract = extractvalue %sx.type.1 %v0, 1
  %v0.fca.2.extract = extractvalue %sx.type.1 %v0, 2
  %v0.fca.3.extract = extractvalue %sx.type.1 %v0, 3
  %v0.fca.4.extract = extractvalue %sx.type.1 %v0, 4
  %v0.fca.5.extract = extractvalue %sx.type.1 %v0, 5
  %v0.fca.6.extract = extractvalue %sx.type.1 %v0, 6
  %v0.fca.7.extract = extractvalue %sx.type.1 %v0, 7
  %v0.fca.8.extract = extractvalue %sx.type.1 %v0, 8
  %v0.fca.9.extract = extractvalue %sx.type.1 %v0, 9
  %v0.fca.10.extract = extractvalue %sx.type.1 %v0, 10
  %v0.fca.11.extract = extractvalue %sx.type.1 %v0, 11
  %v0.fca.12.extract = extractvalue %sx.type.1 %v0, 12
  %v0.fca.13.extract = extractvalue %sx.type.1 %v0, 13
  %v0.fca.14.extract = extractvalue %sx.type.1 %v0, 14
  %v0.fca.15.extract = extractvalue %sx.type.1 %v0, 15
  %v0.fca.16.extract = extractvalue %sx.type.1 %v0, 16
  %v0.fca.17.extract = extractvalue %sx.type.1 %v0, 17
  %v0.fca.18.extract = extractvalue %sx.type.1 %v0, 18
  %v0.fca.19.extract = extractvalue %sx.type.1 %v0, 19
  %v0.fca.20.extract = extractvalue %sx.type.1 %v0, 20
  %v0.fca.21.extract = extractvalue %sx.type.1 %v0, 21
  %v0.fca.22.extract = extractvalue %sx.type.1 %v0, 22
  %v0.fca.23.extract = extractvalue %sx.type.1 %v0, 23
  %v0.fca.24.extract = extractvalue %sx.type.1 %v0, 24
  %v0.fca.25.extract = extractvalue %sx.type.1 %v0, 25
  %v1.fca.0.extract = extractvalue %sx.type.1 %v1, 0
  %v1.fca.1.extract = extractvalue %sx.type.1 %v1, 1
  %v1.fca.2.extract = extractvalue %sx.type.1 %v1, 2
  %v1.fca.3.extract = extractvalue %sx.type.1 %v1, 3
  %v1.fca.4.extract = extractvalue %sx.type.1 %v1, 4
  %v1.fca.5.extract = extractvalue %sx.type.1 %v1, 5
  %v1.fca.6.extract = extractvalue %sx.type.1 %v1, 6
  %v1.fca.7.extract = extractvalue %sx.type.1 %v1, 7
  %v1.fca.8.extract = extractvalue %sx.type.1 %v1, 8
  %v1.fca.9.extract = extractvalue %sx.type.1 %v1, 9
  %v1.fca.10.extract = extractvalue %sx.type.1 %v1, 10
  %v1.fca.11.extract = extractvalue %sx.type.1 %v1, 11
  %v1.fca.12.extract = extractvalue %sx.type.1 %v1, 12
  %v1.fca.13.extract = extractvalue %sx.type.1 %v1, 13
  %v1.fca.14.extract = extractvalue %sx.type.1 %v1, 14
  %v1.fca.15.extract = extractvalue %sx.type.1 %v1, 15
  %v1.fca.16.extract = extractvalue %sx.type.1 %v1, 16
  %v1.fca.17.extract = extractvalue %sx.type.1 %v1, 17
  %v1.fca.18.extract = extractvalue %sx.type.1 %v1, 18
  %v1.fca.19.extract = extractvalue %sx.type.1 %v1, 19
  %v1.fca.20.extract = extractvalue %sx.type.1 %v1, 20
  %v1.fca.21.extract = extractvalue %sx.type.1 %v1, 21
  %v1.fca.22.extract = extractvalue %sx.type.1 %v1, 22
  %v1.fca.23.extract = extractvalue %sx.type.1 %v1, 23
  %v1.fca.24.extract = extractvalue %sx.type.1 %v1, 24
  %v1.fca.25.extract = extractvalue %sx.type.1 %v1, 25
  %v6 = fcmp oeq float %v0.fca.0.extract, %v1.fca.0.extract
  %t0.text = select i1 %v6, ptr @.true, ptr @.false
  %puts = tail call i32 @puts(ptr nonnull dereferenceable(1) %t0.text)
  %v11 = fcmp oeq float %v0.fca.1.extract, %v1.fca.1.extract
  %t1.text = select i1 %v11, ptr @.true, ptr @.false
  %puts1 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t1.text)
  %v16 = fcmp oeq float %v0.fca.2.extract, %v1.fca.2.extract
  %t2.text = select i1 %v16, ptr @.true, ptr @.false
  %puts2 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t2.text)
  %v21 = fcmp oeq float %v0.fca.3.extract, %v1.fca.3.extract
  %t3.text = select i1 %v21, ptr @.true, ptr @.false
  %puts3 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t3.text)
  %v26 = fcmp oeq float %v0.fca.4.extract, %v1.fca.4.extract
  %t4.text = select i1 %v26, ptr @.true, ptr @.false
  %puts4 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t4.text)
  %v31 = fcmp oeq float %v0.fca.5.extract, %v1.fca.5.extract
  %t5.text = select i1 %v31, ptr @.true, ptr @.false
  %puts5 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t5.text)
  %v36 = fcmp oeq float %v0.fca.6.extract, %v1.fca.6.extract
  %t6.text = select i1 %v36, ptr @.true, ptr @.false
  %puts6 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t6.text)
  %v41 = fcmp oeq float %v0.fca.7.extract, %v1.fca.7.extract
  %t7.text = select i1 %v41, ptr @.true, ptr @.false
  %puts7 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t7.text)
  %v46 = fcmp oeq float %v0.fca.8.extract, %v1.fca.8.extract
  %t8.text = select i1 %v46, ptr @.true, ptr @.false
  %puts8 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t8.text)
  %v51 = fcmp oeq float %v0.fca.9.extract, %v1.fca.9.extract
  %t9.text = select i1 %v51, ptr @.true, ptr @.false
  %puts9 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t9.text)
  %v56 = fcmp oeq float %v0.fca.10.extract, %v1.fca.10.extract
  %t10.text = select i1 %v56, ptr @.true, ptr @.false
  %puts10 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t10.text)
  %v61 = fcmp oeq float %v0.fca.11.extract, %v1.fca.11.extract
  %t11.text = select i1 %v61, ptr @.true, ptr @.false
  %puts11 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t11.text)
  %v66 = fcmp oeq float %v0.fca.12.extract, %v1.fca.12.extract
  %t12.text = select i1 %v66, ptr @.true, ptr @.false
  %puts12 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t12.text)
  %v71 = fcmp oeq float %v0.fca.13.extract, %v1.fca.13.extract
  %t13.text = select i1 %v71, ptr @.true, ptr @.false
  %puts13 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t13.text)
  %v76 = fcmp oeq float %v0.fca.14.extract, %v1.fca.14.extract
  %t14.text = select i1 %v76, ptr @.true, ptr @.false
  %puts14 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t14.text)
  %v81 = fcmp oeq float %v0.fca.15.extract, %v1.fca.15.extract
  %t15.text = select i1 %v81, ptr @.true, ptr @.false
  %puts15 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t15.text)
  %v86 = fcmp oeq float %v0.fca.16.extract, %v1.fca.16.extract
  %t16.text = select i1 %v86, ptr @.true, ptr @.false
  %puts16 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t16.text)
  %v91 = fcmp oeq float %v0.fca.17.extract, %v1.fca.17.extract
  %t17.text = select i1 %v91, ptr @.true, ptr @.false
  %puts17 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t17.text)
  %v96 = fcmp oeq float %v0.fca.18.extract, %v1.fca.18.extract
  %t18.text = select i1 %v96, ptr @.true, ptr @.false
  %puts18 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t18.text)
  %v101 = fcmp oeq float %v0.fca.19.extract, %v1.fca.19.extract
  %t19.text = select i1 %v101, ptr @.true, ptr @.false
  %puts19 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t19.text)
  %v106 = fcmp oeq float %v0.fca.20.extract, %v1.fca.20.extract
  %t20.text = select i1 %v106, ptr @.true, ptr @.false
  %puts20 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t20.text)
  %v111 = fcmp oeq float %v0.fca.21.extract, %v1.fca.21.extract
  %t21.text = select i1 %v111, ptr @.true, ptr @.false
  %puts21 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t21.text)
  %v116 = fcmp oeq float %v0.fca.22.extract, %v1.fca.22.extract
  %t22.text = select i1 %v116, ptr @.true, ptr @.false
  %puts22 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t22.text)
  %v121 = fcmp oeq float %v0.fca.23.extract, %v1.fca.23.extract
  %t23.text = select i1 %v121, ptr @.true, ptr @.false
  %puts23 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t23.text)
  %v126 = fcmp oeq float %v0.fca.24.extract, %v1.fca.24.extract
  %t24.text = select i1 %v126, ptr @.true, ptr @.false
  %puts24 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t24.text)
  %v131 = fcmp oeq float %v0.fca.25.extract, %v1.fca.25.extract
  %t25.text = select i1 %v131, ptr @.true, ptr @.false
  %puts25 = tail call i32 @puts(ptr nonnull dereferenceable(1) %t25.text)
  ret void
}

; Function Attrs: nofree nounwind
define void @sx_2() local_unnamed_addr #1 {
b0:
  tail call void @sx_1(%sx.type.1 { float 2.500000e-01, float 2.500000e-01, float 5.000000e-01, float 2.750000e+00, float 5.000000e-01, float 2.000000e+00, float -1.000000e+00, float 5.000000e-01, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 1.200000e+01, float 7.500000e-01, float 2.500000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00 }, %sx.type.1 { float 2.500000e-01, float 2.500000e-01, float 5.000000e-01, float 2.750000e+00, float 5.000000e-01, float 2.000000e+00, float -1.000000e+00, float 5.000000e-01, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 1.200000e+01, float 7.500000e-01, float 2.500000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00 })
  tail call void @sx_1(%sx.type.1 { float 2.500000e-01, float 2.500000e-01, float 5.000000e-01, float 2.750000e+00, float 5.000000e-01, float 0.000000e+00, float -0.000000e+00, float 0.000000e+00, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 1.200000e+01, float 7.500000e-01, float 2.500000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00 }, %sx.type.1 { float 2.500000e-01, float 2.500000e-01, float 5.000000e-01, float 2.750000e+00, float 5.000000e-01, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 1.200000e+01, float 7.500000e-01, float 2.500000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00 })
  %puts = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  tail call void @sx_1(%sx.type.1 { float 2.500000e-01, float 5.000000e-01, float 1.000000e+00, float 5.250000e+00, float 1.000000e+00, float 2.000000e+00, float -1.000000e+00, float 5.000000e-01, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00 }, %sx.type.1 { float 2.500000e-01, float 5.000000e-01, float 1.000000e+00, float 5.250000e+00, float 1.000000e+00, float 2.000000e+00, float -1.000000e+00, float 5.000000e-01, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00 })
  tail call void @sx_1(%sx.type.1 { float 2.500000e-01, float 5.000000e-01, float 1.000000e+00, float 5.250000e+00, float 1.000000e+00, float 0.000000e+00, float -0.000000e+00, float 0.000000e+00, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00 }, %sx.type.1 { float 2.500000e-01, float 5.000000e-01, float 1.000000e+00, float 5.250000e+00, float 1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00 })
  %puts1 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  tail call void @sx_1(%sx.type.1 { float 2.500000e-01, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 2.000000e+00, float -1.000000e+00, float 5.000000e-01, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00 }, %sx.type.1 { float 2.500000e-01, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 2.000000e+00, float -1.000000e+00, float 5.000000e-01, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00 })
  tail call void @sx_1(%sx.type.1 { float 2.500000e-01, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float -0.000000e+00, float 0.000000e+00, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00 }, %sx.type.1 { float 2.500000e-01, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00 })
  %puts2 = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  ret void
}

; Function Attrs: nofree nounwind
define noundef i32 @main() local_unnamed_addr #1 {
entry:
  tail call void @sx_1(%sx.type.1 { float 2.500000e-01, float 2.500000e-01, float 5.000000e-01, float 2.750000e+00, float 5.000000e-01, float 2.000000e+00, float -1.000000e+00, float 5.000000e-01, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 1.200000e+01, float 7.500000e-01, float 2.500000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00 }, %sx.type.1 { float 2.500000e-01, float 2.500000e-01, float 5.000000e-01, float 2.750000e+00, float 5.000000e-01, float 2.000000e+00, float -1.000000e+00, float 5.000000e-01, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 1.200000e+01, float 7.500000e-01, float 2.500000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00 })
  tail call void @sx_1(%sx.type.1 { float 2.500000e-01, float 2.500000e-01, float 5.000000e-01, float 2.750000e+00, float 5.000000e-01, float 0.000000e+00, float -0.000000e+00, float 0.000000e+00, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 1.200000e+01, float 7.500000e-01, float 2.500000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00 }, %sx.type.1 { float 2.500000e-01, float 2.500000e-01, float 5.000000e-01, float 2.750000e+00, float 5.000000e-01, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 1.200000e+01, float 7.500000e-01, float 2.500000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00 })
  %puts.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  tail call void @sx_1(%sx.type.1 { float 2.500000e-01, float 5.000000e-01, float 1.000000e+00, float 5.250000e+00, float 1.000000e+00, float 2.000000e+00, float -1.000000e+00, float 5.000000e-01, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00 }, %sx.type.1 { float 2.500000e-01, float 5.000000e-01, float 1.000000e+00, float 5.250000e+00, float 1.000000e+00, float 2.000000e+00, float -1.000000e+00, float 5.000000e-01, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00 })
  tail call void @sx_1(%sx.type.1 { float 2.500000e-01, float 5.000000e-01, float 1.000000e+00, float 5.250000e+00, float 1.000000e+00, float 0.000000e+00, float -0.000000e+00, float 0.000000e+00, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00 }, %sx.type.1 { float 2.500000e-01, float 5.000000e-01, float 1.000000e+00, float 5.250000e+00, float 1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00, float 1.000000e+00, float 0.000000e+00 })
  %puts1.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  tail call void @sx_1(%sx.type.1 { float 2.500000e-01, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 2.000000e+00, float -1.000000e+00, float 5.000000e-01, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00 }, %sx.type.1 { float 2.500000e-01, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 2.000000e+00, float -1.000000e+00, float 5.000000e-01, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00 })
  tail call void @sx_1(%sx.type.1 { float 2.500000e-01, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float -0.000000e+00, float 0.000000e+00, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00 }, %sx.type.1 { float 2.500000e-01, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 7.500000e-01, float 2.500000e-01, float -5.000000e-01, float 1.250000e-01, float 2.400000e+01, float 8.750000e-01, float 1.250000e-01, float 0.000000e+00, float 1.000000e+00, float 1.000000e+00, float 0.000000e+00, float -1.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00, float 0.000000e+00 })
  %puts2.i = tail call i32 @puts(ptr nonnull dereferenceable(1) @.true)
  ret i32 0
}

; Function Attrs: nofree nounwind
declare noundef i32 @puts(ptr noundef readonly captures(none)) local_unnamed_addr #1

attributes #0 = { mustprogress nofree norecurse nosync nounwind willreturn memory(none) }
attributes #1 = { nofree nounwind }
