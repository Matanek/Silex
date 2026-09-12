
/private/tmp/silex-part03-evidence/fp-memory-flocking-x64:	file format mach-o 64-bit x86-64

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
10000106d: e9 81 08 00 00              	jmp	0x1000018f3 <__text+0x8f3>
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
100001139: 0f 84 2d 00 00 00           	je	0x10000116c <__text+0x16c>
10000113f: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001149: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100001150: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
100001157: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
10000115e: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001165: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
10000116c: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100001173: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
10000117a: 48 39 c8                    	cmpq	%rcx, %rax
10000117d: 0f 84 9a 06 00 00           	je	0x10000181d <__text+0x81d>
100001183: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
10000118a: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100001191: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100001198: 48 b9 e9 a8 c0 17 57 3f e8 a8       	movabsq	$-0x5717c0a8e83f5717, %rcx ## imm = 0xA8E83F5717C0A8E9
1000011a2: 48 f7 e9                    	imulq	%rcx
1000011a5: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
1000011ac: 48 01 ca                    	addq	%rcx, %rdx
1000011af: 48 c1 fa 06                 	sarq	$0x6, %rdx
1000011b3: 48 89 d0                    	movq	%rdx, %rax
1000011b6: 48 c1 e8 3f                 	shrq	$0x3f, %rax
1000011ba: 48 01 c2                    	addq	%rax, %rdx
1000011bd: 48 b8 61 00 00 00 00 00 00 00       	movabsq	$0x61, %rax
1000011c7: 48 0f af d0                 	imulq	%rax, %rdx
1000011cb: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
1000011d2: 48 29 d1                    	subq	%rdx, %rcx
1000011d5: 48 89 8d 48 00 00 00        	movq	%rcx, 0x48(%rbp)
1000011dc: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
1000011e3: 48 89 c1                    	movq	%rax, %rcx
1000011e6: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
1000011eb: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
1000011ef: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
1000011f9: 66 48 0f 6e e2              	movq	%rdx, %xmm4
1000011fe: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001202: 0f 82 39 00 00 00           	jb	0x100001241 <__text+0x241>
100001208: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001212: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001217: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000121b: 0f 83 20 00 00 00           	jae	0x100001241 <__text+0x241>
100001221: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001226: 48 39 c8                    	cmpq	%rcx, %rax
100001229: 0f 85 12 00 00 00           	jne	0x100001241 <__text+0x241>
10000122f: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001233: 66 0f 7e d8                 	movd	%xmm3, %eax
100001237: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000123c: e9 3d 00 00 00              	jmp	0x10000127e <__text+0x27e>
100001241: 48 8d 35 f8 2d 00 00        	leaq	0x2df8(%rip), %rsi      ## 0x100004040
100001248: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000124f: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001256: 4c 89 c2                    	movq	%r8, %rdx
100001259: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001263: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
10000126d: 0f 05                       	syscall
10000126f: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001279: e9 75 06 00 00              	jmp	0x1000018f3 <__text+0x8f3>
10000127e: 48 b8 00 00 e0 40 00 00 00 00       	movabsq	$0x40e00000, %rax ## imm = 0x40E00000
100001288: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000128d: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001290: 0f 28 cf                    	movaps	%xmm7, %xmm1
100001293: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001297: f3 0f 11 85 60 00 00 00     	movss	%xmm0, 0x60(%rbp)
10000129f: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000012a6: 48 b9 71 81 0b 5c e0 02 17 b8       	movabsq	$-0x47e8fd1fa3f47e8f, %rcx ## imm = 0xB81702E05C0B8171
1000012b0: 48 f7 e9                    	imulq	%rcx
1000012b3: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
1000012ba: 48 01 ca                    	addq	%rcx, %rdx
1000012bd: 48 c1 fa 06                 	sarq	$0x6, %rdx
1000012c1: 48 89 d0                    	movq	%rdx, %rax
1000012c4: 48 c1 e8 3f                 	shrq	$0x3f, %rax
1000012c8: 48 01 c2                    	addq	%rax, %rdx
1000012cb: 48 b8 59 00 00 00 00 00 00 00       	movabsq	$0x59, %rax
1000012d5: 48 0f af d0                 	imulq	%rax, %rdx
1000012d9: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
1000012e0: 48 29 d1                    	subq	%rdx, %rcx
1000012e3: 48 89 8d 70 00 00 00        	movq	%rcx, 0x70(%rbp)
1000012ea: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
1000012f1: 48 89 c1                    	movq	%rax, %rcx
1000012f4: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
1000012f9: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
1000012fd: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100001307: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000130c: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001310: 0f 82 39 00 00 00           	jb	0x10000134f <__text+0x34f>
100001316: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001320: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001325: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001329: 0f 83 20 00 00 00           	jae	0x10000134f <__text+0x34f>
10000132f: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001334: 48 39 c8                    	cmpq	%rcx, %rax
100001337: 0f 85 12 00 00 00           	jne	0x10000134f <__text+0x34f>
10000133d: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001341: 66 0f 7e d8                 	movd	%xmm3, %eax
100001345: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000134a: e9 3d 00 00 00              	jmp	0x10000138c <__text+0x38c>
10000134f: 48 8d 35 6a 2d 00 00        	leaq	0x2d6a(%rip), %rsi      ## 0x1000040c0
100001356: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000135d: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001364: 4c 89 c2                    	movq	%r8, %rdx
100001367: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001371: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
10000137b: 0f 05                       	syscall
10000137d: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001387: e9 67 05 00 00              	jmp	0x1000018f3 <__text+0x8f3>
10000138c: 48 b8 00 00 a0 40 00 00 00 00       	movabsq	$0x40a00000, %rax ## imm = 0x40A00000
100001396: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000139b: 0f 28 c6                    	movaps	%xmm6, %xmm0
10000139e: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000013a1: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000013a5: f3 0f 11 85 88 00 00 00     	movss	%xmm0, 0x88(%rbp)
1000013ad: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000013b4: 48 b9 c5 4e ec c4 4e ec c4 4e       	movabsq	$0x4ec4ec4ec4ec4ec5, %rcx ## imm = 0x4EC4EC4EC4EC4EC5
1000013be: 48 f7 e9                    	imulq	%rcx
1000013c1: 48 c1 fa 02                 	sarq	$0x2, %rdx
1000013c5: 48 89 d0                    	movq	%rdx, %rax
1000013c8: 48 c1 e8 3f                 	shrq	$0x3f, %rax
1000013cc: 48 01 c2                    	addq	%rax, %rdx
1000013cf: 48 b8 0d 00 00 00 00 00 00 00       	movabsq	$0xd, %rax
1000013d9: 48 0f af d0                 	imulq	%rax, %rdx
1000013dd: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
1000013e4: 48 29 d1                    	subq	%rdx, %rcx
1000013e7: 48 89 8d 98 00 00 00        	movq	%rcx, 0x98(%rbp)
1000013ee: 48 8b 85 98 00 00 00        	movq	0x98(%rbp), %rax
1000013f5: 48 89 c1                    	movq	%rax, %rcx
1000013f8: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
1000013fd: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100001401: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
10000140b: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001410: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001414: 0f 82 39 00 00 00           	jb	0x100001453 <__text+0x453>
10000141a: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001424: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001429: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000142d: 0f 83 20 00 00 00           	jae	0x100001453 <__text+0x453>
100001433: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001438: 48 39 c8                    	cmpq	%rcx, %rax
10000143b: 0f 85 12 00 00 00           	jne	0x100001453 <__text+0x453>
100001441: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001445: 66 0f 7e d8                 	movd	%xmm3, %eax
100001449: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000144e: e9 3d 00 00 00              	jmp	0x100001490 <__text+0x490>
100001453: 48 8d 35 e6 2c 00 00        	leaq	0x2ce6(%rip), %rsi      ## 0x100004140
10000145a: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001461: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001468: 4c 89 c2                    	movq	%r8, %rdx
10000146b: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001475: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
10000147f: 0f 05                       	syscall
100001481: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000148b: e9 63 04 00 00              	jmp	0x1000018f3 <__text+0x8f3>
100001490: 48 b8 00 00 5c 42 00 00 00 00       	movabsq	$0x425c0000, %rax ## imm = 0x425C0000
10000149a: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000149f: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000014a2: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000014a5: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000014a9: f3 0f 11 85 b0 00 00 00     	movss	%xmm0, 0xb0(%rbp)
1000014b1: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000014b8: 48 b9 79 78 78 78 78 78 78 78       	movabsq	$0x7878787878787879, %rcx ## imm = 0x7878787878787879
1000014c2: 48 f7 e9                    	imulq	%rcx
1000014c5: 48 c1 fa 03                 	sarq	$0x3, %rdx
1000014c9: 48 89 d0                    	movq	%rdx, %rax
1000014cc: 48 c1 e8 3f                 	shrq	$0x3f, %rax
1000014d0: 48 01 c2                    	addq	%rax, %rdx
1000014d3: 48 b8 11 00 00 00 00 00 00 00       	movabsq	$0x11, %rax
1000014dd: 48 0f af d0                 	imulq	%rax, %rdx
1000014e1: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
1000014e8: 48 29 d1                    	subq	%rdx, %rcx
1000014eb: 48 89 8d c0 00 00 00        	movq	%rcx, 0xc0(%rbp)
1000014f2: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
1000014f9: 48 89 c1                    	movq	%rax, %rcx
1000014fc: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100001501: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100001505: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
10000150f: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001514: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001518: 0f 82 39 00 00 00           	jb	0x100001557 <__text+0x557>
10000151e: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001528: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000152d: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001531: 0f 83 20 00 00 00           	jae	0x100001557 <__text+0x557>
100001537: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
10000153c: 48 39 c8                    	cmpq	%rcx, %rax
10000153f: 0f 85 12 00 00 00           	jne	0x100001557 <__text+0x557>
100001545: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001549: 66 0f 7e d8                 	movd	%xmm3, %eax
10000154d: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001552: e9 3d 00 00 00              	jmp	0x100001594 <__text+0x594>
100001557: 48 8d 35 62 2c 00 00        	leaq	0x2c62(%rip), %rsi      ## 0x1000041c0
10000155e: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001565: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000156c: 4c 89 c2                    	movq	%r8, %rdx
10000156f: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001579: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100001583: 0f 05                       	syscall
100001585: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000158f: e9 5f 03 00 00              	jmp	0x1000018f3 <__text+0x8f3>
100001594: 48 b8 00 00 00 41 00 00 00 00       	movabsq	$0x41000000, %rax ## imm = 0x41000000
10000159e: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000015a3: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000015a6: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000015a9: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000015ad: f3 0f 11 85 d8 00 00 00     	movss	%xmm0, 0xd8(%rbp)
1000015b5: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
1000015bc: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
1000015c3: 48 8b 85 88 00 00 00        	movq	0x88(%rbp), %rax
1000015ca: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
1000015d1: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
1000015d8: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
1000015df: 48 8b 85 d8 00 00 00        	movq	0xd8(%rbp), %rax
1000015e6: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
1000015ed: 48 8b 9d 38 00 00 00        	movq	0x38(%rbp), %rbx
1000015f4: 4c 8b a3 00 00 00 00        	movq	(%rbx), %r12
1000015fb: 4d 89 e5                    	movq	%r12, %r13
1000015fe: 49 83 c5 01                 	addq	$0x1, %r13
100001602: 4c 89 ee                    	movq	%r13, %rsi
100001605: 48 b9 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rcx
10000160f: 48 0f af f1                 	imulq	%rcx, %rsi
100001613: 48 81 c6 28 00 00 00        	addq	$0x28, %rsi
10000161a: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
100001624: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000162e: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
100001638: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
100001642: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
10000164c: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
100001656: 0f 05                       	syscall
100001658: 0f 83 0f 00 00 00           	jae	0x10000166d <__text+0x66d>
10000165e: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001668: e9 86 02 00 00              	jmp	0x1000018f3 <__text+0x8f3>
10000166d: 49 89 c7                    	movq	%rax, %r15
100001670: 4d 89 af 00 00 00 00        	movq	%r13, (%r15)
100001677: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001681: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100001688: 49 89 87 10 00 00 00        	movq	%rax, 0x10(%r15)
10000168f: 49 89 87 20 00 00 00        	movq	%rax, 0x20(%r15)
100001696: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000016a0: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
1000016a7: 49 89 b7 18 00 00 00        	movq	%rsi, 0x18(%r15)
1000016ae: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000016b5: 4d 89 fe                    	movq	%r15, %r14
1000016b8: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000016bf: 4d 89 e5                    	movq	%r12, %r13
1000016c2: 48 b9 04 00 00 00 00 00 00 00       	movabsq	$0x4, %rcx
1000016cc: 4c 0f af e9                 	imulq	%rcx, %r13
1000016d0: 4d 85 ed                    	testq	%r13, %r13
1000016d3: 0f 84 20 00 00 00           	je	0x1000016f9 <__text+0x6f9>
1000016d9: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000016e0: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
1000016e7: 48 83 c3 08                 	addq	$0x8, %rbx
1000016eb: 49 83 c6 08                 	addq	$0x8, %r14
1000016ef: 49 83 ed 01                 	subq	$0x1, %r13
1000016f3: 0f 85 e0 ff ff ff           	jne	0x1000016d9 <__text+0x6d9>
1000016f9: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
100001700: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100001707: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
10000170e: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100001715: 48 8b 85 f0 00 00 00        	movq	0xf0(%rbp), %rax
10000171c: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100001723: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
10000172a: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
100001731: 4c 89 bd 00 01 00 00        	movq	%r15, 0x100(%rbp)
100001738: 4c 8b 95 38 00 00 00        	movq	0x38(%rbp), %r10
10000173f: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100001746: 48 85 c0                    	testq	%rax, %rax
100001749: 0f 84 89 00 00 00           	je	0x1000017d8 <__text+0x7d8>
10000174f: 49 89 c3                    	movq	%rax, %r11
100001752: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100001759: f0                          	lock
10000175a: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
10000175f: 0f 85 da ff ff ff           	jne	0x10000173f <__text+0x73f>
100001765: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
10000176c: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100001773: 4c 01 d8                    	addq	%r11, %rax
100001776: 48 85 c0                    	testq	%rax, %rax
100001779: 0f 85 59 00 00 00           	jne	0x1000017d8 <__text+0x7d8>
10000177f: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100001786: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100001790: 48 39 c8                    	cmpq	%rcx, %rax
100001793: 0f 84 e6 ff ff ff           	je	0x10000177f <__text+0x77f>
100001799: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000017a3: 48 39 c8                    	cmpq	%rcx, %rax
1000017a6: 0f 84 2c 00 00 00           	je	0x1000017d8 <__text+0x7d8>
1000017ac: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000017b6: f0                          	lock
1000017b7: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000017bc: 0f 85 bd ff ff ff           	jne	0x10000177f <__text+0x77f>
1000017c2: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000017c9: 4c 89 d7                    	movq	%r10, %rdi
1000017cc: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
1000017d6: 0f 05                       	syscall
1000017d8: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
1000017df: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
1000017e6: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000017ed: 48 8b 8d 28 01 00 00        	movq	0x128(%rbp), %rcx
1000017f4: 48 01 c8                    	addq	%rcx, %rax
1000017f7: 71 0a                       	jno	0x100001803 <__text+0x803>
1000017f9: ba 01 00 00 00              	movl	$0x1, %edx
1000017fe: e9 f0 00 00 00              	jmp	0x1000018f3 <__text+0x8f3>
100001803: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
10000180a: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100001811: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100001818: e9 4f f9 ff ff              	jmp	0x10000116c <__text+0x16c>
10000181d: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100001824: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
10000182b: 4c 8b 95 10 01 00 00        	movq	0x110(%rbp), %r10
100001832: f0                          	lock
100001833: 49 ff 42 08                 	incq	0x8(%r10)
100001837: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
10000183e: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100001845: 4c 8b 95 18 01 00 00        	movq	0x118(%rbp), %r10
10000184c: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100001853: 48 85 c0                    	testq	%rax, %rax
100001856: 0f 84 89 00 00 00           	je	0x1000018e5 <__text+0x8e5>
10000185c: 49 89 c3                    	movq	%rax, %r11
10000185f: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100001866: f0                          	lock
100001867: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
10000186c: 0f 85 da ff ff ff           	jne	0x10000184c <__text+0x84c>
100001872: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100001879: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100001880: 4c 01 d8                    	addq	%r11, %rax
100001883: 48 85 c0                    	testq	%rax, %rax
100001886: 0f 85 59 00 00 00           	jne	0x1000018e5 <__text+0x8e5>
10000188c: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100001893: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
10000189d: 48 39 c8                    	cmpq	%rcx, %rax
1000018a0: 0f 84 e6 ff ff ff           	je	0x10000188c <__text+0x88c>
1000018a6: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000018b0: 48 39 c8                    	cmpq	%rcx, %rax
1000018b3: 0f 84 2c 00 00 00           	je	0x1000018e5 <__text+0x8e5>
1000018b9: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000018c3: f0                          	lock
1000018c4: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000018c9: 0f 85 bd ff ff ff           	jne	0x10000188c <__text+0x88c>
1000018cf: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000018d6: 4c 89 d7                    	movq	%r10, %rdi
1000018d9: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
1000018e3: 0f 05                       	syscall
1000018e5: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
1000018ec: 31 d2                       	xorl	%edx, %edx
1000018ee: e9 00 00 00 00              	jmp	0x1000018f3 <__text+0x8f3>
1000018f3: 48 89 ec                    	movq	%rbp, %rsp
1000018f6: 48 81 c4 50 01 00 00        	addq	$0x150, %rsp            ## imm = 0x150
1000018fd: 5d                          	popq	%rbp
1000018fe: c3                          	retq
1000018ff: 55                          	pushq	%rbp
100001900: 48 89 e5                    	movq	%rsp, %rbp
100001903: 48 81 ec a0 04 00 00        	subq	$0x4a0, %rsp            ## imm = 0x4A0
10000190a: 48 89 e5                    	movq	%rsp, %rbp
10000190d: 48 89 b5 10 00 00 00        	movq	%rsi, 0x10(%rbp)
100001914: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
10000191b: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
100001922: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
100001929: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100001930: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000193a: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000193f: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001949: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100001950: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
10000195a: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100001961: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100001968: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
10000196f: 48 39 c8                    	cmpq	%rcx, %rax
100001972: 0f 9c c0                    	setl	%al
100001975: 48 0f b6 c0                 	movzbq	%al, %rax
100001979: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100001980: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100001987: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
10000198e: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100001995: 48 89 85 28 04 00 00        	movq	%rax, 0x428(%rbp)
10000199c: 66 48 0f 7e f0              	movq	%xmm6, %rax
1000019a1: 48 89 85 48 04 00 00        	movq	%rax, 0x448(%rbp)
1000019a8: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
1000019af: 48 85 c0                    	testq	%rax, %rax
1000019b2: 0f 84 39 00 00 00           	je	0x1000019f1 <__text+0x9f1>
1000019b8: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000019c2: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000019c9: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000019d0: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
1000019d7: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000019de: 48 89 85 28 04 00 00        	movq	%rax, 0x428(%rbp)
1000019e5: 66 48 0f 7e f0              	movq	%xmm6, %rax
1000019ea: 48 89 85 48 04 00 00        	movq	%rax, 0x448(%rbp)
1000019f1: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
1000019f8: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
1000019ff: 48 39 c8                    	cmpq	%rcx, %rax
100001a02: 0f 84 56 01 00 00           	je	0x100001b5e <__text+0xb5e>
100001a08: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
100001a0f: 48 89 c1                    	movq	%rax, %rcx
100001a12: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100001a17: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100001a1b: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100001a25: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001a2a: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001a2e: 0f 82 39 00 00 00           	jb	0x100001a6d <__text+0xa6d>
100001a34: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001a3e: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001a43: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001a47: 0f 83 20 00 00 00           	jae	0x100001a6d <__text+0xa6d>
100001a4d: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001a52: 48 39 c8                    	cmpq	%rcx, %rax
100001a55: 0f 85 12 00 00 00           	jne	0x100001a6d <__text+0xa6d>
100001a5b: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001a5f: 66 0f 7e d8                 	movd	%xmm3, %eax
100001a63: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001a68: e9 3d 00 00 00              	jmp	0x100001aaa <__text+0xaaa>
100001a6d: 48 8d 35 64 28 00 00        	leaq	0x2864(%rip), %rsi      ## 0x1000042d8
100001a74: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001a7b: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001a82: 4c 89 c2                    	movq	%r8, %rdx
100001a85: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001a8f: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100001a99: 0f 05                       	syscall
100001a9b: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001aa5: e9 e8 09 00 00              	jmp	0x100002492 <__text+0x1492>
100001aaa: 48 b8 6f 12 83 3a 00 00 00 00       	movabsq	$0x3a83126f, %rax ## imm = 0x3A83126F
100001ab4: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001ab9: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001abc: 0f 28 cf                    	movaps	%xmm7, %xmm1
100001abf: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001ac3: f3 0f 11 85 78 00 00 00     	movss	%xmm0, 0x78(%rbp)
100001acb: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001ad2: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100001ad9: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100001ae0: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100001ae7: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001af1: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100001af8: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100001aff: 48 89 85 30 04 00 00        	movq	%rax, 0x430(%rbp)
100001b06: 48 8b 85 48 04 00 00        	movq	0x448(%rbp), %rax
100001b0d: 48 89 85 50 04 00 00        	movq	%rax, 0x450(%rbp)
100001b14: e9 61 00 00 00              	jmp	0x100001b7a <__text+0xb7a>
100001b19: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
100001b20: 48 8b 8d 28 04 00 00        	movq	0x428(%rbp), %rcx
100001b27: 48 01 c8                    	addq	%rcx, %rax
100001b2a: 71 0a                       	jno	0x100001b36 <__text+0xb36>
100001b2c: ba 01 00 00 00              	movl	$0x1, %edx
100001b31: e9 5c 09 00 00              	jmp	0x100002492 <__text+0x1492>
100001b36: 48 89 85 10 04 00 00        	movq	%rax, 0x410(%rbp)
100001b3d: 48 8b 85 10 04 00 00        	movq	0x410(%rbp), %rax
100001b44: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
100001b4b: 48 8b 85 50 04 00 00        	movq	0x450(%rbp), %rax
100001b52: 48 89 85 48 04 00 00        	movq	%rax, 0x448(%rbp)
100001b59: e9 93 fe ff ff              	jmp	0x1000019f1 <__text+0x9f1>
100001b5e: 48 8b 85 48 04 00 00        	movq	0x448(%rbp), %rax
100001b65: 48 89 85 18 04 00 00        	movq	%rax, 0x418(%rbp)
100001b6c: 48 8b 85 18 04 00 00        	movq	0x418(%rbp), %rax
100001b73: 31 d2                       	xorl	%edx, %edx
100001b75: e9 18 09 00 00              	jmp	0x100002492 <__text+0x1492>
100001b7a: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100001b81: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100001b88: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100001b8f: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
100001b96: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100001b9d: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
100001ba4: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001bab: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
100001bb2: 48 39 c8                    	cmpq	%rcx, %rax
100001bb5: 0f 8d 5e ff ff ff           	jge	0x100001b19 <__text+0xb19>
100001bbb: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100001bc2: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100001bc9: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100001bd0: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100001bd7: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100001bde: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
100001be5: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001bec: 48 85 c0                    	testq	%rax, %rax
100001bef: 0f 89 03 00 00 00           	jns	0x100001bf8 <__text+0xbf8>
100001bf5: 48 01 c8                    	addq	%rcx, %rax
100001bf8: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100001bff: 48 01 c3                    	addq	%rax, %rbx
100001c02: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001c09: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100001c10: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100001c17: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100001c1e: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100001c25: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100001c2c: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001c33: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100001c3a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c44: 66 4c 0f 6e d8              	movq	%rax, %xmm11
100001c49: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c53: 66 4c 0f 6e e0              	movq	%rax, %xmm12
100001c58: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c62: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100001c69: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c73: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100001c7a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c84: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100001c8b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c95: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100001c9c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001ca6: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100001cad: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001cb4: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100001cbb: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100001cc2: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100001cc9: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001cd3: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100001cda: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100001ce1: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100001ce8: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
100001cef: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001cf6: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100001cfd: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100001d04: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
100001d0b: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
100001d12: 48 8b 85 f0 00 00 00        	movq	0xf0(%rbp), %rax
100001d19: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
100001d20: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100001d27: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
100001d2e: e9 3c 00 00 00              	jmp	0x100001d6f <__text+0xd6f>
100001d33: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001d3d: 48 89 85 08 04 00 00        	movq	%rax, 0x408(%rbp)
100001d44: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001d4b: 48 8b 8d 08 04 00 00        	movq	0x408(%rbp), %rcx
100001d52: 48 01 c8                    	addq	%rcx, %rax
100001d55: 48 89 85 00 04 00 00        	movq	%rax, 0x400(%rbp)
100001d5c: 48 8b 85 00 04 00 00        	movq	0x400(%rbp), %rax
100001d63: 48 89 85 30 04 00 00        	movq	%rax, 0x430(%rbp)
100001d6a: e9 0b fe ff ff              	jmp	0x100001b7a <__text+0xb7a>
100001d6f: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001d76: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100001d7d: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001d84: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100001d8b: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100001d92: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100001d99: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001da0: 48 8b 8d 28 01 00 00        	movq	0x128(%rbp), %rcx
100001da7: 48 39 c8                    	cmpq	%rcx, %rax
100001daa: 0f 8d 64 01 00 00           	jge	0x100001f14 <__text+0xf14>
100001db0: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001db7: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100001dbe: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001dc5: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100001dcc: 48 8b 9d 38 01 00 00        	movq	0x138(%rbp), %rbx
100001dd3: 48 8b 8d 40 01 00 00        	movq	0x140(%rbp), %rcx
100001dda: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001de1: 48 85 c0                    	testq	%rax, %rax
100001de4: 0f 89 03 00 00 00           	jns	0x100001ded <__text+0xded>
100001dea: 48 01 c8                    	addq	%rcx, %rax
100001ded: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100001df4: 48 01 c3                    	addq	%rax, %rbx
100001df7: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001dfe: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100001e05: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100001e0c: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100001e13: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100001e1a: 48 89 85 58 01 00 00        	movq	%rax, 0x158(%rbp)
100001e21: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001e28: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100001e2f: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100001e36: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001e3b: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001e3e: f3 0f 10 8d 78 00 00 00     	movss	0x78(%rbp), %xmm1
100001e46: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001e4a: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001e4d: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001e54: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001e59: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001e5c: 0f 28 cf                    	movaps	%xmm7, %xmm1
100001e5f: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100001e63: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100001e67: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100001e6e: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001e73: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001e7a: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001e7f: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001e82: 0f 28 cf                    	movaps	%xmm7, %xmm1
100001e85: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100001e89: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100001e8d: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100001e91: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100001e95: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001e99: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001e9c: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100001ea0: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100001ea4: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001ea8: 44 0f 28 d0                 	movaps	%xmm0, %xmm10
100001eac: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001eaf: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100001eb3: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001eb7: 0f 28 f8                    	movaps	%xmm0, %xmm7
100001eba: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001ec4: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001ec9: 0f 28 c7                    	movaps	%xmm7, %xmm0
100001ecc: 0f 28 ce                    	movaps	%xmm6, %xmm1
100001ecf: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100001ed2: 0f 87 69 00 00 00           	ja	0x100001f41 <__text+0xf41>
100001ed8: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001ee2: 48 89 85 b8 02 00 00        	movq	%rax, 0x2b8(%rbp)
100001ee9: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001ef0: 48 8b 8d b8 02 00 00        	movq	0x2b8(%rbp), %rcx
100001ef7: 48 01 c8                    	addq	%rcx, %rax
100001efa: 48 89 85 b0 02 00 00        	movq	%rax, 0x2b0(%rbp)
100001f01: 48 8b 85 b0 02 00 00        	movq	0x2b0(%rbp), %rax
100001f08: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001f0f: e9 5b fe ff ff              	jmp	0x100001d6f <__text+0xd6f>
100001f14: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001f1e: 48 89 85 c0 02 00 00        	movq	%rax, 0x2c0(%rbp)
100001f25: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100001f2c: 48 8b 8d c0 02 00 00        	movq	0x2c0(%rbp), %rcx
100001f33: 48 39 c8                    	cmpq	%rcx, %rax
100001f36: 0f 8f a7 02 00 00           	jg	0x1000021e3 <__text+0x11e3>
100001f3c: e9 f2 fd ff ff              	jmp	0x100001d33 <__text+0xd33>
100001f41: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
100001f4b: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001f50: 0f 28 c7                    	movaps	%xmm7, %xmm0
100001f53: 0f 28 ce                    	movaps	%xmm6, %xmm1
100001f56: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100001f59: 0f 8a 79 ff ff ff           	jp	0x100001ed8 <__text+0xed8>
100001f5f: 0f 83 73 ff ff ff           	jae	0x100001ed8 <__text+0xed8>
100001f65: 48 8b 85 68 04 00 00        	movq	0x468(%rbp), %rax
100001f6c: 48 89 85 d8 01 00 00        	movq	%rax, 0x1d8(%rbp)
100001f73: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001f7a: 48 89 85 e0 01 00 00        	movq	%rax, 0x1e0(%rbp)
100001f81: 48 8b 85 70 04 00 00        	movq	0x470(%rbp), %rax
100001f88: 48 89 85 f0 01 00 00        	movq	%rax, 0x1f0(%rbp)
100001f8f: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001f96: 48 89 85 f8 01 00 00        	movq	%rax, 0x1f8(%rbp)
100001f9d: f3 0f 10 9d d8 01 00 00     	movss	0x1d8(%rbp), %xmm3
100001fa5: f3 0f 10 ad f0 01 00 00     	movss	0x1f0(%rbp), %xmm5
100001fad: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100001fb0: f3 0f 10 a5 e0 01 00 00     	movss	0x1e0(%rbp), %xmm4
100001fb8: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100001fc0: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100001fc3: 0f 28 c3                    	movaps	%xmm3, %xmm0
100001fc6: 0f 58 c4                    	addps	%xmm4, %xmm0
100001fc9: f3 0f 11 85 e8 01 00 00     	movss	%xmm0, 0x1e8(%rbp)
100001fd1: 0f 28 e8                    	movaps	%xmm0, %xmm5
100001fd4: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100001fd8: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
100001fe0: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
100001fe7: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
100001fee: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
100001ff5: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
100001ffc: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
100002003: 48 89 85 20 02 00 00        	movq	%rax, 0x220(%rbp)
10000200a: 48 8b 85 60 01 00 00        	movq	0x160(%rbp), %rax
100002011: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100002018: f3 0f 10 9d 08 02 00 00     	movss	0x208(%rbp), %xmm3
100002020: f3 0f 10 ad 20 02 00 00     	movss	0x220(%rbp), %xmm5
100002028: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
10000202b: f3 0f 10 a5 10 02 00 00     	movss	0x210(%rbp), %xmm4
100002033: f3 0f 10 ad 28 02 00 00     	movss	0x228(%rbp), %xmm5
10000203b: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
10000203e: 0f 28 cb                    	movaps	%xmm3, %xmm1
100002041: 0f 58 cc                    	addps	%xmm4, %xmm1
100002044: f3 0f 11 8d 18 02 00 00     	movss	%xmm1, 0x218(%rbp)
10000204c: 0f 28 e9                    	movaps	%xmm1, %xmm5
10000204f: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002053: f3 0f 11 ad 30 02 00 00     	movss	%xmm5, 0x230(%rbp)
10000205b: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002065: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
10000206c: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100002073: 48 8b 8d 38 02 00 00        	movq	0x238(%rbp), %rcx
10000207a: 48 01 c8                    	addq	%rcx, %rax
10000207d: 71 0a                       	jno	0x100002089 <__text+0x1089>
10000207f: ba 01 00 00 00              	movl	$0x1, %edx
100002084: e9 09 04 00 00              	jmp	0x100002492 <__text+0x1492>
100002089: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
100002090: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
10000209a: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000209f: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000020a2: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000020a5: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
1000020a8: 0f 92 c0                    	setb	%al
1000020ab: 0f 9b c1                    	setnp	%cl
1000020ae: 20 c8                       	andb	%cl, %al
1000020b0: 48 0f b6 c0                 	movzbq	%al, %rax
1000020b4: 48 89 85 50 02 00 00        	movq	%rax, 0x250(%rbp)
1000020bb: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
1000020c2: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
1000020c9: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
1000020d0: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
1000020d7: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
1000020de: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
1000020e5: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
1000020ec: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
1000020f3: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
1000020fa: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
100002101: 48 8b 85 50 02 00 00        	movq	0x250(%rbp), %rax
100002108: 48 85 c0                    	testq	%rax, %rax
10000210b: 0f 84 c7 fd ff ff           	je	0x100001ed8 <__text+0xed8>
100002111: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
10000211b: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002120: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
10000212a: 66 4c 0f 6e d0              	movq	%rax, %xmm10
10000212f: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002132: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100002136: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002139: 0f 97 c0                    	seta	%al
10000213c: 48 0f b6 c0                 	movzbq	%al, %rax
100002140: 48 89 85 68 02 00 00        	movq	%rax, 0x268(%rbp)
100002147: 48 8b 85 68 02 00 00        	movq	0x268(%rbp), %rax
10000214e: 48 85 c0                    	testq	%rax, %rax
100002151: 0f 84 03 00 00 00           	je	0x10000215a <__text+0x115a>
100002157: 0f 28 f7                    	movaps	%xmm7, %xmm6
10000215a: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
10000215e: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002161: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002165: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002169: 41 0f 28 c3                 	movaps	%xmm11, %xmm0
10000216d: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002171: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002175: 44 0f 28 d8                 	movaps	%xmm0, %xmm11
100002179: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
10000217d: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002180: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002184: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100002188: 41 0f 28 c4                 	movaps	%xmm12, %xmm0
10000218c: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002190: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002194: 44 0f 28 e0                 	movaps	%xmm0, %xmm12
100002198: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
10000219f: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
1000021a6: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
1000021ad: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
1000021b4: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
1000021bb: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
1000021c2: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
1000021c9: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
1000021d0: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
1000021d7: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
1000021de: e9 f5 fc ff ff              	jmp	0x100001ed8 <__text+0xed8>
1000021e3: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
1000021ea: 48 89 c1                    	movq	%rax, %rcx
1000021ed: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
1000021f2: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
1000021f6: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100002200: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002205: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002209: 0f 82 39 00 00 00           	jb	0x100002248 <__text+0x1248>
10000220f: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100002219: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000221e: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002222: 0f 83 20 00 00 00           	jae	0x100002248 <__text+0x1248>
100002228: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
10000222d: 48 39 c8                    	cmpq	%rcx, %rax
100002230: 0f 85 12 00 00 00           	jne	0x100002248 <__text+0x1248>
100002236: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
10000223a: 66 0f 7e d8                 	movd	%xmm3, %eax
10000223e: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002243: e9 3d 00 00 00              	jmp	0x100002285 <__text+0x1285>
100002248: 48 8d 35 e9 21 00 00        	leaq	0x21e9(%rip), %rsi      ## 0x100004438
10000224f: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100002256: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000225d: 4c 89 c2                    	movq	%r8, %rdx
100002260: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000226a: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100002274: 0f 05                       	syscall
100002276: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002280: e9 0d 02 00 00              	jmp	0x100002492 <__text+0x1492>
100002285: 48 8b 85 50 04 00 00        	movq	0x450(%rbp), %rax
10000228c: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002291: 48 8b 85 68 04 00 00        	movq	0x468(%rbp), %rax
100002298: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000229d: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000022a1: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000022a4: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000022a8: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000022ac: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
1000022b3: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000022b8: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000022bc: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
1000022c0: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000022c4: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000022c8: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
1000022d2: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000022d7: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000022db: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
1000022df: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000022e3: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000022e7: 48 8b 85 70 04 00 00        	movq	0x470(%rbp), %rax
1000022ee: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000022f3: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000022f7: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000022fa: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000022fe: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100002302: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100002309: 66 4c 0f 6e d0              	movq	%rax, %xmm10
10000230e: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002312: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100002316: f3 0f 5c c1                 	subss	%xmm1, %xmm0
10000231a: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
10000231e: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002328: 66 4c 0f 6e d0              	movq	%rax, %xmm10
10000232d: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002331: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100002335: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002339: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
10000233d: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002341: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002345: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002349: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
10000234d: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
100002354: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002359: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
10000235d: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002360: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002364: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100002368: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
10000236f: 66 4c 0f 6e d0              	movq	%rax, %xmm10
100002374: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002378: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
10000237c: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002380: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100002384: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
10000238e: 66 4c 0f 6e d0              	movq	%rax, %xmm10
100002393: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002397: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
10000239b: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000239f: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000023a3: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000023a7: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
1000023ab: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000023af: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000023b3: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
1000023ba: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000023bf: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000023c3: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000023c6: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000023ca: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000023ce: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
1000023d5: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000023da: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000023de: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000023e1: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000023e5: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000023e9: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
1000023f3: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000023f8: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000023fc: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000023ff: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002403: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100002407: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
10000240b: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
10000240f: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002413: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002417: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002421: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002426: 41 0f 28 c3                 	movaps	%xmm11, %xmm0
10000242a: 0f 28 ce                    	movaps	%xmm6, %xmm1
10000242d: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002431: 44 0f 28 d8                 	movaps	%xmm0, %xmm11
100002435: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002439: 41 0f 28 cb                 	movaps	%xmm11, %xmm1
10000243d: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002441: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002445: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
10000244f: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002454: 41 0f 28 c4                 	movaps	%xmm12, %xmm0
100002458: 0f 28 ce                    	movaps	%xmm6, %xmm1
10000245b: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000245f: 44 0f 28 e0                 	movaps	%xmm0, %xmm12
100002463: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002467: 41 0f 28 cc                 	movaps	%xmm12, %xmm1
10000246b: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000246f: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002473: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002476: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
10000247a: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000247e: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002481: 66 48 0f 7e f8              	movq	%xmm7, %rax
100002486: 48 89 85 50 04 00 00        	movq	%rax, 0x450(%rbp)
10000248d: e9 a1 f8 ff ff              	jmp	0x100001d33 <__text+0xd33>
100002492: 48 89 ec                    	movq	%rbp, %rsp
100002495: 48 81 c4 a0 04 00 00        	addq	$0x4a0, %rsp            ## imm = 0x4A0
10000249c: 5d                          	popq	%rbp
10000249d: c3                          	retq
10000249e: 55                          	pushq	%rbp
10000249f: 48 89 e5                    	movq	%rsp, %rbp
1000024a2: 48 81 ec 00 04 00 00        	subq	$0x400, %rsp            ## imm = 0x400
1000024a9: 48 89 e5                    	movq	%rsp, %rbp
1000024ac: 4c 89 bd 30 00 00 00        	movq	%r15, 0x30(%rbp)
1000024b3: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
1000024ba: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
1000024c1: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
1000024c8: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
1000024cf: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
1000024d6: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
1000024dd: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
1000024e4: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
1000024eb: 48 8b 87 10 00 00 00        	movq	0x10(%rdi), %rax
1000024f2: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
1000024f9: 48 8b 87 18 00 00 00        	movq	0x18(%rdi), %rax
100002500: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100002507: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
10000250e: 48 89 85 60 03 00 00        	movq	%rax, 0x360(%rbp)
100002515: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
10000251c: 48 89 85 68 03 00 00        	movq	%rax, 0x368(%rbp)
100002523: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
10000252a: 48 89 85 70 03 00 00        	movq	%rax, 0x370(%rbp)
100002531: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100002538: 48 89 85 78 03 00 00        	movq	%rax, 0x378(%rbp)
10000253f: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002549: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100002550: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000255a: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100002561: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000256b: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
100002572: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000257c: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100002583: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000258d: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100002594: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000259e: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
1000025a5: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000025af: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
1000025b6: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
1000025bd: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000025c4: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
1000025cb: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000025d2: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000025dc: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
1000025e3: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
1000025ea: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
1000025f1: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
1000025f8: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
1000025ff: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100002606: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
10000260d: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100002614: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
10000261b: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100002622: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
100002629: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
100002630: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
100002637: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
10000263e: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
100002645: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
10000264c: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
100002653: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
10000265a: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100002661: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100002668: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
10000266f: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100002676: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
10000267d: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
100002684: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
10000268b: 48 39 c8                    	cmpq	%rcx, %rax
10000268e: 0f 8d 52 01 00 00           	jge	0x1000027e6 <__text+0x17e6>
100002694: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
10000269b: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
1000026a2: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000026a9: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
1000026b0: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
1000026b7: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
1000026be: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
1000026c5: 48 85 c0                    	testq	%rax, %rax
1000026c8: 0f 89 03 00 00 00           	jns	0x1000026d1 <__text+0x16d1>
1000026ce: 48 01 c8                    	addq	%rcx, %rax
1000026d1: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000026d8: 48 01 c3                    	addq	%rax, %rbx
1000026db: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000026e2: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
1000026e9: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
1000026f0: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
1000026f7: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
1000026fe: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100002705: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
10000270c: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100002713: 48 8b 85 60 03 00 00        	movq	0x360(%rbp), %rax
10000271a: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000271f: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100002726: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000272b: 0f 28 c7                    	movaps	%xmm7, %xmm0
10000272e: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002731: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002735: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002739: 48 8b 85 68 03 00 00        	movq	0x368(%rbp), %rax
100002740: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002745: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
10000274c: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002751: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002754: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002757: f3 0f 5c c1                 	subss	%xmm1, %xmm0
10000275b: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
10000275f: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002763: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002767: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000276b: 0f 28 f0                    	movaps	%xmm0, %xmm6
10000276e: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002772: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002776: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000277a: 44 0f 28 d0                 	movaps	%xmm0, %xmm10
10000277e: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002781: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100002785: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002789: 0f 28 f8                    	movaps	%xmm0, %xmm7
10000278c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002796: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000279b: 0f 28 c7                    	movaps	%xmm7, %xmm0
10000279e: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000027a1: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
1000027a4: 0f 87 69 00 00 00           	ja	0x100002813 <__text+0x1813>
1000027aa: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000027b4: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
1000027bb: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
1000027c2: 48 8b 8d 10 02 00 00        	movq	0x210(%rbp), %rcx
1000027c9: 48 01 c8                    	addq	%rcx, %rax
1000027cc: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
1000027d3: 48 8b 85 08 02 00 00        	movq	0x208(%rbp), %rax
1000027da: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
1000027e1: e9 6d fe ff ff              	jmp	0x100002653 <__text+0x1653>
1000027e6: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000027f0: 48 89 85 18 02 00 00        	movq	%rax, 0x218(%rbp)
1000027f7: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
1000027fe: 48 8b 8d 18 02 00 00        	movq	0x218(%rbp), %rcx
100002805: 48 39 c8                    	cmpq	%rcx, %rax
100002808: 0f 84 0a 03 00 00           	je	0x100002b18 <__text+0x1b18>
10000280e: e9 77 03 00 00              	jmp	0x100002b8a <__text+0x1b8a>
100002813: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
10000281d: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002822: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002825: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002828: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
10000282b: 0f 8a 79 ff ff ff           	jp	0x1000027aa <__text+0x17aa>
100002831: 0f 83 73 ff ff ff           	jae	0x1000027aa <__text+0x17aa>
100002837: 48 8b 85 c0 03 00 00        	movq	0x3c0(%rbp), %rax
10000283e: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
100002845: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
10000284c: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100002853: 48 8b 85 c8 03 00 00        	movq	0x3c8(%rbp), %rax
10000285a: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100002861: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100002868: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
10000286f: f3 0f 10 9d 30 01 00 00     	movss	0x130(%rbp), %xmm3
100002877: f3 0f 10 ad 48 01 00 00     	movss	0x148(%rbp), %xmm5
10000287f: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002882: f3 0f 10 a5 38 01 00 00     	movss	0x138(%rbp), %xmm4
10000288a: f3 0f 10 ad 50 01 00 00     	movss	0x150(%rbp), %xmm5
100002892: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002895: 0f 28 c3                    	movaps	%xmm3, %xmm0
100002898: 0f 58 c4                    	addps	%xmm4, %xmm0
10000289b: f3 0f 11 85 40 01 00 00     	movss	%xmm0, 0x140(%rbp)
1000028a3: 0f 28 e8                    	movaps	%xmm0, %xmm5
1000028a6: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
1000028aa: f3 0f 11 ad 58 01 00 00     	movss	%xmm5, 0x158(%rbp)
1000028b2: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
1000028b9: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
1000028c0: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
1000028c7: 48 89 85 68 01 00 00        	movq	%rax, 0x168(%rbp)
1000028ce: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
1000028d5: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
1000028dc: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
1000028e3: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
1000028ea: f3 0f 10 9d 60 01 00 00     	movss	0x160(%rbp), %xmm3
1000028f2: f3 0f 10 ad 78 01 00 00     	movss	0x178(%rbp), %xmm5
1000028fa: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
1000028fd: f3 0f 10 a5 68 01 00 00     	movss	0x168(%rbp), %xmm4
100002905: f3 0f 10 ad 80 01 00 00     	movss	0x180(%rbp), %xmm5
10000290d: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002910: 0f 28 cb                    	movaps	%xmm3, %xmm1
100002913: 0f 58 cc                    	addps	%xmm4, %xmm1
100002916: f3 0f 11 8d 70 01 00 00     	movss	%xmm1, 0x170(%rbp)
10000291e: 0f 28 e9                    	movaps	%xmm1, %xmm5
100002921: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002925: f3 0f 11 ad 88 01 00 00     	movss	%xmm5, 0x188(%rbp)
10000292d: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002937: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
10000293e: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002945: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
10000294c: 48 01 c8                    	addq	%rcx, %rax
10000294f: 71 0a                       	jno	0x10000295b <__text+0x195b>
100002951: ba 01 00 00 00              	movl	$0x1, %edx
100002956: e9 00 05 00 00              	jmp	0x100002e5b <__text+0x1e5b>
10000295b: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002962: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
10000296c: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002971: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002974: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002977: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
10000297a: 0f 92 c0                    	setb	%al
10000297d: 0f 9b c1                    	setnp	%cl
100002980: 20 c8                       	andb	%cl, %al
100002982: 48 0f b6 c0                 	movzbq	%al, %rax
100002986: 48 89 85 a8 01 00 00        	movq	%rax, 0x1a8(%rbp)
10000298d: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100002994: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
10000299b: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
1000029a2: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
1000029a9: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000029b0: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
1000029b7: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
1000029be: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
1000029c5: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000029cc: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
1000029d3: 48 8b 85 a8 01 00 00        	movq	0x1a8(%rbp), %rax
1000029da: 48 85 c0                    	testq	%rax, %rax
1000029dd: 0f 84 c7 fd ff ff           	je	0x1000027aa <__text+0x17aa>
1000029e3: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
1000029ed: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000029f2: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
1000029fc: 66 4c 0f 6e d0              	movq	%rax, %xmm10
100002a01: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002a04: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100002a08: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002a0b: 0f 97 c0                    	seta	%al
100002a0e: 48 0f b6 c0                 	movzbq	%al, %rax
100002a12: 48 89 85 c0 01 00 00        	movq	%rax, 0x1c0(%rbp)
100002a19: 48 8b 85 c0 01 00 00        	movq	0x1c0(%rbp), %rax
100002a20: 48 85 c0                    	testq	%rax, %rax
100002a23: 0f 84 03 00 00 00           	je	0x100002a2c <__text+0x1a2c>
100002a29: 0f 28 f7                    	movaps	%xmm7, %xmm6
100002a2c: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002a33: 48 89 85 c8 01 00 00        	movq	%rax, 0x1c8(%rbp)
100002a3a: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002a3e: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002a41: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002a45: f3 0f 11 85 d8 01 00 00     	movss	%xmm0, 0x1d8(%rbp)
100002a4d: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
100002a54: 48 89 85 e8 01 00 00        	movq	%rax, 0x1e8(%rbp)
100002a5b: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002a5f: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002a62: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002a66: f3 0f 11 85 f8 01 00 00     	movss	%xmm0, 0x1f8(%rbp)
100002a6e: f3 0f 10 9d c8 01 00 00     	movss	0x1c8(%rbp), %xmm3
100002a76: f3 0f 10 ad e8 01 00 00     	movss	0x1e8(%rbp), %xmm5
100002a7e: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002a81: f3 0f 10 a5 d8 01 00 00     	movss	0x1d8(%rbp), %xmm4
100002a89: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100002a91: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002a94: 0f 28 d3                    	movaps	%xmm3, %xmm2
100002a97: 0f 58 d4                    	addps	%xmm4, %xmm2
100002a9a: f3 0f 11 95 e0 01 00 00     	movss	%xmm2, 0x1e0(%rbp)
100002aa2: 0f 28 ea                    	movaps	%xmm2, %xmm5
100002aa5: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002aa9: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
100002ab1: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100002ab8: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
100002abf: 48 8b 85 e0 01 00 00        	movq	0x1e0(%rbp), %rax
100002ac6: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
100002acd: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002ad4: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
100002adb: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
100002ae2: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
100002ae9: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
100002af0: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
100002af7: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002afe: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
100002b05: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100002b0c: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
100002b13: e9 92 fc ff ff              	jmp	0x1000027aa <__text+0x17aa>
100002b18: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002b22: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100002b29: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002b33: 48 89 85 30 02 00 00        	movq	%rax, 0x230(%rbp)
100002b3a: 48 8b 85 28 02 00 00        	movq	0x228(%rbp), %rax
100002b41: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
100002b48: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
100002b4f: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
100002b56: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002b5d: 48 8b 85 38 02 00 00        	movq	0x238(%rbp), %rax
100002b64: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002b6b: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
100002b72: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002b79: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002b83: 31 d2                       	xorl	%edx, %edx
100002b85: e9 d1 02 00 00              	jmp	0x100002e5b <__text+0x1e5b>
100002b8a: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002b91: 48 89 c1                    	movq	%rax, %rcx
100002b94: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100002b99: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100002b9d: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100002ba7: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002bac: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002bb0: 0f 82 39 00 00 00           	jb	0x100002bef <__text+0x1bef>
100002bb6: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100002bc0: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002bc5: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002bc9: 0f 83 20 00 00 00           	jae	0x100002bef <__text+0x1bef>
100002bcf: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100002bd4: 48 39 c8                    	cmpq	%rcx, %rax
100002bd7: 0f 85 12 00 00 00           	jne	0x100002bef <__text+0x1bef>
100002bdd: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100002be1: 66 0f 7e d8                 	movd	%xmm3, %eax
100002be5: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002bea: e9 3d 00 00 00              	jmp	0x100002c2c <__text+0x1c2c>
100002bef: 48 8d 35 32 19 00 00        	leaq	0x1932(%rip), %rsi      ## 0x100004528
100002bf6: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100002bfd: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100002c04: 4c 89 c2                    	movq	%r8, %rdx
100002c07: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100002c11: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100002c1b: 0f 05                       	syscall
100002c1d: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002c27: e9 2f 02 00 00              	jmp	0x100002e5b <__text+0x1e5b>
100002c2c: 48 8b 85 c0 03 00 00        	movq	0x3c0(%rbp), %rax
100002c33: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002c38: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002c3b: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002c3e: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002c42: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002c45: 48 8b 85 60 03 00 00        	movq	0x360(%rbp), %rax
100002c4c: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002c51: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002c54: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002c58: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002c5c: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002c5f: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002c69: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002c6e: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002c71: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002c75: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002c79: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002c7c: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
100002c83: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002c88: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002c8c: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002c8f: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002c93: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002c97: 48 8b 85 70 03 00 00        	movq	0x370(%rbp), %rax
100002c9e: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002ca3: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002ca7: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002cab: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002caf: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002cb3: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002cbd: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002cc2: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002cc6: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002cca: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002cce: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002cd2: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002cd5: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002cd9: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002cdd: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002ce0: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002ce7: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002cec: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002cf6: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002cfb: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002cff: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002d03: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002d07: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002d0b: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002d0e: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002d12: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002d16: f3 0f 11 85 c0 02 00 00     	movss	%xmm0, 0x2c0(%rbp)
100002d1e: 48 8b 85 c8 03 00 00        	movq	0x3c8(%rbp), %rax
100002d25: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002d2a: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002d2d: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002d30: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002d34: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002d37: 48 8b 85 68 03 00 00        	movq	0x368(%rbp), %rax
100002d3e: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002d43: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002d46: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002d4a: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002d4e: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002d51: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002d5b: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002d60: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002d63: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002d67: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002d6b: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002d6e: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
100002d75: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002d7a: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002d7e: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002d81: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002d85: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002d89: 48 8b 85 78 03 00 00        	movq	0x378(%rbp), %rax
100002d90: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002d95: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002d99: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002d9c: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002da0: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002da4: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002dae: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002db3: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002db7: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002dba: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002dbe: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002dc2: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002dc5: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002dc9: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002dcd: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002dd0: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
100002dd7: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002ddc: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002de6: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002deb: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002dee: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002df2: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002df6: 0f 28 f0                    	movaps	%xmm0, %xmm6
100002df9: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002dfc: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002dff: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002e03: f3 0f 11 85 38 03 00 00     	movss	%xmm0, 0x338(%rbp)
100002e0b: 48 8b 85 c0 02 00 00        	movq	0x2c0(%rbp), %rax
100002e12: 48 89 85 40 03 00 00        	movq	%rax, 0x340(%rbp)
100002e19: 48 8b 85 38 03 00 00        	movq	0x338(%rbp), %rax
100002e20: 48 89 85 48 03 00 00        	movq	%rax, 0x348(%rbp)
100002e27: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002e2e: 48 8b 85 40 03 00 00        	movq	0x340(%rbp), %rax
100002e35: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002e3c: 48 8b 85 48 03 00 00        	movq	0x348(%rbp), %rax
100002e43: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002e4a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002e54: 31 d2                       	xorl	%edx, %edx
100002e56: e9 00 00 00 00              	jmp	0x100002e5b <__text+0x1e5b>
100002e5b: 48 89 ec                    	movq	%rbp, %rsp
100002e5e: 48 81 c4 00 04 00 00        	addq	$0x400, %rsp            ## imm = 0x400
100002e65: 5d                          	popq	%rbp
100002e66: c3                          	retq
100002e67: 55                          	pushq	%rbp
100002e68: 48 89 e5                    	movq	%rsp, %rbp
100002e6b: 48 81 ec b0 01 00 00        	subq	$0x1b0, %rsp            ## imm = 0x1B0
100002e72: 48 89 e5                    	movq	%rsp, %rbp
100002e75: 48 89 95 18 00 00 00        	movq	%rdx, 0x18(%rbp)
100002e7c: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
100002e83: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100002e8a: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
100002e91: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
100002e98: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
100002e9f: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002ea9: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002eae: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002eb8: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100002ebf: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002ec6: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002ecd: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100002ed4: 48 8b 8d 30 00 00 00        	movq	0x30(%rbp), %rcx
100002edb: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002ee2: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100002ee9: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
100002ef3: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100002efa: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002f01: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100002f08: 48 39 c8                    	cmpq	%rcx, %rax
100002f0b: 0f 9c c0                    	setl	%al
100002f0e: 48 0f b6 c0                 	movzbq	%al, %rax
100002f12: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100002f19: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002f20: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100002f27: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100002f2e: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002f35: 66 48 0f 7e f0              	movq	%xmm6, %rax
100002f3a: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002f41: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100002f48: 48 85 c0                    	testq	%rax, %rax
100002f4b: 0f 84 39 00 00 00           	je	0x100002f8a <__text+0x1f8a>
100002f51: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002f5b: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100002f62: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002f69: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100002f70: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
100002f77: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002f7e: 66 48 0f 7e f0              	movq	%xmm6, %rax
100002f83: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002f8a: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002f91: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100002f98: 48 39 c8                    	cmpq	%rcx, %rax
100002f9b: 0f 84 ad 05 00 00           	je	0x10000354e <__text+0x254e>
100002fa1: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002fa8: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002faf: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100002fb6: 48 8b 9d 60 00 00 00        	movq	0x60(%rbp), %rbx
100002fbd: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100002fc4: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100002fcb: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002fd2: 48 85 c0                    	testq	%rax, %rax
100002fd5: 0f 89 03 00 00 00           	jns	0x100002fde <__text+0x1fde>
100002fdb: 48 01 c8                    	addq	%rcx, %rax
100002fde: 48 39 c8                    	cmpq	%rcx, %rax
100002fe1: 0f 82 0f 00 00 00           	jb	0x100002ff6 <__text+0x1ff6>
100002fe7: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002ff1: e9 74 05 00 00              	jmp	0x10000356a <__text+0x256a>
100002ff6: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002ffd: 48 01 c3                    	addq	%rax, %rbx
100003000: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003007: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
10000300e: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003015: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
10000301c: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003023: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
10000302a: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003031: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100003038: 4c 8d bd 88 00 00 00        	leaq	0x88(%rbp), %r15
10000303f: 48 8d bd 68 00 00 00        	leaq	0x68(%rbp), %rdi
100003046: 48 8d b5 08 00 00 00        	leaq	0x8(%rbp), %rsi
10000304d: e8 4c f4 ff ff              	callq	0x10000249e <__text+0x149e>
100003052: 48 85 d2                    	testq	%rdx, %rdx
100003055: 0f 85 0f 05 00 00           	jne	0x10000356a <__text+0x256a>
10000305b: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
100003062: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003067: 48 8b 85 88 00 00 00        	movq	0x88(%rbp), %rax
10000306e: 66 48 0f 6e f8              	movq	%rax, %xmm7
100003073: 0f 28 c7                    	movaps	%xmm7, %xmm0
100003076: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
10000307e: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100003082: 0f 28 f8                    	movaps	%xmm0, %xmm7
100003085: 0f 28 c6                    	movaps	%xmm6, %xmm0
100003088: 0f 28 cf                    	movaps	%xmm7, %xmm1
10000308b: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000308f: f3 0f 11 85 b0 00 00 00     	movss	%xmm0, 0xb0(%rbp)
100003097: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
10000309e: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000030a3: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
1000030aa: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000030af: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000030b2: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
1000030ba: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000030be: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000030c1: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000030c4: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000030c7: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000030cb: f3 0f 11 85 d0 00 00 00     	movss	%xmm0, 0xd0(%rbp)
1000030d3: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
1000030da: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000030df: f3 0f 10 85 b0 00 00 00     	movss	0xb0(%rbp), %xmm0
1000030e7: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
1000030ef: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000030f3: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000030f6: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000030f9: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000030fc: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003100: f3 0f 11 85 e8 00 00 00     	movss	%xmm0, 0xe8(%rbp)
100003108: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
10000310f: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003114: f3 0f 10 85 d0 00 00 00     	movss	0xd0(%rbp), %xmm0
10000311c: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100003124: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100003128: 0f 28 f8                    	movaps	%xmm0, %xmm7
10000312b: 0f 28 c6                    	movaps	%xmm6, %xmm0
10000312e: 0f 28 cf                    	movaps	%xmm7, %xmm1
100003131: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003135: f3 0f 11 85 00 01 00 00     	movss	%xmm0, 0x100(%rbp)
10000313d: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100003144: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
10000314b: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100003152: 48 8b 9d 08 01 00 00        	movq	0x108(%rbp), %rbx
100003159: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003160: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003167: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
10000316e: 48 85 c0                    	testq	%rax, %rax
100003171: 0f 89 03 00 00 00           	jns	0x10000317a <__text+0x217a>
100003177: 48 01 c8                    	addq	%rcx, %rax
10000317a: 48 39 c8                    	cmpq	%rcx, %rax
10000317d: 0f 82 0f 00 00 00           	jb	0x100003192 <__text+0x2192>
100003183: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000318d: e9 d8 03 00 00              	jmp	0x10000356a <__text+0x256a>
100003192: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003199: 48 01 c3                    	addq	%rax, %rbx
10000319c: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000031a3: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
1000031aa: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
1000031b1: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
1000031b8: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
1000031bf: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
1000031c6: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
1000031cd: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000031d4: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
1000031db: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
1000031e2: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
1000031e9: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
1000031f0: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
1000031f7: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
1000031fe: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
100003205: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
10000320c: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100003213: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
10000321a: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100003221: 48 8b 9d 50 01 00 00        	movq	0x150(%rbp), %rbx
100003228: 4c 8b a3 00 00 00 00        	movq	(%rbx), %r12
10000322f: 4c 8b ad 88 01 00 00        	movq	0x188(%rbp), %r13
100003236: 4d 85 ed                    	testq	%r13, %r13
100003239: 0f 89 03 00 00 00           	jns	0x100003242 <__text+0x2242>
10000323f: 4d 01 e5                    	addq	%r12, %r13
100003242: 4d 39 e5                    	cmpq	%r12, %r13
100003245: 0f 82 0f 00 00 00           	jb	0x10000325a <__text+0x225a>
10000324b: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003255: e9 10 03 00 00              	jmp	0x10000356a <__text+0x256a>
10000325a: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003261: 4c 8b 9b 10 00 00 00        	movq	0x10(%rbx), %r11
100003268: 4c 01 d8                    	addq	%r11, %rax
10000326b: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003275: 48 39 c8                    	cmpq	%rcx, %rax
100003278: 0f 85 5b 00 00 00           	jne	0x1000032d9 <__text+0x22d9>
10000327e: 49 89 de                    	movq	%rbx, %r14
100003281: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100003288: 4c 89 e8                    	movq	%r13, %rax
10000328b: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003292: 49 01 c6                    	addq	%rax, %r14
100003295: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
10000329c: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
1000032a3: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
1000032aa: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
1000032b1: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
1000032b8: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
1000032bf: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
1000032c6: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
1000032cd: 48 89 9d 58 01 00 00        	movq	%rbx, 0x158(%rbp)
1000032d4: e9 ed 01 00 00              	jmp	0x1000034c6 <__text+0x24c6>
1000032d9: 4c 89 e6                    	movq	%r12, %rsi
1000032dc: 48 b9 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rcx
1000032e6: 48 0f af f1                 	imulq	%rcx, %rsi
1000032ea: 48 81 c6 28 00 00 00        	addq	$0x28, %rsi
1000032f1: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
1000032fb: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003305: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
10000330f: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
100003319: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
100003323: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
10000332d: 0f 05                       	syscall
10000332f: 0f 83 0f 00 00 00           	jae	0x100003344 <__text+0x2344>
100003335: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000333f: e9 26 02 00 00              	jmp	0x10000356a <__text+0x256a>
100003344: 49 89 c7                    	movq	%rax, %r15
100003347: 4d 89 a7 00 00 00 00        	movq	%r12, (%r15)
10000334e: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003358: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
10000335f: 49 89 87 10 00 00 00        	movq	%rax, 0x10(%r15)
100003366: 49 89 87 20 00 00 00        	movq	%rax, 0x20(%r15)
10000336d: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100003377: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
10000337e: 49 89 b7 18 00 00 00        	movq	%rsi, 0x18(%r15)
100003385: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
10000338c: 4d 89 fe                    	movq	%r15, %r14
10000338f: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100003396: 4c 89 e6                    	movq	%r12, %rsi
100003399: 48 b9 04 00 00 00 00 00 00 00       	movabsq	$0x4, %rcx
1000033a3: 48 0f af f1                 	imulq	%rcx, %rsi
1000033a7: 48 85 f6                    	testq	%rsi, %rsi
1000033aa: 0f 84 20 00 00 00           	je	0x1000033d0 <__text+0x23d0>
1000033b0: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000033b7: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
1000033be: 48 83 c3 08                 	addq	$0x8, %rbx
1000033c2: 49 83 c6 08                 	addq	$0x8, %r14
1000033c6: 48 83 ee 01                 	subq	$0x1, %rsi
1000033ca: 0f 85 e0 ff ff ff           	jne	0x1000033b0 <__text+0x23b0>
1000033d0: 4d 89 fe                    	movq	%r15, %r14
1000033d3: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000033da: 4c 89 e8                    	movq	%r13, %rax
1000033dd: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000033e4: 49 01 c6                    	addq	%rax, %r14
1000033e7: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
1000033ee: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
1000033f5: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
1000033fc: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100003403: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
10000340a: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100003411: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100003418: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
10000341f: 4c 89 bd 58 01 00 00        	movq	%r15, 0x158(%rbp)
100003426: 4c 8b 95 50 01 00 00        	movq	0x150(%rbp), %r10
10000342d: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003434: 48 85 c0                    	testq	%rax, %rax
100003437: 0f 84 89 00 00 00           	je	0x1000034c6 <__text+0x24c6>
10000343d: 49 89 c3                    	movq	%rax, %r11
100003440: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003447: f0                          	lock
100003448: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
10000344d: 0f 85 da ff ff ff           	jne	0x10000342d <__text+0x242d>
100003453: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
10000345a: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003461: 4c 01 d8                    	addq	%r11, %rax
100003464: 48 85 c0                    	testq	%rax, %rax
100003467: 0f 85 59 00 00 00           	jne	0x1000034c6 <__text+0x24c6>
10000346d: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003474: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
10000347e: 48 39 c8                    	cmpq	%rcx, %rax
100003481: 0f 84 e6 ff ff ff           	je	0x10000346d <__text+0x246d>
100003487: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003491: 48 39 c8                    	cmpq	%rcx, %rax
100003494: 0f 84 2c 00 00 00           	je	0x1000034c6 <__text+0x24c6>
10000349a: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000034a4: f0                          	lock
1000034a5: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000034aa: 0f 85 bd ff ff ff           	jne	0x10000346d <__text+0x246d>
1000034b0: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000034b7: 4c 89 d7                    	movq	%r10, %rdi
1000034ba: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
1000034c4: 0f 05                       	syscall
1000034c6: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
1000034cd: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000034d4: 48 89 81 00 00 00 00        	movq	%rax, (%rcx)
1000034db: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
1000034e2: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000034e7: f3 0f 10 85 e8 00 00 00     	movss	0xe8(%rbp), %xmm0
1000034ef: f3 0f 10 8d 00 01 00 00     	movss	0x100(%rbp), %xmm1
1000034f7: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000034fb: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000034fe: 0f 28 c6                    	movaps	%xmm6, %xmm0
100003501: 0f 28 cf                    	movaps	%xmm7, %xmm1
100003504: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003508: 0f 28 f0                    	movaps	%xmm0, %xmm6
10000350b: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100003512: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
100003519: 48 01 c8                    	addq	%rcx, %rax
10000351c: 71 0a                       	jno	0x100003528 <__text+0x2528>
10000351e: ba 01 00 00 00              	movl	$0x1, %edx
100003523: e9 42 00 00 00              	jmp	0x10000356a <__text+0x256a>
100003528: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
10000352f: 48 8b 85 78 01 00 00        	movq	0x178(%rbp), %rax
100003536: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
10000353d: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003542: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100003549: e9 3c fa ff ff              	jmp	0x100002f8a <__text+0x1f8a>
10000354e: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100003555: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
10000355c: 48 8b 85 80 01 00 00        	movq	0x180(%rbp), %rax
100003563: 31 d2                       	xorl	%edx, %edx
100003565: e9 00 00 00 00              	jmp	0x10000356a <__text+0x256a>
10000356a: 48 89 ec                    	movq	%rbp, %rsp
10000356d: 48 81 c4 b0 01 00 00        	addq	$0x1b0, %rsp            ## imm = 0x1B0
100003574: 5d                          	popq	%rbp
100003575: c3                          	retq
100003576: 55                          	pushq	%rbp
100003577: 48 89 e5                    	movq	%rsp, %rbp
10000357a: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
100003581: 48 89 e5                    	movq	%rsp, %rbp
100003584: 48 89 b5 10 00 00 00        	movq	%rsi, 0x10(%rbp)
10000358b: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
100003592: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
100003599: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
1000035a0: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
1000035a7: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000035b1: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000035b6: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000035c0: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
1000035c7: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
1000035d1: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000035d8: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
1000035df: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
1000035e6: 48 39 c8                    	cmpq	%rcx, %rax
1000035e9: 0f 9c c0                    	setl	%al
1000035ec: 48 0f b6 c0                 	movzbq	%al, %rax
1000035f0: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000035f7: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
1000035fe: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100003605: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
10000360c: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003613: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003618: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
10000361f: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100003626: 48 85 c0                    	testq	%rax, %rax
100003629: 0f 84 39 00 00 00           	je	0x100003668 <__text+0x2668>
10000362f: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100003639: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003640: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100003647: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
10000364e: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100003655: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
10000365c: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003661: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003668: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
10000366f: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
100003676: 48 39 c8                    	cmpq	%rcx, %rax
100003679: 0f 84 93 00 00 00           	je	0x100003712 <__text+0x2712>
10000367f: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100003686: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
10000368d: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100003694: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
10000369b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000036a5: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000036ac: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000036b3: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
1000036ba: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000036c1: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000036c8: e9 61 00 00 00              	jmp	0x10000372e <__text+0x272e>
1000036cd: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
1000036d4: 48 8b 8d 10 01 00 00        	movq	0x110(%rbp), %rcx
1000036db: 48 01 c8                    	addq	%rcx, %rax
1000036de: 71 0a                       	jno	0x1000036ea <__text+0x26ea>
1000036e0: ba 01 00 00 00              	movl	$0x1, %edx
1000036e5: e9 ae 01 00 00              	jmp	0x100003898 <__text+0x2898>
1000036ea: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
1000036f1: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
1000036f8: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
1000036ff: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003706: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
10000370d: e9 56 ff ff ff              	jmp	0x100003668 <__text+0x2668>
100003712: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100003719: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100003720: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100003727: 31 d2                       	xorl	%edx, %edx
100003729: e9 6a 01 00 00              	jmp	0x100003898 <__text+0x2898>
10000372e: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100003735: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
10000373c: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100003743: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
10000374a: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100003751: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100003758: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
10000375f: 48 8b 8d 70 00 00 00        	movq	0x70(%rbp), %rcx
100003766: 48 39 c8                    	cmpq	%rcx, %rax
100003769: 0f 8d 5e ff ff ff           	jge	0x1000036cd <__text+0x26cd>
10000376f: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100003776: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
10000377d: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100003784: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
10000378b: 48 8b 9d 80 00 00 00        	movq	0x80(%rbp), %rbx
100003792: 48 8b 8d 88 00 00 00        	movq	0x88(%rbp), %rcx
100003799: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
1000037a0: 48 85 c0                    	testq	%rax, %rax
1000037a3: 0f 89 03 00 00 00           	jns	0x1000037ac <__text+0x27ac>
1000037a9: 48 01 c8                    	addq	%rcx, %rax
1000037ac: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000037b3: 48 01 c3                    	addq	%rax, %rbx
1000037b6: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000037bd: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
1000037c4: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
1000037cb: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
1000037d2: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
1000037d9: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
1000037e0: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
1000037e7: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
1000037ee: 4c 8d bd b0 00 00 00        	leaq	0xb0(%rbp), %r15
1000037f5: 48 8d bd 90 00 00 00        	leaq	0x90(%rbp), %rdi
1000037fc: 48 8d b5 00 00 00 00        	leaq	(%rbp), %rsi
100003803: e8 96 ec ff ff              	callq	0x10000249e <__text+0x149e>
100003808: 48 85 d2                    	testq	%rdx, %rdx
10000380b: 0f 85 87 00 00 00           	jne	0x100003898 <__text+0x2898>
100003811: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003818: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000381d: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100003824: 66 48 0f 6e f8              	movq	%rax, %xmm7
100003829: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100003830: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100003835: 0f 28 c7                    	movaps	%xmm7, %xmm0
100003838: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
10000383c: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003840: 0f 28 f8                    	movaps	%xmm0, %xmm7
100003843: 0f 28 c6                    	movaps	%xmm6, %xmm0
100003846: 0f 28 cf                    	movaps	%xmm7, %xmm1
100003849: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000384d: 0f 28 f0                    	movaps	%xmm0, %xmm6
100003850: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000385a: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003861: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003868: 48 8b 8d f0 00 00 00        	movq	0xf0(%rbp), %rcx
10000386f: 48 01 c8                    	addq	%rcx, %rax
100003872: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100003879: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100003880: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003887: 66 48 0f 7e f0              	movq	%xmm6, %rax
10000388c: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100003893: e9 96 fe ff ff              	jmp	0x10000372e <__text+0x272e>
100003898: 48 89 ec                    	movq	%rbp, %rsp
10000389b: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
1000038a2: 5d                          	popq	%rbp
1000038a3: c3                          	retq
1000038a4: 55                          	pushq	%rbp
1000038a5: 48 89 e5                    	movq	%rsp, %rbp
1000038a8: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
1000038af: 48 89 e5                    	movq	%rsp, %rbp
1000038b2: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
1000038bc: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
1000038c3: 48 8b bd 00 00 00 00        	movq	(%rbp), %rdi
1000038ca: e8 31 d7 ff ff              	callq	0x100001000 <__text>
1000038cf: 48 85 d2                    	testq	%rdx, %rdx
1000038d2: 0f 85 fd 05 00 00           	jne	0x100003ed5 <__text+0x2ed5>
1000038d8: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
1000038df: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000038e9: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
1000038f0: 48 8b 8d 08 00 00 00        	movq	0x8(%rbp), %rcx
1000038f7: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
1000038fe: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100003905: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
10000390c: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003913: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
10000391a: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
100003921: 48 85 c0                    	testq	%rax, %rax
100003924: 0f 89 03 00 00 00           	jns	0x10000392d <__text+0x292d>
10000392a: 48 01 c8                    	addq	%rcx, %rax
10000392d: 48 85 c0                    	testq	%rax, %rax
100003930: 0f 89 0a 00 00 00           	jns	0x100003940 <__text+0x2940>
100003936: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003940: 48 39 c8                    	cmpq	%rcx, %rax
100003943: 0f 8e 03 00 00 00           	jle	0x10000394c <__text+0x294c>
100003949: 48 89 c8                    	movq	%rcx, %rax
10000394c: 48 8b 95 18 00 00 00        	movq	0x18(%rbp), %rdx
100003953: 48 85 d2                    	testq	%rdx, %rdx
100003956: 0f 89 03 00 00 00           	jns	0x10000395f <__text+0x295f>
10000395c: 48 01 ca                    	addq	%rcx, %rdx
10000395f: 48 85 d2                    	testq	%rdx, %rdx
100003962: 0f 89 0a 00 00 00           	jns	0x100003972 <__text+0x2972>
100003968: 48 ba 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdx
100003972: 48 39 ca                    	cmpq	%rcx, %rdx
100003975: 0f 8e 03 00 00 00           	jle	0x10000397e <__text+0x297e>
10000397b: 48 89 ca                    	movq	%rcx, %rdx
10000397e: 49 bb 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r11
100003988: 48 39 d0                    	cmpq	%rdx, %rax
10000398b: 0f 8d 06 00 00 00           	jge	0x100003997 <__text+0x2997>
100003991: 49 89 d3                    	movq	%rdx, %r11
100003994: 49 29 c3                    	subq	%rax, %r11
100003997: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
10000399e: 48 01 c3                    	addq	%rax, %rbx
1000039a1: 48 89 9d 20 00 00 00        	movq	%rbx, 0x20(%rbp)
1000039a8: 4c 89 9d 28 00 00 00        	movq	%r11, 0x28(%rbp)
1000039af: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
1000039b9: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
1000039c0: 48 8b bd 30 00 00 00        	movq	0x30(%rbp), %rdi
1000039c7: e8 34 d6 ff ff              	callq	0x100001000 <__text>
1000039cc: 48 85 d2                    	testq	%rdx, %rdx
1000039cf: 0f 85 00 05 00 00           	jne	0x100003ed5 <__text+0x2ed5>
1000039d5: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000039dc: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000039e3: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000039ea: 48 b8 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rax
1000039f4: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000039fb: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
100003a02: 48 8b b5 40 00 00 00        	movq	0x40(%rbp), %rsi
100003a09: e8 f1 de ff ff              	callq	0x1000018ff <__text+0x8ff>
100003a0e: 48 85 d2                    	testq	%rdx, %rdx
100003a11: 0f 85 be 04 00 00           	jne	0x100003ed5 <__text+0x2ed5>
100003a17: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003a1e: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003a28: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003a2d: f3 0f 10 85 48 00 00 00     	movss	0x48(%rbp), %xmm0
100003a35: 0f 28 ce                    	movaps	%xmm6, %xmm1
100003a38: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003a3b: 0f 97 c0                    	seta	%al
100003a3e: 48 0f b6 c0                 	movzbq	%al, %rax
100003a42: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
100003a49: 48 b8 00 01 00 00 00 00 00 00       	movabsq	$0x100, %rax    ## imm = 0x100
100003a53: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100003a5a: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
100003a61: 48 8b b5 60 00 00 00        	movq	0x60(%rbp), %rsi
100003a68: e8 09 fb ff ff              	callq	0x100003576 <__text+0x2576>
100003a6d: 48 85 d2                    	testq	%rdx, %rdx
100003a70: 0f 85 5f 04 00 00           	jne	0x100003ed5 <__text+0x2ed5>
100003a76: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100003a7d: f3 0f 10 85 68 00 00 00     	movss	0x68(%rbp), %xmm0
100003a85: f3 0f 10 8d 68 00 00 00     	movss	0x68(%rbp), %xmm1
100003a8d: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003a90: 0f 94 c0                    	sete	%al
100003a93: 0f 9b c1                    	setnp	%cl
100003a96: 20 c8                       	andb	%cl, %al
100003a98: 48 0f b6 c0                 	movzbq	%al, %rax
100003a9c: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100003aa3: 48 b8 89 88 08 3c 00 00 00 00       	movabsq	$0x3c088889, %rax ## imm = 0x3C088889
100003aad: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100003ab4: 48 8d 85 28 01 00 00        	leaq	0x128(%rbp), %rax
100003abb: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100003ac2: 48 8b bd 80 00 00 00        	movq	0x80(%rbp), %rdi
100003ac9: 48 8d b5 20 00 00 00        	leaq	0x20(%rbp), %rsi
100003ad0: 48 8b 95 78 00 00 00        	movq	0x78(%rbp), %rdx
100003ad7: e8 8b f3 ff ff              	callq	0x100002e67 <__text+0x1e67>
100003adc: 48 85 d2                    	testq	%rdx, %rdx
100003adf: 0f 85 f0 03 00 00           	jne	0x100003ed5 <__text+0x2ed5>
100003ae5: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100003aec: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003af6: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003afb: f3 0f 10 85 88 00 00 00     	movss	0x88(%rbp), %xmm0
100003b03: 0f 28 ce                    	movaps	%xmm6, %xmm1
100003b06: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003b09: 0f 86 7b 01 00 00           	jbe	0x100003c8a <__text+0x2c8a>
100003b0f: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003b16: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100003b1d: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003b27: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100003b2e: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100003b35: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003b3c: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003b43: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100003b4a: 48 85 c0                    	testq	%rax, %rax
100003b4d: 0f 89 03 00 00 00           	jns	0x100003b56 <__text+0x2b56>
100003b53: 48 01 c8                    	addq	%rcx, %rax
100003b56: 48 39 c8                    	cmpq	%rcx, %rax
100003b59: 0f 82 0f 00 00 00           	jb	0x100003b6e <__text+0x2b6e>
100003b5f: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003b69: e9 67 03 00 00              	jmp	0x100003ed5 <__text+0x2ed5>
100003b6e: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003b75: 48 01 c3                    	addq	%rax, %rbx
100003b78: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003b7f: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100003b86: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003b8d: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100003b94: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003b9b: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100003ba2: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003ba9: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100003bb0: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100003bb7: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003bbc: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003bc6: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
100003bcd: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
100003bd4: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003bdb: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003be2: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
100003be9: 48 85 c0                    	testq	%rax, %rax
100003bec: 0f 89 03 00 00 00           	jns	0x100003bf5 <__text+0x2bf5>
100003bf2: 48 01 c8                    	addq	%rcx, %rax
100003bf5: 48 39 c8                    	cmpq	%rcx, %rax
100003bf8: 0f 82 0f 00 00 00           	jb	0x100003c0d <__text+0x2c0d>
100003bfe: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003c08: e9 c8 02 00 00              	jmp	0x100003ed5 <__text+0x2ed5>
100003c0d: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003c14: 48 01 c3                    	addq	%rax, %rbx
100003c17: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003c1e: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100003c25: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003c2c: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003c33: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003c3a: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100003c41: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003c48: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100003c4f: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100003c56: 66 48 0f 6e f8              	movq	%rax, %xmm7
100003c5b: 0f 28 c6                    	movaps	%xmm6, %xmm0
100003c5e: 0f 28 cf                    	movaps	%xmm7, %xmm1
100003c61: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003c64: 0f 95 c0                    	setne	%al
100003c67: 0f 9a c1                    	setp	%cl
100003c6a: 08 c8                       	orb	%cl, %al
100003c6c: 48 0f b6 c0                 	movzbq	%al, %rax
100003c70: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003c77: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
100003c7e: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003c85: e9 11 00 00 00              	jmp	0x100003c9b <__text+0x2c9b>
100003c8a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003c94: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003c9b: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
100003ca2: 48 85 c0                    	testq	%rax, %rax
100003ca5: 0f 84 23 00 00 00           	je	0x100003cce <__text+0x2cce>
100003cab: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100003cb2: 48 85 c0                    	testq	%rax, %rax
100003cb5: 0f 84 13 00 00 00           	je	0x100003cce <__text+0x2cce>
100003cbb: 48 8b 85 a0 00 00 00        	movq	0xa0(%rbp), %rax
100003cc2: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003cc9: e9 11 00 00 00              	jmp	0x100003cdf <__text+0x2cdf>
100003cce: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003cd8: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003cdf: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003ce6: 48 85 c0                    	testq	%rax, %rax
100003ce9: 0f 84 33 00 00 00           	je	0x100003d22 <__text+0x2d22>
100003cef: 48 8d 35 1a 03 00 00        	leaq	0x31a(%rip), %rsi       ## 0x100004010
100003cf6: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003cfd: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003d04: 4c 89 c2                    	movq	%r8, %rdx
100003d07: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003d11: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003d1b: 0f 05                       	syscall
100003d1d: e9 2e 00 00 00              	jmp	0x100003d50 <__text+0x2d50>
100003d22: 48 8d 35 f7 02 00 00        	leaq	0x2f7(%rip), %rsi       ## 0x100004020
100003d29: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003d30: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003d37: 4c 89 c2                    	movq	%r8, %rdx
100003d3a: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003d44: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003d4e: 0f 05                       	syscall
100003d50: 48 8d 35 a9 02 00 00        	leaq	0x2a9(%rip), %rsi       ## 0x100004000
100003d57: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003d5e: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003d65: 4c 89 c2                    	movq	%r8, %rdx
100003d68: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003d72: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003d7c: 0f 05                       	syscall
100003d7e: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003d85: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003d8c: 4c 8b 95 20 01 00 00        	movq	0x120(%rbp), %r10
100003d93: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003d9a: 48 85 c0                    	testq	%rax, %rax
100003d9d: 0f 84 89 00 00 00           	je	0x100003e2c <__text+0x2e2c>
100003da3: 49 89 c3                    	movq	%rax, %r11
100003da6: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003dad: f0                          	lock
100003dae: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003db3: 0f 85 da ff ff ff           	jne	0x100003d93 <__text+0x2d93>
100003db9: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003dc0: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003dc7: 4c 01 d8                    	addq	%r11, %rax
100003dca: 48 85 c0                    	testq	%rax, %rax
100003dcd: 0f 85 59 00 00 00           	jne	0x100003e2c <__text+0x2e2c>
100003dd3: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003dda: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003de4: 48 39 c8                    	cmpq	%rcx, %rax
100003de7: 0f 84 e6 ff ff ff           	je	0x100003dd3 <__text+0x2dd3>
100003ded: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003df7: 48 39 c8                    	cmpq	%rcx, %rax
100003dfa: 0f 84 2c 00 00 00           	je	0x100003e2c <__text+0x2e2c>
100003e00: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100003e0a: f0                          	lock
100003e0b: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003e10: 0f 85 bd ff ff ff           	jne	0x100003dd3 <__text+0x2dd3>
100003e16: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100003e1d: 4c 89 d7                    	movq	%r10, %rdi
100003e20: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100003e2a: 0f 05                       	syscall
100003e2c: 4c 8b 95 08 00 00 00        	movq	0x8(%rbp), %r10
100003e33: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003e3a: 48 85 c0                    	testq	%rax, %rax
100003e3d: 0f 84 89 00 00 00           	je	0x100003ecc <__text+0x2ecc>
100003e43: 49 89 c3                    	movq	%rax, %r11
100003e46: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003e4d: f0                          	lock
100003e4e: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003e53: 0f 85 da ff ff ff           	jne	0x100003e33 <__text+0x2e33>
100003e59: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003e60: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003e67: 4c 01 d8                    	addq	%r11, %rax
100003e6a: 48 85 c0                    	testq	%rax, %rax
100003e6d: 0f 85 59 00 00 00           	jne	0x100003ecc <__text+0x2ecc>
100003e73: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003e7a: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003e84: 48 39 c8                    	cmpq	%rcx, %rax
100003e87: 0f 84 e6 ff ff ff           	je	0x100003e73 <__text+0x2e73>
100003e8d: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003e97: 48 39 c8                    	cmpq	%rcx, %rax
100003e9a: 0f 84 2c 00 00 00           	je	0x100003ecc <__text+0x2ecc>
100003ea0: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100003eaa: f0                          	lock
100003eab: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003eb0: 0f 85 bd ff ff ff           	jne	0x100003e73 <__text+0x2e73>
100003eb6: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100003ebd: 4c 89 d7                    	movq	%r10, %rdi
100003ec0: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100003eca: 0f 05                       	syscall
100003ecc: 31 c0                       	xorl	%eax, %eax
100003ece: 31 d2                       	xorl	%edx, %edx
100003ed0: e9 00 00 00 00              	jmp	0x100003ed5 <__text+0x2ed5>
100003ed5: 48 89 ec                    	movq	%rbp, %rsp
100003ed8: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
100003edf: 5d                          	popq	%rbp
100003ee0: c3                          	retq
100003ee1: 53                          	pushq	%rbx
100003ee2: 41 54                       	pushq	%r12
100003ee4: 41 55                       	pushq	%r13
100003ee6: 41 56                       	pushq	%r14
100003ee8: 41 57                       	pushq	%r15
100003eea: e8 b5 f9 ff ff              	callq	0x1000038a4 <__text+0x28a4>
100003eef: 48 85 d2                    	testq	%rdx, %rdx
100003ef2: 0f 95 c2                    	setne	%dl
100003ef5: 0f b6 d2                    	movzbl	%dl, %edx
100003ef8: 48 89 d0                    	movq	%rdx, %rax
100003efb: 41 5f                       	popq	%r15
100003efd: 41 5e                       	popq	%r14
100003eff: 41 5d                       	popq	%r13
100003f01: 41 5c                       	popq	%r12
100003f03: 5b                          	popq	%rbx
100003f04: c3                          	retq
		...
100003ffd: 00 00                       	addb	%al, (%rax)
100003fff: 00                          	<unknown>
