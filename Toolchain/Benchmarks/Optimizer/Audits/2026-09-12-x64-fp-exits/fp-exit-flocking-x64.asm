
/private/tmp/silex-part03-evidence/fp-exit-flocking-macos-x64:	file format mach-o 64-bit x86-64

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
10000199c: 44 0f 28 f6                 	movaps	%xmm6, %xmm14
1000019a0: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
1000019a7: 48 85 c0                    	testq	%rax, %rax
1000019aa: 0f 84 31 00 00 00           	je	0x1000019e1 <__text+0x9e1>
1000019b0: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000019ba: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000019c1: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000019c8: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
1000019cf: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000019d6: 48 89 85 28 04 00 00        	movq	%rax, 0x428(%rbp)
1000019dd: 44 0f 28 f6                 	movaps	%xmm6, %xmm14
1000019e1: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
1000019e8: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
1000019ef: 48 39 c8                    	cmpq	%rcx, %rax
1000019f2: 0f 84 37 01 00 00           	je	0x100001b2f <__text+0xb2f>
1000019f8: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
1000019ff: 48 89 c1                    	movq	%rax, %rcx
100001a02: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100001a07: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100001a0b: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100001a15: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001a1a: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001a1e: 0f 82 39 00 00 00           	jb	0x100001a5d <__text+0xa5d>
100001a24: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001a2e: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001a33: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001a37: 0f 83 20 00 00 00           	jae	0x100001a5d <__text+0xa5d>
100001a3d: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001a42: 48 39 c8                    	cmpq	%rcx, %rax
100001a45: 0f 85 12 00 00 00           	jne	0x100001a5d <__text+0xa5d>
100001a4b: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001a4f: 66 0f 7e d8                 	movd	%xmm3, %eax
100001a53: 66 4c 0f 6e d8              	movq	%rax, %xmm11
100001a58: e9 3d 00 00 00              	jmp	0x100001a9a <__text+0xa9a>
100001a5d: 48 8d 35 74 28 00 00        	leaq	0x2874(%rip), %rsi      ## 0x1000042d8
100001a64: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001a6b: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001a72: 4c 89 c2                    	movq	%r8, %rdx
100001a75: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001a7f: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100001a89: 0f 05                       	syscall
100001a8b: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001a95: e9 9c 09 00 00              	jmp	0x100002436 <__text+0x1436>
100001a9a: 48 b8 6f 12 83 3a 00 00 00 00       	movabsq	$0x3a83126f, %rax ## imm = 0x3A83126F
100001aa4: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001aa9: 41 0f 28 c3                 	movaps	%xmm11, %xmm0
100001aad: 0f 28 ce                    	movaps	%xmm6, %xmm1
100001ab0: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001ab4: 44 0f 28 d8                 	movaps	%xmm0, %xmm11
100001ab8: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001abf: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100001ac6: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100001acd: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100001ad4: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001ade: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100001ae5: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100001aec: 48 89 85 30 04 00 00        	movq	%rax, 0x430(%rbp)
100001af3: e9 51 00 00 00              	jmp	0x100001b49 <__text+0xb49>
100001af8: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
100001aff: 48 8b 8d 28 04 00 00        	movq	0x428(%rbp), %rcx
100001b06: 48 01 c8                    	addq	%rcx, %rax
100001b09: 71 0a                       	jno	0x100001b15 <__text+0xb15>
100001b0b: ba 01 00 00 00              	movl	$0x1, %edx
100001b10: e9 21 09 00 00              	jmp	0x100002436 <__text+0x1436>
100001b15: 48 89 85 10 04 00 00        	movq	%rax, 0x410(%rbp)
100001b1c: 48 8b 85 10 04 00 00        	movq	0x410(%rbp), %rax
100001b23: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
100001b2a: e9 b2 fe ff ff              	jmp	0x1000019e1 <__text+0x9e1>
100001b2f: 66 4c 0f 7e f0              	movq	%xmm14, %rax
100001b34: 48 89 85 18 04 00 00        	movq	%rax, 0x418(%rbp)
100001b3b: 48 8b 85 18 04 00 00        	movq	0x418(%rbp), %rax
100001b42: 31 d2                       	xorl	%edx, %edx
100001b44: e9 ed 08 00 00              	jmp	0x100002436 <__text+0x1436>
100001b49: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100001b50: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100001b57: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100001b5e: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
100001b65: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100001b6c: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
100001b73: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001b7a: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
100001b81: 48 39 c8                    	cmpq	%rcx, %rax
100001b84: 0f 8d 6e ff ff ff           	jge	0x100001af8 <__text+0xaf8>
100001b8a: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100001b91: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100001b98: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100001b9f: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100001ba6: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100001bad: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
100001bb4: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001bbb: 48 85 c0                    	testq	%rax, %rax
100001bbe: 0f 89 03 00 00 00           	jns	0x100001bc7 <__text+0xbc7>
100001bc4: 48 01 c8                    	addq	%rcx, %rax
100001bc7: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100001bce: 48 01 c3                    	addq	%rax, %rbx
100001bd1: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001bd8: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100001bdf: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100001be6: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100001bed: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100001bf4: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100001bfb: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001c02: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100001c09: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c13: 66 4c 0f 6e e0              	movq	%rax, %xmm12
100001c18: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c22: 66 4c 0f 6e e8              	movq	%rax, %xmm13
100001c27: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c31: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100001c38: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c42: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100001c49: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c53: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100001c5a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c64: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100001c6b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c75: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100001c7c: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001c83: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100001c8a: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100001c91: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100001c98: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001ca2: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100001ca9: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100001cb0: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100001cb7: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
100001cbe: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001cc5: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100001ccc: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100001cd3: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
100001cda: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
100001ce1: 48 8b 85 f0 00 00 00        	movq	0xf0(%rbp), %rax
100001ce8: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
100001cef: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100001cf6: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
100001cfd: e9 3c 00 00 00              	jmp	0x100001d3e <__text+0xd3e>
100001d02: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001d0c: 48 89 85 08 04 00 00        	movq	%rax, 0x408(%rbp)
100001d13: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001d1a: 48 8b 8d 08 04 00 00        	movq	0x408(%rbp), %rcx
100001d21: 48 01 c8                    	addq	%rcx, %rax
100001d24: 48 89 85 00 04 00 00        	movq	%rax, 0x400(%rbp)
100001d2b: 48 8b 85 00 04 00 00        	movq	0x400(%rbp), %rax
100001d32: 48 89 85 30 04 00 00        	movq	%rax, 0x430(%rbp)
100001d39: e9 0b fe ff ff              	jmp	0x100001b49 <__text+0xb49>
100001d3e: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001d45: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100001d4c: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001d53: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100001d5a: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100001d61: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100001d68: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001d6f: 48 8b 8d 28 01 00 00        	movq	0x128(%rbp), %rcx
100001d76: 48 39 c8                    	cmpq	%rcx, %rax
100001d79: 0f 8d 60 01 00 00           	jge	0x100001edf <__text+0xedf>
100001d7f: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001d86: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100001d8d: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001d94: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100001d9b: 48 8b 9d 38 01 00 00        	movq	0x138(%rbp), %rbx
100001da2: 48 8b 8d 40 01 00 00        	movq	0x140(%rbp), %rcx
100001da9: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001db0: 48 85 c0                    	testq	%rax, %rax
100001db3: 0f 89 03 00 00 00           	jns	0x100001dbc <__text+0xdbc>
100001db9: 48 01 c8                    	addq	%rcx, %rax
100001dbc: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100001dc3: 48 01 c3                    	addq	%rax, %rbx
100001dc6: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001dcd: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100001dd4: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100001ddb: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100001de2: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100001de9: 48 89 85 58 01 00 00        	movq	%rax, 0x158(%rbp)
100001df0: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001df7: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100001dfe: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100001e05: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001e0a: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001e0d: 41 0f 28 cb                 	movaps	%xmm11, %xmm1
100001e11: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001e15: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001e18: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001e1f: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001e24: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001e27: 0f 28 cf                    	movaps	%xmm7, %xmm1
100001e2a: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100001e2e: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100001e32: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100001e39: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001e3e: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001e45: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001e4a: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001e4d: 0f 28 cf                    	movaps	%xmm7, %xmm1
100001e50: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100001e54: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100001e58: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100001e5c: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100001e60: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001e64: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001e67: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100001e6b: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100001e6f: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001e73: 44 0f 28 d0                 	movaps	%xmm0, %xmm10
100001e77: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001e7a: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100001e7e: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001e82: 0f 28 f8                    	movaps	%xmm0, %xmm7
100001e85: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001e8f: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001e94: 0f 28 c7                    	movaps	%xmm7, %xmm0
100001e97: 0f 28 ce                    	movaps	%xmm6, %xmm1
100001e9a: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100001e9d: 0f 87 69 00 00 00           	ja	0x100001f0c <__text+0xf0c>
100001ea3: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001ead: 48 89 85 b8 02 00 00        	movq	%rax, 0x2b8(%rbp)
100001eb4: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001ebb: 48 8b 8d b8 02 00 00        	movq	0x2b8(%rbp), %rcx
100001ec2: 48 01 c8                    	addq	%rcx, %rax
100001ec5: 48 89 85 b0 02 00 00        	movq	%rax, 0x2b0(%rbp)
100001ecc: 48 8b 85 b0 02 00 00        	movq	0x2b0(%rbp), %rax
100001ed3: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001eda: e9 5f fe ff ff              	jmp	0x100001d3e <__text+0xd3e>
100001edf: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001ee9: 48 89 85 c0 02 00 00        	movq	%rax, 0x2c0(%rbp)
100001ef0: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100001ef7: 48 8b 8d c0 02 00 00        	movq	0x2c0(%rbp), %rcx
100001efe: 48 39 c8                    	cmpq	%rcx, %rax
100001f01: 0f 8f a7 02 00 00           	jg	0x1000021ae <__text+0x11ae>
100001f07: e9 f6 fd ff ff              	jmp	0x100001d02 <__text+0xd02>
100001f0c: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
100001f16: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001f1b: 0f 28 c7                    	movaps	%xmm7, %xmm0
100001f1e: 0f 28 ce                    	movaps	%xmm6, %xmm1
100001f21: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100001f24: 0f 8a 79 ff ff ff           	jp	0x100001ea3 <__text+0xea3>
100001f2a: 0f 83 73 ff ff ff           	jae	0x100001ea3 <__text+0xea3>
100001f30: 48 8b 85 68 04 00 00        	movq	0x468(%rbp), %rax
100001f37: 48 89 85 d8 01 00 00        	movq	%rax, 0x1d8(%rbp)
100001f3e: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001f45: 48 89 85 e0 01 00 00        	movq	%rax, 0x1e0(%rbp)
100001f4c: 48 8b 85 70 04 00 00        	movq	0x470(%rbp), %rax
100001f53: 48 89 85 f0 01 00 00        	movq	%rax, 0x1f0(%rbp)
100001f5a: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001f61: 48 89 85 f8 01 00 00        	movq	%rax, 0x1f8(%rbp)
100001f68: f3 0f 10 9d d8 01 00 00     	movss	0x1d8(%rbp), %xmm3
100001f70: f3 0f 10 ad f0 01 00 00     	movss	0x1f0(%rbp), %xmm5
100001f78: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100001f7b: f3 0f 10 a5 e0 01 00 00     	movss	0x1e0(%rbp), %xmm4
100001f83: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100001f8b: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100001f8e: 0f 28 c3                    	movaps	%xmm3, %xmm0
100001f91: 0f 58 c4                    	addps	%xmm4, %xmm0
100001f94: f3 0f 11 85 e8 01 00 00     	movss	%xmm0, 0x1e8(%rbp)
100001f9c: 0f 28 e8                    	movaps	%xmm0, %xmm5
100001f9f: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100001fa3: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
100001fab: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
100001fb2: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
100001fb9: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
100001fc0: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
100001fc7: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
100001fce: 48 89 85 20 02 00 00        	movq	%rax, 0x220(%rbp)
100001fd5: 48 8b 85 60 01 00 00        	movq	0x160(%rbp), %rax
100001fdc: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100001fe3: f3 0f 10 9d 08 02 00 00     	movss	0x208(%rbp), %xmm3
100001feb: f3 0f 10 ad 20 02 00 00     	movss	0x220(%rbp), %xmm5
100001ff3: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100001ff6: f3 0f 10 a5 10 02 00 00     	movss	0x210(%rbp), %xmm4
100001ffe: f3 0f 10 ad 28 02 00 00     	movss	0x228(%rbp), %xmm5
100002006: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002009: 0f 28 cb                    	movaps	%xmm3, %xmm1
10000200c: 0f 58 cc                    	addps	%xmm4, %xmm1
10000200f: f3 0f 11 8d 18 02 00 00     	movss	%xmm1, 0x218(%rbp)
100002017: 0f 28 e9                    	movaps	%xmm1, %xmm5
10000201a: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
10000201e: f3 0f 11 ad 30 02 00 00     	movss	%xmm5, 0x230(%rbp)
100002026: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002030: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
100002037: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
10000203e: 48 8b 8d 38 02 00 00        	movq	0x238(%rbp), %rcx
100002045: 48 01 c8                    	addq	%rcx, %rax
100002048: 71 0a                       	jno	0x100002054 <__text+0x1054>
10000204a: ba 01 00 00 00              	movl	$0x1, %edx
10000204f: e9 e2 03 00 00              	jmp	0x100002436 <__text+0x1436>
100002054: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
10000205b: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
100002065: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000206a: 0f 28 c7                    	movaps	%xmm7, %xmm0
10000206d: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002070: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002073: 0f 92 c0                    	setb	%al
100002076: 0f 9b c1                    	setnp	%cl
100002079: 20 c8                       	andb	%cl, %al
10000207b: 48 0f b6 c0                 	movzbq	%al, %rax
10000207f: 48 89 85 50 02 00 00        	movq	%rax, 0x250(%rbp)
100002086: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
10000208d: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100002094: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
10000209b: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
1000020a2: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
1000020a9: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
1000020b0: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
1000020b7: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
1000020be: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
1000020c5: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
1000020cc: 48 8b 85 50 02 00 00        	movq	0x250(%rbp), %rax
1000020d3: 48 85 c0                    	testq	%rax, %rax
1000020d6: 0f 84 c7 fd ff ff           	je	0x100001ea3 <__text+0xea3>
1000020dc: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
1000020e6: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000020eb: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
1000020f5: 66 4c 0f 6e d0              	movq	%rax, %xmm10
1000020fa: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000020fd: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100002101: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002104: 0f 97 c0                    	seta	%al
100002107: 48 0f b6 c0                 	movzbq	%al, %rax
10000210b: 48 89 85 68 02 00 00        	movq	%rax, 0x268(%rbp)
100002112: 48 8b 85 68 02 00 00        	movq	0x268(%rbp), %rax
100002119: 48 85 c0                    	testq	%rax, %rax
10000211c: 0f 84 03 00 00 00           	je	0x100002125 <__text+0x1125>
100002122: 0f 28 f7                    	movaps	%xmm7, %xmm6
100002125: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002129: 0f 28 ce                    	movaps	%xmm6, %xmm1
10000212c: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002130: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002134: 41 0f 28 c4                 	movaps	%xmm12, %xmm0
100002138: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
10000213c: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002140: 44 0f 28 e0                 	movaps	%xmm0, %xmm12
100002144: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002148: 0f 28 ce                    	movaps	%xmm6, %xmm1
10000214b: f3 0f 5e c1                 	divss	%xmm1, %xmm0
10000214f: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100002153: 41 0f 28 c5                 	movaps	%xmm13, %xmm0
100002157: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
10000215b: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000215f: 44 0f 28 e8                 	movaps	%xmm0, %xmm13
100002163: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
10000216a: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100002171: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
100002178: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
10000217f: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
100002186: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
10000218d: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100002194: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
10000219b: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
1000021a2: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
1000021a9: e9 f5 fc ff ff              	jmp	0x100001ea3 <__text+0xea3>
1000021ae: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
1000021b5: 48 89 c1                    	movq	%rax, %rcx
1000021b8: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
1000021bd: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
1000021c1: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
1000021cb: 66 48 0f 6e e2              	movq	%rdx, %xmm4
1000021d0: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
1000021d4: 0f 82 39 00 00 00           	jb	0x100002213 <__text+0x1213>
1000021da: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
1000021e4: 66 48 0f 6e e2              	movq	%rdx, %xmm4
1000021e9: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
1000021ed: 0f 83 20 00 00 00           	jae	0x100002213 <__text+0x1213>
1000021f3: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
1000021f8: 48 39 c8                    	cmpq	%rcx, %rax
1000021fb: 0f 85 12 00 00 00           	jne	0x100002213 <__text+0x1213>
100002201: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100002205: 66 0f 7e d8                 	movd	%xmm3, %eax
100002209: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000220e: e9 3d 00 00 00              	jmp	0x100002250 <__text+0x1250>
100002213: 48 8d 35 1e 22 00 00        	leaq	0x221e(%rip), %rsi      ## 0x100004438
10000221a: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100002221: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100002228: 4c 89 c2                    	movq	%r8, %rdx
10000222b: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100002235: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
10000223f: 0f 05                       	syscall
100002241: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000224b: e9 e6 01 00 00              	jmp	0x100002436 <__text+0x1436>
100002250: 48 8b 85 68 04 00 00        	movq	0x468(%rbp), %rax
100002257: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000225c: 0f 28 c7                    	movaps	%xmm7, %xmm0
10000225f: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002262: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002266: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002269: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100002270: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002275: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002278: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
10000227c: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002280: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002283: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
10000228d: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002292: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002295: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002299: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000229d: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000022a0: 48 8b 85 70 04 00 00        	movq	0x470(%rbp), %rax
1000022a7: 66 4c 0f 6e c0              	movq	%rax, %xmm8
1000022ac: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000022b0: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000022b3: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000022b7: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000022bb: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
1000022c2: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000022c7: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000022cb: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
1000022cf: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000022d3: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000022d7: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
1000022e1: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000022e6: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000022ea: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
1000022ee: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000022f2: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000022f6: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000022f9: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
1000022fd: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002301: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002304: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
10000230b: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002310: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002314: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002317: f3 0f 5e c1                 	divss	%xmm1, %xmm0
10000231b: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
10000231f: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
100002326: 66 4c 0f 6e c8              	movq	%rax, %xmm9
10000232b: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
10000232f: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002333: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002337: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
10000233b: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002345: 66 4c 0f 6e c8              	movq	%rax, %xmm9
10000234a: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
10000234e: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002352: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002356: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
10000235a: 0f 28 c7                    	movaps	%xmm7, %xmm0
10000235d: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002361: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002365: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002368: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
10000236f: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002374: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002378: 0f 28 ce                    	movaps	%xmm6, %xmm1
10000237b: f3 0f 5e c1                 	divss	%xmm1, %xmm0
10000237f: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002383: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
10000238a: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000238f: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002393: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002396: f3 0f 5c c1                 	subss	%xmm1, %xmm0
10000239a: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
10000239e: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
1000023a8: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000023ad: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000023b1: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000023b4: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000023b8: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000023bc: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000023bf: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
1000023c3: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000023c7: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000023ca: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
1000023d4: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000023d9: 41 0f 28 c4                 	movaps	%xmm12, %xmm0
1000023dd: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000023e0: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000023e4: 44 0f 28 e0                 	movaps	%xmm0, %xmm12
1000023e8: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000023eb: 41 0f 28 cc                 	movaps	%xmm12, %xmm1
1000023ef: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000023f3: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000023f6: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002400: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002405: 41 0f 28 c5                 	movaps	%xmm13, %xmm0
100002409: 0f 28 ce                    	movaps	%xmm6, %xmm1
10000240c: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002410: 44 0f 28 e8                 	movaps	%xmm0, %xmm13
100002414: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002417: 41 0f 28 cd                 	movaps	%xmm13, %xmm1
10000241b: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000241f: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002422: 41 0f 28 c6                 	movaps	%xmm14, %xmm0
100002426: 0f 28 cf                    	movaps	%xmm7, %xmm1
100002429: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000242d: 44 0f 28 f0                 	movaps	%xmm0, %xmm14
100002431: e9 cc f8 ff ff              	jmp	0x100001d02 <__text+0xd02>
100002436: 48 89 ec                    	movq	%rbp, %rsp
100002439: 48 81 c4 a0 04 00 00        	addq	$0x4a0, %rsp            ## imm = 0x4A0
100002440: 5d                          	popq	%rbp
100002441: c3                          	retq
100002442: 55                          	pushq	%rbp
100002443: 48 89 e5                    	movq	%rsp, %rbp
100002446: 48 81 ec 00 04 00 00        	subq	$0x400, %rsp            ## imm = 0x400
10000244d: 48 89 e5                    	movq	%rsp, %rbp
100002450: 4c 89 bd 30 00 00 00        	movq	%r15, 0x30(%rbp)
100002457: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
10000245e: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100002465: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
10000246c: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100002473: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
10000247a: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
100002481: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
100002488: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
10000248f: 48 8b 87 10 00 00 00        	movq	0x10(%rdi), %rax
100002496: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
10000249d: 48 8b 87 18 00 00 00        	movq	0x18(%rdi), %rax
1000024a4: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
1000024ab: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
1000024b2: 66 4c 0f 6e d8              	movq	%rax, %xmm11
1000024b7: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
1000024be: 66 4c 0f 6e e0              	movq	%rax, %xmm12
1000024c3: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
1000024ca: 66 4c 0f 6e e8              	movq	%rax, %xmm13
1000024cf: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
1000024d6: 66 4c 0f 6e f0              	movq	%rax, %xmm14
1000024db: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000024e5: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
1000024ec: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000024f6: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
1000024fd: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002507: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
10000250e: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002518: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
10000251f: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002529: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100002530: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000253a: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100002541: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000254b: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100002552: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100002559: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100002560: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002567: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
10000256e: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002578: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
10000257f: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
100002586: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
10000258d: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100002594: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
10000259b: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
1000025a2: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
1000025a9: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
1000025b0: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
1000025b7: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
1000025be: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
1000025c5: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
1000025cc: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
1000025d3: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000025da: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
1000025e1: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
1000025e8: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
1000025ef: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000025f6: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000025fd: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100002604: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
10000260b: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100002612: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
100002619: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
100002620: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
100002627: 48 39 c8                    	cmpq	%rcx, %rax
10000262a: 0f 8d 3c 01 00 00           	jge	0x10000276c <__text+0x176c>
100002630: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
100002637: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
10000263e: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100002645: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
10000264c: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100002653: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
10000265a: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
100002661: 48 85 c0                    	testq	%rax, %rax
100002664: 0f 89 03 00 00 00           	jns	0x10000266d <__text+0x166d>
10000266a: 48 01 c8                    	addq	%rcx, %rax
10000266d: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002674: 48 01 c3                    	addq	%rax, %rbx
100002677: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000267e: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100002685: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
10000268c: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100002693: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
10000269a: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
1000026a1: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
1000026a8: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
1000026af: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
1000026b6: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000026bb: 41 0f 28 c3                 	movaps	%xmm11, %xmm0
1000026bf: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000026c2: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000026c6: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000026ca: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
1000026d1: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000026d6: 41 0f 28 c4                 	movaps	%xmm12, %xmm0
1000026da: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000026dd: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000026e1: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000026e5: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000026e9: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
1000026ed: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000026f1: 0f 28 f0                    	movaps	%xmm0, %xmm6
1000026f4: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000026f8: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
1000026fc: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002700: 44 0f 28 d0                 	movaps	%xmm0, %xmm10
100002704: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002707: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
10000270b: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000270f: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002712: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000271c: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002721: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002724: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002727: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
10000272a: 0f 87 69 00 00 00           	ja	0x100002799 <__text+0x1799>
100002730: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000273a: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
100002741: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
100002748: 48 8b 8d 10 02 00 00        	movq	0x210(%rbp), %rcx
10000274f: 48 01 c8                    	addq	%rcx, %rax
100002752: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
100002759: 48 8b 85 08 02 00 00        	movq	0x208(%rbp), %rax
100002760: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
100002767: e9 83 fe ff ff              	jmp	0x1000025ef <__text+0x15ef>
10000276c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002776: 48 89 85 18 02 00 00        	movq	%rax, 0x218(%rbp)
10000277d: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002784: 48 8b 8d 18 02 00 00        	movq	0x218(%rbp), %rcx
10000278b: 48 39 c8                    	cmpq	%rcx, %rax
10000278e: 0f 84 0a 03 00 00           	je	0x100002a9e <__text+0x1a9e>
100002794: e9 77 03 00 00              	jmp	0x100002b10 <__text+0x1b10>
100002799: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
1000027a3: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000027a8: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000027ab: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000027ae: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
1000027b1: 0f 8a 79 ff ff ff           	jp	0x100002730 <__text+0x1730>
1000027b7: 0f 83 73 ff ff ff           	jae	0x100002730 <__text+0x1730>
1000027bd: 48 8b 85 c0 03 00 00        	movq	0x3c0(%rbp), %rax
1000027c4: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
1000027cb: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
1000027d2: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
1000027d9: 48 8b 85 c8 03 00 00        	movq	0x3c8(%rbp), %rax
1000027e0: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
1000027e7: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
1000027ee: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
1000027f5: f3 0f 10 9d 30 01 00 00     	movss	0x130(%rbp), %xmm3
1000027fd: f3 0f 10 ad 48 01 00 00     	movss	0x148(%rbp), %xmm5
100002805: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002808: f3 0f 10 a5 38 01 00 00     	movss	0x138(%rbp), %xmm4
100002810: f3 0f 10 ad 50 01 00 00     	movss	0x150(%rbp), %xmm5
100002818: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
10000281b: 0f 28 c3                    	movaps	%xmm3, %xmm0
10000281e: 0f 58 c4                    	addps	%xmm4, %xmm0
100002821: f3 0f 11 85 40 01 00 00     	movss	%xmm0, 0x140(%rbp)
100002829: 0f 28 e8                    	movaps	%xmm0, %xmm5
10000282c: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002830: f3 0f 11 ad 58 01 00 00     	movss	%xmm5, 0x158(%rbp)
100002838: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
10000283f: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100002846: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
10000284d: 48 89 85 68 01 00 00        	movq	%rax, 0x168(%rbp)
100002854: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
10000285b: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
100002862: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
100002869: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
100002870: f3 0f 10 9d 60 01 00 00     	movss	0x160(%rbp), %xmm3
100002878: f3 0f 10 ad 78 01 00 00     	movss	0x178(%rbp), %xmm5
100002880: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002883: f3 0f 10 a5 68 01 00 00     	movss	0x168(%rbp), %xmm4
10000288b: f3 0f 10 ad 80 01 00 00     	movss	0x180(%rbp), %xmm5
100002893: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002896: 0f 28 cb                    	movaps	%xmm3, %xmm1
100002899: 0f 58 cc                    	addps	%xmm4, %xmm1
10000289c: f3 0f 11 8d 70 01 00 00     	movss	%xmm1, 0x170(%rbp)
1000028a4: 0f 28 e9                    	movaps	%xmm1, %xmm5
1000028a7: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
1000028ab: f3 0f 11 ad 88 01 00 00     	movss	%xmm5, 0x188(%rbp)
1000028b3: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000028bd: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
1000028c4: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
1000028cb: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
1000028d2: 48 01 c8                    	addq	%rcx, %rax
1000028d5: 71 0a                       	jno	0x1000028e1 <__text+0x18e1>
1000028d7: ba 01 00 00 00              	movl	$0x1, %edx
1000028dc: e9 d1 04 00 00              	jmp	0x100002db2 <__text+0x1db2>
1000028e1: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
1000028e8: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
1000028f2: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000028f7: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000028fa: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000028fd: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002900: 0f 92 c0                    	setb	%al
100002903: 0f 9b c1                    	setnp	%cl
100002906: 20 c8                       	andb	%cl, %al
100002908: 48 0f b6 c0                 	movzbq	%al, %rax
10000290c: 48 89 85 a8 01 00 00        	movq	%rax, 0x1a8(%rbp)
100002913: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
10000291a: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
100002921: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002928: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
10000292f: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002936: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
10000293d: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
100002944: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
10000294b: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
100002952: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
100002959: 48 8b 85 a8 01 00 00        	movq	0x1a8(%rbp), %rax
100002960: 48 85 c0                    	testq	%rax, %rax
100002963: 0f 84 c7 fd ff ff           	je	0x100002730 <__text+0x1730>
100002969: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100002973: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002978: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100002982: 66 4c 0f 6e d0              	movq	%rax, %xmm10
100002987: 0f 28 c7                    	movaps	%xmm7, %xmm0
10000298a: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
10000298e: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002991: 0f 97 c0                    	seta	%al
100002994: 48 0f b6 c0                 	movzbq	%al, %rax
100002998: 48 89 85 c0 01 00 00        	movq	%rax, 0x1c0(%rbp)
10000299f: 48 8b 85 c0 01 00 00        	movq	0x1c0(%rbp), %rax
1000029a6: 48 85 c0                    	testq	%rax, %rax
1000029a9: 0f 84 03 00 00 00           	je	0x1000029b2 <__text+0x19b2>
1000029af: 0f 28 f7                    	movaps	%xmm7, %xmm6
1000029b2: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
1000029b9: 48 89 85 c8 01 00 00        	movq	%rax, 0x1c8(%rbp)
1000029c0: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000029c4: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000029c7: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000029cb: f3 0f 11 85 d8 01 00 00     	movss	%xmm0, 0x1d8(%rbp)
1000029d3: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
1000029da: 48 89 85 e8 01 00 00        	movq	%rax, 0x1e8(%rbp)
1000029e1: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000029e5: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000029e8: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000029ec: f3 0f 11 85 f8 01 00 00     	movss	%xmm0, 0x1f8(%rbp)
1000029f4: f3 0f 10 9d c8 01 00 00     	movss	0x1c8(%rbp), %xmm3
1000029fc: f3 0f 10 ad e8 01 00 00     	movss	0x1e8(%rbp), %xmm5
100002a04: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002a07: f3 0f 10 a5 d8 01 00 00     	movss	0x1d8(%rbp), %xmm4
100002a0f: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100002a17: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002a1a: 0f 28 d3                    	movaps	%xmm3, %xmm2
100002a1d: 0f 58 d4                    	addps	%xmm4, %xmm2
100002a20: f3 0f 11 95 e0 01 00 00     	movss	%xmm2, 0x1e0(%rbp)
100002a28: 0f 28 ea                    	movaps	%xmm2, %xmm5
100002a2b: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002a2f: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
100002a37: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100002a3e: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
100002a45: 48 8b 85 e0 01 00 00        	movq	0x1e0(%rbp), %rax
100002a4c: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
100002a53: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002a5a: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
100002a61: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
100002a68: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
100002a6f: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
100002a76: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
100002a7d: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002a84: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
100002a8b: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100002a92: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
100002a99: e9 92 fc ff ff              	jmp	0x100002730 <__text+0x1730>
100002a9e: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002aa8: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100002aaf: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002ab9: 48 89 85 30 02 00 00        	movq	%rax, 0x230(%rbp)
100002ac0: 48 8b 85 28 02 00 00        	movq	0x228(%rbp), %rax
100002ac7: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
100002ace: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
100002ad5: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
100002adc: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002ae3: 48 8b 85 38 02 00 00        	movq	0x238(%rbp), %rax
100002aea: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002af1: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
100002af8: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002aff: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002b09: 31 d2                       	xorl	%edx, %edx
100002b0b: e9 a2 02 00 00              	jmp	0x100002db2 <__text+0x1db2>
100002b10: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002b17: 48 89 c1                    	movq	%rax, %rcx
100002b1a: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100002b1f: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100002b23: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100002b2d: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002b32: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002b36: 0f 82 39 00 00 00           	jb	0x100002b75 <__text+0x1b75>
100002b3c: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100002b46: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002b4b: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002b4f: 0f 83 20 00 00 00           	jae	0x100002b75 <__text+0x1b75>
100002b55: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100002b5a: 48 39 c8                    	cmpq	%rcx, %rax
100002b5d: 0f 85 12 00 00 00           	jne	0x100002b75 <__text+0x1b75>
100002b63: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100002b67: 66 0f 7e d8                 	movd	%xmm3, %eax
100002b6b: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002b70: e9 3d 00 00 00              	jmp	0x100002bb2 <__text+0x1bb2>
100002b75: 48 8d 35 ac 19 00 00        	leaq	0x19ac(%rip), %rsi      ## 0x100004528
100002b7c: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100002b83: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100002b8a: 4c 89 c2                    	movq	%r8, %rdx
100002b8d: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100002b97: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100002ba1: 0f 05                       	syscall
100002ba3: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002bad: e9 00 02 00 00              	jmp	0x100002db2 <__text+0x1db2>
100002bb2: 48 8b 85 c0 03 00 00        	movq	0x3c0(%rbp), %rax
100002bb9: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002bbe: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002bc1: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002bc4: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002bc8: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002bcb: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002bce: 41 0f 28 cb                 	movaps	%xmm11, %xmm1
100002bd2: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002bd6: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002bd9: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002be3: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002be8: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002beb: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002bef: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002bf3: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002bf6: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
100002bfd: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002c02: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002c06: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002c09: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002c0d: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002c11: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002c15: 41 0f 28 cd                 	movaps	%xmm13, %xmm1
100002c19: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002c1d: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002c21: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002c2b: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002c30: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002c34: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002c38: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002c3c: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002c40: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002c43: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002c47: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002c4b: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002c4e: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002c55: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002c5a: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002c64: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002c69: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002c6d: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002c71: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002c75: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002c79: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002c7c: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002c80: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002c84: f3 0f 11 85 c0 02 00 00     	movss	%xmm0, 0x2c0(%rbp)
100002c8c: 48 8b 85 c8 03 00 00        	movq	0x3c8(%rbp), %rax
100002c93: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002c98: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002c9b: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002c9e: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002ca2: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002ca5: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002ca8: 41 0f 28 cc                 	movaps	%xmm12, %xmm1
100002cac: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002cb0: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002cb3: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002cbd: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002cc2: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002cc5: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002cc9: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002ccd: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002cd0: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
100002cd7: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002cdc: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002ce0: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002ce3: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002ce7: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002ceb: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002cef: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
100002cf3: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002cf7: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002cfb: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002d05: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002d0a: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002d0e: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002d11: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002d15: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002d19: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002d1c: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002d20: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002d24: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002d27: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
100002d2e: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002d33: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002d3d: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002d42: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002d45: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002d49: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002d4d: 0f 28 f0                    	movaps	%xmm0, %xmm6
100002d50: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002d53: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002d56: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002d5a: f3 0f 11 85 38 03 00 00     	movss	%xmm0, 0x338(%rbp)
100002d62: 48 8b 85 c0 02 00 00        	movq	0x2c0(%rbp), %rax
100002d69: 48 89 85 40 03 00 00        	movq	%rax, 0x340(%rbp)
100002d70: 48 8b 85 38 03 00 00        	movq	0x338(%rbp), %rax
100002d77: 48 89 85 48 03 00 00        	movq	%rax, 0x348(%rbp)
100002d7e: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002d85: 48 8b 85 40 03 00 00        	movq	0x340(%rbp), %rax
100002d8c: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002d93: 48 8b 85 48 03 00 00        	movq	0x348(%rbp), %rax
100002d9a: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002da1: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002dab: 31 d2                       	xorl	%edx, %edx
100002dad: e9 00 00 00 00              	jmp	0x100002db2 <__text+0x1db2>
100002db2: 48 89 ec                    	movq	%rbp, %rsp
100002db5: 48 81 c4 00 04 00 00        	addq	$0x400, %rsp            ## imm = 0x400
100002dbc: 5d                          	popq	%rbp
100002dbd: c3                          	retq
100002dbe: 55                          	pushq	%rbp
100002dbf: 48 89 e5                    	movq	%rsp, %rbp
100002dc2: 48 81 ec b0 01 00 00        	subq	$0x1b0, %rsp            ## imm = 0x1B0
100002dc9: 48 89 e5                    	movq	%rsp, %rbp
100002dcc: 48 89 95 18 00 00 00        	movq	%rdx, 0x18(%rbp)
100002dd3: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
100002dda: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100002de1: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
100002de8: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
100002def: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
100002df6: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002e00: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002e05: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002e0f: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100002e16: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002e1d: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002e24: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100002e2b: 48 8b 8d 30 00 00 00        	movq	0x30(%rbp), %rcx
100002e32: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002e39: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100002e40: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
100002e4a: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100002e51: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002e58: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100002e5f: 48 39 c8                    	cmpq	%rcx, %rax
100002e62: 0f 9c c0                    	setl	%al
100002e65: 48 0f b6 c0                 	movzbq	%al, %rax
100002e69: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100002e70: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002e77: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100002e7e: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100002e85: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002e8c: 66 48 0f 7e f0              	movq	%xmm6, %rax
100002e91: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002e98: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100002e9f: 48 85 c0                    	testq	%rax, %rax
100002ea2: 0f 84 39 00 00 00           	je	0x100002ee1 <__text+0x1ee1>
100002ea8: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002eb2: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100002eb9: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002ec0: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100002ec7: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
100002ece: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002ed5: 66 48 0f 7e f0              	movq	%xmm6, %rax
100002eda: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002ee1: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002ee8: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100002eef: 48 39 c8                    	cmpq	%rcx, %rax
100002ef2: 0f 84 ad 05 00 00           	je	0x1000034a5 <__text+0x24a5>
100002ef8: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002eff: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002f06: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100002f0d: 48 8b 9d 60 00 00 00        	movq	0x60(%rbp), %rbx
100002f14: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100002f1b: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100002f22: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002f29: 48 85 c0                    	testq	%rax, %rax
100002f2c: 0f 89 03 00 00 00           	jns	0x100002f35 <__text+0x1f35>
100002f32: 48 01 c8                    	addq	%rcx, %rax
100002f35: 48 39 c8                    	cmpq	%rcx, %rax
100002f38: 0f 82 0f 00 00 00           	jb	0x100002f4d <__text+0x1f4d>
100002f3e: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002f48: e9 74 05 00 00              	jmp	0x1000034c1 <__text+0x24c1>
100002f4d: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002f54: 48 01 c3                    	addq	%rax, %rbx
100002f57: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002f5e: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100002f65: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002f6c: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100002f73: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002f7a: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100002f81: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100002f88: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100002f8f: 4c 8d bd 88 00 00 00        	leaq	0x88(%rbp), %r15
100002f96: 48 8d bd 68 00 00 00        	leaq	0x68(%rbp), %rdi
100002f9d: 48 8d b5 08 00 00 00        	leaq	0x8(%rbp), %rsi
100002fa4: e8 99 f4 ff ff              	callq	0x100002442 <__text+0x1442>
100002fa9: 48 85 d2                    	testq	%rdx, %rdx
100002fac: 0f 85 0f 05 00 00           	jne	0x1000034c1 <__text+0x24c1>
100002fb2: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
100002fb9: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002fbe: 48 8b 85 88 00 00 00        	movq	0x88(%rbp), %rax
100002fc5: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002fca: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002fcd: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002fd5: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002fd9: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002fdc: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002fdf: 0f 28 cf                    	movaps	%xmm7, %xmm1
100002fe2: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002fe6: f3 0f 11 85 b0 00 00 00     	movss	%xmm0, 0xb0(%rbp)
100002fee: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100002ff5: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002ffa: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100003001: 66 48 0f 6e f8              	movq	%rax, %xmm7
100003006: 0f 28 c7                    	movaps	%xmm7, %xmm0
100003009: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100003011: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100003015: 0f 28 f8                    	movaps	%xmm0, %xmm7
100003018: 0f 28 c6                    	movaps	%xmm6, %xmm0
10000301b: 0f 28 cf                    	movaps	%xmm7, %xmm1
10000301e: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003022: f3 0f 11 85 d0 00 00 00     	movss	%xmm0, 0xd0(%rbp)
10000302a: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100003031: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003036: f3 0f 10 85 b0 00 00 00     	movss	0xb0(%rbp), %xmm0
10000303e: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100003046: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000304a: 0f 28 f8                    	movaps	%xmm0, %xmm7
10000304d: 0f 28 c6                    	movaps	%xmm6, %xmm0
100003050: 0f 28 cf                    	movaps	%xmm7, %xmm1
100003053: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003057: f3 0f 11 85 e8 00 00 00     	movss	%xmm0, 0xe8(%rbp)
10000305f: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100003066: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000306b: f3 0f 10 85 d0 00 00 00     	movss	0xd0(%rbp), %xmm0
100003073: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
10000307b: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000307f: 0f 28 f8                    	movaps	%xmm0, %xmm7
100003082: 0f 28 c6                    	movaps	%xmm6, %xmm0
100003085: 0f 28 cf                    	movaps	%xmm7, %xmm1
100003088: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000308c: f3 0f 11 85 00 01 00 00     	movss	%xmm0, 0x100(%rbp)
100003094: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
10000309b: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
1000030a2: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
1000030a9: 48 8b 9d 08 01 00 00        	movq	0x108(%rbp), %rbx
1000030b0: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
1000030b7: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000030be: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000030c5: 48 85 c0                    	testq	%rax, %rax
1000030c8: 0f 89 03 00 00 00           	jns	0x1000030d1 <__text+0x20d1>
1000030ce: 48 01 c8                    	addq	%rcx, %rax
1000030d1: 48 39 c8                    	cmpq	%rcx, %rax
1000030d4: 0f 82 0f 00 00 00           	jb	0x1000030e9 <__text+0x20e9>
1000030da: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000030e4: e9 d8 03 00 00              	jmp	0x1000034c1 <__text+0x24c1>
1000030e9: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000030f0: 48 01 c3                    	addq	%rax, %rbx
1000030f3: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000030fa: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003101: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003108: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
10000310f: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003116: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
10000311d: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003124: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
10000312b: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100003132: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
100003139: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100003140: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100003147: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
10000314e: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100003155: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
10000315c: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100003163: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
10000316a: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100003171: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100003178: 48 8b 9d 50 01 00 00        	movq	0x150(%rbp), %rbx
10000317f: 4c 8b a3 00 00 00 00        	movq	(%rbx), %r12
100003186: 4c 8b ad 88 01 00 00        	movq	0x188(%rbp), %r13
10000318d: 4d 85 ed                    	testq	%r13, %r13
100003190: 0f 89 03 00 00 00           	jns	0x100003199 <__text+0x2199>
100003196: 4d 01 e5                    	addq	%r12, %r13
100003199: 4d 39 e5                    	cmpq	%r12, %r13
10000319c: 0f 82 0f 00 00 00           	jb	0x1000031b1 <__text+0x21b1>
1000031a2: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000031ac: e9 10 03 00 00              	jmp	0x1000034c1 <__text+0x24c1>
1000031b1: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
1000031b8: 4c 8b 9b 10 00 00 00        	movq	0x10(%rbx), %r11
1000031bf: 4c 01 d8                    	addq	%r11, %rax
1000031c2: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000031cc: 48 39 c8                    	cmpq	%rcx, %rax
1000031cf: 0f 85 5b 00 00 00           	jne	0x100003230 <__text+0x2230>
1000031d5: 49 89 de                    	movq	%rbx, %r14
1000031d8: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000031df: 4c 89 e8                    	movq	%r13, %rax
1000031e2: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000031e9: 49 01 c6                    	addq	%rax, %r14
1000031ec: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
1000031f3: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
1000031fa: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
100003201: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100003208: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
10000320f: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100003216: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
10000321d: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
100003224: 48 89 9d 58 01 00 00        	movq	%rbx, 0x158(%rbp)
10000322b: e9 ed 01 00 00              	jmp	0x10000341d <__text+0x241d>
100003230: 4c 89 e6                    	movq	%r12, %rsi
100003233: 48 b9 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rcx
10000323d: 48 0f af f1                 	imulq	%rcx, %rsi
100003241: 48 81 c6 28 00 00 00        	addq	$0x28, %rsi
100003248: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
100003252: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000325c: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
100003266: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
100003270: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
10000327a: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
100003284: 0f 05                       	syscall
100003286: 0f 83 0f 00 00 00           	jae	0x10000329b <__text+0x229b>
10000328c: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003296: e9 26 02 00 00              	jmp	0x1000034c1 <__text+0x24c1>
10000329b: 49 89 c7                    	movq	%rax, %r15
10000329e: 4d 89 a7 00 00 00 00        	movq	%r12, (%r15)
1000032a5: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000032af: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
1000032b6: 49 89 87 10 00 00 00        	movq	%rax, 0x10(%r15)
1000032bd: 49 89 87 20 00 00 00        	movq	%rax, 0x20(%r15)
1000032c4: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000032ce: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
1000032d5: 49 89 b7 18 00 00 00        	movq	%rsi, 0x18(%r15)
1000032dc: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000032e3: 4d 89 fe                    	movq	%r15, %r14
1000032e6: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000032ed: 4c 89 e6                    	movq	%r12, %rsi
1000032f0: 48 b9 04 00 00 00 00 00 00 00       	movabsq	$0x4, %rcx
1000032fa: 48 0f af f1                 	imulq	%rcx, %rsi
1000032fe: 48 85 f6                    	testq	%rsi, %rsi
100003301: 0f 84 20 00 00 00           	je	0x100003327 <__text+0x2327>
100003307: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000330e: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100003315: 48 83 c3 08                 	addq	$0x8, %rbx
100003319: 49 83 c6 08                 	addq	$0x8, %r14
10000331d: 48 83 ee 01                 	subq	$0x1, %rsi
100003321: 0f 85 e0 ff ff ff           	jne	0x100003307 <__text+0x2307>
100003327: 4d 89 fe                    	movq	%r15, %r14
10000332a: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100003331: 4c 89 e8                    	movq	%r13, %rax
100003334: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
10000333b: 49 01 c6                    	addq	%rax, %r14
10000333e: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100003345: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
10000334c: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
100003353: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
10000335a: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100003361: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100003368: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
10000336f: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
100003376: 4c 89 bd 58 01 00 00        	movq	%r15, 0x158(%rbp)
10000337d: 4c 8b 95 50 01 00 00        	movq	0x150(%rbp), %r10
100003384: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
10000338b: 48 85 c0                    	testq	%rax, %rax
10000338e: 0f 84 89 00 00 00           	je	0x10000341d <__text+0x241d>
100003394: 49 89 c3                    	movq	%rax, %r11
100003397: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
10000339e: f0                          	lock
10000339f: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
1000033a4: 0f 85 da ff ff ff           	jne	0x100003384 <__text+0x2384>
1000033aa: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
1000033b1: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
1000033b8: 4c 01 d8                    	addq	%r11, %rax
1000033bb: 48 85 c0                    	testq	%rax, %rax
1000033be: 0f 85 59 00 00 00           	jne	0x10000341d <__text+0x241d>
1000033c4: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
1000033cb: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
1000033d5: 48 39 c8                    	cmpq	%rcx, %rax
1000033d8: 0f 84 e6 ff ff ff           	je	0x1000033c4 <__text+0x23c4>
1000033de: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000033e8: 48 39 c8                    	cmpq	%rcx, %rax
1000033eb: 0f 84 2c 00 00 00           	je	0x10000341d <__text+0x241d>
1000033f1: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000033fb: f0                          	lock
1000033fc: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003401: 0f 85 bd ff ff ff           	jne	0x1000033c4 <__text+0x23c4>
100003407: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
10000340e: 4c 89 d7                    	movq	%r10, %rdi
100003411: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
10000341b: 0f 05                       	syscall
10000341d: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100003424: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
10000342b: 48 89 81 00 00 00 00        	movq	%rax, (%rcx)
100003432: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100003439: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000343e: f3 0f 10 85 e8 00 00 00     	movss	0xe8(%rbp), %xmm0
100003446: f3 0f 10 8d 00 01 00 00     	movss	0x100(%rbp), %xmm1
10000344e: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003452: 0f 28 f8                    	movaps	%xmm0, %xmm7
100003455: 0f 28 c6                    	movaps	%xmm6, %xmm0
100003458: 0f 28 cf                    	movaps	%xmm7, %xmm1
10000345b: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000345f: 0f 28 f0                    	movaps	%xmm0, %xmm6
100003462: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100003469: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
100003470: 48 01 c8                    	addq	%rcx, %rax
100003473: 71 0a                       	jno	0x10000347f <__text+0x247f>
100003475: ba 01 00 00 00              	movl	$0x1, %edx
10000347a: e9 42 00 00 00              	jmp	0x1000034c1 <__text+0x24c1>
10000347f: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
100003486: 48 8b 85 78 01 00 00        	movq	0x178(%rbp), %rax
10000348d: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100003494: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003499: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
1000034a0: e9 3c fa ff ff              	jmp	0x100002ee1 <__text+0x1ee1>
1000034a5: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
1000034ac: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
1000034b3: 48 8b 85 80 01 00 00        	movq	0x180(%rbp), %rax
1000034ba: 31 d2                       	xorl	%edx, %edx
1000034bc: e9 00 00 00 00              	jmp	0x1000034c1 <__text+0x24c1>
1000034c1: 48 89 ec                    	movq	%rbp, %rsp
1000034c4: 48 81 c4 b0 01 00 00        	addq	$0x1b0, %rsp            ## imm = 0x1B0
1000034cb: 5d                          	popq	%rbp
1000034cc: c3                          	retq
1000034cd: 55                          	pushq	%rbp
1000034ce: 48 89 e5                    	movq	%rsp, %rbp
1000034d1: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
1000034d8: 48 89 e5                    	movq	%rsp, %rbp
1000034db: 48 89 b5 10 00 00 00        	movq	%rsi, 0x10(%rbp)
1000034e2: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
1000034e9: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
1000034f0: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
1000034f7: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
1000034fe: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003508: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000350d: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003517: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
10000351e: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
100003528: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
10000352f: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100003536: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
10000353d: 48 39 c8                    	cmpq	%rcx, %rax
100003540: 0f 9c c0                    	setl	%al
100003543: 48 0f b6 c0                 	movzbq	%al, %rax
100003547: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
10000354e: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100003555: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
10000355c: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
100003563: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
10000356a: 66 48 0f 7e f0              	movq	%xmm6, %rax
10000356f: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003576: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
10000357d: 48 85 c0                    	testq	%rax, %rax
100003580: 0f 84 39 00 00 00           	je	0x1000035bf <__text+0x25bf>
100003586: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100003590: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003597: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
10000359e: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
1000035a5: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
1000035ac: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
1000035b3: 66 48 0f 7e f0              	movq	%xmm6, %rax
1000035b8: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
1000035bf: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
1000035c6: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
1000035cd: 48 39 c8                    	cmpq	%rcx, %rax
1000035d0: 0f 84 93 00 00 00           	je	0x100003669 <__text+0x2669>
1000035d6: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
1000035dd: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
1000035e4: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
1000035eb: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
1000035f2: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000035fc: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
100003603: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
10000360a: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003611: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100003618: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
10000361f: e9 61 00 00 00              	jmp	0x100003685 <__text+0x2685>
100003624: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
10000362b: 48 8b 8d 10 01 00 00        	movq	0x110(%rbp), %rcx
100003632: 48 01 c8                    	addq	%rcx, %rax
100003635: 71 0a                       	jno	0x100003641 <__text+0x2641>
100003637: ba 01 00 00 00              	movl	$0x1, %edx
10000363c: e9 ae 01 00 00              	jmp	0x1000037ef <__text+0x27ef>
100003641: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100003648: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
10000364f: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100003656: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
10000365d: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003664: e9 56 ff ff ff              	jmp	0x1000035bf <__text+0x25bf>
100003669: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100003670: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100003677: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
10000367e: 31 d2                       	xorl	%edx, %edx
100003680: e9 6a 01 00 00              	jmp	0x1000037ef <__text+0x27ef>
100003685: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
10000368c: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100003693: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
10000369a: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
1000036a1: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
1000036a8: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
1000036af: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
1000036b6: 48 8b 8d 70 00 00 00        	movq	0x70(%rbp), %rcx
1000036bd: 48 39 c8                    	cmpq	%rcx, %rax
1000036c0: 0f 8d 5e ff ff ff           	jge	0x100003624 <__text+0x2624>
1000036c6: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
1000036cd: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
1000036d4: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
1000036db: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000036e2: 48 8b 9d 80 00 00 00        	movq	0x80(%rbp), %rbx
1000036e9: 48 8b 8d 88 00 00 00        	movq	0x88(%rbp), %rcx
1000036f0: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
1000036f7: 48 85 c0                    	testq	%rax, %rax
1000036fa: 0f 89 03 00 00 00           	jns	0x100003703 <__text+0x2703>
100003700: 48 01 c8                    	addq	%rcx, %rax
100003703: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
10000370a: 48 01 c3                    	addq	%rax, %rbx
10000370d: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003714: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
10000371b: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003722: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
100003729: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003730: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003737: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
10000373e: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100003745: 4c 8d bd b0 00 00 00        	leaq	0xb0(%rbp), %r15
10000374c: 48 8d bd 90 00 00 00        	leaq	0x90(%rbp), %rdi
100003753: 48 8d b5 00 00 00 00        	leaq	(%rbp), %rsi
10000375a: e8 e3 ec ff ff              	callq	0x100002442 <__text+0x1442>
10000375f: 48 85 d2                    	testq	%rdx, %rdx
100003762: 0f 85 87 00 00 00           	jne	0x1000037ef <__text+0x27ef>
100003768: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
10000376f: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003774: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
10000377b: 66 48 0f 6e f8              	movq	%rax, %xmm7
100003780: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100003787: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000378c: 0f 28 c7                    	movaps	%xmm7, %xmm0
10000378f: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100003793: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003797: 0f 28 f8                    	movaps	%xmm0, %xmm7
10000379a: 0f 28 c6                    	movaps	%xmm6, %xmm0
10000379d: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000037a0: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000037a4: 0f 28 f0                    	movaps	%xmm0, %xmm6
1000037a7: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000037b1: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
1000037b8: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
1000037bf: 48 8b 8d f0 00 00 00        	movq	0xf0(%rbp), %rcx
1000037c6: 48 01 c8                    	addq	%rcx, %rax
1000037c9: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
1000037d0: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
1000037d7: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
1000037de: 66 48 0f 7e f0              	movq	%xmm6, %rax
1000037e3: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000037ea: e9 96 fe ff ff              	jmp	0x100003685 <__text+0x2685>
1000037ef: 48 89 ec                    	movq	%rbp, %rsp
1000037f2: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
1000037f9: 5d                          	popq	%rbp
1000037fa: c3                          	retq
1000037fb: 55                          	pushq	%rbp
1000037fc: 48 89 e5                    	movq	%rsp, %rbp
1000037ff: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
100003806: 48 89 e5                    	movq	%rsp, %rbp
100003809: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
100003813: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
10000381a: 48 8b bd 00 00 00 00        	movq	(%rbp), %rdi
100003821: e8 da d7 ff ff              	callq	0x100001000 <__text>
100003826: 48 85 d2                    	testq	%rdx, %rdx
100003829: 0f 85 fd 05 00 00           	jne	0x100003e2c <__text+0x2e2c>
10000382f: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100003836: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003840: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
100003847: 48 8b 8d 08 00 00 00        	movq	0x8(%rbp), %rcx
10000384e: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100003855: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
10000385c: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
100003863: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
10000386a: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003871: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
100003878: 48 85 c0                    	testq	%rax, %rax
10000387b: 0f 89 03 00 00 00           	jns	0x100003884 <__text+0x2884>
100003881: 48 01 c8                    	addq	%rcx, %rax
100003884: 48 85 c0                    	testq	%rax, %rax
100003887: 0f 89 0a 00 00 00           	jns	0x100003897 <__text+0x2897>
10000388d: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003897: 48 39 c8                    	cmpq	%rcx, %rax
10000389a: 0f 8e 03 00 00 00           	jle	0x1000038a3 <__text+0x28a3>
1000038a0: 48 89 c8                    	movq	%rcx, %rax
1000038a3: 48 8b 95 18 00 00 00        	movq	0x18(%rbp), %rdx
1000038aa: 48 85 d2                    	testq	%rdx, %rdx
1000038ad: 0f 89 03 00 00 00           	jns	0x1000038b6 <__text+0x28b6>
1000038b3: 48 01 ca                    	addq	%rcx, %rdx
1000038b6: 48 85 d2                    	testq	%rdx, %rdx
1000038b9: 0f 89 0a 00 00 00           	jns	0x1000038c9 <__text+0x28c9>
1000038bf: 48 ba 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdx
1000038c9: 48 39 ca                    	cmpq	%rcx, %rdx
1000038cc: 0f 8e 03 00 00 00           	jle	0x1000038d5 <__text+0x28d5>
1000038d2: 48 89 ca                    	movq	%rcx, %rdx
1000038d5: 49 bb 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r11
1000038df: 48 39 d0                    	cmpq	%rdx, %rax
1000038e2: 0f 8d 06 00 00 00           	jge	0x1000038ee <__text+0x28ee>
1000038e8: 49 89 d3                    	movq	%rdx, %r11
1000038eb: 49 29 c3                    	subq	%rax, %r11
1000038ee: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000038f5: 48 01 c3                    	addq	%rax, %rbx
1000038f8: 48 89 9d 20 00 00 00        	movq	%rbx, 0x20(%rbp)
1000038ff: 4c 89 9d 28 00 00 00        	movq	%r11, 0x28(%rbp)
100003906: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
100003910: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100003917: 48 8b bd 30 00 00 00        	movq	0x30(%rbp), %rdi
10000391e: e8 dd d6 ff ff              	callq	0x100001000 <__text>
100003923: 48 85 d2                    	testq	%rdx, %rdx
100003926: 0f 85 00 05 00 00           	jne	0x100003e2c <__text+0x2e2c>
10000392c: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100003933: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
10000393a: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100003941: 48 b8 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rax
10000394b: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100003952: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
100003959: 48 8b b5 40 00 00 00        	movq	0x40(%rbp), %rsi
100003960: e8 9a df ff ff              	callq	0x1000018ff <__text+0x8ff>
100003965: 48 85 d2                    	testq	%rdx, %rdx
100003968: 0f 85 be 04 00 00           	jne	0x100003e2c <__text+0x2e2c>
10000396e: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003975: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000397f: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003984: f3 0f 10 85 48 00 00 00     	movss	0x48(%rbp), %xmm0
10000398c: 0f 28 ce                    	movaps	%xmm6, %xmm1
10000398f: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003992: 0f 97 c0                    	seta	%al
100003995: 48 0f b6 c0                 	movzbq	%al, %rax
100003999: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000039a0: 48 b8 00 01 00 00 00 00 00 00       	movabsq	$0x100, %rax    ## imm = 0x100
1000039aa: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
1000039b1: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
1000039b8: 48 8b b5 60 00 00 00        	movq	0x60(%rbp), %rsi
1000039bf: e8 09 fb ff ff              	callq	0x1000034cd <__text+0x24cd>
1000039c4: 48 85 d2                    	testq	%rdx, %rdx
1000039c7: 0f 85 5f 04 00 00           	jne	0x100003e2c <__text+0x2e2c>
1000039cd: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
1000039d4: f3 0f 10 85 68 00 00 00     	movss	0x68(%rbp), %xmm0
1000039dc: f3 0f 10 8d 68 00 00 00     	movss	0x68(%rbp), %xmm1
1000039e4: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
1000039e7: 0f 94 c0                    	sete	%al
1000039ea: 0f 9b c1                    	setnp	%cl
1000039ed: 20 c8                       	andb	%cl, %al
1000039ef: 48 0f b6 c0                 	movzbq	%al, %rax
1000039f3: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
1000039fa: 48 b8 89 88 08 3c 00 00 00 00       	movabsq	$0x3c088889, %rax ## imm = 0x3C088889
100003a04: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100003a0b: 48 8d 85 28 01 00 00        	leaq	0x128(%rbp), %rax
100003a12: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100003a19: 48 8b bd 80 00 00 00        	movq	0x80(%rbp), %rdi
100003a20: 48 8d b5 20 00 00 00        	leaq	0x20(%rbp), %rsi
100003a27: 48 8b 95 78 00 00 00        	movq	0x78(%rbp), %rdx
100003a2e: e8 8b f3 ff ff              	callq	0x100002dbe <__text+0x1dbe>
100003a33: 48 85 d2                    	testq	%rdx, %rdx
100003a36: 0f 85 f0 03 00 00           	jne	0x100003e2c <__text+0x2e2c>
100003a3c: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100003a43: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003a4d: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003a52: f3 0f 10 85 88 00 00 00     	movss	0x88(%rbp), %xmm0
100003a5a: 0f 28 ce                    	movaps	%xmm6, %xmm1
100003a5d: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003a60: 0f 86 7b 01 00 00           	jbe	0x100003be1 <__text+0x2be1>
100003a66: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003a6d: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100003a74: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003a7e: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100003a85: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100003a8c: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003a93: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003a9a: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100003aa1: 48 85 c0                    	testq	%rax, %rax
100003aa4: 0f 89 03 00 00 00           	jns	0x100003aad <__text+0x2aad>
100003aaa: 48 01 c8                    	addq	%rcx, %rax
100003aad: 48 39 c8                    	cmpq	%rcx, %rax
100003ab0: 0f 82 0f 00 00 00           	jb	0x100003ac5 <__text+0x2ac5>
100003ab6: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003ac0: e9 67 03 00 00              	jmp	0x100003e2c <__text+0x2e2c>
100003ac5: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003acc: 48 01 c3                    	addq	%rax, %rbx
100003acf: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003ad6: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100003add: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003ae4: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100003aeb: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003af2: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100003af9: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003b00: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100003b07: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100003b0e: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003b13: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003b1d: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
100003b24: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
100003b2b: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003b32: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003b39: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
100003b40: 48 85 c0                    	testq	%rax, %rax
100003b43: 0f 89 03 00 00 00           	jns	0x100003b4c <__text+0x2b4c>
100003b49: 48 01 c8                    	addq	%rcx, %rax
100003b4c: 48 39 c8                    	cmpq	%rcx, %rax
100003b4f: 0f 82 0f 00 00 00           	jb	0x100003b64 <__text+0x2b64>
100003b55: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003b5f: e9 c8 02 00 00              	jmp	0x100003e2c <__text+0x2e2c>
100003b64: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003b6b: 48 01 c3                    	addq	%rax, %rbx
100003b6e: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003b75: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100003b7c: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003b83: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003b8a: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003b91: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100003b98: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003b9f: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100003ba6: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100003bad: 66 48 0f 6e f8              	movq	%rax, %xmm7
100003bb2: 0f 28 c6                    	movaps	%xmm6, %xmm0
100003bb5: 0f 28 cf                    	movaps	%xmm7, %xmm1
100003bb8: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003bbb: 0f 95 c0                    	setne	%al
100003bbe: 0f 9a c1                    	setp	%cl
100003bc1: 08 c8                       	orb	%cl, %al
100003bc3: 48 0f b6 c0                 	movzbq	%al, %rax
100003bc7: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003bce: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
100003bd5: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003bdc: e9 11 00 00 00              	jmp	0x100003bf2 <__text+0x2bf2>
100003be1: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003beb: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003bf2: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
100003bf9: 48 85 c0                    	testq	%rax, %rax
100003bfc: 0f 84 23 00 00 00           	je	0x100003c25 <__text+0x2c25>
100003c02: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100003c09: 48 85 c0                    	testq	%rax, %rax
100003c0c: 0f 84 13 00 00 00           	je	0x100003c25 <__text+0x2c25>
100003c12: 48 8b 85 a0 00 00 00        	movq	0xa0(%rbp), %rax
100003c19: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003c20: e9 11 00 00 00              	jmp	0x100003c36 <__text+0x2c36>
100003c25: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003c2f: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003c36: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003c3d: 48 85 c0                    	testq	%rax, %rax
100003c40: 0f 84 33 00 00 00           	je	0x100003c79 <__text+0x2c79>
100003c46: 48 8d 35 c3 03 00 00        	leaq	0x3c3(%rip), %rsi       ## 0x100004010
100003c4d: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003c54: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003c5b: 4c 89 c2                    	movq	%r8, %rdx
100003c5e: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003c68: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003c72: 0f 05                       	syscall
100003c74: e9 2e 00 00 00              	jmp	0x100003ca7 <__text+0x2ca7>
100003c79: 48 8d 35 a0 03 00 00        	leaq	0x3a0(%rip), %rsi       ## 0x100004020
100003c80: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003c87: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003c8e: 4c 89 c2                    	movq	%r8, %rdx
100003c91: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003c9b: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003ca5: 0f 05                       	syscall
100003ca7: 48 8d 35 52 03 00 00        	leaq	0x352(%rip), %rsi       ## 0x100004000
100003cae: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003cb5: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003cbc: 4c 89 c2                    	movq	%r8, %rdx
100003cbf: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003cc9: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003cd3: 0f 05                       	syscall
100003cd5: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003cdc: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003ce3: 4c 8b 95 20 01 00 00        	movq	0x120(%rbp), %r10
100003cea: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003cf1: 48 85 c0                    	testq	%rax, %rax
100003cf4: 0f 84 89 00 00 00           	je	0x100003d83 <__text+0x2d83>
100003cfa: 49 89 c3                    	movq	%rax, %r11
100003cfd: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003d04: f0                          	lock
100003d05: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003d0a: 0f 85 da ff ff ff           	jne	0x100003cea <__text+0x2cea>
100003d10: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003d17: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003d1e: 4c 01 d8                    	addq	%r11, %rax
100003d21: 48 85 c0                    	testq	%rax, %rax
100003d24: 0f 85 59 00 00 00           	jne	0x100003d83 <__text+0x2d83>
100003d2a: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003d31: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003d3b: 48 39 c8                    	cmpq	%rcx, %rax
100003d3e: 0f 84 e6 ff ff ff           	je	0x100003d2a <__text+0x2d2a>
100003d44: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003d4e: 48 39 c8                    	cmpq	%rcx, %rax
100003d51: 0f 84 2c 00 00 00           	je	0x100003d83 <__text+0x2d83>
100003d57: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100003d61: f0                          	lock
100003d62: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003d67: 0f 85 bd ff ff ff           	jne	0x100003d2a <__text+0x2d2a>
100003d6d: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100003d74: 4c 89 d7                    	movq	%r10, %rdi
100003d77: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100003d81: 0f 05                       	syscall
100003d83: 4c 8b 95 08 00 00 00        	movq	0x8(%rbp), %r10
100003d8a: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003d91: 48 85 c0                    	testq	%rax, %rax
100003d94: 0f 84 89 00 00 00           	je	0x100003e23 <__text+0x2e23>
100003d9a: 49 89 c3                    	movq	%rax, %r11
100003d9d: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003da4: f0                          	lock
100003da5: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003daa: 0f 85 da ff ff ff           	jne	0x100003d8a <__text+0x2d8a>
100003db0: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003db7: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003dbe: 4c 01 d8                    	addq	%r11, %rax
100003dc1: 48 85 c0                    	testq	%rax, %rax
100003dc4: 0f 85 59 00 00 00           	jne	0x100003e23 <__text+0x2e23>
100003dca: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003dd1: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003ddb: 48 39 c8                    	cmpq	%rcx, %rax
100003dde: 0f 84 e6 ff ff ff           	je	0x100003dca <__text+0x2dca>
100003de4: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003dee: 48 39 c8                    	cmpq	%rcx, %rax
100003df1: 0f 84 2c 00 00 00           	je	0x100003e23 <__text+0x2e23>
100003df7: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100003e01: f0                          	lock
100003e02: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003e07: 0f 85 bd ff ff ff           	jne	0x100003dca <__text+0x2dca>
100003e0d: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100003e14: 4c 89 d7                    	movq	%r10, %rdi
100003e17: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100003e21: 0f 05                       	syscall
100003e23: 31 c0                       	xorl	%eax, %eax
100003e25: 31 d2                       	xorl	%edx, %edx
100003e27: e9 00 00 00 00              	jmp	0x100003e2c <__text+0x2e2c>
100003e2c: 48 89 ec                    	movq	%rbp, %rsp
100003e2f: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
100003e36: 5d                          	popq	%rbp
100003e37: c3                          	retq
100003e38: 53                          	pushq	%rbx
100003e39: 41 54                       	pushq	%r12
100003e3b: 41 55                       	pushq	%r13
100003e3d: 41 56                       	pushq	%r14
100003e3f: 41 57                       	pushq	%r15
100003e41: e8 b5 f9 ff ff              	callq	0x1000037fb <__text+0x27fb>
100003e46: 48 85 d2                    	testq	%rdx, %rdx
100003e49: 0f 95 c2                    	setne	%dl
100003e4c: 0f b6 d2                    	movzbl	%dl, %edx
100003e4f: 48 89 d0                    	movq	%rdx, %rax
100003e52: 41 5f                       	popq	%r15
100003e54: 41 5e                       	popq	%r14
100003e56: 41 5d                       	popq	%r13
100003e58: 41 5c                       	popq	%r12
100003e5a: 5b                          	popq	%rbx
100003e5b: c3                          	retq
		...
