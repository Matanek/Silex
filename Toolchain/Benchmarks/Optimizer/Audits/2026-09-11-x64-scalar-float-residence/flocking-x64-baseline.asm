
/private/tmp/silex-part03-evidence/flocking-x64-baseline:	file format mach-o 64-bit x86-64

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
10000106d: e9 db 08 00 00              	jmp	0x10000194d <__text+0x94d>
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
1000011a0: e9 d2 06 00 00              	jmp	0x100001877 <__text+0x877>
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
100001224: 0f 82 3b 00 00 00           	jb	0x100001265 <__text+0x265>
10000122a: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001234: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001239: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000123d: 0f 83 22 00 00 00           	jae	0x100001265 <__text+0x265>
100001243: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001248: 48 39 c8                    	cmpq	%rcx, %rax
10000124b: 0f 85 14 00 00 00           	jne	0x100001265 <__text+0x265>
100001251: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001255: 66 0f 7e d8                 	movd	%xmm3, %eax
100001259: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100001260: e9 3d 00 00 00              	jmp	0x1000012a2 <__text+0x2a2>
100001265: 48 8d 35 d4 3d 00 00        	leaq	0x3dd4(%rip), %rsi      ## 0x100005040
10000126c: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001273: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000127a: 4c 89 c2                    	movq	%r8, %rdx
10000127d: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001287: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100001291: 0f 05                       	syscall
100001293: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000129d: e9 ab 06 00 00              	jmp	0x10000194d <__text+0x94d>
1000012a2: 48 b8 00 00 e0 40 00 00 00 00       	movabsq	$0x40e00000, %rax ## imm = 0x40E00000
1000012ac: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000012b3: f3 0f 10 85 50 00 00 00     	movss	0x50(%rbp), %xmm0
1000012bb: f3 0f 10 8d 58 00 00 00     	movss	0x58(%rbp), %xmm1
1000012c3: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000012c7: f3 0f 11 85 60 00 00 00     	movss	%xmm0, 0x60(%rbp)
1000012cf: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000012d6: 48 b9 71 81 0b 5c e0 02 17 b8       	movabsq	$-0x47e8fd1fa3f47e8f, %rcx ## imm = 0xB81702E05C0B8171
1000012e0: 48 f7 e9                    	imulq	%rcx
1000012e3: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
1000012ea: 48 01 ca                    	addq	%rcx, %rdx
1000012ed: 48 c1 fa 06                 	sarq	$0x6, %rdx
1000012f1: 48 89 d0                    	movq	%rdx, %rax
1000012f4: 48 c1 e8 3f                 	shrq	$0x3f, %rax
1000012f8: 48 01 c2                    	addq	%rax, %rdx
1000012fb: 48 b8 59 00 00 00 00 00 00 00       	movabsq	$0x59, %rax
100001305: 48 0f af d0                 	imulq	%rax, %rdx
100001309: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
100001310: 48 29 d1                    	subq	%rdx, %rcx
100001313: 48 89 8d 70 00 00 00        	movq	%rcx, 0x70(%rbp)
10000131a: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100001321: 48 89 c1                    	movq	%rax, %rcx
100001324: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100001329: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
10000132d: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100001337: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000133c: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001340: 0f 82 3b 00 00 00           	jb	0x100001381 <__text+0x381>
100001346: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001350: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001355: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001359: 0f 83 22 00 00 00           	jae	0x100001381 <__text+0x381>
10000135f: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001364: 48 39 c8                    	cmpq	%rcx, %rax
100001367: 0f 85 14 00 00 00           	jne	0x100001381 <__text+0x381>
10000136d: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001371: 66 0f 7e d8                 	movd	%xmm3, %eax
100001375: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
10000137c: e9 3d 00 00 00              	jmp	0x1000013be <__text+0x3be>
100001381: 48 8d 35 30 3d 00 00        	leaq	0x3d30(%rip), %rsi      ## 0x1000050b8
100001388: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000138f: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001396: 4c 89 c2                    	movq	%r8, %rdx
100001399: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000013a3: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
1000013ad: 0f 05                       	syscall
1000013af: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000013b9: e9 8f 05 00 00              	jmp	0x10000194d <__text+0x94d>
1000013be: 48 b8 00 00 a0 40 00 00 00 00       	movabsq	$0x40a00000, %rax ## imm = 0x40A00000
1000013c8: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
1000013cf: f3 0f 10 85 78 00 00 00     	movss	0x78(%rbp), %xmm0
1000013d7: f3 0f 10 8d 80 00 00 00     	movss	0x80(%rbp), %xmm1
1000013df: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000013e3: f3 0f 11 85 88 00 00 00     	movss	%xmm0, 0x88(%rbp)
1000013eb: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000013f2: 48 b9 c5 4e ec c4 4e ec c4 4e       	movabsq	$0x4ec4ec4ec4ec4ec5, %rcx ## imm = 0x4EC4EC4EC4EC4EC5
1000013fc: 48 f7 e9                    	imulq	%rcx
1000013ff: 48 c1 fa 02                 	sarq	$0x2, %rdx
100001403: 48 89 d0                    	movq	%rdx, %rax
100001406: 48 c1 e8 3f                 	shrq	$0x3f, %rax
10000140a: 48 01 c2                    	addq	%rax, %rdx
10000140d: 48 b8 0d 00 00 00 00 00 00 00       	movabsq	$0xd, %rax
100001417: 48 0f af d0                 	imulq	%rax, %rdx
10000141b: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
100001422: 48 29 d1                    	subq	%rdx, %rcx
100001425: 48 89 8d 98 00 00 00        	movq	%rcx, 0x98(%rbp)
10000142c: 48 8b 85 98 00 00 00        	movq	0x98(%rbp), %rax
100001433: 48 89 c1                    	movq	%rax, %rcx
100001436: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
10000143b: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
10000143f: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100001449: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000144e: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001452: 0f 82 3b 00 00 00           	jb	0x100001493 <__text+0x493>
100001458: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001462: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001467: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000146b: 0f 83 22 00 00 00           	jae	0x100001493 <__text+0x493>
100001471: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001476: 48 39 c8                    	cmpq	%rcx, %rax
100001479: 0f 85 14 00 00 00           	jne	0x100001493 <__text+0x493>
10000147f: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001483: 66 0f 7e d8                 	movd	%xmm3, %eax
100001487: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
10000148e: e9 3d 00 00 00              	jmp	0x1000014d0 <__text+0x4d0>
100001493: 48 8d 35 96 3c 00 00        	leaq	0x3c96(%rip), %rsi      ## 0x100005130
10000149a: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000014a1: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000014a8: 4c 89 c2                    	movq	%r8, %rdx
1000014ab: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000014b5: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
1000014bf: 0f 05                       	syscall
1000014c1: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000014cb: e9 7d 04 00 00              	jmp	0x10000194d <__text+0x94d>
1000014d0: 48 b8 00 00 5c 42 00 00 00 00       	movabsq	$0x425c0000, %rax ## imm = 0x425C0000
1000014da: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
1000014e1: f3 0f 10 85 a0 00 00 00     	movss	0xa0(%rbp), %xmm0
1000014e9: f3 0f 10 8d a8 00 00 00     	movss	0xa8(%rbp), %xmm1
1000014f1: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000014f5: f3 0f 11 85 b0 00 00 00     	movss	%xmm0, 0xb0(%rbp)
1000014fd: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100001504: 48 b9 79 78 78 78 78 78 78 78       	movabsq	$0x7878787878787879, %rcx ## imm = 0x7878787878787879
10000150e: 48 f7 e9                    	imulq	%rcx
100001511: 48 c1 fa 03                 	sarq	$0x3, %rdx
100001515: 48 89 d0                    	movq	%rdx, %rax
100001518: 48 c1 e8 3f                 	shrq	$0x3f, %rax
10000151c: 48 01 c2                    	addq	%rax, %rdx
10000151f: 48 b8 11 00 00 00 00 00 00 00       	movabsq	$0x11, %rax
100001529: 48 0f af d0                 	imulq	%rax, %rdx
10000152d: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
100001534: 48 29 d1                    	subq	%rdx, %rcx
100001537: 48 89 8d c0 00 00 00        	movq	%rcx, 0xc0(%rbp)
10000153e: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100001545: 48 89 c1                    	movq	%rax, %rcx
100001548: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
10000154d: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100001551: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
10000155b: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001560: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001564: 0f 82 3b 00 00 00           	jb	0x1000015a5 <__text+0x5a5>
10000156a: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001574: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001579: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000157d: 0f 83 22 00 00 00           	jae	0x1000015a5 <__text+0x5a5>
100001583: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001588: 48 39 c8                    	cmpq	%rcx, %rax
10000158b: 0f 85 14 00 00 00           	jne	0x1000015a5 <__text+0x5a5>
100001591: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001595: 66 0f 7e d8                 	movd	%xmm3, %eax
100001599: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
1000015a0: e9 3d 00 00 00              	jmp	0x1000015e2 <__text+0x5e2>
1000015a5: 48 8d 35 fc 3b 00 00        	leaq	0x3bfc(%rip), %rsi      ## 0x1000051a8
1000015ac: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000015b3: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000015ba: 4c 89 c2                    	movq	%r8, %rdx
1000015bd: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000015c7: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
1000015d1: 0f 05                       	syscall
1000015d3: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000015dd: e9 6b 03 00 00              	jmp	0x10000194d <__text+0x94d>
1000015e2: 48 b8 00 00 00 41 00 00 00 00       	movabsq	$0x41000000, %rax ## imm = 0x41000000
1000015ec: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
1000015f3: f3 0f 10 85 c8 00 00 00     	movss	0xc8(%rbp), %xmm0
1000015fb: f3 0f 10 8d d0 00 00 00     	movss	0xd0(%rbp), %xmm1
100001603: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100001607: f3 0f 11 85 d8 00 00 00     	movss	%xmm0, 0xd8(%rbp)
10000160f: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
100001616: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
10000161d: 48 8b 85 88 00 00 00        	movq	0x88(%rbp), %rax
100001624: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
10000162b: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100001632: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100001639: 48 8b 85 d8 00 00 00        	movq	0xd8(%rbp), %rax
100001640: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100001647: 48 8b 9d 38 00 00 00        	movq	0x38(%rbp), %rbx
10000164e: 4c 8b a3 00 00 00 00        	movq	(%rbx), %r12
100001655: 4d 89 e5                    	movq	%r12, %r13
100001658: 49 83 c5 01                 	addq	$0x1, %r13
10000165c: 4c 89 ee                    	movq	%r13, %rsi
10000165f: 48 b9 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rcx
100001669: 48 0f af f1                 	imulq	%rcx, %rsi
10000166d: 48 81 c6 28 00 00 00        	addq	$0x28, %rsi
100001674: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
10000167e: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001688: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
100001692: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
10000169c: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
1000016a6: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
1000016b0: 0f 05                       	syscall
1000016b2: 0f 83 0f 00 00 00           	jae	0x1000016c7 <__text+0x6c7>
1000016b8: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000016c2: e9 86 02 00 00              	jmp	0x10000194d <__text+0x94d>
1000016c7: 49 89 c7                    	movq	%rax, %r15
1000016ca: 4d 89 af 00 00 00 00        	movq	%r13, (%r15)
1000016d1: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000016db: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
1000016e2: 49 89 87 10 00 00 00        	movq	%rax, 0x10(%r15)
1000016e9: 49 89 87 20 00 00 00        	movq	%rax, 0x20(%r15)
1000016f0: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000016fa: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100001701: 49 89 b7 18 00 00 00        	movq	%rsi, 0x18(%r15)
100001708: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
10000170f: 4d 89 fe                    	movq	%r15, %r14
100001712: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100001719: 4d 89 e5                    	movq	%r12, %r13
10000171c: 48 b9 04 00 00 00 00 00 00 00       	movabsq	$0x4, %rcx
100001726: 4c 0f af e9                 	imulq	%rcx, %r13
10000172a: 4d 85 ed                    	testq	%r13, %r13
10000172d: 0f 84 20 00 00 00           	je	0x100001753 <__text+0x753>
100001733: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000173a: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100001741: 48 83 c3 08                 	addq	$0x8, %rbx
100001745: 49 83 c6 08                 	addq	$0x8, %r14
100001749: 49 83 ed 01                 	subq	$0x1, %r13
10000174d: 0f 85 e0 ff ff ff           	jne	0x100001733 <__text+0x733>
100001753: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
10000175a: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100001761: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100001768: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
10000176f: 48 8b 85 f0 00 00 00        	movq	0xf0(%rbp), %rax
100001776: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
10000177d: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
100001784: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
10000178b: 4c 89 bd 00 01 00 00        	movq	%r15, 0x100(%rbp)
100001792: 4c 8b 95 38 00 00 00        	movq	0x38(%rbp), %r10
100001799: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
1000017a0: 48 85 c0                    	testq	%rax, %rax
1000017a3: 0f 84 89 00 00 00           	je	0x100001832 <__text+0x832>
1000017a9: 49 89 c3                    	movq	%rax, %r11
1000017ac: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
1000017b3: f0                          	lock
1000017b4: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
1000017b9: 0f 85 da ff ff ff           	jne	0x100001799 <__text+0x799>
1000017bf: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
1000017c6: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
1000017cd: 4c 01 d8                    	addq	%r11, %rax
1000017d0: 48 85 c0                    	testq	%rax, %rax
1000017d3: 0f 85 59 00 00 00           	jne	0x100001832 <__text+0x832>
1000017d9: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
1000017e0: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
1000017ea: 48 39 c8                    	cmpq	%rcx, %rax
1000017ed: 0f 84 e6 ff ff ff           	je	0x1000017d9 <__text+0x7d9>
1000017f3: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000017fd: 48 39 c8                    	cmpq	%rcx, %rax
100001800: 0f 84 2c 00 00 00           	je	0x100001832 <__text+0x832>
100001806: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100001810: f0                          	lock
100001811: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100001816: 0f 85 bd ff ff ff           	jne	0x1000017d9 <__text+0x7d9>
10000181c: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100001823: 4c 89 d7                    	movq	%r10, %rdi
100001826: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100001830: 0f 05                       	syscall
100001832: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100001839: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
100001840: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100001847: 48 8b 8d 28 01 00 00        	movq	0x128(%rbp), %rcx
10000184e: 48 01 c8                    	addq	%rcx, %rax
100001851: 71 0a                       	jno	0x10000185d <__text+0x85d>
100001853: ba 01 00 00 00              	movl	$0x1, %edx
100001858: e9 f0 00 00 00              	jmp	0x10000194d <__text+0x94d>
10000185d: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100001864: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
10000186b: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100001872: e9 fa f8 ff ff              	jmp	0x100001171 <__text+0x171>
100001877: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
10000187e: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100001885: 4c 8b 95 10 01 00 00        	movq	0x110(%rbp), %r10
10000188c: f0                          	lock
10000188d: 49 ff 42 08                 	incq	0x8(%r10)
100001891: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100001898: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
10000189f: 4c 8b 95 18 01 00 00        	movq	0x118(%rbp), %r10
1000018a6: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
1000018ad: 48 85 c0                    	testq	%rax, %rax
1000018b0: 0f 84 89 00 00 00           	je	0x10000193f <__text+0x93f>
1000018b6: 49 89 c3                    	movq	%rax, %r11
1000018b9: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
1000018c0: f0                          	lock
1000018c1: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
1000018c6: 0f 85 da ff ff ff           	jne	0x1000018a6 <__text+0x8a6>
1000018cc: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
1000018d3: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
1000018da: 4c 01 d8                    	addq	%r11, %rax
1000018dd: 48 85 c0                    	testq	%rax, %rax
1000018e0: 0f 85 59 00 00 00           	jne	0x10000193f <__text+0x93f>
1000018e6: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
1000018ed: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
1000018f7: 48 39 c8                    	cmpq	%rcx, %rax
1000018fa: 0f 84 e6 ff ff ff           	je	0x1000018e6 <__text+0x8e6>
100001900: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
10000190a: 48 39 c8                    	cmpq	%rcx, %rax
10000190d: 0f 84 2c 00 00 00           	je	0x10000193f <__text+0x93f>
100001913: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
10000191d: f0                          	lock
10000191e: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100001923: 0f 85 bd ff ff ff           	jne	0x1000018e6 <__text+0x8e6>
100001929: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100001930: 4c 89 d7                    	movq	%r10, %rdi
100001933: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
10000193d: 0f 05                       	syscall
10000193f: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
100001946: 31 d2                       	xorl	%edx, %edx
100001948: e9 00 00 00 00              	jmp	0x10000194d <__text+0x94d>
10000194d: 48 89 ec                    	movq	%rbp, %rsp
100001950: 48 81 c4 50 01 00 00        	addq	$0x150, %rsp            ## imm = 0x150
100001957: 5d                          	popq	%rbp
100001958: c3                          	retq
100001959: 55                          	pushq	%rbp
10000195a: 48 89 e5                    	movq	%rsp, %rbp
10000195d: 48 81 ec a0 04 00 00        	subq	$0x4a0, %rsp            ## imm = 0x4A0
100001964: 48 89 e5                    	movq	%rsp, %rbp
100001967: 48 89 b5 10 00 00 00        	movq	%rsi, 0x10(%rbp)
10000196e: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
100001975: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
10000197c: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
100001983: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
10000198a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001994: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
10000199b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000019a5: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000019ac: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
1000019b6: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
1000019bd: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000019c4: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
1000019cb: 48 39 c8                    	cmpq	%rcx, %rax
1000019ce: 0f 9c c0                    	setl	%al
1000019d1: 48 0f b6 c0                 	movzbq	%al, %rax
1000019d5: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
1000019dc: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000019e3: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
1000019ea: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
1000019f1: 48 89 85 28 04 00 00        	movq	%rax, 0x428(%rbp)
1000019f8: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000019ff: 48 89 85 48 04 00 00        	movq	%rax, 0x448(%rbp)
100001a06: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
100001a0d: 48 85 c0                    	testq	%rax, %rax
100001a10: 0f 85 05 00 00 00           	jne	0x100001a1b <__text+0xa1b>
100001a16: e9 3b 00 00 00              	jmp	0x100001a56 <__text+0xa56>
100001a1b: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001a25: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
100001a2c: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100001a33: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
100001a3a: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
100001a41: 48 89 85 28 04 00 00        	movq	%rax, 0x428(%rbp)
100001a48: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
100001a4f: 48 89 85 48 04 00 00        	movq	%rax, 0x448(%rbp)
100001a56: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
100001a5d: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
100001a64: 48 39 c8                    	cmpq	%rcx, %rax
100001a67: 0f 95 c0                    	setne	%al
100001a6a: 48 0f b6 c0                 	movzbq	%al, %rax
100001a6e: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100001a75: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
100001a7c: 48 85 c0                    	testq	%rax, %rax
100001a7f: 0f 85 05 00 00 00           	jne	0x100001a8a <__text+0xa8a>
100001a85: e9 64 01 00 00              	jmp	0x100001bee <__text+0xbee>
100001a8a: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
100001a91: 48 89 c1                    	movq	%rax, %rcx
100001a94: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100001a99: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100001a9d: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100001aa7: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001aac: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001ab0: 0f 82 3b 00 00 00           	jb	0x100001af1 <__text+0xaf1>
100001ab6: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001ac0: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001ac5: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001ac9: 0f 83 22 00 00 00           	jae	0x100001af1 <__text+0xaf1>
100001acf: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001ad4: 48 39 c8                    	cmpq	%rcx, %rax
100001ad7: 0f 85 14 00 00 00           	jne	0x100001af1 <__text+0xaf1>
100001add: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001ae1: 66 0f 7e d8                 	movd	%xmm3, %eax
100001ae5: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100001aec: e9 3d 00 00 00              	jmp	0x100001b2e <__text+0xb2e>
100001af1: 48 8d 35 c0 37 00 00        	leaq	0x37c0(%rip), %rsi      ## 0x1000052b8
100001af8: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001aff: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001b06: 4c 89 c2                    	movq	%r8, %rdx
100001b09: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001b13: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100001b1d: 0f 05                       	syscall
100001b1f: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001b29: e9 06 0d 00 00              	jmp	0x100002834 <__text+0x1834>
100001b2e: 48 b8 6f 12 83 3a 00 00 00 00       	movabsq	$0x3a83126f, %rax ## imm = 0x3A83126F
100001b38: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100001b3f: f3 0f 10 85 68 00 00 00     	movss	0x68(%rbp), %xmm0
100001b47: f3 0f 10 8d 70 00 00 00     	movss	0x70(%rbp), %xmm1
100001b4f: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001b53: f3 0f 11 85 78 00 00 00     	movss	%xmm0, 0x78(%rbp)
100001b5b: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001b62: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100001b69: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100001b70: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100001b77: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001b81: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100001b88: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100001b8f: 48 89 85 30 04 00 00        	movq	%rax, 0x430(%rbp)
100001b96: 48 8b 85 48 04 00 00        	movq	0x448(%rbp), %rax
100001b9d: 48 89 85 50 04 00 00        	movq	%rax, 0x450(%rbp)
100001ba4: e9 61 00 00 00              	jmp	0x100001c0a <__text+0xc0a>
100001ba9: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
100001bb0: 48 8b 8d 28 04 00 00        	movq	0x428(%rbp), %rcx
100001bb7: 48 01 c8                    	addq	%rcx, %rax
100001bba: 71 0a                       	jno	0x100001bc6 <__text+0xbc6>
100001bbc: ba 01 00 00 00              	movl	$0x1, %edx
100001bc1: e9 6e 0c 00 00              	jmp	0x100002834 <__text+0x1834>
100001bc6: 48 89 85 10 04 00 00        	movq	%rax, 0x410(%rbp)
100001bcd: 48 8b 85 10 04 00 00        	movq	0x410(%rbp), %rax
100001bd4: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
100001bdb: 48 8b 85 50 04 00 00        	movq	0x450(%rbp), %rax
100001be2: 48 89 85 48 04 00 00        	movq	%rax, 0x448(%rbp)
100001be9: e9 68 fe ff ff              	jmp	0x100001a56 <__text+0xa56>
100001bee: 48 8b 85 48 04 00 00        	movq	0x448(%rbp), %rax
100001bf5: 48 89 85 18 04 00 00        	movq	%rax, 0x418(%rbp)
100001bfc: 48 8b 85 18 04 00 00        	movq	0x418(%rbp), %rax
100001c03: 31 d2                       	xorl	%edx, %edx
100001c05: e9 2a 0c 00 00              	jmp	0x100002834 <__text+0x1834>
100001c0a: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100001c11: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100001c18: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100001c1f: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
100001c26: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100001c2d: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
100001c34: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001c3b: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
100001c42: 48 39 c8                    	cmpq	%rcx, %rax
100001c45: 0f 9c c0                    	setl	%al
100001c48: 48 0f b6 c0                 	movzbq	%al, %rax
100001c4c: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100001c53: 48 8b 85 a0 00 00 00        	movq	0xa0(%rbp), %rax
100001c5a: 48 85 c0                    	testq	%rax, %rax
100001c5d: 0f 85 05 00 00 00           	jne	0x100001c68 <__text+0xc68>
100001c63: e9 41 ff ff ff              	jmp	0x100001ba9 <__text+0xba9>
100001c68: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100001c6f: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100001c76: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100001c7d: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100001c84: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100001c8b: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
100001c92: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001c99: 48 85 c0                    	testq	%rax, %rax
100001c9c: 0f 89 03 00 00 00           	jns	0x100001ca5 <__text+0xca5>
100001ca2: 48 01 c8                    	addq	%rcx, %rax
100001ca5: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100001cac: 48 01 c3                    	addq	%rax, %rbx
100001caf: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001cb6: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100001cbd: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100001cc4: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100001ccb: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100001cd2: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100001cd9: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001ce0: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100001ce7: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001cf1: 48 89 85 d8 00 00 00        	movq	%rax, 0xd8(%rbp)
100001cf8: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001d02: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
100001d09: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001d13: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100001d1a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001d24: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100001d2b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001d35: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100001d3c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001d46: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100001d4d: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001d57: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100001d5e: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001d65: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100001d6c: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100001d73: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100001d7a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001d84: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100001d8b: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100001d92: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100001d99: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
100001da0: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001da7: 48 8b 85 d8 00 00 00        	movq	0xd8(%rbp), %rax
100001dae: 48 89 85 58 04 00 00        	movq	%rax, 0x458(%rbp)
100001db5: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100001dbc: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100001dc3: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
100001dca: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
100001dd1: 48 8b 85 f0 00 00 00        	movq	0xf0(%rbp), %rax
100001dd8: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
100001ddf: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100001de6: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
100001ded: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
100001df4: 48 89 85 60 04 00 00        	movq	%rax, 0x460(%rbp)
100001dfb: e9 3c 00 00 00              	jmp	0x100001e3c <__text+0xe3c>
100001e00: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001e0a: 48 89 85 08 04 00 00        	movq	%rax, 0x408(%rbp)
100001e11: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001e18: 48 8b 8d 08 04 00 00        	movq	0x408(%rbp), %rcx
100001e1f: 48 01 c8                    	addq	%rcx, %rax
100001e22: 48 89 85 00 04 00 00        	movq	%rax, 0x400(%rbp)
100001e29: 48 8b 85 00 04 00 00        	movq	0x400(%rbp), %rax
100001e30: 48 89 85 30 04 00 00        	movq	%rax, 0x430(%rbp)
100001e37: e9 ce fd ff ff              	jmp	0x100001c0a <__text+0xc0a>
100001e3c: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001e43: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100001e4a: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001e51: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100001e58: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100001e5f: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100001e66: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001e6d: 48 8b 8d 28 01 00 00        	movq	0x128(%rbp), %rcx
100001e74: 48 39 c8                    	cmpq	%rcx, %rax
100001e77: 0f 9c c0                    	setl	%al
100001e7a: 48 0f b6 c0                 	movzbq	%al, %rax
100001e7e: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
100001e85: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100001e8c: 48 85 c0                    	testq	%rax, %rax
100001e8f: 0f 85 05 00 00 00           	jne	0x100001e9a <__text+0xe9a>
100001e95: e9 e2 01 00 00              	jmp	0x10000207c <__text+0x107c>
100001e9a: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001ea1: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100001ea8: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001eaf: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100001eb6: 48 8b 9d 38 01 00 00        	movq	0x138(%rbp), %rbx
100001ebd: 48 8b 8d 40 01 00 00        	movq	0x140(%rbp), %rcx
100001ec4: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001ecb: 48 85 c0                    	testq	%rax, %rax
100001ece: 0f 89 03 00 00 00           	jns	0x100001ed7 <__text+0xed7>
100001ed4: 48 01 c8                    	addq	%rcx, %rax
100001ed7: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100001ede: 48 01 c3                    	addq	%rax, %rbx
100001ee1: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001ee8: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100001eef: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100001ef6: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100001efd: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100001f04: 48 89 85 58 01 00 00        	movq	%rax, 0x158(%rbp)
100001f0b: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001f12: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100001f19: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100001f20: 48 89 85 68 01 00 00        	movq	%rax, 0x168(%rbp)
100001f27: f3 0f 10 85 68 01 00 00     	movss	0x168(%rbp), %xmm0
100001f2f: f3 0f 10 8d 78 00 00 00     	movss	0x78(%rbp), %xmm1
100001f37: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001f3b: f3 0f 11 85 70 01 00 00     	movss	%xmm0, 0x170(%rbp)
100001f43: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001f4a: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
100001f51: f3 0f 10 85 70 01 00 00     	movss	0x170(%rbp), %xmm0
100001f59: f3 0f 10 8d 78 01 00 00     	movss	0x178(%rbp), %xmm1
100001f61: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100001f65: f3 0f 11 85 80 01 00 00     	movss	%xmm0, 0x180(%rbp)
100001f6d: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100001f74: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100001f7b: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001f82: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100001f89: f3 0f 10 85 88 01 00 00     	movss	0x188(%rbp), %xmm0
100001f91: f3 0f 10 8d 90 01 00 00     	movss	0x190(%rbp), %xmm1
100001f99: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100001f9d: f3 0f 11 85 98 01 00 00     	movss	%xmm0, 0x198(%rbp)
100001fa5: f3 0f 10 85 80 01 00 00     	movss	0x180(%rbp), %xmm0
100001fad: f3 0f 10 8d 80 01 00 00     	movss	0x180(%rbp), %xmm1
100001fb5: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001fb9: f3 0f 11 85 a0 01 00 00     	movss	%xmm0, 0x1a0(%rbp)
100001fc1: f3 0f 10 85 98 01 00 00     	movss	0x198(%rbp), %xmm0
100001fc9: f3 0f 10 8d 98 01 00 00     	movss	0x198(%rbp), %xmm1
100001fd1: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001fd5: f3 0f 11 85 a8 01 00 00     	movss	%xmm0, 0x1a8(%rbp)
100001fdd: f3 0f 10 85 a0 01 00 00     	movss	0x1a0(%rbp), %xmm0
100001fe5: f3 0f 10 8d a8 01 00 00     	movss	0x1a8(%rbp), %xmm1
100001fed: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001ff1: f3 0f 11 85 b0 01 00 00     	movss	%xmm0, 0x1b0(%rbp)
100001ff9: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002003: 48 89 85 b8 01 00 00        	movq	%rax, 0x1b8(%rbp)
10000200a: f3 0f 10 85 b0 01 00 00     	movss	0x1b0(%rbp), %xmm0
100002012: f3 0f 10 8d b8 01 00 00     	movss	0x1b8(%rbp), %xmm1
10000201a: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
10000201d: 0f 97 c0                    	seta	%al
100002020: 48 0f b6 c0                 	movzbq	%al, %rax
100002024: 48 89 85 c0 01 00 00        	movq	%rax, 0x1c0(%rbp)
10000202b: 48 8b 85 c0 01 00 00        	movq	0x1c0(%rbp), %rax
100002032: 48 85 c0                    	testq	%rax, %rax
100002035: 0f 85 86 00 00 00           	jne	0x1000020c1 <__text+0x10c1>
10000203b: e9 00 00 00 00              	jmp	0x100002040 <__text+0x1040>
100002040: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000204a: 48 89 85 b8 02 00 00        	movq	%rax, 0x2b8(%rbp)
100002051: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100002058: 48 8b 8d b8 02 00 00        	movq	0x2b8(%rbp), %rcx
10000205f: 48 01 c8                    	addq	%rcx, %rax
100002062: 48 89 85 b0 02 00 00        	movq	%rax, 0x2b0(%rbp)
100002069: 48 8b 85 b0 02 00 00        	movq	0x2b0(%rbp), %rax
100002070: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100002077: e9 c0 fd ff ff              	jmp	0x100001e3c <__text+0xe3c>
10000207c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002086: 48 89 85 c0 02 00 00        	movq	%rax, 0x2c0(%rbp)
10000208d: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100002094: 48 8b 8d c0 02 00 00        	movq	0x2c0(%rbp), %rcx
10000209b: 48 39 c8                    	cmpq	%rcx, %rax
10000209e: 0f 9f c0                    	setg	%al
1000020a1: 48 0f b6 c0                 	movzbq	%al, %rax
1000020a5: 48 89 85 c8 02 00 00        	movq	%rax, 0x2c8(%rbp)
1000020ac: 48 8b 85 c8 02 00 00        	movq	0x2c8(%rbp), %rax
1000020b3: 48 85 c0                    	testq	%rax, %rax
1000020b6: 0f 85 91 03 00 00           	jne	0x10000244d <__text+0x144d>
1000020bc: e9 3f fd ff ff              	jmp	0x100001e00 <__text+0xe00>
1000020c1: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
1000020cb: 48 89 85 c8 01 00 00        	movq	%rax, 0x1c8(%rbp)
1000020d2: f3 0f 10 85 b0 01 00 00     	movss	0x1b0(%rbp), %xmm0
1000020da: f3 0f 10 8d c8 01 00 00     	movss	0x1c8(%rbp), %xmm1
1000020e2: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
1000020e5: 0f 92 c0                    	setb	%al
1000020e8: 0f 9b c1                    	setnp	%cl
1000020eb: 20 c8                       	andb	%cl, %al
1000020ed: 48 0f b6 c0                 	movzbq	%al, %rax
1000020f1: 48 89 85 d0 01 00 00        	movq	%rax, 0x1d0(%rbp)
1000020f8: 48 8b 85 d0 01 00 00        	movq	0x1d0(%rbp), %rax
1000020ff: 48 85 c0                    	testq	%rax, %rax
100002102: 0f 85 05 00 00 00           	jne	0x10000210d <__text+0x110d>
100002108: e9 33 ff ff ff              	jmp	0x100002040 <__text+0x1040>
10000210d: 48 8b 85 68 04 00 00        	movq	0x468(%rbp), %rax
100002114: 48 89 85 d8 01 00 00        	movq	%rax, 0x1d8(%rbp)
10000211b: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100002122: 48 89 85 e0 01 00 00        	movq	%rax, 0x1e0(%rbp)
100002129: 48 8b 85 70 04 00 00        	movq	0x470(%rbp), %rax
100002130: 48 89 85 f0 01 00 00        	movq	%rax, 0x1f0(%rbp)
100002137: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
10000213e: 48 89 85 f8 01 00 00        	movq	%rax, 0x1f8(%rbp)
100002145: f3 0f 10 9d d8 01 00 00     	movss	0x1d8(%rbp), %xmm3
10000214d: f3 0f 10 ad f0 01 00 00     	movss	0x1f0(%rbp), %xmm5
100002155: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002158: f3 0f 10 a5 e0 01 00 00     	movss	0x1e0(%rbp), %xmm4
100002160: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100002168: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
10000216b: 0f 28 c3                    	movaps	%xmm3, %xmm0
10000216e: 0f 58 c4                    	addps	%xmm4, %xmm0
100002171: f3 0f 11 85 e8 01 00 00     	movss	%xmm0, 0x1e8(%rbp)
100002179: 0f 28 e8                    	movaps	%xmm0, %xmm5
10000217c: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002180: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
100002188: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
10000218f: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
100002196: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
10000219d: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
1000021a4: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
1000021ab: 48 89 85 20 02 00 00        	movq	%rax, 0x220(%rbp)
1000021b2: 48 8b 85 60 01 00 00        	movq	0x160(%rbp), %rax
1000021b9: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
1000021c0: f3 0f 10 9d 08 02 00 00     	movss	0x208(%rbp), %xmm3
1000021c8: f3 0f 10 ad 20 02 00 00     	movss	0x220(%rbp), %xmm5
1000021d0: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
1000021d3: f3 0f 10 a5 10 02 00 00     	movss	0x210(%rbp), %xmm4
1000021db: f3 0f 10 ad 28 02 00 00     	movss	0x228(%rbp), %xmm5
1000021e3: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
1000021e6: 0f 28 cb                    	movaps	%xmm3, %xmm1
1000021e9: 0f 58 cc                    	addps	%xmm4, %xmm1
1000021ec: f3 0f 11 8d 18 02 00 00     	movss	%xmm1, 0x218(%rbp)
1000021f4: 0f 28 e9                    	movaps	%xmm1, %xmm5
1000021f7: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
1000021fb: f3 0f 11 ad 30 02 00 00     	movss	%xmm5, 0x230(%rbp)
100002203: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000220d: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
100002214: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
10000221b: 48 8b 8d 38 02 00 00        	movq	0x238(%rbp), %rcx
100002222: 48 01 c8                    	addq	%rcx, %rax
100002225: 71 0a                       	jno	0x100002231 <__text+0x1231>
100002227: ba 01 00 00 00              	movl	$0x1, %edx
10000222c: e9 03 06 00 00              	jmp	0x100002834 <__text+0x1834>
100002231: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
100002238: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
100002242: 48 89 85 48 02 00 00        	movq	%rax, 0x248(%rbp)
100002249: f3 0f 10 85 b0 01 00 00     	movss	0x1b0(%rbp), %xmm0
100002251: f3 0f 10 8d 48 02 00 00     	movss	0x248(%rbp), %xmm1
100002259: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
10000225c: 0f 92 c0                    	setb	%al
10000225f: 0f 9b c1                    	setnp	%cl
100002262: 20 c8                       	andb	%cl, %al
100002264: 48 0f b6 c0                 	movzbq	%al, %rax
100002268: 48 89 85 50 02 00 00        	movq	%rax, 0x250(%rbp)
10000226f: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
100002276: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
10000227d: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
100002284: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
10000228b: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
100002292: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100002299: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
1000022a0: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
1000022a7: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
1000022ae: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
1000022b5: 48 8b 85 50 02 00 00        	movq	0x250(%rbp), %rax
1000022bc: 48 85 c0                    	testq	%rax, %rax
1000022bf: 0f 85 05 00 00 00           	jne	0x1000022ca <__text+0x12ca>
1000022c5: e9 76 fd ff ff              	jmp	0x100002040 <__text+0x1040>
1000022ca: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
1000022d4: 48 89 85 58 02 00 00        	movq	%rax, 0x258(%rbp)
1000022db: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
1000022e5: 48 89 85 60 02 00 00        	movq	%rax, 0x260(%rbp)
1000022ec: f3 0f 10 85 b0 01 00 00     	movss	0x1b0(%rbp), %xmm0
1000022f4: f3 0f 10 8d 60 02 00 00     	movss	0x260(%rbp), %xmm1
1000022fc: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
1000022ff: 0f 97 c0                    	seta	%al
100002302: 48 0f b6 c0                 	movzbq	%al, %rax
100002306: 48 89 85 68 02 00 00        	movq	%rax, 0x268(%rbp)
10000230d: 48 8b 85 58 02 00 00        	movq	0x258(%rbp), %rax
100002314: 48 89 85 88 04 00 00        	movq	%rax, 0x488(%rbp)
10000231b: 48 8b 85 68 02 00 00        	movq	0x268(%rbp), %rax
100002322: 48 85 c0                    	testq	%rax, %rax
100002325: 0f 85 05 00 00 00           	jne	0x100002330 <__text+0x1330>
10000232b: e9 0e 00 00 00              	jmp	0x10000233e <__text+0x133e>
100002330: 48 8b 85 b0 01 00 00        	movq	0x1b0(%rbp), %rax
100002337: 48 89 85 88 04 00 00        	movq	%rax, 0x488(%rbp)
10000233e: 48 8b 85 58 04 00 00        	movq	0x458(%rbp), %rax
100002345: 48 89 85 70 02 00 00        	movq	%rax, 0x270(%rbp)
10000234c: 48 8b 85 88 04 00 00        	movq	0x488(%rbp), %rax
100002353: 48 89 85 78 02 00 00        	movq	%rax, 0x278(%rbp)
10000235a: f3 0f 10 85 80 01 00 00     	movss	0x180(%rbp), %xmm0
100002362: f3 0f 10 8d 78 02 00 00     	movss	0x278(%rbp), %xmm1
10000236a: f3 0f 5e c1                 	divss	%xmm1, %xmm0
10000236e: f3 0f 11 85 80 02 00 00     	movss	%xmm0, 0x280(%rbp)
100002376: f3 0f 10 85 70 02 00 00     	movss	0x270(%rbp), %xmm0
10000237e: f3 0f 10 8d 80 02 00 00     	movss	0x280(%rbp), %xmm1
100002386: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000238a: f3 0f 11 85 88 02 00 00     	movss	%xmm0, 0x288(%rbp)
100002392: 48 8b 85 60 04 00 00        	movq	0x460(%rbp), %rax
100002399: 48 89 85 90 02 00 00        	movq	%rax, 0x290(%rbp)
1000023a0: 48 8b 85 88 04 00 00        	movq	0x488(%rbp), %rax
1000023a7: 48 89 85 98 02 00 00        	movq	%rax, 0x298(%rbp)
1000023ae: f3 0f 10 85 98 01 00 00     	movss	0x198(%rbp), %xmm0
1000023b6: f3 0f 10 8d 98 02 00 00     	movss	0x298(%rbp), %xmm1
1000023be: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000023c2: f3 0f 11 85 a0 02 00 00     	movss	%xmm0, 0x2a0(%rbp)
1000023ca: f3 0f 10 85 90 02 00 00     	movss	0x290(%rbp), %xmm0
1000023d2: f3 0f 10 8d a0 02 00 00     	movss	0x2a0(%rbp), %xmm1
1000023da: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000023de: f3 0f 11 85 a8 02 00 00     	movss	%xmm0, 0x2a8(%rbp)
1000023e6: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
1000023ed: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
1000023f4: 48 8b 85 88 02 00 00        	movq	0x288(%rbp), %rax
1000023fb: 48 89 85 58 04 00 00        	movq	%rax, 0x458(%rbp)
100002402: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
100002409: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100002410: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
100002417: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
10000241e: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100002425: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
10000242c: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
100002433: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
10000243a: 48 8b 85 a8 02 00 00        	movq	0x2a8(%rbp), %rax
100002441: 48 89 85 60 04 00 00        	movq	%rax, 0x460(%rbp)
100002448: e9 f3 fb ff ff              	jmp	0x100002040 <__text+0x1040>
10000244d: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100002454: 48 89 c1                    	movq	%rax, %rcx
100002457: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
10000245c: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100002460: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
10000246a: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000246f: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002473: 0f 82 3b 00 00 00           	jb	0x1000024b4 <__text+0x14b4>
100002479: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100002483: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002488: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000248c: 0f 83 22 00 00 00           	jae	0x1000024b4 <__text+0x14b4>
100002492: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100002497: 48 39 c8                    	cmpq	%rcx, %rax
10000249a: 0f 85 14 00 00 00           	jne	0x1000024b4 <__text+0x14b4>
1000024a0: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
1000024a4: 66 0f 7e d8                 	movd	%xmm3, %eax
1000024a8: 48 89 85 d0 02 00 00        	movq	%rax, 0x2d0(%rbp)
1000024af: e9 3d 00 00 00              	jmp	0x1000024f1 <__text+0x14f1>
1000024b4: 48 8d 35 55 2f 00 00        	leaq	0x2f55(%rip), %rsi      ## 0x100005410
1000024bb: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000024c2: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000024c9: 4c 89 c2                    	movq	%r8, %rdx
1000024cc: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000024d6: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
1000024e0: 0f 05                       	syscall
1000024e2: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000024ec: e9 43 03 00 00              	jmp	0x100002834 <__text+0x1834>
1000024f1: 48 8b 85 50 04 00 00        	movq	0x450(%rbp), %rax
1000024f8: 48 89 85 d8 02 00 00        	movq	%rax, 0x2d8(%rbp)
1000024ff: 48 8b 85 68 04 00 00        	movq	0x468(%rbp), %rax
100002506: 48 89 85 e0 02 00 00        	movq	%rax, 0x2e0(%rbp)
10000250d: f3 0f 10 85 e0 02 00 00     	movss	0x2e0(%rbp), %xmm0
100002515: f3 0f 10 8d d0 02 00 00     	movss	0x2d0(%rbp), %xmm1
10000251d: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002521: f3 0f 11 85 e8 02 00 00     	movss	%xmm0, 0x2e8(%rbp)
100002529: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100002530: 48 89 85 f0 02 00 00        	movq	%rax, 0x2f0(%rbp)
100002537: f3 0f 10 85 e8 02 00 00     	movss	0x2e8(%rbp), %xmm0
10000253f: f3 0f 10 8d f0 02 00 00     	movss	0x2f0(%rbp), %xmm1
100002547: f3 0f 5c c1                 	subss	%xmm1, %xmm0
10000254b: f3 0f 11 85 f8 02 00 00     	movss	%xmm0, 0x2f8(%rbp)
100002553: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
10000255d: 48 89 85 00 03 00 00        	movq	%rax, 0x300(%rbp)
100002564: f3 0f 10 85 f8 02 00 00     	movss	0x2f8(%rbp), %xmm0
10000256c: f3 0f 10 8d 00 03 00 00     	movss	0x300(%rbp), %xmm1
100002574: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002578: f3 0f 11 85 08 03 00 00     	movss	%xmm0, 0x308(%rbp)
100002580: 48 8b 85 70 04 00 00        	movq	0x470(%rbp), %rax
100002587: 48 89 85 10 03 00 00        	movq	%rax, 0x310(%rbp)
10000258e: f3 0f 10 85 10 03 00 00     	movss	0x310(%rbp), %xmm0
100002596: f3 0f 10 8d d0 02 00 00     	movss	0x2d0(%rbp), %xmm1
10000259e: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000025a2: f3 0f 11 85 18 03 00 00     	movss	%xmm0, 0x318(%rbp)
1000025aa: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
1000025b1: 48 89 85 20 03 00 00        	movq	%rax, 0x320(%rbp)
1000025b8: f3 0f 10 85 18 03 00 00     	movss	0x318(%rbp), %xmm0
1000025c0: f3 0f 10 8d 20 03 00 00     	movss	0x320(%rbp), %xmm1
1000025c8: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000025cc: f3 0f 11 85 28 03 00 00     	movss	%xmm0, 0x328(%rbp)
1000025d4: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
1000025de: 48 89 85 30 03 00 00        	movq	%rax, 0x330(%rbp)
1000025e5: f3 0f 10 85 28 03 00 00     	movss	0x328(%rbp), %xmm0
1000025ed: f3 0f 10 8d 30 03 00 00     	movss	0x330(%rbp), %xmm1
1000025f5: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000025f9: f3 0f 11 85 38 03 00 00     	movss	%xmm0, 0x338(%rbp)
100002601: f3 0f 10 85 08 03 00 00     	movss	0x308(%rbp), %xmm0
100002609: f3 0f 10 8d 38 03 00 00     	movss	0x338(%rbp), %xmm1
100002611: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002615: f3 0f 11 85 40 03 00 00     	movss	%xmm0, 0x340(%rbp)
10000261d: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
100002624: 48 89 85 48 03 00 00        	movq	%rax, 0x348(%rbp)
10000262b: f3 0f 10 85 48 03 00 00     	movss	0x348(%rbp), %xmm0
100002633: f3 0f 10 8d d0 02 00 00     	movss	0x2d0(%rbp), %xmm1
10000263b: f3 0f 5e c1                 	divss	%xmm1, %xmm0
10000263f: f3 0f 11 85 50 03 00 00     	movss	%xmm0, 0x350(%rbp)
100002647: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
10000264e: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
100002655: f3 0f 10 85 50 03 00 00     	movss	0x350(%rbp), %xmm0
10000265d: f3 0f 10 8d 58 03 00 00     	movss	0x358(%rbp), %xmm1
100002665: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002669: f3 0f 11 85 60 03 00 00     	movss	%xmm0, 0x360(%rbp)
100002671: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
10000267b: 48 89 85 68 03 00 00        	movq	%rax, 0x368(%rbp)
100002682: f3 0f 10 85 60 03 00 00     	movss	0x360(%rbp), %xmm0
10000268a: f3 0f 10 8d 68 03 00 00     	movss	0x368(%rbp), %xmm1
100002692: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002696: f3 0f 11 85 70 03 00 00     	movss	%xmm0, 0x370(%rbp)
10000269e: f3 0f 10 85 40 03 00 00     	movss	0x340(%rbp), %xmm0
1000026a6: f3 0f 10 8d 70 03 00 00     	movss	0x370(%rbp), %xmm1
1000026ae: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000026b2: f3 0f 11 85 78 03 00 00     	movss	%xmm0, 0x378(%rbp)
1000026ba: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
1000026c1: 48 89 85 80 03 00 00        	movq	%rax, 0x380(%rbp)
1000026c8: f3 0f 10 85 80 03 00 00     	movss	0x380(%rbp), %xmm0
1000026d0: f3 0f 10 8d d0 02 00 00     	movss	0x2d0(%rbp), %xmm1
1000026d8: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000026dc: f3 0f 11 85 88 03 00 00     	movss	%xmm0, 0x388(%rbp)
1000026e4: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
1000026eb: 48 89 85 90 03 00 00        	movq	%rax, 0x390(%rbp)
1000026f2: f3 0f 10 85 88 03 00 00     	movss	0x388(%rbp), %xmm0
1000026fa: f3 0f 10 8d 90 03 00 00     	movss	0x390(%rbp), %xmm1
100002702: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002706: f3 0f 11 85 98 03 00 00     	movss	%xmm0, 0x398(%rbp)
10000270e: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002718: 48 89 85 a0 03 00 00        	movq	%rax, 0x3a0(%rbp)
10000271f: f3 0f 10 85 98 03 00 00     	movss	0x398(%rbp), %xmm0
100002727: f3 0f 10 8d a0 03 00 00     	movss	0x3a0(%rbp), %xmm1
10000272f: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002733: f3 0f 11 85 a8 03 00 00     	movss	%xmm0, 0x3a8(%rbp)
10000273b: f3 0f 10 85 78 03 00 00     	movss	0x378(%rbp), %xmm0
100002743: f3 0f 10 8d a8 03 00 00     	movss	0x3a8(%rbp), %xmm1
10000274b: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000274f: f3 0f 11 85 b0 03 00 00     	movss	%xmm0, 0x3b0(%rbp)
100002757: 48 8b 85 58 04 00 00        	movq	0x458(%rbp), %rax
10000275e: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
100002765: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
10000276f: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
100002776: f3 0f 10 85 b8 03 00 00     	movss	0x3b8(%rbp), %xmm0
10000277e: f3 0f 10 8d c0 03 00 00     	movss	0x3c0(%rbp), %xmm1
100002786: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000278a: f3 0f 11 85 c8 03 00 00     	movss	%xmm0, 0x3c8(%rbp)
100002792: f3 0f 10 85 b0 03 00 00     	movss	0x3b0(%rbp), %xmm0
10000279a: f3 0f 10 8d c8 03 00 00     	movss	0x3c8(%rbp), %xmm1
1000027a2: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000027a6: f3 0f 11 85 d0 03 00 00     	movss	%xmm0, 0x3d0(%rbp)
1000027ae: 48 8b 85 60 04 00 00        	movq	0x460(%rbp), %rax
1000027b5: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
1000027bc: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
1000027c6: 48 89 85 e0 03 00 00        	movq	%rax, 0x3e0(%rbp)
1000027cd: f3 0f 10 85 d8 03 00 00     	movss	0x3d8(%rbp), %xmm0
1000027d5: f3 0f 10 8d e0 03 00 00     	movss	0x3e0(%rbp), %xmm1
1000027dd: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000027e1: f3 0f 11 85 e8 03 00 00     	movss	%xmm0, 0x3e8(%rbp)
1000027e9: f3 0f 10 85 d0 03 00 00     	movss	0x3d0(%rbp), %xmm0
1000027f1: f3 0f 10 8d e8 03 00 00     	movss	0x3e8(%rbp), %xmm1
1000027f9: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000027fd: f3 0f 11 85 f0 03 00 00     	movss	%xmm0, 0x3f0(%rbp)
100002805: f3 0f 10 85 d8 02 00 00     	movss	0x2d8(%rbp), %xmm0
10000280d: f3 0f 10 8d f0 03 00 00     	movss	0x3f0(%rbp), %xmm1
100002815: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002819: f3 0f 11 85 f8 03 00 00     	movss	%xmm0, 0x3f8(%rbp)
100002821: 48 8b 85 f8 03 00 00        	movq	0x3f8(%rbp), %rax
100002828: 48 89 85 50 04 00 00        	movq	%rax, 0x450(%rbp)
10000282f: e9 cc f5 ff ff              	jmp	0x100001e00 <__text+0xe00>
100002834: 48 89 ec                    	movq	%rbp, %rsp
100002837: 48 81 c4 a0 04 00 00        	addq	$0x4a0, %rsp            ## imm = 0x4A0
10000283e: 5d                          	popq	%rbp
10000283f: c3                          	retq
100002840: 55                          	pushq	%rbp
100002841: 48 89 e5                    	movq	%rsp, %rbp
100002844: 48 81 ec 00 04 00 00        	subq	$0x400, %rsp            ## imm = 0x400
10000284b: 48 89 e5                    	movq	%rsp, %rbp
10000284e: 4c 89 bd 30 00 00 00        	movq	%r15, 0x30(%rbp)
100002855: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
10000285c: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100002863: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
10000286a: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100002871: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
100002878: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
10000287f: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
100002886: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
10000288d: 48 8b 87 10 00 00 00        	movq	0x10(%rdi), %rax
100002894: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
10000289b: 48 8b 87 18 00 00 00        	movq	0x18(%rdi), %rax
1000028a2: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
1000028a9: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
1000028b0: 48 89 85 60 03 00 00        	movq	%rax, 0x360(%rbp)
1000028b7: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
1000028be: 48 89 85 68 03 00 00        	movq	%rax, 0x368(%rbp)
1000028c5: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
1000028cc: 48 89 85 70 03 00 00        	movq	%rax, 0x370(%rbp)
1000028d3: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
1000028da: 48 89 85 78 03 00 00        	movq	%rax, 0x378(%rbp)
1000028e1: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000028eb: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
1000028f2: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000028fc: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100002903: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000290d: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
100002914: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000291e: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100002925: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000292f: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100002936: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002940: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100002947: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002951: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100002958: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
10000295f: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100002966: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
10000296d: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100002974: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000297e: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100002985: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
10000298c: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
100002993: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
10000299a: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
1000029a1: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
1000029a8: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
1000029af: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
1000029b6: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
1000029bd: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
1000029c4: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
1000029cb: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
1000029d2: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
1000029d9: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000029e0: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
1000029e7: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
1000029ee: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
1000029f5: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000029fc: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100002a03: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100002a0a: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
100002a11: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100002a18: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
100002a1f: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
100002a26: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
100002a2d: 48 39 c8                    	cmpq	%rcx, %rax
100002a30: 0f 9c c0                    	setl	%al
100002a33: 48 0f b6 c0                 	movzbq	%al, %rax
100002a37: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100002a3e: 48 8b 85 a0 00 00 00        	movq	0xa0(%rbp), %rax
100002a45: 48 85 c0                    	testq	%rax, %rax
100002a48: 0f 85 05 00 00 00           	jne	0x100002a53 <__text+0x1a53>
100002a4e: e9 c6 01 00 00              	jmp	0x100002c19 <__text+0x1c19>
100002a53: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
100002a5a: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100002a61: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100002a68: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100002a6f: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100002a76: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
100002a7d: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
100002a84: 48 85 c0                    	testq	%rax, %rax
100002a87: 0f 89 03 00 00 00           	jns	0x100002a90 <__text+0x1a90>
100002a8d: 48 01 c8                    	addq	%rcx, %rax
100002a90: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002a97: 48 01 c3                    	addq	%rax, %rbx
100002a9a: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002aa1: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100002aa8: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002aaf: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100002ab6: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002abd: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100002ac4: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100002acb: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100002ad2: 48 8b 85 60 03 00 00        	movq	0x360(%rbp), %rax
100002ad9: 48 89 85 80 03 00 00        	movq	%rax, 0x380(%rbp)
100002ae0: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100002ae7: 48 89 85 d8 00 00 00        	movq	%rax, 0xd8(%rbp)
100002aee: f3 0f 10 85 80 03 00 00     	movss	0x380(%rbp), %xmm0
100002af6: f3 0f 10 8d d8 00 00 00     	movss	0xd8(%rbp), %xmm1
100002afe: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002b02: f3 0f 11 85 e0 00 00 00     	movss	%xmm0, 0xe0(%rbp)
100002b0a: 48 8b 85 68 03 00 00        	movq	0x368(%rbp), %rax
100002b11: 48 89 85 88 03 00 00        	movq	%rax, 0x388(%rbp)
100002b18: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100002b1f: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100002b26: f3 0f 10 85 88 03 00 00     	movss	0x388(%rbp), %xmm0
100002b2e: f3 0f 10 8d e8 00 00 00     	movss	0xe8(%rbp), %xmm1
100002b36: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002b3a: f3 0f 11 85 f0 00 00 00     	movss	%xmm0, 0xf0(%rbp)
100002b42: f3 0f 10 85 e0 00 00 00     	movss	0xe0(%rbp), %xmm0
100002b4a: f3 0f 10 8d e0 00 00 00     	movss	0xe0(%rbp), %xmm1
100002b52: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002b56: f3 0f 11 85 f8 00 00 00     	movss	%xmm0, 0xf8(%rbp)
100002b5e: f3 0f 10 85 f0 00 00 00     	movss	0xf0(%rbp), %xmm0
100002b66: f3 0f 10 8d f0 00 00 00     	movss	0xf0(%rbp), %xmm1
100002b6e: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002b72: f3 0f 11 85 00 01 00 00     	movss	%xmm0, 0x100(%rbp)
100002b7a: f3 0f 10 85 f8 00 00 00     	movss	0xf8(%rbp), %xmm0
100002b82: f3 0f 10 8d 00 01 00 00     	movss	0x100(%rbp), %xmm1
100002b8a: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002b8e: f3 0f 11 85 08 01 00 00     	movss	%xmm0, 0x108(%rbp)
100002b96: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002ba0: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100002ba7: f3 0f 10 85 08 01 00 00     	movss	0x108(%rbp), %xmm0
100002baf: f3 0f 10 8d 10 01 00 00     	movss	0x110(%rbp), %xmm1
100002bb7: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002bba: 0f 97 c0                    	seta	%al
100002bbd: 48 0f b6 c0                 	movzbq	%al, %rax
100002bc1: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100002bc8: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100002bcf: 48 85 c0                    	testq	%rax, %rax
100002bd2: 0f 85 86 00 00 00           	jne	0x100002c5e <__text+0x1c5e>
100002bd8: e9 00 00 00 00              	jmp	0x100002bdd <__text+0x1bdd>
100002bdd: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002be7: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
100002bee: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
100002bf5: 48 8b 8d 10 02 00 00        	movq	0x210(%rbp), %rcx
100002bfc: 48 01 c8                    	addq	%rcx, %rax
100002bff: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
100002c06: 48 8b 85 08 02 00 00        	movq	0x208(%rbp), %rax
100002c0d: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
100002c14: e9 dc fd ff ff              	jmp	0x1000029f5 <__text+0x19f5>
100002c19: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002c23: 48 89 85 18 02 00 00        	movq	%rax, 0x218(%rbp)
100002c2a: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002c31: 48 8b 8d 18 02 00 00        	movq	0x218(%rbp), %rcx
100002c38: 48 39 c8                    	cmpq	%rcx, %rax
100002c3b: 0f 94 c0                    	sete	%al
100002c3e: 48 0f b6 c0                 	movzbq	%al, %rax
100002c42: 48 89 85 20 02 00 00        	movq	%rax, 0x220(%rbp)
100002c49: 48 8b 85 20 02 00 00        	movq	0x220(%rbp), %rax
100002c50: 48 85 c0                    	testq	%rax, %rax
100002c53: 0f 85 9c 03 00 00           	jne	0x100002ff5 <__text+0x1ff5>
100002c59: e9 09 04 00 00              	jmp	0x100003067 <__text+0x2067>
100002c5e: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
100002c68: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100002c6f: f3 0f 10 85 08 01 00 00     	movss	0x108(%rbp), %xmm0
100002c77: f3 0f 10 8d 20 01 00 00     	movss	0x120(%rbp), %xmm1
100002c7f: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002c82: 0f 92 c0                    	setb	%al
100002c85: 0f 9b c1                    	setnp	%cl
100002c88: 20 c8                       	andb	%cl, %al
100002c8a: 48 0f b6 c0                 	movzbq	%al, %rax
100002c8e: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100002c95: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100002c9c: 48 85 c0                    	testq	%rax, %rax
100002c9f: 0f 85 05 00 00 00           	jne	0x100002caa <__text+0x1caa>
100002ca5: e9 33 ff ff ff              	jmp	0x100002bdd <__text+0x1bdd>
100002caa: 48 8b 85 c0 03 00 00        	movq	0x3c0(%rbp), %rax
100002cb1: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
100002cb8: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100002cbf: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100002cc6: 48 8b 85 c8 03 00 00        	movq	0x3c8(%rbp), %rax
100002ccd: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100002cd4: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100002cdb: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100002ce2: f3 0f 10 9d 30 01 00 00     	movss	0x130(%rbp), %xmm3
100002cea: f3 0f 10 ad 48 01 00 00     	movss	0x148(%rbp), %xmm5
100002cf2: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002cf5: f3 0f 10 a5 38 01 00 00     	movss	0x138(%rbp), %xmm4
100002cfd: f3 0f 10 ad 50 01 00 00     	movss	0x150(%rbp), %xmm5
100002d05: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002d08: 0f 28 c3                    	movaps	%xmm3, %xmm0
100002d0b: 0f 58 c4                    	addps	%xmm4, %xmm0
100002d0e: f3 0f 11 85 40 01 00 00     	movss	%xmm0, 0x140(%rbp)
100002d16: 0f 28 e8                    	movaps	%xmm0, %xmm5
100002d19: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002d1d: f3 0f 11 ad 58 01 00 00     	movss	%xmm5, 0x158(%rbp)
100002d25: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
100002d2c: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100002d33: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
100002d3a: 48 89 85 68 01 00 00        	movq	%rax, 0x168(%rbp)
100002d41: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
100002d48: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
100002d4f: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
100002d56: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
100002d5d: f3 0f 10 9d 60 01 00 00     	movss	0x160(%rbp), %xmm3
100002d65: f3 0f 10 ad 78 01 00 00     	movss	0x178(%rbp), %xmm5
100002d6d: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002d70: f3 0f 10 a5 68 01 00 00     	movss	0x168(%rbp), %xmm4
100002d78: f3 0f 10 ad 80 01 00 00     	movss	0x180(%rbp), %xmm5
100002d80: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002d83: 0f 28 cb                    	movaps	%xmm3, %xmm1
100002d86: 0f 58 cc                    	addps	%xmm4, %xmm1
100002d89: f3 0f 11 8d 70 01 00 00     	movss	%xmm1, 0x170(%rbp)
100002d91: 0f 28 e9                    	movaps	%xmm1, %xmm5
100002d94: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002d98: f3 0f 11 ad 88 01 00 00     	movss	%xmm5, 0x188(%rbp)
100002da0: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002daa: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002db1: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002db8: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
100002dbf: 48 01 c8                    	addq	%rcx, %rax
100002dc2: 71 0a                       	jno	0x100002dce <__text+0x1dce>
100002dc4: ba 01 00 00 00              	movl	$0x1, %edx
100002dc9: e9 77 06 00 00              	jmp	0x100003445 <__text+0x2445>
100002dce: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002dd5: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
100002ddf: 48 89 85 a0 01 00 00        	movq	%rax, 0x1a0(%rbp)
100002de6: f3 0f 10 85 08 01 00 00     	movss	0x108(%rbp), %xmm0
100002dee: f3 0f 10 8d a0 01 00 00     	movss	0x1a0(%rbp), %xmm1
100002df6: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002df9: 0f 92 c0                    	setb	%al
100002dfc: 0f 9b c1                    	setnp	%cl
100002dff: 20 c8                       	andb	%cl, %al
100002e01: 48 0f b6 c0                 	movzbq	%al, %rax
100002e05: 48 89 85 a8 01 00 00        	movq	%rax, 0x1a8(%rbp)
100002e0c: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100002e13: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
100002e1a: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002e21: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
100002e28: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002e2f: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
100002e36: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
100002e3d: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
100002e44: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
100002e4b: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
100002e52: 48 8b 85 a8 01 00 00        	movq	0x1a8(%rbp), %rax
100002e59: 48 85 c0                    	testq	%rax, %rax
100002e5c: 0f 85 05 00 00 00           	jne	0x100002e67 <__text+0x1e67>
100002e62: e9 76 fd ff ff              	jmp	0x100002bdd <__text+0x1bdd>
100002e67: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100002e71: 48 89 85 b0 01 00 00        	movq	%rax, 0x1b0(%rbp)
100002e78: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100002e82: 48 89 85 b8 01 00 00        	movq	%rax, 0x1b8(%rbp)
100002e89: f3 0f 10 85 08 01 00 00     	movss	0x108(%rbp), %xmm0
100002e91: f3 0f 10 8d b8 01 00 00     	movss	0x1b8(%rbp), %xmm1
100002e99: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002e9c: 0f 97 c0                    	seta	%al
100002e9f: 48 0f b6 c0                 	movzbq	%al, %rax
100002ea3: 48 89 85 c0 01 00 00        	movq	%rax, 0x1c0(%rbp)
100002eaa: 48 8b 85 b0 01 00 00        	movq	0x1b0(%rbp), %rax
100002eb1: 48 89 85 e0 03 00 00        	movq	%rax, 0x3e0(%rbp)
100002eb8: 48 8b 85 c0 01 00 00        	movq	0x1c0(%rbp), %rax
100002ebf: 48 85 c0                    	testq	%rax, %rax
100002ec2: 0f 85 05 00 00 00           	jne	0x100002ecd <__text+0x1ecd>
100002ec8: e9 0e 00 00 00              	jmp	0x100002edb <__text+0x1edb>
100002ecd: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100002ed4: 48 89 85 e0 03 00 00        	movq	%rax, 0x3e0(%rbp)
100002edb: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002ee2: 48 89 85 c8 01 00 00        	movq	%rax, 0x1c8(%rbp)
100002ee9: 48 8b 85 e0 03 00 00        	movq	0x3e0(%rbp), %rax
100002ef0: 48 89 85 d0 01 00 00        	movq	%rax, 0x1d0(%rbp)
100002ef7: f3 0f 10 85 e0 00 00 00     	movss	0xe0(%rbp), %xmm0
100002eff: f3 0f 10 8d d0 01 00 00     	movss	0x1d0(%rbp), %xmm1
100002f07: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002f0b: f3 0f 11 85 d8 01 00 00     	movss	%xmm0, 0x1d8(%rbp)
100002f13: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
100002f1a: 48 89 85 e8 01 00 00        	movq	%rax, 0x1e8(%rbp)
100002f21: 48 8b 85 e0 03 00 00        	movq	0x3e0(%rbp), %rax
100002f28: 48 89 85 f0 01 00 00        	movq	%rax, 0x1f0(%rbp)
100002f2f: f3 0f 10 85 f0 00 00 00     	movss	0xf0(%rbp), %xmm0
100002f37: f3 0f 10 8d f0 01 00 00     	movss	0x1f0(%rbp), %xmm1
100002f3f: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002f43: f3 0f 11 85 f8 01 00 00     	movss	%xmm0, 0x1f8(%rbp)
100002f4b: f3 0f 10 9d c8 01 00 00     	movss	0x1c8(%rbp), %xmm3
100002f53: f3 0f 10 ad e8 01 00 00     	movss	0x1e8(%rbp), %xmm5
100002f5b: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002f5e: f3 0f 10 a5 d8 01 00 00     	movss	0x1d8(%rbp), %xmm4
100002f66: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100002f6e: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002f71: 0f 28 d3                    	movaps	%xmm3, %xmm2
100002f74: 0f 58 d4                    	addps	%xmm4, %xmm2
100002f77: f3 0f 11 95 e0 01 00 00     	movss	%xmm2, 0x1e0(%rbp)
100002f7f: 0f 28 ea                    	movaps	%xmm2, %xmm5
100002f82: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002f86: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
100002f8e: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100002f95: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
100002f9c: 48 8b 85 e0 01 00 00        	movq	0x1e0(%rbp), %rax
100002fa3: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
100002faa: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002fb1: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
100002fb8: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
100002fbf: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
100002fc6: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
100002fcd: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
100002fd4: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002fdb: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
100002fe2: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100002fe9: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
100002ff0: e9 e8 fb ff ff              	jmp	0x100002bdd <__text+0x1bdd>
100002ff5: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002fff: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100003006: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003010: 48 89 85 30 02 00 00        	movq	%rax, 0x230(%rbp)
100003017: 48 8b 85 28 02 00 00        	movq	0x228(%rbp), %rax
10000301e: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
100003025: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
10000302c: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
100003033: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
10000303a: 48 8b 85 38 02 00 00        	movq	0x238(%rbp), %rax
100003041: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100003048: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
10000304f: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100003056: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003060: 31 d2                       	xorl	%edx, %edx
100003062: e9 de 03 00 00              	jmp	0x100003445 <__text+0x2445>
100003067: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
10000306e: 48 89 c1                    	movq	%rax, %rcx
100003071: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100003076: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
10000307a: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100003084: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100003089: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000308d: 0f 82 3b 00 00 00           	jb	0x1000030ce <__text+0x20ce>
100003093: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
10000309d: 66 48 0f 6e e2              	movq	%rdx, %xmm4
1000030a2: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
1000030a6: 0f 83 22 00 00 00           	jae	0x1000030ce <__text+0x20ce>
1000030ac: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
1000030b1: 48 39 c8                    	cmpq	%rcx, %rax
1000030b4: 0f 85 14 00 00 00           	jne	0x1000030ce <__text+0x20ce>
1000030ba: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
1000030be: 66 0f 7e d8                 	movd	%xmm3, %eax
1000030c2: 48 89 85 48 02 00 00        	movq	%rax, 0x248(%rbp)
1000030c9: e9 3d 00 00 00              	jmp	0x10000310b <__text+0x210b>
1000030ce: 48 8d 35 23 24 00 00        	leaq	0x2423(%rip), %rsi      ## 0x1000054f8
1000030d5: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000030dc: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000030e3: 4c 89 c2                    	movq	%r8, %rdx
1000030e6: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000030f0: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
1000030fa: 0f 05                       	syscall
1000030fc: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003106: e9 3a 03 00 00              	jmp	0x100003445 <__text+0x2445>
10000310b: 48 8b 85 c0 03 00 00        	movq	0x3c0(%rbp), %rax
100003112: 48 89 85 50 02 00 00        	movq	%rax, 0x250(%rbp)
100003119: f3 0f 10 85 50 02 00 00     	movss	0x250(%rbp), %xmm0
100003121: f3 0f 10 8d 48 02 00 00     	movss	0x248(%rbp), %xmm1
100003129: f3 0f 5e c1                 	divss	%xmm1, %xmm0
10000312d: f3 0f 11 85 58 02 00 00     	movss	%xmm0, 0x258(%rbp)
100003135: 48 8b 85 60 03 00 00        	movq	0x360(%rbp), %rax
10000313c: 48 89 85 90 03 00 00        	movq	%rax, 0x390(%rbp)
100003143: f3 0f 10 85 58 02 00 00     	movss	0x258(%rbp), %xmm0
10000314b: f3 0f 10 8d 90 03 00 00     	movss	0x390(%rbp), %xmm1
100003153: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100003157: f3 0f 11 85 60 02 00 00     	movss	%xmm0, 0x260(%rbp)
10000315f: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100003169: 48 89 85 68 02 00 00        	movq	%rax, 0x268(%rbp)
100003170: f3 0f 10 85 60 02 00 00     	movss	0x260(%rbp), %xmm0
100003178: f3 0f 10 8d 68 02 00 00     	movss	0x268(%rbp), %xmm1
100003180: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100003184: f3 0f 11 85 70 02 00 00     	movss	%xmm0, 0x270(%rbp)
10000318c: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
100003193: 48 89 85 78 02 00 00        	movq	%rax, 0x278(%rbp)
10000319a: f3 0f 10 85 78 02 00 00     	movss	0x278(%rbp), %xmm0
1000031a2: f3 0f 10 8d 48 02 00 00     	movss	0x248(%rbp), %xmm1
1000031aa: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000031ae: f3 0f 11 85 80 02 00 00     	movss	%xmm0, 0x280(%rbp)
1000031b6: 48 8b 85 70 03 00 00        	movq	0x370(%rbp), %rax
1000031bd: 48 89 85 98 03 00 00        	movq	%rax, 0x398(%rbp)
1000031c4: f3 0f 10 85 80 02 00 00     	movss	0x280(%rbp), %xmm0
1000031cc: f3 0f 10 8d 98 03 00 00     	movss	0x398(%rbp), %xmm1
1000031d4: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000031d8: f3 0f 11 85 88 02 00 00     	movss	%xmm0, 0x288(%rbp)
1000031e0: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
1000031ea: 48 89 85 90 02 00 00        	movq	%rax, 0x290(%rbp)
1000031f1: f3 0f 10 85 88 02 00 00     	movss	0x288(%rbp), %xmm0
1000031f9: f3 0f 10 8d 90 02 00 00     	movss	0x290(%rbp), %xmm1
100003201: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100003205: f3 0f 11 85 98 02 00 00     	movss	%xmm0, 0x298(%rbp)
10000320d: f3 0f 10 85 70 02 00 00     	movss	0x270(%rbp), %xmm0
100003215: f3 0f 10 8d 98 02 00 00     	movss	0x298(%rbp), %xmm1
10000321d: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003221: f3 0f 11 85 a0 02 00 00     	movss	%xmm0, 0x2a0(%rbp)
100003229: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100003230: 48 89 85 a8 02 00 00        	movq	%rax, 0x2a8(%rbp)
100003237: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100003241: 48 89 85 b0 02 00 00        	movq	%rax, 0x2b0(%rbp)
100003248: f3 0f 10 85 a8 02 00 00     	movss	0x2a8(%rbp), %xmm0
100003250: f3 0f 10 8d b0 02 00 00     	movss	0x2b0(%rbp), %xmm1
100003258: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000325c: f3 0f 11 85 b8 02 00 00     	movss	%xmm0, 0x2b8(%rbp)
100003264: f3 0f 10 85 a0 02 00 00     	movss	0x2a0(%rbp), %xmm0
10000326c: f3 0f 10 8d b8 02 00 00     	movss	0x2b8(%rbp), %xmm1
100003274: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003278: f3 0f 11 85 c0 02 00 00     	movss	%xmm0, 0x2c0(%rbp)
100003280: 48 8b 85 c8 03 00 00        	movq	0x3c8(%rbp), %rax
100003287: 48 89 85 c8 02 00 00        	movq	%rax, 0x2c8(%rbp)
10000328e: f3 0f 10 85 c8 02 00 00     	movss	0x2c8(%rbp), %xmm0
100003296: f3 0f 10 8d 48 02 00 00     	movss	0x248(%rbp), %xmm1
10000329e: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000032a2: f3 0f 11 85 d0 02 00 00     	movss	%xmm0, 0x2d0(%rbp)
1000032aa: 48 8b 85 68 03 00 00        	movq	0x368(%rbp), %rax
1000032b1: 48 89 85 a0 03 00 00        	movq	%rax, 0x3a0(%rbp)
1000032b8: f3 0f 10 85 d0 02 00 00     	movss	0x2d0(%rbp), %xmm0
1000032c0: f3 0f 10 8d a0 03 00 00     	movss	0x3a0(%rbp), %xmm1
1000032c8: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000032cc: f3 0f 11 85 d8 02 00 00     	movss	%xmm0, 0x2d8(%rbp)
1000032d4: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
1000032de: 48 89 85 e0 02 00 00        	movq	%rax, 0x2e0(%rbp)
1000032e5: f3 0f 10 85 d8 02 00 00     	movss	0x2d8(%rbp), %xmm0
1000032ed: f3 0f 10 8d e0 02 00 00     	movss	0x2e0(%rbp), %xmm1
1000032f5: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000032f9: f3 0f 11 85 e8 02 00 00     	movss	%xmm0, 0x2e8(%rbp)
100003301: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
100003308: 48 89 85 f0 02 00 00        	movq	%rax, 0x2f0(%rbp)
10000330f: f3 0f 10 85 f0 02 00 00     	movss	0x2f0(%rbp), %xmm0
100003317: f3 0f 10 8d 48 02 00 00     	movss	0x248(%rbp), %xmm1
10000331f: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100003323: f3 0f 11 85 f8 02 00 00     	movss	%xmm0, 0x2f8(%rbp)
10000332b: 48 8b 85 78 03 00 00        	movq	0x378(%rbp), %rax
100003332: 48 89 85 a8 03 00 00        	movq	%rax, 0x3a8(%rbp)
100003339: f3 0f 10 85 f8 02 00 00     	movss	0x2f8(%rbp), %xmm0
100003341: f3 0f 10 8d a8 03 00 00     	movss	0x3a8(%rbp), %xmm1
100003349: f3 0f 5c c1                 	subss	%xmm1, %xmm0
10000334d: f3 0f 11 85 00 03 00 00     	movss	%xmm0, 0x300(%rbp)
100003355: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
10000335f: 48 89 85 08 03 00 00        	movq	%rax, 0x308(%rbp)
100003366: f3 0f 10 85 00 03 00 00     	movss	0x300(%rbp), %xmm0
10000336e: f3 0f 10 8d 08 03 00 00     	movss	0x308(%rbp), %xmm1
100003376: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000337a: f3 0f 11 85 10 03 00 00     	movss	%xmm0, 0x310(%rbp)
100003382: f3 0f 10 85 e8 02 00 00     	movss	0x2e8(%rbp), %xmm0
10000338a: f3 0f 10 8d 10 03 00 00     	movss	0x310(%rbp), %xmm1
100003392: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003396: f3 0f 11 85 18 03 00 00     	movss	%xmm0, 0x318(%rbp)
10000339e: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
1000033a5: 48 89 85 20 03 00 00        	movq	%rax, 0x320(%rbp)
1000033ac: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
1000033b6: 48 89 85 28 03 00 00        	movq	%rax, 0x328(%rbp)
1000033bd: f3 0f 10 85 20 03 00 00     	movss	0x320(%rbp), %xmm0
1000033c5: f3 0f 10 8d 28 03 00 00     	movss	0x328(%rbp), %xmm1
1000033cd: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000033d1: f3 0f 11 85 30 03 00 00     	movss	%xmm0, 0x330(%rbp)
1000033d9: f3 0f 10 85 18 03 00 00     	movss	0x318(%rbp), %xmm0
1000033e1: f3 0f 10 8d 30 03 00 00     	movss	0x330(%rbp), %xmm1
1000033e9: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000033ed: f3 0f 11 85 38 03 00 00     	movss	%xmm0, 0x338(%rbp)
1000033f5: 48 8b 85 c0 02 00 00        	movq	0x2c0(%rbp), %rax
1000033fc: 48 89 85 40 03 00 00        	movq	%rax, 0x340(%rbp)
100003403: 48 8b 85 38 03 00 00        	movq	0x338(%rbp), %rax
10000340a: 48 89 85 48 03 00 00        	movq	%rax, 0x348(%rbp)
100003411: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100003418: 48 8b 85 40 03 00 00        	movq	0x340(%rbp), %rax
10000341f: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100003426: 48 8b 85 48 03 00 00        	movq	0x348(%rbp), %rax
10000342d: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100003434: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000343e: 31 d2                       	xorl	%edx, %edx
100003440: e9 00 00 00 00              	jmp	0x100003445 <__text+0x2445>
100003445: 48 89 ec                    	movq	%rbp, %rsp
100003448: 48 81 c4 00 04 00 00        	addq	$0x400, %rsp            ## imm = 0x400
10000344f: 5d                          	popq	%rbp
100003450: c3                          	retq
100003451: 55                          	pushq	%rbp
100003452: 48 89 e5                    	movq	%rsp, %rbp
100003455: 48 81 ec b0 01 00 00        	subq	$0x1b0, %rsp            ## imm = 0x1B0
10000345c: 48 89 e5                    	movq	%rsp, %rbp
10000345f: 48 89 95 18 00 00 00        	movq	%rdx, 0x18(%rbp)
100003466: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
10000346d: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100003474: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
10000347b: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
100003482: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
100003489: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003493: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
10000349a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000034a4: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
1000034ab: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
1000034b2: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
1000034b9: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
1000034c0: 48 8b 8d 30 00 00 00        	movq	0x30(%rbp), %rcx
1000034c7: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
1000034ce: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000034d5: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
1000034df: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000034e6: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
1000034ed: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
1000034f4: 48 39 c8                    	cmpq	%rcx, %rax
1000034f7: 0f 9c c0                    	setl	%al
1000034fa: 48 0f b6 c0                 	movzbq	%al, %rax
1000034fe: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003505: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
10000350c: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100003513: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
10000351a: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100003521: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100003528: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
10000352f: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100003536: 48 85 c0                    	testq	%rax, %rax
100003539: 0f 85 05 00 00 00           	jne	0x100003544 <__text+0x2544>
10000353f: e9 3b 00 00 00              	jmp	0x10000357f <__text+0x257f>
100003544: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000354e: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100003555: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
10000355c: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100003563: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
10000356a: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100003571: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100003578: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
10000357f: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100003586: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
10000358d: 48 39 c8                    	cmpq	%rcx, %rax
100003590: 0f 95 c0                    	setne	%al
100003593: 48 0f b6 c0                 	movzbq	%al, %rax
100003597: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
10000359e: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000035a5: 48 85 c0                    	testq	%rax, %rax
1000035a8: 0f 85 05 00 00 00           	jne	0x1000035b3 <__text+0x25b3>
1000035ae: e9 17 06 00 00              	jmp	0x100003bca <__text+0x2bca>
1000035b3: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
1000035ba: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
1000035c1: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
1000035c8: 48 8b 9d 60 00 00 00        	movq	0x60(%rbp), %rbx
1000035cf: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
1000035d6: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000035dd: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000035e4: 48 85 c0                    	testq	%rax, %rax
1000035e7: 0f 89 03 00 00 00           	jns	0x1000035f0 <__text+0x25f0>
1000035ed: 48 01 c8                    	addq	%rcx, %rax
1000035f0: 48 39 c8                    	cmpq	%rcx, %rax
1000035f3: 0f 82 0f 00 00 00           	jb	0x100003608 <__text+0x2608>
1000035f9: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003603: e9 de 05 00 00              	jmp	0x100003be6 <__text+0x2be6>
100003608: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
10000360f: 48 01 c3                    	addq	%rax, %rbx
100003612: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003619: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100003620: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003627: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
10000362e: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003635: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
10000363c: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003643: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
10000364a: 4c 8d bd 88 00 00 00        	leaq	0x88(%rbp), %r15
100003651: 48 8d bd 68 00 00 00        	leaq	0x68(%rbp), %rdi
100003658: 48 8d b5 08 00 00 00        	leaq	0x8(%rbp), %rsi
10000365f: e8 dc f1 ff ff              	callq	0x100002840 <__text+0x1840>
100003664: 48 85 d2                    	testq	%rdx, %rdx
100003667: 0f 85 79 05 00 00           	jne	0x100003be6 <__text+0x2be6>
10000366d: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
100003674: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
10000367b: 48 8b 85 88 00 00 00        	movq	0x88(%rbp), %rax
100003682: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003689: f3 0f 10 85 a0 00 00 00     	movss	0xa0(%rbp), %xmm0
100003691: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100003699: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000369d: f3 0f 11 85 a8 00 00 00     	movss	%xmm0, 0xa8(%rbp)
1000036a5: f3 0f 10 85 98 00 00 00     	movss	0x98(%rbp), %xmm0
1000036ad: f3 0f 10 8d a8 00 00 00     	movss	0xa8(%rbp), %xmm1
1000036b5: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000036b9: f3 0f 11 85 b0 00 00 00     	movss	%xmm0, 0xb0(%rbp)
1000036c1: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
1000036c8: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
1000036cf: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
1000036d6: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
1000036dd: f3 0f 10 85 c0 00 00 00     	movss	0xc0(%rbp), %xmm0
1000036e5: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
1000036ed: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000036f1: f3 0f 11 85 c8 00 00 00     	movss	%xmm0, 0xc8(%rbp)
1000036f9: f3 0f 10 85 b8 00 00 00     	movss	0xb8(%rbp), %xmm0
100003701: f3 0f 10 8d c8 00 00 00     	movss	0xc8(%rbp), %xmm1
100003709: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000370d: f3 0f 11 85 d0 00 00 00     	movss	%xmm0, 0xd0(%rbp)
100003715: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
10000371c: 48 89 85 d8 00 00 00        	movq	%rax, 0xd8(%rbp)
100003723: f3 0f 10 85 b0 00 00 00     	movss	0xb0(%rbp), %xmm0
10000372b: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100003733: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100003737: f3 0f 11 85 e0 00 00 00     	movss	%xmm0, 0xe0(%rbp)
10000373f: f3 0f 10 85 d8 00 00 00     	movss	0xd8(%rbp), %xmm0
100003747: f3 0f 10 8d e0 00 00 00     	movss	0xe0(%rbp), %xmm1
10000374f: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003753: f3 0f 11 85 e8 00 00 00     	movss	%xmm0, 0xe8(%rbp)
10000375b: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100003762: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003769: f3 0f 10 85 d0 00 00 00     	movss	0xd0(%rbp), %xmm0
100003771: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100003779: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000377d: f3 0f 11 85 f8 00 00 00     	movss	%xmm0, 0xf8(%rbp)
100003785: f3 0f 10 85 f0 00 00 00     	movss	0xf0(%rbp), %xmm0
10000378d: f3 0f 10 8d f8 00 00 00     	movss	0xf8(%rbp), %xmm1
100003795: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003799: f3 0f 11 85 00 01 00 00     	movss	%xmm0, 0x100(%rbp)
1000037a1: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
1000037a8: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
1000037af: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
1000037b6: 48 8b 9d 08 01 00 00        	movq	0x108(%rbp), %rbx
1000037bd: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
1000037c4: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000037cb: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000037d2: 48 85 c0                    	testq	%rax, %rax
1000037d5: 0f 89 03 00 00 00           	jns	0x1000037de <__text+0x27de>
1000037db: 48 01 c8                    	addq	%rcx, %rax
1000037de: 48 39 c8                    	cmpq	%rcx, %rax
1000037e1: 0f 82 0f 00 00 00           	jb	0x1000037f6 <__text+0x27f6>
1000037e7: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000037f1: e9 f0 03 00 00              	jmp	0x100003be6 <__text+0x2be6>
1000037f6: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000037fd: 48 01 c3                    	addq	%rax, %rbx
100003800: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003807: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
10000380e: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003815: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
10000381c: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003823: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
10000382a: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003831: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100003838: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
10000383f: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
100003846: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
10000384d: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100003854: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
10000385b: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100003862: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
100003869: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100003870: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100003877: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
10000387e: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100003885: 48 8b 9d 50 01 00 00        	movq	0x150(%rbp), %rbx
10000388c: 4c 8b a3 00 00 00 00        	movq	(%rbx), %r12
100003893: 4c 8b ad 88 01 00 00        	movq	0x188(%rbp), %r13
10000389a: 4d 85 ed                    	testq	%r13, %r13
10000389d: 0f 89 03 00 00 00           	jns	0x1000038a6 <__text+0x28a6>
1000038a3: 4d 01 e5                    	addq	%r12, %r13
1000038a6: 4d 39 e5                    	cmpq	%r12, %r13
1000038a9: 0f 82 0f 00 00 00           	jb	0x1000038be <__text+0x28be>
1000038af: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000038b9: e9 28 03 00 00              	jmp	0x100003be6 <__text+0x2be6>
1000038be: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
1000038c5: 4c 8b 9b 10 00 00 00        	movq	0x10(%rbx), %r11
1000038cc: 4c 01 d8                    	addq	%r11, %rax
1000038cf: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000038d9: 48 39 c8                    	cmpq	%rcx, %rax
1000038dc: 0f 85 5b 00 00 00           	jne	0x10000393d <__text+0x293d>
1000038e2: 49 89 de                    	movq	%rbx, %r14
1000038e5: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000038ec: 4c 89 e8                    	movq	%r13, %rax
1000038ef: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000038f6: 49 01 c6                    	addq	%rax, %r14
1000038f9: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100003900: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100003907: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
10000390e: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100003915: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
10000391c: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100003923: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
10000392a: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
100003931: 48 89 9d 58 01 00 00        	movq	%rbx, 0x158(%rbp)
100003938: e9 ed 01 00 00              	jmp	0x100003b2a <__text+0x2b2a>
10000393d: 4c 89 e6                    	movq	%r12, %rsi
100003940: 48 b9 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rcx
10000394a: 48 0f af f1                 	imulq	%rcx, %rsi
10000394e: 48 81 c6 28 00 00 00        	addq	$0x28, %rsi
100003955: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
10000395f: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003969: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
100003973: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
10000397d: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
100003987: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
100003991: 0f 05                       	syscall
100003993: 0f 83 0f 00 00 00           	jae	0x1000039a8 <__text+0x29a8>
100003999: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000039a3: e9 3e 02 00 00              	jmp	0x100003be6 <__text+0x2be6>
1000039a8: 49 89 c7                    	movq	%rax, %r15
1000039ab: 4d 89 a7 00 00 00 00        	movq	%r12, (%r15)
1000039b2: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000039bc: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
1000039c3: 49 89 87 10 00 00 00        	movq	%rax, 0x10(%r15)
1000039ca: 49 89 87 20 00 00 00        	movq	%rax, 0x20(%r15)
1000039d1: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000039db: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
1000039e2: 49 89 b7 18 00 00 00        	movq	%rsi, 0x18(%r15)
1000039e9: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000039f0: 4d 89 fe                    	movq	%r15, %r14
1000039f3: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000039fa: 4c 89 e6                    	movq	%r12, %rsi
1000039fd: 48 b9 04 00 00 00 00 00 00 00       	movabsq	$0x4, %rcx
100003a07: 48 0f af f1                 	imulq	%rcx, %rsi
100003a0b: 48 85 f6                    	testq	%rsi, %rsi
100003a0e: 0f 84 20 00 00 00           	je	0x100003a34 <__text+0x2a34>
100003a14: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003a1b: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100003a22: 48 83 c3 08                 	addq	$0x8, %rbx
100003a26: 49 83 c6 08                 	addq	$0x8, %r14
100003a2a: 48 83 ee 01                 	subq	$0x1, %rsi
100003a2e: 0f 85 e0 ff ff ff           	jne	0x100003a14 <__text+0x2a14>
100003a34: 4d 89 fe                    	movq	%r15, %r14
100003a37: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100003a3e: 4c 89 e8                    	movq	%r13, %rax
100003a41: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003a48: 49 01 c6                    	addq	%rax, %r14
100003a4b: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100003a52: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100003a59: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
100003a60: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100003a67: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100003a6e: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100003a75: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100003a7c: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
100003a83: 4c 89 bd 58 01 00 00        	movq	%r15, 0x158(%rbp)
100003a8a: 4c 8b 95 50 01 00 00        	movq	0x150(%rbp), %r10
100003a91: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003a98: 48 85 c0                    	testq	%rax, %rax
100003a9b: 0f 84 89 00 00 00           	je	0x100003b2a <__text+0x2b2a>
100003aa1: 49 89 c3                    	movq	%rax, %r11
100003aa4: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003aab: f0                          	lock
100003aac: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003ab1: 0f 85 da ff ff ff           	jne	0x100003a91 <__text+0x2a91>
100003ab7: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003abe: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003ac5: 4c 01 d8                    	addq	%r11, %rax
100003ac8: 48 85 c0                    	testq	%rax, %rax
100003acb: 0f 85 59 00 00 00           	jne	0x100003b2a <__text+0x2b2a>
100003ad1: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003ad8: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003ae2: 48 39 c8                    	cmpq	%rcx, %rax
100003ae5: 0f 84 e6 ff ff ff           	je	0x100003ad1 <__text+0x2ad1>
100003aeb: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003af5: 48 39 c8                    	cmpq	%rcx, %rax
100003af8: 0f 84 2c 00 00 00           	je	0x100003b2a <__text+0x2b2a>
100003afe: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100003b08: f0                          	lock
100003b09: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003b0e: 0f 85 bd ff ff ff           	jne	0x100003ad1 <__text+0x2ad1>
100003b14: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100003b1b: 4c 89 d7                    	movq	%r10, %rdi
100003b1e: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100003b28: 0f 05                       	syscall
100003b2a: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100003b31: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
100003b38: 48 89 81 00 00 00 00        	movq	%rax, (%rcx)
100003b3f: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100003b46: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100003b4d: f3 0f 10 85 e8 00 00 00     	movss	0xe8(%rbp), %xmm0
100003b55: f3 0f 10 8d 00 01 00 00     	movss	0x100(%rbp), %xmm1
100003b5d: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003b61: f3 0f 11 85 68 01 00 00     	movss	%xmm0, 0x168(%rbp)
100003b69: f3 0f 10 85 60 01 00 00     	movss	0x160(%rbp), %xmm0
100003b71: f3 0f 10 8d 68 01 00 00     	movss	0x168(%rbp), %xmm1
100003b79: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003b7d: f3 0f 11 85 70 01 00 00     	movss	%xmm0, 0x170(%rbp)
100003b85: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100003b8c: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
100003b93: 48 01 c8                    	addq	%rcx, %rax
100003b96: 71 0a                       	jno	0x100003ba2 <__text+0x2ba2>
100003b98: ba 01 00 00 00              	movl	$0x1, %edx
100003b9d: e9 44 00 00 00              	jmp	0x100003be6 <__text+0x2be6>
100003ba2: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
100003ba9: 48 8b 85 78 01 00 00        	movq	0x178(%rbp), %rax
100003bb0: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100003bb7: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
100003bbe: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100003bc5: e9 b5 f9 ff ff              	jmp	0x10000357f <__text+0x257f>
100003bca: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100003bd1: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
100003bd8: 48 8b 85 80 01 00 00        	movq	0x180(%rbp), %rax
100003bdf: 31 d2                       	xorl	%edx, %edx
100003be1: e9 00 00 00 00              	jmp	0x100003be6 <__text+0x2be6>
100003be6: 48 89 ec                    	movq	%rbp, %rsp
100003be9: 48 81 c4 b0 01 00 00        	addq	$0x1b0, %rsp            ## imm = 0x1B0
100003bf0: 5d                          	popq	%rbp
100003bf1: c3                          	retq
100003bf2: 55                          	pushq	%rbp
100003bf3: 48 89 e5                    	movq	%rsp, %rbp
100003bf6: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
100003bfd: 48 89 e5                    	movq	%rsp, %rbp
100003c00: 48 89 b5 10 00 00 00        	movq	%rsi, 0x10(%rbp)
100003c07: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
100003c0e: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
100003c15: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
100003c1c: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100003c23: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003c2d: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100003c34: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003c3e: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100003c45: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
100003c4f: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100003c56: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100003c5d: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
100003c64: 48 39 c8                    	cmpq	%rcx, %rax
100003c67: 0f 9c c0                    	setl	%al
100003c6a: 48 0f b6 c0                 	movzbq	%al, %rax
100003c6e: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100003c75: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100003c7c: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100003c83: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
100003c8a: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003c91: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100003c98: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003c9f: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100003ca6: 48 85 c0                    	testq	%rax, %rax
100003ca9: 0f 85 05 00 00 00           	jne	0x100003cb4 <__text+0x2cb4>
100003caf: e9 3b 00 00 00              	jmp	0x100003cef <__text+0x2cef>
100003cb4: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100003cbe: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003cc5: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100003ccc: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100003cd3: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100003cda: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003ce1: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100003ce8: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003cef: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100003cf6: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
100003cfd: 48 39 c8                    	cmpq	%rcx, %rax
100003d00: 0f 95 c0                    	setne	%al
100003d03: 48 0f b6 c0                 	movzbq	%al, %rax
100003d07: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100003d0e: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
100003d15: 48 85 c0                    	testq	%rax, %rax
100003d18: 0f 85 05 00 00 00           	jne	0x100003d23 <__text+0x2d23>
100003d1e: e9 93 00 00 00              	jmp	0x100003db6 <__text+0x2db6>
100003d23: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100003d2a: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100003d31: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100003d38: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100003d3f: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003d49: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
100003d50: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
100003d57: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003d5e: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100003d65: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100003d6c: e9 61 00 00 00              	jmp	0x100003dd2 <__text+0x2dd2>
100003d71: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100003d78: 48 8b 8d 10 01 00 00        	movq	0x110(%rbp), %rcx
100003d7f: 48 01 c8                    	addq	%rcx, %rax
100003d82: 71 0a                       	jno	0x100003d8e <__text+0x2d8e>
100003d84: ba 01 00 00 00              	movl	$0x1, %edx
100003d89: e9 f0 01 00 00              	jmp	0x100003f7e <__text+0x2f7e>
100003d8e: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100003d95: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
100003d9c: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100003da3: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003daa: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003db1: e9 39 ff ff ff              	jmp	0x100003cef <__text+0x2cef>
100003db6: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100003dbd: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100003dc4: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100003dcb: 31 d2                       	xorl	%edx, %edx
100003dcd: e9 ac 01 00 00              	jmp	0x100003f7e <__text+0x2f7e>
100003dd2: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100003dd9: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100003de0: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100003de7: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100003dee: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100003df5: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100003dfc: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003e03: 48 8b 8d 70 00 00 00        	movq	0x70(%rbp), %rcx
100003e0a: 48 39 c8                    	cmpq	%rcx, %rax
100003e0d: 0f 9c c0                    	setl	%al
100003e10: 48 0f b6 c0                 	movzbq	%al, %rax
100003e14: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100003e1b: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
100003e22: 48 85 c0                    	testq	%rax, %rax
100003e25: 0f 85 05 00 00 00           	jne	0x100003e30 <__text+0x2e30>
100003e2b: e9 41 ff ff ff              	jmp	0x100003d71 <__text+0x2d71>
100003e30: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100003e37: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100003e3e: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100003e45: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100003e4c: 48 8b 9d 80 00 00 00        	movq	0x80(%rbp), %rbx
100003e53: 48 8b 8d 88 00 00 00        	movq	0x88(%rbp), %rcx
100003e5a: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003e61: 48 85 c0                    	testq	%rax, %rax
100003e64: 0f 89 03 00 00 00           	jns	0x100003e6d <__text+0x2e6d>
100003e6a: 48 01 c8                    	addq	%rcx, %rax
100003e6d: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003e74: 48 01 c3                    	addq	%rax, %rbx
100003e77: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003e7e: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
100003e85: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003e8c: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
100003e93: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003e9a: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003ea1: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003ea8: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100003eaf: 4c 8d bd b0 00 00 00        	leaq	0xb0(%rbp), %r15
100003eb6: 48 8d bd 90 00 00 00        	leaq	0x90(%rbp), %rdi
100003ebd: 48 8d b5 00 00 00 00        	leaq	(%rbp), %rsi
100003ec4: e8 77 e9 ff ff              	callq	0x100002840 <__text+0x1840>
100003ec9: 48 85 d2                    	testq	%rdx, %rdx
100003ecc: 0f 85 ac 00 00 00           	jne	0x100003f7e <__text+0x2f7e>
100003ed2: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003ed9: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100003ee0: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100003ee7: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100003eee: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100003ef5: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100003efc: f3 0f 10 85 c8 00 00 00     	movss	0xc8(%rbp), %xmm0
100003f04: f3 0f 10 8d d0 00 00 00     	movss	0xd0(%rbp), %xmm1
100003f0c: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003f10: f3 0f 11 85 d8 00 00 00     	movss	%xmm0, 0xd8(%rbp)
100003f18: f3 0f 10 85 c0 00 00 00     	movss	0xc0(%rbp), %xmm0
100003f20: f3 0f 10 8d d8 00 00 00     	movss	0xd8(%rbp), %xmm1
100003f28: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003f2c: f3 0f 11 85 e0 00 00 00     	movss	%xmm0, 0xe0(%rbp)
100003f34: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100003f3e: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003f45: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003f4c: 48 8b 8d f0 00 00 00        	movq	0xf0(%rbp), %rcx
100003f53: 48 01 c8                    	addq	%rcx, %rax
100003f56: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100003f5d: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100003f64: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003f6b: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
100003f72: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100003f79: e9 54 fe ff ff              	jmp	0x100003dd2 <__text+0x2dd2>
100003f7e: 48 89 ec                    	movq	%rbp, %rsp
100003f81: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
100003f88: 5d                          	popq	%rbp
100003f89: c3                          	retq
100003f8a: 55                          	pushq	%rbp
100003f8b: 48 89 e5                    	movq	%rsp, %rbp
100003f8e: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
100003f95: 48 89 e5                    	movq	%rsp, %rbp
100003f98: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
100003fa2: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
100003fa9: 48 8b bd 00 00 00 00        	movq	(%rbp), %rdi
100003fb0: e8 4b d0 ff ff              	callq	0x100001000 <__text>
100003fb5: 48 85 d2                    	testq	%rdx, %rdx
100003fb8: 0f 85 40 06 00 00           	jne	0x1000045fe <__text+0x35fe>
100003fbe: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100003fc5: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003fcf: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
100003fd6: 48 8b 8d 08 00 00 00        	movq	0x8(%rbp), %rcx
100003fdd: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100003fe4: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100003feb: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
100003ff2: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003ff9: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100004000: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
100004007: 48 85 c0                    	testq	%rax, %rax
10000400a: 0f 89 03 00 00 00           	jns	0x100004013 <__text+0x3013>
100004010: 48 01 c8                    	addq	%rcx, %rax
100004013: 48 85 c0                    	testq	%rax, %rax
100004016: 0f 89 0a 00 00 00           	jns	0x100004026 <__text+0x3026>
10000401c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100004026: 48 39 c8                    	cmpq	%rcx, %rax
100004029: 0f 8e 03 00 00 00           	jle	0x100004032 <__text+0x3032>
10000402f: 48 89 c8                    	movq	%rcx, %rax
100004032: 48 8b 95 18 00 00 00        	movq	0x18(%rbp), %rdx
100004039: 48 85 d2                    	testq	%rdx, %rdx
10000403c: 0f 89 03 00 00 00           	jns	0x100004045 <__text+0x3045>
100004042: 48 01 ca                    	addq	%rcx, %rdx
100004045: 48 85 d2                    	testq	%rdx, %rdx
100004048: 0f 89 0a 00 00 00           	jns	0x100004058 <__text+0x3058>
10000404e: 48 ba 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdx
100004058: 48 39 ca                    	cmpq	%rcx, %rdx
10000405b: 0f 8e 03 00 00 00           	jle	0x100004064 <__text+0x3064>
100004061: 48 89 ca                    	movq	%rcx, %rdx
100004064: 49 bb 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r11
10000406e: 48 39 d0                    	cmpq	%rdx, %rax
100004071: 0f 8d 06 00 00 00           	jge	0x10000407d <__text+0x307d>
100004077: 49 89 d3                    	movq	%rdx, %r11
10000407a: 49 29 c3                    	subq	%rax, %r11
10000407d: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100004084: 48 01 c3                    	addq	%rax, %rbx
100004087: 48 89 9d 20 00 00 00        	movq	%rbx, 0x20(%rbp)
10000408e: 4c 89 9d 28 00 00 00        	movq	%r11, 0x28(%rbp)
100004095: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
10000409f: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
1000040a6: 48 8b bd 30 00 00 00        	movq	0x30(%rbp), %rdi
1000040ad: e8 4e cf ff ff              	callq	0x100001000 <__text>
1000040b2: 48 85 d2                    	testq	%rdx, %rdx
1000040b5: 0f 85 43 05 00 00           	jne	0x1000045fe <__text+0x35fe>
1000040bb: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000040c2: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000040c9: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000040d0: 48 b8 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rax
1000040da: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000040e1: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
1000040e8: 48 8b b5 40 00 00 00        	movq	0x40(%rbp), %rsi
1000040ef: e8 65 d8 ff ff              	callq	0x100001959 <__text+0x959>
1000040f4: 48 85 d2                    	testq	%rdx, %rdx
1000040f7: 0f 85 01 05 00 00           	jne	0x1000045fe <__text+0x35fe>
1000040fd: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100004104: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000410e: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100004115: f3 0f 10 85 48 00 00 00     	movss	0x48(%rbp), %xmm0
10000411d: f3 0f 10 8d 50 00 00 00     	movss	0x50(%rbp), %xmm1
100004125: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100004128: 0f 97 c0                    	seta	%al
10000412b: 48 0f b6 c0                 	movzbq	%al, %rax
10000412f: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
100004136: 48 b8 00 01 00 00 00 00 00 00       	movabsq	$0x100, %rax    ## imm = 0x100
100004140: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100004147: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
10000414e: 48 8b b5 60 00 00 00        	movq	0x60(%rbp), %rsi
100004155: e8 98 fa ff ff              	callq	0x100003bf2 <__text+0x2bf2>
10000415a: 48 85 d2                    	testq	%rdx, %rdx
10000415d: 0f 85 9b 04 00 00           	jne	0x1000045fe <__text+0x35fe>
100004163: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
10000416a: f3 0f 10 85 68 00 00 00     	movss	0x68(%rbp), %xmm0
100004172: f3 0f 10 8d 68 00 00 00     	movss	0x68(%rbp), %xmm1
10000417a: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
10000417d: 0f 94 c0                    	sete	%al
100004180: 0f 9b c1                    	setnp	%cl
100004183: 20 c8                       	andb	%cl, %al
100004185: 48 0f b6 c0                 	movzbq	%al, %rax
100004189: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100004190: 48 b8 89 88 08 3c 00 00 00 00       	movabsq	$0x3c088889, %rax ## imm = 0x3C088889
10000419a: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
1000041a1: 48 8d 85 28 01 00 00        	leaq	0x128(%rbp), %rax
1000041a8: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
1000041af: 48 8b bd 80 00 00 00        	movq	0x80(%rbp), %rdi
1000041b6: 48 8d b5 20 00 00 00        	leaq	0x20(%rbp), %rsi
1000041bd: 48 8b 95 78 00 00 00        	movq	0x78(%rbp), %rdx
1000041c4: e8 88 f2 ff ff              	callq	0x100003451 <__text+0x2451>
1000041c9: 48 85 d2                    	testq	%rdx, %rdx
1000041cc: 0f 85 2c 04 00 00           	jne	0x1000045fe <__text+0x35fe>
1000041d2: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000041d9: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000041e3: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
1000041ea: f3 0f 10 85 88 00 00 00     	movss	0x88(%rbp), %xmm0
1000041f2: f3 0f 10 8d 90 00 00 00     	movss	0x90(%rbp), %xmm1
1000041fa: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
1000041fd: 0f 97 c0                    	seta	%al
100004200: 48 0f b6 c0                 	movzbq	%al, %rax
100004204: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
10000420b: 48 8b 85 98 00 00 00        	movq	0x98(%rbp), %rax
100004212: 48 85 c0                    	testq	%rax, %rax
100004215: 0f 85 05 00 00 00           	jne	0x100004220 <__text+0x3220>
10000421b: e9 89 01 00 00              	jmp	0x1000043a9 <__text+0x33a9>
100004220: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100004227: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
10000422e: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100004238: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
10000423f: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100004246: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
10000424d: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100004254: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
10000425b: 48 85 c0                    	testq	%rax, %rax
10000425e: 0f 89 03 00 00 00           	jns	0x100004267 <__text+0x3267>
100004264: 48 01 c8                    	addq	%rcx, %rax
100004267: 48 39 c8                    	cmpq	%rcx, %rax
10000426a: 0f 82 0f 00 00 00           	jb	0x10000427f <__text+0x327f>
100004270: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000427a: e9 7f 03 00 00              	jmp	0x1000045fe <__text+0x35fe>
10000427f: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100004286: 48 01 c3                    	addq	%rax, %rbx
100004289: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100004290: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100004297: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
10000429e: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
1000042a5: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
1000042ac: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
1000042b3: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
1000042ba: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
1000042c1: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
1000042c8: 48 89 85 d8 00 00 00        	movq	%rax, 0xd8(%rbp)
1000042cf: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000042d9: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
1000042e0: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
1000042e7: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
1000042ee: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000042f5: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
1000042fc: 48 85 c0                    	testq	%rax, %rax
1000042ff: 0f 89 03 00 00 00           	jns	0x100004308 <__text+0x3308>
100004305: 48 01 c8                    	addq	%rcx, %rax
100004308: 48 39 c8                    	cmpq	%rcx, %rax
10000430b: 0f 82 0f 00 00 00           	jb	0x100004320 <__text+0x3320>
100004311: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000431b: e9 de 02 00 00              	jmp	0x1000045fe <__text+0x35fe>
100004320: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100004327: 48 01 c3                    	addq	%rax, %rbx
10000432a: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100004331: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100004338: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
10000433f: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100004346: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
10000434d: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100004354: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
10000435b: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100004362: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100004369: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100004370: f3 0f 10 85 d8 00 00 00     	movss	0xd8(%rbp), %xmm0
100004378: f3 0f 10 8d 08 01 00 00     	movss	0x108(%rbp), %xmm1
100004380: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100004383: 0f 95 c0                    	setne	%al
100004386: 0f 9a c1                    	setp	%cl
100004389: 08 c8                       	orb	%cl, %al
10000438b: 48 0f b6 c0                 	movzbq	%al, %rax
10000438f: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100004396: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
10000439d: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
1000043a4: e9 11 00 00 00              	jmp	0x1000043ba <__text+0x33ba>
1000043a9: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000043b3: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
1000043ba: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000043c1: 48 85 c0                    	testq	%rax, %rax
1000043c4: 0f 85 05 00 00 00           	jne	0x1000043cf <__text+0x33cf>
1000043ca: e9 28 00 00 00              	jmp	0x1000043f7 <__text+0x33f7>
1000043cf: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
1000043d6: 48 85 c0                    	testq	%rax, %rax
1000043d9: 0f 85 05 00 00 00           	jne	0x1000043e4 <__text+0x33e4>
1000043df: e9 13 00 00 00              	jmp	0x1000043f7 <__text+0x33f7>
1000043e4: 48 8b 85 a0 00 00 00        	movq	0xa0(%rbp), %rax
1000043eb: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
1000043f2: e9 11 00 00 00              	jmp	0x100004408 <__text+0x3408>
1000043f7: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100004401: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100004408: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
10000440f: 48 85 c0                    	testq	%rax, %rax
100004412: 0f 84 33 00 00 00           	je	0x10000444b <__text+0x344b>
100004418: 48 8d 35 f1 0b 00 00        	leaq	0xbf1(%rip), %rsi       ## 0x100005010
10000441f: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100004426: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000442d: 4c 89 c2                    	movq	%r8, %rdx
100004430: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000443a: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100004444: 0f 05                       	syscall
100004446: e9 2e 00 00 00              	jmp	0x100004479 <__text+0x3479>
10000444b: 48 8d 35 ce 0b 00 00        	leaq	0xbce(%rip), %rsi       ## 0x100005020
100004452: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100004459: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100004460: 4c 89 c2                    	movq	%r8, %rdx
100004463: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000446d: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100004477: 0f 05                       	syscall
100004479: 48 8d 35 80 0b 00 00        	leaq	0xb80(%rip), %rsi       ## 0x100005000
100004480: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100004487: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000448e: 4c 89 c2                    	movq	%r8, %rdx
100004491: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000449b: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000044a5: 0f 05                       	syscall
1000044a7: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
1000044ae: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
1000044b5: 4c 8b 95 20 01 00 00        	movq	0x120(%rbp), %r10
1000044bc: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
1000044c3: 48 85 c0                    	testq	%rax, %rax
1000044c6: 0f 84 89 00 00 00           	je	0x100004555 <__text+0x3555>
1000044cc: 49 89 c3                    	movq	%rax, %r11
1000044cf: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
1000044d6: f0                          	lock
1000044d7: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
1000044dc: 0f 85 da ff ff ff           	jne	0x1000044bc <__text+0x34bc>
1000044e2: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
1000044e9: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
1000044f0: 4c 01 d8                    	addq	%r11, %rax
1000044f3: 48 85 c0                    	testq	%rax, %rax
1000044f6: 0f 85 59 00 00 00           	jne	0x100004555 <__text+0x3555>
1000044fc: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100004503: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
10000450d: 48 39 c8                    	cmpq	%rcx, %rax
100004510: 0f 84 e6 ff ff ff           	je	0x1000044fc <__text+0x34fc>
100004516: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100004520: 48 39 c8                    	cmpq	%rcx, %rax
100004523: 0f 84 2c 00 00 00           	je	0x100004555 <__text+0x3555>
100004529: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100004533: f0                          	lock
100004534: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100004539: 0f 85 bd ff ff ff           	jne	0x1000044fc <__text+0x34fc>
10000453f: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100004546: 4c 89 d7                    	movq	%r10, %rdi
100004549: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100004553: 0f 05                       	syscall
100004555: 4c 8b 95 08 00 00 00        	movq	0x8(%rbp), %r10
10000455c: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100004563: 48 85 c0                    	testq	%rax, %rax
100004566: 0f 84 89 00 00 00           	je	0x1000045f5 <__text+0x35f5>
10000456c: 49 89 c3                    	movq	%rax, %r11
10000456f: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100004576: f0                          	lock
100004577: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
10000457c: 0f 85 da ff ff ff           	jne	0x10000455c <__text+0x355c>
100004582: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100004589: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100004590: 4c 01 d8                    	addq	%r11, %rax
100004593: 48 85 c0                    	testq	%rax, %rax
100004596: 0f 85 59 00 00 00           	jne	0x1000045f5 <__text+0x35f5>
10000459c: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
1000045a3: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
1000045ad: 48 39 c8                    	cmpq	%rcx, %rax
1000045b0: 0f 84 e6 ff ff ff           	je	0x10000459c <__text+0x359c>
1000045b6: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000045c0: 48 39 c8                    	cmpq	%rcx, %rax
1000045c3: 0f 84 2c 00 00 00           	je	0x1000045f5 <__text+0x35f5>
1000045c9: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000045d3: f0                          	lock
1000045d4: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000045d9: 0f 85 bd ff ff ff           	jne	0x10000459c <__text+0x359c>
1000045df: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000045e6: 4c 89 d7                    	movq	%r10, %rdi
1000045e9: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
1000045f3: 0f 05                       	syscall
1000045f5: 31 c0                       	xorl	%eax, %eax
1000045f7: 31 d2                       	xorl	%edx, %edx
1000045f9: e9 00 00 00 00              	jmp	0x1000045fe <__text+0x35fe>
1000045fe: 48 89 ec                    	movq	%rbp, %rsp
100004601: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
100004608: 5d                          	popq	%rbp
100004609: c3                          	retq
10000460a: 53                          	pushq	%rbx
10000460b: 41 54                       	pushq	%r12
10000460d: 41 55                       	pushq	%r13
10000460f: 41 56                       	pushq	%r14
100004611: 41 57                       	pushq	%r15
100004613: e8 72 f9 ff ff              	callq	0x100003f8a <__text+0x2f8a>
100004618: 48 85 d2                    	testq	%rdx, %rdx
10000461b: 0f 95 c2                    	setne	%dl
10000461e: 0f b6 d2                    	movzbl	%dl, %edx
100004621: 48 89 d0                    	movq	%rdx, %rax
100004624: 41 5f                       	popq	%r15
100004626: 41 5e                       	popq	%r14
100004628: 41 5d                       	popq	%r13
10000462a: 41 5c                       	popq	%r12
10000462c: 5b                          	popq	%rbx
10000462d: c3                          	retq
		...
100004ffe: 00 00                       	addb	%al, (%rax)
