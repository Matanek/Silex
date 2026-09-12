
/private/tmp/silex-part03-evidence/flocking-x64-floats:	file format mach-o 64-bit x86-64

Disassembly of section __TEXT,__text:

0000000100001000 <__text>:
100001000: 55                          	pushq	%rbp
100001001: 48 89 e5                    	movq	%rsp, %rbp
100001004: 48 81 ec 50 01 00 00        	subq	$0x150, %rsp            ## imm = 0x150
10000100b: 48 89 e5                    	movq	%rsp, %rbp
10000100e: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
100001015: 48 be 28 00 00 00 00 00 00 00       	movabsq	$0x28, %rsi
10000101f: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
100001029: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001033: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
10000103d: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
100001047: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
100001051: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
10000105b: 0f 05                       	syscall
10000105d: 0f 83 0f 00 00 00           	jae	0x100001072 <__text+0x72>
100001063: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000106d: e9 a3 08 00 00              	jmp	0x100001915 <__text+0x915>
100001072: 49 89 c2                    	movq	%rax, %r10
100001075: 49 bc 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r12
10000107f: 4d 89 a2 00 00 00 00        	movq	%r12, (%r10)
100001086: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001090: 49 89 82 08 00 00 00        	movq	%rax, 0x8(%r10)
100001097: 49 89 82 10 00 00 00        	movq	%rax, 0x10(%r10)
10000109e: 49 89 82 20 00 00 00        	movq	%rax, 0x20(%r10)
1000010a5: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000010af: 49 89 82 08 00 00 00        	movq	%rax, 0x8(%r10)
1000010b6: 49 89 b2 18 00 00 00        	movq	%rsi, 0x18(%r10)
1000010bd: 4c 89 95 08 00 00 00        	movq	%r10, 0x8(%rbp)
1000010c4: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
1000010cb: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
1000010d2: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000010dc: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
1000010e3: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
1000010ed: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
1000010f4: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
1000010fb: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100001102: 48 39 c8                    	cmpq	%rcx, %rax
100001105: 0f 9c c0                    	setl	%al
100001108: 48 0f b6 c0                 	movzbq	%al, %rax
10000110c: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100001113: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
10000111a: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100001121: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100001128: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
10000112f: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100001136: 48 85 c0                    	testq	%rax, %rax
100001139: 0f 85 05 00 00 00           	jne	0x100001144 <__text+0x144>
10000113f: e9 2d 00 00 00              	jmp	0x100001171 <__text+0x171>
100001144: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000114e: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100001155: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
10000115c: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100001163: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
10000116a: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100001171: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100001178: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
10000117f: 48 39 c8                    	cmpq	%rcx, %rax
100001182: 0f 95 c0                    	setne	%al
100001185: 48 0f b6 c0                 	movzbq	%al, %rax
100001189: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100001190: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001197: 48 85 c0                    	testq	%rax, %rax
10000119a: 0f 85 05 00 00 00           	jne	0x1000011a5 <__text+0x1a5>
1000011a0: e9 9a 06 00 00              	jmp	0x10000183f <__text+0x83f>
1000011a5: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
1000011ac: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000011b3: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000011ba: 48 b9 e9 a8 c0 17 57 3f e8 a8       	movabsq	$-0x5717c0a8e83f5717, %rcx ## imm = 0xA8E83F5717C0A8E9
1000011c4: 48 f7 e9                    	imulq	%rcx
1000011c7: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
1000011ce: 48 01 ca                    	addq	%rcx, %rdx
1000011d1: 48 c1 fa 06                 	sarq	$0x6, %rdx
1000011d5: 48 89 d0                    	movq	%rdx, %rax
1000011d8: 48 c1 e8 3f                 	shrq	$0x3f, %rax
1000011dc: 48 01 c2                    	addq	%rax, %rdx
1000011df: 48 b8 61 00 00 00 00 00 00 00       	movabsq	$0x61, %rax
1000011e9: 48 0f af d0                 	imulq	%rax, %rdx
1000011ed: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
1000011f4: 48 29 d1                    	subq	%rdx, %rcx
1000011f7: 48 89 8d 48 00 00 00        	movq	%rcx, 0x48(%rbp)
1000011fe: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100001205: 48 89 c1                    	movq	%rax, %rcx
100001208: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
10000120d: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100001211: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
10000121b: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001220: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001224: 0f 82 39 00 00 00           	jb	0x100001263 <__text+0x263>
10000122a: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001234: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001239: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000123d: 0f 83 20 00 00 00           	jae	0x100001263 <__text+0x263>
100001243: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001248: 48 39 c8                    	cmpq	%rcx, %rax
10000124b: 0f 85 12 00 00 00           	jne	0x100001263 <__text+0x263>
100001251: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001255: 66 0f 7e d8                 	movd	%xmm3, %eax
100001259: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000125e: e9 3d 00 00 00              	jmp	0x1000012a0 <__text+0x2a0>
100001263: 48 8d 35 d6 3d 00 00        	leaq	0x3dd6(%rip), %rsi      ## 0x100005040
10000126a: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001271: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001278: 4c 89 c2                    	movq	%r8, %rdx
10000127b: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001285: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
10000128f: 0f 05                       	syscall
100001291: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000129b: e9 75 06 00 00              	jmp	0x100001915 <__text+0x915>
1000012a0: 48 b8 00 00 e0 40 00 00 00 00       	movabsq	$0x40e00000, %rax ## imm = 0x40E00000
1000012aa: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000012af: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000012b2: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000012b5: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000012b9: f3 0f 11 85 60 00 00 00     	movss	%xmm0, 0x60(%rbp)
1000012c1: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000012c8: 48 b9 71 81 0b 5c e0 02 17 b8       	movabsq	$-0x47e8fd1fa3f47e8f, %rcx ## imm = 0xB81702E05C0B8171
1000012d2: 48 f7 e9                    	imulq	%rcx
1000012d5: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
1000012dc: 48 01 ca                    	addq	%rcx, %rdx
1000012df: 48 c1 fa 06                 	sarq	$0x6, %rdx
1000012e3: 48 89 d0                    	movq	%rdx, %rax
1000012e6: 48 c1 e8 3f                 	shrq	$0x3f, %rax
1000012ea: 48 01 c2                    	addq	%rax, %rdx
1000012ed: 48 b8 59 00 00 00 00 00 00 00       	movabsq	$0x59, %rax
1000012f7: 48 0f af d0                 	imulq	%rax, %rdx
1000012fb: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
100001302: 48 29 d1                    	subq	%rdx, %rcx
100001305: 48 89 8d 70 00 00 00        	movq	%rcx, 0x70(%rbp)
10000130c: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100001313: 48 89 c1                    	movq	%rax, %rcx
100001316: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
10000131b: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
10000131f: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100001329: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000132e: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001332: 0f 82 39 00 00 00           	jb	0x100001371 <__text+0x371>
100001338: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001342: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001347: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000134b: 0f 83 20 00 00 00           	jae	0x100001371 <__text+0x371>
100001351: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001356: 48 39 c8                    	cmpq	%rcx, %rax
100001359: 0f 85 12 00 00 00           	jne	0x100001371 <__text+0x371>
10000135f: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001363: 66 0f 7e d8                 	movd	%xmm3, %eax
100001367: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000136c: e9 3d 00 00 00              	jmp	0x1000013ae <__text+0x3ae>
100001371: 48 8d 35 40 3d 00 00        	leaq	0x3d40(%rip), %rsi      ## 0x1000050b8
100001378: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000137f: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001386: 4c 89 c2                    	movq	%r8, %rdx
100001389: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001393: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
10000139d: 0f 05                       	syscall
10000139f: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000013a9: e9 67 05 00 00              	jmp	0x100001915 <__text+0x915>
1000013ae: 48 b8 00 00 a0 40 00 00 00 00       	movabsq	$0x40a00000, %rax ## imm = 0x40A00000
1000013b8: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000013bd: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000013c0: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000013c3: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000013c7: f3 0f 11 85 88 00 00 00     	movss	%xmm0, 0x88(%rbp)
1000013cf: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000013d6: 48 b9 c5 4e ec c4 4e ec c4 4e       	movabsq	$0x4ec4ec4ec4ec4ec5, %rcx ## imm = 0x4EC4EC4EC4EC4EC5
1000013e0: 48 f7 e9                    	imulq	%rcx
1000013e3: 48 c1 fa 02                 	sarq	$0x2, %rdx
1000013e7: 48 89 d0                    	movq	%rdx, %rax
1000013ea: 48 c1 e8 3f                 	shrq	$0x3f, %rax
1000013ee: 48 01 c2                    	addq	%rax, %rdx
1000013f1: 48 b8 0d 00 00 00 00 00 00 00       	movabsq	$0xd, %rax
1000013fb: 48 0f af d0                 	imulq	%rax, %rdx
1000013ff: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
100001406: 48 29 d1                    	subq	%rdx, %rcx
100001409: 48 89 8d 98 00 00 00        	movq	%rcx, 0x98(%rbp)
100001410: 48 8b 85 98 00 00 00        	movq	0x98(%rbp), %rax
100001417: 48 89 c1                    	movq	%rax, %rcx
10000141a: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
10000141f: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100001423: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
10000142d: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001432: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001436: 0f 82 39 00 00 00           	jb	0x100001475 <__text+0x475>
10000143c: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001446: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000144b: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000144f: 0f 83 20 00 00 00           	jae	0x100001475 <__text+0x475>
100001455: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
10000145a: 48 39 c8                    	cmpq	%rcx, %rax
10000145d: 0f 85 12 00 00 00           	jne	0x100001475 <__text+0x475>
100001463: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001467: 66 0f 7e d8                 	movd	%xmm3, %eax
10000146b: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001470: e9 3d 00 00 00              	jmp	0x1000014b2 <__text+0x4b2>
100001475: 48 8d 35 b4 3c 00 00        	leaq	0x3cb4(%rip), %rsi      ## 0x100005130
10000147c: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001483: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000148a: 4c 89 c2                    	movq	%r8, %rdx
10000148d: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001497: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
1000014a1: 0f 05                       	syscall
1000014a3: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000014ad: e9 63 04 00 00              	jmp	0x100001915 <__text+0x915>
1000014b2: 48 b8 00 00 5c 42 00 00 00 00       	movabsq	$0x425c0000, %rax ## imm = 0x425C0000
1000014bc: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000014c1: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000014c4: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000014c7: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000014cb: f3 0f 11 85 b0 00 00 00     	movss	%xmm0, 0xb0(%rbp)
1000014d3: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000014da: 48 b9 79 78 78 78 78 78 78 78       	movabsq	$0x7878787878787879, %rcx ## imm = 0x7878787878787879
1000014e4: 48 f7 e9                    	imulq	%rcx
1000014e7: 48 c1 fa 03                 	sarq	$0x3, %rdx
1000014eb: 48 89 d0                    	movq	%rdx, %rax
1000014ee: 48 c1 e8 3f                 	shrq	$0x3f, %rax
1000014f2: 48 01 c2                    	addq	%rax, %rdx
1000014f5: 48 b8 11 00 00 00 00 00 00 00       	movabsq	$0x11, %rax
1000014ff: 48 0f af d0                 	imulq	%rax, %rdx
100001503: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
10000150a: 48 29 d1                    	subq	%rdx, %rcx
10000150d: 48 89 8d c0 00 00 00        	movq	%rcx, 0xc0(%rbp)
100001514: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
10000151b: 48 89 c1                    	movq	%rax, %rcx
10000151e: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100001523: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100001527: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100001531: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001536: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000153a: 0f 82 39 00 00 00           	jb	0x100001579 <__text+0x579>
100001540: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
10000154a: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000154f: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001553: 0f 83 20 00 00 00           	jae	0x100001579 <__text+0x579>
100001559: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
10000155e: 48 39 c8                    	cmpq	%rcx, %rax
100001561: 0f 85 12 00 00 00           	jne	0x100001579 <__text+0x579>
100001567: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
10000156b: 66 0f 7e d8                 	movd	%xmm3, %eax
10000156f: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001574: e9 3d 00 00 00              	jmp	0x1000015b6 <__text+0x5b6>
100001579: 48 8d 35 28 3c 00 00        	leaq	0x3c28(%rip), %rsi      ## 0x1000051a8
100001580: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001587: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000158e: 4c 89 c2                    	movq	%r8, %rdx
100001591: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000159b: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
1000015a5: 0f 05                       	syscall
1000015a7: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000015b1: e9 5f 03 00 00              	jmp	0x100001915 <__text+0x915>
1000015b6: 48 b8 00 00 00 41 00 00 00 00       	movabsq	$0x41000000, %rax ## imm = 0x41000000
1000015c0: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000015c5: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000015c8: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000015cb: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000015cf: f3 0f 11 85 d8 00 00 00     	movss	%xmm0, 0xd8(%rbp)
1000015d7: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
1000015de: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
1000015e5: 48 8b 85 88 00 00 00        	movq	0x88(%rbp), %rax
1000015ec: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
1000015f3: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
1000015fa: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100001601: 48 8b 85 d8 00 00 00        	movq	0xd8(%rbp), %rax
100001608: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
10000160f: 48 8b 9d 38 00 00 00        	movq	0x38(%rbp), %rbx
100001616: 4c 8b a3 00 00 00 00        	movq	(%rbx), %r12
10000161d: 4d 89 e5                    	movq	%r12, %r13
100001620: 49 83 c5 01                 	addq	$0x1, %r13
100001624: 4c 89 ee                    	movq	%r13, %rsi
100001627: 48 b9 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rcx
100001631: 48 0f af f1                 	imulq	%rcx, %rsi
100001635: 48 81 c6 28 00 00 00        	addq	$0x28, %rsi
10000163c: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
100001646: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001650: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
10000165a: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
100001664: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
10000166e: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
100001678: 0f 05                       	syscall
10000167a: 0f 83 0f 00 00 00           	jae	0x10000168f <__text+0x68f>
100001680: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000168a: e9 86 02 00 00              	jmp	0x100001915 <__text+0x915>
10000168f: 49 89 c7                    	movq	%rax, %r15
100001692: 4d 89 af 00 00 00 00        	movq	%r13, (%r15)
100001699: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000016a3: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
1000016aa: 49 89 87 10 00 00 00        	movq	%rax, 0x10(%r15)
1000016b1: 49 89 87 20 00 00 00        	movq	%rax, 0x20(%r15)
1000016b8: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000016c2: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
1000016c9: 49 89 b7 18 00 00 00        	movq	%rsi, 0x18(%r15)
1000016d0: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000016d7: 4d 89 fe                    	movq	%r15, %r14
1000016da: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000016e1: 4d 89 e5                    	movq	%r12, %r13
1000016e4: 48 b9 04 00 00 00 00 00 00 00       	movabsq	$0x4, %rcx
1000016ee: 4c 0f af e9                 	imulq	%rcx, %r13
1000016f2: 4d 85 ed                    	testq	%r13, %r13
1000016f5: 0f 84 20 00 00 00           	je	0x10000171b <__text+0x71b>
1000016fb: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001702: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100001709: 48 83 c3 08                 	addq	$0x8, %rbx
10000170d: 49 83 c6 08                 	addq	$0x8, %r14
100001711: 49 83 ed 01                 	subq	$0x1, %r13
100001715: 0f 85 e0 ff ff ff           	jne	0x1000016fb <__text+0x6fb>
10000171b: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
100001722: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100001729: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100001730: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100001737: 48 8b 85 f0 00 00 00        	movq	0xf0(%rbp), %rax
10000173e: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100001745: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
10000174c: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
100001753: 4c 89 bd 00 01 00 00        	movq	%r15, 0x100(%rbp)
10000175a: 4c 8b 95 38 00 00 00        	movq	0x38(%rbp), %r10
100001761: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100001768: 48 85 c0                    	testq	%rax, %rax
10000176b: 0f 84 89 00 00 00           	je	0x1000017fa <__text+0x7fa>
100001771: 49 89 c3                    	movq	%rax, %r11
100001774: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
10000177b: f0                          	lock
10000177c: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100001781: 0f 85 da ff ff ff           	jne	0x100001761 <__text+0x761>
100001787: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
10000178e: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100001795: 4c 01 d8                    	addq	%r11, %rax
100001798: 48 85 c0                    	testq	%rax, %rax
10000179b: 0f 85 59 00 00 00           	jne	0x1000017fa <__text+0x7fa>
1000017a1: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
1000017a8: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
1000017b2: 48 39 c8                    	cmpq	%rcx, %rax
1000017b5: 0f 84 e6 ff ff ff           	je	0x1000017a1 <__text+0x7a1>
1000017bb: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000017c5: 48 39 c8                    	cmpq	%rcx, %rax
1000017c8: 0f 84 2c 00 00 00           	je	0x1000017fa <__text+0x7fa>
1000017ce: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000017d8: f0                          	lock
1000017d9: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000017de: 0f 85 bd ff ff ff           	jne	0x1000017a1 <__text+0x7a1>
1000017e4: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000017eb: 4c 89 d7                    	movq	%r10, %rdi
1000017ee: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
1000017f8: 0f 05                       	syscall
1000017fa: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100001801: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
100001808: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
10000180f: 48 8b 8d 28 01 00 00        	movq	0x128(%rbp), %rcx
100001816: 48 01 c8                    	addq	%rcx, %rax
100001819: 71 0a                       	jno	0x100001825 <__text+0x825>
10000181b: ba 01 00 00 00              	movl	$0x1, %edx
100001820: e9 f0 00 00 00              	jmp	0x100001915 <__text+0x915>
100001825: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
10000182c: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100001833: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
10000183a: e9 32 f9 ff ff              	jmp	0x100001171 <__text+0x171>
10000183f: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100001846: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
10000184d: 4c 8b 95 10 01 00 00        	movq	0x110(%rbp), %r10
100001854: f0                          	lock
100001855: 49 ff 42 08                 	incq	0x8(%r10)
100001859: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100001860: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100001867: 4c 8b 95 18 01 00 00        	movq	0x118(%rbp), %r10
10000186e: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100001875: 48 85 c0                    	testq	%rax, %rax
100001878: 0f 84 89 00 00 00           	je	0x100001907 <__text+0x907>
10000187e: 49 89 c3                    	movq	%rax, %r11
100001881: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100001888: f0                          	lock
100001889: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
10000188e: 0f 85 da ff ff ff           	jne	0x10000186e <__text+0x86e>
100001894: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
10000189b: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
1000018a2: 4c 01 d8                    	addq	%r11, %rax
1000018a5: 48 85 c0                    	testq	%rax, %rax
1000018a8: 0f 85 59 00 00 00           	jne	0x100001907 <__text+0x907>
1000018ae: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
1000018b5: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
1000018bf: 48 39 c8                    	cmpq	%rcx, %rax
1000018c2: 0f 84 e6 ff ff ff           	je	0x1000018ae <__text+0x8ae>
1000018c8: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000018d2: 48 39 c8                    	cmpq	%rcx, %rax
1000018d5: 0f 84 2c 00 00 00           	je	0x100001907 <__text+0x907>
1000018db: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000018e5: f0                          	lock
1000018e6: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000018eb: 0f 85 bd ff ff ff           	jne	0x1000018ae <__text+0x8ae>
1000018f1: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000018f8: 4c 89 d7                    	movq	%r10, %rdi
1000018fb: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100001905: 0f 05                       	syscall
100001907: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
10000190e: 31 d2                       	xorl	%edx, %edx
100001910: e9 00 00 00 00              	jmp	0x100001915 <__text+0x915>
100001915: 48 89 ec                    	movq	%rbp, %rsp
100001918: 48 81 c4 50 01 00 00        	addq	$0x150, %rsp            ## imm = 0x150
10000191f: 5d                          	popq	%rbp
100001920: c3                          	retq
100001921: 55                          	pushq	%rbp
100001922: 48 89 e5                    	movq	%rsp, %rbp
100001925: 48 81 ec a0 04 00 00        	subq	$0x4a0, %rsp            ## imm = 0x4A0
10000192c: 48 89 e5                    	movq	%rsp, %rbp
10000192f: 48 89 b5 10 00 00 00        	movq	%rsi, 0x10(%rbp)
100001936: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
10000193d: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
100001944: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
10000194b: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100001952: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000195c: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001961: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000196b: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100001972: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
10000197c: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100001983: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
10000198a: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
100001991: 48 39 c8                    	cmpq	%rcx, %rax
100001994: 0f 9c c0                    	setl	%al
100001997: 48 0f b6 c0                 	movzbq	%al, %rax
10000199b: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
1000019a2: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000019a9: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
1000019b0: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
1000019b7: 48 89 85 28 04 00 00        	movq	%rax, 0x428(%rbp)
1000019be: 66 48 0f 7e f0              	movq	%xmm6, %rax
1000019c3: 48 89 85 48 04 00 00        	movq	%rax, 0x448(%rbp)
1000019ca: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
1000019d1: 48 85 c0                    	testq	%rax, %rax
1000019d4: 0f 85 05 00 00 00           	jne	0x1000019df <__text+0x9df>
1000019da: e9 39 00 00 00              	jmp	0x100001a18 <__text+0xa18>
1000019df: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000019e9: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000019f0: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000019f7: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
1000019fe: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
100001a05: 48 89 85 28 04 00 00        	movq	%rax, 0x428(%rbp)
100001a0c: 66 48 0f 7e f0              	movq	%xmm6, %rax
100001a11: 48 89 85 48 04 00 00        	movq	%rax, 0x448(%rbp)
100001a18: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
100001a1f: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
100001a26: 48 39 c8                    	cmpq	%rcx, %rax
100001a29: 0f 95 c0                    	setne	%al
100001a2c: 48 0f b6 c0                 	movzbq	%al, %rax
100001a30: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100001a37: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
100001a3e: 48 85 c0                    	testq	%rax, %rax
100001a41: 0f 85 05 00 00 00           	jne	0x100001a4c <__text+0xa4c>
100001a47: e9 56 01 00 00              	jmp	0x100001ba2 <__text+0xba2>
100001a4c: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
100001a53: 48 89 c1                    	movq	%rax, %rcx
100001a56: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100001a5b: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100001a5f: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100001a69: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001a6e: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001a72: 0f 82 39 00 00 00           	jb	0x100001ab1 <__text+0xab1>
100001a78: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001a82: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001a87: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001a8b: 0f 83 20 00 00 00           	jae	0x100001ab1 <__text+0xab1>
100001a91: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001a96: 48 39 c8                    	cmpq	%rcx, %rax
100001a99: 0f 85 12 00 00 00           	jne	0x100001ab1 <__text+0xab1>
100001a9f: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001aa3: 66 0f 7e d8                 	movd	%xmm3, %eax
100001aa7: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001aac: e9 3d 00 00 00              	jmp	0x100001aee <__text+0xaee>
100001ab1: 48 8d 35 00 38 00 00        	leaq	0x3800(%rip), %rsi      ## 0x1000052b8
100001ab8: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001abf: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001ac6: 4c 89 c2                    	movq	%r8, %rdx
100001ac9: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001ad3: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100001add: 0f 05                       	syscall
100001adf: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001ae9: e9 df 0a 00 00              	jmp	0x1000025cd <__text+0x15cd>
100001aee: 48 b8 6f 12 83 3a 00 00 00 00       	movabsq	$0x3a83126f, %rax ## imm = 0x3A83126F
100001af8: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001afd: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001b00: 0f 28 cf                    	movaps	%xmm7, %xmm1
100001b03: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001b07: f3 0f 11 85 78 00 00 00     	movss	%xmm0, 0x78(%rbp)
100001b0f: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001b16: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100001b1d: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100001b24: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100001b2b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001b35: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100001b3c: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100001b43: 48 89 85 30 04 00 00        	movq	%rax, 0x430(%rbp)
100001b4a: 48 8b 85 48 04 00 00        	movq	0x448(%rbp), %rax
100001b51: 48 89 85 50 04 00 00        	movq	%rax, 0x450(%rbp)
100001b58: e9 61 00 00 00              	jmp	0x100001bbe <__text+0xbbe>
100001b5d: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
100001b64: 48 8b 8d 28 04 00 00        	movq	0x428(%rbp), %rcx
100001b6b: 48 01 c8                    	addq	%rcx, %rax
100001b6e: 71 0a                       	jno	0x100001b7a <__text+0xb7a>
100001b70: ba 01 00 00 00              	movl	$0x1, %edx
100001b75: e9 53 0a 00 00              	jmp	0x1000025cd <__text+0x15cd>
100001b7a: 48 89 85 10 04 00 00        	movq	%rax, 0x410(%rbp)
100001b81: 48 8b 85 10 04 00 00        	movq	0x410(%rbp), %rax
100001b88: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
100001b8f: 48 8b 85 50 04 00 00        	movq	0x450(%rbp), %rax
100001b96: 48 89 85 48 04 00 00        	movq	%rax, 0x448(%rbp)
100001b9d: e9 76 fe ff ff              	jmp	0x100001a18 <__text+0xa18>
100001ba2: 48 8b 85 48 04 00 00        	movq	0x448(%rbp), %rax
100001ba9: 48 89 85 18 04 00 00        	movq	%rax, 0x418(%rbp)
100001bb0: 48 8b 85 18 04 00 00        	movq	0x418(%rbp), %rax
100001bb7: 31 d2                       	xorl	%edx, %edx
100001bb9: e9 0f 0a 00 00              	jmp	0x1000025cd <__text+0x15cd>
100001bbe: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100001bc5: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100001bcc: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100001bd3: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
100001bda: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100001be1: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
100001be8: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001bef: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
100001bf6: 48 39 c8                    	cmpq	%rcx, %rax
100001bf9: 0f 9c c0                    	setl	%al
100001bfc: 48 0f b6 c0                 	movzbq	%al, %rax
100001c00: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100001c07: 48 8b 85 a0 00 00 00        	movq	0xa0(%rbp), %rax
100001c0e: 48 85 c0                    	testq	%rax, %rax
100001c11: 0f 85 05 00 00 00           	jne	0x100001c1c <__text+0xc1c>
100001c17: e9 41 ff ff ff              	jmp	0x100001b5d <__text+0xb5d>
100001c1c: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100001c23: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100001c2a: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100001c31: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100001c38: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100001c3f: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
100001c46: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001c4d: 48 85 c0                    	testq	%rax, %rax
100001c50: 0f 89 03 00 00 00           	jns	0x100001c59 <__text+0xc59>
100001c56: 48 01 c8                    	addq	%rcx, %rax
100001c59: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100001c60: 48 01 c3                    	addq	%rax, %rbx
100001c63: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001c6a: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100001c71: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100001c78: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100001c7f: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100001c86: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100001c8d: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001c94: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100001c9b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001ca5: 48 89 85 d8 00 00 00        	movq	%rax, 0xd8(%rbp)
100001cac: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001cb6: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
100001cbd: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001cc7: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100001cce: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001cd8: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100001cdf: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001ce9: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100001cf0: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001cfa: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100001d01: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001d0b: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100001d12: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001d19: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100001d20: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100001d27: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100001d2e: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001d38: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100001d3f: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100001d46: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100001d4d: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
100001d54: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001d5b: 48 8b 85 d8 00 00 00        	movq	0xd8(%rbp), %rax
100001d62: 48 89 85 58 04 00 00        	movq	%rax, 0x458(%rbp)
100001d69: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100001d70: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100001d77: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
100001d7e: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
100001d85: 48 8b 85 f0 00 00 00        	movq	0xf0(%rbp), %rax
100001d8c: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
100001d93: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100001d9a: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
100001da1: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
100001da8: 48 89 85 60 04 00 00        	movq	%rax, 0x460(%rbp)
100001daf: e9 3c 00 00 00              	jmp	0x100001df0 <__text+0xdf0>
100001db4: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001dbe: 48 89 85 08 04 00 00        	movq	%rax, 0x408(%rbp)
100001dc5: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001dcc: 48 8b 8d 08 04 00 00        	movq	0x408(%rbp), %rcx
100001dd3: 48 01 c8                    	addq	%rcx, %rax
100001dd6: 48 89 85 00 04 00 00        	movq	%rax, 0x400(%rbp)
100001ddd: 48 8b 85 00 04 00 00        	movq	0x400(%rbp), %rax
100001de4: 48 89 85 30 04 00 00        	movq	%rax, 0x430(%rbp)
100001deb: e9 ce fd ff ff              	jmp	0x100001bbe <__text+0xbbe>
100001df0: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001df7: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100001dfe: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001e05: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100001e0c: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100001e13: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100001e1a: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001e21: 48 8b 8d 28 01 00 00        	movq	0x128(%rbp), %rcx
100001e28: 48 39 c8                    	cmpq	%rcx, %rax
100001e2b: 0f 9c c0                    	setl	%al
100001e2e: 48 0f b6 c0                 	movzbq	%al, %rax
100001e32: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
100001e39: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100001e40: 48 85 c0                    	testq	%rax, %rax
100001e43: 0f 85 05 00 00 00           	jne	0x100001e4e <__text+0xe4e>
100001e49: e9 81 01 00 00              	jmp	0x100001fcf <__text+0xfcf>
100001e4e: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001e55: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100001e5c: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001e63: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100001e6a: 48 8b 9d 38 01 00 00        	movq	0x138(%rbp), %rbx
100001e71: 48 8b 8d 40 01 00 00        	movq	0x140(%rbp), %rcx
100001e78: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001e7f: 48 85 c0                    	testq	%rax, %rax
100001e82: 0f 89 03 00 00 00           	jns	0x100001e8b <__text+0xe8b>
100001e88: 48 01 c8                    	addq	%rcx, %rax
100001e8b: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100001e92: 48 01 c3                    	addq	%rax, %rbx
100001e95: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001e9c: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100001ea3: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100001eaa: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100001eb1: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100001eb8: 48 89 85 58 01 00 00        	movq	%rax, 0x158(%rbp)
100001ebf: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001ec6: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100001ecd: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100001ed4: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001ed9: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001edc: f3 0f 10 8d 78 00 00 00     	movss	0x78(%rbp), %xmm1
100001ee4: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001ee8: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001eeb: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001ef2: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001ef7: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001efa: 0f 28 cf                    	movaps	%xmm7, %xmm1
100001efd: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100001f01: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100001f05: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100001f0c: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001f11: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001f18: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001f1d: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001f20: 0f 28 cf                    	movaps	%xmm7, %xmm1
100001f23: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100001f27: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100001f2b: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100001f2f: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100001f33: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001f37: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001f3a: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100001f3e: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100001f42: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001f46: 44 0f 28 d0                 	movaps	%xmm0, %xmm10
100001f4a: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001f4d: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100001f51: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001f55: 0f 28 f8                    	movaps	%xmm0, %xmm7
100001f58: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001f62: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001f67: 0f 28 c7                    	movaps	%xmm7, %xmm0
100001f6a: 0f 28 ce                    	movaps	%xmm6, %xmm1
100001f6d: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100001f70: 0f 97 c0                    	seta	%al
100001f73: 48 0f b6 c0                 	movzbq	%al, %rax
100001f77: 48 89 85 c0 01 00 00        	movq	%rax, 0x1c0(%rbp)
100001f7e: 48 8b 85 c0 01 00 00        	movq	0x1c0(%rbp), %rax
100001f85: 48 85 c0                    	testq	%rax, %rax
100001f88: 0f 85 86 00 00 00           	jne	0x100002014 <__text+0x1014>
100001f8e: e9 00 00 00 00              	jmp	0x100001f93 <__text+0xf93>
100001f93: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001f9d: 48 89 85 b8 02 00 00        	movq	%rax, 0x2b8(%rbp)
100001fa4: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001fab: 48 8b 8d b8 02 00 00        	movq	0x2b8(%rbp), %rcx
100001fb2: 48 01 c8                    	addq	%rcx, %rax
100001fb5: 48 89 85 b0 02 00 00        	movq	%rax, 0x2b0(%rbp)
100001fbc: 48 8b 85 b0 02 00 00        	movq	0x2b0(%rbp), %rax
100001fc3: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001fca: e9 21 fe ff ff              	jmp	0x100001df0 <__text+0xdf0>
100001fcf: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001fd9: 48 89 85 c0 02 00 00        	movq	%rax, 0x2c0(%rbp)
100001fe0: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100001fe7: 48 8b 8d c0 02 00 00        	movq	0x2c0(%rbp), %rcx
100001fee: 48 39 c8                    	cmpq	%rcx, %rax
100001ff1: 0f 9f c0                    	setg	%al
100001ff4: 48 0f b6 c0                 	movzbq	%al, %rax
100001ff8: 48 89 85 c8 02 00 00        	movq	%rax, 0x2c8(%rbp)
100001fff: 48 8b 85 c8 02 00 00        	movq	0x2c8(%rbp), %rax
100002006: 48 85 c0                    	testq	%rax, %rax
100002009: 0f 85 fb 02 00 00           	jne	0x10000230a <__text+0x130a>
10000200f: e9 a0 fd ff ff              	jmp	0x100001db4 <__text+0xdb4>
100002014: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
10000201e: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002023: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002026: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002029: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
10000202c: 0f 92 c0                    	setb	%al
10000202f: 0f 9b c1                    	setnp	%cl
100002032: 20 c8                       	andb	%cl, %al
100002034: 48 0f b6 c0                 	movzbq	%al, %rax
100002038: 48 89 85 d0 01 00 00        	movq	%rax, 0x1d0(%rbp)
10000203f: 48 8b 85 d0 01 00 00        	movq	0x1d0(%rbp), %rax
100002046: 48 85 c0                    	testq	%rax, %rax
100002049: 0f 85 05 00 00 00           	jne	0x100002054 <__text+0x1054>
10000204f: e9 3f ff ff ff              	jmp	0x100001f93 <__text+0xf93>
100002054: 48 8b 85 68 04 00 00        	movq	0x468(%rbp), %rax
10000205b: 48 89 85 d8 01 00 00        	movq	%rax, 0x1d8(%rbp)
100002062: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100002069: 48 89 85 e0 01 00 00        	movq	%rax, 0x1e0(%rbp)
100002070: 48 8b 85 70 04 00 00        	movq	0x470(%rbp), %rax
100002077: 48 89 85 f0 01 00 00        	movq	%rax, 0x1f0(%rbp)
10000207e: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100002085: 48 89 85 f8 01 00 00        	movq	%rax, 0x1f8(%rbp)
10000208c: f3 0f 10 9d d8 01 00 00     	movss	0x1d8(%rbp), %xmm3
100002094: f3 0f 10 ad f0 01 00 00     	movss	0x1f0(%rbp), %xmm5
10000209c: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
10000209f: f3 0f 10 a5 e0 01 00 00     	movss	0x1e0(%rbp), %xmm4
1000020a7: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
1000020af: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
1000020b2: 0f 28 c3                    	movaps	%xmm3, %xmm0
1000020b5: 0f 58 c4                    	addps	%xmm4, %xmm0
1000020b8: f3 0f 11 85 e8 01 00 00     	movss	%xmm0, 0x1e8(%rbp)
1000020c0: 0f 28 e8                    	movaps	%xmm0, %xmm5
1000020c3: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
1000020c7: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
1000020cf: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
1000020d6: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
1000020dd: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000020e4: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
1000020eb: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
1000020f2: 48 89 85 20 02 00 00        	movq	%rax, 0x220(%rbp)
1000020f9: 48 8b 85 60 01 00 00        	movq	0x160(%rbp), %rax
100002100: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100002107: f3 0f 10 9d 08 02 00 00     	movss	0x208(%rbp), %xmm3
10000210f: f3 0f 10 ad 20 02 00 00     	movss	0x220(%rbp), %xmm5
100002117: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
10000211a: f3 0f 10 a5 10 02 00 00     	movss	0x210(%rbp), %xmm4
100002122: f3 0f 10 ad 28 02 00 00     	movss	0x228(%rbp), %xmm5
10000212a: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
10000212d: 0f 28 cb                    	movaps	%xmm3, %xmm1
100002130: 0f 58 cc                    	addps	%xmm4, %xmm1
100002133: f3 0f 11 8d 18 02 00 00     	movss	%xmm1, 0x218(%rbp)
10000213b: 0f 28 e9                    	movaps	%xmm1, %xmm5
10000213e: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002142: f3 0f 11 ad 30 02 00 00     	movss	%xmm5, 0x230(%rbp)
10000214a: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002154: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
10000215b: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100002162: 48 8b 8d 38 02 00 00        	movq	0x238(%rbp), %rcx
100002169: 48 01 c8                    	addq	%rcx, %rax
10000216c: 71 0a                       	jno	0x100002178 <__text+0x1178>
10000216e: ba 01 00 00 00              	movl	$0x1, %edx
100002173: e9 55 04 00 00              	jmp	0x1000025cd <__text+0x15cd>
100002178: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
10000217f: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
100002189: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000218e: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002191: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002194: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002197: 0f 92 c0                    	setb	%al
10000219a: 0f 9b c1                    	setnp	%cl
10000219d: 20 c8                       	andb	%cl, %al
10000219f: 48 0f b6 c0                 	movzbq	%al, %rax
1000021a3: 48 89 85 50 02 00 00        	movq	%rax, 0x250(%rbp)
1000021aa: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
1000021b1: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
1000021b8: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
1000021bf: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
1000021c6: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
1000021cd: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
1000021d4: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
1000021db: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
1000021e2: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
1000021e9: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
1000021f0: 48 8b 85 50 02 00 00        	movq	0x250(%rbp), %rax
1000021f7: 48 85 c0                    	testq	%rax, %rax
1000021fa: 0f 85 05 00 00 00           	jne	0x100002205 <__text+0x1205>
100002200: e9 8e fd ff ff              	jmp	0x100001f93 <__text+0xf93>
100002205: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
10000220f: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002214: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
10000221e: 66 4c 0f 6e d0              	movq	%rax, %xmm10
100002223: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002226: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
10000222a: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
10000222d: 0f 97 c0                    	seta	%al
100002230: 48 0f b6 c0                 	movzbq	%al, %rax
100002234: 48 89 85 68 02 00 00        	movq	%rax, 0x268(%rbp)
10000223b: 48 8b 85 68 02 00 00        	movq	0x268(%rbp), %rax
100002242: 48 85 c0                    	testq	%rax, %rax
100002245: 0f 85 05 00 00 00           	jne	0x100002250 <__text+0x1250>
10000224b: e9 03 00 00 00              	jmp	0x100002253 <__text+0x1253>
100002250: 0f 28 f7                    	movaps	%xmm7, %xmm6
100002253: 48 8b 85 58 04 00 00        	movq	0x458(%rbp), %rax
10000225a: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000225f: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002263: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002266: f3 0f 5e c1                 	divss	%xmm1, %xmm0
10000226a: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
10000226e: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002271: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002275: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002279: 0f 28 f8                    	movaps	%xmm0, %xmm7
10000227c: 48 8b 85 60 04 00 00        	movq	0x460(%rbp), %rax
100002283: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002288: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
10000228c: 0f 28 ce                    	movaps	%xmm6, %xmm1
10000228f: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002293: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100002297: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
10000229b: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
10000229f: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000022a3: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000022a7: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
1000022ae: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
1000022b5: 66 48 0f 7e f8              	movq	%xmm7, %rax
1000022ba: 48 89 85 58 04 00 00        	movq	%rax, 0x458(%rbp)
1000022c1: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
1000022c8: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
1000022cf: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
1000022d6: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
1000022dd: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
1000022e4: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
1000022eb: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
1000022f2: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
1000022f9: 66 4c 0f 7e c0              	movq	%xmm8, %rax
1000022fe: 48 89 85 60 04 00 00        	movq	%rax, 0x460(%rbp)
100002305: e9 89 fc ff ff              	jmp	0x100001f93 <__text+0xf93>
10000230a: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100002311: 48 89 c1                    	movq	%rax, %rcx
100002314: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100002319: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
10000231d: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100002327: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000232c: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002330: 0f 82 39 00 00 00           	jb	0x10000236f <__text+0x136f>
100002336: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100002340: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002345: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002349: 0f 83 20 00 00 00           	jae	0x10000236f <__text+0x136f>
10000234f: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100002354: 48 39 c8                    	cmpq	%rcx, %rax
100002357: 0f 85 12 00 00 00           	jne	0x10000236f <__text+0x136f>
10000235d: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100002361: 66 0f 7e d8                 	movd	%xmm3, %eax
100002365: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000236a: e9 3d 00 00 00              	jmp	0x1000023ac <__text+0x13ac>
10000236f: 48 8d 35 9a 30 00 00        	leaq	0x309a(%rip), %rsi      ## 0x100005410
100002376: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000237d: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100002384: 4c 89 c2                    	movq	%r8, %rdx
100002387: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100002391: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
10000239b: 0f 05                       	syscall
10000239d: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000023a7: e9 21 02 00 00              	jmp	0x1000025cd <__text+0x15cd>
1000023ac: 48 8b 85 50 04 00 00        	movq	0x450(%rbp), %rax
1000023b3: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000023b8: 48 8b 85 68 04 00 00        	movq	0x468(%rbp), %rax
1000023bf: 66 4c 0f 6e c0              	movq	%rax, %xmm8
1000023c4: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000023c8: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000023cb: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000023cf: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000023d3: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
1000023da: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000023df: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000023e3: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
1000023e7: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000023eb: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000023ef: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
1000023f9: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000023fe: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002402: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002406: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000240a: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
10000240e: 48 8b 85 70 04 00 00        	movq	0x470(%rbp), %rax
100002415: 66 4c 0f 6e c8              	movq	%rax, %xmm9
10000241a: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
10000241e: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002421: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002425: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100002429: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100002430: 66 4c 0f 6e d0              	movq	%rax, %xmm10
100002435: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002439: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
10000243d: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002441: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100002445: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
10000244f: 66 4c 0f 6e d0              	movq	%rax, %xmm10
100002454: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002458: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
10000245c: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002460: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100002464: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002468: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
10000246c: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002470: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002474: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
10000247b: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002480: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002484: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002487: f3 0f 5e c1                 	divss	%xmm1, %xmm0
10000248b: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
10000248f: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
100002496: 66 4c 0f 6e d0              	movq	%rax, %xmm10
10000249b: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
10000249f: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
1000024a3: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000024a7: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000024ab: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
1000024b5: 66 4c 0f 6e d0              	movq	%rax, %xmm10
1000024ba: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000024be: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
1000024c2: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000024c6: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000024ca: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000024ce: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
1000024d2: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000024d6: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000024da: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
1000024e1: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000024e6: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000024ea: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000024ed: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000024f1: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000024f5: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
1000024fc: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002501: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002505: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002508: f3 0f 5c c1                 	subss	%xmm1, %xmm0
10000250c: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100002510: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
10000251a: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000251f: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002523: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002526: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000252a: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
10000252e: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002532: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002536: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000253a: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
10000253e: 48 8b 85 58 04 00 00        	movq	0x458(%rbp), %rax
100002545: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000254a: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002554: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002559: 0f 28 c6                    	movaps	%xmm6, %xmm0
10000255c: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002560: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002564: 0f 28 f0                    	movaps	%xmm0, %xmm6
100002567: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
10000256b: 0f 28 ce                    	movaps	%xmm6, %xmm1
10000256e: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002572: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002576: 48 8b 85 60 04 00 00        	movq	0x460(%rbp), %rax
10000257d: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002582: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
10000258c: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002591: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002594: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002598: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000259c: 0f 28 f0                    	movaps	%xmm0, %xmm6
10000259f: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000025a3: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000025a6: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000025aa: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000025ae: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000025b1: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
1000025b5: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000025b9: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000025bc: 66 48 0f 7e f8              	movq	%xmm7, %rax
1000025c1: 48 89 85 50 04 00 00        	movq	%rax, 0x450(%rbp)
1000025c8: e9 e7 f7 ff ff              	jmp	0x100001db4 <__text+0xdb4>
1000025cd: 48 89 ec                    	movq	%rbp, %rsp
1000025d0: 48 81 c4 a0 04 00 00        	addq	$0x4a0, %rsp            ## imm = 0x4A0
1000025d7: 5d                          	popq	%rbp
1000025d8: c3                          	retq
1000025d9: 55                          	pushq	%rbp
1000025da: 48 89 e5                    	movq	%rsp, %rbp
1000025dd: 48 81 ec 00 04 00 00        	subq	$0x400, %rsp            ## imm = 0x400
1000025e4: 48 89 e5                    	movq	%rsp, %rbp
1000025e7: 4c 89 bd 30 00 00 00        	movq	%r15, 0x30(%rbp)
1000025ee: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
1000025f5: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
1000025fc: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
100002603: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
10000260a: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
100002611: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
100002618: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
10000261f: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100002626: 48 8b 87 10 00 00 00        	movq	0x10(%rdi), %rax
10000262d: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
100002634: 48 8b 87 18 00 00 00        	movq	0x18(%rdi), %rax
10000263b: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100002642: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100002649: 48 89 85 60 03 00 00        	movq	%rax, 0x360(%rbp)
100002650: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100002657: 48 89 85 68 03 00 00        	movq	%rax, 0x368(%rbp)
10000265e: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
100002665: 48 89 85 70 03 00 00        	movq	%rax, 0x370(%rbp)
10000266c: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100002673: 48 89 85 78 03 00 00        	movq	%rax, 0x378(%rbp)
10000267a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002684: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
10000268b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002695: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
10000269c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000026a6: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000026ad: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000026b7: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
1000026be: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000026c8: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
1000026cf: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000026d9: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
1000026e0: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000026ea: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
1000026f1: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
1000026f8: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000026ff: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002706: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
10000270d: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002717: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
10000271e: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
100002725: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
10000272c: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100002733: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
10000273a: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100002741: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
100002748: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
10000274f: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
100002756: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
10000275d: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
100002764: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
10000276b: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
100002772: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
100002779: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
100002780: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
100002787: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
10000278e: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
100002795: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
10000279c: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000027a3: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
1000027aa: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
1000027b1: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
1000027b8: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
1000027bf: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
1000027c6: 48 39 c8                    	cmpq	%rcx, %rax
1000027c9: 0f 9c c0                    	setl	%al
1000027cc: 48 0f b6 c0                 	movzbq	%al, %rax
1000027d0: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
1000027d7: 48 8b 85 a0 00 00 00        	movq	0xa0(%rbp), %rax
1000027de: 48 85 c0                    	testq	%rax, %rax
1000027e1: 0f 85 05 00 00 00           	jne	0x1000027ec <__text+0x17ec>
1000027e7: e9 6f 01 00 00              	jmp	0x10000295b <__text+0x195b>
1000027ec: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000027f3: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
1000027fa: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100002801: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100002808: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
10000280f: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
100002816: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
10000281d: 48 85 c0                    	testq	%rax, %rax
100002820: 0f 89 03 00 00 00           	jns	0x100002829 <__text+0x1829>
100002826: 48 01 c8                    	addq	%rcx, %rax
100002829: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002830: 48 01 c3                    	addq	%rax, %rbx
100002833: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000283a: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100002841: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002848: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
10000284f: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002856: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
10000285d: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100002864: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
10000286b: 48 8b 85 60 03 00 00        	movq	0x360(%rbp), %rax
100002872: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002877: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
10000287e: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002883: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002886: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002889: f3 0f 5c c1                 	subss	%xmm1, %xmm0
10000288d: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002891: 48 8b 85 68 03 00 00        	movq	0x368(%rbp), %rax
100002898: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000289d: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
1000028a4: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000028a9: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000028ac: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000028af: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000028b3: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000028b7: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000028bb: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
1000028bf: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000028c3: 0f 28 f0                    	movaps	%xmm0, %xmm6
1000028c6: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000028ca: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
1000028ce: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000028d2: 44 0f 28 d0                 	movaps	%xmm0, %xmm10
1000028d6: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000028d9: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
1000028dd: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000028e1: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000028e4: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000028ee: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000028f3: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000028f6: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000028f9: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
1000028fc: 0f 97 c0                    	seta	%al
1000028ff: 48 0f b6 c0                 	movzbq	%al, %rax
100002903: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
10000290a: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100002911: 48 85 c0                    	testq	%rax, %rax
100002914: 0f 85 86 00 00 00           	jne	0x1000029a0 <__text+0x19a0>
10000291a: e9 00 00 00 00              	jmp	0x10000291f <__text+0x191f>
10000291f: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002929: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
100002930: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
100002937: 48 8b 8d 10 02 00 00        	movq	0x210(%rbp), %rcx
10000293e: 48 01 c8                    	addq	%rcx, %rax
100002941: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
100002948: 48 8b 85 08 02 00 00        	movq	0x208(%rbp), %rax
10000294f: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
100002956: e9 33 fe ff ff              	jmp	0x10000278e <__text+0x178e>
10000295b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002965: 48 89 85 18 02 00 00        	movq	%rax, 0x218(%rbp)
10000296c: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002973: 48 8b 8d 18 02 00 00        	movq	0x218(%rbp), %rcx
10000297a: 48 39 c8                    	cmpq	%rcx, %rax
10000297d: 0f 94 c0                    	sete	%al
100002980: 48 0f b6 c0                 	movzbq	%al, %rax
100002984: 48 89 85 20 02 00 00        	movq	%rax, 0x220(%rbp)
10000298b: 48 8b 85 20 02 00 00        	movq	0x220(%rbp), %rax
100002992: 48 85 c0                    	testq	%rax, %rax
100002995: 0f 85 30 03 00 00           	jne	0x100002ccb <__text+0x1ccb>
10000299b: e9 9d 03 00 00              	jmp	0x100002d3d <__text+0x1d3d>
1000029a0: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
1000029aa: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000029af: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000029b2: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000029b5: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
1000029b8: 0f 92 c0                    	setb	%al
1000029bb: 0f 9b c1                    	setnp	%cl
1000029be: 20 c8                       	andb	%cl, %al
1000029c0: 48 0f b6 c0                 	movzbq	%al, %rax
1000029c4: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000029cb: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
1000029d2: 48 85 c0                    	testq	%rax, %rax
1000029d5: 0f 85 05 00 00 00           	jne	0x1000029e0 <__text+0x19e0>
1000029db: e9 3f ff ff ff              	jmp	0x10000291f <__text+0x191f>
1000029e0: 48 8b 85 c0 03 00 00        	movq	0x3c0(%rbp), %rax
1000029e7: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
1000029ee: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
1000029f5: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
1000029fc: 48 8b 85 c8 03 00 00        	movq	0x3c8(%rbp), %rax
100002a03: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100002a0a: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100002a11: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100002a18: f3 0f 10 9d 30 01 00 00     	movss	0x130(%rbp), %xmm3
100002a20: f3 0f 10 ad 48 01 00 00     	movss	0x148(%rbp), %xmm5
100002a28: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002a2b: f3 0f 10 a5 38 01 00 00     	movss	0x138(%rbp), %xmm4
100002a33: f3 0f 10 ad 50 01 00 00     	movss	0x150(%rbp), %xmm5
100002a3b: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002a3e: 0f 28 c3                    	movaps	%xmm3, %xmm0
100002a41: 0f 58 c4                    	addps	%xmm4, %xmm0
100002a44: f3 0f 11 85 40 01 00 00     	movss	%xmm0, 0x140(%rbp)
100002a4c: 0f 28 e8                    	movaps	%xmm0, %xmm5
100002a4f: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002a53: f3 0f 11 ad 58 01 00 00     	movss	%xmm5, 0x158(%rbp)
100002a5b: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
100002a62: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100002a69: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
100002a70: 48 89 85 68 01 00 00        	movq	%rax, 0x168(%rbp)
100002a77: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
100002a7e: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
100002a85: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
100002a8c: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
100002a93: f3 0f 10 9d 60 01 00 00     	movss	0x160(%rbp), %xmm3
100002a9b: f3 0f 10 ad 78 01 00 00     	movss	0x178(%rbp), %xmm5
100002aa3: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002aa6: f3 0f 10 a5 68 01 00 00     	movss	0x168(%rbp), %xmm4
100002aae: f3 0f 10 ad 80 01 00 00     	movss	0x180(%rbp), %xmm5
100002ab6: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002ab9: 0f 28 cb                    	movaps	%xmm3, %xmm1
100002abc: 0f 58 cc                    	addps	%xmm4, %xmm1
100002abf: f3 0f 11 8d 70 01 00 00     	movss	%xmm1, 0x170(%rbp)
100002ac7: 0f 28 e9                    	movaps	%xmm1, %xmm5
100002aca: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002ace: f3 0f 11 ad 88 01 00 00     	movss	%xmm5, 0x188(%rbp)
100002ad6: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002ae0: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002ae7: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002aee: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
100002af5: 48 01 c8                    	addq	%rcx, %rax
100002af8: 71 0a                       	jno	0x100002b04 <__text+0x1b04>
100002afa: ba 01 00 00 00              	movl	$0x1, %edx
100002aff: e9 0a 05 00 00              	jmp	0x10000300e <__text+0x200e>
100002b04: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002b0b: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
100002b15: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002b1a: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002b1d: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002b20: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002b23: 0f 92 c0                    	setb	%al
100002b26: 0f 9b c1                    	setnp	%cl
100002b29: 20 c8                       	andb	%cl, %al
100002b2b: 48 0f b6 c0                 	movzbq	%al, %rax
100002b2f: 48 89 85 a8 01 00 00        	movq	%rax, 0x1a8(%rbp)
100002b36: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100002b3d: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
100002b44: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002b4b: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
100002b52: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002b59: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
100002b60: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
100002b67: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
100002b6e: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
100002b75: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
100002b7c: 48 8b 85 a8 01 00 00        	movq	0x1a8(%rbp), %rax
100002b83: 48 85 c0                    	testq	%rax, %rax
100002b86: 0f 85 05 00 00 00           	jne	0x100002b91 <__text+0x1b91>
100002b8c: e9 8e fd ff ff              	jmp	0x10000291f <__text+0x191f>
100002b91: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100002b9b: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002ba0: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100002baa: 66 4c 0f 6e d0              	movq	%rax, %xmm10
100002baf: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002bb2: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100002bb6: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002bb9: 0f 97 c0                    	seta	%al
100002bbc: 48 0f b6 c0                 	movzbq	%al, %rax
100002bc0: 48 89 85 c0 01 00 00        	movq	%rax, 0x1c0(%rbp)
100002bc7: 48 8b 85 c0 01 00 00        	movq	0x1c0(%rbp), %rax
100002bce: 48 85 c0                    	testq	%rax, %rax
100002bd1: 0f 85 05 00 00 00           	jne	0x100002bdc <__text+0x1bdc>
100002bd7: e9 03 00 00 00              	jmp	0x100002bdf <__text+0x1bdf>
100002bdc: 0f 28 f7                    	movaps	%xmm7, %xmm6
100002bdf: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002be6: 48 89 85 c8 01 00 00        	movq	%rax, 0x1c8(%rbp)
100002bed: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002bf1: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002bf4: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002bf8: f3 0f 11 85 d8 01 00 00     	movss	%xmm0, 0x1d8(%rbp)
100002c00: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
100002c07: 48 89 85 e8 01 00 00        	movq	%rax, 0x1e8(%rbp)
100002c0e: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002c12: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002c15: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002c19: f3 0f 11 85 f8 01 00 00     	movss	%xmm0, 0x1f8(%rbp)
100002c21: f3 0f 10 9d c8 01 00 00     	movss	0x1c8(%rbp), %xmm3
100002c29: f3 0f 10 ad e8 01 00 00     	movss	0x1e8(%rbp), %xmm5
100002c31: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002c34: f3 0f 10 a5 d8 01 00 00     	movss	0x1d8(%rbp), %xmm4
100002c3c: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100002c44: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002c47: 0f 28 d3                    	movaps	%xmm3, %xmm2
100002c4a: 0f 58 d4                    	addps	%xmm4, %xmm2
100002c4d: f3 0f 11 95 e0 01 00 00     	movss	%xmm2, 0x1e0(%rbp)
100002c55: 0f 28 ea                    	movaps	%xmm2, %xmm5
100002c58: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002c5c: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
100002c64: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100002c6b: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
100002c72: 48 8b 85 e0 01 00 00        	movq	0x1e0(%rbp), %rax
100002c79: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
100002c80: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002c87: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
100002c8e: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
100002c95: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
100002c9c: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
100002ca3: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
100002caa: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002cb1: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
100002cb8: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100002cbf: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
100002cc6: e9 54 fc ff ff              	jmp	0x10000291f <__text+0x191f>
100002ccb: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002cd5: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100002cdc: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002ce6: 48 89 85 30 02 00 00        	movq	%rax, 0x230(%rbp)
100002ced: 48 8b 85 28 02 00 00        	movq	0x228(%rbp), %rax
100002cf4: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
100002cfb: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
100002d02: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
100002d09: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002d10: 48 8b 85 38 02 00 00        	movq	0x238(%rbp), %rax
100002d17: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002d1e: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
100002d25: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002d2c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002d36: 31 d2                       	xorl	%edx, %edx
100002d38: e9 d1 02 00 00              	jmp	0x10000300e <__text+0x200e>
100002d3d: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002d44: 48 89 c1                    	movq	%rax, %rcx
100002d47: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100002d4c: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100002d50: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100002d5a: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002d5f: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002d63: 0f 82 39 00 00 00           	jb	0x100002da2 <__text+0x1da2>
100002d69: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100002d73: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002d78: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002d7c: 0f 83 20 00 00 00           	jae	0x100002da2 <__text+0x1da2>
100002d82: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100002d87: 48 39 c8                    	cmpq	%rcx, %rax
100002d8a: 0f 85 12 00 00 00           	jne	0x100002da2 <__text+0x1da2>
100002d90: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100002d94: 66 0f 7e d8                 	movd	%xmm3, %eax
100002d98: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002d9d: e9 3d 00 00 00              	jmp	0x100002ddf <__text+0x1ddf>
100002da2: 48 8d 35 4f 27 00 00        	leaq	0x274f(%rip), %rsi      ## 0x1000054f8
100002da9: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100002db0: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100002db7: 4c 89 c2                    	movq	%r8, %rdx
100002dba: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100002dc4: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100002dce: 0f 05                       	syscall
100002dd0: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002dda: e9 2f 02 00 00              	jmp	0x10000300e <__text+0x200e>
100002ddf: 48 8b 85 c0 03 00 00        	movq	0x3c0(%rbp), %rax
100002de6: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002deb: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002dee: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002df1: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002df5: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002df8: 48 8b 85 60 03 00 00        	movq	0x360(%rbp), %rax
100002dff: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002e04: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002e07: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002e0b: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002e0f: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002e12: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002e1c: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002e21: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002e24: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002e28: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002e2c: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002e2f: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
100002e36: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002e3b: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002e3f: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002e42: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002e46: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002e4a: 48 8b 85 70 03 00 00        	movq	0x370(%rbp), %rax
100002e51: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002e56: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002e5a: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002e5e: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002e62: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002e66: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002e70: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002e75: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002e79: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002e7d: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002e81: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002e85: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002e88: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002e8c: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002e90: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002e93: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002e9a: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002e9f: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002ea9: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002eae: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002eb2: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002eb6: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002eba: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002ebe: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002ec1: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002ec5: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002ec9: f3 0f 11 85 c0 02 00 00     	movss	%xmm0, 0x2c0(%rbp)
100002ed1: 48 8b 85 c8 03 00 00        	movq	0x3c8(%rbp), %rax
100002ed8: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002edd: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002ee0: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002ee3: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002ee7: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002eea: 48 8b 85 68 03 00 00        	movq	0x368(%rbp), %rax
100002ef1: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002ef6: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002ef9: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002efd: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002f01: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002f04: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002f0e: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002f13: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002f16: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002f1a: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002f1e: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002f21: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
100002f28: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002f2d: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002f31: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002f34: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002f38: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002f3c: 48 8b 85 78 03 00 00        	movq	0x378(%rbp), %rax
100002f43: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002f48: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002f4c: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002f4f: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002f53: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002f57: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002f61: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002f66: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002f6a: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002f6d: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002f71: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002f75: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002f78: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002f7c: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002f80: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002f83: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
100002f8a: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002f8f: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002f99: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002f9e: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002fa1: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002fa5: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002fa9: 0f 28 f0                    	movaps	%xmm0, %xmm6
100002fac: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002faf: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002fb2: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002fb6: f3 0f 11 85 38 03 00 00     	movss	%xmm0, 0x338(%rbp)
100002fbe: 48 8b 85 c0 02 00 00        	movq	0x2c0(%rbp), %rax
100002fc5: 48 89 85 40 03 00 00        	movq	%rax, 0x340(%rbp)
100002fcc: 48 8b 85 38 03 00 00        	movq	0x338(%rbp), %rax
100002fd3: 48 89 85 48 03 00 00        	movq	%rax, 0x348(%rbp)
100002fda: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002fe1: 48 8b 85 40 03 00 00        	movq	0x340(%rbp), %rax
100002fe8: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002fef: 48 8b 85 48 03 00 00        	movq	0x348(%rbp), %rax
100002ff6: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002ffd: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003007: 31 d2                       	xorl	%edx, %edx
100003009: e9 00 00 00 00              	jmp	0x10000300e <__text+0x200e>
10000300e: 48 89 ec                    	movq	%rbp, %rsp
100003011: 48 81 c4 00 04 00 00        	addq	$0x400, %rsp            ## imm = 0x400
100003018: 5d                          	popq	%rbp
100003019: c3                          	retq
10000301a: 55                          	pushq	%rbp
10000301b: 48 89 e5                    	movq	%rsp, %rbp
10000301e: 48 81 ec b0 01 00 00        	subq	$0x1b0, %rsp            ## imm = 0x1B0
100003025: 48 89 e5                    	movq	%rsp, %rbp
100003028: 48 89 95 18 00 00 00        	movq	%rdx, 0x18(%rbp)
10000302f: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
100003036: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
10000303d: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
100003044: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
10000304b: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
100003052: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000305c: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100003063: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000306d: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100003074: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
10000307b: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100003082: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100003089: 48 8b 8d 30 00 00 00        	movq	0x30(%rbp), %rcx
100003090: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100003097: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
10000309e: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
1000030a8: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000030af: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
1000030b6: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
1000030bd: 48 39 c8                    	cmpq	%rcx, %rax
1000030c0: 0f 9c c0                    	setl	%al
1000030c3: 48 0f b6 c0                 	movzbq	%al, %rax
1000030c7: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
1000030ce: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
1000030d5: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
1000030dc: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000030e3: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
1000030ea: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
1000030f1: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
1000030f8: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
1000030ff: 48 85 c0                    	testq	%rax, %rax
100003102: 0f 85 05 00 00 00           	jne	0x10000310d <__text+0x210d>
100003108: e9 3b 00 00 00              	jmp	0x100003148 <__text+0x2148>
10000310d: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100003117: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
10000311e: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100003125: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
10000312c: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
100003133: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
10000313a: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100003141: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100003148: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
10000314f: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100003156: 48 39 c8                    	cmpq	%rcx, %rax
100003159: 0f 95 c0                    	setne	%al
10000315c: 48 0f b6 c0                 	movzbq	%al, %rax
100003160: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
100003167: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
10000316e: 48 85 c0                    	testq	%rax, %rax
100003171: 0f 85 05 00 00 00           	jne	0x10000317c <__text+0x217c>
100003177: e9 ad 05 00 00              	jmp	0x100003729 <__text+0x2729>
10000317c: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100003183: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
10000318a: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100003191: 48 8b 9d 60 00 00 00        	movq	0x60(%rbp), %rbx
100003198: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
10000319f: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000031a6: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000031ad: 48 85 c0                    	testq	%rax, %rax
1000031b0: 0f 89 03 00 00 00           	jns	0x1000031b9 <__text+0x21b9>
1000031b6: 48 01 c8                    	addq	%rcx, %rax
1000031b9: 48 39 c8                    	cmpq	%rcx, %rax
1000031bc: 0f 82 0f 00 00 00           	jb	0x1000031d1 <__text+0x21d1>
1000031c2: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000031cc: e9 74 05 00 00              	jmp	0x100003745 <__text+0x2745>
1000031d1: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000031d8: 48 01 c3                    	addq	%rax, %rbx
1000031db: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000031e2: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
1000031e9: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
1000031f0: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
1000031f7: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
1000031fe: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100003205: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
10000320c: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100003213: 4c 8d bd 88 00 00 00        	leaq	0x88(%rbp), %r15
10000321a: 48 8d bd 68 00 00 00        	leaq	0x68(%rbp), %rdi
100003221: 48 8d b5 08 00 00 00        	leaq	0x8(%rbp), %rsi
100003228: e8 ac f3 ff ff              	callq	0x1000025d9 <__text+0x15d9>
10000322d: 48 85 d2                    	testq	%rdx, %rdx
100003230: 0f 85 0f 05 00 00           	jne	0x100003745 <__text+0x2745>
100003236: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
10000323d: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003242: 48 8b 85 88 00 00 00        	movq	0x88(%rbp), %rax
100003249: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000324e: 0f 28 c7                    	movaps	%xmm7, %xmm0
100003251: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100003259: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000325d: 0f 28 f8                    	movaps	%xmm0, %xmm7
100003260: 0f 28 c6                    	movaps	%xmm6, %xmm0
100003263: 0f 28 cf                    	movaps	%xmm7, %xmm1
100003266: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000326a: f3 0f 11 85 b0 00 00 00     	movss	%xmm0, 0xb0(%rbp)
100003272: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100003279: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000327e: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100003285: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000328a: 0f 28 c7                    	movaps	%xmm7, %xmm0
10000328d: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100003295: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100003299: 0f 28 f8                    	movaps	%xmm0, %xmm7
10000329c: 0f 28 c6                    	movaps	%xmm6, %xmm0
10000329f: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000032a2: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000032a6: f3 0f 11 85 d0 00 00 00     	movss	%xmm0, 0xd0(%rbp)
1000032ae: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
1000032b5: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000032ba: f3 0f 10 85 b0 00 00 00     	movss	0xb0(%rbp), %xmm0
1000032c2: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
1000032ca: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000032ce: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000032d1: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000032d4: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000032d7: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000032db: f3 0f 11 85 e8 00 00 00     	movss	%xmm0, 0xe8(%rbp)
1000032e3: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
1000032ea: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000032ef: f3 0f 10 85 d0 00 00 00     	movss	0xd0(%rbp), %xmm0
1000032f7: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
1000032ff: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100003303: 0f 28 f8                    	movaps	%xmm0, %xmm7
100003306: 0f 28 c6                    	movaps	%xmm6, %xmm0
100003309: 0f 28 cf                    	movaps	%xmm7, %xmm1
10000330c: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003310: f3 0f 11 85 00 01 00 00     	movss	%xmm0, 0x100(%rbp)
100003318: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
10000331f: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100003326: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
10000332d: 48 8b 9d 08 01 00 00        	movq	0x108(%rbp), %rbx
100003334: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
10000333b: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003342: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100003349: 48 85 c0                    	testq	%rax, %rax
10000334c: 0f 89 03 00 00 00           	jns	0x100003355 <__text+0x2355>
100003352: 48 01 c8                    	addq	%rcx, %rax
100003355: 48 39 c8                    	cmpq	%rcx, %rax
100003358: 0f 82 0f 00 00 00           	jb	0x10000336d <__text+0x236d>
10000335e: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003368: e9 d8 03 00 00              	jmp	0x100003745 <__text+0x2745>
10000336d: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003374: 48 01 c3                    	addq	%rax, %rbx
100003377: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000337e: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003385: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
10000338c: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003393: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
10000339a: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
1000033a1: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
1000033a8: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000033af: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
1000033b6: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
1000033bd: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
1000033c4: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
1000033cb: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
1000033d2: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
1000033d9: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
1000033e0: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
1000033e7: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
1000033ee: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
1000033f5: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
1000033fc: 48 8b 9d 50 01 00 00        	movq	0x150(%rbp), %rbx
100003403: 4c 8b a3 00 00 00 00        	movq	(%rbx), %r12
10000340a: 4c 8b ad 88 01 00 00        	movq	0x188(%rbp), %r13
100003411: 4d 85 ed                    	testq	%r13, %r13
100003414: 0f 89 03 00 00 00           	jns	0x10000341d <__text+0x241d>
10000341a: 4d 01 e5                    	addq	%r12, %r13
10000341d: 4d 39 e5                    	cmpq	%r12, %r13
100003420: 0f 82 0f 00 00 00           	jb	0x100003435 <__text+0x2435>
100003426: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003430: e9 10 03 00 00              	jmp	0x100003745 <__text+0x2745>
100003435: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
10000343c: 4c 8b 9b 10 00 00 00        	movq	0x10(%rbx), %r11
100003443: 4c 01 d8                    	addq	%r11, %rax
100003446: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003450: 48 39 c8                    	cmpq	%rcx, %rax
100003453: 0f 85 5b 00 00 00           	jne	0x1000034b4 <__text+0x24b4>
100003459: 49 89 de                    	movq	%rbx, %r14
10000345c: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100003463: 4c 89 e8                    	movq	%r13, %rax
100003466: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
10000346d: 49 01 c6                    	addq	%rax, %r14
100003470: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100003477: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
10000347e: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
100003485: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
10000348c: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100003493: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
10000349a: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
1000034a1: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
1000034a8: 48 89 9d 58 01 00 00        	movq	%rbx, 0x158(%rbp)
1000034af: e9 ed 01 00 00              	jmp	0x1000036a1 <__text+0x26a1>
1000034b4: 4c 89 e6                    	movq	%r12, %rsi
1000034b7: 48 b9 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rcx
1000034c1: 48 0f af f1                 	imulq	%rcx, %rsi
1000034c5: 48 81 c6 28 00 00 00        	addq	$0x28, %rsi
1000034cc: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
1000034d6: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000034e0: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
1000034ea: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
1000034f4: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
1000034fe: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
100003508: 0f 05                       	syscall
10000350a: 0f 83 0f 00 00 00           	jae	0x10000351f <__text+0x251f>
100003510: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000351a: e9 26 02 00 00              	jmp	0x100003745 <__text+0x2745>
10000351f: 49 89 c7                    	movq	%rax, %r15
100003522: 4d 89 a7 00 00 00 00        	movq	%r12, (%r15)
100003529: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003533: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
10000353a: 49 89 87 10 00 00 00        	movq	%rax, 0x10(%r15)
100003541: 49 89 87 20 00 00 00        	movq	%rax, 0x20(%r15)
100003548: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100003552: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100003559: 49 89 b7 18 00 00 00        	movq	%rsi, 0x18(%r15)
100003560: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003567: 4d 89 fe                    	movq	%r15, %r14
10000356a: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100003571: 4c 89 e6                    	movq	%r12, %rsi
100003574: 48 b9 04 00 00 00 00 00 00 00       	movabsq	$0x4, %rcx
10000357e: 48 0f af f1                 	imulq	%rcx, %rsi
100003582: 48 85 f6                    	testq	%rsi, %rsi
100003585: 0f 84 20 00 00 00           	je	0x1000035ab <__text+0x25ab>
10000358b: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003592: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100003599: 48 83 c3 08                 	addq	$0x8, %rbx
10000359d: 49 83 c6 08                 	addq	$0x8, %r14
1000035a1: 48 83 ee 01                 	subq	$0x1, %rsi
1000035a5: 0f 85 e0 ff ff ff           	jne	0x10000358b <__text+0x258b>
1000035ab: 4d 89 fe                    	movq	%r15, %r14
1000035ae: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000035b5: 4c 89 e8                    	movq	%r13, %rax
1000035b8: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000035bf: 49 01 c6                    	addq	%rax, %r14
1000035c2: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
1000035c9: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
1000035d0: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
1000035d7: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
1000035de: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
1000035e5: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
1000035ec: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
1000035f3: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
1000035fa: 4c 89 bd 58 01 00 00        	movq	%r15, 0x158(%rbp)
100003601: 4c 8b 95 50 01 00 00        	movq	0x150(%rbp), %r10
100003608: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
10000360f: 48 85 c0                    	testq	%rax, %rax
100003612: 0f 84 89 00 00 00           	je	0x1000036a1 <__text+0x26a1>
100003618: 49 89 c3                    	movq	%rax, %r11
10000361b: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003622: f0                          	lock
100003623: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003628: 0f 85 da ff ff ff           	jne	0x100003608 <__text+0x2608>
10000362e: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003635: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
10000363c: 4c 01 d8                    	addq	%r11, %rax
10000363f: 48 85 c0                    	testq	%rax, %rax
100003642: 0f 85 59 00 00 00           	jne	0x1000036a1 <__text+0x26a1>
100003648: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
10000364f: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003659: 48 39 c8                    	cmpq	%rcx, %rax
10000365c: 0f 84 e6 ff ff ff           	je	0x100003648 <__text+0x2648>
100003662: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
10000366c: 48 39 c8                    	cmpq	%rcx, %rax
10000366f: 0f 84 2c 00 00 00           	je	0x1000036a1 <__text+0x26a1>
100003675: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
10000367f: f0                          	lock
100003680: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003685: 0f 85 bd ff ff ff           	jne	0x100003648 <__text+0x2648>
10000368b: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100003692: 4c 89 d7                    	movq	%r10, %rdi
100003695: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
10000369f: 0f 05                       	syscall
1000036a1: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
1000036a8: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000036af: 48 89 81 00 00 00 00        	movq	%rax, (%rcx)
1000036b6: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
1000036bd: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000036c2: f3 0f 10 85 e8 00 00 00     	movss	0xe8(%rbp), %xmm0
1000036ca: f3 0f 10 8d 00 01 00 00     	movss	0x100(%rbp), %xmm1
1000036d2: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000036d6: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000036d9: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000036dc: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000036df: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000036e3: 0f 28 f0                    	movaps	%xmm0, %xmm6
1000036e6: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000036ed: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
1000036f4: 48 01 c8                    	addq	%rcx, %rax
1000036f7: 71 0a                       	jno	0x100003703 <__text+0x2703>
1000036f9: ba 01 00 00 00              	movl	$0x1, %edx
1000036fe: e9 42 00 00 00              	jmp	0x100003745 <__text+0x2745>
100003703: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
10000370a: 48 8b 85 78 01 00 00        	movq	0x178(%rbp), %rax
100003711: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100003718: 66 48 0f 7e f0              	movq	%xmm6, %rax
10000371d: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100003724: e9 1f fa ff ff              	jmp	0x100003148 <__text+0x2148>
100003729: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100003730: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
100003737: 48 8b 85 80 01 00 00        	movq	0x180(%rbp), %rax
10000373e: 31 d2                       	xorl	%edx, %edx
100003740: e9 00 00 00 00              	jmp	0x100003745 <__text+0x2745>
100003745: 48 89 ec                    	movq	%rbp, %rsp
100003748: 48 81 c4 b0 01 00 00        	addq	$0x1b0, %rsp            ## imm = 0x1B0
10000374f: 5d                          	popq	%rbp
100003750: c3                          	retq
100003751: 55                          	pushq	%rbp
100003752: 48 89 e5                    	movq	%rsp, %rbp
100003755: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
10000375c: 48 89 e5                    	movq	%rsp, %rbp
10000375f: 48 89 b5 10 00 00 00        	movq	%rsi, 0x10(%rbp)
100003766: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
10000376d: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
100003774: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
10000377b: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100003782: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000378c: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003791: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000379b: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
1000037a2: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
1000037ac: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000037b3: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
1000037ba: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
1000037c1: 48 39 c8                    	cmpq	%rcx, %rax
1000037c4: 0f 9c c0                    	setl	%al
1000037c7: 48 0f b6 c0                 	movzbq	%al, %rax
1000037cb: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000037d2: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
1000037d9: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
1000037e0: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000037e7: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
1000037ee: 66 48 0f 7e f0              	movq	%xmm6, %rax
1000037f3: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
1000037fa: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100003801: 48 85 c0                    	testq	%rax, %rax
100003804: 0f 85 05 00 00 00           	jne	0x10000380f <__text+0x280f>
10000380a: e9 39 00 00 00              	jmp	0x100003848 <__text+0x2848>
10000380f: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100003819: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003820: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100003827: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
10000382e: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100003835: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
10000383c: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003841: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003848: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
10000384f: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
100003856: 48 39 c8                    	cmpq	%rcx, %rax
100003859: 0f 95 c0                    	setne	%al
10000385c: 48 0f b6 c0                 	movzbq	%al, %rax
100003860: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100003867: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
10000386e: 48 85 c0                    	testq	%rax, %rax
100003871: 0f 85 05 00 00 00           	jne	0x10000387c <__text+0x287c>
100003877: e9 93 00 00 00              	jmp	0x10000390f <__text+0x290f>
10000387c: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100003883: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
10000388a: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100003891: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100003898: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000038a2: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000038a9: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000038b0: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
1000038b7: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000038be: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000038c5: e9 61 00 00 00              	jmp	0x10000392b <__text+0x292b>
1000038ca: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
1000038d1: 48 8b 8d 10 01 00 00        	movq	0x110(%rbp), %rcx
1000038d8: 48 01 c8                    	addq	%rcx, %rax
1000038db: 71 0a                       	jno	0x1000038e7 <__text+0x28e7>
1000038dd: ba 01 00 00 00              	movl	$0x1, %edx
1000038e2: e9 cb 01 00 00              	jmp	0x100003ab2 <__text+0x2ab2>
1000038e7: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
1000038ee: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
1000038f5: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
1000038fc: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003903: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
10000390a: e9 39 ff ff ff              	jmp	0x100003848 <__text+0x2848>
10000390f: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100003916: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
10000391d: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100003924: 31 d2                       	xorl	%edx, %edx
100003926: e9 87 01 00 00              	jmp	0x100003ab2 <__text+0x2ab2>
10000392b: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100003932: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100003939: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100003940: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100003947: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
10000394e: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100003955: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
10000395c: 48 8b 8d 70 00 00 00        	movq	0x70(%rbp), %rcx
100003963: 48 39 c8                    	cmpq	%rcx, %rax
100003966: 0f 9c c0                    	setl	%al
100003969: 48 0f b6 c0                 	movzbq	%al, %rax
10000396d: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100003974: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
10000397b: 48 85 c0                    	testq	%rax, %rax
10000397e: 0f 85 05 00 00 00           	jne	0x100003989 <__text+0x2989>
100003984: e9 41 ff ff ff              	jmp	0x1000038ca <__text+0x28ca>
100003989: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100003990: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100003997: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
10000399e: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000039a5: 48 8b 9d 80 00 00 00        	movq	0x80(%rbp), %rbx
1000039ac: 48 8b 8d 88 00 00 00        	movq	0x88(%rbp), %rcx
1000039b3: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
1000039ba: 48 85 c0                    	testq	%rax, %rax
1000039bd: 0f 89 03 00 00 00           	jns	0x1000039c6 <__text+0x29c6>
1000039c3: 48 01 c8                    	addq	%rcx, %rax
1000039c6: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000039cd: 48 01 c3                    	addq	%rax, %rbx
1000039d0: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000039d7: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
1000039de: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
1000039e5: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
1000039ec: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
1000039f3: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
1000039fa: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003a01: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100003a08: 4c 8d bd b0 00 00 00        	leaq	0xb0(%rbp), %r15
100003a0f: 48 8d bd 90 00 00 00        	leaq	0x90(%rbp), %rdi
100003a16: 48 8d b5 00 00 00 00        	leaq	(%rbp), %rsi
100003a1d: e8 b7 eb ff ff              	callq	0x1000025d9 <__text+0x15d9>
100003a22: 48 85 d2                    	testq	%rdx, %rdx
100003a25: 0f 85 87 00 00 00           	jne	0x100003ab2 <__text+0x2ab2>
100003a2b: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003a32: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003a37: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100003a3e: 66 48 0f 6e f8              	movq	%rax, %xmm7
100003a43: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100003a4a: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100003a4f: 0f 28 c7                    	movaps	%xmm7, %xmm0
100003a52: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100003a56: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003a5a: 0f 28 f8                    	movaps	%xmm0, %xmm7
100003a5d: 0f 28 c6                    	movaps	%xmm6, %xmm0
100003a60: 0f 28 cf                    	movaps	%xmm7, %xmm1
100003a63: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003a67: 0f 28 f0                    	movaps	%xmm0, %xmm6
100003a6a: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100003a74: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003a7b: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003a82: 48 8b 8d f0 00 00 00        	movq	0xf0(%rbp), %rcx
100003a89: 48 01 c8                    	addq	%rcx, %rax
100003a8c: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100003a93: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100003a9a: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003aa1: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003aa6: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100003aad: e9 79 fe ff ff              	jmp	0x10000392b <__text+0x292b>
100003ab2: 48 89 ec                    	movq	%rbp, %rsp
100003ab5: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
100003abc: 5d                          	popq	%rbp
100003abd: c3                          	retq
100003abe: 55                          	pushq	%rbp
100003abf: 48 89 e5                    	movq	%rsp, %rbp
100003ac2: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
100003ac9: 48 89 e5                    	movq	%rsp, %rbp
100003acc: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
100003ad6: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
100003add: 48 8b bd 00 00 00 00        	movq	(%rbp), %rdi
100003ae4: e8 17 d5 ff ff              	callq	0x100001000 <__text>
100003ae9: 48 85 d2                    	testq	%rdx, %rdx
100003aec: 0f 85 2b 06 00 00           	jne	0x10000411d <__text+0x311d>
100003af2: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100003af9: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003b03: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
100003b0a: 48 8b 8d 08 00 00 00        	movq	0x8(%rbp), %rcx
100003b11: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100003b18: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100003b1f: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
100003b26: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003b2d: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003b34: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
100003b3b: 48 85 c0                    	testq	%rax, %rax
100003b3e: 0f 89 03 00 00 00           	jns	0x100003b47 <__text+0x2b47>
100003b44: 48 01 c8                    	addq	%rcx, %rax
100003b47: 48 85 c0                    	testq	%rax, %rax
100003b4a: 0f 89 0a 00 00 00           	jns	0x100003b5a <__text+0x2b5a>
100003b50: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003b5a: 48 39 c8                    	cmpq	%rcx, %rax
100003b5d: 0f 8e 03 00 00 00           	jle	0x100003b66 <__text+0x2b66>
100003b63: 48 89 c8                    	movq	%rcx, %rax
100003b66: 48 8b 95 18 00 00 00        	movq	0x18(%rbp), %rdx
100003b6d: 48 85 d2                    	testq	%rdx, %rdx
100003b70: 0f 89 03 00 00 00           	jns	0x100003b79 <__text+0x2b79>
100003b76: 48 01 ca                    	addq	%rcx, %rdx
100003b79: 48 85 d2                    	testq	%rdx, %rdx
100003b7c: 0f 89 0a 00 00 00           	jns	0x100003b8c <__text+0x2b8c>
100003b82: 48 ba 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdx
100003b8c: 48 39 ca                    	cmpq	%rcx, %rdx
100003b8f: 0f 8e 03 00 00 00           	jle	0x100003b98 <__text+0x2b98>
100003b95: 48 89 ca                    	movq	%rcx, %rdx
100003b98: 49 bb 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r11
100003ba2: 48 39 d0                    	cmpq	%rdx, %rax
100003ba5: 0f 8d 06 00 00 00           	jge	0x100003bb1 <__text+0x2bb1>
100003bab: 49 89 d3                    	movq	%rdx, %r11
100003bae: 49 29 c3                    	subq	%rax, %r11
100003bb1: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003bb8: 48 01 c3                    	addq	%rax, %rbx
100003bbb: 48 89 9d 20 00 00 00        	movq	%rbx, 0x20(%rbp)
100003bc2: 4c 89 9d 28 00 00 00        	movq	%r11, 0x28(%rbp)
100003bc9: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
100003bd3: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100003bda: 48 8b bd 30 00 00 00        	movq	0x30(%rbp), %rdi
100003be1: e8 1a d4 ff ff              	callq	0x100001000 <__text>
100003be6: 48 85 d2                    	testq	%rdx, %rdx
100003be9: 0f 85 2e 05 00 00           	jne	0x10000411d <__text+0x311d>
100003bef: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100003bf6: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
100003bfd: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100003c04: 48 b8 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rax
100003c0e: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100003c15: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
100003c1c: 48 8b b5 40 00 00 00        	movq	0x40(%rbp), %rsi
100003c23: e8 f9 dc ff ff              	callq	0x100001921 <__text+0x921>
100003c28: 48 85 d2                    	testq	%rdx, %rdx
100003c2b: 0f 85 ec 04 00 00           	jne	0x10000411d <__text+0x311d>
100003c31: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003c38: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003c42: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003c47: f3 0f 10 85 48 00 00 00     	movss	0x48(%rbp), %xmm0
100003c4f: 0f 28 ce                    	movaps	%xmm6, %xmm1
100003c52: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003c55: 0f 97 c0                    	seta	%al
100003c58: 48 0f b6 c0                 	movzbq	%al, %rax
100003c5c: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
100003c63: 48 b8 00 01 00 00 00 00 00 00       	movabsq	$0x100, %rax    ## imm = 0x100
100003c6d: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100003c74: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
100003c7b: 48 8b b5 60 00 00 00        	movq	0x60(%rbp), %rsi
100003c82: e8 ca fa ff ff              	callq	0x100003751 <__text+0x2751>
100003c87: 48 85 d2                    	testq	%rdx, %rdx
100003c8a: 0f 85 8d 04 00 00           	jne	0x10000411d <__text+0x311d>
100003c90: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100003c97: f3 0f 10 85 68 00 00 00     	movss	0x68(%rbp), %xmm0
100003c9f: f3 0f 10 8d 68 00 00 00     	movss	0x68(%rbp), %xmm1
100003ca7: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003caa: 0f 94 c0                    	sete	%al
100003cad: 0f 9b c1                    	setnp	%cl
100003cb0: 20 c8                       	andb	%cl, %al
100003cb2: 48 0f b6 c0                 	movzbq	%al, %rax
100003cb6: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100003cbd: 48 b8 89 88 08 3c 00 00 00 00       	movabsq	$0x3c088889, %rax ## imm = 0x3C088889
100003cc7: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100003cce: 48 8d 85 28 01 00 00        	leaq	0x128(%rbp), %rax
100003cd5: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100003cdc: 48 8b bd 80 00 00 00        	movq	0x80(%rbp), %rdi
100003ce3: 48 8d b5 20 00 00 00        	leaq	0x20(%rbp), %rsi
100003cea: 48 8b 95 78 00 00 00        	movq	0x78(%rbp), %rdx
100003cf1: e8 24 f3 ff ff              	callq	0x10000301a <__text+0x201a>
100003cf6: 48 85 d2                    	testq	%rdx, %rdx
100003cf9: 0f 85 1e 04 00 00           	jne	0x10000411d <__text+0x311d>
100003cff: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100003d06: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003d10: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003d15: f3 0f 10 85 88 00 00 00     	movss	0x88(%rbp), %xmm0
100003d1d: 0f 28 ce                    	movaps	%xmm6, %xmm1
100003d20: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003d23: 0f 97 c0                    	seta	%al
100003d26: 48 0f b6 c0                 	movzbq	%al, %rax
100003d2a: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
100003d31: 48 8b 85 98 00 00 00        	movq	0x98(%rbp), %rax
100003d38: 48 85 c0                    	testq	%rax, %rax
100003d3b: 0f 85 05 00 00 00           	jne	0x100003d46 <__text+0x2d46>
100003d41: e9 82 01 00 00              	jmp	0x100003ec8 <__text+0x2ec8>
100003d46: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003d4d: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100003d54: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003d5e: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100003d65: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100003d6c: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003d73: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003d7a: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100003d81: 48 85 c0                    	testq	%rax, %rax
100003d84: 0f 89 03 00 00 00           	jns	0x100003d8d <__text+0x2d8d>
100003d8a: 48 01 c8                    	addq	%rcx, %rax
100003d8d: 48 39 c8                    	cmpq	%rcx, %rax
100003d90: 0f 82 0f 00 00 00           	jb	0x100003da5 <__text+0x2da5>
100003d96: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003da0: e9 78 03 00 00              	jmp	0x10000411d <__text+0x311d>
100003da5: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003dac: 48 01 c3                    	addq	%rax, %rbx
100003daf: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003db6: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100003dbd: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003dc4: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100003dcb: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003dd2: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100003dd9: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003de0: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100003de7: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100003dee: 48 89 85 d8 00 00 00        	movq	%rax, 0xd8(%rbp)
100003df5: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003dff: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
100003e06: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
100003e0d: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003e14: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003e1b: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
100003e22: 48 85 c0                    	testq	%rax, %rax
100003e25: 0f 89 03 00 00 00           	jns	0x100003e2e <__text+0x2e2e>
100003e2b: 48 01 c8                    	addq	%rcx, %rax
100003e2e: 48 39 c8                    	cmpq	%rcx, %rax
100003e31: 0f 82 0f 00 00 00           	jb	0x100003e46 <__text+0x2e46>
100003e37: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003e41: e9 d7 02 00 00              	jmp	0x10000411d <__text+0x311d>
100003e46: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003e4d: 48 01 c3                    	addq	%rax, %rbx
100003e50: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003e57: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100003e5e: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003e65: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003e6c: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003e73: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100003e7a: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003e81: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100003e88: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100003e8f: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003e94: f3 0f 10 85 d8 00 00 00     	movss	0xd8(%rbp), %xmm0
100003e9c: 0f 28 ce                    	movaps	%xmm6, %xmm1
100003e9f: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003ea2: 0f 95 c0                    	setne	%al
100003ea5: 0f 9a c1                    	setp	%cl
100003ea8: 08 c8                       	orb	%cl, %al
100003eaa: 48 0f b6 c0                 	movzbq	%al, %rax
100003eae: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003eb5: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
100003ebc: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003ec3: e9 11 00 00 00              	jmp	0x100003ed9 <__text+0x2ed9>
100003ec8: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003ed2: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003ed9: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
100003ee0: 48 85 c0                    	testq	%rax, %rax
100003ee3: 0f 85 05 00 00 00           	jne	0x100003eee <__text+0x2eee>
100003ee9: e9 28 00 00 00              	jmp	0x100003f16 <__text+0x2f16>
100003eee: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100003ef5: 48 85 c0                    	testq	%rax, %rax
100003ef8: 0f 85 05 00 00 00           	jne	0x100003f03 <__text+0x2f03>
100003efe: e9 13 00 00 00              	jmp	0x100003f16 <__text+0x2f16>
100003f03: 48 8b 85 a0 00 00 00        	movq	0xa0(%rbp), %rax
100003f0a: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003f11: e9 11 00 00 00              	jmp	0x100003f27 <__text+0x2f27>
100003f16: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003f20: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003f27: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003f2e: 48 85 c0                    	testq	%rax, %rax
100003f31: 0f 84 33 00 00 00           	je	0x100003f6a <__text+0x2f6a>
100003f37: 48 8d 35 d2 10 00 00        	leaq	0x10d2(%rip), %rsi      ## 0x100005010
100003f3e: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003f45: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003f4c: 4c 89 c2                    	movq	%r8, %rdx
100003f4f: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003f59: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003f63: 0f 05                       	syscall
100003f65: e9 2e 00 00 00              	jmp	0x100003f98 <__text+0x2f98>
100003f6a: 48 8d 35 af 10 00 00        	leaq	0x10af(%rip), %rsi      ## 0x100005020
100003f71: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003f78: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003f7f: 4c 89 c2                    	movq	%r8, %rdx
100003f82: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003f8c: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003f96: 0f 05                       	syscall
100003f98: 48 8d 35 61 10 00 00        	leaq	0x1061(%rip), %rsi      ## 0x100005000
100003f9f: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003fa6: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003fad: 4c 89 c2                    	movq	%r8, %rdx
100003fb0: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003fba: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003fc4: 0f 05                       	syscall
100003fc6: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003fcd: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003fd4: 4c 8b 95 20 01 00 00        	movq	0x120(%rbp), %r10
100003fdb: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003fe2: 48 85 c0                    	testq	%rax, %rax
100003fe5: 0f 84 89 00 00 00           	je	0x100004074 <__text+0x3074>
100003feb: 49 89 c3                    	movq	%rax, %r11
100003fee: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003ff5: f0                          	lock
100003ff6: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003ffb: 0f 85 da ff ff ff           	jne	0x100003fdb <__text+0x2fdb>
100004001: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100004008: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
10000400f: 4c 01 d8                    	addq	%r11, %rax
100004012: 48 85 c0                    	testq	%rax, %rax
100004015: 0f 85 59 00 00 00           	jne	0x100004074 <__text+0x3074>
10000401b: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100004022: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
10000402c: 48 39 c8                    	cmpq	%rcx, %rax
10000402f: 0f 84 e6 ff ff ff           	je	0x10000401b <__text+0x301b>
100004035: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
10000403f: 48 39 c8                    	cmpq	%rcx, %rax
100004042: 0f 84 2c 00 00 00           	je	0x100004074 <__text+0x3074>
100004048: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100004052: f0                          	lock
100004053: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100004058: 0f 85 bd ff ff ff           	jne	0x10000401b <__text+0x301b>
10000405e: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100004065: 4c 89 d7                    	movq	%r10, %rdi
100004068: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100004072: 0f 05                       	syscall
100004074: 4c 8b 95 08 00 00 00        	movq	0x8(%rbp), %r10
10000407b: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100004082: 48 85 c0                    	testq	%rax, %rax
100004085: 0f 84 89 00 00 00           	je	0x100004114 <__text+0x3114>
10000408b: 49 89 c3                    	movq	%rax, %r11
10000408e: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100004095: f0                          	lock
100004096: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
10000409b: 0f 85 da ff ff ff           	jne	0x10000407b <__text+0x307b>
1000040a1: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
1000040a8: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
1000040af: 4c 01 d8                    	addq	%r11, %rax
1000040b2: 48 85 c0                    	testq	%rax, %rax
1000040b5: 0f 85 59 00 00 00           	jne	0x100004114 <__text+0x3114>
1000040bb: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
1000040c2: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
1000040cc: 48 39 c8                    	cmpq	%rcx, %rax
1000040cf: 0f 84 e6 ff ff ff           	je	0x1000040bb <__text+0x30bb>
1000040d5: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000040df: 48 39 c8                    	cmpq	%rcx, %rax
1000040e2: 0f 84 2c 00 00 00           	je	0x100004114 <__text+0x3114>
1000040e8: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000040f2: f0                          	lock
1000040f3: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000040f8: 0f 85 bd ff ff ff           	jne	0x1000040bb <__text+0x30bb>
1000040fe: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100004105: 4c 89 d7                    	movq	%r10, %rdi
100004108: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100004112: 0f 05                       	syscall
100004114: 31 c0                       	xorl	%eax, %eax
100004116: 31 d2                       	xorl	%edx, %edx
100004118: e9 00 00 00 00              	jmp	0x10000411d <__text+0x311d>
10000411d: 48 89 ec                    	movq	%rbp, %rsp
100004120: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
100004127: 5d                          	popq	%rbp
100004128: c3                          	retq
100004129: 53                          	pushq	%rbx
10000412a: 41 54                       	pushq	%r12
10000412c: 41 55                       	pushq	%r13
10000412e: 41 56                       	pushq	%r14
100004130: 41 57                       	pushq	%r15
100004132: e8 87 f9 ff ff              	callq	0x100003abe <__text+0x2abe>
100004137: 48 85 d2                    	testq	%rdx, %rdx
10000413a: 0f 95 c2                    	setne	%dl
10000413d: 0f b6 d2                    	movzbl	%dl, %edx
100004140: 48 89 d0                    	movq	%rdx, %rax
100004143: 41 5f                       	popq	%r15
100004145: 41 5e                       	popq	%r14
100004147: 41 5d                       	popq	%r13
100004149: 41 5c                       	popq	%r12
10000414b: 5b                          	popq	%rbx
10000414c: c3                          	retq
		...
100004ffd: 00 00                       	addb	%al, (%rax)
100004fff: 00                          	<unknown>
