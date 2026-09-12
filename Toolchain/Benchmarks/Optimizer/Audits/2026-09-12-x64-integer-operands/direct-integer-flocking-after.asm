
/private/tmp/silex-part03-evidence/direct-integer-flocking-macos-x64:	file format mach-o 64-bit x86-64

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
100001a61: e9 d2 07 00 00              	jmp	0x100002238 <__text+0x1238>
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
100001ac0: 49 89 c0                    	movq	%rax, %r8
100001ac3: 49 01 c8                    	addq	%rcx, %r8
100001ac6: 71 0a                       	jno	0x100001ad2 <__text+0xad2>
100001ac8: ba 01 00 00 00              	movl	$0x1, %edx
100001acd: e9 66 07 00 00              	jmp	0x100002238 <__text+0x1238>
100001ad2: 4c 89 c0                    	movq	%r8, %rax
100001ad5: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
100001adc: e9 cc fe ff ff              	jmp	0x1000019ad <__text+0x9ad>
100001ae1: 66 4c 0f 7e f0              	movq	%xmm14, %rax
100001ae6: 48 89 85 18 04 00 00        	movq	%rax, 0x418(%rbp)
100001aed: 48 8b 85 18 04 00 00        	movq	0x418(%rbp), %rax
100001af4: 31 d2                       	xorl	%edx, %edx
100001af6: e9 3d 07 00 00              	jmp	0x100002238 <__text+0x1238>
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
100001c97: e9 29 00 00 00              	jmp	0x100001cc5 <__text+0xcc5>
100001c9c: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001ca6: 49 89 c1                    	movq	%rax, %r9
100001ca9: 48 8b 85 30 04 00 00        	movq	0x430(%rbp), %rax
100001cb0: 49 89 c0                    	movq	%rax, %r8
100001cb3: 4d 01 c8                    	addq	%r9, %r8
100001cb6: 4c 89 c0                    	movq	%r8, %rax
100001cb9: 48 89 85 30 04 00 00        	movq	%rax, 0x430(%rbp)
100001cc0: e9 36 fe ff ff              	jmp	0x100001afb <__text+0xafb>
100001cc5: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001ccc: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100001cd3: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001cda: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100001ce1: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
100001ce8: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100001cef: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001cf6: 48 8b 8d 28 01 00 00        	movq	0x128(%rbp), %rcx
100001cfd: 48 39 c8                    	cmpq	%rcx, %rax
100001d00: 0f 8d 1f 01 00 00           	jge	0x100001e25 <__text+0xe25>
100001d06: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100001d0d: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100001d14: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001d1b: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100001d22: 48 8b 9d 38 01 00 00        	movq	0x138(%rbp), %rbx
100001d29: 48 8b 8d 40 01 00 00        	movq	0x140(%rbp), %rcx
100001d30: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001d37: 48 85 c0                    	testq	%rax, %rax
100001d3a: 0f 89 03 00 00 00           	jns	0x100001d43 <__text+0xd43>
100001d40: 48 01 c8                    	addq	%rcx, %rax
100001d43: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100001d4a: 48 01 c3                    	addq	%rax, %rbx
100001d4d: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100001d54: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100001d5b: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100001d62: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100001d69: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100001d70: 66 4c 0f 6e f8              	movq	%rax, %xmm15
100001d75: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001d7c: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100001d83: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100001d8a: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001d8f: f3 41 0f 58 f3              	addss	%xmm11, %xmm6
100001d94: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001d9b: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001da0: 44 0f 28 c6                 	movaps	%xmm6, %xmm8
100001da4: f3 44 0f 5c c7              	subss	%xmm7, %xmm8
100001da9: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100001db0: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001db5: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001dbc: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001dc1: 44 0f 28 ce                 	movaps	%xmm6, %xmm9
100001dc5: f3 44 0f 5c cf              	subss	%xmm7, %xmm9
100001dca: 41 0f 28 f0                 	movaps	%xmm8, %xmm6
100001dce: f3 41 0f 59 f0              	mulss	%xmm8, %xmm6
100001dd3: 45 0f 28 d1                 	movaps	%xmm9, %xmm10
100001dd7: f3 45 0f 59 d1              	mulss	%xmm9, %xmm10
100001ddc: 0f 28 fe                    	movaps	%xmm6, %xmm7
100001ddf: f3 41 0f 58 fa              	addss	%xmm10, %xmm7
100001de4: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001dee: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001df3: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100001df6: 0f 87 4b 00 00 00           	ja	0x100001e47 <__text+0xe47>
100001dfc: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001e06: 49 89 c1                    	movq	%rax, %r9
100001e09: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001e10: 49 89 c0                    	movq	%rax, %r8
100001e13: 4d 01 c8                    	addq	%r9, %r8
100001e16: 4c 89 c0                    	movq	%r8, %rax
100001e19: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001e20: e9 a0 fe ff ff              	jmp	0x100001cc5 <__text+0xcc5>
100001e25: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001e2f: 49 89 c0                    	movq	%rax, %r8
100001e32: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100001e39: 4c 39 c0                    	cmpq	%r8, %rax
100001e3c: 0f 8f 3a 02 00 00           	jg	0x10000207c <__text+0x107c>
100001e42: e9 55 fe ff ff              	jmp	0x100001c9c <__text+0xc9c>
100001e47: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
100001e51: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001e56: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100001e59: 0f 8a 9d ff ff ff           	jp	0x100001dfc <__text+0xdfc>
100001e5f: 0f 83 97 ff ff ff           	jae	0x100001dfc <__text+0xdfc>
100001e65: 4c 89 d0                    	movq	%r10, %rax
100001e68: 48 89 85 d8 01 00 00        	movq	%rax, 0x1d8(%rbp)
100001e6f: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001e76: 48 89 85 e0 01 00 00        	movq	%rax, 0x1e0(%rbp)
100001e7d: 4c 89 d8                    	movq	%r11, %rax
100001e80: 48 89 85 f0 01 00 00        	movq	%rax, 0x1f0(%rbp)
100001e87: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001e8e: 48 89 85 f8 01 00 00        	movq	%rax, 0x1f8(%rbp)
100001e95: f3 0f 10 9d d8 01 00 00     	movss	0x1d8(%rbp), %xmm3
100001e9d: f3 0f 10 ad f0 01 00 00     	movss	0x1f0(%rbp), %xmm5
100001ea5: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100001ea8: f3 0f 10 a5 e0 01 00 00     	movss	0x1e0(%rbp), %xmm4
100001eb0: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100001eb8: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100001ebb: 0f 28 c3                    	movaps	%xmm3, %xmm0
100001ebe: 0f 58 c4                    	addps	%xmm4, %xmm0
100001ec1: f3 0f 11 85 e8 01 00 00     	movss	%xmm0, 0x1e8(%rbp)
100001ec9: 0f 28 e8                    	movaps	%xmm0, %xmm5
100001ecc: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100001ed0: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
100001ed8: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
100001edf: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
100001ee6: 66 4c 0f 7e f8              	movq	%xmm15, %rax
100001eeb: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
100001ef2: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
100001ef9: 48 89 85 20 02 00 00        	movq	%rax, 0x220(%rbp)
100001f00: 48 8b 85 60 01 00 00        	movq	0x160(%rbp), %rax
100001f07: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100001f0e: f3 0f 10 9d 08 02 00 00     	movss	0x208(%rbp), %xmm3
100001f16: f3 0f 10 ad 20 02 00 00     	movss	0x220(%rbp), %xmm5
100001f1e: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100001f21: f3 0f 10 a5 10 02 00 00     	movss	0x210(%rbp), %xmm4
100001f29: f3 0f 10 ad 28 02 00 00     	movss	0x228(%rbp), %xmm5
100001f31: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100001f34: 0f 28 cb                    	movaps	%xmm3, %xmm1
100001f37: 0f 58 cc                    	addps	%xmm4, %xmm1
100001f3a: f3 0f 11 8d 18 02 00 00     	movss	%xmm1, 0x218(%rbp)
100001f42: 0f 28 e9                    	movaps	%xmm1, %xmm5
100001f45: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100001f49: f3 0f 11 ad 30 02 00 00     	movss	%xmm5, 0x230(%rbp)
100001f51: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001f5b: 49 89 c1                    	movq	%rax, %r9
100001f5e: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100001f65: 49 89 c0                    	movq	%rax, %r8
100001f68: 4d 01 c8                    	addq	%r9, %r8
100001f6b: 71 0a                       	jno	0x100001f77 <__text+0xf77>
100001f6d: ba 01 00 00 00              	movl	$0x1, %edx
100001f72: e9 c1 02 00 00              	jmp	0x100002238 <__text+0x1238>
100001f77: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
100001f81: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001f86: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100001f89: 0f 92 c0                    	setb	%al
100001f8c: 0f 9b c1                    	setnp	%cl
100001f8f: 20 c8                       	andb	%cl, %al
100001f91: 48 0f b6 c0                 	movzbq	%al, %rax
100001f95: 48 89 85 50 02 00 00        	movq	%rax, 0x250(%rbp)
100001f9c: 4c 89 c0                    	movq	%r8, %rax
100001f9f: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100001fa6: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
100001fad: 49 89 c2                    	movq	%rax, %r10
100001fb0: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
100001fb7: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100001fbe: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
100001fc5: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
100001fcc: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100001fd3: 49 89 c3                    	movq	%rax, %r11
100001fd6: 48 8b 85 50 02 00 00        	movq	0x250(%rbp), %rax
100001fdd: 48 85 c0                    	testq	%rax, %rax
100001fe0: 0f 84 16 fe ff ff           	je	0x100001dfc <__text+0xdfc>
100001fe6: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100001ff0: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001ff5: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100001fff: 66 4c 0f 6e d0              	movq	%rax, %xmm10
100002004: 41 0f 2e fa                 	ucomiss	%xmm10, %xmm7
100002008: 0f 97 c0                    	seta	%al
10000200b: 48 0f b6 c0                 	movzbq	%al, %rax
10000200f: 48 89 85 68 02 00 00        	movq	%rax, 0x268(%rbp)
100002016: 48 8b 85 68 02 00 00        	movq	0x268(%rbp), %rax
10000201d: 48 85 c0                    	testq	%rax, %rax
100002020: 0f 84 03 00 00 00           	je	0x100002029 <__text+0x1029>
100002026: 0f 28 f7                    	movaps	%xmm7, %xmm6
100002029: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
10000202e: f3 45 0f 58 e0              	addss	%xmm8, %xmm12
100002033: f3 44 0f 5e ce              	divss	%xmm6, %xmm9
100002038: f3 45 0f 58 e9              	addss	%xmm9, %xmm13
10000203d: 4c 89 c0                    	movq	%r8, %rax
100002040: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100002047: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
10000204e: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100002055: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
10000205c: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
100002063: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
10000206a: 49 89 c3                    	movq	%rax, %r11
10000206d: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
100002074: 49 89 c2                    	movq	%rax, %r10
100002077: e9 80 fd ff ff              	jmp	0x100001dfc <__text+0xdfc>
10000207c: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100002083: 48 89 c1                    	movq	%rax, %rcx
100002086: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
10000208b: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
10000208f: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100002099: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000209e: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
1000020a2: 0f 82 39 00 00 00           	jb	0x1000020e1 <__text+0x10e1>
1000020a8: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
1000020b2: 66 48 0f 6e e2              	movq	%rdx, %xmm4
1000020b7: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
1000020bb: 0f 83 20 00 00 00           	jae	0x1000020e1 <__text+0x10e1>
1000020c1: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
1000020c6: 48 39 c8                    	cmpq	%rcx, %rax
1000020c9: 0f 85 12 00 00 00           	jne	0x1000020e1 <__text+0x10e1>
1000020cf: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
1000020d3: 66 0f 7e d8                 	movd	%xmm3, %eax
1000020d7: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000020dc: e9 3d 00 00 00              	jmp	0x10000211e <__text+0x111e>
1000020e1: 48 8d 35 50 23 00 00        	leaq	0x2350(%rip), %rsi      ## 0x100004438
1000020e8: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000020ef: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000020f6: 4c 89 c2                    	movq	%r8, %rdx
1000020f9: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100002103: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
10000210d: 0f 05                       	syscall
10000210f: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002119: e9 1a 01 00 00              	jmp	0x100002238 <__text+0x1238>
10000211e: 4c 89 d0                    	movq	%r10, %rax
100002121: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002126: f3 0f 5e fe                 	divss	%xmm6, %xmm7
10000212a: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100002131: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002136: f3 41 0f 5c f8              	subss	%xmm8, %xmm7
10000213b: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002145: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000214a: f3 41 0f 59 f8              	mulss	%xmm8, %xmm7
10000214f: 4c 89 d8                    	movq	%r11, %rax
100002152: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002157: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
10000215c: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100002163: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002168: f3 45 0f 5c c1              	subss	%xmm9, %xmm8
10000216d: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002177: 66 4c 0f 6e c8              	movq	%rax, %xmm9
10000217c: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
100002181: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
100002186: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
10000218d: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002192: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
100002197: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
10000219e: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000021a3: f3 45 0f 5c c1              	subss	%xmm9, %xmm8
1000021a8: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
1000021b2: 66 4c 0f 6e c8              	movq	%rax, %xmm9
1000021b7: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
1000021bc: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
1000021c1: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
1000021c8: 66 4c 0f 6e c0              	movq	%rax, %xmm8
1000021cd: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
1000021d2: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
1000021d9: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000021de: f3 44 0f 5c c6              	subss	%xmm6, %xmm8
1000021e3: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
1000021ed: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000021f2: f3 44 0f 59 c6              	mulss	%xmm6, %xmm8
1000021f7: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
1000021fc: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002206: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000220b: f3 44 0f 59 e6              	mulss	%xmm6, %xmm12
100002210: f3 41 0f 58 fc              	addss	%xmm12, %xmm7
100002215: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
10000221f: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002224: f3 44 0f 59 ee              	mulss	%xmm6, %xmm13
100002229: f3 41 0f 58 fd              	addss	%xmm13, %xmm7
10000222e: f3 44 0f 58 f7              	addss	%xmm7, %xmm14
100002233: e9 64 fa ff ff              	jmp	0x100001c9c <__text+0xc9c>
100002238: 48 89 ec                    	movq	%rbp, %rsp
10000223b: 48 81 c4 a0 04 00 00        	addq	$0x4a0, %rsp            ## imm = 0x4A0
100002242: 5d                          	popq	%rbp
100002243: c3                          	retq
100002244: 55                          	pushq	%rbp
100002245: 48 89 e5                    	movq	%rsp, %rbp
100002248: 48 81 ec 00 04 00 00        	subq	$0x400, %rsp            ## imm = 0x400
10000224f: 48 89 e5                    	movq	%rsp, %rbp
100002252: 4c 89 bd 30 00 00 00        	movq	%r15, 0x30(%rbp)
100002259: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
100002260: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100002267: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
10000226e: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100002275: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
10000227c: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
100002283: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
10000228a: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100002291: 48 8b 87 10 00 00 00        	movq	0x10(%rdi), %rax
100002298: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
10000229f: 48 8b 87 18 00 00 00        	movq	0x18(%rdi), %rax
1000022a6: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
1000022ad: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
1000022b4: 66 4c 0f 6e d8              	movq	%rax, %xmm11
1000022b9: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
1000022c0: 66 4c 0f 6e e0              	movq	%rax, %xmm12
1000022c5: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
1000022cc: 66 4c 0f 6e e8              	movq	%rax, %xmm13
1000022d1: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
1000022d8: 66 4c 0f 6e f0              	movq	%rax, %xmm14
1000022dd: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000022e7: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
1000022ee: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000022f8: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
1000022ff: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002309: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
100002310: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000231a: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100002321: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000232b: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100002332: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000233c: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100002343: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000234d: 49 89 c0                    	movq	%rax, %r8
100002350: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100002357: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
10000235e: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002365: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
10000236c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002376: 49 89 c1                    	movq	%rax, %r9
100002379: 4c 89 c0                    	movq	%r8, %rax
10000237c: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
100002383: 4c 89 c8                    	movq	%r9, %rax
100002386: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
10000238d: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100002394: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
10000239b: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
1000023a2: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
1000023a9: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
1000023b0: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
1000023b7: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
1000023be: 49 89 c3                    	movq	%rax, %r11
1000023c1: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000023c8: 49 89 c2                    	movq	%rax, %r10
1000023cb: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
1000023d2: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
1000023d9: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000023e0: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000023e7: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000023ee: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
1000023f5: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
1000023fc: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
100002403: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
10000240a: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
100002411: 48 39 c8                    	cmpq	%rcx, %rax
100002414: 0f 8d fa 00 00 00           	jge	0x100002514 <__text+0x1514>
10000241a: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
100002421: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100002428: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
10000242f: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100002436: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
10000243d: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
100002444: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
10000244b: 48 85 c0                    	testq	%rax, %rax
10000244e: 0f 89 03 00 00 00           	jns	0x100002457 <__text+0x1457>
100002454: 48 01 c8                    	addq	%rcx, %rax
100002457: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
10000245e: 48 01 c3                    	addq	%rax, %rbx
100002461: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002468: 66 4c 0f 6e f8              	movq	%rax, %xmm15
10000246d: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002474: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
10000247b: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002482: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100002489: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100002490: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100002497: 41 0f 28 f7                 	movaps	%xmm15, %xmm6
10000249b: 45 0f 28 c3                 	movaps	%xmm11, %xmm8
10000249f: f3 44 0f 5c c6              	subss	%xmm6, %xmm8
1000024a4: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
1000024ab: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000024b0: 45 0f 28 cc                 	movaps	%xmm12, %xmm9
1000024b4: f3 44 0f 5c ce              	subss	%xmm6, %xmm9
1000024b9: 41 0f 28 f0                 	movaps	%xmm8, %xmm6
1000024bd: f3 41 0f 59 f0              	mulss	%xmm8, %xmm6
1000024c2: 45 0f 28 d1                 	movaps	%xmm9, %xmm10
1000024c6: f3 45 0f 59 d1              	mulss	%xmm9, %xmm10
1000024cb: 0f 28 fe                    	movaps	%xmm6, %xmm7
1000024ce: f3 41 0f 58 fa              	addss	%xmm10, %xmm7
1000024d3: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000024dd: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000024e2: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
1000024e5: 0f 87 4b 00 00 00           	ja	0x100002536 <__text+0x1536>
1000024eb: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000024f5: 49 89 c1                    	movq	%rax, %r9
1000024f8: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
1000024ff: 49 89 c0                    	movq	%rax, %r8
100002502: 4d 01 c8                    	addq	%r9, %r8
100002505: 4c 89 c0                    	movq	%r8, %rax
100002508: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
10000250f: e9 c5 fe ff ff              	jmp	0x1000023d9 <__text+0x13d9>
100002514: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000251e: 49 89 c0                    	movq	%rax, %r8
100002521: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002528: 4c 39 c0                    	cmpq	%r8, %rax
10000252b: 0f 84 c1 02 00 00           	je	0x1000027f2 <__text+0x17f2>
100002531: e9 2e 03 00 00              	jmp	0x100002864 <__text+0x1864>
100002536: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
100002540: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002545: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100002548: 0f 8a 9d ff ff ff           	jp	0x1000024eb <__text+0x14eb>
10000254e: 0f 83 97 ff ff ff           	jae	0x1000024eb <__text+0x14eb>
100002554: 4c 89 d0                    	movq	%r10, %rax
100002557: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
10000255e: 66 4c 0f 7e f8              	movq	%xmm15, %rax
100002563: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
10000256a: 4c 89 d8                    	movq	%r11, %rax
10000256d: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100002574: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
10000257b: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100002582: f3 0f 10 9d 30 01 00 00     	movss	0x130(%rbp), %xmm3
10000258a: f3 0f 10 ad 48 01 00 00     	movss	0x148(%rbp), %xmm5
100002592: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002595: f3 0f 10 a5 38 01 00 00     	movss	0x138(%rbp), %xmm4
10000259d: f3 0f 10 ad 50 01 00 00     	movss	0x150(%rbp), %xmm5
1000025a5: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
1000025a8: 0f 28 c3                    	movaps	%xmm3, %xmm0
1000025ab: 0f 58 c4                    	addps	%xmm4, %xmm0
1000025ae: f3 0f 11 85 40 01 00 00     	movss	%xmm0, 0x140(%rbp)
1000025b6: 0f 28 e8                    	movaps	%xmm0, %xmm5
1000025b9: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
1000025bd: f3 0f 11 ad 58 01 00 00     	movss	%xmm5, 0x158(%rbp)
1000025c5: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
1000025cc: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
1000025d3: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
1000025da: 48 89 85 68 01 00 00        	movq	%rax, 0x168(%rbp)
1000025e1: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
1000025e8: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
1000025ef: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
1000025f6: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
1000025fd: f3 0f 10 9d 60 01 00 00     	movss	0x160(%rbp), %xmm3
100002605: f3 0f 10 ad 78 01 00 00     	movss	0x178(%rbp), %xmm5
10000260d: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002610: f3 0f 10 a5 68 01 00 00     	movss	0x168(%rbp), %xmm4
100002618: f3 0f 10 ad 80 01 00 00     	movss	0x180(%rbp), %xmm5
100002620: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002623: 0f 28 cb                    	movaps	%xmm3, %xmm1
100002626: 0f 58 cc                    	addps	%xmm4, %xmm1
100002629: f3 0f 11 8d 70 01 00 00     	movss	%xmm1, 0x170(%rbp)
100002631: 0f 28 e9                    	movaps	%xmm1, %xmm5
100002634: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100002638: f3 0f 11 ad 88 01 00 00     	movss	%xmm5, 0x188(%rbp)
100002640: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000264a: 49 89 c1                    	movq	%rax, %r9
10000264d: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002654: 49 89 c0                    	movq	%rax, %r8
100002657: 4d 01 c8                    	addq	%r9, %r8
10000265a: 71 0a                       	jno	0x100002666 <__text+0x1666>
10000265c: ba 01 00 00 00              	movl	$0x1, %edx
100002661: e9 f7 03 00 00              	jmp	0x100002a5d <__text+0x1a5d>
100002666: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
100002670: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002675: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100002678: 0f 92 c0                    	setb	%al
10000267b: 0f 9b c1                    	setnp	%cl
10000267e: 20 c8                       	andb	%cl, %al
100002680: 48 0f b6 c0                 	movzbq	%al, %rax
100002684: 48 89 85 a8 01 00 00        	movq	%rax, 0x1a8(%rbp)
10000268b: 4c 89 c0                    	movq	%r8, %rax
10000268e: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
100002695: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
10000269c: 49 89 c2                    	movq	%rax, %r10
10000269f: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000026a6: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
1000026ad: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
1000026b4: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
1000026bb: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000026c2: 49 89 c3                    	movq	%rax, %r11
1000026c5: 48 8b 85 a8 01 00 00        	movq	0x1a8(%rbp), %rax
1000026cc: 48 85 c0                    	testq	%rax, %rax
1000026cf: 0f 84 16 fe ff ff           	je	0x1000024eb <__text+0x14eb>
1000026d5: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
1000026df: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000026e4: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
1000026ee: 66 4c 0f 6e d0              	movq	%rax, %xmm10
1000026f3: 41 0f 2e fa                 	ucomiss	%xmm10, %xmm7
1000026f7: 0f 97 c0                    	seta	%al
1000026fa: 48 0f b6 c0                 	movzbq	%al, %rax
1000026fe: 48 89 85 c0 01 00 00        	movq	%rax, 0x1c0(%rbp)
100002705: 48 8b 85 c0 01 00 00        	movq	0x1c0(%rbp), %rax
10000270c: 48 85 c0                    	testq	%rax, %rax
10000270f: 0f 84 03 00 00 00           	je	0x100002718 <__text+0x1718>
100002715: 0f 28 f7                    	movaps	%xmm7, %xmm6
100002718: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
10000271f: 48 89 85 c8 01 00 00        	movq	%rax, 0x1c8(%rbp)
100002726: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
10000272a: f3 0f 5e c6                 	divss	%xmm6, %xmm0
10000272e: f3 0f 11 85 d8 01 00 00     	movss	%xmm0, 0x1d8(%rbp)
100002736: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
10000273d: 48 89 85 e8 01 00 00        	movq	%rax, 0x1e8(%rbp)
100002744: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002748: f3 0f 5e c6                 	divss	%xmm6, %xmm0
10000274c: f3 0f 11 85 f8 01 00 00     	movss	%xmm0, 0x1f8(%rbp)
100002754: f3 0f 10 9d c8 01 00 00     	movss	0x1c8(%rbp), %xmm3
10000275c: f3 0f 10 ad e8 01 00 00     	movss	0x1e8(%rbp), %xmm5
100002764: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002767: f3 0f 10 a5 d8 01 00 00     	movss	0x1d8(%rbp), %xmm4
10000276f: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100002777: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
10000277a: 0f 28 d3                    	movaps	%xmm3, %xmm2
10000277d: 0f 58 d4                    	addps	%xmm4, %xmm2
100002780: f3 0f 11 95 e0 01 00 00     	movss	%xmm2, 0x1e0(%rbp)
100002788: 0f 28 ea                    	movaps	%xmm2, %xmm5
10000278b: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
10000278f: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
100002797: 4c 89 c0                    	movq	%r8, %rax
10000279a: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
1000027a1: 48 8b 85 e0 01 00 00        	movq	0x1e0(%rbp), %rax
1000027a8: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
1000027af: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000027b6: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
1000027bd: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
1000027c4: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
1000027cb: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000027d2: 49 89 c3                    	movq	%rax, %r11
1000027d5: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
1000027dc: 49 89 c2                    	movq	%rax, %r10
1000027df: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
1000027e6: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
1000027ed: e9 f9 fc ff ff              	jmp	0x1000024eb <__text+0x14eb>
1000027f2: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000027fc: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100002803: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000280d: 48 89 85 30 02 00 00        	movq	%rax, 0x230(%rbp)
100002814: 48 8b 85 28 02 00 00        	movq	0x228(%rbp), %rax
10000281b: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
100002822: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
100002829: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
100002830: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002837: 48 8b 85 38 02 00 00        	movq	0x238(%rbp), %rax
10000283e: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002845: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
10000284c: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002853: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000285d: 31 d2                       	xorl	%edx, %edx
10000285f: e9 f9 01 00 00              	jmp	0x100002a5d <__text+0x1a5d>
100002864: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
10000286b: 48 89 c1                    	movq	%rax, %rcx
10000286e: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
100002873: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100002877: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
100002881: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002886: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000288a: 0f 82 39 00 00 00           	jb	0x1000028c9 <__text+0x18c9>
100002890: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
10000289a: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000289f: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
1000028a3: 0f 83 20 00 00 00           	jae	0x1000028c9 <__text+0x18c9>
1000028a9: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
1000028ae: 48 39 c8                    	cmpq	%rcx, %rax
1000028b1: 0f 85 12 00 00 00           	jne	0x1000028c9 <__text+0x18c9>
1000028b7: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
1000028bb: 66 0f 7e d8                 	movd	%xmm3, %eax
1000028bf: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000028c4: e9 3d 00 00 00              	jmp	0x100002906 <__text+0x1906>
1000028c9: 48 8d 35 58 1c 00 00        	leaq	0x1c58(%rip), %rsi      ## 0x100004528
1000028d0: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000028d7: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000028de: 4c 89 c2                    	movq	%r8, %rdx
1000028e1: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000028eb: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
1000028f5: 0f 05                       	syscall
1000028f7: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002901: e9 57 01 00 00              	jmp	0x100002a5d <__text+0x1a5d>
100002906: 4c 89 d0                    	movq	%r10, %rax
100002909: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000290e: f3 0f 5e fe                 	divss	%xmm6, %xmm7
100002912: f3 41 0f 5c fb              	subss	%xmm11, %xmm7
100002917: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002921: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002926: f3 41 0f 59 f8              	mulss	%xmm8, %xmm7
10000292b: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
100002932: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002937: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
10000293c: f3 45 0f 5c c5              	subss	%xmm13, %xmm8
100002941: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
10000294b: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002950: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
100002955: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
10000295a: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002961: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002966: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002970: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002975: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
10000297a: 0f 28 c7                    	movaps	%xmm7, %xmm0
10000297d: f3 41 0f 58 c0              	addss	%xmm8, %xmm0
100002982: f3 0f 11 85 c0 02 00 00     	movss	%xmm0, 0x2c0(%rbp)
10000298a: 4c 89 d8                    	movq	%r11, %rax
10000298d: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002992: f3 0f 5e fe                 	divss	%xmm6, %xmm7
100002996: f3 41 0f 5c fc              	subss	%xmm12, %xmm7
10000299b: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
1000029a5: 66 4c 0f 6e c0              	movq	%rax, %xmm8
1000029aa: f3 41 0f 59 f8              	mulss	%xmm8, %xmm7
1000029af: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
1000029b6: 66 4c 0f 6e c0              	movq	%rax, %xmm8
1000029bb: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
1000029c0: f3 45 0f 5c c6              	subss	%xmm14, %xmm8
1000029c5: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
1000029cf: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000029d4: f3 44 0f 59 c6              	mulss	%xmm6, %xmm8
1000029d9: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
1000029de: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
1000029e5: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000029ea: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
1000029f4: 66 4c 0f 6e c0              	movq	%rax, %xmm8
1000029f9: f3 41 0f 59 f0              	mulss	%xmm8, %xmm6
1000029fe: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002a01: f3 0f 58 c6                 	addss	%xmm6, %xmm0
100002a05: f3 0f 11 85 38 03 00 00     	movss	%xmm0, 0x338(%rbp)
100002a0d: 48 8b 85 c0 02 00 00        	movq	0x2c0(%rbp), %rax
100002a14: 48 89 85 40 03 00 00        	movq	%rax, 0x340(%rbp)
100002a1b: 48 8b 85 38 03 00 00        	movq	0x338(%rbp), %rax
100002a22: 48 89 85 48 03 00 00        	movq	%rax, 0x348(%rbp)
100002a29: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002a30: 48 8b 85 40 03 00 00        	movq	0x340(%rbp), %rax
100002a37: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002a3e: 48 8b 85 48 03 00 00        	movq	0x348(%rbp), %rax
100002a45: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002a4c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002a56: 31 d2                       	xorl	%edx, %edx
100002a58: e9 00 00 00 00              	jmp	0x100002a5d <__text+0x1a5d>
100002a5d: 48 89 ec                    	movq	%rbp, %rsp
100002a60: 48 81 c4 00 04 00 00        	addq	$0x400, %rsp            ## imm = 0x400
100002a67: 5d                          	popq	%rbp
100002a68: c3                          	retq
100002a69: 55                          	pushq	%rbp
100002a6a: 48 89 e5                    	movq	%rsp, %rbp
100002a6d: 48 81 ec b0 01 00 00        	subq	$0x1b0, %rsp            ## imm = 0x1B0
100002a74: 48 89 e5                    	movq	%rsp, %rbp
100002a77: 48 89 95 18 00 00 00        	movq	%rdx, 0x18(%rbp)
100002a7e: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
100002a85: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100002a8c: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
100002a93: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
100002a9a: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
100002aa1: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002aab: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002ab0: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002aba: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100002ac1: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002ac8: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002acf: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100002ad6: 48 8b 8d 30 00 00 00        	movq	0x30(%rbp), %rcx
100002add: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002ae4: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100002aeb: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
100002af5: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100002afc: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002b03: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100002b0a: 48 39 c8                    	cmpq	%rcx, %rax
100002b0d: 0f 9c c0                    	setl	%al
100002b10: 48 0f b6 c0                 	movzbq	%al, %rax
100002b14: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100002b1b: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002b22: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100002b29: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100002b30: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002b37: 66 48 0f 7e f0              	movq	%xmm6, %rax
100002b3c: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002b43: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100002b4a: 48 85 c0                    	testq	%rax, %rax
100002b4d: 0f 84 39 00 00 00           	je	0x100002b8c <__text+0x1b8c>
100002b53: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002b5d: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100002b64: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002b6b: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100002b72: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
100002b79: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002b80: 66 48 0f 7e f0              	movq	%xmm6, %rax
100002b85: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002b8c: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002b93: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100002b9a: 48 39 c8                    	cmpq	%rcx, %rax
100002b9d: 0f 84 8c 05 00 00           	je	0x10000312f <__text+0x212f>
100002ba3: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002baa: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002bb1: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100002bb8: 48 8b 9d 60 00 00 00        	movq	0x60(%rbp), %rbx
100002bbf: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100002bc6: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100002bcd: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002bd4: 48 85 c0                    	testq	%rax, %rax
100002bd7: 0f 89 03 00 00 00           	jns	0x100002be0 <__text+0x1be0>
100002bdd: 48 01 c8                    	addq	%rcx, %rax
100002be0: 48 39 c8                    	cmpq	%rcx, %rax
100002be3: 0f 82 0f 00 00 00           	jb	0x100002bf8 <__text+0x1bf8>
100002be9: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002bf3: e9 53 05 00 00              	jmp	0x10000314b <__text+0x214b>
100002bf8: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002bff: 48 01 c3                    	addq	%rax, %rbx
100002c02: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002c09: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100002c10: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002c17: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100002c1e: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002c25: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100002c2c: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100002c33: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100002c3a: 4c 8d bd 88 00 00 00        	leaq	0x88(%rbp), %r15
100002c41: 48 8d bd 68 00 00 00        	leaq	0x68(%rbp), %rdi
100002c48: 48 8d b5 08 00 00 00        	leaq	0x8(%rbp), %rsi
100002c4f: e8 f0 f5 ff ff              	callq	0x100002244 <__text+0x1244>
100002c54: 48 85 d2                    	testq	%rdx, %rdx
100002c57: 0f 85 ee 04 00 00           	jne	0x10000314b <__text+0x214b>
100002c5d: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
100002c64: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002c69: 48 8b 85 88 00 00 00        	movq	0x88(%rbp), %rax
100002c70: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002c75: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002c7d: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002c81: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002c84: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002c88: f3 0f 11 85 b0 00 00 00     	movss	%xmm0, 0xb0(%rbp)
100002c90: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100002c97: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002c9c: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100002ca3: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002ca8: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002cb0: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002cb4: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002cb7: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002cbb: f3 0f 11 85 d0 00 00 00     	movss	%xmm0, 0xd0(%rbp)
100002cc3: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100002cca: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002ccf: f3 0f 10 85 b0 00 00 00     	movss	0xb0(%rbp), %xmm0
100002cd7: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002cdf: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002ce2: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002ce6: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002ce9: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002ced: f3 0f 11 85 e8 00 00 00     	movss	%xmm0, 0xe8(%rbp)
100002cf5: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100002cfc: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002d01: f3 0f 10 85 d0 00 00 00     	movss	0xd0(%rbp), %xmm0
100002d09: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002d11: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002d14: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002d18: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002d1b: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002d1f: f3 0f 11 85 00 01 00 00     	movss	%xmm0, 0x100(%rbp)
100002d27: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002d2e: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002d35: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100002d3c: 48 8b 9d 08 01 00 00        	movq	0x108(%rbp), %rbx
100002d43: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100002d4a: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100002d51: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002d58: 48 85 c0                    	testq	%rax, %rax
100002d5b: 0f 89 03 00 00 00           	jns	0x100002d64 <__text+0x1d64>
100002d61: 48 01 c8                    	addq	%rcx, %rax
100002d64: 48 39 c8                    	cmpq	%rcx, %rax
100002d67: 0f 82 0f 00 00 00           	jb	0x100002d7c <__text+0x1d7c>
100002d6d: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002d77: e9 cf 03 00 00              	jmp	0x10000314b <__text+0x214b>
100002d7c: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002d83: 48 01 c3                    	addq	%rax, %rbx
100002d86: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002d8d: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100002d94: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002d9b: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100002da2: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002da9: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100002db0: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100002db7: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100002dbe: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100002dc5: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
100002dcc: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100002dd3: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100002dda: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100002de1: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100002de8: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
100002def: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100002df6: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002dfd: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002e04: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100002e0b: 48 8b 9d 50 01 00 00        	movq	0x150(%rbp), %rbx
100002e12: 4c 8b a3 00 00 00 00        	movq	(%rbx), %r12
100002e19: 4c 8b ad 88 01 00 00        	movq	0x188(%rbp), %r13
100002e20: 4d 85 ed                    	testq	%r13, %r13
100002e23: 0f 89 03 00 00 00           	jns	0x100002e2c <__text+0x1e2c>
100002e29: 4d 01 e5                    	addq	%r12, %r13
100002e2c: 4d 39 e5                    	cmpq	%r12, %r13
100002e2f: 0f 82 0f 00 00 00           	jb	0x100002e44 <__text+0x1e44>
100002e35: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002e3f: e9 07 03 00 00              	jmp	0x10000314b <__text+0x214b>
100002e44: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002e4b: 4c 8b 9b 10 00 00 00        	movq	0x10(%rbx), %r11
100002e52: 4c 01 d8                    	addq	%r11, %rax
100002e55: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100002e5f: 48 39 c8                    	cmpq	%rcx, %rax
100002e62: 0f 85 5b 00 00 00           	jne	0x100002ec3 <__text+0x1ec3>
100002e68: 49 89 de                    	movq	%rbx, %r14
100002e6b: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100002e72: 4c 89 e8                    	movq	%r13, %rax
100002e75: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002e7c: 49 01 c6                    	addq	%rax, %r14
100002e7f: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100002e86: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100002e8d: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
100002e94: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100002e9b: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002ea2: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100002ea9: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100002eb0: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
100002eb7: 48 89 9d 58 01 00 00        	movq	%rbx, 0x158(%rbp)
100002ebe: e9 ed 01 00 00              	jmp	0x1000030b0 <__text+0x20b0>
100002ec3: 4c 89 e6                    	movq	%r12, %rsi
100002ec6: 48 b9 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rcx
100002ed0: 48 0f af f1                 	imulq	%rcx, %rsi
100002ed4: 48 81 c6 28 00 00 00        	addq	$0x28, %rsi
100002edb: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
100002ee5: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002eef: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
100002ef9: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
100002f03: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
100002f0d: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
100002f17: 0f 05                       	syscall
100002f19: 0f 83 0f 00 00 00           	jae	0x100002f2e <__text+0x1f2e>
100002f1f: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002f29: e9 1d 02 00 00              	jmp	0x10000314b <__text+0x214b>
100002f2e: 49 89 c7                    	movq	%rax, %r15
100002f31: 4d 89 a7 00 00 00 00        	movq	%r12, (%r15)
100002f38: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002f42: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002f49: 49 89 87 10 00 00 00        	movq	%rax, 0x10(%r15)
100002f50: 49 89 87 20 00 00 00        	movq	%rax, 0x20(%r15)
100002f57: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002f61: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002f68: 49 89 b7 18 00 00 00        	movq	%rsi, 0x18(%r15)
100002f6f: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100002f76: 4d 89 fe                    	movq	%r15, %r14
100002f79: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100002f80: 4c 89 e6                    	movq	%r12, %rsi
100002f83: 48 b9 04 00 00 00 00 00 00 00       	movabsq	$0x4, %rcx
100002f8d: 48 0f af f1                 	imulq	%rcx, %rsi
100002f91: 48 85 f6                    	testq	%rsi, %rsi
100002f94: 0f 84 20 00 00 00           	je	0x100002fba <__text+0x1fba>
100002f9a: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002fa1: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100002fa8: 48 83 c3 08                 	addq	$0x8, %rbx
100002fac: 49 83 c6 08                 	addq	$0x8, %r14
100002fb0: 48 83 ee 01                 	subq	$0x1, %rsi
100002fb4: 0f 85 e0 ff ff ff           	jne	0x100002f9a <__text+0x1f9a>
100002fba: 4d 89 fe                    	movq	%r15, %r14
100002fbd: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100002fc4: 4c 89 e8                    	movq	%r13, %rax
100002fc7: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002fce: 49 01 c6                    	addq	%rax, %r14
100002fd1: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100002fd8: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100002fdf: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
100002fe6: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100002fed: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002ff4: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100002ffb: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100003002: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
100003009: 4c 89 bd 58 01 00 00        	movq	%r15, 0x158(%rbp)
100003010: 4c 8b 95 50 01 00 00        	movq	0x150(%rbp), %r10
100003017: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
10000301e: 48 85 c0                    	testq	%rax, %rax
100003021: 0f 84 89 00 00 00           	je	0x1000030b0 <__text+0x20b0>
100003027: 49 89 c3                    	movq	%rax, %r11
10000302a: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003031: f0                          	lock
100003032: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003037: 0f 85 da ff ff ff           	jne	0x100003017 <__text+0x2017>
10000303d: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003044: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
10000304b: 4c 01 d8                    	addq	%r11, %rax
10000304e: 48 85 c0                    	testq	%rax, %rax
100003051: 0f 85 59 00 00 00           	jne	0x1000030b0 <__text+0x20b0>
100003057: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
10000305e: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003068: 48 39 c8                    	cmpq	%rcx, %rax
10000306b: 0f 84 e6 ff ff ff           	je	0x100003057 <__text+0x2057>
100003071: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
10000307b: 48 39 c8                    	cmpq	%rcx, %rax
10000307e: 0f 84 2c 00 00 00           	je	0x1000030b0 <__text+0x20b0>
100003084: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
10000308e: f0                          	lock
10000308f: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003094: 0f 85 bd ff ff ff           	jne	0x100003057 <__text+0x2057>
10000309a: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000030a1: 4c 89 d7                    	movq	%r10, %rdi
1000030a4: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
1000030ae: 0f 05                       	syscall
1000030b0: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
1000030b7: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000030be: 48 89 81 00 00 00 00        	movq	%rax, (%rcx)
1000030c5: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
1000030cc: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000030d1: f3 0f 10 85 e8 00 00 00     	movss	0xe8(%rbp), %xmm0
1000030d9: f3 0f 10 8d 00 01 00 00     	movss	0x100(%rbp), %xmm1
1000030e1: 0f 28 f8                    	movaps	%xmm0, %xmm7
1000030e4: f3 0f 58 f9                 	addss	%xmm1, %xmm7
1000030e8: f3 0f 58 f7                 	addss	%xmm7, %xmm6
1000030ec: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000030f3: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
1000030fa: 48 01 c8                    	addq	%rcx, %rax
1000030fd: 71 0a                       	jno	0x100003109 <__text+0x2109>
1000030ff: ba 01 00 00 00              	movl	$0x1, %edx
100003104: e9 42 00 00 00              	jmp	0x10000314b <__text+0x214b>
100003109: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
100003110: 48 8b 85 78 01 00 00        	movq	0x178(%rbp), %rax
100003117: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
10000311e: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003123: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
10000312a: e9 5d fa ff ff              	jmp	0x100002b8c <__text+0x1b8c>
10000312f: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100003136: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
10000313d: 48 8b 85 80 01 00 00        	movq	0x180(%rbp), %rax
100003144: 31 d2                       	xorl	%edx, %edx
100003146: e9 00 00 00 00              	jmp	0x10000314b <__text+0x214b>
10000314b: 48 89 ec                    	movq	%rbp, %rsp
10000314e: 48 81 c4 b0 01 00 00        	addq	$0x1b0, %rsp            ## imm = 0x1B0
100003155: 5d                          	popq	%rbp
100003156: c3                          	retq
100003157: 55                          	pushq	%rbp
100003158: 48 89 e5                    	movq	%rsp, %rbp
10000315b: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
100003162: 48 89 e5                    	movq	%rsp, %rbp
100003165: 48 89 b5 10 00 00 00        	movq	%rsi, 0x10(%rbp)
10000316c: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
100003173: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
10000317a: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
100003181: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100003188: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003192: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003197: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000031a1: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
1000031a8: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
1000031b2: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000031b9: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
1000031c0: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
1000031c7: 48 39 c8                    	cmpq	%rcx, %rax
1000031ca: 0f 9c c0                    	setl	%al
1000031cd: 48 0f b6 c0                 	movzbq	%al, %rax
1000031d1: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000031d8: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
1000031df: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
1000031e6: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000031ed: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
1000031f4: 66 48 0f 7e f0              	movq	%xmm6, %rax
1000031f9: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003200: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100003207: 48 85 c0                    	testq	%rax, %rax
10000320a: 0f 84 39 00 00 00           	je	0x100003249 <__text+0x2249>
100003210: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000321a: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003221: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100003228: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
10000322f: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100003236: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
10000323d: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003242: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003249: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100003250: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
100003257: 48 39 c8                    	cmpq	%rcx, %rax
10000325a: 0f 84 93 00 00 00           	je	0x1000032f3 <__text+0x22f3>
100003260: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100003267: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
10000326e: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100003275: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
10000327c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003286: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
10000328d: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
100003294: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
10000329b: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000032a2: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000032a9: e9 61 00 00 00              	jmp	0x10000330f <__text+0x230f>
1000032ae: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
1000032b5: 48 8b 8d 10 01 00 00        	movq	0x110(%rbp), %rcx
1000032bc: 48 01 c8                    	addq	%rcx, %rax
1000032bf: 71 0a                       	jno	0x1000032cb <__text+0x22cb>
1000032c1: ba 01 00 00 00              	movl	$0x1, %edx
1000032c6: e9 9c 01 00 00              	jmp	0x100003467 <__text+0x2467>
1000032cb: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
1000032d2: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
1000032d9: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
1000032e0: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
1000032e7: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
1000032ee: e9 56 ff ff ff              	jmp	0x100003249 <__text+0x2249>
1000032f3: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000032fa: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100003301: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100003308: 31 d2                       	xorl	%edx, %edx
10000330a: e9 58 01 00 00              	jmp	0x100003467 <__text+0x2467>
10000330f: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100003316: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
10000331d: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100003324: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
10000332b: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100003332: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100003339: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003340: 48 8b 8d 70 00 00 00        	movq	0x70(%rbp), %rcx
100003347: 48 39 c8                    	cmpq	%rcx, %rax
10000334a: 0f 8d 5e ff ff ff           	jge	0x1000032ae <__text+0x22ae>
100003350: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100003357: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
10000335e: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100003365: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
10000336c: 48 8b 9d 80 00 00 00        	movq	0x80(%rbp), %rbx
100003373: 48 8b 8d 88 00 00 00        	movq	0x88(%rbp), %rcx
10000337a: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003381: 48 85 c0                    	testq	%rax, %rax
100003384: 0f 89 03 00 00 00           	jns	0x10000338d <__text+0x238d>
10000338a: 48 01 c8                    	addq	%rcx, %rax
10000338d: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003394: 48 01 c3                    	addq	%rax, %rbx
100003397: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000339e: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
1000033a5: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
1000033ac: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
1000033b3: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
1000033ba: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
1000033c1: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
1000033c8: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
1000033cf: 4c 8d bd b0 00 00 00        	leaq	0xb0(%rbp), %r15
1000033d6: 48 8d bd 90 00 00 00        	leaq	0x90(%rbp), %rdi
1000033dd: 48 8d b5 00 00 00 00        	leaq	(%rbp), %rsi
1000033e4: e8 5b ee ff ff              	callq	0x100002244 <__text+0x1244>
1000033e9: 48 85 d2                    	testq	%rdx, %rdx
1000033ec: 0f 85 75 00 00 00           	jne	0x100003467 <__text+0x2467>
1000033f2: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
1000033f9: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000033fe: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100003405: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000340a: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100003411: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100003416: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
10000341b: f3 0f 58 f7                 	addss	%xmm7, %xmm6
10000341f: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100003429: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003430: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003437: 48 8b 8d f0 00 00 00        	movq	0xf0(%rbp), %rcx
10000343e: 48 01 c8                    	addq	%rcx, %rax
100003441: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100003448: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
10000344f: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003456: 66 48 0f 7e f0              	movq	%xmm6, %rax
10000345b: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100003462: e9 a8 fe ff ff              	jmp	0x10000330f <__text+0x230f>
100003467: 48 89 ec                    	movq	%rbp, %rsp
10000346a: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
100003471: 5d                          	popq	%rbp
100003472: c3                          	retq
100003473: 55                          	pushq	%rbp
100003474: 48 89 e5                    	movq	%rsp, %rbp
100003477: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
10000347e: 48 89 e5                    	movq	%rsp, %rbp
100003481: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
10000348b: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
100003492: 48 8b bd 00 00 00 00        	movq	(%rbp), %rdi
100003499: e8 62 db ff ff              	callq	0x100001000 <__text>
10000349e: 48 85 d2                    	testq	%rdx, %rdx
1000034a1: 0f 85 d5 05 00 00           	jne	0x100003a7c <__text+0x2a7c>
1000034a7: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
1000034ae: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000034b8: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
1000034bf: 48 8b 8d 08 00 00 00        	movq	0x8(%rbp), %rcx
1000034c6: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
1000034cd: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
1000034d4: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
1000034db: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
1000034e2: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000034e9: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
1000034f0: 48 85 c0                    	testq	%rax, %rax
1000034f3: 0f 89 03 00 00 00           	jns	0x1000034fc <__text+0x24fc>
1000034f9: 48 01 c8                    	addq	%rcx, %rax
1000034fc: 48 85 c0                    	testq	%rax, %rax
1000034ff: 0f 89 0a 00 00 00           	jns	0x10000350f <__text+0x250f>
100003505: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000350f: 48 39 c8                    	cmpq	%rcx, %rax
100003512: 0f 8e 03 00 00 00           	jle	0x10000351b <__text+0x251b>
100003518: 48 89 c8                    	movq	%rcx, %rax
10000351b: 48 8b 95 18 00 00 00        	movq	0x18(%rbp), %rdx
100003522: 48 85 d2                    	testq	%rdx, %rdx
100003525: 0f 89 03 00 00 00           	jns	0x10000352e <__text+0x252e>
10000352b: 48 01 ca                    	addq	%rcx, %rdx
10000352e: 48 85 d2                    	testq	%rdx, %rdx
100003531: 0f 89 0a 00 00 00           	jns	0x100003541 <__text+0x2541>
100003537: 48 ba 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdx
100003541: 48 39 ca                    	cmpq	%rcx, %rdx
100003544: 0f 8e 03 00 00 00           	jle	0x10000354d <__text+0x254d>
10000354a: 48 89 ca                    	movq	%rcx, %rdx
10000354d: 49 bb 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r11
100003557: 48 39 d0                    	cmpq	%rdx, %rax
10000355a: 0f 8d 06 00 00 00           	jge	0x100003566 <__text+0x2566>
100003560: 49 89 d3                    	movq	%rdx, %r11
100003563: 49 29 c3                    	subq	%rax, %r11
100003566: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
10000356d: 48 01 c3                    	addq	%rax, %rbx
100003570: 48 89 9d 20 00 00 00        	movq	%rbx, 0x20(%rbp)
100003577: 4c 89 9d 28 00 00 00        	movq	%r11, 0x28(%rbp)
10000357e: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
100003588: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
10000358f: 48 8b bd 30 00 00 00        	movq	0x30(%rbp), %rdi
100003596: e8 65 da ff ff              	callq	0x100001000 <__text>
10000359b: 48 85 d2                    	testq	%rdx, %rdx
10000359e: 0f 85 d8 04 00 00           	jne	0x100003a7c <__text+0x2a7c>
1000035a4: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000035ab: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000035b2: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000035b9: 48 b8 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rax
1000035c3: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000035ca: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
1000035d1: 48 8b b5 40 00 00 00        	movq	0x40(%rbp), %rsi
1000035d8: e8 16 e3 ff ff              	callq	0x1000018f3 <__text+0x8f3>
1000035dd: 48 85 d2                    	testq	%rdx, %rdx
1000035e0: 0f 85 96 04 00 00           	jne	0x100003a7c <__text+0x2a7c>
1000035e6: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
1000035ed: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000035f7: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000035fc: f3 0f 10 85 48 00 00 00     	movss	0x48(%rbp), %xmm0
100003604: 0f 2e c6                    	ucomiss	%xmm6, %xmm0
100003607: 0f 97 c0                    	seta	%al
10000360a: 48 0f b6 c0                 	movzbq	%al, %rax
10000360e: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
100003615: 48 b8 00 01 00 00 00 00 00 00       	movabsq	$0x100, %rax    ## imm = 0x100
10000361f: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100003626: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
10000362d: 48 8b b5 60 00 00 00        	movq	0x60(%rbp), %rsi
100003634: e8 1e fb ff ff              	callq	0x100003157 <__text+0x2157>
100003639: 48 85 d2                    	testq	%rdx, %rdx
10000363c: 0f 85 3a 04 00 00           	jne	0x100003a7c <__text+0x2a7c>
100003642: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100003649: f3 0f 10 85 68 00 00 00     	movss	0x68(%rbp), %xmm0
100003651: f3 0f 10 8d 68 00 00 00     	movss	0x68(%rbp), %xmm1
100003659: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
10000365c: 0f 94 c0                    	sete	%al
10000365f: 0f 9b c1                    	setnp	%cl
100003662: 20 c8                       	andb	%cl, %al
100003664: 48 0f b6 c0                 	movzbq	%al, %rax
100003668: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
10000366f: 48 b8 89 88 08 3c 00 00 00 00       	movabsq	$0x3c088889, %rax ## imm = 0x3C088889
100003679: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100003680: 48 8d 85 28 01 00 00        	leaq	0x128(%rbp), %rax
100003687: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
10000368e: 48 8b bd 80 00 00 00        	movq	0x80(%rbp), %rdi
100003695: 48 8d b5 20 00 00 00        	leaq	0x20(%rbp), %rsi
10000369c: 48 8b 95 78 00 00 00        	movq	0x78(%rbp), %rdx
1000036a3: e8 c1 f3 ff ff              	callq	0x100002a69 <__text+0x1a69>
1000036a8: 48 85 d2                    	testq	%rdx, %rdx
1000036ab: 0f 85 cb 03 00 00           	jne	0x100003a7c <__text+0x2a7c>
1000036b1: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000036b8: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000036c2: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000036c7: f3 0f 10 85 88 00 00 00     	movss	0x88(%rbp), %xmm0
1000036cf: 0f 2e c6                    	ucomiss	%xmm6, %xmm0
1000036d2: 0f 86 59 01 00 00           	jbe	0x100003831 <__text+0x2831>
1000036d8: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
1000036df: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
1000036e6: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000036f0: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
1000036f7: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
1000036fe: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003705: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
10000370c: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100003713: 48 85 c0                    	testq	%rax, %rax
100003716: 0f 89 03 00 00 00           	jns	0x10000371f <__text+0x271f>
10000371c: 48 01 c8                    	addq	%rcx, %rax
10000371f: 48 39 c8                    	cmpq	%rcx, %rax
100003722: 0f 82 0f 00 00 00           	jb	0x100003737 <__text+0x2737>
100003728: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003732: e9 45 03 00 00              	jmp	0x100003a7c <__text+0x2a7c>
100003737: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
10000373e: 48 01 c3                    	addq	%rax, %rbx
100003741: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100003748: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000374d: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100003754: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
10000375b: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003762: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
100003769: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003770: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
100003777: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003781: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
100003788: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
10000378f: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003796: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
10000379d: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
1000037a4: 48 85 c0                    	testq	%rax, %rax
1000037a7: 0f 89 03 00 00 00           	jns	0x1000037b0 <__text+0x27b0>
1000037ad: 48 01 c8                    	addq	%rcx, %rax
1000037b0: 48 39 c8                    	cmpq	%rcx, %rax
1000037b3: 0f 82 0f 00 00 00           	jb	0x1000037c8 <__text+0x27c8>
1000037b9: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000037c3: e9 b4 02 00 00              	jmp	0x100003a7c <__text+0x2a7c>
1000037c8: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000037cf: 48 01 c3                    	addq	%rax, %rbx
1000037d2: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000037d9: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000037de: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
1000037e5: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
1000037ec: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
1000037f3: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
1000037fa: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003801: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100003808: 0f 2e f7                    	ucomiss	%xmm7, %xmm6
10000380b: 0f 95 c0                    	setne	%al
10000380e: 0f 9a c1                    	setp	%cl
100003811: 08 c8                       	orb	%cl, %al
100003813: 48 0f b6 c0                 	movzbq	%al, %rax
100003817: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
10000381e: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
100003825: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
10000382c: e9 11 00 00 00              	jmp	0x100003842 <__text+0x2842>
100003831: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000383b: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003842: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
100003849: 48 85 c0                    	testq	%rax, %rax
10000384c: 0f 84 23 00 00 00           	je	0x100003875 <__text+0x2875>
100003852: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100003859: 48 85 c0                    	testq	%rax, %rax
10000385c: 0f 84 13 00 00 00           	je	0x100003875 <__text+0x2875>
100003862: 48 8b 85 a0 00 00 00        	movq	0xa0(%rbp), %rax
100003869: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003870: e9 11 00 00 00              	jmp	0x100003886 <__text+0x2886>
100003875: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000387f: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100003886: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
10000388d: 48 85 c0                    	testq	%rax, %rax
100003890: 0f 84 33 00 00 00           	je	0x1000038c9 <__text+0x28c9>
100003896: 48 8d 35 73 07 00 00        	leaq	0x773(%rip), %rsi       ## 0x100004010
10000389d: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000038a4: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000038ab: 4c 89 c2                    	movq	%r8, %rdx
1000038ae: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000038b8: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000038c2: 0f 05                       	syscall
1000038c4: e9 2e 00 00 00              	jmp	0x1000038f7 <__text+0x28f7>
1000038c9: 48 8d 35 50 07 00 00        	leaq	0x750(%rip), %rsi       ## 0x100004020
1000038d0: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000038d7: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000038de: 4c 89 c2                    	movq	%r8, %rdx
1000038e1: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000038eb: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000038f5: 0f 05                       	syscall
1000038f7: 48 8d 35 02 07 00 00        	leaq	0x702(%rip), %rsi       ## 0x100004000
1000038fe: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003905: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000390c: 4c 89 c2                    	movq	%r8, %rdx
10000390f: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003919: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003923: 0f 05                       	syscall
100003925: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
10000392c: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003933: 4c 8b 95 20 01 00 00        	movq	0x120(%rbp), %r10
10000393a: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003941: 48 85 c0                    	testq	%rax, %rax
100003944: 0f 84 89 00 00 00           	je	0x1000039d3 <__text+0x29d3>
10000394a: 49 89 c3                    	movq	%rax, %r11
10000394d: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003954: f0                          	lock
100003955: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
10000395a: 0f 85 da ff ff ff           	jne	0x10000393a <__text+0x293a>
100003960: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003967: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
10000396e: 4c 01 d8                    	addq	%r11, %rax
100003971: 48 85 c0                    	testq	%rax, %rax
100003974: 0f 85 59 00 00 00           	jne	0x1000039d3 <__text+0x29d3>
10000397a: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003981: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
10000398b: 48 39 c8                    	cmpq	%rcx, %rax
10000398e: 0f 84 e6 ff ff ff           	je	0x10000397a <__text+0x297a>
100003994: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
10000399e: 48 39 c8                    	cmpq	%rcx, %rax
1000039a1: 0f 84 2c 00 00 00           	je	0x1000039d3 <__text+0x29d3>
1000039a7: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000039b1: f0                          	lock
1000039b2: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000039b7: 0f 85 bd ff ff ff           	jne	0x10000397a <__text+0x297a>
1000039bd: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000039c4: 4c 89 d7                    	movq	%r10, %rdi
1000039c7: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
1000039d1: 0f 05                       	syscall
1000039d3: 4c 8b 95 08 00 00 00        	movq	0x8(%rbp), %r10
1000039da: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
1000039e1: 48 85 c0                    	testq	%rax, %rax
1000039e4: 0f 84 89 00 00 00           	je	0x100003a73 <__text+0x2a73>
1000039ea: 49 89 c3                    	movq	%rax, %r11
1000039ed: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
1000039f4: f0                          	lock
1000039f5: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
1000039fa: 0f 85 da ff ff ff           	jne	0x1000039da <__text+0x29da>
100003a00: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003a07: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003a0e: 4c 01 d8                    	addq	%r11, %rax
100003a11: 48 85 c0                    	testq	%rax, %rax
100003a14: 0f 85 59 00 00 00           	jne	0x100003a73 <__text+0x2a73>
100003a1a: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003a21: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003a2b: 48 39 c8                    	cmpq	%rcx, %rax
100003a2e: 0f 84 e6 ff ff ff           	je	0x100003a1a <__text+0x2a1a>
100003a34: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003a3e: 48 39 c8                    	cmpq	%rcx, %rax
100003a41: 0f 84 2c 00 00 00           	je	0x100003a73 <__text+0x2a73>
100003a47: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100003a51: f0                          	lock
100003a52: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003a57: 0f 85 bd ff ff ff           	jne	0x100003a1a <__text+0x2a1a>
100003a5d: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100003a64: 4c 89 d7                    	movq	%r10, %rdi
100003a67: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100003a71: 0f 05                       	syscall
100003a73: 31 c0                       	xorl	%eax, %eax
100003a75: 31 d2                       	xorl	%edx, %edx
100003a77: e9 00 00 00 00              	jmp	0x100003a7c <__text+0x2a7c>
100003a7c: 48 89 ec                    	movq	%rbp, %rsp
100003a7f: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
100003a86: 5d                          	popq	%rbp
100003a87: c3                          	retq
100003a88: 53                          	pushq	%rbx
100003a89: 41 54                       	pushq	%r12
100003a8b: 41 55                       	pushq	%r13
100003a8d: 41 56                       	pushq	%r14
100003a8f: 41 57                       	pushq	%r15
100003a91: e8 dd f9 ff ff              	callq	0x100003473 <__text+0x2473>
100003a96: 48 85 d2                    	testq	%rdx, %rdx
100003a99: 0f 95 c2                    	setne	%dl
100003a9c: 0f b6 d2                    	movzbl	%dl, %edx
100003a9f: 48 89 d0                    	movq	%rdx, %rax
100003aa2: 41 5f                       	popq	%r15
100003aa4: 41 5e                       	popq	%r14
100003aa6: 41 5d                       	popq	%r13
100003aa8: 41 5c                       	popq	%r12
100003aaa: 5b                          	popq	%rbx
100003aab: c3                          	retq
		...
