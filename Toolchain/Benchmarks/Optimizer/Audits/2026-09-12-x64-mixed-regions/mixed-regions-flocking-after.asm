
/private/tmp/silex-part03-evidence/mixed-regions-flocking-macos-x64:	file format mach-o 64-bit x86-64

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
10000106d: e9 75 08 00 00              	jmp	0x1000018e7 <__text+0x8e7>
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
10000117d: 0f 84 8e 06 00 00           	je	0x100001811 <__text+0x811>
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
100001279: e9 69 06 00 00              	jmp	0x1000018e7 <__text+0x8e7>
10000127e: 48 b8 00 00 e0 40 00 00 00 00       	movabsq	$0x40e00000, %rax ## imm = 0x40E00000
100001288: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000128d: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001290: f3 0f 59 c7                 	mulss	%xmm7, %xmm0
100001294: f3 0f 11 85 60 00 00 00     	movss	%xmm0, 0x60(%rbp)
10000129c: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000012a3: 48 b9 71 81 0b 5c e0 02 17 b8       	movabsq	$-0x47e8fd1fa3f47e8f, %rcx ## imm = 0xB81702E05C0B8171
1000012ad: 48 f7 e9                    	imulq	%rcx
1000012b0: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
1000012b7: 48 01 ca                    	addq	%rcx, %rdx
1000012ba: 48 c1 fa 06                 	sarq	$0x6, %rdx
1000012be: 48 89 d0                    	movq	%rdx, %rax
1000012c1: 48 c1 e8 3f                 	shrq	$0x3f, %rax
1000012c5: 48 01 c2                    	addq	%rax, %rdx
1000012c8: 48 b8 59 00 00 00 00 00 00 00       	movabsq	$0x59, %rax
1000012d2: 48 0f af d0                 	imulq	%rax, %rdx
1000012d6: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
1000012dd: 48 29 d1                    	subq	%rdx, %rcx
1000012e0: 48 89 8d 70 00 00 00        	movq	%rcx, 0x70(%rbp)
1000012e7: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
1000012ee: 48 89 c1                    	movq	%rax, %rcx
1000012f1: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
1000012f6: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
1000012fa: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100001304: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001309: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000130d: 0f 82 39 00 00 00           	jb	0x10000134c <__text+0x34c>
100001313: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
10000131d: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001322: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001326: 0f 83 20 00 00 00           	jae	0x10000134c <__text+0x34c>
10000132c: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001331: 48 39 c8                    	cmpq	%rcx, %rax
100001334: 0f 85 12 00 00 00           	jne	0x10000134c <__text+0x34c>
10000133a: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
10000133e: 66 0f 7e d8                 	movd	%xmm3, %eax
100001342: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001347: e9 3d 00 00 00              	jmp	0x100001389 <__text+0x389>
10000134c: 48 8d 35 6d 2d 00 00        	leaq	0x2d6d(%rip), %rsi      ## 0x1000040c0
100001353: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000135a: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001361: 4c 89 c2                    	movq	%r8, %rdx
100001364: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000136e: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100001378: 0f 05                       	syscall
10000137a: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001384: e9 5e 05 00 00              	jmp	0x1000018e7 <__text+0x8e7>
100001389: 48 b8 00 00 a0 40 00 00 00 00       	movabsq	$0x40a00000, %rax ## imm = 0x40A00000
100001393: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001398: 0f 28 c6                    	movaps	%xmm6, %xmm0
10000139b: f3 0f 59 c7                 	mulss	%xmm7, %xmm0
10000139f: f3 0f 11 85 88 00 00 00     	movss	%xmm0, 0x88(%rbp)
1000013a7: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000013ae: 48 b9 c5 4e ec c4 4e ec c4 4e       	movabsq	$0x4ec4ec4ec4ec4ec5, %rcx ## imm = 0x4EC4EC4EC4EC4EC5
1000013b8: 48 f7 e9                    	imulq	%rcx
1000013bb: 48 c1 fa 02                 	sarq	$0x2, %rdx
1000013bf: 48 89 d0                    	movq	%rdx, %rax
1000013c2: 48 c1 e8 3f                 	shrq	$0x3f, %rax
1000013c6: 48 01 c2                    	addq	%rax, %rdx
1000013c9: 48 b8 0d 00 00 00 00 00 00 00       	movabsq	$0xd, %rax
1000013d3: 48 0f af d0                 	imulq	%rax, %rdx
1000013d7: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
1000013de: 48 29 d1                    	subq	%rdx, %rcx
1000013e1: 48 89 8d 98 00 00 00        	movq	%rcx, 0x98(%rbp)
1000013e8: 48 8b 85 98 00 00 00        	movq	0x98(%rbp), %rax
1000013ef: 48 89 c1                    	movq	%rax, %rcx
1000013f2: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
1000013f7: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
1000013fb: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100001405: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000140a: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000140e: 0f 82 39 00 00 00           	jb	0x10000144d <__text+0x44d>
100001414: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
10000141e: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001423: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001427: 0f 83 20 00 00 00           	jae	0x10000144d <__text+0x44d>
10000142d: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001432: 48 39 c8                    	cmpq	%rcx, %rax
100001435: 0f 85 12 00 00 00           	jne	0x10000144d <__text+0x44d>
10000143b: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
10000143f: 66 0f 7e d8                 	movd	%xmm3, %eax
100001443: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001448: e9 3d 00 00 00              	jmp	0x10000148a <__text+0x48a>
10000144d: 48 8d 35 ec 2c 00 00        	leaq	0x2cec(%rip), %rsi      ## 0x100004140
100001454: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000145b: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001462: 4c 89 c2                    	movq	%r8, %rdx
100001465: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000146f: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100001479: 0f 05                       	syscall
10000147b: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001485: e9 5d 04 00 00              	jmp	0x1000018e7 <__text+0x8e7>
10000148a: 48 b8 00 00 5c 42 00 00 00 00       	movabsq	$0x425c0000, %rax ## imm = 0x425C0000
100001494: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001499: 0f 28 c6                    	movaps	%xmm6, %xmm0
10000149c: f3 0f 58 c7                 	addss	%xmm7, %xmm0
1000014a0: f3 0f 11 85 b0 00 00 00     	movss	%xmm0, 0xb0(%rbp)
1000014a8: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000014af: 48 b9 79 78 78 78 78 78 78 78       	movabsq	$0x7878787878787879, %rcx ## imm = 0x7878787878787879
1000014b9: 48 f7 e9                    	imulq	%rcx
1000014bc: 48 c1 fa 03                 	sarq	$0x3, %rdx
1000014c0: 48 89 d0                    	movq	%rdx, %rax
1000014c3: 48 c1 e8 3f                 	shrq	$0x3f, %rax
1000014c7: 48 01 c2                    	addq	%rax, %rdx
1000014ca: 48 b8 11 00 00 00 00 00 00 00       	movabsq	$0x11, %rax
1000014d4: 48 0f af d0                 	imulq	%rax, %rdx
1000014d8: 48 8b 8d 20 01 00 00        	movq	0x120(%rbp), %rcx
1000014df: 48 29 d1                    	subq	%rdx, %rcx
1000014e2: 48 89 8d c0 00 00 00        	movq	%rcx, 0xc0(%rbp)
1000014e9: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
1000014f0: 48 89 c1                    	movq	%rax, %rcx
1000014f3: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
1000014f8: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
1000014fc: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100001506: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000150b: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000150f: 0f 82 39 00 00 00           	jb	0x10000154e <__text+0x54e>
100001515: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
10000151f: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001524: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001528: 0f 83 20 00 00 00           	jae	0x10000154e <__text+0x54e>
10000152e: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001533: 48 39 c8                    	cmpq	%rcx, %rax
100001536: 0f 85 12 00 00 00           	jne	0x10000154e <__text+0x54e>
10000153c: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001540: 66 0f 7e d8                 	movd	%xmm3, %eax
100001544: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001549: e9 3d 00 00 00              	jmp	0x10000158b <__text+0x58b>
10000154e: 48 8d 35 6b 2c 00 00        	leaq	0x2c6b(%rip), %rsi      ## 0x1000041c0
100001555: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000155c: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001563: 4c 89 c2                    	movq	%r8, %rdx
100001566: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001570: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
10000157a: 0f 05                       	syscall
10000157c: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001586: e9 5c 03 00 00              	jmp	0x1000018e7 <__text+0x8e7>
10000158b: 48 b8 00 00 00 41 00 00 00 00       	movabsq	$0x41000000, %rax ## imm = 0x41000000
100001595: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000159a: 0f 28 c6                    	movaps	%xmm6, %xmm0
10000159d: f3 0f 5c c7                 	subss	%xmm7, %xmm0
1000015a1: f3 0f 11 85 d8 00 00 00     	movss	%xmm0, 0xd8(%rbp)
1000015a9: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
1000015b0: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
1000015b7: 48 8b 85 88 00 00 00        	movq	0x88(%rbp), %rax
1000015be: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
1000015c5: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
1000015cc: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
1000015d3: 48 8b 85 d8 00 00 00        	movq	0xd8(%rbp), %rax
1000015da: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
1000015e1: 48 8b 9d 38 00 00 00        	movq	0x38(%rbp), %rbx
1000015e8: 4c 8b a3 00 00 00 00        	movq	(%rbx), %r12
1000015ef: 4d 89 e5                    	movq	%r12, %r13
1000015f2: 49 83 c5 01                 	addq	$0x1, %r13
1000015f6: 4c 89 ee                    	movq	%r13, %rsi
1000015f9: 48 b9 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rcx
100001603: 48 0f af f1                 	imulq	%rcx, %rsi
100001607: 48 81 c6 28 00 00 00        	addq	$0x28, %rsi
10000160e: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
100001618: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001622: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
10000162c: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
100001636: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
100001640: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
10000164a: 0f 05                       	syscall
10000164c: 0f 83 0f 00 00 00           	jae	0x100001661 <__text+0x661>
100001652: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000165c: e9 86 02 00 00              	jmp	0x1000018e7 <__text+0x8e7>
100001661: 49 89 c7                    	movq	%rax, %r15
100001664: 4d 89 af 00 00 00 00        	movq	%r13, (%r15)
10000166b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001675: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
10000167c: 49 89 87 10 00 00 00        	movq	%rax, 0x10(%r15)
100001683: 49 89 87 20 00 00 00        	movq	%rax, 0x20(%r15)
10000168a: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001694: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
10000169b: 49 89 b7 18 00 00 00        	movq	%rsi, 0x18(%r15)
1000016a2: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000016a9: 4d 89 fe                    	movq	%r15, %r14
1000016ac: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000016b3: 4d 89 e5                    	movq	%r12, %r13
1000016b6: 48 b9 04 00 00 00 00 00 00 00       	movabsq	$0x4, %rcx
1000016c0: 4c 0f af e9                 	imulq	%rcx, %r13
1000016c4: 4d 85 ed                    	testq	%r13, %r13
1000016c7: 0f 84 20 00 00 00           	je	0x1000016ed <__text+0x6ed>
1000016cd: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000016d4: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
1000016db: 48 83 c3 08                 	addq	$0x8, %rbx
1000016df: 49 83 c6 08                 	addq	$0x8, %r14
1000016e3: 49 83 ed 01                 	subq	$0x1, %r13
1000016e7: 0f 85 e0 ff ff ff           	jne	0x1000016cd <__text+0x6cd>
1000016ed: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
1000016f4: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
1000016fb: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100001702: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100001709: 48 8b 85 f0 00 00 00        	movq	0xf0(%rbp), %rax
100001710: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100001717: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
10000171e: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
100001725: 4c 89 bd 00 01 00 00        	movq	%r15, 0x100(%rbp)
10000172c: 4c 8b 95 38 00 00 00        	movq	0x38(%rbp), %r10
100001733: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
10000173a: 48 85 c0                    	testq	%rax, %rax
10000173d: 0f 84 89 00 00 00           	je	0x1000017cc <__text+0x7cc>
100001743: 49 89 c3                    	movq	%rax, %r11
100001746: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
10000174d: f0                          	lock
10000174e: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100001753: 0f 85 da ff ff ff           	jne	0x100001733 <__text+0x733>
100001759: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100001760: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100001767: 4c 01 d8                    	addq	%r11, %rax
10000176a: 48 85 c0                    	testq	%rax, %rax
10000176d: 0f 85 59 00 00 00           	jne	0x1000017cc <__text+0x7cc>
100001773: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
10000177a: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100001784: 48 39 c8                    	cmpq	%rcx, %rax
100001787: 0f 84 e6 ff ff ff           	je	0x100001773 <__text+0x773>
10000178d: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100001797: 48 39 c8                    	cmpq	%rcx, %rax
10000179a: 0f 84 2c 00 00 00           	je	0x1000017cc <__text+0x7cc>
1000017a0: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000017aa: f0                          	lock
1000017ab: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000017b0: 0f 85 bd ff ff ff           	jne	0x100001773 <__text+0x773>
1000017b6: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000017bd: 4c 89 d7                    	movq	%r10, %rdi
1000017c0: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
1000017ca: 0f 05                       	syscall
1000017cc: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
1000017d3: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
1000017da: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000017e1: 48 8b 8d 28 01 00 00        	movq	0x128(%rbp), %rcx
1000017e8: 48 01 c8                    	addq	%rcx, %rax
1000017eb: 71 0a                       	jno	0x1000017f7 <__text+0x7f7>
1000017ed: ba 01 00 00 00              	movl	$0x1, %edx
1000017f2: e9 f0 00 00 00              	jmp	0x1000018e7 <__text+0x8e7>
1000017f7: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
1000017fe: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100001805: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
10000180c: e9 5b f9 ff ff              	jmp	0x10000116c <__text+0x16c>
100001811: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100001818: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
10000181f: 4c 8b 95 10 01 00 00        	movq	0x110(%rbp), %r10
100001826: f0                          	lock
100001827: 49 ff 42 08                 	incq	0x8(%r10)
10000182b: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100001832: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100001839: 4c 8b 95 18 01 00 00        	movq	0x118(%rbp), %r10
100001840: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100001847: 48 85 c0                    	testq	%rax, %rax
10000184a: 0f 84 89 00 00 00           	je	0x1000018d9 <__text+0x8d9>
100001850: 49 89 c3                    	movq	%rax, %r11
100001853: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
10000185a: f0                          	lock
10000185b: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100001860: 0f 85 da ff ff ff           	jne	0x100001840 <__text+0x840>
100001866: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
10000186d: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100001874: 4c 01 d8                    	addq	%r11, %rax
100001877: 48 85 c0                    	testq	%rax, %rax
10000187a: 0f 85 59 00 00 00           	jne	0x1000018d9 <__text+0x8d9>
100001880: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100001887: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100001891: 48 39 c8                    	cmpq	%rcx, %rax
100001894: 0f 84 e6 ff ff ff           	je	0x100001880 <__text+0x880>
10000189a: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000018a4: 48 39 c8                    	cmpq	%rcx, %rax
1000018a7: 0f 84 2c 00 00 00           	je	0x1000018d9 <__text+0x8d9>
1000018ad: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000018b7: f0                          	lock
1000018b8: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000018bd: 0f 85 bd ff ff ff           	jne	0x100001880 <__text+0x880>
1000018c3: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000018ca: 4c 89 d7                    	movq	%r10, %rdi
1000018cd: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
1000018d7: 0f 05                       	syscall
1000018d9: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
1000018e0: 31 d2                       	xorl	%edx, %edx
1000018e2: e9 00 00 00 00              	jmp	0x1000018e7 <__text+0x8e7>
1000018e7: 48 89 ec                    	movq	%rbp, %rsp
1000018ea: 48 81 c4 50 01 00 00        	addq	$0x150, %rsp            ## imm = 0x150
1000018f1: 5d                          	popq	%rbp
1000018f2: c3                          	retq
1000018f3: 55                          	pushq	%rbp
1000018f4: 48 89 e5                    	movq	%rsp, %rbp
1000018f7: 48 81 ec a0 04 00 00        	subq	$0x4a0, %rsp            ## imm = 0x4A0
1000018fe: 48 89 e5                    	movq	%rsp, %rbp
100001901: 48 89 b5 10 00 00 00        	movq	%rsi, 0x10(%rbp)
100001908: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
10000190f: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
100001916: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
10000191d: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100001924: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000192e: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001933: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000193d: 49 89 c1                    	movq	%rax, %r9
100001940: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
10000194a: 49 89 c0                    	movq	%rax, %r8
10000194d: 4c 89 c8                    	movq	%r9, %rax
100001950: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
100001957: 48 39 c8                    	cmpq	%rcx, %rax
10000195a: 0f 9c c0                    	setl	%al
10000195d: 48 0f b6 c0                 	movzbq	%al, %rax
100001961: 49 89 c2                    	movq	%rax, %r10
100001964: 4c 89 c8                    	movq	%r9, %rax
100001967: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
10000196e: 4c 89 c0                    	movq	%r8, %rax
100001971: 48 89 85 28 04 00 00        	movq	%rax, 0x428(%rbp)
100001978: 44 0f 28 f6                 	movaps	%xmm6, %xmm14
10000197c: 4c 89 d0                    	movq	%r10, %rax
10000197f: 48 85 c0                    	testq	%rax, %rax
100001982: 0f 84 25 00 00 00           	je	0x1000019ad <__text+0x9ad>
100001988: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001992: 49 89 c0                    	movq	%rax, %r8
100001995: 4c 89 c8                    	movq	%r9, %rax
100001998: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
10000199f: 4c 89 c0                    	movq	%r8, %rax
1000019a2: 48 89 85 28 04 00 00        	movq	%rax, 0x428(%rbp)
1000019a9: 44 0f 28 f6                 	movaps	%xmm6, %xmm14
1000019ad: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
1000019b4: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
1000019bb: 48 39 c8                    	cmpq	%rcx, %rax
1000019be: 0f 84 1d 01 00 00           	je	0x100001ae1 <__text+0xae1>
1000019c4: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
1000019cb: 48 89 c1                    	movq	%rax, %rcx
1000019ce: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
1000019d3: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
1000019d7: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
1000019e1: 66 48 0f 6e e2              	movq	%rdx, %xmm4
1000019e6: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
1000019ea: 0f 82 39 00 00 00           	jb	0x100001a29 <__text+0xa29>
1000019f0: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
1000019fa: 66 48 0f 6e e2              	movq	%rdx, %xmm4
1000019ff: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001a03: 0f 83 20 00 00 00           	jae	0x100001a29 <__text+0xa29>
100001a09: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001a0e: 48 39 c8                    	cmpq	%rcx, %rax
100001a11: 0f 85 12 00 00 00           	jne	0x100001a29 <__text+0xa29>
100001a17: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001a1b: 66 0f 7e d8                 	movd	%xmm3, %eax
100001a1f: 66 4c 0f 6e d8              	movq	%rax, %xmm11
100001a24: e9 3d 00 00 00              	jmp	0x100001a66 <__text+0xa66>
100001a29: 48 8d 35 a8 28 00 00        	leaq	0x28a8(%rip), %rsi      ## 0x1000042d8
100001a30: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001a37: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001a3e: 4c 89 c2                    	movq	%r8, %rdx
100001a41: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001a4b: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100001a55: 0f 05                       	syscall
100001a57: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001a61: e9 de 07 00 00              	jmp	0x100002244 <__text+0x1244>
100001a66: 48 b8 6f 12 83 3a 00 00 00 00       	movabsq	$0x3a83126f, %rax ## imm = 0x3A83126F
100001a70: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001a75: f3 44 0f 59 de              	mulss	%xmm6, %xmm11
100001a7a: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001a81: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100001a88: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100001a8f: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100001a96: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001aa0: 49 89 c1                    	movq	%rax, %r9
100001aa3: 4c 89 c8                    	movq	%r9, %rax
100001aa6: 48 89 85 30 04 00 00        	movq	%rax, 0x430(%rbp)
100001aad: e9 49 00 00 00              	jmp	0x100001afb <__text+0xafb>
100001ab2: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
100001ab9: 48 8b 8d 28 04 00 00        	movq	0x428(%rbp), %rcx
100001ac0: 48 01 c8                    	addq	%rcx, %rax
100001ac3: 71 0a                       	jno	0x100001acf <__text+0xacf>
100001ac5: ba 01 00 00 00              	movl	$0x1, %edx
100001aca: e9 75 07 00 00              	jmp	0x100002244 <__text+0x1244>
100001acf: 49 89 c0                    	movq	%rax, %r8
100001ad2: 4c 89 c0                    	movq	%r8, %rax
100001ad5: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
100001adc: e9 cc fe ff ff              	jmp	0x1000019ad <__text+0x9ad>
100001ae1: 66 4c 0f 7e f0              	movq	%xmm14, %rax
100001ae6: 48 89 85 18 04 00 00        	movq	%rax, 0x418(%rbp)
100001aed: 48 8b 85 18 04 00 00        	movq	0x418(%rbp), %rax
100001af4: 31 d2                       	xorl	%edx, %edx
100001af6: e9 49 07 00 00              	jmp	0x100002244 <__text+0x1244>
100001afb: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100001b02: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100001b09: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100001b10: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
100001b17: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100001b1e: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
100001b25: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001b2c: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
100001b33: 48 39 c8                    	cmpq	%rcx, %rax
100001b36: 0f 8d 76 ff ff ff           	jge	0x100001ab2 <__text+0xab2>
100001b3c: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100001b43: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100001b4a: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100001b51: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100001b58: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100001b5f: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
100001b66: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001b6d: 48 85 c0                    	testq	%rax, %rax
100001b70: 0f 89 03 00 00 00           	jns	0x100001b79 <__text+0xb79>
100001b76: 48 01 c8                    	addq	%rcx, %rax
100001b79: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100001b80: 48 01 c3                    	addq	%rax, %rbx
100001b83: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001b8a: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100001b91: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100001b98: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100001b9f: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100001ba6: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100001bad: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001bb4: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100001bbb: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001bc5: 66 4c 0f 6e e0              	movq	%rax, %xmm12
100001bca: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001bd4: 66 4c 0f 6e e8              	movq	%rax, %xmm13
100001bd9: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001be3: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100001bea: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001bf4: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100001bfb: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c05: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100001c0c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c16: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100001c1d: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c27: 49 89 c0                    	movq	%rax, %r8
100001c2a: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001c31: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100001c38: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100001c3f: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100001c46: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c50: 49 89 c1                    	movq	%rax, %r9
100001c53: 4c 89 c0                    	movq	%r8, %rax
100001c56: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100001c5d: 4c 89 c8                    	movq	%r9, %rax
100001c60: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001c67: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100001c6e: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100001c75: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
100001c7c: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
100001c83: 48 8b 85 f0 00 00 00        	movq	0xf0(%rbp), %rax
100001c8a: 49 89 c3                    	movq	%rax, %r11
100001c8d: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100001c94: 49 89 c2                    	movq	%rax, %r10
100001c97: e9 2c 00 00 00              	jmp	0x100001cc8 <__text+0xcc8>
100001c9c: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001ca6: 49 89 c1                    	movq	%rax, %r9
100001ca9: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001cb0: 4c 89 c9                    	movq	%r9, %rcx
100001cb3: 48 01 c8                    	addq	%rcx, %rax
100001cb6: 49 89 c0                    	movq	%rax, %r8
100001cb9: 4c 89 c0                    	movq	%r8, %rax
100001cbc: 48 89 85 30 04 00 00        	movq	%rax, 0x430(%rbp)
100001cc3: e9 33 fe ff ff              	jmp	0x100001afb <__text+0xafb>
100001cc8: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001ccf: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100001cd6: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001cdd: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100001ce4: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100001ceb: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100001cf2: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001cf9: 48 8b 8d 28 01 00 00        	movq	0x128(%rbp), %rcx
100001d00: 48 39 c8                    	cmpq	%rcx, %rax
100001d03: 0f 8d 22 01 00 00           	jge	0x100001e2b <__text+0xe2b>
100001d09: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001d10: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100001d17: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001d1e: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100001d25: 48 8b 9d 38 01 00 00        	movq	0x138(%rbp), %rbx
100001d2c: 48 8b 8d 40 01 00 00        	movq	0x140(%rbp), %rcx
100001d33: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001d3a: 48 85 c0                    	testq	%rax, %rax
100001d3d: 0f 89 03 00 00 00           	jns	0x100001d46 <__text+0xd46>
100001d43: 48 01 c8                    	addq	%rcx, %rax
100001d46: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100001d4d: 48 01 c3                    	addq	%rax, %rbx
100001d50: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001d57: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100001d5e: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100001d65: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100001d6c: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100001d73: 66 4c 0f 6e f8              	movq	%rax, %xmm15
100001d78: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001d7f: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100001d86: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100001d8d: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001d92: f3 41 0f 58 f3              	addss	%xmm11, %xmm6
100001d97: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001d9e: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001da3: 44 0f 28 c6                 	movaps	%xmm6, %xmm8
100001da7: f3 44 0f 5c c7              	subss	%xmm7, %xmm8
100001dac: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100001db3: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001db8: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001dbf: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001dc4: 44 0f 28 ce                 	movaps	%xmm6, %xmm9
100001dc8: f3 44 0f 5c cf              	subss	%xmm7, %xmm9
100001dcd: 41 0f 28 f0                 	movaps	%xmm8, %xmm6
100001dd1: f3 41 0f 59 f0              	mulss	%xmm8, %xmm6
100001dd6: 45 0f 28 d1                 	movaps	%xmm9, %xmm10
100001dda: f3 45 0f 59 d1              	mulss	%xmm9, %xmm10
100001ddf: 0f 28 fe                    	movaps	%xmm6, %xmm7
100001de2: f3 41 0f 58 fa              	addss	%xmm10, %xmm7
100001de7: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001df1: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001df6: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100001df9: 0f 87 51 00 00 00           	ja	0x100001e50 <__text+0xe50>
100001dff: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001e09: 49 89 c1                    	movq	%rax, %r9
100001e0c: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001e13: 4c 89 c9                    	movq	%r9, %rcx
100001e16: 48 01 c8                    	addq	%rcx, %rax
100001e19: 49 89 c0                    	movq	%rax, %r8
100001e1c: 4c 89 c0                    	movq	%r8, %rax
100001e1f: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001e26: e9 9d fe ff ff              	jmp	0x100001cc8 <__text+0xcc8>
100001e2b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001e35: 49 89 c0                    	movq	%rax, %r8
100001e38: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100001e3f: 4c 89 c1                    	movq	%r8, %rcx
100001e42: 48 39 c8                    	cmpq	%rcx, %rax
100001e45: 0f 8f 3d 02 00 00           	jg	0x100002088 <__text+0x1088>
100001e4b: e9 4c fe ff ff              	jmp	0x100001c9c <__text+0xc9c>
100001e50: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
100001e5a: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001e5f: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100001e62: 0f 8a 97 ff ff ff           	jp	0x100001dff <__text+0xdff>
100001e68: 0f 83 91 ff ff ff           	jae	0x100001dff <__text+0xdff>
100001e6e: 4c 89 d0                    	movq	%r10, %rax
100001e71: 48 89 85 d8 01 00 00        	movq	%rax, 0x1d8(%rbp)
100001e78: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001e7f: 48 89 85 e0 01 00 00        	movq	%rax, 0x1e0(%rbp)
100001e86: 4c 89 d8                    	movq	%r11, %rax
100001e89: 48 89 85 f0 01 00 00        	movq	%rax, 0x1f0(%rbp)
100001e90: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001e97: 48 89 85 f8 01 00 00        	movq	%rax, 0x1f8(%rbp)
100001e9e: f3 0f 10 9d d8 01 00 00     	movss	0x1d8(%rbp), %xmm3
100001ea6: f3 0f 10 ad f0 01 00 00     	movss	0x1f0(%rbp), %xmm5
100001eae: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100001eb1: f3 0f 10 a5 e0 01 00 00     	movss	0x1e0(%rbp), %xmm4
100001eb9: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100001ec1: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100001ec4: 0f 28 c3                    	movaps	%xmm3, %xmm0
100001ec7: 0f 58 c4                    	addps	%xmm4, %xmm0
100001eca: f3 0f 11 85 e8 01 00 00     	movss	%xmm0, 0x1e8(%rbp)
100001ed2: 0f 28 e8                    	movaps	%xmm0, %xmm5
100001ed5: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100001ed9: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
100001ee1: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
100001ee8: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
100001eef: 66 4c 0f 7e f8              	movq	%xmm15, %rax
100001ef4: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
100001efb: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
100001f02: 48 89 85 20 02 00 00        	movq	%rax, 0x220(%rbp)
100001f09: 48 8b 85 60 01 00 00        	movq	0x160(%rbp), %rax
100001f10: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100001f17: f3 0f 10 9d 08 02 00 00     	movss	0x208(%rbp), %xmm3
100001f1f: f3 0f 10 ad 20 02 00 00     	movss	0x220(%rbp), %xmm5
100001f27: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100001f2a: f3 0f 10 a5 10 02 00 00     	movss	0x210(%rbp), %xmm4
100001f32: f3 0f 10 ad 28 02 00 00     	movss	0x228(%rbp), %xmm5
100001f3a: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100001f3d: 0f 28 cb                    	movaps	%xmm3, %xmm1
100001f40: 0f 58 cc                    	addps	%xmm4, %xmm1
100001f43: f3 0f 11 8d 18 02 00 00     	movss	%xmm1, 0x218(%rbp)
100001f4b: 0f 28 e9                    	movaps	%xmm1, %xmm5
100001f4e: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100001f52: f3 0f 11 ad 30 02 00 00     	movss	%xmm5, 0x230(%rbp)
100001f5a: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001f64: 49 89 c1                    	movq	%rax, %r9
100001f67: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100001f6e: 4c 89 c9                    	movq	%r9, %rcx
100001f71: 48 01 c8                    	addq	%rcx, %rax
100001f74: 71 0a                       	jno	0x100001f80 <__text+0xf80>
100001f76: ba 01 00 00 00              	movl	$0x1, %edx
100001f7b: e9 c4 02 00 00              	jmp	0x100002244 <__text+0x1244>
100001f80: 49 89 c0                    	movq	%rax, %r8
100001f83: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
100001f8d: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001f92: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100001f95: 0f 92 c0                    	setb	%al
100001f98: 0f 9b c1                    	setnp	%cl
100001f9b: 20 c8                       	andb	%cl, %al
100001f9d: 48 0f b6 c0                 	movzbq	%al, %rax
100001fa1: 48 89 85 50 02 00 00        	movq	%rax, 0x250(%rbp)
100001fa8: 4c 89 c0                    	movq	%r8, %rax
100001fab: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100001fb2: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
100001fb9: 49 89 c2                    	movq	%rax, %r10
100001fbc: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
100001fc3: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100001fca: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
100001fd1: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
100001fd8: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100001fdf: 49 89 c3                    	movq	%rax, %r11
100001fe2: 48 8b 85 50 02 00 00        	movq	0x250(%rbp), %rax
100001fe9: 48 85 c0                    	testq	%rax, %rax
100001fec: 0f 84 0d fe ff ff           	je	0x100001dff <__text+0xdff>
100001ff2: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100001ffc: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002001: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
10000200b: 66 4c 0f 6e d0              	movq	%rax, %xmm10
100002010: 41 0f 2e fa                 	ucomiss	%xmm10, %xmm7
100002014: 0f 97 c0                    	seta	%al
100002017: 48 0f b6 c0                 	movzbq	%al, %rax
10000201b: 48 89 85 68 02 00 00        	movq	%rax, 0x268(%rbp)
100002022: 48 8b 85 68 02 00 00        	movq	0x268(%rbp), %rax
100002029: 48 85 c0                    	testq	%rax, %rax
10000202c: 0f 84 03 00 00 00           	je	0x100002035 <__text+0x1035>
100002032: 0f 28 f7                    	movaps	%xmm7, %xmm6
100002035: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
10000203a: f3 45 0f 58 e0              	addss	%xmm8, %xmm12
10000203f: f3 44 0f 5e ce              	divss	%xmm6, %xmm9
100002044: f3 45 0f 58 e9              	addss	%xmm9, %xmm13
100002049: 4c 89 c0                    	movq	%r8, %rax
10000204c: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100002053: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
10000205a: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100002061: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
100002068: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
10000206f: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100002076: 49 89 c3                    	movq	%rax, %r11
100002079: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
100002080: 49 89 c2                    	movq	%rax, %r10
100002083: e9 77 fd ff ff              	jmp	0x100001dff <__text+0xdff>
100002088: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
10000208f: 48 89 c1                    	movq	%rax, %rcx
100002092: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100002097: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
10000209b: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
1000020a5: 66 48 0f 6e e2              	movq	%rdx, %xmm4
1000020aa: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
1000020ae: 0f 82 39 00 00 00           	jb	0x1000020ed <__text+0x10ed>
1000020b4: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
1000020be: 66 48 0f 6e e2              	movq	%rdx, %xmm4
1000020c3: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
1000020c7: 0f 83 20 00 00 00           	jae	0x1000020ed <__text+0x10ed>
1000020cd: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
1000020d2: 48 39 c8                    	cmpq	%rcx, %rax
1000020d5: 0f 85 12 00 00 00           	jne	0x1000020ed <__text+0x10ed>
1000020db: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
1000020df: 66 0f 7e d8                 	movd	%xmm3, %eax
1000020e3: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000020e8: e9 3d 00 00 00              	jmp	0x10000212a <__text+0x112a>
1000020ed: 48 8d 35 44 23 00 00        	leaq	0x2344(%rip), %rsi      ## 0x100004438
1000020f4: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000020fb: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100002102: 4c 89 c2                    	movq	%r8, %rdx
100002105: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000210f: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100002119: 0f 05                       	syscall
10000211b: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002125: e9 1a 01 00 00              	jmp	0x100002244 <__text+0x1244>
10000212a: 4c 89 d0                    	movq	%r10, %rax
10000212d: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002132: f3 0f 5e fe                 	divss	%xmm6, %xmm7
100002136: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
10000213d: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002142: f3 41 0f 5c f8              	subss	%xmm8, %xmm7
100002147: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002151: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002156: f3 41 0f 59 f8              	mulss	%xmm8, %xmm7
10000215b: 4c 89 d8                    	movq	%r11, %rax
10000215e: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002163: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
100002168: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
10000216f: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002174: f3 45 0f 5c c1              	subss	%xmm9, %xmm8
100002179: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002183: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002188: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
10000218d: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
100002192: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
100002199: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000219e: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
1000021a3: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
1000021aa: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000021af: f3 45 0f 5c c1              	subss	%xmm9, %xmm8
1000021b4: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
1000021be: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000021c3: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
1000021c8: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
1000021cd: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
1000021d4: 66 4c 0f 6e c0              	movq	%rax, %xmm8
1000021d9: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
1000021de: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
1000021e5: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000021ea: f3 44 0f 5c c6              	subss	%xmm6, %xmm8
1000021ef: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
1000021f9: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000021fe: f3 44 0f 59 c6              	mulss	%xmm6, %xmm8
100002203: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
100002208: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002212: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002217: f3 44 0f 59 e6              	mulss	%xmm6, %xmm12
10000221c: f3 41 0f 58 fc              	addss	%xmm12, %xmm7
100002221: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
10000222b: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002230: f3 44 0f 59 ee              	mulss	%xmm6, %xmm13
100002235: f3 41 0f 58 fd              	addss	%xmm13, %xmm7
10000223a: f3 44 0f 58 f7              	addss	%xmm7, %xmm14
10000223f: e9 58 fa ff ff              	jmp	0x100001c9c <__text+0xc9c>
100002244: 48 89 ec                    	movq	%rbp, %rsp
100002247: 48 81 c4 a0 04 00 00        	addq	$0x4a0, %rsp            ## imm = 0x4A0
10000224e: 5d                          	popq	%rbp
10000224f: c3                          	retq
100002250: 55                          	pushq	%rbp
100002251: 48 89 e5                    	movq	%rsp, %rbp
100002254: 48 81 ec 00 04 00 00        	subq	$0x400, %rsp            ## imm = 0x400
10000225b: 48 89 e5                    	movq	%rsp, %rbp
10000225e: 4c 89 bd 30 00 00 00        	movq	%r15, 0x30(%rbp)
100002265: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
10000226c: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100002273: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
10000227a: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100002281: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
100002288: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
10000228f: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
100002296: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
10000229d: 48 8b 87 10 00 00 00        	movq	0x10(%rdi), %rax
1000022a4: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
1000022ab: 48 8b 87 18 00 00 00        	movq	0x18(%rdi), %rax
1000022b2: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
1000022b9: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
1000022c0: 66 4c 0f 6e d8              	movq	%rax, %xmm11
1000022c5: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
1000022cc: 66 4c 0f 6e e0              	movq	%rax, %xmm12
1000022d1: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
1000022d8: 66 4c 0f 6e e8              	movq	%rax, %xmm13
1000022dd: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
1000022e4: 66 4c 0f 6e f0              	movq	%rax, %xmm14
1000022e9: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000022f3: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
1000022fa: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002304: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
10000230b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002315: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
10000231c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002326: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
10000232d: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002337: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
10000233e: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002348: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
10000234f: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002359: 49 89 c0                    	movq	%rax, %r8
10000235c: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100002363: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
10000236a: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002371: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100002378: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002382: 49 89 c1                    	movq	%rax, %r9
100002385: 4c 89 c0                    	movq	%r8, %rax
100002388: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
10000238f: 4c 89 c8                    	movq	%r9, %rax
100002392: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
100002399: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
1000023a0: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
1000023a7: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
1000023ae: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
1000023b5: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
1000023bc: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
1000023c3: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
1000023ca: 49 89 c3                    	movq	%rax, %r11
1000023cd: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000023d4: 49 89 c2                    	movq	%rax, %r10
1000023d7: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
1000023de: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
1000023e5: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000023ec: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000023f3: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000023fa: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
100002401: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100002408: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
10000240f: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
100002416: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
10000241d: 48 39 c8                    	cmpq	%rcx, %rax
100002420: 0f 8d fd 00 00 00           	jge	0x100002523 <__text+0x1523>
100002426: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
10000242d: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100002434: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
10000243b: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100002442: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100002449: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
100002450: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
100002457: 48 85 c0                    	testq	%rax, %rax
10000245a: 0f 89 03 00 00 00           	jns	0x100002463 <__text+0x1463>
100002460: 48 01 c8                    	addq	%rcx, %rax
100002463: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
10000246a: 48 01 c3                    	addq	%rax, %rbx
10000246d: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002474: 66 4c 0f 6e f8              	movq	%rax, %xmm15
100002479: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002480: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100002487: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
10000248e: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100002495: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
10000249c: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
1000024a3: 41 0f 28 f7                 	movaps	%xmm15, %xmm6
1000024a7: 45 0f 28 c3                 	movaps	%xmm11, %xmm8
1000024ab: f3 44 0f 5c c6              	subss	%xmm6, %xmm8
1000024b0: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
1000024b7: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000024bc: 45 0f 28 cc                 	movaps	%xmm12, %xmm9
1000024c0: f3 44 0f 5c ce              	subss	%xmm6, %xmm9
1000024c5: 41 0f 28 f0                 	movaps	%xmm8, %xmm6
1000024c9: f3 41 0f 59 f0              	mulss	%xmm8, %xmm6
1000024ce: 45 0f 28 d1                 	movaps	%xmm9, %xmm10
1000024d2: f3 45 0f 59 d1              	mulss	%xmm9, %xmm10
1000024d7: 0f 28 fe                    	movaps	%xmm6, %xmm7
1000024da: f3 41 0f 58 fa              	addss	%xmm10, %xmm7
1000024df: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000024e9: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000024ee: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
1000024f1: 0f 87 51 00 00 00           	ja	0x100002548 <__text+0x1548>
1000024f7: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002501: 49 89 c1                    	movq	%rax, %r9
100002504: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
10000250b: 4c 89 c9                    	movq	%r9, %rcx
10000250e: 48 01 c8                    	addq	%rcx, %rax
100002511: 49 89 c0                    	movq	%rax, %r8
100002514: 4c 89 c0                    	movq	%r8, %rax
100002517: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
10000251e: e9 c2 fe ff ff              	jmp	0x1000023e5 <__text+0x13e5>
100002523: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000252d: 49 89 c0                    	movq	%rax, %r8
100002530: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002537: 4c 89 c1                    	movq	%r8, %rcx
10000253a: 48 39 c8                    	cmpq	%rcx, %rax
10000253d: 0f 84 c4 02 00 00           	je	0x100002807 <__text+0x1807>
100002543: e9 31 03 00 00              	jmp	0x100002879 <__text+0x1879>
100002548: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
100002552: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002557: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
10000255a: 0f 8a 97 ff ff ff           	jp	0x1000024f7 <__text+0x14f7>
100002560: 0f 83 91 ff ff ff           	jae	0x1000024f7 <__text+0x14f7>
100002566: 4c 89 d0                    	movq	%r10, %rax
100002569: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
100002570: 66 4c 0f 7e f8              	movq	%xmm15, %rax
100002575: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
10000257c: 4c 89 d8                    	movq	%r11, %rax
10000257f: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100002586: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
10000258d: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100002594: f3 0f 10 9d 30 01 00 00     	movss	0x130(%rbp), %xmm3
10000259c: f3 0f 10 ad 48 01 00 00     	movss	0x148(%rbp), %xmm5
1000025a4: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
1000025a7: f3 0f 10 a5 38 01 00 00     	movss	0x138(%rbp), %xmm4
1000025af: f3 0f 10 ad 50 01 00 00     	movss	0x150(%rbp), %xmm5
1000025b7: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
1000025ba: 0f 28 c3                    	movaps	%xmm3, %xmm0
1000025bd: 0f 58 c4                    	addps	%xmm4, %xmm0
1000025c0: f3 0f 11 85 40 01 00 00     	movss	%xmm0, 0x140(%rbp)
1000025c8: 0f 28 e8                    	movaps	%xmm0, %xmm5
1000025cb: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
1000025cf: f3 0f 11 ad 58 01 00 00     	movss	%xmm5, 0x158(%rbp)
1000025d7: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
1000025de: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
1000025e5: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
1000025ec: 48 89 85 68 01 00 00        	movq	%rax, 0x168(%rbp)
1000025f3: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
1000025fa: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
100002601: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
100002608: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
10000260f: f3 0f 10 9d 60 01 00 00     	movss	0x160(%rbp), %xmm3
100002617: f3 0f 10 ad 78 01 00 00     	movss	0x178(%rbp), %xmm5
10000261f: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002622: f3 0f 10 a5 68 01 00 00     	movss	0x168(%rbp), %xmm4
10000262a: f3 0f 10 ad 80 01 00 00     	movss	0x180(%rbp), %xmm5
100002632: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002635: 0f 28 cb                    	movaps	%xmm3, %xmm1
100002638: 0f 58 cc                    	addps	%xmm4, %xmm1
10000263b: f3 0f 11 8d 70 01 00 00     	movss	%xmm1, 0x170(%rbp)
100002643: 0f 28 e9                    	movaps	%xmm1, %xmm5
100002646: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
10000264a: f3 0f 11 ad 88 01 00 00     	movss	%xmm5, 0x188(%rbp)
100002652: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000265c: 49 89 c1                    	movq	%rax, %r9
10000265f: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002666: 4c 89 c9                    	movq	%r9, %rcx
100002669: 48 01 c8                    	addq	%rcx, %rax
10000266c: 71 0a                       	jno	0x100002678 <__text+0x1678>
10000266e: ba 01 00 00 00              	movl	$0x1, %edx
100002673: e9 fa 03 00 00              	jmp	0x100002a72 <__text+0x1a72>
100002678: 49 89 c0                    	movq	%rax, %r8
10000267b: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
100002685: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000268a: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
10000268d: 0f 92 c0                    	setb	%al
100002690: 0f 9b c1                    	setnp	%cl
100002693: 20 c8                       	andb	%cl, %al
100002695: 48 0f b6 c0                 	movzbq	%al, %rax
100002699: 48 89 85 a8 01 00 00        	movq	%rax, 0x1a8(%rbp)
1000026a0: 4c 89 c0                    	movq	%r8, %rax
1000026a3: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
1000026aa: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
1000026b1: 49 89 c2                    	movq	%rax, %r10
1000026b4: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000026bb: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
1000026c2: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
1000026c9: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
1000026d0: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000026d7: 49 89 c3                    	movq	%rax, %r11
1000026da: 48 8b 85 a8 01 00 00        	movq	0x1a8(%rbp), %rax
1000026e1: 48 85 c0                    	testq	%rax, %rax
1000026e4: 0f 84 0d fe ff ff           	je	0x1000024f7 <__text+0x14f7>
1000026ea: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
1000026f4: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000026f9: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100002703: 66 4c 0f 6e d0              	movq	%rax, %xmm10
100002708: 41 0f 2e fa                 	ucomiss	%xmm10, %xmm7
10000270c: 0f 97 c0                    	seta	%al
10000270f: 48 0f b6 c0                 	movzbq	%al, %rax
100002713: 48 89 85 c0 01 00 00        	movq	%rax, 0x1c0(%rbp)
10000271a: 48 8b 85 c0 01 00 00        	movq	0x1c0(%rbp), %rax
100002721: 48 85 c0                    	testq	%rax, %rax
100002724: 0f 84 03 00 00 00           	je	0x10000272d <__text+0x172d>
10000272a: 0f 28 f7                    	movaps	%xmm7, %xmm6
10000272d: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002734: 48 89 85 c8 01 00 00        	movq	%rax, 0x1c8(%rbp)
10000273b: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
10000273f: f3 0f 5e c6                 	divss	%xmm6, %xmm0
100002743: f3 0f 11 85 d8 01 00 00     	movss	%xmm0, 0x1d8(%rbp)
10000274b: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
100002752: 48 89 85 e8 01 00 00        	movq	%rax, 0x1e8(%rbp)
100002759: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
10000275d: f3 0f 5e c6                 	divss	%xmm6, %xmm0
100002761: f3 0f 11 85 f8 01 00 00     	movss	%xmm0, 0x1f8(%rbp)
100002769: f3 0f 10 9d c8 01 00 00     	movss	0x1c8(%rbp), %xmm3
100002771: f3 0f 10 ad e8 01 00 00     	movss	0x1e8(%rbp), %xmm5
100002779: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
10000277c: f3 0f 10 a5 d8 01 00 00     	movss	0x1d8(%rbp), %xmm4
100002784: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
10000278c: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
10000278f: 0f 28 d3                    	movaps	%xmm3, %xmm2
100002792: 0f 58 d4                    	addps	%xmm4, %xmm2
100002795: f3 0f 11 95 e0 01 00 00     	movss	%xmm2, 0x1e0(%rbp)
10000279d: 0f 28 ea                    	movaps	%xmm2, %xmm5
1000027a0: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
1000027a4: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
1000027ac: 4c 89 c0                    	movq	%r8, %rax
1000027af: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
1000027b6: 48 8b 85 e0 01 00 00        	movq	0x1e0(%rbp), %rax
1000027bd: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
1000027c4: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000027cb: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
1000027d2: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
1000027d9: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
1000027e0: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000027e7: 49 89 c3                    	movq	%rax, %r11
1000027ea: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
1000027f1: 49 89 c2                    	movq	%rax, %r10
1000027f4: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
1000027fb: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
100002802: e9 f0 fc ff ff              	jmp	0x1000024f7 <__text+0x14f7>
100002807: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002811: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100002818: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002822: 48 89 85 30 02 00 00        	movq	%rax, 0x230(%rbp)
100002829: 48 8b 85 28 02 00 00        	movq	0x228(%rbp), %rax
100002830: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
100002837: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
10000283e: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
100002845: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
10000284c: 48 8b 85 38 02 00 00        	movq	0x238(%rbp), %rax
100002853: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
10000285a: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
100002861: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002868: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002872: 31 d2                       	xorl	%edx, %edx
100002874: e9 f9 01 00 00              	jmp	0x100002a72 <__text+0x1a72>
100002879: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002880: 48 89 c1                    	movq	%rax, %rcx
100002883: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100002888: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
10000288c: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100002896: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000289b: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000289f: 0f 82 39 00 00 00           	jb	0x1000028de <__text+0x18de>
1000028a5: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
1000028af: 66 48 0f 6e e2              	movq	%rdx, %xmm4
1000028b4: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
1000028b8: 0f 83 20 00 00 00           	jae	0x1000028de <__text+0x18de>
1000028be: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
1000028c3: 48 39 c8                    	cmpq	%rcx, %rax
1000028c6: 0f 85 12 00 00 00           	jne	0x1000028de <__text+0x18de>
1000028cc: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
1000028d0: 66 0f 7e d8                 	movd	%xmm3, %eax
1000028d4: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000028d9: e9 3d 00 00 00              	jmp	0x10000291b <__text+0x191b>
1000028de: 48 8d 35 43 1c 00 00        	leaq	0x1c43(%rip), %rsi      ## 0x100004528
1000028e5: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000028ec: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000028f3: 4c 89 c2                    	movq	%r8, %rdx
1000028f6: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100002900: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
10000290a: 0f 05                       	syscall
10000290c: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002916: e9 57 01 00 00              	jmp	0x100002a72 <__text+0x1a72>
10000291b: 4c 89 d0                    	movq	%r10, %rax
10000291e: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002923: f3 0f 5e fe                 	divss	%xmm6, %xmm7
100002927: f3 41 0f 5c fb              	subss	%xmm11, %xmm7
10000292c: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002936: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000293b: f3 41 0f 59 f8              	mulss	%xmm8, %xmm7
100002940: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
100002947: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000294c: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
100002951: f3 45 0f 5c c5              	subss	%xmm13, %xmm8
100002956: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002960: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002965: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
10000296a: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
10000296f: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002976: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000297b: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002985: 66 4c 0f 6e c8              	movq	%rax, %xmm9
10000298a: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
10000298f: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002992: f3 41 0f 58 c0              	addss	%xmm8, %xmm0
100002997: f3 0f 11 85 c0 02 00 00     	movss	%xmm0, 0x2c0(%rbp)
10000299f: 4c 89 d8                    	movq	%r11, %rax
1000029a2: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000029a7: f3 0f 5e fe                 	divss	%xmm6, %xmm7
1000029ab: f3 41 0f 5c fc              	subss	%xmm12, %xmm7
1000029b0: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
1000029ba: 66 4c 0f 6e c0              	movq	%rax, %xmm8
1000029bf: f3 41 0f 59 f8              	mulss	%xmm8, %xmm7
1000029c4: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
1000029cb: 66 4c 0f 6e c0              	movq	%rax, %xmm8
1000029d0: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
1000029d5: f3 45 0f 5c c6              	subss	%xmm14, %xmm8
1000029da: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
1000029e4: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000029e9: f3 44 0f 59 c6              	mulss	%xmm6, %xmm8
1000029ee: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
1000029f3: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
1000029fa: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000029ff: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002a09: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002a0e: f3 41 0f 59 f0              	mulss	%xmm8, %xmm6
100002a13: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002a16: f3 0f 58 c6                 	addss	%xmm6, %xmm0
100002a1a: f3 0f 11 85 38 03 00 00     	movss	%xmm0, 0x338(%rbp)
100002a22: 48 8b 85 c0 02 00 00        	movq	0x2c0(%rbp), %rax
100002a29: 48 89 85 40 03 00 00        	movq	%rax, 0x340(%rbp)
100002a30: 48 8b 85 38 03 00 00        	movq	0x338(%rbp), %rax
100002a37: 48 89 85 48 03 00 00        	movq	%rax, 0x348(%rbp)
100002a3e: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002a45: 48 8b 85 40 03 00 00        	movq	0x340(%rbp), %rax
100002a4c: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002a53: 48 8b 85 48 03 00 00        	movq	0x348(%rbp), %rax
100002a5a: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002a61: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002a6b: 31 d2                       	xorl	%edx, %edx
100002a6d: e9 00 00 00 00              	jmp	0x100002a72 <__text+0x1a72>
100002a72: 48 89 ec                    	movq	%rbp, %rsp
100002a75: 48 81 c4 00 04 00 00        	addq	$0x400, %rsp            ## imm = 0x400
100002a7c: 5d                          	popq	%rbp
100002a7d: c3                          	retq
100002a7e: 55                          	pushq	%rbp
100002a7f: 48 89 e5                    	movq	%rsp, %rbp
100002a82: 48 81 ec b0 01 00 00        	subq	$0x1b0, %rsp            ## imm = 0x1B0
100002a89: 48 89 e5                    	movq	%rsp, %rbp
100002a8c: 48 89 95 18 00 00 00        	movq	%rdx, 0x18(%rbp)
100002a93: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
100002a9a: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100002aa1: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
100002aa8: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
100002aaf: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
100002ab6: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002ac0: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002ac5: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002acf: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100002ad6: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002add: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002ae4: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100002aeb: 48 8b 8d 30 00 00 00        	movq	0x30(%rbp), %rcx
100002af2: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002af9: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100002b00: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
100002b0a: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100002b11: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002b18: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100002b1f: 48 39 c8                    	cmpq	%rcx, %rax
100002b22: 0f 9c c0                    	setl	%al
100002b25: 48 0f b6 c0                 	movzbq	%al, %rax
100002b29: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100002b30: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002b37: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100002b3e: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100002b45: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002b4c: 66 48 0f 7e f0              	movq	%xmm6, %rax
100002b51: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002b58: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100002b5f: 48 85 c0                    	testq	%rax, %rax
100002b62: 0f 84 39 00 00 00           	je	0x100002ba1 <__text+0x1ba1>
100002b68: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002b72: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100002b79: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002b80: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100002b87: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
100002b8e: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002b95: 66 48 0f 7e f0              	movq	%xmm6, %rax
100002b9a: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002ba1: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002ba8: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100002baf: 48 39 c8                    	cmpq	%rcx, %rax
100002bb2: 0f 84 8c 05 00 00           	je	0x100003144 <__text+0x2144>
100002bb8: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002bbf: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002bc6: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100002bcd: 48 8b 9d 60 00 00 00        	movq	0x60(%rbp), %rbx
100002bd4: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100002bdb: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100002be2: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002be9: 48 85 c0                    	testq	%rax, %rax
100002bec: 0f 89 03 00 00 00           	jns	0x100002bf5 <__text+0x1bf5>
100002bf2: 48 01 c8                    	addq	%rcx, %rax
100002bf5: 48 39 c8                    	cmpq	%rcx, %rax
100002bf8: 0f 82 0f 00 00 00           	jb	0x100002c0d <__text+0x1c0d>
100002bfe: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002c08: e9 53 05 00 00              	jmp	0x100003160 <__text+0x2160>
100002c0d: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002c14: 48 01 c3                    	addq	%rax, %rbx
100002c17: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002c1e: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100002c25: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002c2c: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100002c33: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002c3a: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100002c41: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100002c48: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100002c4f: 4c 8d bd 88 00 00 00        	leaq	0x88(%rbp), %r15
100002c56: 48 8d bd 68 00 00 00        	leaq	0x68(%rbp), %rdi
100002c5d: 48 8d b5 08 00 00 00        	leaq	0x8(%rbp), %rsi
100002c64: e8 e7 f5 ff ff              	callq	0x100002250 <__text+0x1250>
100002c69: 48 85 d2                    	testq	%rdx, %rdx
100002c6c: 0f 85 ee 04 00 00           	jne	0x100003160 <__text+0x2160>
100002c72: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
100002c79: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002c7e: 48 8b 85 88 00 00 00        	movq	0x88(%rbp), %rax
100002c85: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002c8a: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002c92: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002c96: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002c99: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002c9d: f3 0f 11 85 b0 00 00 00     	movss	%xmm0, 0xb0(%rbp)
100002ca5: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100002cac: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002cb1: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100002cb8: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002cbd: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002cc5: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002cc9: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002ccc: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002cd0: f3 0f 11 85 d0 00 00 00     	movss	%xmm0, 0xd0(%rbp)
100002cd8: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100002cdf: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002ce4: f3 0f 10 85 b0 00 00 00     	movss	0xb0(%rbp), %xmm0
100002cec: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002cf4: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002cf7: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002cfb: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002cfe: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002d02: f3 0f 11 85 e8 00 00 00     	movss	%xmm0, 0xe8(%rbp)
100002d0a: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100002d11: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002d16: f3 0f 10 85 d0 00 00 00     	movss	0xd0(%rbp), %xmm0
100002d1e: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002d26: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002d29: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002d2d: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002d30: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002d34: f3 0f 11 85 00 01 00 00     	movss	%xmm0, 0x100(%rbp)
100002d3c: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002d43: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002d4a: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100002d51: 48 8b 9d 08 01 00 00        	movq	0x108(%rbp), %rbx
100002d58: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100002d5f: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100002d66: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002d6d: 48 85 c0                    	testq	%rax, %rax
100002d70: 0f 89 03 00 00 00           	jns	0x100002d79 <__text+0x1d79>
100002d76: 48 01 c8                    	addq	%rcx, %rax
100002d79: 48 39 c8                    	cmpq	%rcx, %rax
100002d7c: 0f 82 0f 00 00 00           	jb	0x100002d91 <__text+0x1d91>
100002d82: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002d8c: e9 cf 03 00 00              	jmp	0x100003160 <__text+0x2160>
100002d91: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002d98: 48 01 c3                    	addq	%rax, %rbx
100002d9b: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002da2: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100002da9: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002db0: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100002db7: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002dbe: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100002dc5: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100002dcc: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100002dd3: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100002dda: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
100002de1: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100002de8: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100002def: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100002df6: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100002dfd: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
100002e04: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100002e0b: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002e12: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002e19: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100002e20: 48 8b 9d 50 01 00 00        	movq	0x150(%rbp), %rbx
100002e27: 4c 8b a3 00 00 00 00        	movq	(%rbx), %r12
100002e2e: 4c 8b ad 88 01 00 00        	movq	0x188(%rbp), %r13
100002e35: 4d 85 ed                    	testq	%r13, %r13
100002e38: 0f 89 03 00 00 00           	jns	0x100002e41 <__text+0x1e41>
100002e3e: 4d 01 e5                    	addq	%r12, %r13
100002e41: 4d 39 e5                    	cmpq	%r12, %r13
100002e44: 0f 82 0f 00 00 00           	jb	0x100002e59 <__text+0x1e59>
100002e4a: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002e54: e9 07 03 00 00              	jmp	0x100003160 <__text+0x2160>
100002e59: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002e60: 4c 8b 9b 10 00 00 00        	movq	0x10(%rbx), %r11
100002e67: 4c 01 d8                    	addq	%r11, %rax
100002e6a: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100002e74: 48 39 c8                    	cmpq	%rcx, %rax
100002e77: 0f 85 5b 00 00 00           	jne	0x100002ed8 <__text+0x1ed8>
100002e7d: 49 89 de                    	movq	%rbx, %r14
100002e80: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100002e87: 4c 89 e8                    	movq	%r13, %rax
100002e8a: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002e91: 49 01 c6                    	addq	%rax, %r14
100002e94: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100002e9b: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100002ea2: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
100002ea9: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100002eb0: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002eb7: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100002ebe: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100002ec5: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
100002ecc: 48 89 9d 58 01 00 00        	movq	%rbx, 0x158(%rbp)
100002ed3: e9 ed 01 00 00              	jmp	0x1000030c5 <__text+0x20c5>
100002ed8: 4c 89 e6                    	movq	%r12, %rsi
100002edb: 48 b9 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rcx
100002ee5: 48 0f af f1                 	imulq	%rcx, %rsi
100002ee9: 48 81 c6 28 00 00 00        	addq	$0x28, %rsi
100002ef0: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
100002efa: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002f04: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
100002f0e: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
100002f18: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
100002f22: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
100002f2c: 0f 05                       	syscall
100002f2e: 0f 83 0f 00 00 00           	jae	0x100002f43 <__text+0x1f43>
100002f34: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002f3e: e9 1d 02 00 00              	jmp	0x100003160 <__text+0x2160>
100002f43: 49 89 c7                    	movq	%rax, %r15
100002f46: 4d 89 a7 00 00 00 00        	movq	%r12, (%r15)
100002f4d: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002f57: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002f5e: 49 89 87 10 00 00 00        	movq	%rax, 0x10(%r15)
100002f65: 49 89 87 20 00 00 00        	movq	%rax, 0x20(%r15)
100002f6c: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002f76: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002f7d: 49 89 b7 18 00 00 00        	movq	%rsi, 0x18(%r15)
100002f84: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100002f8b: 4d 89 fe                    	movq	%r15, %r14
100002f8e: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100002f95: 4c 89 e6                    	movq	%r12, %rsi
100002f98: 48 b9 04 00 00 00 00 00 00 00       	movabsq	$0x4, %rcx
100002fa2: 48 0f af f1                 	imulq	%rcx, %rsi
100002fa6: 48 85 f6                    	testq	%rsi, %rsi
100002fa9: 0f 84 20 00 00 00           	je	0x100002fcf <__text+0x1fcf>
100002faf: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002fb6: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100002fbd: 48 83 c3 08                 	addq	$0x8, %rbx
100002fc1: 49 83 c6 08                 	addq	$0x8, %r14
100002fc5: 48 83 ee 01                 	subq	$0x1, %rsi
100002fc9: 0f 85 e0 ff ff ff           	jne	0x100002faf <__text+0x1faf>
100002fcf: 4d 89 fe                    	movq	%r15, %r14
100002fd2: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100002fd9: 4c 89 e8                    	movq	%r13, %rax
100002fdc: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002fe3: 49 01 c6                    	addq	%rax, %r14
100002fe6: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100002fed: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100002ff4: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
100002ffb: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100003002: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100003009: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100003010: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100003017: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
10000301e: 4c 89 bd 58 01 00 00        	movq	%r15, 0x158(%rbp)
100003025: 4c 8b 95 50 01 00 00        	movq	0x150(%rbp), %r10
10000302c: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003033: 48 85 c0                    	testq	%rax, %rax
100003036: 0f 84 89 00 00 00           	je	0x1000030c5 <__text+0x20c5>
10000303c: 49 89 c3                    	movq	%rax, %r11
10000303f: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003046: f0                          	lock
100003047: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
10000304c: 0f 85 da ff ff ff           	jne	0x10000302c <__text+0x202c>
100003052: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003059: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003060: 4c 01 d8                    	addq	%r11, %rax
100003063: 48 85 c0                    	testq	%rax, %rax
100003066: 0f 85 59 00 00 00           	jne	0x1000030c5 <__text+0x20c5>
10000306c: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003073: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
10000307d: 48 39 c8                    	cmpq	%rcx, %rax
100003080: 0f 84 e6 ff ff ff           	je	0x10000306c <__text+0x206c>
100003086: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003090: 48 39 c8                    	cmpq	%rcx, %rax
100003093: 0f 84 2c 00 00 00           	je	0x1000030c5 <__text+0x20c5>
100003099: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000030a3: f0                          	lock
1000030a4: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000030a9: 0f 85 bd ff ff ff           	jne	0x10000306c <__text+0x206c>
1000030af: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000030b6: 4c 89 d7                    	movq	%r10, %rdi
1000030b9: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
1000030c3: 0f 05                       	syscall
1000030c5: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
1000030cc: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000030d3: 48 89 81 00 00 00 00        	movq	%rax, (%rcx)
1000030da: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
1000030e1: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000030e6: f3 0f 10 85 e8 00 00 00     	movss	0xe8(%rbp), %xmm0
1000030ee: f3 0f 10 8d 00 01 00 00     	movss	0x100(%rbp), %xmm1
1000030f6: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000030f9: f3 0f 58 f9                 	addss	%xmm1, %xmm7
1000030fd: f3 0f 58 f7                 	addss	%xmm7, %xmm6
100003101: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100003108: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
10000310f: 48 01 c8                    	addq	%rcx, %rax
100003112: 71 0a                       	jno	0x10000311e <__text+0x211e>
100003114: ba 01 00 00 00              	movl	$0x1, %edx
100003119: e9 42 00 00 00              	jmp	0x100003160 <__text+0x2160>
10000311e: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
100003125: 48 8b 85 78 01 00 00        	movq	0x178(%rbp), %rax
10000312c: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100003133: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003138: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
10000313f: e9 5d fa ff ff              	jmp	0x100002ba1 <__text+0x1ba1>
100003144: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
10000314b: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
100003152: 48 8b 85 80 01 00 00        	movq	0x180(%rbp), %rax
100003159: 31 d2                       	xorl	%edx, %edx
10000315b: e9 00 00 00 00              	jmp	0x100003160 <__text+0x2160>
100003160: 48 89 ec                    	movq	%rbp, %rsp
100003163: 48 81 c4 b0 01 00 00        	addq	$0x1b0, %rsp            ## imm = 0x1B0
10000316a: 5d                          	popq	%rbp
10000316b: c3                          	retq
10000316c: 55                          	pushq	%rbp
10000316d: 48 89 e5                    	movq	%rsp, %rbp
100003170: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
100003177: 48 89 e5                    	movq	%rsp, %rbp
10000317a: 48 89 b5 10 00 00 00        	movq	%rsi, 0x10(%rbp)
100003181: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
100003188: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
10000318f: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
100003196: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
10000319d: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000031a7: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000031ac: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000031b6: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
1000031bd: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
1000031c7: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000031ce: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
1000031d5: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
1000031dc: 48 39 c8                    	cmpq	%rcx, %rax
1000031df: 0f 9c c0                    	setl	%al
1000031e2: 48 0f b6 c0                 	movzbq	%al, %rax
1000031e6: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000031ed: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
1000031f4: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
1000031fb: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
100003202: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003209: 66 48 0f 7e f0              	movq	%xmm6, %rax
10000320e: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003215: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
10000321c: 48 85 c0                    	testq	%rax, %rax
10000321f: 0f 84 39 00 00 00           	je	0x10000325e <__text+0x225e>
100003225: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000322f: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003236: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
10000323d: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100003244: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
10000324b: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003252: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003257: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
10000325e: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100003265: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
10000326c: 48 39 c8                    	cmpq	%rcx, %rax
10000326f: 0f 84 93 00 00 00           	je	0x100003308 <__text+0x2308>
100003275: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
10000327c: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100003283: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
10000328a: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100003291: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000329b: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000032a2: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000032a9: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
1000032b0: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000032b7: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000032be: e9 61 00 00 00              	jmp	0x100003324 <__text+0x2324>
1000032c3: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
1000032ca: 48 8b 8d 10 01 00 00        	movq	0x110(%rbp), %rcx
1000032d1: 48 01 c8                    	addq	%rcx, %rax
1000032d4: 71 0a                       	jno	0x1000032e0 <__text+0x22e0>
1000032d6: ba 01 00 00 00              	movl	$0x1, %edx
1000032db: e9 9c 01 00 00              	jmp	0x10000347c <__text+0x247c>
1000032e0: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
1000032e7: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
1000032ee: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
1000032f5: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
1000032fc: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003303: e9 56 ff ff ff              	jmp	0x10000325e <__text+0x225e>
100003308: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
10000330f: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100003316: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
10000331d: 31 d2                       	xorl	%edx, %edx
10000331f: e9 58 01 00 00              	jmp	0x10000347c <__text+0x247c>
100003324: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
10000332b: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100003332: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100003339: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100003340: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100003347: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
10000334e: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003355: 48 8b 8d 70 00 00 00        	movq	0x70(%rbp), %rcx
10000335c: 48 39 c8                    	cmpq	%rcx, %rax
10000335f: 0f 8d 5e ff ff ff           	jge	0x1000032c3 <__text+0x22c3>
100003365: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
10000336c: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100003373: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
10000337a: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100003381: 48 8b 9d 80 00 00 00        	movq	0x80(%rbp), %rbx
100003388: 48 8b 8d 88 00 00 00        	movq	0x88(%rbp), %rcx
10000338f: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003396: 48 85 c0                    	testq	%rax, %rax
100003399: 0f 89 03 00 00 00           	jns	0x1000033a2 <__text+0x23a2>
10000339f: 48 01 c8                    	addq	%rcx, %rax
1000033a2: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000033a9: 48 01 c3                    	addq	%rax, %rbx
1000033ac: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000033b3: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
1000033ba: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
1000033c1: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
1000033c8: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
1000033cf: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
1000033d6: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
1000033dd: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
1000033e4: 4c 8d bd b0 00 00 00        	leaq	0xb0(%rbp), %r15
1000033eb: 48 8d bd 90 00 00 00        	leaq	0x90(%rbp), %rdi
1000033f2: 48 8d b5 00 00 00 00        	leaq	(%rbp), %rsi
1000033f9: e8 52 ee ff ff              	callq	0x100002250 <__text+0x1250>
1000033fe: 48 85 d2                    	testq	%rdx, %rdx
100003401: 0f 85 75 00 00 00           	jne	0x10000347c <__text+0x247c>
100003407: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
10000340e: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003413: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
10000341a: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000341f: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100003426: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000342b: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
100003430: f3 0f 58 f7                 	addss	%xmm7, %xmm6
100003434: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000343e: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003445: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
10000344c: 48 8b 8d f0 00 00 00        	movq	0xf0(%rbp), %rcx
100003453: 48 01 c8                    	addq	%rcx, %rax
100003456: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
10000345d: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100003464: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
10000346b: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003470: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100003477: e9 a8 fe ff ff              	jmp	0x100003324 <__text+0x2324>
10000347c: 48 89 ec                    	movq	%rbp, %rsp
10000347f: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
100003486: 5d                          	popq	%rbp
100003487: c3                          	retq
100003488: 55                          	pushq	%rbp
100003489: 48 89 e5                    	movq	%rsp, %rbp
10000348c: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
100003493: 48 89 e5                    	movq	%rsp, %rbp
100003496: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
1000034a0: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
1000034a7: 48 8b bd 00 00 00 00        	movq	(%rbp), %rdi
1000034ae: e8 4d db ff ff              	callq	0x100001000 <__text>
1000034b3: 48 85 d2                    	testq	%rdx, %rdx
1000034b6: 0f 85 d5 05 00 00           	jne	0x100003a91 <__text+0x2a91>
1000034bc: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
1000034c3: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000034cd: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
1000034d4: 48 8b 8d 08 00 00 00        	movq	0x8(%rbp), %rcx
1000034db: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
1000034e2: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
1000034e9: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
1000034f0: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
1000034f7: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000034fe: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
100003505: 48 85 c0                    	testq	%rax, %rax
100003508: 0f 89 03 00 00 00           	jns	0x100003511 <__text+0x2511>
10000350e: 48 01 c8                    	addq	%rcx, %rax
100003511: 48 85 c0                    	testq	%rax, %rax
100003514: 0f 89 0a 00 00 00           	jns	0x100003524 <__text+0x2524>
10000351a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003524: 48 39 c8                    	cmpq	%rcx, %rax
100003527: 0f 8e 03 00 00 00           	jle	0x100003530 <__text+0x2530>
10000352d: 48 89 c8                    	movq	%rcx, %rax
100003530: 48 8b 95 18 00 00 00        	movq	0x18(%rbp), %rdx
100003537: 48 85 d2                    	testq	%rdx, %rdx
10000353a: 0f 89 03 00 00 00           	jns	0x100003543 <__text+0x2543>
100003540: 48 01 ca                    	addq	%rcx, %rdx
100003543: 48 85 d2                    	testq	%rdx, %rdx
100003546: 0f 89 0a 00 00 00           	jns	0x100003556 <__text+0x2556>
10000354c: 48 ba 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdx
100003556: 48 39 ca                    	cmpq	%rcx, %rdx
100003559: 0f 8e 03 00 00 00           	jle	0x100003562 <__text+0x2562>
10000355f: 48 89 ca                    	movq	%rcx, %rdx
100003562: 49 bb 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r11
10000356c: 48 39 d0                    	cmpq	%rdx, %rax
10000356f: 0f 8d 06 00 00 00           	jge	0x10000357b <__text+0x257b>
100003575: 49 89 d3                    	movq	%rdx, %r11
100003578: 49 29 c3                    	subq	%rax, %r11
10000357b: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003582: 48 01 c3                    	addq	%rax, %rbx
100003585: 48 89 9d 20 00 00 00        	movq	%rbx, 0x20(%rbp)
10000358c: 4c 89 9d 28 00 00 00        	movq	%r11, 0x28(%rbp)
100003593: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
10000359d: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
1000035a4: 48 8b bd 30 00 00 00        	movq	0x30(%rbp), %rdi
1000035ab: e8 50 da ff ff              	callq	0x100001000 <__text>
1000035b0: 48 85 d2                    	testq	%rdx, %rdx
1000035b3: 0f 85 d8 04 00 00           	jne	0x100003a91 <__text+0x2a91>
1000035b9: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000035c0: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000035c7: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000035ce: 48 b8 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rax
1000035d8: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000035df: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
1000035e6: 48 8b b5 40 00 00 00        	movq	0x40(%rbp), %rsi
1000035ed: e8 01 e3 ff ff              	callq	0x1000018f3 <__text+0x8f3>
1000035f2: 48 85 d2                    	testq	%rdx, %rdx
1000035f5: 0f 85 96 04 00 00           	jne	0x100003a91 <__text+0x2a91>
1000035fb: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003602: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000360c: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003611: f3 0f 10 85 48 00 00 00     	movss	0x48(%rbp), %xmm0
100003619: 0f 2e c6                    	ucomiss	%xmm6, %xmm0
10000361c: 0f 97 c0                    	seta	%al
10000361f: 48 0f b6 c0                 	movzbq	%al, %rax
100003623: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
10000362a: 48 b8 00 01 00 00 00 00 00 00       	movabsq	$0x100, %rax    ## imm = 0x100
100003634: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
10000363b: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
100003642: 48 8b b5 60 00 00 00        	movq	0x60(%rbp), %rsi
100003649: e8 1e fb ff ff              	callq	0x10000316c <__text+0x216c>
10000364e: 48 85 d2                    	testq	%rdx, %rdx
100003651: 0f 85 3a 04 00 00           	jne	0x100003a91 <__text+0x2a91>
100003657: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
10000365e: f3 0f 10 85 68 00 00 00     	movss	0x68(%rbp), %xmm0
100003666: f3 0f 10 8d 68 00 00 00     	movss	0x68(%rbp), %xmm1
10000366e: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003671: 0f 94 c0                    	sete	%al
100003674: 0f 9b c1                    	setnp	%cl
100003677: 20 c8                       	andb	%cl, %al
100003679: 48 0f b6 c0                 	movzbq	%al, %rax
10000367d: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100003684: 48 b8 89 88 08 3c 00 00 00 00       	movabsq	$0x3c088889, %rax ## imm = 0x3C088889
10000368e: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100003695: 48 8d 85 28 01 00 00        	leaq	0x128(%rbp), %rax
10000369c: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
1000036a3: 48 8b bd 80 00 00 00        	movq	0x80(%rbp), %rdi
1000036aa: 48 8d b5 20 00 00 00        	leaq	0x20(%rbp), %rsi
1000036b1: 48 8b 95 78 00 00 00        	movq	0x78(%rbp), %rdx
1000036b8: e8 c1 f3 ff ff              	callq	0x100002a7e <__text+0x1a7e>
1000036bd: 48 85 d2                    	testq	%rdx, %rdx
1000036c0: 0f 85 cb 03 00 00           	jne	0x100003a91 <__text+0x2a91>
1000036c6: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000036cd: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000036d7: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000036dc: f3 0f 10 85 88 00 00 00     	movss	0x88(%rbp), %xmm0
1000036e4: 0f 2e c6                    	ucomiss	%xmm6, %xmm0
1000036e7: 0f 86 59 01 00 00           	jbe	0x100003846 <__text+0x2846>
1000036ed: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
1000036f4: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
1000036fb: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003705: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
10000370c: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100003713: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
10000371a: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003721: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100003728: 48 85 c0                    	testq	%rax, %rax
10000372b: 0f 89 03 00 00 00           	jns	0x100003734 <__text+0x2734>
100003731: 48 01 c8                    	addq	%rcx, %rax
100003734: 48 39 c8                    	cmpq	%rcx, %rax
100003737: 0f 82 0f 00 00 00           	jb	0x10000374c <__text+0x274c>
10000373d: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003747: e9 45 03 00 00              	jmp	0x100003a91 <__text+0x2a91>
10000374c: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003753: 48 01 c3                    	addq	%rax, %rbx
100003756: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000375d: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003762: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003769: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100003770: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003777: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
10000377e: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003785: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
10000378c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003796: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
10000379d: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
1000037a4: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
1000037ab: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000037b2: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
1000037b9: 48 85 c0                    	testq	%rax, %rax
1000037bc: 0f 89 03 00 00 00           	jns	0x1000037c5 <__text+0x27c5>
1000037c2: 48 01 c8                    	addq	%rcx, %rax
1000037c5: 48 39 c8                    	cmpq	%rcx, %rax
1000037c8: 0f 82 0f 00 00 00           	jb	0x1000037dd <__text+0x27dd>
1000037ce: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000037d8: e9 b4 02 00 00              	jmp	0x100003a91 <__text+0x2a91>
1000037dd: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000037e4: 48 01 c3                    	addq	%rax, %rbx
1000037e7: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000037ee: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000037f3: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
1000037fa: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003801: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003808: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
10000380f: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003816: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
10000381d: 0f 2e f7                    	ucomiss	%xmm7, %xmm6
100003820: 0f 95 c0                    	setne	%al
100003823: 0f 9a c1                    	setp	%cl
100003826: 08 c8                       	orb	%cl, %al
100003828: 48 0f b6 c0                 	movzbq	%al, %rax
10000382c: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003833: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
10000383a: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003841: e9 11 00 00 00              	jmp	0x100003857 <__text+0x2857>
100003846: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003850: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003857: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
10000385e: 48 85 c0                    	testq	%rax, %rax
100003861: 0f 84 23 00 00 00           	je	0x10000388a <__text+0x288a>
100003867: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
10000386e: 48 85 c0                    	testq	%rax, %rax
100003871: 0f 84 13 00 00 00           	je	0x10000388a <__text+0x288a>
100003877: 48 8b 85 a0 00 00 00        	movq	0xa0(%rbp), %rax
10000387e: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003885: e9 11 00 00 00              	jmp	0x10000389b <__text+0x289b>
10000388a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003894: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
10000389b: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
1000038a2: 48 85 c0                    	testq	%rax, %rax
1000038a5: 0f 84 33 00 00 00           	je	0x1000038de <__text+0x28de>
1000038ab: 48 8d 35 5e 07 00 00        	leaq	0x75e(%rip), %rsi       ## 0x100004010
1000038b2: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000038b9: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000038c0: 4c 89 c2                    	movq	%r8, %rdx
1000038c3: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000038cd: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000038d7: 0f 05                       	syscall
1000038d9: e9 2e 00 00 00              	jmp	0x10000390c <__text+0x290c>
1000038de: 48 8d 35 3b 07 00 00        	leaq	0x73b(%rip), %rsi       ## 0x100004020
1000038e5: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000038ec: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000038f3: 4c 89 c2                    	movq	%r8, %rdx
1000038f6: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003900: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
10000390a: 0f 05                       	syscall
10000390c: 48 8d 35 ed 06 00 00        	leaq	0x6ed(%rip), %rsi       ## 0x100004000
100003913: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000391a: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003921: 4c 89 c2                    	movq	%r8, %rdx
100003924: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000392e: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003938: 0f 05                       	syscall
10000393a: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003941: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003948: 4c 8b 95 20 01 00 00        	movq	0x120(%rbp), %r10
10000394f: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003956: 48 85 c0                    	testq	%rax, %rax
100003959: 0f 84 89 00 00 00           	je	0x1000039e8 <__text+0x29e8>
10000395f: 49 89 c3                    	movq	%rax, %r11
100003962: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003969: f0                          	lock
10000396a: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
10000396f: 0f 85 da ff ff ff           	jne	0x10000394f <__text+0x294f>
100003975: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
10000397c: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003983: 4c 01 d8                    	addq	%r11, %rax
100003986: 48 85 c0                    	testq	%rax, %rax
100003989: 0f 85 59 00 00 00           	jne	0x1000039e8 <__text+0x29e8>
10000398f: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003996: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
1000039a0: 48 39 c8                    	cmpq	%rcx, %rax
1000039a3: 0f 84 e6 ff ff ff           	je	0x10000398f <__text+0x298f>
1000039a9: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000039b3: 48 39 c8                    	cmpq	%rcx, %rax
1000039b6: 0f 84 2c 00 00 00           	je	0x1000039e8 <__text+0x29e8>
1000039bc: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000039c6: f0                          	lock
1000039c7: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000039cc: 0f 85 bd ff ff ff           	jne	0x10000398f <__text+0x298f>
1000039d2: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000039d9: 4c 89 d7                    	movq	%r10, %rdi
1000039dc: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
1000039e6: 0f 05                       	syscall
1000039e8: 4c 8b 95 08 00 00 00        	movq	0x8(%rbp), %r10
1000039ef: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
1000039f6: 48 85 c0                    	testq	%rax, %rax
1000039f9: 0f 84 89 00 00 00           	je	0x100003a88 <__text+0x2a88>
1000039ff: 49 89 c3                    	movq	%rax, %r11
100003a02: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003a09: f0                          	lock
100003a0a: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003a0f: 0f 85 da ff ff ff           	jne	0x1000039ef <__text+0x29ef>
100003a15: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003a1c: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003a23: 4c 01 d8                    	addq	%r11, %rax
100003a26: 48 85 c0                    	testq	%rax, %rax
100003a29: 0f 85 59 00 00 00           	jne	0x100003a88 <__text+0x2a88>
100003a2f: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003a36: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003a40: 48 39 c8                    	cmpq	%rcx, %rax
100003a43: 0f 84 e6 ff ff ff           	je	0x100003a2f <__text+0x2a2f>
100003a49: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003a53: 48 39 c8                    	cmpq	%rcx, %rax
100003a56: 0f 84 2c 00 00 00           	je	0x100003a88 <__text+0x2a88>
100003a5c: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100003a66: f0                          	lock
100003a67: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003a6c: 0f 85 bd ff ff ff           	jne	0x100003a2f <__text+0x2a2f>
100003a72: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100003a79: 4c 89 d7                    	movq	%r10, %rdi
100003a7c: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100003a86: 0f 05                       	syscall
100003a88: 31 c0                       	xorl	%eax, %eax
100003a8a: 31 d2                       	xorl	%edx, %edx
100003a8c: e9 00 00 00 00              	jmp	0x100003a91 <__text+0x2a91>
100003a91: 48 89 ec                    	movq	%rbp, %rsp
100003a94: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
100003a9b: 5d                          	popq	%rbp
100003a9c: c3                          	retq
100003a9d: 53                          	pushq	%rbx
100003a9e: 41 54                       	pushq	%r12
100003aa0: 41 55                       	pushq	%r13
100003aa2: 41 56                       	pushq	%r14
100003aa4: 41 57                       	pushq	%r15
100003aa6: e8 dd f9 ff ff              	callq	0x100003488 <__text+0x2488>
100003aab: 48 85 d2                    	testq	%rdx, %rdx
100003aae: 0f 95 c2                    	setne	%dl
100003ab1: 0f b6 d2                    	movzbl	%dl, %edx
100003ab4: 48 89 d0                    	movq	%rdx, %rax
100003ab7: 41 5f                       	popq	%r15
100003ab9: 41 5e                       	popq	%r14
100003abb: 41 5d                       	popq	%r13
100003abd: 41 5c                       	popq	%r12
100003abf: 5b                          	popq	%rbx
100003ac0: c3                          	retq
		...
100003ffd: 00 00                       	addb	%al, (%rax)
100003fff: 00                          	<unknown>
