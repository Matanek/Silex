
/private/tmp/silex-part03-evidence/cfg-native-flocking-x64:	file format mach-o 64-bit x86-64

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
100001aa5: e9 4a 0a 00 00              	jmp	0x1000024f4 <__text+0x14f4>
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
100001b31: e9 be 09 00 00              	jmp	0x1000024f4 <__text+0x14f4>
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
100001b75: e9 7a 09 00 00              	jmp	0x1000024f4 <__text+0x14f4>
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
100001c44: 48 89 85 d8 00 00 00        	movq	%rax, 0xd8(%rbp)
100001c4b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c55: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
100001c5c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c66: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100001c6d: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c77: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100001c7e: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c88: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100001c8f: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c99: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100001ca0: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001caa: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100001cb1: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001cb8: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100001cbf: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100001cc6: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100001ccd: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001cd7: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100001cde: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100001ce5: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100001cec: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
100001cf3: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001cfa: 48 8b 85 d8 00 00 00        	movq	0xd8(%rbp), %rax
100001d01: 48 89 85 58 04 00 00        	movq	%rax, 0x458(%rbp)
100001d08: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100001d0f: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100001d16: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
100001d1d: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
100001d24: 48 8b 85 f0 00 00 00        	movq	0xf0(%rbp), %rax
100001d2b: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
100001d32: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100001d39: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
100001d40: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
100001d47: 48 89 85 60 04 00 00        	movq	%rax, 0x460(%rbp)
100001d4e: e9 3c 00 00 00              	jmp	0x100001d8f <__text+0xd8f>
100001d53: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001d5d: 48 89 85 08 04 00 00        	movq	%rax, 0x408(%rbp)
100001d64: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001d6b: 48 8b 8d 08 04 00 00        	movq	0x408(%rbp), %rcx
100001d72: 48 01 c8                    	addq	%rcx, %rax
100001d75: 48 89 85 00 04 00 00        	movq	%rax, 0x400(%rbp)
100001d7c: 48 8b 85 00 04 00 00        	movq	0x400(%rbp), %rax
100001d83: 48 89 85 30 04 00 00        	movq	%rax, 0x430(%rbp)
100001d8a: e9 eb fd ff ff              	jmp	0x100001b7a <__text+0xb7a>
100001d8f: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001d96: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100001d9d: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001da4: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100001dab: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100001db2: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100001db9: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001dc0: 48 8b 8d 28 01 00 00        	movq	0x128(%rbp), %rcx
100001dc7: 48 39 c8                    	cmpq	%rcx, %rax
100001dca: 0f 8d 64 01 00 00           	jge	0x100001f34 <__text+0xf34>
100001dd0: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001dd7: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100001dde: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001de5: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100001dec: 48 8b 9d 38 01 00 00        	movq	0x138(%rbp), %rbx
100001df3: 48 8b 8d 40 01 00 00        	movq	0x140(%rbp), %rcx
100001dfa: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001e01: 48 85 c0                    	testq	%rax, %rax
100001e04: 0f 89 03 00 00 00           	jns	0x100001e0d <__text+0xe0d>
100001e0a: 48 01 c8                    	addq	%rcx, %rax
100001e0d: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100001e14: 48 01 c3                    	addq	%rax, %rbx
100001e17: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001e1e: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100001e25: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100001e2c: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100001e33: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100001e3a: 48 89 85 58 01 00 00        	movq	%rax, 0x158(%rbp)
100001e41: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001e48: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100001e4f: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100001e56: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001e5b: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001e5e: f3 0f 10 8d 78 00 00 00     	movss	0x78(%rbp), %xmm1
100001e66: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001e6a: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001e6d: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001e74: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001e79: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001e7c: 0f 28 cf                    	movaps	%xmm7, %xmm1
100001e7f: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100001e83: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100001e87: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100001e8e: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001e93: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001e9a: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001e9f: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001ea2: 0f 28 cf                    	movaps	%xmm7, %xmm1
100001ea5: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100001ea9: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100001ead: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100001eb1: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100001eb5: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001eb9: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001ebc: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100001ec0: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100001ec4: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001ec8: 44 0f 28 d0                 	movaps	%xmm0, %xmm10
100001ecc: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001ecf: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100001ed3: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001ed7: 0f 28 f8                    	movaps	%xmm0, %xmm7
100001eda: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001ee4: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001ee9: 0f 28 c7                    	movaps	%xmm7, %xmm0
100001eec: 0f 28 ce                    	movaps	%xmm6, %xmm1
100001eef: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100001ef2: 0f 87 69 00 00 00           	ja	0x100001f61 <__text+0xf61>
100001ef8: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001f02: 48 89 85 b8 02 00 00        	movq	%rax, 0x2b8(%rbp)
100001f09: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001f10: 48 8b 8d b8 02 00 00        	movq	0x2b8(%rbp), %rcx
100001f17: 48 01 c8                    	addq	%rcx, %rax
100001f1a: 48 89 85 b0 02 00 00        	movq	%rax, 0x2b0(%rbp)
100001f21: 48 8b 85 b0 02 00 00        	movq	0x2b0(%rbp), %rax
100001f28: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001f2f: e9 5b fe ff ff              	jmp	0x100001d8f <__text+0xd8f>
100001f34: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001f3e: 48 89 85 c0 02 00 00        	movq	%rax, 0x2c0(%rbp)
100001f45: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100001f4c: 48 8b 8d c0 02 00 00        	movq	0x2c0(%rbp), %rcx
100001f53: 48 39 c8                    	cmpq	%rcx, %rax
100001f56: 0f 8f d5 02 00 00           	jg	0x100002231 <__text+0x1231>
100001f5c: e9 f2 fd ff ff              	jmp	0x100001d53 <__text+0xd53>
100001f61: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
100001f6b: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001f70: 0f 28 c7                    	movaps	%xmm7, %xmm0
100001f73: 0f 28 ce                    	movaps	%xmm6, %xmm1
100001f76: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100001f79: 0f 8a 79 ff ff ff           	jp	0x100001ef8 <__text+0xef8>
100001f7f: 0f 83 73 ff ff ff           	jae	0x100001ef8 <__text+0xef8>
100001f85: 48 8b 85 68 04 00 00        	movq	0x468(%rbp), %rax
100001f8c: 48 89 85 d8 01 00 00        	movq	%rax, 0x1d8(%rbp)
100001f93: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001f9a: 48 89 85 e0 01 00 00        	movq	%rax, 0x1e0(%rbp)
100001fa1: 48 8b 85 70 04 00 00        	movq	0x470(%rbp), %rax
100001fa8: 48 89 85 f0 01 00 00        	movq	%rax, 0x1f0(%rbp)
100001faf: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001fb6: 48 89 85 f8 01 00 00        	movq	%rax, 0x1f8(%rbp)
100001fbd: f3 0f 10 9d d8 01 00 00     	movss	0x1d8(%rbp), %xmm3
100001fc5: f3 0f 10 ad f0 01 00 00     	movss	0x1f0(%rbp), %xmm5
100001fcd: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100001fd0: f3 0f 10 a5 e0 01 00 00     	movss	0x1e0(%rbp), %xmm4
100001fd8: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100001fe0: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100001fe3: 0f 28 c3                    	movaps	%xmm3, %xmm0
100001fe6: 0f 58 c4                    	addps	%xmm4, %xmm0
100001fe9: f3 0f 11 85 e8 01 00 00     	movss	%xmm0, 0x1e8(%rbp)
100001ff1: 0f 28 e8                    	movaps	%xmm0, %xmm5
100001ff4: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100001ff8: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
100002000: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
100002007: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
10000200e: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
100002015: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
10000201c: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
100002023: 48 89 85 20 02 00 00        	movq	%rax, 0x220(%rbp)
10000202a: 48 8b 85 60 01 00 00        	movq	0x160(%rbp), %rax
100002031: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100002038: f3 0f 10 9d 08 02 00 00     	movss	0x208(%rbp), %xmm3
100002040: f3 0f 10 ad 20 02 00 00     	movss	0x220(%rbp), %xmm5
100002048: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
10000204b: f3 0f 10 a5 10 02 00 00     	movss	0x210(%rbp), %xmm4
100002053: f3 0f 10 ad 28 02 00 00     	movss	0x228(%rbp), %xmm5
10000205b: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
10000205e: 0f 28 cb                    	movaps	%xmm3, %xmm1
100002061: 0f 58 cc                    	addps	%xmm4, %xmm1
100002064: f3 0f 11 8d 18 02 00 00     	movss	%xmm1, 0x218(%rbp)
10000206c: 0f 28 e9                    	movaps	%xmm1, %xmm5
10000206f: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002073: f3 0f 11 ad 30 02 00 00     	movss	%xmm5, 0x230(%rbp)
10000207b: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002085: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
10000208c: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100002093: 48 8b 8d 38 02 00 00        	movq	0x238(%rbp), %rcx
10000209a: 48 01 c8                    	addq	%rcx, %rax
10000209d: 71 0a                       	jno	0x1000020a9 <__text+0x10a9>
10000209f: ba 01 00 00 00              	movl	$0x1, %edx
1000020a4: e9 4b 04 00 00              	jmp	0x1000024f4 <__text+0x14f4>
1000020a9: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
1000020b0: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
1000020ba: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000020bf: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000020c2: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000020c5: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
1000020c8: 0f 92 c0                    	setb	%al
1000020cb: 0f 9b c1                    	setnp	%cl
1000020ce: 20 c8                       	andb	%cl, %al
1000020d0: 48 0f b6 c0                 	movzbq	%al, %rax
1000020d4: 48 89 85 50 02 00 00        	movq	%rax, 0x250(%rbp)
1000020db: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
1000020e2: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
1000020e9: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
1000020f0: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
1000020f7: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
1000020fe: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100002105: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
10000210c: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
100002113: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
10000211a: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
100002121: 48 8b 85 50 02 00 00        	movq	0x250(%rbp), %rax
100002128: 48 85 c0                    	testq	%rax, %rax
10000212b: 0f 84 c7 fd ff ff           	je	0x100001ef8 <__text+0xef8>
100002131: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
10000213b: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002140: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
10000214a: 66 4c 0f 6e d0              	movq	%rax, %xmm10
10000214f: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002152: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100002156: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002159: 0f 97 c0                    	seta	%al
10000215c: 48 0f b6 c0                 	movzbq	%al, %rax
100002160: 48 89 85 68 02 00 00        	movq	%rax, 0x268(%rbp)
100002167: 48 8b 85 68 02 00 00        	movq	0x268(%rbp), %rax
10000216e: 48 85 c0                    	testq	%rax, %rax
100002171: 0f 84 03 00 00 00           	je	0x10000217a <__text+0x117a>
100002177: 0f 28 f7                    	movaps	%xmm7, %xmm6
10000217a: 48 8b 85 58 04 00 00        	movq	0x458(%rbp), %rax
100002181: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002186: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
10000218a: 0f 28 ce                    	movaps	%xmm6, %xmm1
10000218d: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002191: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002195: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002198: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
10000219c: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000021a0: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000021a3: 48 8b 85 60 04 00 00        	movq	0x460(%rbp), %rax
1000021aa: 66 4c 0f 6e c0              	movq	%rax, %xmm8
1000021af: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000021b3: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000021b6: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000021ba: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000021be: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000021c2: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
1000021c6: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000021ca: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000021ce: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
1000021d5: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
1000021dc: 66 48 0f 7e f8              	movq	%xmm7, %rax
1000021e1: 48 89 85 58 04 00 00        	movq	%rax, 0x458(%rbp)
1000021e8: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
1000021ef: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
1000021f6: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
1000021fd: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
100002204: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
10000220b: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
100002212: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
100002219: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
100002220: 66 4c 0f 7e c0              	movq	%xmm8, %rax
100002225: 48 89 85 60 04 00 00        	movq	%rax, 0x460(%rbp)
10000222c: e9 c7 fc ff ff              	jmp	0x100001ef8 <__text+0xef8>
100002231: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100002238: 48 89 c1                    	movq	%rax, %rcx
10000223b: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100002240: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100002244: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
10000224e: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002253: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002257: 0f 82 39 00 00 00           	jb	0x100002296 <__text+0x1296>
10000225d: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100002267: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000226c: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002270: 0f 83 20 00 00 00           	jae	0x100002296 <__text+0x1296>
100002276: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
10000227b: 48 39 c8                    	cmpq	%rcx, %rax
10000227e: 0f 85 12 00 00 00           	jne	0x100002296 <__text+0x1296>
100002284: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100002288: 66 0f 7e d8                 	movd	%xmm3, %eax
10000228c: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002291: e9 3d 00 00 00              	jmp	0x1000022d3 <__text+0x12d3>
100002296: 48 8d 35 9b 21 00 00        	leaq	0x219b(%rip), %rsi      ## 0x100004438
10000229d: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000022a4: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000022ab: 4c 89 c2                    	movq	%r8, %rdx
1000022ae: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000022b8: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
1000022c2: 0f 05                       	syscall
1000022c4: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000022ce: e9 21 02 00 00              	jmp	0x1000024f4 <__text+0x14f4>
1000022d3: 48 8b 85 50 04 00 00        	movq	0x450(%rbp), %rax
1000022da: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000022df: 48 8b 85 68 04 00 00        	movq	0x468(%rbp), %rax
1000022e6: 66 4c 0f 6e c0              	movq	%rax, %xmm8
1000022eb: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000022ef: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000022f2: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000022f6: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000022fa: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100002301: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002306: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
10000230a: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
10000230e: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002312: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002316: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002320: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002325: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002329: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
10000232d: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002331: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002335: 48 8b 85 70 04 00 00        	movq	0x470(%rbp), %rax
10000233c: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002341: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002345: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002348: f3 0f 5e c1                 	divss	%xmm1, %xmm0
10000234c: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100002350: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100002357: 66 4c 0f 6e d0              	movq	%rax, %xmm10
10000235c: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002360: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100002364: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002368: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
10000236c: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002376: 66 4c 0f 6e d0              	movq	%rax, %xmm10
10000237b: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
10000237f: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100002383: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002387: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
10000238b: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
10000238f: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002393: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002397: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
10000239b: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
1000023a2: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000023a7: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000023ab: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000023ae: f3 0f 5e c1                 	divss	%xmm1, %xmm0
1000023b2: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000023b6: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
1000023bd: 66 4c 0f 6e d0              	movq	%rax, %xmm10
1000023c2: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000023c6: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
1000023ca: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000023ce: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000023d2: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
1000023dc: 66 4c 0f 6e d0              	movq	%rax, %xmm10
1000023e1: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000023e5: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
1000023e9: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000023ed: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000023f1: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000023f5: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
1000023f9: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000023fd: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002401: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
100002408: 66 4c 0f 6e c8              	movq	%rax, %xmm9
10000240d: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002411: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002414: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002418: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
10000241c: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
100002423: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002428: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
10000242c: 0f 28 ce                    	movaps	%xmm6, %xmm1
10000242f: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002433: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100002437: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002441: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002446: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
10000244a: 0f 28 ce                    	movaps	%xmm6, %xmm1
10000244d: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002451: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
100002455: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002459: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
10000245d: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002461: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002465: 48 8b 85 58 04 00 00        	movq	0x458(%rbp), %rax
10000246c: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002471: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
10000247b: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002480: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002483: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002487: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000248b: 0f 28 f0                    	movaps	%xmm0, %xmm6
10000248e: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002492: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002495: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002499: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
10000249d: 48 8b 85 60 04 00 00        	movq	0x460(%rbp), %rax
1000024a4: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000024a9: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
1000024b3: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000024b8: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000024bb: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
1000024bf: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000024c3: 0f 28 f0                    	movaps	%xmm0, %xmm6
1000024c6: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000024ca: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000024cd: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000024d1: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
1000024d5: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000024d8: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
1000024dc: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000024e0: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000024e3: 66 48 0f 7e f8              	movq	%xmm7, %rax
1000024e8: 48 89 85 50 04 00 00        	movq	%rax, 0x450(%rbp)
1000024ef: e9 5f f8 ff ff              	jmp	0x100001d53 <__text+0xd53>
1000024f4: 48 89 ec                    	movq	%rbp, %rsp
1000024f7: 48 81 c4 a0 04 00 00        	addq	$0x4a0, %rsp            ## imm = 0x4A0
1000024fe: 5d                          	popq	%rbp
1000024ff: c3                          	retq
100002500: 55                          	pushq	%rbp
100002501: 48 89 e5                    	movq	%rsp, %rbp
100002504: 48 81 ec 00 04 00 00        	subq	$0x400, %rsp            ## imm = 0x400
10000250b: 48 89 e5                    	movq	%rsp, %rbp
10000250e: 4c 89 bd 30 00 00 00        	movq	%r15, 0x30(%rbp)
100002515: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
10000251c: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100002523: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
10000252a: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100002531: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
100002538: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
10000253f: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
100002546: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
10000254d: 48 8b 87 10 00 00 00        	movq	0x10(%rdi), %rax
100002554: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
10000255b: 48 8b 87 18 00 00 00        	movq	0x18(%rdi), %rax
100002562: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100002569: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100002570: 48 89 85 60 03 00 00        	movq	%rax, 0x360(%rbp)
100002577: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
10000257e: 48 89 85 68 03 00 00        	movq	%rax, 0x368(%rbp)
100002585: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
10000258c: 48 89 85 70 03 00 00        	movq	%rax, 0x370(%rbp)
100002593: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
10000259a: 48 89 85 78 03 00 00        	movq	%rax, 0x378(%rbp)
1000025a1: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000025ab: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
1000025b2: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000025bc: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
1000025c3: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000025cd: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000025d4: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000025de: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
1000025e5: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000025ef: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
1000025f6: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002600: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100002607: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002611: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100002618: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
10000261f: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100002626: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
10000262d: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100002634: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000263e: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100002645: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
10000264c: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
100002653: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
10000265a: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
100002661: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100002668: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
10000266f: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100002676: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
10000267d: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100002684: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
10000268b: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
100002692: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
100002699: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000026a0: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
1000026a7: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
1000026ae: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
1000026b5: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000026bc: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000026c3: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000026ca: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
1000026d1: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
1000026d8: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
1000026df: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
1000026e6: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
1000026ed: 48 39 c8                    	cmpq	%rcx, %rax
1000026f0: 0f 8d 52 01 00 00           	jge	0x100002848 <__text+0x1848>
1000026f6: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000026fd: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100002704: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
10000270b: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100002712: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100002719: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
100002720: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
100002727: 48 85 c0                    	testq	%rax, %rax
10000272a: 0f 89 03 00 00 00           	jns	0x100002733 <__text+0x1733>
100002730: 48 01 c8                    	addq	%rcx, %rax
100002733: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
10000273a: 48 01 c3                    	addq	%rax, %rbx
10000273d: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002744: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
10000274b: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002752: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100002759: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002760: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100002767: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
10000276e: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100002775: 48 8b 85 60 03 00 00        	movq	0x360(%rbp), %rax
10000277c: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002781: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100002788: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000278d: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002790: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002793: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002797: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
10000279b: 48 8b 85 68 03 00 00        	movq	0x368(%rbp), %rax
1000027a2: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000027a7: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
1000027ae: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000027b3: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000027b6: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000027b9: f3 0f 5c c1                 	subss	%xmm1, %xmm0
1000027bd: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000027c1: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
1000027c5: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
1000027c9: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000027cd: 0f 28 f0                    	movaps	%xmm0, %xmm6
1000027d0: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000027d4: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
1000027d8: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000027dc: 44 0f 28 d0                 	movaps	%xmm0, %xmm10
1000027e0: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000027e3: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
1000027e7: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000027eb: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000027ee: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000027f8: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000027fd: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002800: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002803: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002806: 0f 87 69 00 00 00           	ja	0x100002875 <__text+0x1875>
10000280c: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002816: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
10000281d: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
100002824: 48 8b 8d 10 02 00 00        	movq	0x210(%rbp), %rcx
10000282b: 48 01 c8                    	addq	%rcx, %rax
10000282e: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
100002835: 48 8b 85 08 02 00 00        	movq	0x208(%rbp), %rax
10000283c: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
100002843: e9 6d fe ff ff              	jmp	0x1000026b5 <__text+0x16b5>
100002848: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002852: 48 89 85 18 02 00 00        	movq	%rax, 0x218(%rbp)
100002859: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002860: 48 8b 8d 18 02 00 00        	movq	0x218(%rbp), %rcx
100002867: 48 39 c8                    	cmpq	%rcx, %rax
10000286a: 0f 84 0a 03 00 00           	je	0x100002b7a <__text+0x1b7a>
100002870: e9 77 03 00 00              	jmp	0x100002bec <__text+0x1bec>
100002875: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
10000287f: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002884: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002887: 0f 28 ce                    	movaps	%xmm6, %xmm1
10000288a: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
10000288d: 0f 8a 79 ff ff ff           	jp	0x10000280c <__text+0x180c>
100002893: 0f 83 73 ff ff ff           	jae	0x10000280c <__text+0x180c>
100002899: 48 8b 85 c0 03 00 00        	movq	0x3c0(%rbp), %rax
1000028a0: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
1000028a7: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
1000028ae: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
1000028b5: 48 8b 85 c8 03 00 00        	movq	0x3c8(%rbp), %rax
1000028bc: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
1000028c3: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
1000028ca: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
1000028d1: f3 0f 10 9d 30 01 00 00     	movss	0x130(%rbp), %xmm3
1000028d9: f3 0f 10 ad 48 01 00 00     	movss	0x148(%rbp), %xmm5
1000028e1: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
1000028e4: f3 0f 10 a5 38 01 00 00     	movss	0x138(%rbp), %xmm4
1000028ec: f3 0f 10 ad 50 01 00 00     	movss	0x150(%rbp), %xmm5
1000028f4: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
1000028f7: 0f 28 c3                    	movaps	%xmm3, %xmm0
1000028fa: 0f 58 c4                    	addps	%xmm4, %xmm0
1000028fd: f3 0f 11 85 40 01 00 00     	movss	%xmm0, 0x140(%rbp)
100002905: 0f 28 e8                    	movaps	%xmm0, %xmm5
100002908: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
10000290c: f3 0f 11 ad 58 01 00 00     	movss	%xmm5, 0x158(%rbp)
100002914: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
10000291b: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100002922: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
100002929: 48 89 85 68 01 00 00        	movq	%rax, 0x168(%rbp)
100002930: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
100002937: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
10000293e: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
100002945: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
10000294c: f3 0f 10 9d 60 01 00 00     	movss	0x160(%rbp), %xmm3
100002954: f3 0f 10 ad 78 01 00 00     	movss	0x178(%rbp), %xmm5
10000295c: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
10000295f: f3 0f 10 a5 68 01 00 00     	movss	0x168(%rbp), %xmm4
100002967: f3 0f 10 ad 80 01 00 00     	movss	0x180(%rbp), %xmm5
10000296f: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002972: 0f 28 cb                    	movaps	%xmm3, %xmm1
100002975: 0f 58 cc                    	addps	%xmm4, %xmm1
100002978: f3 0f 11 8d 70 01 00 00     	movss	%xmm1, 0x170(%rbp)
100002980: 0f 28 e9                    	movaps	%xmm1, %xmm5
100002983: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002987: f3 0f 11 ad 88 01 00 00     	movss	%xmm5, 0x188(%rbp)
10000298f: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002999: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
1000029a0: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
1000029a7: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
1000029ae: 48 01 c8                    	addq	%rcx, %rax
1000029b1: 71 0a                       	jno	0x1000029bd <__text+0x19bd>
1000029b3: ba 01 00 00 00              	movl	$0x1, %edx
1000029b8: e9 00 05 00 00              	jmp	0x100002ebd <__text+0x1ebd>
1000029bd: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
1000029c4: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
1000029ce: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000029d3: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000029d6: 0f 28 ce                    	movaps	%xmm6, %xmm1
1000029d9: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
1000029dc: 0f 92 c0                    	setb	%al
1000029df: 0f 9b c1                    	setnp	%cl
1000029e2: 20 c8                       	andb	%cl, %al
1000029e4: 48 0f b6 c0                 	movzbq	%al, %rax
1000029e8: 48 89 85 a8 01 00 00        	movq	%rax, 0x1a8(%rbp)
1000029ef: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
1000029f6: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
1000029fd: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002a04: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
100002a0b: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002a12: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
100002a19: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
100002a20: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
100002a27: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
100002a2e: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
100002a35: 48 8b 85 a8 01 00 00        	movq	0x1a8(%rbp), %rax
100002a3c: 48 85 c0                    	testq	%rax, %rax
100002a3f: 0f 84 c7 fd ff ff           	je	0x10000280c <__text+0x180c>
100002a45: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100002a4f: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002a54: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100002a5e: 66 4c 0f 6e d0              	movq	%rax, %xmm10
100002a63: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002a66: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
100002a6a: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100002a6d: 0f 97 c0                    	seta	%al
100002a70: 48 0f b6 c0                 	movzbq	%al, %rax
100002a74: 48 89 85 c0 01 00 00        	movq	%rax, 0x1c0(%rbp)
100002a7b: 48 8b 85 c0 01 00 00        	movq	0x1c0(%rbp), %rax
100002a82: 48 85 c0                    	testq	%rax, %rax
100002a85: 0f 84 03 00 00 00           	je	0x100002a8e <__text+0x1a8e>
100002a8b: 0f 28 f7                    	movaps	%xmm7, %xmm6
100002a8e: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002a95: 48 89 85 c8 01 00 00        	movq	%rax, 0x1c8(%rbp)
100002a9c: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002aa0: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002aa3: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002aa7: f3 0f 11 85 d8 01 00 00     	movss	%xmm0, 0x1d8(%rbp)
100002aaf: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
100002ab6: 48 89 85 e8 01 00 00        	movq	%rax, 0x1e8(%rbp)
100002abd: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002ac1: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002ac4: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002ac8: f3 0f 11 85 f8 01 00 00     	movss	%xmm0, 0x1f8(%rbp)
100002ad0: f3 0f 10 9d c8 01 00 00     	movss	0x1c8(%rbp), %xmm3
100002ad8: f3 0f 10 ad e8 01 00 00     	movss	0x1e8(%rbp), %xmm5
100002ae0: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002ae3: f3 0f 10 a5 d8 01 00 00     	movss	0x1d8(%rbp), %xmm4
100002aeb: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100002af3: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002af6: 0f 28 d3                    	movaps	%xmm3, %xmm2
100002af9: 0f 58 d4                    	addps	%xmm4, %xmm2
100002afc: f3 0f 11 95 e0 01 00 00     	movss	%xmm2, 0x1e0(%rbp)
100002b04: 0f 28 ea                    	movaps	%xmm2, %xmm5
100002b07: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002b0b: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
100002b13: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100002b1a: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
100002b21: 48 8b 85 e0 01 00 00        	movq	0x1e0(%rbp), %rax
100002b28: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
100002b2f: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002b36: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
100002b3d: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
100002b44: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
100002b4b: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
100002b52: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
100002b59: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002b60: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
100002b67: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100002b6e: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
100002b75: e9 92 fc ff ff              	jmp	0x10000280c <__text+0x180c>
100002b7a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002b84: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100002b8b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002b95: 48 89 85 30 02 00 00        	movq	%rax, 0x230(%rbp)
100002b9c: 48 8b 85 28 02 00 00        	movq	0x228(%rbp), %rax
100002ba3: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
100002baa: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
100002bb1: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
100002bb8: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002bbf: 48 8b 85 38 02 00 00        	movq	0x238(%rbp), %rax
100002bc6: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002bcd: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
100002bd4: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002bdb: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002be5: 31 d2                       	xorl	%edx, %edx
100002be7: e9 d1 02 00 00              	jmp	0x100002ebd <__text+0x1ebd>
100002bec: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002bf3: 48 89 c1                    	movq	%rax, %rcx
100002bf6: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100002bfb: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100002bff: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100002c09: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002c0e: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002c12: 0f 82 39 00 00 00           	jb	0x100002c51 <__text+0x1c51>
100002c18: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100002c22: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002c27: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002c2b: 0f 83 20 00 00 00           	jae	0x100002c51 <__text+0x1c51>
100002c31: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100002c36: 48 39 c8                    	cmpq	%rcx, %rax
100002c39: 0f 85 12 00 00 00           	jne	0x100002c51 <__text+0x1c51>
100002c3f: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100002c43: 66 0f 7e d8                 	movd	%xmm3, %eax
100002c47: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002c4c: e9 3d 00 00 00              	jmp	0x100002c8e <__text+0x1c8e>
100002c51: 48 8d 35 d0 18 00 00        	leaq	0x18d0(%rip), %rsi      ## 0x100004528
100002c58: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100002c5f: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100002c66: 4c 89 c2                    	movq	%r8, %rdx
100002c69: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100002c73: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100002c7d: 0f 05                       	syscall
100002c7f: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002c89: e9 2f 02 00 00              	jmp	0x100002ebd <__text+0x1ebd>
100002c8e: 48 8b 85 c0 03 00 00        	movq	0x3c0(%rbp), %rax
100002c95: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002c9a: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002c9d: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002ca0: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002ca4: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002ca7: 48 8b 85 60 03 00 00        	movq	0x360(%rbp), %rax
100002cae: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002cb3: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002cb6: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002cba: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002cbe: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002cc1: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002ccb: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002cd0: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002cd3: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002cd7: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002cdb: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002cde: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
100002ce5: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002cea: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002cee: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002cf1: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002cf5: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002cf9: 48 8b 85 70 03 00 00        	movq	0x370(%rbp), %rax
100002d00: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002d05: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002d09: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002d0d: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002d11: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002d15: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002d1f: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002d24: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002d28: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002d2c: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002d30: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002d34: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002d37: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002d3b: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002d3f: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002d42: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002d49: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002d4e: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002d58: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002d5d: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002d61: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100002d65: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002d69: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002d6d: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002d70: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002d74: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002d78: f3 0f 11 85 c0 02 00 00     	movss	%xmm0, 0x2c0(%rbp)
100002d80: 48 8b 85 c8 03 00 00        	movq	0x3c8(%rbp), %rax
100002d87: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002d8c: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002d8f: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002d92: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002d96: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002d99: 48 8b 85 68 03 00 00        	movq	0x368(%rbp), %rax
100002da0: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002da5: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002da8: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002dac: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002db0: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002db3: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002dbd: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002dc2: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002dc5: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002dc9: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002dcd: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002dd0: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
100002dd7: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002ddc: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002de0: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002de3: f3 0f 5e c1                 	divss	%xmm1, %xmm0
100002de7: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002deb: 48 8b 85 78 03 00 00        	movq	0x378(%rbp), %rax
100002df2: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002df7: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002dfb: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002dfe: f3 0f 5c c1                 	subss	%xmm1, %xmm0
100002e02: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002e06: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002e10: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002e15: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100002e19: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002e1c: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002e20: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
100002e24: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002e27: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002e2b: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002e2f: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002e32: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
100002e39: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002e3e: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002e48: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002e4d: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002e50: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100002e54: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100002e58: 0f 28 f0                    	movaps	%xmm0, %xmm6
100002e5b: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002e5e: 0f 28 ce                    	movaps	%xmm6, %xmm1
100002e61: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100002e65: f3 0f 11 85 38 03 00 00     	movss	%xmm0, 0x338(%rbp)
100002e6d: 48 8b 85 c0 02 00 00        	movq	0x2c0(%rbp), %rax
100002e74: 48 89 85 40 03 00 00        	movq	%rax, 0x340(%rbp)
100002e7b: 48 8b 85 38 03 00 00        	movq	0x338(%rbp), %rax
100002e82: 48 89 85 48 03 00 00        	movq	%rax, 0x348(%rbp)
100002e89: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002e90: 48 8b 85 40 03 00 00        	movq	0x340(%rbp), %rax
100002e97: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002e9e: 48 8b 85 48 03 00 00        	movq	0x348(%rbp), %rax
100002ea5: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002eac: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002eb6: 31 d2                       	xorl	%edx, %edx
100002eb8: e9 00 00 00 00              	jmp	0x100002ebd <__text+0x1ebd>
100002ebd: 48 89 ec                    	movq	%rbp, %rsp
100002ec0: 48 81 c4 00 04 00 00        	addq	$0x400, %rsp            ## imm = 0x400
100002ec7: 5d                          	popq	%rbp
100002ec8: c3                          	retq
100002ec9: 55                          	pushq	%rbp
100002eca: 48 89 e5                    	movq	%rsp, %rbp
100002ecd: 48 81 ec b0 01 00 00        	subq	$0x1b0, %rsp            ## imm = 0x1B0
100002ed4: 48 89 e5                    	movq	%rsp, %rbp
100002ed7: 48 89 95 18 00 00 00        	movq	%rdx, 0x18(%rbp)
100002ede: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
100002ee5: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100002eec: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
100002ef3: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
100002efa: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
100002f01: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002f0b: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100002f12: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002f1c: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100002f23: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002f2a: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002f31: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100002f38: 48 8b 8d 30 00 00 00        	movq	0x30(%rbp), %rcx
100002f3f: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002f46: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100002f4d: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
100002f57: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100002f5e: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002f65: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100002f6c: 48 39 c8                    	cmpq	%rcx, %rax
100002f6f: 0f 9c c0                    	setl	%al
100002f72: 48 0f b6 c0                 	movzbq	%al, %rax
100002f76: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100002f7d: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002f84: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100002f8b: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100002f92: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002f99: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100002fa0: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002fa7: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100002fae: 48 85 c0                    	testq	%rax, %rax
100002fb1: 0f 84 3b 00 00 00           	je	0x100002ff2 <__text+0x1ff2>
100002fb7: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002fc1: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100002fc8: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002fcf: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100002fd6: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
100002fdd: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002fe4: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100002feb: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002ff2: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002ff9: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100003000: 48 39 c8                    	cmpq	%rcx, %rax
100003003: 0f 84 ad 05 00 00           	je	0x1000035b6 <__text+0x25b6>
100003009: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100003010: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100003017: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
10000301e: 48 8b 9d 60 00 00 00        	movq	0x60(%rbp), %rbx
100003025: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
10000302c: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003033: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
10000303a: 48 85 c0                    	testq	%rax, %rax
10000303d: 0f 89 03 00 00 00           	jns	0x100003046 <__text+0x2046>
100003043: 48 01 c8                    	addq	%rcx, %rax
100003046: 48 39 c8                    	cmpq	%rcx, %rax
100003049: 0f 82 0f 00 00 00           	jb	0x10000305e <__text+0x205e>
10000304f: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003059: e9 74 05 00 00              	jmp	0x1000035d2 <__text+0x25d2>
10000305e: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003065: 48 01 c3                    	addq	%rax, %rbx
100003068: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000306f: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100003076: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
10000307d: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100003084: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
10000308b: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100003092: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003099: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
1000030a0: 4c 8d bd 88 00 00 00        	leaq	0x88(%rbp), %r15
1000030a7: 48 8d bd 68 00 00 00        	leaq	0x68(%rbp), %rdi
1000030ae: 48 8d b5 08 00 00 00        	leaq	0x8(%rbp), %rsi
1000030b5: e8 46 f4 ff ff              	callq	0x100002500 <__text+0x1500>
1000030ba: 48 85 d2                    	testq	%rdx, %rdx
1000030bd: 0f 85 0f 05 00 00           	jne	0x1000035d2 <__text+0x25d2>
1000030c3: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
1000030ca: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000030cf: 48 8b 85 88 00 00 00        	movq	0x88(%rbp), %rax
1000030d6: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000030db: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000030de: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
1000030e6: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000030ea: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000030ed: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000030f0: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000030f3: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000030f7: f3 0f 11 85 b0 00 00 00     	movss	%xmm0, 0xb0(%rbp)
1000030ff: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100003106: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000310b: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100003112: 66 48 0f 6e f8              	movq	%rax, %xmm7
100003117: 0f 28 c7                    	movaps	%xmm7, %xmm0
10000311a: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100003122: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100003126: 0f 28 f8                    	movaps	%xmm0, %xmm7
100003129: 0f 28 c6                    	movaps	%xmm6, %xmm0
10000312c: 0f 28 cf                    	movaps	%xmm7, %xmm1
10000312f: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003133: f3 0f 11 85 d0 00 00 00     	movss	%xmm0, 0xd0(%rbp)
10000313b: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100003142: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003147: f3 0f 10 85 b0 00 00 00     	movss	0xb0(%rbp), %xmm0
10000314f: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100003157: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000315b: 0f 28 f8                    	movaps	%xmm0, %xmm7
10000315e: 0f 28 c6                    	movaps	%xmm6, %xmm0
100003161: 0f 28 cf                    	movaps	%xmm7, %xmm1
100003164: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003168: f3 0f 11 85 e8 00 00 00     	movss	%xmm0, 0xe8(%rbp)
100003170: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100003177: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000317c: f3 0f 10 85 d0 00 00 00     	movss	0xd0(%rbp), %xmm0
100003184: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
10000318c: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100003190: 0f 28 f8                    	movaps	%xmm0, %xmm7
100003193: 0f 28 c6                    	movaps	%xmm6, %xmm0
100003196: 0f 28 cf                    	movaps	%xmm7, %xmm1
100003199: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000319d: f3 0f 11 85 00 01 00 00     	movss	%xmm0, 0x100(%rbp)
1000031a5: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
1000031ac: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
1000031b3: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
1000031ba: 48 8b 9d 08 01 00 00        	movq	0x108(%rbp), %rbx
1000031c1: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
1000031c8: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000031cf: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000031d6: 48 85 c0                    	testq	%rax, %rax
1000031d9: 0f 89 03 00 00 00           	jns	0x1000031e2 <__text+0x21e2>
1000031df: 48 01 c8                    	addq	%rcx, %rax
1000031e2: 48 39 c8                    	cmpq	%rcx, %rax
1000031e5: 0f 82 0f 00 00 00           	jb	0x1000031fa <__text+0x21fa>
1000031eb: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000031f5: e9 d8 03 00 00              	jmp	0x1000035d2 <__text+0x25d2>
1000031fa: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003201: 48 01 c3                    	addq	%rax, %rbx
100003204: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000320b: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003212: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003219: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003220: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003227: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
10000322e: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003235: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
10000323c: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100003243: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
10000324a: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100003251: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100003258: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
10000325f: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100003266: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
10000326d: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100003274: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
10000327b: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100003282: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100003289: 48 8b 9d 50 01 00 00        	movq	0x150(%rbp), %rbx
100003290: 4c 8b a3 00 00 00 00        	movq	(%rbx), %r12
100003297: 4c 8b ad 88 01 00 00        	movq	0x188(%rbp), %r13
10000329e: 4d 85 ed                    	testq	%r13, %r13
1000032a1: 0f 89 03 00 00 00           	jns	0x1000032aa <__text+0x22aa>
1000032a7: 4d 01 e5                    	addq	%r12, %r13
1000032aa: 4d 39 e5                    	cmpq	%r12, %r13
1000032ad: 0f 82 0f 00 00 00           	jb	0x1000032c2 <__text+0x22c2>
1000032b3: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000032bd: e9 10 03 00 00              	jmp	0x1000035d2 <__text+0x25d2>
1000032c2: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
1000032c9: 4c 8b 9b 10 00 00 00        	movq	0x10(%rbx), %r11
1000032d0: 4c 01 d8                    	addq	%r11, %rax
1000032d3: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000032dd: 48 39 c8                    	cmpq	%rcx, %rax
1000032e0: 0f 85 5b 00 00 00           	jne	0x100003341 <__text+0x2341>
1000032e6: 49 89 de                    	movq	%rbx, %r14
1000032e9: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000032f0: 4c 89 e8                    	movq	%r13, %rax
1000032f3: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000032fa: 49 01 c6                    	addq	%rax, %r14
1000032fd: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100003304: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
10000330b: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
100003312: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100003319: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100003320: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100003327: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
10000332e: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
100003335: 48 89 9d 58 01 00 00        	movq	%rbx, 0x158(%rbp)
10000333c: e9 ed 01 00 00              	jmp	0x10000352e <__text+0x252e>
100003341: 4c 89 e6                    	movq	%r12, %rsi
100003344: 48 b9 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rcx
10000334e: 48 0f af f1                 	imulq	%rcx, %rsi
100003352: 48 81 c6 28 00 00 00        	addq	$0x28, %rsi
100003359: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
100003363: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000336d: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
100003377: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
100003381: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
10000338b: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
100003395: 0f 05                       	syscall
100003397: 0f 83 0f 00 00 00           	jae	0x1000033ac <__text+0x23ac>
10000339d: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000033a7: e9 26 02 00 00              	jmp	0x1000035d2 <__text+0x25d2>
1000033ac: 49 89 c7                    	movq	%rax, %r15
1000033af: 4d 89 a7 00 00 00 00        	movq	%r12, (%r15)
1000033b6: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000033c0: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
1000033c7: 49 89 87 10 00 00 00        	movq	%rax, 0x10(%r15)
1000033ce: 49 89 87 20 00 00 00        	movq	%rax, 0x20(%r15)
1000033d5: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000033df: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
1000033e6: 49 89 b7 18 00 00 00        	movq	%rsi, 0x18(%r15)
1000033ed: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000033f4: 4d 89 fe                    	movq	%r15, %r14
1000033f7: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000033fe: 4c 89 e6                    	movq	%r12, %rsi
100003401: 48 b9 04 00 00 00 00 00 00 00       	movabsq	$0x4, %rcx
10000340b: 48 0f af f1                 	imulq	%rcx, %rsi
10000340f: 48 85 f6                    	testq	%rsi, %rsi
100003412: 0f 84 20 00 00 00           	je	0x100003438 <__text+0x2438>
100003418: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000341f: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100003426: 48 83 c3 08                 	addq	$0x8, %rbx
10000342a: 49 83 c6 08                 	addq	$0x8, %r14
10000342e: 48 83 ee 01                 	subq	$0x1, %rsi
100003432: 0f 85 e0 ff ff ff           	jne	0x100003418 <__text+0x2418>
100003438: 4d 89 fe                    	movq	%r15, %r14
10000343b: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100003442: 4c 89 e8                    	movq	%r13, %rax
100003445: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
10000344c: 49 01 c6                    	addq	%rax, %r14
10000344f: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100003456: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
10000345d: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
100003464: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
10000346b: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100003472: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100003479: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100003480: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
100003487: 4c 89 bd 58 01 00 00        	movq	%r15, 0x158(%rbp)
10000348e: 4c 8b 95 50 01 00 00        	movq	0x150(%rbp), %r10
100003495: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
10000349c: 48 85 c0                    	testq	%rax, %rax
10000349f: 0f 84 89 00 00 00           	je	0x10000352e <__text+0x252e>
1000034a5: 49 89 c3                    	movq	%rax, %r11
1000034a8: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
1000034af: f0                          	lock
1000034b0: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
1000034b5: 0f 85 da ff ff ff           	jne	0x100003495 <__text+0x2495>
1000034bb: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
1000034c2: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
1000034c9: 4c 01 d8                    	addq	%r11, %rax
1000034cc: 48 85 c0                    	testq	%rax, %rax
1000034cf: 0f 85 59 00 00 00           	jne	0x10000352e <__text+0x252e>
1000034d5: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
1000034dc: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
1000034e6: 48 39 c8                    	cmpq	%rcx, %rax
1000034e9: 0f 84 e6 ff ff ff           	je	0x1000034d5 <__text+0x24d5>
1000034ef: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000034f9: 48 39 c8                    	cmpq	%rcx, %rax
1000034fc: 0f 84 2c 00 00 00           	je	0x10000352e <__text+0x252e>
100003502: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
10000350c: f0                          	lock
10000350d: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003512: 0f 85 bd ff ff ff           	jne	0x1000034d5 <__text+0x24d5>
100003518: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
10000351f: 4c 89 d7                    	movq	%r10, %rdi
100003522: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
10000352c: 0f 05                       	syscall
10000352e: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100003535: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
10000353c: 48 89 81 00 00 00 00        	movq	%rax, (%rcx)
100003543: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
10000354a: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000354f: f3 0f 10 85 e8 00 00 00     	movss	0xe8(%rbp), %xmm0
100003557: f3 0f 10 8d 00 01 00 00     	movss	0x100(%rbp), %xmm1
10000355f: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003563: 0f 28 f8                    	movaps	%xmm0, %xmm7
100003566: 0f 28 c6                    	movaps	%xmm6, %xmm0
100003569: 0f 28 cf                    	movaps	%xmm7, %xmm1
10000356c: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100003570: 0f 28 f0                    	movaps	%xmm0, %xmm6
100003573: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
10000357a: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
100003581: 48 01 c8                    	addq	%rcx, %rax
100003584: 71 0a                       	jno	0x100003590 <__text+0x2590>
100003586: ba 01 00 00 00              	movl	$0x1, %edx
10000358b: e9 42 00 00 00              	jmp	0x1000035d2 <__text+0x25d2>
100003590: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
100003597: 48 8b 85 78 01 00 00        	movq	0x178(%rbp), %rax
10000359e: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
1000035a5: 66 48 0f 7e f0              	movq	%xmm6, %rax
1000035aa: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
1000035b1: e9 3c fa ff ff              	jmp	0x100002ff2 <__text+0x1ff2>
1000035b6: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
1000035bd: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
1000035c4: 48 8b 85 80 01 00 00        	movq	0x180(%rbp), %rax
1000035cb: 31 d2                       	xorl	%edx, %edx
1000035cd: e9 00 00 00 00              	jmp	0x1000035d2 <__text+0x25d2>
1000035d2: 48 89 ec                    	movq	%rbp, %rsp
1000035d5: 48 81 c4 b0 01 00 00        	addq	$0x1b0, %rsp            ## imm = 0x1B0
1000035dc: 5d                          	popq	%rbp
1000035dd: c3                          	retq
1000035de: 55                          	pushq	%rbp
1000035df: 48 89 e5                    	movq	%rsp, %rbp
1000035e2: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
1000035e9: 48 89 e5                    	movq	%rsp, %rbp
1000035ec: 48 89 b5 10 00 00 00        	movq	%rsi, 0x10(%rbp)
1000035f3: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
1000035fa: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
100003601: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
100003608: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
10000360f: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003619: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000361e: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003628: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
10000362f: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
100003639: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100003640: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100003647: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
10000364e: 48 39 c8                    	cmpq	%rcx, %rax
100003651: 0f 9c c0                    	setl	%al
100003654: 48 0f b6 c0                 	movzbq	%al, %rax
100003658: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
10000365f: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100003666: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
10000366d: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
100003674: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
10000367b: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003680: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003687: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
10000368e: 48 85 c0                    	testq	%rax, %rax
100003691: 0f 84 39 00 00 00           	je	0x1000036d0 <__text+0x26d0>
100003697: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000036a1: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
1000036a8: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
1000036af: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
1000036b6: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
1000036bd: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
1000036c4: 66 48 0f 7e f0              	movq	%xmm6, %rax
1000036c9: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
1000036d0: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
1000036d7: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
1000036de: 48 39 c8                    	cmpq	%rcx, %rax
1000036e1: 0f 84 93 00 00 00           	je	0x10000377a <__text+0x277a>
1000036e7: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
1000036ee: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
1000036f5: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
1000036fc: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100003703: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000370d: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
100003714: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
10000371b: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003722: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100003729: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100003730: e9 61 00 00 00              	jmp	0x100003796 <__text+0x2796>
100003735: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
10000373c: 48 8b 8d 10 01 00 00        	movq	0x110(%rbp), %rcx
100003743: 48 01 c8                    	addq	%rcx, %rax
100003746: 71 0a                       	jno	0x100003752 <__text+0x2752>
100003748: ba 01 00 00 00              	movl	$0x1, %edx
10000374d: e9 ae 01 00 00              	jmp	0x100003900 <__text+0x2900>
100003752: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100003759: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
100003760: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100003767: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
10000376e: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003775: e9 56 ff ff ff              	jmp	0x1000036d0 <__text+0x26d0>
10000377a: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100003781: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100003788: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
10000378f: 31 d2                       	xorl	%edx, %edx
100003791: e9 6a 01 00 00              	jmp	0x100003900 <__text+0x2900>
100003796: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
10000379d: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
1000037a4: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
1000037ab: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
1000037b2: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
1000037b9: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
1000037c0: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
1000037c7: 48 8b 8d 70 00 00 00        	movq	0x70(%rbp), %rcx
1000037ce: 48 39 c8                    	cmpq	%rcx, %rax
1000037d1: 0f 8d 5e ff ff ff           	jge	0x100003735 <__text+0x2735>
1000037d7: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
1000037de: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
1000037e5: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
1000037ec: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000037f3: 48 8b 9d 80 00 00 00        	movq	0x80(%rbp), %rbx
1000037fa: 48 8b 8d 88 00 00 00        	movq	0x88(%rbp), %rcx
100003801: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003808: 48 85 c0                    	testq	%rax, %rax
10000380b: 0f 89 03 00 00 00           	jns	0x100003814 <__text+0x2814>
100003811: 48 01 c8                    	addq	%rcx, %rax
100003814: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
10000381b: 48 01 c3                    	addq	%rax, %rbx
10000381e: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003825: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
10000382c: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003833: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
10000383a: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003841: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003848: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
10000384f: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100003856: 4c 8d bd b0 00 00 00        	leaq	0xb0(%rbp), %r15
10000385d: 48 8d bd 90 00 00 00        	leaq	0x90(%rbp), %rdi
100003864: 48 8d b5 00 00 00 00        	leaq	(%rbp), %rsi
10000386b: e8 90 ec ff ff              	callq	0x100002500 <__text+0x1500>
100003870: 48 85 d2                    	testq	%rdx, %rdx
100003873: 0f 85 87 00 00 00           	jne	0x100003900 <__text+0x2900>
100003879: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003880: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003885: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
10000388c: 66 48 0f 6e f8              	movq	%rax, %xmm7
100003891: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100003898: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000389d: 0f 28 c7                    	movaps	%xmm7, %xmm0
1000038a0: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
1000038a4: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000038a8: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000038ab: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000038ae: 0f 28 cf                    	movaps	%xmm7, %xmm1
1000038b1: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000038b5: 0f 28 f0                    	movaps	%xmm0, %xmm6
1000038b8: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000038c2: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
1000038c9: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
1000038d0: 48 8b 8d f0 00 00 00        	movq	0xf0(%rbp), %rcx
1000038d7: 48 01 c8                    	addq	%rcx, %rax
1000038da: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
1000038e1: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
1000038e8: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
1000038ef: 66 48 0f 7e f0              	movq	%xmm6, %rax
1000038f4: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000038fb: e9 96 fe ff ff              	jmp	0x100003796 <__text+0x2796>
100003900: 48 89 ec                    	movq	%rbp, %rsp
100003903: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
10000390a: 5d                          	popq	%rbp
10000390b: c3                          	retq
10000390c: 55                          	pushq	%rbp
10000390d: 48 89 e5                    	movq	%rsp, %rbp
100003910: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
100003917: 48 89 e5                    	movq	%rsp, %rbp
10000391a: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
100003924: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
10000392b: 48 8b bd 00 00 00 00        	movq	(%rbp), %rdi
100003932: e8 c9 d6 ff ff              	callq	0x100001000 <__text>
100003937: 48 85 d2                    	testq	%rdx, %rdx
10000393a: 0f 85 04 06 00 00           	jne	0x100003f44 <__text+0x2f44>
100003940: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100003947: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003951: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
100003958: 48 8b 8d 08 00 00 00        	movq	0x8(%rbp), %rcx
10000395f: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100003966: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
10000396d: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
100003974: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
10000397b: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003982: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
100003989: 48 85 c0                    	testq	%rax, %rax
10000398c: 0f 89 03 00 00 00           	jns	0x100003995 <__text+0x2995>
100003992: 48 01 c8                    	addq	%rcx, %rax
100003995: 48 85 c0                    	testq	%rax, %rax
100003998: 0f 89 0a 00 00 00           	jns	0x1000039a8 <__text+0x29a8>
10000399e: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000039a8: 48 39 c8                    	cmpq	%rcx, %rax
1000039ab: 0f 8e 03 00 00 00           	jle	0x1000039b4 <__text+0x29b4>
1000039b1: 48 89 c8                    	movq	%rcx, %rax
1000039b4: 48 8b 95 18 00 00 00        	movq	0x18(%rbp), %rdx
1000039bb: 48 85 d2                    	testq	%rdx, %rdx
1000039be: 0f 89 03 00 00 00           	jns	0x1000039c7 <__text+0x29c7>
1000039c4: 48 01 ca                    	addq	%rcx, %rdx
1000039c7: 48 85 d2                    	testq	%rdx, %rdx
1000039ca: 0f 89 0a 00 00 00           	jns	0x1000039da <__text+0x29da>
1000039d0: 48 ba 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdx
1000039da: 48 39 ca                    	cmpq	%rcx, %rdx
1000039dd: 0f 8e 03 00 00 00           	jle	0x1000039e6 <__text+0x29e6>
1000039e3: 48 89 ca                    	movq	%rcx, %rdx
1000039e6: 49 bb 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r11
1000039f0: 48 39 d0                    	cmpq	%rdx, %rax
1000039f3: 0f 8d 06 00 00 00           	jge	0x1000039ff <__text+0x29ff>
1000039f9: 49 89 d3                    	movq	%rdx, %r11
1000039fc: 49 29 c3                    	subq	%rax, %r11
1000039ff: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003a06: 48 01 c3                    	addq	%rax, %rbx
100003a09: 48 89 9d 20 00 00 00        	movq	%rbx, 0x20(%rbp)
100003a10: 4c 89 9d 28 00 00 00        	movq	%r11, 0x28(%rbp)
100003a17: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
100003a21: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100003a28: 48 8b bd 30 00 00 00        	movq	0x30(%rbp), %rdi
100003a2f: e8 cc d5 ff ff              	callq	0x100001000 <__text>
100003a34: 48 85 d2                    	testq	%rdx, %rdx
100003a37: 0f 85 07 05 00 00           	jne	0x100003f44 <__text+0x2f44>
100003a3d: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100003a44: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
100003a4b: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100003a52: 48 b8 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rax
100003a5c: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100003a63: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
100003a6a: 48 8b b5 40 00 00 00        	movq	0x40(%rbp), %rsi
100003a71: e8 89 de ff ff              	callq	0x1000018ff <__text+0x8ff>
100003a76: 48 85 d2                    	testq	%rdx, %rdx
100003a79: 0f 85 c5 04 00 00           	jne	0x100003f44 <__text+0x2f44>
100003a7f: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003a86: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003a90: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003a95: f3 0f 10 85 48 00 00 00     	movss	0x48(%rbp), %xmm0
100003a9d: 0f 28 ce                    	movaps	%xmm6, %xmm1
100003aa0: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003aa3: 0f 97 c0                    	seta	%al
100003aa6: 48 0f b6 c0                 	movzbq	%al, %rax
100003aaa: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
100003ab1: 48 b8 00 01 00 00 00 00 00 00       	movabsq	$0x100, %rax    ## imm = 0x100
100003abb: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100003ac2: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
100003ac9: 48 8b b5 60 00 00 00        	movq	0x60(%rbp), %rsi
100003ad0: e8 09 fb ff ff              	callq	0x1000035de <__text+0x25de>
100003ad5: 48 85 d2                    	testq	%rdx, %rdx
100003ad8: 0f 85 66 04 00 00           	jne	0x100003f44 <__text+0x2f44>
100003ade: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100003ae5: f3 0f 10 85 68 00 00 00     	movss	0x68(%rbp), %xmm0
100003aed: f3 0f 10 8d 68 00 00 00     	movss	0x68(%rbp), %xmm1
100003af5: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003af8: 0f 94 c0                    	sete	%al
100003afb: 0f 9b c1                    	setnp	%cl
100003afe: 20 c8                       	andb	%cl, %al
100003b00: 48 0f b6 c0                 	movzbq	%al, %rax
100003b04: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100003b0b: 48 b8 89 88 08 3c 00 00 00 00       	movabsq	$0x3c088889, %rax ## imm = 0x3C088889
100003b15: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100003b1c: 48 8d 85 28 01 00 00        	leaq	0x128(%rbp), %rax
100003b23: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100003b2a: 48 8b bd 80 00 00 00        	movq	0x80(%rbp), %rdi
100003b31: 48 8d b5 20 00 00 00        	leaq	0x20(%rbp), %rsi
100003b38: 48 8b 95 78 00 00 00        	movq	0x78(%rbp), %rdx
100003b3f: e8 85 f3 ff ff              	callq	0x100002ec9 <__text+0x1ec9>
100003b44: 48 85 d2                    	testq	%rdx, %rdx
100003b47: 0f 85 f7 03 00 00           	jne	0x100003f44 <__text+0x2f44>
100003b4d: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100003b54: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003b5e: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003b63: f3 0f 10 85 88 00 00 00     	movss	0x88(%rbp), %xmm0
100003b6b: 0f 28 ce                    	movaps	%xmm6, %xmm1
100003b6e: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003b71: 0f 86 82 01 00 00           	jbe	0x100003cf9 <__text+0x2cf9>
100003b77: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003b7e: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100003b85: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003b8f: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100003b96: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100003b9d: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003ba4: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003bab: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100003bb2: 48 85 c0                    	testq	%rax, %rax
100003bb5: 0f 89 03 00 00 00           	jns	0x100003bbe <__text+0x2bbe>
100003bbb: 48 01 c8                    	addq	%rcx, %rax
100003bbe: 48 39 c8                    	cmpq	%rcx, %rax
100003bc1: 0f 82 0f 00 00 00           	jb	0x100003bd6 <__text+0x2bd6>
100003bc7: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003bd1: e9 6e 03 00 00              	jmp	0x100003f44 <__text+0x2f44>
100003bd6: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003bdd: 48 01 c3                    	addq	%rax, %rbx
100003be0: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003be7: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100003bee: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003bf5: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100003bfc: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003c03: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100003c0a: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003c11: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100003c18: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100003c1f: 48 89 85 d8 00 00 00        	movq	%rax, 0xd8(%rbp)
100003c26: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003c30: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
100003c37: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
100003c3e: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003c45: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003c4c: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
100003c53: 48 85 c0                    	testq	%rax, %rax
100003c56: 0f 89 03 00 00 00           	jns	0x100003c5f <__text+0x2c5f>
100003c5c: 48 01 c8                    	addq	%rcx, %rax
100003c5f: 48 39 c8                    	cmpq	%rcx, %rax
100003c62: 0f 82 0f 00 00 00           	jb	0x100003c77 <__text+0x2c77>
100003c68: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003c72: e9 cd 02 00 00              	jmp	0x100003f44 <__text+0x2f44>
100003c77: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003c7e: 48 01 c3                    	addq	%rax, %rbx
100003c81: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003c88: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100003c8f: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003c96: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003c9d: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003ca4: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100003cab: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003cb2: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100003cb9: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100003cc0: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003cc5: f3 0f 10 85 d8 00 00 00     	movss	0xd8(%rbp), %xmm0
100003ccd: 0f 28 ce                    	movaps	%xmm6, %xmm1
100003cd0: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003cd3: 0f 95 c0                    	setne	%al
100003cd6: 0f 9a c1                    	setp	%cl
100003cd9: 08 c8                       	orb	%cl, %al
100003cdb: 48 0f b6 c0                 	movzbq	%al, %rax
100003cdf: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003ce6: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
100003ced: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003cf4: e9 11 00 00 00              	jmp	0x100003d0a <__text+0x2d0a>
100003cf9: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003d03: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003d0a: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
100003d11: 48 85 c0                    	testq	%rax, %rax
100003d14: 0f 84 23 00 00 00           	je	0x100003d3d <__text+0x2d3d>
100003d1a: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100003d21: 48 85 c0                    	testq	%rax, %rax
100003d24: 0f 84 13 00 00 00           	je	0x100003d3d <__text+0x2d3d>
100003d2a: 48 8b 85 a0 00 00 00        	movq	0xa0(%rbp), %rax
100003d31: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003d38: e9 11 00 00 00              	jmp	0x100003d4e <__text+0x2d4e>
100003d3d: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003d47: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003d4e: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003d55: 48 85 c0                    	testq	%rax, %rax
100003d58: 0f 84 33 00 00 00           	je	0x100003d91 <__text+0x2d91>
100003d5e: 48 8d 35 ab 02 00 00        	leaq	0x2ab(%rip), %rsi       ## 0x100004010
100003d65: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003d6c: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003d73: 4c 89 c2                    	movq	%r8, %rdx
100003d76: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003d80: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003d8a: 0f 05                       	syscall
100003d8c: e9 2e 00 00 00              	jmp	0x100003dbf <__text+0x2dbf>
100003d91: 48 8d 35 88 02 00 00        	leaq	0x288(%rip), %rsi       ## 0x100004020
100003d98: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003d9f: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003da6: 4c 89 c2                    	movq	%r8, %rdx
100003da9: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003db3: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003dbd: 0f 05                       	syscall
100003dbf: 48 8d 35 3a 02 00 00        	leaq	0x23a(%rip), %rsi       ## 0x100004000
100003dc6: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003dcd: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003dd4: 4c 89 c2                    	movq	%r8, %rdx
100003dd7: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003de1: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003deb: 0f 05                       	syscall
100003ded: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003df4: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003dfb: 4c 8b 95 20 01 00 00        	movq	0x120(%rbp), %r10
100003e02: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003e09: 48 85 c0                    	testq	%rax, %rax
100003e0c: 0f 84 89 00 00 00           	je	0x100003e9b <__text+0x2e9b>
100003e12: 49 89 c3                    	movq	%rax, %r11
100003e15: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003e1c: f0                          	lock
100003e1d: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003e22: 0f 85 da ff ff ff           	jne	0x100003e02 <__text+0x2e02>
100003e28: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003e2f: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003e36: 4c 01 d8                    	addq	%r11, %rax
100003e39: 48 85 c0                    	testq	%rax, %rax
100003e3c: 0f 85 59 00 00 00           	jne	0x100003e9b <__text+0x2e9b>
100003e42: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003e49: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003e53: 48 39 c8                    	cmpq	%rcx, %rax
100003e56: 0f 84 e6 ff ff ff           	je	0x100003e42 <__text+0x2e42>
100003e5c: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003e66: 48 39 c8                    	cmpq	%rcx, %rax
100003e69: 0f 84 2c 00 00 00           	je	0x100003e9b <__text+0x2e9b>
100003e6f: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100003e79: f0                          	lock
100003e7a: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003e7f: 0f 85 bd ff ff ff           	jne	0x100003e42 <__text+0x2e42>
100003e85: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100003e8c: 4c 89 d7                    	movq	%r10, %rdi
100003e8f: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100003e99: 0f 05                       	syscall
100003e9b: 4c 8b 95 08 00 00 00        	movq	0x8(%rbp), %r10
100003ea2: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003ea9: 48 85 c0                    	testq	%rax, %rax
100003eac: 0f 84 89 00 00 00           	je	0x100003f3b <__text+0x2f3b>
100003eb2: 49 89 c3                    	movq	%rax, %r11
100003eb5: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003ebc: f0                          	lock
100003ebd: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003ec2: 0f 85 da ff ff ff           	jne	0x100003ea2 <__text+0x2ea2>
100003ec8: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003ecf: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003ed6: 4c 01 d8                    	addq	%r11, %rax
100003ed9: 48 85 c0                    	testq	%rax, %rax
100003edc: 0f 85 59 00 00 00           	jne	0x100003f3b <__text+0x2f3b>
100003ee2: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003ee9: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003ef3: 48 39 c8                    	cmpq	%rcx, %rax
100003ef6: 0f 84 e6 ff ff ff           	je	0x100003ee2 <__text+0x2ee2>
100003efc: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003f06: 48 39 c8                    	cmpq	%rcx, %rax
100003f09: 0f 84 2c 00 00 00           	je	0x100003f3b <__text+0x2f3b>
100003f0f: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100003f19: f0                          	lock
100003f1a: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003f1f: 0f 85 bd ff ff ff           	jne	0x100003ee2 <__text+0x2ee2>
100003f25: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100003f2c: 4c 89 d7                    	movq	%r10, %rdi
100003f2f: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100003f39: 0f 05                       	syscall
100003f3b: 31 c0                       	xorl	%eax, %eax
100003f3d: 31 d2                       	xorl	%edx, %edx
100003f3f: e9 00 00 00 00              	jmp	0x100003f44 <__text+0x2f44>
100003f44: 48 89 ec                    	movq	%rbp, %rsp
100003f47: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
100003f4e: 5d                          	popq	%rbp
100003f4f: c3                          	retq
100003f50: 53                          	pushq	%rbx
100003f51: 41 54                       	pushq	%r12
100003f53: 41 55                       	pushq	%r13
100003f55: 41 56                       	pushq	%r14
100003f57: 41 57                       	pushq	%r15
100003f59: e8 ae f9 ff ff              	callq	0x10000390c <__text+0x290c>
100003f5e: 48 85 d2                    	testq	%rdx, %rdx
100003f61: 0f 95 c2                    	setne	%dl
100003f64: 0f b6 d2                    	movzbl	%dl, %edx
100003f67: 48 89 d0                    	movq	%rdx, %rax
100003f6a: 41 5f                       	popq	%r15
100003f6c: 41 5e                       	popq	%r14
100003f6e: 41 5d                       	popq	%r13
100003f70: 41 5c                       	popq	%r12
100003f72: 5b                          	popq	%rbx
100003f73: c3                          	retq
		...
