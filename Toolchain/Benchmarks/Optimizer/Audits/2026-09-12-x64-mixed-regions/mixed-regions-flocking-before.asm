
/private/tmp/silex-part03-evidence/gpr-exhaustive-flocking-macos-x64:	file format mach-o 64-bit x86-64

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
10000193d: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100001944: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
10000194e: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100001955: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
10000195c: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
100001963: 48 39 c8                    	cmpq	%rcx, %rax
100001966: 0f 9c c0                    	setl	%al
100001969: 48 0f b6 c0                 	movzbq	%al, %rax
10000196d: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100001974: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
10000197b: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
100001982: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100001989: 48 89 85 28 04 00 00        	movq	%rax, 0x428(%rbp)
100001990: 44 0f 28 f6                 	movaps	%xmm6, %xmm14
100001994: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
10000199b: 48 85 c0                    	testq	%rax, %rax
10000199e: 0f 84 31 00 00 00           	je	0x1000019d5 <__text+0x9d5>
1000019a4: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000019ae: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000019b5: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000019bc: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
1000019c3: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000019ca: 48 89 85 28 04 00 00        	movq	%rax, 0x428(%rbp)
1000019d1: 44 0f 28 f6                 	movaps	%xmm6, %xmm14
1000019d5: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
1000019dc: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
1000019e3: 48 39 c8                    	cmpq	%rcx, %rax
1000019e6: 0f 84 2d 01 00 00           	je	0x100001b19 <__text+0xb19>
1000019ec: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
1000019f3: 48 89 c1                    	movq	%rax, %rcx
1000019f6: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
1000019fb: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
1000019ff: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100001a09: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001a0e: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001a12: 0f 82 39 00 00 00           	jb	0x100001a51 <__text+0xa51>
100001a18: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100001a22: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100001a27: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100001a2b: 0f 83 20 00 00 00           	jae	0x100001a51 <__text+0xa51>
100001a31: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100001a36: 48 39 c8                    	cmpq	%rcx, %rax
100001a39: 0f 85 12 00 00 00           	jne	0x100001a51 <__text+0xa51>
100001a3f: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100001a43: 66 0f 7e d8                 	movd	%xmm3, %eax
100001a47: 66 4c 0f 6e d8              	movq	%rax, %xmm11
100001a4c: e9 3d 00 00 00              	jmp	0x100001a8e <__text+0xa8e>
100001a51: 48 8d 35 80 28 00 00        	leaq	0x2880(%rip), %rsi      ## 0x1000042d8
100001a58: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001a5f: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001a66: 4c 89 c2                    	movq	%r8, %rdx
100001a69: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001a73: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100001a7d: 0f 05                       	syscall
100001a7f: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001a89: e9 62 08 00 00              	jmp	0x1000022f0 <__text+0x12f0>
100001a8e: 48 b8 6f 12 83 3a 00 00 00 00       	movabsq	$0x3a83126f, %rax ## imm = 0x3A83126F
100001a98: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001a9d: f3 44 0f 59 de              	mulss	%xmm6, %xmm11
100001aa2: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001aa9: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100001ab0: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100001ab7: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100001abe: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001ac8: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100001acf: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100001ad6: 48 89 85 30 04 00 00        	movq	%rax, 0x430(%rbp)
100001add: e9 51 00 00 00              	jmp	0x100001b33 <__text+0xb33>
100001ae2: 48 8b 85 20 04 00 00        	movq	0x420(%rbp), %rax
100001ae9: 48 8b 8d 28 04 00 00        	movq	0x428(%rbp), %rcx
100001af0: 48 01 c8                    	addq	%rcx, %rax
100001af3: 71 0a                       	jno	0x100001aff <__text+0xaff>
100001af5: ba 01 00 00 00              	movl	$0x1, %edx
100001afa: e9 f1 07 00 00              	jmp	0x1000022f0 <__text+0x12f0>
100001aff: 48 89 85 10 04 00 00        	movq	%rax, 0x410(%rbp)
100001b06: 48 8b 85 10 04 00 00        	movq	0x410(%rbp), %rax
100001b0d: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
100001b14: e9 bc fe ff ff              	jmp	0x1000019d5 <__text+0x9d5>
100001b19: 66 4c 0f 7e f0              	movq	%xmm14, %rax
100001b1e: 48 89 85 18 04 00 00        	movq	%rax, 0x418(%rbp)
100001b25: 48 8b 85 18 04 00 00        	movq	0x418(%rbp), %rax
100001b2c: 31 d2                       	xorl	%edx, %edx
100001b2e: e9 bd 07 00 00              	jmp	0x1000022f0 <__text+0x12f0>
100001b33: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100001b3a: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100001b41: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100001b48: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
100001b4f: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100001b56: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
100001b5d: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001b64: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
100001b6b: 48 39 c8                    	cmpq	%rcx, %rax
100001b6e: 0f 8d 6e ff ff ff           	jge	0x100001ae2 <__text+0xae2>
100001b74: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100001b7b: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100001b82: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100001b89: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100001b90: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100001b97: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
100001b9e: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001ba5: 48 85 c0                    	testq	%rax, %rax
100001ba8: 0f 89 03 00 00 00           	jns	0x100001bb1 <__text+0xbb1>
100001bae: 48 01 c8                    	addq	%rcx, %rax
100001bb1: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100001bb8: 48 01 c3                    	addq	%rax, %rbx
100001bbb: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001bc2: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100001bc9: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100001bd0: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100001bd7: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100001bde: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100001be5: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001bec: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100001bf3: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001bfd: 66 4c 0f 6e e0              	movq	%rax, %xmm12
100001c02: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c0c: 66 4c 0f 6e e8              	movq	%rax, %xmm13
100001c11: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c1b: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100001c22: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c2c: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100001c33: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c3d: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100001c44: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c4e: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100001c55: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c5f: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100001c66: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001c6d: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100001c74: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100001c7b: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100001c82: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c8c: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100001c93: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100001c9a: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100001ca1: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
100001ca8: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001caf: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100001cb6: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100001cbd: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
100001cc4: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
100001ccb: 48 8b 85 f0 00 00 00        	movq	0xf0(%rbp), %rax
100001cd2: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
100001cd9: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100001ce0: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
100001ce7: e9 3c 00 00 00              	jmp	0x100001d28 <__text+0xd28>
100001cec: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001cf6: 48 89 85 08 04 00 00        	movq	%rax, 0x408(%rbp)
100001cfd: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001d04: 48 8b 8d 08 04 00 00        	movq	0x408(%rbp), %rcx
100001d0b: 48 01 c8                    	addq	%rcx, %rax
100001d0e: 48 89 85 00 04 00 00        	movq	%rax, 0x400(%rbp)
100001d15: 48 8b 85 00 04 00 00        	movq	0x400(%rbp), %rax
100001d1c: 48 89 85 30 04 00 00        	movq	%rax, 0x430(%rbp)
100001d23: e9 0b fe ff ff              	jmp	0x100001b33 <__text+0xb33>
100001d28: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001d2f: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100001d36: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001d3d: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100001d44: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100001d4b: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100001d52: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001d59: 48 8b 8d 28 01 00 00        	movq	0x128(%rbp), %rcx
100001d60: 48 39 c8                    	cmpq	%rcx, %rax
100001d63: 0f 8d 32 01 00 00           	jge	0x100001e9b <__text+0xe9b>
100001d69: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001d70: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100001d77: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001d7e: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100001d85: 48 8b 9d 38 01 00 00        	movq	0x138(%rbp), %rbx
100001d8c: 48 8b 8d 40 01 00 00        	movq	0x140(%rbp), %rcx
100001d93: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001d9a: 48 85 c0                    	testq	%rax, %rax
100001d9d: 0f 89 03 00 00 00           	jns	0x100001da6 <__text+0xda6>
100001da3: 48 01 c8                    	addq	%rcx, %rax
100001da6: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100001dad: 48 01 c3                    	addq	%rax, %rbx
100001db0: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001db7: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100001dbe: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100001dc5: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100001dcc: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100001dd3: 66 4c 0f 6e f8              	movq	%rax, %xmm15
100001dd8: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001ddf: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100001de6: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100001ded: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001df2: f3 41 0f 58 f3              	addss	%xmm11, %xmm6
100001df7: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001dfe: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001e03: 44 0f 28 c6                 	movaps	%xmm6, %xmm8
100001e07: f3 44 0f 5c c7              	subss	%xmm7, %xmm8
100001e0c: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100001e13: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001e18: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001e1f: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001e24: 44 0f 28 ce                 	movaps	%xmm6, %xmm9
100001e28: f3 44 0f 5c cf              	subss	%xmm7, %xmm9
100001e2d: 41 0f 28 f0                 	movaps	%xmm8, %xmm6
100001e31: f3 41 0f 59 f0              	mulss	%xmm8, %xmm6
100001e36: 45 0f 28 d1                 	movaps	%xmm9, %xmm10
100001e3a: f3 45 0f 59 d1              	mulss	%xmm9, %xmm10
100001e3f: 0f 28 fe                    	movaps	%xmm6, %xmm7
100001e42: f3 41 0f 58 fa              	addss	%xmm10, %xmm7
100001e47: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001e51: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001e56: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100001e59: 0f 87 69 00 00 00           	ja	0x100001ec8 <__text+0xec8>
100001e5f: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001e69: 48 89 85 b8 02 00 00        	movq	%rax, 0x2b8(%rbp)
100001e70: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001e77: 48 8b 8d b8 02 00 00        	movq	0x2b8(%rbp), %rcx
100001e7e: 48 01 c8                    	addq	%rcx, %rax
100001e81: 48 89 85 b0 02 00 00        	movq	%rax, 0x2b0(%rbp)
100001e88: 48 8b 85 b0 02 00 00        	movq	0x2b0(%rbp), %rax
100001e8f: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001e96: e9 8d fe ff ff              	jmp	0x100001d28 <__text+0xd28>
100001e9b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001ea5: 48 89 85 c0 02 00 00        	movq	%rax, 0x2c0(%rbp)
100001eac: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100001eb3: 48 8b 8d c0 02 00 00        	movq	0x2c0(%rbp), %rcx
100001eba: 48 39 c8                    	cmpq	%rcx, %rax
100001ebd: 0f 8f 69 02 00 00           	jg	0x10000212c <__text+0x112c>
100001ec3: e9 24 fe ff ff              	jmp	0x100001cec <__text+0xcec>
100001ec8: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
100001ed2: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001ed7: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100001eda: 0f 8a 7f ff ff ff           	jp	0x100001e5f <__text+0xe5f>
100001ee0: 0f 83 79 ff ff ff           	jae	0x100001e5f <__text+0xe5f>
100001ee6: 48 8b 85 68 04 00 00        	movq	0x468(%rbp), %rax
100001eed: 48 89 85 d8 01 00 00        	movq	%rax, 0x1d8(%rbp)
100001ef4: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001efb: 48 89 85 e0 01 00 00        	movq	%rax, 0x1e0(%rbp)
100001f02: 48 8b 85 70 04 00 00        	movq	0x470(%rbp), %rax
100001f09: 48 89 85 f0 01 00 00        	movq	%rax, 0x1f0(%rbp)
100001f10: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001f17: 48 89 85 f8 01 00 00        	movq	%rax, 0x1f8(%rbp)
100001f1e: f3 0f 10 9d d8 01 00 00     	movss	0x1d8(%rbp), %xmm3
100001f26: f3 0f 10 ad f0 01 00 00     	movss	0x1f0(%rbp), %xmm5
100001f2e: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100001f31: f3 0f 10 a5 e0 01 00 00     	movss	0x1e0(%rbp), %xmm4
100001f39: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100001f41: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100001f44: 0f 28 c3                    	movaps	%xmm3, %xmm0
100001f47: 0f 58 c4                    	addps	%xmm4, %xmm0
100001f4a: f3 0f 11 85 e8 01 00 00     	movss	%xmm0, 0x1e8(%rbp)
100001f52: 0f 28 e8                    	movaps	%xmm0, %xmm5
100001f55: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100001f59: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
100001f61: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
100001f68: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
100001f6f: 66 4c 0f 7e f8              	movq	%xmm15, %rax
100001f74: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
100001f7b: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
100001f82: 48 89 85 20 02 00 00        	movq	%rax, 0x220(%rbp)
100001f89: 48 8b 85 60 01 00 00        	movq	0x160(%rbp), %rax
100001f90: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100001f97: f3 0f 10 9d 08 02 00 00     	movss	0x208(%rbp), %xmm3
100001f9f: f3 0f 10 ad 20 02 00 00     	movss	0x220(%rbp), %xmm5
100001fa7: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100001faa: f3 0f 10 a5 10 02 00 00     	movss	0x210(%rbp), %xmm4
100001fb2: f3 0f 10 ad 28 02 00 00     	movss	0x228(%rbp), %xmm5
100001fba: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100001fbd: 0f 28 cb                    	movaps	%xmm3, %xmm1
100001fc0: 0f 58 cc                    	addps	%xmm4, %xmm1
100001fc3: f3 0f 11 8d 18 02 00 00     	movss	%xmm1, 0x218(%rbp)
100001fcb: 0f 28 e9                    	movaps	%xmm1, %xmm5
100001fce: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100001fd2: f3 0f 11 ad 30 02 00 00     	movss	%xmm5, 0x230(%rbp)
100001fda: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001fe4: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
100001feb: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100001ff2: 48 8b 8d 38 02 00 00        	movq	0x238(%rbp), %rcx
100001ff9: 48 01 c8                    	addq	%rcx, %rax
100001ffc: 71 0a                       	jno	0x100002008 <__text+0x1008>
100001ffe: ba 01 00 00 00              	movl	$0x1, %edx
100002003: e9 e8 02 00 00              	jmp	0x1000022f0 <__text+0x12f0>
100002008: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
10000200f: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
100002019: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000201e: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100002021: 0f 92 c0                    	setb	%al
100002024: 0f 9b c1                    	setnp	%cl
100002027: 20 c8                       	andb	%cl, %al
100002029: 48 0f b6 c0                 	movzbq	%al, %rax
10000202d: 48 89 85 50 02 00 00        	movq	%rax, 0x250(%rbp)
100002034: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
10000203b: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100002042: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
100002049: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
100002050: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
100002057: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
10000205e: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
100002065: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
10000206c: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100002073: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
10000207a: 48 8b 85 50 02 00 00        	movq	0x250(%rbp), %rax
100002081: 48 85 c0                    	testq	%rax, %rax
100002084: 0f 84 d5 fd ff ff           	je	0x100001e5f <__text+0xe5f>
10000208a: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100002094: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002099: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
1000020a3: 66 4c 0f 6e d0              	movq	%rax, %xmm10
1000020a8: 41 0f 2e fa                 	ucomiss	%xmm10, %xmm7
1000020ac: 0f 97 c0                    	seta	%al
1000020af: 48 0f b6 c0                 	movzbq	%al, %rax
1000020b3: 48 89 85 68 02 00 00        	movq	%rax, 0x268(%rbp)
1000020ba: 48 8b 85 68 02 00 00        	movq	0x268(%rbp), %rax
1000020c1: 48 85 c0                    	testq	%rax, %rax
1000020c4: 0f 84 03 00 00 00           	je	0x1000020cd <__text+0x10cd>
1000020ca: 0f 28 f7                    	movaps	%xmm7, %xmm6
1000020cd: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
1000020d2: f3 45 0f 58 e0              	addss	%xmm8, %xmm12
1000020d7: f3 44 0f 5e ce              	divss	%xmm6, %xmm9
1000020dc: f3 45 0f 58 e9              	addss	%xmm9, %xmm13
1000020e1: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
1000020e8: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
1000020ef: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
1000020f6: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
1000020fd: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
100002104: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
10000210b: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100002112: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
100002119: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
100002120: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
100002127: e9 33 fd ff ff              	jmp	0x100001e5f <__text+0xe5f>
10000212c: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100002133: 48 89 c1                    	movq	%rax, %rcx
100002136: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
10000213b: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
10000213f: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100002149: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000214e: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002152: 0f 82 39 00 00 00           	jb	0x100002191 <__text+0x1191>
100002158: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100002162: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002167: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000216b: 0f 83 20 00 00 00           	jae	0x100002191 <__text+0x1191>
100002171: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
100002176: 48 39 c8                    	cmpq	%rcx, %rax
100002179: 0f 85 12 00 00 00           	jne	0x100002191 <__text+0x1191>
10000217f: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100002183: 66 0f 7e d8                 	movd	%xmm3, %eax
100002187: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000218c: e9 3d 00 00 00              	jmp	0x1000021ce <__text+0x11ce>
100002191: 48 8d 35 a0 22 00 00        	leaq	0x22a0(%rip), %rsi      ## 0x100004438
100002198: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000219f: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000021a6: 4c 89 c2                    	movq	%r8, %rdx
1000021a9: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000021b3: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
1000021bd: 0f 05                       	syscall
1000021bf: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000021c9: e9 22 01 00 00              	jmp	0x1000022f0 <__text+0x12f0>
1000021ce: 48 8b 85 68 04 00 00        	movq	0x468(%rbp), %rax
1000021d5: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000021da: f3 0f 5e fe                 	divss	%xmm6, %xmm7
1000021de: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
1000021e5: 66 4c 0f 6e c0              	movq	%rax, %xmm8
1000021ea: f3 41 0f 5c f8              	subss	%xmm8, %xmm7
1000021ef: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
1000021f9: 66 4c 0f 6e c0              	movq	%rax, %xmm8
1000021fe: f3 41 0f 59 f8              	mulss	%xmm8, %xmm7
100002203: 48 8b 85 70 04 00 00        	movq	0x470(%rbp), %rax
10000220a: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000220f: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
100002214: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
10000221b: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002220: f3 45 0f 5c c1              	subss	%xmm9, %xmm8
100002225: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
10000222f: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002234: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
100002239: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
10000223e: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
100002245: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000224a: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
10000224f: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
100002256: 66 4c 0f 6e c8              	movq	%rax, %xmm9
10000225b: f3 45 0f 5c c1              	subss	%xmm9, %xmm8
100002260: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
10000226a: 66 4c 0f 6e c8              	movq	%rax, %xmm9
10000226f: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
100002274: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
100002279: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
100002280: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002285: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
10000228a: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
100002291: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002296: f3 44 0f 5c c6              	subss	%xmm6, %xmm8
10000229b: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
1000022a5: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000022aa: f3 44 0f 59 c6              	mulss	%xmm6, %xmm8
1000022af: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
1000022b4: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
1000022be: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000022c3: f3 44 0f 59 e6              	mulss	%xmm6, %xmm12
1000022c8: f3 41 0f 58 fc              	addss	%xmm12, %xmm7
1000022cd: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
1000022d7: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000022dc: f3 44 0f 59 ee              	mulss	%xmm6, %xmm13
1000022e1: f3 41 0f 58 fd              	addss	%xmm13, %xmm7
1000022e6: f3 44 0f 58 f7              	addss	%xmm7, %xmm14
1000022eb: e9 fc f9 ff ff              	jmp	0x100001cec <__text+0xcec>
1000022f0: 48 89 ec                    	movq	%rbp, %rsp
1000022f3: 48 81 c4 a0 04 00 00        	addq	$0x4a0, %rsp            ## imm = 0x4A0
1000022fa: 5d                          	popq	%rbp
1000022fb: c3                          	retq
1000022fc: 55                          	pushq	%rbp
1000022fd: 48 89 e5                    	movq	%rsp, %rbp
100002300: 48 81 ec 00 04 00 00        	subq	$0x400, %rsp            ## imm = 0x400
100002307: 48 89 e5                    	movq	%rsp, %rbp
10000230a: 4c 89 bd 30 00 00 00        	movq	%r15, 0x30(%rbp)
100002311: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
100002318: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
10000231f: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
100002326: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
10000232d: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
100002334: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
10000233b: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
100002342: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100002349: 48 8b 87 10 00 00 00        	movq	0x10(%rdi), %rax
100002350: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
100002357: 48 8b 87 18 00 00 00        	movq	0x18(%rdi), %rax
10000235e: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100002365: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
10000236c: 66 4c 0f 6e d8              	movq	%rax, %xmm11
100002371: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100002378: 66 4c 0f 6e e0              	movq	%rax, %xmm12
10000237d: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
100002384: 66 4c 0f 6e e8              	movq	%rax, %xmm13
100002389: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100002390: 66 4c 0f 6e f0              	movq	%rax, %xmm14
100002395: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000239f: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
1000023a6: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000023b0: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
1000023b7: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000023c1: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000023c8: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000023d2: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
1000023d9: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000023e3: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
1000023ea: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000023f4: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
1000023fb: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002405: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
10000240c: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100002413: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
10000241a: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002421: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100002428: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002432: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100002439: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
100002440: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
100002447: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
10000244e: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
100002455: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
10000245c: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
100002463: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
10000246a: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
100002471: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100002478: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
10000247f: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
100002486: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
10000248d: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
100002494: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
10000249b: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
1000024a2: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
1000024a9: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000024b0: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000024b7: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000024be: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
1000024c5: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
1000024cc: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
1000024d3: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
1000024da: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
1000024e1: 48 39 c8                    	cmpq	%rcx, %rax
1000024e4: 0f 8d 0d 01 00 00           	jge	0x1000025f7 <__text+0x15f7>
1000024ea: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000024f1: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
1000024f8: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000024ff: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100002506: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
10000250d: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
100002514: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
10000251b: 48 85 c0                    	testq	%rax, %rax
10000251e: 0f 89 03 00 00 00           	jns	0x100002527 <__text+0x1527>
100002524: 48 01 c8                    	addq	%rcx, %rax
100002527: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
10000252e: 48 01 c3                    	addq	%rax, %rbx
100002531: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002538: 66 4c 0f 6e f8              	movq	%rax, %xmm15
10000253d: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002544: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
10000254b: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002552: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100002559: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100002560: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100002567: 41 0f 28 f7                 	movaps	%xmm15, %xmm6
10000256b: 45 0f 28 c3                 	movaps	%xmm11, %xmm8
10000256f: f3 44 0f 5c c6              	subss	%xmm6, %xmm8
100002574: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
10000257b: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002580: 45 0f 28 cc                 	movaps	%xmm12, %xmm9
100002584: f3 44 0f 5c ce              	subss	%xmm6, %xmm9
100002589: 41 0f 28 f0                 	movaps	%xmm8, %xmm6
10000258d: f3 41 0f 59 f0              	mulss	%xmm8, %xmm6
100002592: 45 0f 28 d1                 	movaps	%xmm9, %xmm10
100002596: f3 45 0f 59 d1              	mulss	%xmm9, %xmm10
10000259b: 0f 28 fe                    	movaps	%xmm6, %xmm7
10000259e: f3 41 0f 58 fa              	addss	%xmm10, %xmm7
1000025a3: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000025ad: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000025b2: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
1000025b5: 0f 87 69 00 00 00           	ja	0x100002624 <__text+0x1624>
1000025bb: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000025c5: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
1000025cc: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
1000025d3: 48 8b 8d 10 02 00 00        	movq	0x210(%rbp), %rcx
1000025da: 48 01 c8                    	addq	%rcx, %rax
1000025dd: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
1000025e4: 48 8b 85 08 02 00 00        	movq	0x208(%rbp), %rax
1000025eb: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
1000025f2: e9 b2 fe ff ff              	jmp	0x1000024a9 <__text+0x14a9>
1000025f7: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002601: 48 89 85 18 02 00 00        	movq	%rax, 0x218(%rbp)
100002608: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
10000260f: 48 8b 8d 18 02 00 00        	movq	0x218(%rbp), %rcx
100002616: 48 39 c8                    	cmpq	%rcx, %rax
100002619: 0f 84 f0 02 00 00           	je	0x10000290f <__text+0x190f>
10000261f: e9 5d 03 00 00              	jmp	0x100002981 <__text+0x1981>
100002624: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
10000262e: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002633: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100002636: 0f 8a 7f ff ff ff           	jp	0x1000025bb <__text+0x15bb>
10000263c: 0f 83 79 ff ff ff           	jae	0x1000025bb <__text+0x15bb>
100002642: 48 8b 85 c0 03 00 00        	movq	0x3c0(%rbp), %rax
100002649: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
100002650: 66 4c 0f 7e f8              	movq	%xmm15, %rax
100002655: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
10000265c: 48 8b 85 c8 03 00 00        	movq	0x3c8(%rbp), %rax
100002663: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
10000266a: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100002671: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100002678: f3 0f 10 9d 30 01 00 00     	movss	0x130(%rbp), %xmm3
100002680: f3 0f 10 ad 48 01 00 00     	movss	0x148(%rbp), %xmm5
100002688: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
10000268b: f3 0f 10 a5 38 01 00 00     	movss	0x138(%rbp), %xmm4
100002693: f3 0f 10 ad 50 01 00 00     	movss	0x150(%rbp), %xmm5
10000269b: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
10000269e: 0f 28 c3                    	movaps	%xmm3, %xmm0
1000026a1: 0f 58 c4                    	addps	%xmm4, %xmm0
1000026a4: f3 0f 11 85 40 01 00 00     	movss	%xmm0, 0x140(%rbp)
1000026ac: 0f 28 e8                    	movaps	%xmm0, %xmm5
1000026af: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
1000026b3: f3 0f 11 ad 58 01 00 00     	movss	%xmm5, 0x158(%rbp)
1000026bb: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
1000026c2: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
1000026c9: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
1000026d0: 48 89 85 68 01 00 00        	movq	%rax, 0x168(%rbp)
1000026d7: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
1000026de: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
1000026e5: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
1000026ec: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
1000026f3: f3 0f 10 9d 60 01 00 00     	movss	0x160(%rbp), %xmm3
1000026fb: f3 0f 10 ad 78 01 00 00     	movss	0x178(%rbp), %xmm5
100002703: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002706: f3 0f 10 a5 68 01 00 00     	movss	0x168(%rbp), %xmm4
10000270e: f3 0f 10 ad 80 01 00 00     	movss	0x180(%rbp), %xmm5
100002716: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002719: 0f 28 cb                    	movaps	%xmm3, %xmm1
10000271c: 0f 58 cc                    	addps	%xmm4, %xmm1
10000271f: f3 0f 11 8d 70 01 00 00     	movss	%xmm1, 0x170(%rbp)
100002727: 0f 28 e9                    	movaps	%xmm1, %xmm5
10000272a: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
10000272e: f3 0f 11 ad 88 01 00 00     	movss	%xmm5, 0x188(%rbp)
100002736: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002740: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002747: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
10000274e: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
100002755: 48 01 c8                    	addq	%rcx, %rax
100002758: 71 0a                       	jno	0x100002764 <__text+0x1764>
10000275a: ba 01 00 00 00              	movl	$0x1, %edx
10000275f: e9 1e 04 00 00              	jmp	0x100002b82 <__text+0x1b82>
100002764: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
10000276b: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
100002775: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000277a: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
10000277d: 0f 92 c0                    	setb	%al
100002780: 0f 9b c1                    	setnp	%cl
100002783: 20 c8                       	andb	%cl, %al
100002785: 48 0f b6 c0                 	movzbq	%al, %rax
100002789: 48 89 85 a8 01 00 00        	movq	%rax, 0x1a8(%rbp)
100002790: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100002797: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
10000279e: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
1000027a5: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
1000027ac: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000027b3: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
1000027ba: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
1000027c1: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
1000027c8: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000027cf: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
1000027d6: 48 8b 85 a8 01 00 00        	movq	0x1a8(%rbp), %rax
1000027dd: 48 85 c0                    	testq	%rax, %rax
1000027e0: 0f 84 d5 fd ff ff           	je	0x1000025bb <__text+0x15bb>
1000027e6: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
1000027f0: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000027f5: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
1000027ff: 66 4c 0f 6e d0              	movq	%rax, %xmm10
100002804: 41 0f 2e fa                 	ucomiss	%xmm10, %xmm7
100002808: 0f 97 c0                    	seta	%al
10000280b: 48 0f b6 c0                 	movzbq	%al, %rax
10000280f: 48 89 85 c0 01 00 00        	movq	%rax, 0x1c0(%rbp)
100002816: 48 8b 85 c0 01 00 00        	movq	0x1c0(%rbp), %rax
10000281d: 48 85 c0                    	testq	%rax, %rax
100002820: 0f 84 03 00 00 00           	je	0x100002829 <__text+0x1829>
100002826: 0f 28 f7                    	movaps	%xmm7, %xmm6
100002829: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002830: 48 89 85 c8 01 00 00        	movq	%rax, 0x1c8(%rbp)
100002837: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
10000283b: f3 0f 5e c6                 	divss	%xmm6, %xmm0
10000283f: f3 0f 11 85 d8 01 00 00     	movss	%xmm0, 0x1d8(%rbp)
100002847: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
10000284e: 48 89 85 e8 01 00 00        	movq	%rax, 0x1e8(%rbp)
100002855: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002859: f3 0f 5e c6                 	divss	%xmm6, %xmm0
10000285d: f3 0f 11 85 f8 01 00 00     	movss	%xmm0, 0x1f8(%rbp)
100002865: f3 0f 10 9d c8 01 00 00     	movss	0x1c8(%rbp), %xmm3
10000286d: f3 0f 10 ad e8 01 00 00     	movss	0x1e8(%rbp), %xmm5
100002875: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002878: f3 0f 10 a5 d8 01 00 00     	movss	0x1d8(%rbp), %xmm4
100002880: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100002888: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
10000288b: 0f 28 d3                    	movaps	%xmm3, %xmm2
10000288e: 0f 58 d4                    	addps	%xmm4, %xmm2
100002891: f3 0f 11 95 e0 01 00 00     	movss	%xmm2, 0x1e0(%rbp)
100002899: 0f 28 ea                    	movaps	%xmm2, %xmm5
10000289c: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
1000028a0: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
1000028a8: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
1000028af: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
1000028b6: 48 8b 85 e0 01 00 00        	movq	0x1e0(%rbp), %rax
1000028bd: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
1000028c4: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000028cb: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
1000028d2: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
1000028d9: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
1000028e0: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000028e7: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
1000028ee: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
1000028f5: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
1000028fc: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100002903: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
10000290a: e9 ac fc ff ff              	jmp	0x1000025bb <__text+0x15bb>
10000290f: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002919: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100002920: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000292a: 48 89 85 30 02 00 00        	movq	%rax, 0x230(%rbp)
100002931: 48 8b 85 28 02 00 00        	movq	0x228(%rbp), %rax
100002938: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
10000293f: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
100002946: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
10000294d: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002954: 48 8b 85 38 02 00 00        	movq	0x238(%rbp), %rax
10000295b: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002962: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
100002969: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002970: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000297a: 31 d2                       	xorl	%edx, %edx
10000297c: e9 01 02 00 00              	jmp	0x100002b82 <__text+0x1b82>
100002981: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002988: 48 89 c1                    	movq	%rax, %rcx
10000298b: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100002990: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100002994: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
10000299e: 66 48 0f 6e e2              	movq	%rdx, %xmm4
1000029a3: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
1000029a7: 0f 82 39 00 00 00           	jb	0x1000029e6 <__text+0x19e6>
1000029ad: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
1000029b7: 66 48 0f 6e e2              	movq	%rdx, %xmm4
1000029bc: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
1000029c0: 0f 83 20 00 00 00           	jae	0x1000029e6 <__text+0x19e6>
1000029c6: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
1000029cb: 48 39 c8                    	cmpq	%rcx, %rax
1000029ce: 0f 85 12 00 00 00           	jne	0x1000029e6 <__text+0x19e6>
1000029d4: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
1000029d8: 66 0f 7e d8                 	movd	%xmm3, %eax
1000029dc: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000029e1: e9 3d 00 00 00              	jmp	0x100002a23 <__text+0x1a23>
1000029e6: 48 8d 35 3b 1b 00 00        	leaq	0x1b3b(%rip), %rsi      ## 0x100004528
1000029ed: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000029f4: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000029fb: 4c 89 c2                    	movq	%r8, %rdx
1000029fe: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100002a08: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100002a12: 0f 05                       	syscall
100002a14: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002a1e: e9 5f 01 00 00              	jmp	0x100002b82 <__text+0x1b82>
100002a23: 48 8b 85 c0 03 00 00        	movq	0x3c0(%rbp), %rax
100002a2a: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002a2f: f3 0f 5e fe                 	divss	%xmm6, %xmm7
100002a33: f3 41 0f 5c fb              	subss	%xmm11, %xmm7
100002a38: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002a42: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002a47: f3 41 0f 59 f8              	mulss	%xmm8, %xmm7
100002a4c: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
100002a53: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002a58: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
100002a5d: f3 45 0f 5c c5              	subss	%xmm13, %xmm8
100002a62: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002a6c: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002a71: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
100002a76: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
100002a7b: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002a82: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002a87: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002a91: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002a96: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
100002a9b: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002a9e: f3 41 0f 58 c0              	addss	%xmm8, %xmm0
100002aa3: f3 0f 11 85 c0 02 00 00     	movss	%xmm0, 0x2c0(%rbp)
100002aab: 48 8b 85 c8 03 00 00        	movq	0x3c8(%rbp), %rax
100002ab2: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002ab7: f3 0f 5e fe                 	divss	%xmm6, %xmm7
100002abb: f3 41 0f 5c fc              	subss	%xmm12, %xmm7
100002ac0: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002aca: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002acf: f3 41 0f 59 f8              	mulss	%xmm8, %xmm7
100002ad4: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
100002adb: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002ae0: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
100002ae5: f3 45 0f 5c c6              	subss	%xmm14, %xmm8
100002aea: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002af4: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002af9: f3 44 0f 59 c6              	mulss	%xmm6, %xmm8
100002afe: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
100002b03: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
100002b0a: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002b0f: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002b19: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002b1e: f3 41 0f 59 f0              	mulss	%xmm8, %xmm6
100002b23: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002b26: f3 0f 58 c6                 	addss	%xmm6, %xmm0
100002b2a: f3 0f 11 85 38 03 00 00     	movss	%xmm0, 0x338(%rbp)
100002b32: 48 8b 85 c0 02 00 00        	movq	0x2c0(%rbp), %rax
100002b39: 48 89 85 40 03 00 00        	movq	%rax, 0x340(%rbp)
100002b40: 48 8b 85 38 03 00 00        	movq	0x338(%rbp), %rax
100002b47: 48 89 85 48 03 00 00        	movq	%rax, 0x348(%rbp)
100002b4e: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002b55: 48 8b 85 40 03 00 00        	movq	0x340(%rbp), %rax
100002b5c: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002b63: 48 8b 85 48 03 00 00        	movq	0x348(%rbp), %rax
100002b6a: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002b71: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002b7b: 31 d2                       	xorl	%edx, %edx
100002b7d: e9 00 00 00 00              	jmp	0x100002b82 <__text+0x1b82>
100002b82: 48 89 ec                    	movq	%rbp, %rsp
100002b85: 48 81 c4 00 04 00 00        	addq	$0x400, %rsp            ## imm = 0x400
100002b8c: 5d                          	popq	%rbp
100002b8d: c3                          	retq
100002b8e: 55                          	pushq	%rbp
100002b8f: 48 89 e5                    	movq	%rsp, %rbp
100002b92: 48 81 ec b0 01 00 00        	subq	$0x1b0, %rsp            ## imm = 0x1B0
100002b99: 48 89 e5                    	movq	%rsp, %rbp
100002b9c: 48 89 95 18 00 00 00        	movq	%rdx, 0x18(%rbp)
100002ba3: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
100002baa: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100002bb1: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
100002bb8: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
100002bbf: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
100002bc6: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002bd0: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002bd5: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002bdf: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100002be6: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002bed: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002bf4: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100002bfb: 48 8b 8d 30 00 00 00        	movq	0x30(%rbp), %rcx
100002c02: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002c09: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100002c10: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
100002c1a: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100002c21: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002c28: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100002c2f: 48 39 c8                    	cmpq	%rcx, %rax
100002c32: 0f 9c c0                    	setl	%al
100002c35: 48 0f b6 c0                 	movzbq	%al, %rax
100002c39: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100002c40: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002c47: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100002c4e: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100002c55: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002c5c: 66 48 0f 7e f0              	movq	%xmm6, %rax
100002c61: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002c68: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100002c6f: 48 85 c0                    	testq	%rax, %rax
100002c72: 0f 84 39 00 00 00           	je	0x100002cb1 <__text+0x1cb1>
100002c78: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002c82: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100002c89: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002c90: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100002c97: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
100002c9e: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002ca5: 66 48 0f 7e f0              	movq	%xmm6, %rax
100002caa: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002cb1: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002cb8: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100002cbf: 48 39 c8                    	cmpq	%rcx, %rax
100002cc2: 0f 84 8c 05 00 00           	je	0x100003254 <__text+0x2254>
100002cc8: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002ccf: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002cd6: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100002cdd: 48 8b 9d 60 00 00 00        	movq	0x60(%rbp), %rbx
100002ce4: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100002ceb: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100002cf2: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002cf9: 48 85 c0                    	testq	%rax, %rax
100002cfc: 0f 89 03 00 00 00           	jns	0x100002d05 <__text+0x1d05>
100002d02: 48 01 c8                    	addq	%rcx, %rax
100002d05: 48 39 c8                    	cmpq	%rcx, %rax
100002d08: 0f 82 0f 00 00 00           	jb	0x100002d1d <__text+0x1d1d>
100002d0e: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002d18: e9 53 05 00 00              	jmp	0x100003270 <__text+0x2270>
100002d1d: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002d24: 48 01 c3                    	addq	%rax, %rbx
100002d27: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002d2e: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100002d35: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002d3c: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100002d43: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002d4a: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100002d51: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100002d58: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100002d5f: 4c 8d bd 88 00 00 00        	leaq	0x88(%rbp), %r15
100002d66: 48 8d bd 68 00 00 00        	leaq	0x68(%rbp), %rdi
100002d6d: 48 8d b5 08 00 00 00        	leaq	0x8(%rbp), %rsi
100002d74: e8 83 f5 ff ff              	callq	0x1000022fc <__text+0x12fc>
100002d79: 48 85 d2                    	testq	%rdx, %rdx
100002d7c: 0f 85 ee 04 00 00           	jne	0x100003270 <__text+0x2270>
100002d82: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
100002d89: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002d8e: 48 8b 85 88 00 00 00        	movq	0x88(%rbp), %rax
100002d95: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002d9a: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002da2: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002da6: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002da9: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002dad: f3 0f 11 85 b0 00 00 00     	movss	%xmm0, 0xb0(%rbp)
100002db5: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100002dbc: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002dc1: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100002dc8: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002dcd: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002dd5: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002dd9: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002ddc: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002de0: f3 0f 11 85 d0 00 00 00     	movss	%xmm0, 0xd0(%rbp)
100002de8: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100002def: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002df4: f3 0f 10 85 b0 00 00 00     	movss	0xb0(%rbp), %xmm0
100002dfc: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002e04: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002e07: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002e0b: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002e0e: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002e12: f3 0f 11 85 e8 00 00 00     	movss	%xmm0, 0xe8(%rbp)
100002e1a: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100002e21: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002e26: f3 0f 10 85 d0 00 00 00     	movss	0xd0(%rbp), %xmm0
100002e2e: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002e36: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002e39: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002e3d: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002e40: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002e44: f3 0f 11 85 00 01 00 00     	movss	%xmm0, 0x100(%rbp)
100002e4c: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002e53: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002e5a: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100002e61: 48 8b 9d 08 01 00 00        	movq	0x108(%rbp), %rbx
100002e68: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100002e6f: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100002e76: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002e7d: 48 85 c0                    	testq	%rax, %rax
100002e80: 0f 89 03 00 00 00           	jns	0x100002e89 <__text+0x1e89>
100002e86: 48 01 c8                    	addq	%rcx, %rax
100002e89: 48 39 c8                    	cmpq	%rcx, %rax
100002e8c: 0f 82 0f 00 00 00           	jb	0x100002ea1 <__text+0x1ea1>
100002e92: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002e9c: e9 cf 03 00 00              	jmp	0x100003270 <__text+0x2270>
100002ea1: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002ea8: 48 01 c3                    	addq	%rax, %rbx
100002eab: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002eb2: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100002eb9: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002ec0: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100002ec7: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002ece: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100002ed5: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100002edc: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100002ee3: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100002eea: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
100002ef1: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100002ef8: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100002eff: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100002f06: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100002f0d: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
100002f14: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100002f1b: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002f22: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002f29: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100002f30: 48 8b 9d 50 01 00 00        	movq	0x150(%rbp), %rbx
100002f37: 4c 8b a3 00 00 00 00        	movq	(%rbx), %r12
100002f3e: 4c 8b ad 88 01 00 00        	movq	0x188(%rbp), %r13
100002f45: 4d 85 ed                    	testq	%r13, %r13
100002f48: 0f 89 03 00 00 00           	jns	0x100002f51 <__text+0x1f51>
100002f4e: 4d 01 e5                    	addq	%r12, %r13
100002f51: 4d 39 e5                    	cmpq	%r12, %r13
100002f54: 0f 82 0f 00 00 00           	jb	0x100002f69 <__text+0x1f69>
100002f5a: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002f64: e9 07 03 00 00              	jmp	0x100003270 <__text+0x2270>
100002f69: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002f70: 4c 8b 9b 10 00 00 00        	movq	0x10(%rbx), %r11
100002f77: 4c 01 d8                    	addq	%r11, %rax
100002f7a: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100002f84: 48 39 c8                    	cmpq	%rcx, %rax
100002f87: 0f 85 5b 00 00 00           	jne	0x100002fe8 <__text+0x1fe8>
100002f8d: 49 89 de                    	movq	%rbx, %r14
100002f90: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100002f97: 4c 89 e8                    	movq	%r13, %rax
100002f9a: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002fa1: 49 01 c6                    	addq	%rax, %r14
100002fa4: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100002fab: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100002fb2: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
100002fb9: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100002fc0: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002fc7: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100002fce: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100002fd5: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
100002fdc: 48 89 9d 58 01 00 00        	movq	%rbx, 0x158(%rbp)
100002fe3: e9 ed 01 00 00              	jmp	0x1000031d5 <__text+0x21d5>
100002fe8: 4c 89 e6                    	movq	%r12, %rsi
100002feb: 48 b9 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rcx
100002ff5: 48 0f af f1                 	imulq	%rcx, %rsi
100002ff9: 48 81 c6 28 00 00 00        	addq	$0x28, %rsi
100003000: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
10000300a: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003014: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
10000301e: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
100003028: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
100003032: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
10000303c: 0f 05                       	syscall
10000303e: 0f 83 0f 00 00 00           	jae	0x100003053 <__text+0x2053>
100003044: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000304e: e9 1d 02 00 00              	jmp	0x100003270 <__text+0x2270>
100003053: 49 89 c7                    	movq	%rax, %r15
100003056: 4d 89 a7 00 00 00 00        	movq	%r12, (%r15)
10000305d: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003067: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
10000306e: 49 89 87 10 00 00 00        	movq	%rax, 0x10(%r15)
100003075: 49 89 87 20 00 00 00        	movq	%rax, 0x20(%r15)
10000307c: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100003086: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
10000308d: 49 89 b7 18 00 00 00        	movq	%rsi, 0x18(%r15)
100003094: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
10000309b: 4d 89 fe                    	movq	%r15, %r14
10000309e: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000030a5: 4c 89 e6                    	movq	%r12, %rsi
1000030a8: 48 b9 04 00 00 00 00 00 00 00       	movabsq	$0x4, %rcx
1000030b2: 48 0f af f1                 	imulq	%rcx, %rsi
1000030b6: 48 85 f6                    	testq	%rsi, %rsi
1000030b9: 0f 84 20 00 00 00           	je	0x1000030df <__text+0x20df>
1000030bf: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000030c6: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
1000030cd: 48 83 c3 08                 	addq	$0x8, %rbx
1000030d1: 49 83 c6 08                 	addq	$0x8, %r14
1000030d5: 48 83 ee 01                 	subq	$0x1, %rsi
1000030d9: 0f 85 e0 ff ff ff           	jne	0x1000030bf <__text+0x20bf>
1000030df: 4d 89 fe                    	movq	%r15, %r14
1000030e2: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000030e9: 4c 89 e8                    	movq	%r13, %rax
1000030ec: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000030f3: 49 01 c6                    	addq	%rax, %r14
1000030f6: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
1000030fd: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100003104: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
10000310b: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100003112: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100003119: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100003120: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100003127: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
10000312e: 4c 89 bd 58 01 00 00        	movq	%r15, 0x158(%rbp)
100003135: 4c 8b 95 50 01 00 00        	movq	0x150(%rbp), %r10
10000313c: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003143: 48 85 c0                    	testq	%rax, %rax
100003146: 0f 84 89 00 00 00           	je	0x1000031d5 <__text+0x21d5>
10000314c: 49 89 c3                    	movq	%rax, %r11
10000314f: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003156: f0                          	lock
100003157: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
10000315c: 0f 85 da ff ff ff           	jne	0x10000313c <__text+0x213c>
100003162: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003169: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003170: 4c 01 d8                    	addq	%r11, %rax
100003173: 48 85 c0                    	testq	%rax, %rax
100003176: 0f 85 59 00 00 00           	jne	0x1000031d5 <__text+0x21d5>
10000317c: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003183: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
10000318d: 48 39 c8                    	cmpq	%rcx, %rax
100003190: 0f 84 e6 ff ff ff           	je	0x10000317c <__text+0x217c>
100003196: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000031a0: 48 39 c8                    	cmpq	%rcx, %rax
1000031a3: 0f 84 2c 00 00 00           	je	0x1000031d5 <__text+0x21d5>
1000031a9: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000031b3: f0                          	lock
1000031b4: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000031b9: 0f 85 bd ff ff ff           	jne	0x10000317c <__text+0x217c>
1000031bf: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000031c6: 4c 89 d7                    	movq	%r10, %rdi
1000031c9: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
1000031d3: 0f 05                       	syscall
1000031d5: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
1000031dc: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000031e3: 48 89 81 00 00 00 00        	movq	%rax, (%rcx)
1000031ea: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
1000031f1: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000031f6: f3 0f 10 85 e8 00 00 00     	movss	0xe8(%rbp), %xmm0
1000031fe: f3 0f 10 8d 00 01 00 00     	movss	0x100(%rbp), %xmm1
100003206: 0f 28 f8                    	movaps	%xmm0, %xmm7
100003209: f3 0f 58 f9                 	addss	%xmm1, %xmm7
10000320d: f3 0f 58 f7                 	addss	%xmm7, %xmm6
100003211: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100003218: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
10000321f: 48 01 c8                    	addq	%rcx, %rax
100003222: 71 0a                       	jno	0x10000322e <__text+0x222e>
100003224: ba 01 00 00 00              	movl	$0x1, %edx
100003229: e9 42 00 00 00              	jmp	0x100003270 <__text+0x2270>
10000322e: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
100003235: 48 8b 85 78 01 00 00        	movq	0x178(%rbp), %rax
10000323c: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100003243: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003248: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
10000324f: e9 5d fa ff ff              	jmp	0x100002cb1 <__text+0x1cb1>
100003254: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
10000325b: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
100003262: 48 8b 85 80 01 00 00        	movq	0x180(%rbp), %rax
100003269: 31 d2                       	xorl	%edx, %edx
10000326b: e9 00 00 00 00              	jmp	0x100003270 <__text+0x2270>
100003270: 48 89 ec                    	movq	%rbp, %rsp
100003273: 48 81 c4 b0 01 00 00        	addq	$0x1b0, %rsp            ## imm = 0x1B0
10000327a: 5d                          	popq	%rbp
10000327b: c3                          	retq
10000327c: 55                          	pushq	%rbp
10000327d: 48 89 e5                    	movq	%rsp, %rbp
100003280: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
100003287: 48 89 e5                    	movq	%rsp, %rbp
10000328a: 48 89 b5 10 00 00 00        	movq	%rsi, 0x10(%rbp)
100003291: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
100003298: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
10000329f: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
1000032a6: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
1000032ad: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000032b7: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000032bc: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000032c6: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
1000032cd: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
1000032d7: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000032de: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
1000032e5: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
1000032ec: 48 39 c8                    	cmpq	%rcx, %rax
1000032ef: 0f 9c c0                    	setl	%al
1000032f2: 48 0f b6 c0                 	movzbq	%al, %rax
1000032f6: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000032fd: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100003304: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
10000330b: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
100003312: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003319: 66 48 0f 7e f0              	movq	%xmm6, %rax
10000331e: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003325: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
10000332c: 48 85 c0                    	testq	%rax, %rax
10000332f: 0f 84 39 00 00 00           	je	0x10000336e <__text+0x236e>
100003335: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000333f: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003346: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
10000334d: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100003354: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
10000335b: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003362: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003367: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
10000336e: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100003375: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
10000337c: 48 39 c8                    	cmpq	%rcx, %rax
10000337f: 0f 84 93 00 00 00           	je	0x100003418 <__text+0x2418>
100003385: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
10000338c: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100003393: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
10000339a: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
1000033a1: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000033ab: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000033b2: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000033b9: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
1000033c0: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000033c7: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000033ce: e9 61 00 00 00              	jmp	0x100003434 <__text+0x2434>
1000033d3: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
1000033da: 48 8b 8d 10 01 00 00        	movq	0x110(%rbp), %rcx
1000033e1: 48 01 c8                    	addq	%rcx, %rax
1000033e4: 71 0a                       	jno	0x1000033f0 <__text+0x23f0>
1000033e6: ba 01 00 00 00              	movl	$0x1, %edx
1000033eb: e9 9c 01 00 00              	jmp	0x10000358c <__text+0x258c>
1000033f0: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
1000033f7: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
1000033fe: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100003405: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
10000340c: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003413: e9 56 ff ff ff              	jmp	0x10000336e <__text+0x236e>
100003418: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
10000341f: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100003426: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
10000342d: 31 d2                       	xorl	%edx, %edx
10000342f: e9 58 01 00 00              	jmp	0x10000358c <__text+0x258c>
100003434: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
10000343b: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100003442: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100003449: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100003450: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100003457: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
10000345e: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003465: 48 8b 8d 70 00 00 00        	movq	0x70(%rbp), %rcx
10000346c: 48 39 c8                    	cmpq	%rcx, %rax
10000346f: 0f 8d 5e ff ff ff           	jge	0x1000033d3 <__text+0x23d3>
100003475: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
10000347c: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100003483: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
10000348a: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100003491: 48 8b 9d 80 00 00 00        	movq	0x80(%rbp), %rbx
100003498: 48 8b 8d 88 00 00 00        	movq	0x88(%rbp), %rcx
10000349f: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
1000034a6: 48 85 c0                    	testq	%rax, %rax
1000034a9: 0f 89 03 00 00 00           	jns	0x1000034b2 <__text+0x24b2>
1000034af: 48 01 c8                    	addq	%rcx, %rax
1000034b2: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000034b9: 48 01 c3                    	addq	%rax, %rbx
1000034bc: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000034c3: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
1000034ca: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
1000034d1: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
1000034d8: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
1000034df: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
1000034e6: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
1000034ed: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
1000034f4: 4c 8d bd b0 00 00 00        	leaq	0xb0(%rbp), %r15
1000034fb: 48 8d bd 90 00 00 00        	leaq	0x90(%rbp), %rdi
100003502: 48 8d b5 00 00 00 00        	leaq	(%rbp), %rsi
100003509: e8 ee ed ff ff              	callq	0x1000022fc <__text+0x12fc>
10000350e: 48 85 d2                    	testq	%rdx, %rdx
100003511: 0f 85 75 00 00 00           	jne	0x10000358c <__text+0x258c>
100003517: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
10000351e: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003523: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
10000352a: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000352f: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100003536: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000353b: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
100003540: f3 0f 58 f7                 	addss	%xmm7, %xmm6
100003544: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000354e: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003555: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
10000355c: 48 8b 8d f0 00 00 00        	movq	0xf0(%rbp), %rcx
100003563: 48 01 c8                    	addq	%rcx, %rax
100003566: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
10000356d: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100003574: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
10000357b: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003580: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100003587: e9 a8 fe ff ff              	jmp	0x100003434 <__text+0x2434>
10000358c: 48 89 ec                    	movq	%rbp, %rsp
10000358f: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
100003596: 5d                          	popq	%rbp
100003597: c3                          	retq
100003598: 55                          	pushq	%rbp
100003599: 48 89 e5                    	movq	%rsp, %rbp
10000359c: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
1000035a3: 48 89 e5                    	movq	%rsp, %rbp
1000035a6: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
1000035b0: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
1000035b7: 48 8b bd 00 00 00 00        	movq	(%rbp), %rdi
1000035be: e8 3d da ff ff              	callq	0x100001000 <__text>
1000035c3: 48 85 d2                    	testq	%rdx, %rdx
1000035c6: 0f 85 d5 05 00 00           	jne	0x100003ba1 <__text+0x2ba1>
1000035cc: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
1000035d3: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000035dd: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
1000035e4: 48 8b 8d 08 00 00 00        	movq	0x8(%rbp), %rcx
1000035eb: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
1000035f2: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
1000035f9: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
100003600: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003607: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
10000360e: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
100003615: 48 85 c0                    	testq	%rax, %rax
100003618: 0f 89 03 00 00 00           	jns	0x100003621 <__text+0x2621>
10000361e: 48 01 c8                    	addq	%rcx, %rax
100003621: 48 85 c0                    	testq	%rax, %rax
100003624: 0f 89 0a 00 00 00           	jns	0x100003634 <__text+0x2634>
10000362a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003634: 48 39 c8                    	cmpq	%rcx, %rax
100003637: 0f 8e 03 00 00 00           	jle	0x100003640 <__text+0x2640>
10000363d: 48 89 c8                    	movq	%rcx, %rax
100003640: 48 8b 95 18 00 00 00        	movq	0x18(%rbp), %rdx
100003647: 48 85 d2                    	testq	%rdx, %rdx
10000364a: 0f 89 03 00 00 00           	jns	0x100003653 <__text+0x2653>
100003650: 48 01 ca                    	addq	%rcx, %rdx
100003653: 48 85 d2                    	testq	%rdx, %rdx
100003656: 0f 89 0a 00 00 00           	jns	0x100003666 <__text+0x2666>
10000365c: 48 ba 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdx
100003666: 48 39 ca                    	cmpq	%rcx, %rdx
100003669: 0f 8e 03 00 00 00           	jle	0x100003672 <__text+0x2672>
10000366f: 48 89 ca                    	movq	%rcx, %rdx
100003672: 49 bb 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r11
10000367c: 48 39 d0                    	cmpq	%rdx, %rax
10000367f: 0f 8d 06 00 00 00           	jge	0x10000368b <__text+0x268b>
100003685: 49 89 d3                    	movq	%rdx, %r11
100003688: 49 29 c3                    	subq	%rax, %r11
10000368b: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003692: 48 01 c3                    	addq	%rax, %rbx
100003695: 48 89 9d 20 00 00 00        	movq	%rbx, 0x20(%rbp)
10000369c: 4c 89 9d 28 00 00 00        	movq	%r11, 0x28(%rbp)
1000036a3: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
1000036ad: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
1000036b4: 48 8b bd 30 00 00 00        	movq	0x30(%rbp), %rdi
1000036bb: e8 40 d9 ff ff              	callq	0x100001000 <__text>
1000036c0: 48 85 d2                    	testq	%rdx, %rdx
1000036c3: 0f 85 d8 04 00 00           	jne	0x100003ba1 <__text+0x2ba1>
1000036c9: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000036d0: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000036d7: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000036de: 48 b8 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rax
1000036e8: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000036ef: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
1000036f6: 48 8b b5 40 00 00 00        	movq	0x40(%rbp), %rsi
1000036fd: e8 f1 e1 ff ff              	callq	0x1000018f3 <__text+0x8f3>
100003702: 48 85 d2                    	testq	%rdx, %rdx
100003705: 0f 85 96 04 00 00           	jne	0x100003ba1 <__text+0x2ba1>
10000370b: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003712: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000371c: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003721: f3 0f 10 85 48 00 00 00     	movss	0x48(%rbp), %xmm0
100003729: 0f 2e c6                    	ucomiss	%xmm6, %xmm0
10000372c: 0f 97 c0                    	seta	%al
10000372f: 48 0f b6 c0                 	movzbq	%al, %rax
100003733: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
10000373a: 48 b8 00 01 00 00 00 00 00 00       	movabsq	$0x100, %rax    ## imm = 0x100
100003744: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
10000374b: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
100003752: 48 8b b5 60 00 00 00        	movq	0x60(%rbp), %rsi
100003759: e8 1e fb ff ff              	callq	0x10000327c <__text+0x227c>
10000375e: 48 85 d2                    	testq	%rdx, %rdx
100003761: 0f 85 3a 04 00 00           	jne	0x100003ba1 <__text+0x2ba1>
100003767: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
10000376e: f3 0f 10 85 68 00 00 00     	movss	0x68(%rbp), %xmm0
100003776: f3 0f 10 8d 68 00 00 00     	movss	0x68(%rbp), %xmm1
10000377e: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003781: 0f 94 c0                    	sete	%al
100003784: 0f 9b c1                    	setnp	%cl
100003787: 20 c8                       	andb	%cl, %al
100003789: 48 0f b6 c0                 	movzbq	%al, %rax
10000378d: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100003794: 48 b8 89 88 08 3c 00 00 00 00       	movabsq	$0x3c088889, %rax ## imm = 0x3C088889
10000379e: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
1000037a5: 48 8d 85 28 01 00 00        	leaq	0x128(%rbp), %rax
1000037ac: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
1000037b3: 48 8b bd 80 00 00 00        	movq	0x80(%rbp), %rdi
1000037ba: 48 8d b5 20 00 00 00        	leaq	0x20(%rbp), %rsi
1000037c1: 48 8b 95 78 00 00 00        	movq	0x78(%rbp), %rdx
1000037c8: e8 c1 f3 ff ff              	callq	0x100002b8e <__text+0x1b8e>
1000037cd: 48 85 d2                    	testq	%rdx, %rdx
1000037d0: 0f 85 cb 03 00 00           	jne	0x100003ba1 <__text+0x2ba1>
1000037d6: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000037dd: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000037e7: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000037ec: f3 0f 10 85 88 00 00 00     	movss	0x88(%rbp), %xmm0
1000037f4: 0f 2e c6                    	ucomiss	%xmm6, %xmm0
1000037f7: 0f 86 59 01 00 00           	jbe	0x100003956 <__text+0x2956>
1000037fd: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003804: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
10000380b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003815: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
10000381c: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100003823: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
10000382a: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003831: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100003838: 48 85 c0                    	testq	%rax, %rax
10000383b: 0f 89 03 00 00 00           	jns	0x100003844 <__text+0x2844>
100003841: 48 01 c8                    	addq	%rcx, %rax
100003844: 48 39 c8                    	cmpq	%rcx, %rax
100003847: 0f 82 0f 00 00 00           	jb	0x10000385c <__text+0x285c>
10000384d: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003857: e9 45 03 00 00              	jmp	0x100003ba1 <__text+0x2ba1>
10000385c: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003863: 48 01 c3                    	addq	%rax, %rbx
100003866: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000386d: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003872: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003879: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100003880: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003887: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
10000388e: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003895: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
10000389c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000038a6: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
1000038ad: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
1000038b4: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
1000038bb: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000038c2: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
1000038c9: 48 85 c0                    	testq	%rax, %rax
1000038cc: 0f 89 03 00 00 00           	jns	0x1000038d5 <__text+0x28d5>
1000038d2: 48 01 c8                    	addq	%rcx, %rax
1000038d5: 48 39 c8                    	cmpq	%rcx, %rax
1000038d8: 0f 82 0f 00 00 00           	jb	0x1000038ed <__text+0x28ed>
1000038de: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000038e8: e9 b4 02 00 00              	jmp	0x100003ba1 <__text+0x2ba1>
1000038ed: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000038f4: 48 01 c3                    	addq	%rax, %rbx
1000038f7: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000038fe: 66 48 0f 6e f8              	movq	%rax, %xmm7
100003903: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
10000390a: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003911: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003918: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
10000391f: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003926: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
10000392d: 0f 2e f7                    	ucomiss	%xmm7, %xmm6
100003930: 0f 95 c0                    	setne	%al
100003933: 0f 9a c1                    	setp	%cl
100003936: 08 c8                       	orb	%cl, %al
100003938: 48 0f b6 c0                 	movzbq	%al, %rax
10000393c: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003943: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
10000394a: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003951: e9 11 00 00 00              	jmp	0x100003967 <__text+0x2967>
100003956: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003960: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003967: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
10000396e: 48 85 c0                    	testq	%rax, %rax
100003971: 0f 84 23 00 00 00           	je	0x10000399a <__text+0x299a>
100003977: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
10000397e: 48 85 c0                    	testq	%rax, %rax
100003981: 0f 84 13 00 00 00           	je	0x10000399a <__text+0x299a>
100003987: 48 8b 85 a0 00 00 00        	movq	0xa0(%rbp), %rax
10000398e: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003995: e9 11 00 00 00              	jmp	0x1000039ab <__text+0x29ab>
10000399a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000039a4: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
1000039ab: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
1000039b2: 48 85 c0                    	testq	%rax, %rax
1000039b5: 0f 84 33 00 00 00           	je	0x1000039ee <__text+0x29ee>
1000039bb: 48 8d 35 4e 06 00 00        	leaq	0x64e(%rip), %rsi       ## 0x100004010
1000039c2: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000039c9: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000039d0: 4c 89 c2                    	movq	%r8, %rdx
1000039d3: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000039dd: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000039e7: 0f 05                       	syscall
1000039e9: e9 2e 00 00 00              	jmp	0x100003a1c <__text+0x2a1c>
1000039ee: 48 8d 35 2b 06 00 00        	leaq	0x62b(%rip), %rsi       ## 0x100004020
1000039f5: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000039fc: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003a03: 4c 89 c2                    	movq	%r8, %rdx
100003a06: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003a10: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003a1a: 0f 05                       	syscall
100003a1c: 48 8d 35 dd 05 00 00        	leaq	0x5dd(%rip), %rsi       ## 0x100004000
100003a23: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003a2a: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003a31: 4c 89 c2                    	movq	%r8, %rdx
100003a34: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003a3e: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003a48: 0f 05                       	syscall
100003a4a: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003a51: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003a58: 4c 8b 95 20 01 00 00        	movq	0x120(%rbp), %r10
100003a5f: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003a66: 48 85 c0                    	testq	%rax, %rax
100003a69: 0f 84 89 00 00 00           	je	0x100003af8 <__text+0x2af8>
100003a6f: 49 89 c3                    	movq	%rax, %r11
100003a72: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003a79: f0                          	lock
100003a7a: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003a7f: 0f 85 da ff ff ff           	jne	0x100003a5f <__text+0x2a5f>
100003a85: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003a8c: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003a93: 4c 01 d8                    	addq	%r11, %rax
100003a96: 48 85 c0                    	testq	%rax, %rax
100003a99: 0f 85 59 00 00 00           	jne	0x100003af8 <__text+0x2af8>
100003a9f: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003aa6: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003ab0: 48 39 c8                    	cmpq	%rcx, %rax
100003ab3: 0f 84 e6 ff ff ff           	je	0x100003a9f <__text+0x2a9f>
100003ab9: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003ac3: 48 39 c8                    	cmpq	%rcx, %rax
100003ac6: 0f 84 2c 00 00 00           	je	0x100003af8 <__text+0x2af8>
100003acc: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100003ad6: f0                          	lock
100003ad7: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003adc: 0f 85 bd ff ff ff           	jne	0x100003a9f <__text+0x2a9f>
100003ae2: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100003ae9: 4c 89 d7                    	movq	%r10, %rdi
100003aec: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100003af6: 0f 05                       	syscall
100003af8: 4c 8b 95 08 00 00 00        	movq	0x8(%rbp), %r10
100003aff: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003b06: 48 85 c0                    	testq	%rax, %rax
100003b09: 0f 84 89 00 00 00           	je	0x100003b98 <__text+0x2b98>
100003b0f: 49 89 c3                    	movq	%rax, %r11
100003b12: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003b19: f0                          	lock
100003b1a: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003b1f: 0f 85 da ff ff ff           	jne	0x100003aff <__text+0x2aff>
100003b25: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003b2c: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003b33: 4c 01 d8                    	addq	%r11, %rax
100003b36: 48 85 c0                    	testq	%rax, %rax
100003b39: 0f 85 59 00 00 00           	jne	0x100003b98 <__text+0x2b98>
100003b3f: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003b46: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003b50: 48 39 c8                    	cmpq	%rcx, %rax
100003b53: 0f 84 e6 ff ff ff           	je	0x100003b3f <__text+0x2b3f>
100003b59: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003b63: 48 39 c8                    	cmpq	%rcx, %rax
100003b66: 0f 84 2c 00 00 00           	je	0x100003b98 <__text+0x2b98>
100003b6c: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100003b76: f0                          	lock
100003b77: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003b7c: 0f 85 bd ff ff ff           	jne	0x100003b3f <__text+0x2b3f>
100003b82: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100003b89: 4c 89 d7                    	movq	%r10, %rdi
100003b8c: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100003b96: 0f 05                       	syscall
100003b98: 31 c0                       	xorl	%eax, %eax
100003b9a: 31 d2                       	xorl	%edx, %edx
100003b9c: e9 00 00 00 00              	jmp	0x100003ba1 <__text+0x2ba1>
100003ba1: 48 89 ec                    	movq	%rbp, %rsp
100003ba4: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
100003bab: 5d                          	popq	%rbp
100003bac: c3                          	retq
100003bad: 53                          	pushq	%rbx
100003bae: 41 54                       	pushq	%r12
100003bb0: 41 55                       	pushq	%r13
100003bb2: 41 56                       	pushq	%r14
100003bb4: 41 57                       	pushq	%r15
100003bb6: e8 dd f9 ff ff              	callq	0x100003598 <__text+0x2598>
100003bbb: 48 85 d2                    	testq	%rdx, %rdx
100003bbe: 0f 95 c2                    	setne	%dl
100003bc1: 0f b6 d2                    	movzbl	%dl, %edx
100003bc4: 48 89 d0                    	movq	%rdx, %rax
100003bc7: 41 5f                       	popq	%r15
100003bc9: 41 5e                       	popq	%r14
100003bcb: 41 5d                       	popq	%r13
100003bcd: 41 5c                       	popq	%r12
100003bcf: 5b                          	popq	%rbx
100003bd0: c3                          	retq
		...
100003ffd: 00 00                       	addb	%al, (%rax)
100003fff: 00                          	<unknown>
