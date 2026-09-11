
/private/tmp/silex-part03-evidence/direct-sse-flocking-macos-x64:	file format mach-o 64-bit x86-64

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
100001a89: e9 66 08 00 00              	jmp	0x1000022f4 <__text+0x12f4>
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
100001afa: e9 f5 07 00 00              	jmp	0x1000022f4 <__text+0x12f4>
100001aff: 48 89 85 10 04 00 00        	movq	%rax, 0x410(%rbp)
100001b06: 48 8b 85 10 04 00 00        	movq	0x410(%rbp), %rax
100001b0d: 48 89 85 20 04 00 00        	movq	%rax, 0x420(%rbp)
100001b14: e9 bc fe ff ff              	jmp	0x1000019d5 <__text+0x9d5>
100001b19: 66 4c 0f 7e f0              	movq	%xmm14, %rax
100001b1e: 48 89 85 18 04 00 00        	movq	%rax, 0x418(%rbp)
100001b25: 48 8b 85 18 04 00 00        	movq	0x418(%rbp), %rax
100001b2c: 31 d2                       	xorl	%edx, %edx
100001b2e: e9 c1 07 00 00              	jmp	0x1000022f4 <__text+0x12f4>
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
100001d63: 0f 8d 34 01 00 00           	jge	0x100001e9d <__text+0xe9d>
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
100001dd3: 48 89 85 58 01 00 00        	movq	%rax, 0x158(%rbp)
100001dda: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100001de1: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100001de8: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100001def: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001df4: f3 41 0f 58 f3              	addss	%xmm11, %xmm6
100001df9: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001e00: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001e05: 44 0f 28 c6                 	movaps	%xmm6, %xmm8
100001e09: f3 44 0f 5c c7              	subss	%xmm7, %xmm8
100001e0e: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100001e15: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001e1a: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001e21: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001e26: 44 0f 28 ce                 	movaps	%xmm6, %xmm9
100001e2a: f3 44 0f 5c cf              	subss	%xmm7, %xmm9
100001e2f: 41 0f 28 f0                 	movaps	%xmm8, %xmm6
100001e33: f3 41 0f 59 f0              	mulss	%xmm8, %xmm6
100001e38: 45 0f 28 d1                 	movaps	%xmm9, %xmm10
100001e3c: f3 45 0f 59 d1              	mulss	%xmm9, %xmm10
100001e41: 0f 28 fe                    	movaps	%xmm6, %xmm7
100001e44: f3 41 0f 58 fa              	addss	%xmm10, %xmm7
100001e49: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001e53: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001e58: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100001e5b: 0f 87 69 00 00 00           	ja	0x100001eca <__text+0xeca>
100001e61: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001e6b: 48 89 85 b8 02 00 00        	movq	%rax, 0x2b8(%rbp)
100001e72: 48 8b 85 40 04 00 00        	movq	0x440(%rbp), %rax
100001e79: 48 8b 8d b8 02 00 00        	movq	0x2b8(%rbp), %rcx
100001e80: 48 01 c8                    	addq	%rcx, %rax
100001e83: 48 89 85 b0 02 00 00        	movq	%rax, 0x2b0(%rbp)
100001e8a: 48 8b 85 b0 02 00 00        	movq	0x2b0(%rbp), %rax
100001e91: 48 89 85 40 04 00 00        	movq	%rax, 0x440(%rbp)
100001e98: e9 8b fe ff ff              	jmp	0x100001d28 <__text+0xd28>
100001e9d: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001ea7: 48 89 85 c0 02 00 00        	movq	%rax, 0x2c0(%rbp)
100001eae: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100001eb5: 48 8b 8d c0 02 00 00        	movq	0x2c0(%rbp), %rcx
100001ebc: 48 39 c8                    	cmpq	%rcx, %rax
100001ebf: 0f 8f 6b 02 00 00           	jg	0x100002130 <__text+0x1130>
100001ec5: e9 22 fe ff ff              	jmp	0x100001cec <__text+0xcec>
100001eca: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
100001ed4: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001ed9: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100001edc: 0f 8a 7f ff ff ff           	jp	0x100001e61 <__text+0xe61>
100001ee2: 0f 83 79 ff ff ff           	jae	0x100001e61 <__text+0xe61>
100001ee8: 48 8b 85 68 04 00 00        	movq	0x468(%rbp), %rax
100001eef: 48 89 85 d8 01 00 00        	movq	%rax, 0x1d8(%rbp)
100001ef6: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100001efd: 48 89 85 e0 01 00 00        	movq	%rax, 0x1e0(%rbp)
100001f04: 48 8b 85 70 04 00 00        	movq	0x470(%rbp), %rax
100001f0b: 48 89 85 f0 01 00 00        	movq	%rax, 0x1f0(%rbp)
100001f12: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001f19: 48 89 85 f8 01 00 00        	movq	%rax, 0x1f8(%rbp)
100001f20: f3 0f 10 9d d8 01 00 00     	movss	0x1d8(%rbp), %xmm3
100001f28: f3 0f 10 ad f0 01 00 00     	movss	0x1f0(%rbp), %xmm5
100001f30: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100001f33: f3 0f 10 a5 e0 01 00 00     	movss	0x1e0(%rbp), %xmm4
100001f3b: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100001f43: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100001f46: 0f 28 c3                    	movaps	%xmm3, %xmm0
100001f49: 0f 58 c4                    	addps	%xmm4, %xmm0
100001f4c: f3 0f 11 85 e8 01 00 00     	movss	%xmm0, 0x1e8(%rbp)
100001f54: 0f 28 e8                    	movaps	%xmm0, %xmm5
100001f57: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100001f5b: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
100001f63: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
100001f6a: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
100001f71: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
100001f78: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
100001f7f: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
100001f86: 48 89 85 20 02 00 00        	movq	%rax, 0x220(%rbp)
100001f8d: 48 8b 85 60 01 00 00        	movq	0x160(%rbp), %rax
100001f94: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100001f9b: f3 0f 10 9d 08 02 00 00     	movss	0x208(%rbp), %xmm3
100001fa3: f3 0f 10 ad 20 02 00 00     	movss	0x220(%rbp), %xmm5
100001fab: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100001fae: f3 0f 10 a5 10 02 00 00     	movss	0x210(%rbp), %xmm4
100001fb6: f3 0f 10 ad 28 02 00 00     	movss	0x228(%rbp), %xmm5
100001fbe: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100001fc1: 0f 28 cb                    	movaps	%xmm3, %xmm1
100001fc4: 0f 58 cc                    	addps	%xmm4, %xmm1
100001fc7: f3 0f 11 8d 18 02 00 00     	movss	%xmm1, 0x218(%rbp)
100001fcf: 0f 28 e9                    	movaps	%xmm1, %xmm5
100001fd2: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
100001fd6: f3 0f 11 ad 30 02 00 00     	movss	%xmm5, 0x230(%rbp)
100001fde: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100001fe8: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
100001fef: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100001ff6: 48 8b 8d 38 02 00 00        	movq	0x238(%rbp), %rcx
100001ffd: 48 01 c8                    	addq	%rcx, %rax
100002000: 71 0a                       	jno	0x10000200c <__text+0x100c>
100002002: ba 01 00 00 00              	movl	$0x1, %edx
100002007: e9 e8 02 00 00              	jmp	0x1000022f4 <__text+0x12f4>
10000200c: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
100002013: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
10000201d: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002022: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100002025: 0f 92 c0                    	setb	%al
100002028: 0f 9b c1                    	setnp	%cl
10000202b: 20 c8                       	andb	%cl, %al
10000202d: 48 0f b6 c0                 	movzbq	%al, %rax
100002031: 48 89 85 50 02 00 00        	movq	%rax, 0x250(%rbp)
100002038: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
10000203f: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
100002046: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
10000204d: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
100002054: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
10000205b: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100002062: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
100002069: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
100002070: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100002077: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
10000207e: 48 8b 85 50 02 00 00        	movq	0x250(%rbp), %rax
100002085: 48 85 c0                    	testq	%rax, %rax
100002088: 0f 84 d3 fd ff ff           	je	0x100001e61 <__text+0xe61>
10000208e: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100002098: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000209d: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
1000020a7: 66 4c 0f 6e d0              	movq	%rax, %xmm10
1000020ac: 41 0f 2e fa                 	ucomiss	%xmm10, %xmm7
1000020b0: 0f 97 c0                    	seta	%al
1000020b3: 48 0f b6 c0                 	movzbq	%al, %rax
1000020b7: 48 89 85 68 02 00 00        	movq	%rax, 0x268(%rbp)
1000020be: 48 8b 85 68 02 00 00        	movq	0x268(%rbp), %rax
1000020c5: 48 85 c0                    	testq	%rax, %rax
1000020c8: 0f 84 03 00 00 00           	je	0x1000020d1 <__text+0x10d1>
1000020ce: 0f 28 f7                    	movaps	%xmm7, %xmm6
1000020d1: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
1000020d6: f3 45 0f 58 e0              	addss	%xmm8, %xmm12
1000020db: f3 44 0f 5e ce              	divss	%xmm6, %xmm9
1000020e0: f3 45 0f 58 e9              	addss	%xmm9, %xmm13
1000020e5: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
1000020ec: 48 89 85 38 04 00 00        	movq	%rax, 0x438(%rbp)
1000020f3: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
1000020fa: 48 89 85 80 04 00 00        	movq	%rax, 0x480(%rbp)
100002101: 48 8b 85 18 02 00 00        	movq	0x218(%rbp), %rax
100002108: 48 89 85 78 04 00 00        	movq	%rax, 0x478(%rbp)
10000210f: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100002116: 48 89 85 70 04 00 00        	movq	%rax, 0x470(%rbp)
10000211d: 48 8b 85 e8 01 00 00        	movq	0x1e8(%rbp), %rax
100002124: 48 89 85 68 04 00 00        	movq	%rax, 0x468(%rbp)
10000212b: e9 31 fd ff ff              	jmp	0x100001e61 <__text+0xe61>
100002130: 48 8b 85 38 04 00 00        	movq	0x438(%rbp), %rax
100002137: 48 89 c1                    	movq	%rax, %rcx
10000213a: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
10000213f: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100002143: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
10000214d: 66 48 0f 6e e2              	movq	%rdx, %xmm4
100002152: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
100002156: 0f 82 39 00 00 00           	jb	0x100002195 <__text+0x1195>
10000215c: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
100002166: 66 48 0f 6e e2              	movq	%rdx, %xmm4
10000216b: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
10000216f: 0f 83 20 00 00 00           	jae	0x100002195 <__text+0x1195>
100002175: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
10000217a: 48 39 c8                    	cmpq	%rcx, %rax
10000217d: 0f 85 12 00 00 00           	jne	0x100002195 <__text+0x1195>
100002183: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
100002187: 66 0f 7e d8                 	movd	%xmm3, %eax
10000218b: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002190: e9 3d 00 00 00              	jmp	0x1000021d2 <__text+0x11d2>
100002195: 48 8d 35 9c 22 00 00        	leaq	0x229c(%rip), %rsi      ## 0x100004438
10000219c: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000021a3: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000021aa: 4c 89 c2                    	movq	%r8, %rdx
1000021ad: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000021b7: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
1000021c1: 0f 05                       	syscall
1000021c3: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
1000021cd: e9 22 01 00 00              	jmp	0x1000022f4 <__text+0x12f4>
1000021d2: 48 8b 85 68 04 00 00        	movq	0x468(%rbp), %rax
1000021d9: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000021de: f3 0f 5e fe                 	divss	%xmm6, %xmm7
1000021e2: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
1000021e9: 66 4c 0f 6e c0              	movq	%rax, %xmm8
1000021ee: f3 41 0f 5c f8              	subss	%xmm8, %xmm7
1000021f3: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
1000021fd: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002202: f3 41 0f 59 f8              	mulss	%xmm8, %xmm7
100002207: 48 8b 85 70 04 00 00        	movq	0x470(%rbp), %rax
10000220e: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002213: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
100002218: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
10000221f: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002224: f3 45 0f 5c c1              	subss	%xmm9, %xmm8
100002229: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002233: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002238: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
10000223d: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
100002242: 48 8b 85 78 04 00 00        	movq	0x478(%rbp), %rax
100002249: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000224e: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
100002253: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
10000225a: 66 4c 0f 6e c8              	movq	%rax, %xmm9
10000225f: f3 45 0f 5c c1              	subss	%xmm9, %xmm8
100002264: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
10000226e: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002273: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
100002278: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
10000227d: 48 8b 85 80 04 00 00        	movq	0x480(%rbp), %rax
100002284: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002289: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
10000228e: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
100002295: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000229a: f3 44 0f 5c c6              	subss	%xmm6, %xmm8
10000229f: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
1000022a9: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000022ae: f3 44 0f 59 c6              	mulss	%xmm6, %xmm8
1000022b3: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
1000022b8: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
1000022c2: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000022c7: f3 44 0f 59 e6              	mulss	%xmm6, %xmm12
1000022cc: f3 41 0f 58 fc              	addss	%xmm12, %xmm7
1000022d1: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
1000022db: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000022e0: f3 44 0f 59 ee              	mulss	%xmm6, %xmm13
1000022e5: f3 41 0f 58 fd              	addss	%xmm13, %xmm7
1000022ea: f3 44 0f 58 f7              	addss	%xmm7, %xmm14
1000022ef: e9 f8 f9 ff ff              	jmp	0x100001cec <__text+0xcec>
1000022f4: 48 89 ec                    	movq	%rbp, %rsp
1000022f7: 48 81 c4 a0 04 00 00        	addq	$0x4a0, %rsp            ## imm = 0x4A0
1000022fe: 5d                          	popq	%rbp
1000022ff: c3                          	retq
100002300: 55                          	pushq	%rbp
100002301: 48 89 e5                    	movq	%rsp, %rbp
100002304: 48 81 ec 00 04 00 00        	subq	$0x400, %rsp            ## imm = 0x400
10000230b: 48 89 e5                    	movq	%rsp, %rbp
10000230e: 4c 89 bd 30 00 00 00        	movq	%r15, 0x30(%rbp)
100002315: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
10000231c: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100002323: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
10000232a: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100002331: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
100002338: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
10000233f: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
100002346: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
10000234d: 48 8b 87 10 00 00 00        	movq	0x10(%rdi), %rax
100002354: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
10000235b: 48 8b 87 18 00 00 00        	movq	0x18(%rdi), %rax
100002362: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100002369: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100002370: 66 4c 0f 6e d8              	movq	%rax, %xmm11
100002375: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
10000237c: 66 4c 0f 6e e0              	movq	%rax, %xmm12
100002381: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
100002388: 66 4c 0f 6e e8              	movq	%rax, %xmm13
10000238d: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
100002394: 66 4c 0f 6e f0              	movq	%rax, %xmm14
100002399: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000023a3: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
1000023aa: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000023b4: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
1000023bb: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000023c5: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000023cc: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000023d6: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
1000023dd: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000023e7: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
1000023ee: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000023f8: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
1000023ff: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002409: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100002410: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100002417: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
10000241e: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002425: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
10000242c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002436: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
10000243d: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
100002444: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
10000244b: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100002452: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
100002459: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100002460: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
100002467: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
10000246e: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
100002475: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
10000247c: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
100002483: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
10000248a: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
100002491: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
100002498: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
10000249f: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
1000024a6: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
1000024ad: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000024b4: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000024bb: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
1000024c2: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
1000024c9: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
1000024d0: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
1000024d7: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
1000024de: 48 8b 8d 98 00 00 00        	movq	0x98(%rbp), %rcx
1000024e5: 48 39 c8                    	cmpq	%rcx, %rax
1000024e8: 0f 8d 17 01 00 00           	jge	0x100002605 <__text+0x1605>
1000024ee: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000024f5: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
1000024fc: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100002503: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
10000250a: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100002511: 48 8b 8d b0 00 00 00        	movq	0xb0(%rbp), %rcx
100002518: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
10000251f: 48 85 c0                    	testq	%rax, %rax
100002522: 0f 89 03 00 00 00           	jns	0x10000252b <__text+0x152b>
100002528: 48 01 c8                    	addq	%rcx, %rax
10000252b: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002532: 48 01 c3                    	addq	%rax, %rbx
100002535: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000253c: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100002543: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
10000254a: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100002551: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002558: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
10000255f: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100002566: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
10000256d: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100002574: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002579: 45 0f 28 c3                 	movaps	%xmm11, %xmm8
10000257d: f3 44 0f 5c c6              	subss	%xmm6, %xmm8
100002582: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100002589: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000258e: 45 0f 28 cc                 	movaps	%xmm12, %xmm9
100002592: f3 44 0f 5c ce              	subss	%xmm6, %xmm9
100002597: 41 0f 28 f0                 	movaps	%xmm8, %xmm6
10000259b: f3 41 0f 59 f0              	mulss	%xmm8, %xmm6
1000025a0: 45 0f 28 d1                 	movaps	%xmm9, %xmm10
1000025a4: f3 45 0f 59 d1              	mulss	%xmm9, %xmm10
1000025a9: 0f 28 fe                    	movaps	%xmm6, %xmm7
1000025ac: f3 41 0f 58 fa              	addss	%xmm10, %xmm7
1000025b1: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000025bb: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000025c0: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
1000025c3: 0f 87 69 00 00 00           	ja	0x100002632 <__text+0x1632>
1000025c9: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000025d3: 48 89 85 10 02 00 00        	movq	%rax, 0x210(%rbp)
1000025da: 48 8b 85 58 03 00 00        	movq	0x358(%rbp), %rax
1000025e1: 48 8b 8d 10 02 00 00        	movq	0x210(%rbp), %rcx
1000025e8: 48 01 c8                    	addq	%rcx, %rax
1000025eb: 48 89 85 08 02 00 00        	movq	%rax, 0x208(%rbp)
1000025f2: 48 8b 85 08 02 00 00        	movq	0x208(%rbp), %rax
1000025f9: 48 89 85 58 03 00 00        	movq	%rax, 0x358(%rbp)
100002600: e9 a8 fe ff ff              	jmp	0x1000024ad <__text+0x14ad>
100002605: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000260f: 48 89 85 18 02 00 00        	movq	%rax, 0x218(%rbp)
100002616: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
10000261d: 48 8b 8d 18 02 00 00        	movq	0x218(%rbp), %rcx
100002624: 48 39 c8                    	cmpq	%rcx, %rax
100002627: 0f 84 f2 02 00 00           	je	0x10000291f <__text+0x191f>
10000262d: e9 5f 03 00 00              	jmp	0x100002991 <__text+0x1991>
100002632: 48 b8 00 00 a2 45 00 00 00 00       	movabsq	$0x45a20000, %rax ## imm = 0x45A20000
10000263c: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002641: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
100002644: 0f 8a 7f ff ff ff           	jp	0x1000025c9 <__text+0x15c9>
10000264a: 0f 83 79 ff ff ff           	jae	0x1000025c9 <__text+0x15c9>
100002650: 48 8b 85 c0 03 00 00        	movq	0x3c0(%rbp), %rax
100002657: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
10000265e: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100002665: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
10000266c: 48 8b 85 c8 03 00 00        	movq	0x3c8(%rbp), %rax
100002673: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
10000267a: 48 8b 85 c0 00 00 00        	movq	0xc0(%rbp), %rax
100002681: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100002688: f3 0f 10 9d 30 01 00 00     	movss	0x130(%rbp), %xmm3
100002690: f3 0f 10 ad 48 01 00 00     	movss	0x148(%rbp), %xmm5
100002698: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
10000269b: f3 0f 10 a5 38 01 00 00     	movss	0x138(%rbp), %xmm4
1000026a3: f3 0f 10 ad 50 01 00 00     	movss	0x150(%rbp), %xmm5
1000026ab: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
1000026ae: 0f 28 c3                    	movaps	%xmm3, %xmm0
1000026b1: 0f 58 c4                    	addps	%xmm4, %xmm0
1000026b4: f3 0f 11 85 40 01 00 00     	movss	%xmm0, 0x140(%rbp)
1000026bc: 0f 28 e8                    	movaps	%xmm0, %xmm5
1000026bf: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
1000026c3: f3 0f 11 ad 58 01 00 00     	movss	%xmm5, 0x158(%rbp)
1000026cb: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
1000026d2: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
1000026d9: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
1000026e0: 48 89 85 68 01 00 00        	movq	%rax, 0x168(%rbp)
1000026e7: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
1000026ee: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
1000026f5: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
1000026fc: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
100002703: f3 0f 10 9d 60 01 00 00     	movss	0x160(%rbp), %xmm3
10000270b: f3 0f 10 ad 78 01 00 00     	movss	0x178(%rbp), %xmm5
100002713: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002716: f3 0f 10 a5 68 01 00 00     	movss	0x168(%rbp), %xmm4
10000271e: f3 0f 10 ad 80 01 00 00     	movss	0x180(%rbp), %xmm5
100002726: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
100002729: 0f 28 cb                    	movaps	%xmm3, %xmm1
10000272c: 0f 58 cc                    	addps	%xmm4, %xmm1
10000272f: f3 0f 11 8d 70 01 00 00     	movss	%xmm1, 0x170(%rbp)
100002737: 0f 28 e9                    	movaps	%xmm1, %xmm5
10000273a: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
10000273e: f3 0f 11 ad 88 01 00 00     	movss	%xmm5, 0x188(%rbp)
100002746: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002750: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002757: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
10000275e: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
100002765: 48 01 c8                    	addq	%rcx, %rax
100002768: 71 0a                       	jno	0x100002774 <__text+0x1774>
10000276a: ba 01 00 00 00              	movl	$0x1, %edx
10000276f: e9 1e 04 00 00              	jmp	0x100002b92 <__text+0x1b92>
100002774: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
10000277b: 48 b8 00 00 44 44 00 00 00 00       	movabsq	$0x44440000, %rax ## imm = 0x44440000
100002785: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000278a: 0f 2e fe                    	ucomiss	%xmm6, %xmm7
10000278d: 0f 92 c0                    	setb	%al
100002790: 0f 9b c1                    	setnp	%cl
100002793: 20 c8                       	andb	%cl, %al
100002795: 48 0f b6 c0                 	movzbq	%al, %rax
100002799: 48 89 85 a8 01 00 00        	movq	%rax, 0x1a8(%rbp)
1000027a0: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
1000027a7: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
1000027ae: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
1000027b5: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
1000027bc: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000027c3: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
1000027ca: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
1000027d1: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
1000027d8: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000027df: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
1000027e6: 48 8b 85 a8 01 00 00        	movq	0x1a8(%rbp), %rax
1000027ed: 48 85 c0                    	testq	%rax, %rax
1000027f0: 0f 84 d3 fd ff ff           	je	0x1000025c9 <__text+0x15c9>
1000027f6: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100002800: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002805: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
10000280f: 66 4c 0f 6e d0              	movq	%rax, %xmm10
100002814: 41 0f 2e fa                 	ucomiss	%xmm10, %xmm7
100002818: 0f 97 c0                    	seta	%al
10000281b: 48 0f b6 c0                 	movzbq	%al, %rax
10000281f: 48 89 85 c0 01 00 00        	movq	%rax, 0x1c0(%rbp)
100002826: 48 8b 85 c0 01 00 00        	movq	0x1c0(%rbp), %rax
10000282d: 48 85 c0                    	testq	%rax, %rax
100002830: 0f 84 03 00 00 00           	je	0x100002839 <__text+0x1839>
100002836: 0f 28 f7                    	movaps	%xmm7, %xmm6
100002839: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002840: 48 89 85 c8 01 00 00        	movq	%rax, 0x1c8(%rbp)
100002847: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
10000284b: f3 0f 5e c6                 	divss	%xmm6, %xmm0
10000284f: f3 0f 11 85 d8 01 00 00     	movss	%xmm0, 0x1d8(%rbp)
100002857: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
10000285e: 48 89 85 e8 01 00 00        	movq	%rax, 0x1e8(%rbp)
100002865: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
100002869: f3 0f 5e c6                 	divss	%xmm6, %xmm0
10000286d: f3 0f 11 85 f8 01 00 00     	movss	%xmm0, 0x1f8(%rbp)
100002875: f3 0f 10 9d c8 01 00 00     	movss	0x1c8(%rbp), %xmm3
10000287d: f3 0f 10 ad e8 01 00 00     	movss	0x1e8(%rbp), %xmm5
100002885: 0f 14 dd                    	unpcklps	%xmm5, %xmm3            ## xmm3 = xmm3[0],xmm5[0],xmm3[1],xmm5[1]
100002888: f3 0f 10 a5 d8 01 00 00     	movss	0x1d8(%rbp), %xmm4
100002890: f3 0f 10 ad f8 01 00 00     	movss	0x1f8(%rbp), %xmm5
100002898: 0f 14 e5                    	unpcklps	%xmm5, %xmm4            ## xmm4 = xmm4[0],xmm5[0],xmm4[1],xmm5[1]
10000289b: 0f 28 d3                    	movaps	%xmm3, %xmm2
10000289e: 0f 58 d4                    	addps	%xmm4, %xmm2
1000028a1: f3 0f 11 95 e0 01 00 00     	movss	%xmm2, 0x1e0(%rbp)
1000028a9: 0f 28 ea                    	movaps	%xmm2, %xmm5
1000028ac: 0f c6 ed 55                 	shufps	$0x55, %xmm5, %xmm5     ## xmm5 = xmm5[1,1,1,1]
1000028b0: f3 0f 11 ad 00 02 00 00     	movss	%xmm5, 0x200(%rbp)
1000028b8: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
1000028bf: 48 89 85 50 03 00 00        	movq	%rax, 0x350(%rbp)
1000028c6: 48 8b 85 e0 01 00 00        	movq	0x1e0(%rbp), %rax
1000028cd: 48 89 85 b0 03 00 00        	movq	%rax, 0x3b0(%rbp)
1000028d4: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
1000028db: 48 89 85 d8 03 00 00        	movq	%rax, 0x3d8(%rbp)
1000028e2: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
1000028e9: 48 89 85 d0 03 00 00        	movq	%rax, 0x3d0(%rbp)
1000028f0: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000028f7: 48 89 85 c8 03 00 00        	movq	%rax, 0x3c8(%rbp)
1000028fe: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002905: 48 89 85 c0 03 00 00        	movq	%rax, 0x3c0(%rbp)
10000290c: 48 8b 85 00 02 00 00        	movq	0x200(%rbp), %rax
100002913: 48 89 85 b8 03 00 00        	movq	%rax, 0x3b8(%rbp)
10000291a: e9 aa fc ff ff              	jmp	0x1000025c9 <__text+0x15c9>
10000291f: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002929: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
100002930: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000293a: 48 89 85 30 02 00 00        	movq	%rax, 0x230(%rbp)
100002941: 48 8b 85 28 02 00 00        	movq	0x228(%rbp), %rax
100002948: 48 89 85 38 02 00 00        	movq	%rax, 0x238(%rbp)
10000294f: 48 8b 85 30 02 00 00        	movq	0x230(%rbp), %rax
100002956: 48 89 85 40 02 00 00        	movq	%rax, 0x240(%rbp)
10000295d: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002964: 48 8b 85 38 02 00 00        	movq	0x238(%rbp), %rax
10000296b: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002972: 48 8b 85 40 02 00 00        	movq	0x240(%rbp), %rax
100002979: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002980: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000298a: 31 d2                       	xorl	%edx, %edx
10000298c: e9 01 02 00 00              	jmp	0x100002b92 <__text+0x1b92>
100002991: 48 8b 85 50 03 00 00        	movq	0x350(%rbp), %rax
100002998: 48 89 c1                    	movq	%rax, %rcx
10000299b: f3 48 0f 2a d8              	cvtsi2ss	%rax, %xmm3
1000029a0: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
1000029a4: 48 ba 00 00 00 00 00 00 e0 c3       	movabsq	$-0x3c20000000000000, %rdx ## imm = 0xC3E0000000000000
1000029ae: 66 48 0f 6e e2              	movq	%rdx, %xmm4
1000029b3: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
1000029b7: 0f 82 39 00 00 00           	jb	0x1000029f6 <__text+0x19f6>
1000029bd: 48 ba 00 00 00 00 00 00 e0 43       	movabsq	$0x43e0000000000000, %rdx ## imm = 0x43E0000000000000
1000029c7: 66 48 0f 6e e2              	movq	%rdx, %xmm4
1000029cc: 66 0f 2e dc                 	ucomisd	%xmm4, %xmm3
1000029d0: 0f 83 20 00 00 00           	jae	0x1000029f6 <__text+0x19f6>
1000029d6: f2 48 0f 2c c3              	cvttsd2si	%xmm3, %rax
1000029db: 48 39 c8                    	cmpq	%rcx, %rax
1000029de: 0f 85 12 00 00 00           	jne	0x1000029f6 <__text+0x19f6>
1000029e4: f2 0f 5a db                 	cvtsd2ss	%xmm3, %xmm3
1000029e8: 66 0f 7e d8                 	movd	%xmm3, %eax
1000029ec: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000029f1: e9 3d 00 00 00              	jmp	0x100002a33 <__text+0x1a33>
1000029f6: 48 8d 35 2b 1b 00 00        	leaq	0x1b2b(%rip), %rsi      ## 0x100004528
1000029fd: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100002a04: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100002a0b: 4c 89 c2                    	movq	%r8, %rdx
100002a0e: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100002a18: 48 bf 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rdi
100002a22: 0f 05                       	syscall
100002a24: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002a2e: e9 5f 01 00 00              	jmp	0x100002b92 <__text+0x1b92>
100002a33: 48 8b 85 c0 03 00 00        	movq	0x3c0(%rbp), %rax
100002a3a: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002a3f: f3 0f 5e fe                 	divss	%xmm6, %xmm7
100002a43: f3 41 0f 5c fb              	subss	%xmm11, %xmm7
100002a48: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002a52: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002a57: f3 41 0f 59 f8              	mulss	%xmm8, %xmm7
100002a5c: 48 8b 85 d0 03 00 00        	movq	0x3d0(%rbp), %rax
100002a63: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002a68: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
100002a6d: f3 45 0f 5c c5              	subss	%xmm13, %xmm8
100002a72: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002a7c: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002a81: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
100002a86: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
100002a8b: 48 8b 85 b0 03 00 00        	movq	0x3b0(%rbp), %rax
100002a92: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002a97: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002aa1: 66 4c 0f 6e c8              	movq	%rax, %xmm9
100002aa6: f3 45 0f 59 c1              	mulss	%xmm9, %xmm8
100002aab: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002aae: f3 41 0f 58 c0              	addss	%xmm8, %xmm0
100002ab3: f3 0f 11 85 c0 02 00 00     	movss	%xmm0, 0x2c0(%rbp)
100002abb: 48 8b 85 c8 03 00 00        	movq	0x3c8(%rbp), %rax
100002ac2: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002ac7: f3 0f 5e fe                 	divss	%xmm6, %xmm7
100002acb: f3 41 0f 5c fc              	subss	%xmm12, %xmm7
100002ad0: 48 b8 33 33 b3 3e 00 00 00 00       	movabsq	$0x3eb33333, %rax ## imm = 0x3EB33333
100002ada: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002adf: f3 41 0f 59 f8              	mulss	%xmm8, %xmm7
100002ae4: 48 8b 85 d8 03 00 00        	movq	0x3d8(%rbp), %rax
100002aeb: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002af0: f3 44 0f 5e c6              	divss	%xmm6, %xmm8
100002af5: f3 45 0f 5c c6              	subss	%xmm14, %xmm8
100002afa: 48 b8 cd cc 4c 3f 00 00 00 00       	movabsq	$0x3f4ccccd, %rax ## imm = 0x3F4CCCCD
100002b04: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002b09: f3 44 0f 59 c6              	mulss	%xmm6, %xmm8
100002b0e: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
100002b13: 48 8b 85 b8 03 00 00        	movq	0x3b8(%rbp), %rax
100002b1a: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002b1f: 48 b8 00 00 af 44 00 00 00 00       	movabsq	$0x44af0000, %rax ## imm = 0x44AF0000
100002b29: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100002b2e: f3 41 0f 59 f0              	mulss	%xmm8, %xmm6
100002b33: 0f 28 c7                    	movaps	%xmm7, %xmm0
100002b36: f3 0f 58 c6                 	addss	%xmm6, %xmm0
100002b3a: f3 0f 11 85 38 03 00 00     	movss	%xmm0, 0x338(%rbp)
100002b42: 48 8b 85 c0 02 00 00        	movq	0x2c0(%rbp), %rax
100002b49: 48 89 85 40 03 00 00        	movq	%rax, 0x340(%rbp)
100002b50: 48 8b 85 38 03 00 00        	movq	0x338(%rbp), %rax
100002b57: 48 89 85 48 03 00 00        	movq	%rax, 0x348(%rbp)
100002b5e: 4c 8b bd 30 00 00 00        	movq	0x30(%rbp), %r15
100002b65: 48 8b 85 40 03 00 00        	movq	0x340(%rbp), %rax
100002b6c: 49 89 87 00 00 00 00        	movq	%rax, (%r15)
100002b73: 48 8b 85 48 03 00 00        	movq	0x348(%rbp), %rax
100002b7a: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
100002b81: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002b8b: 31 d2                       	xorl	%edx, %edx
100002b8d: e9 00 00 00 00              	jmp	0x100002b92 <__text+0x1b92>
100002b92: 48 89 ec                    	movq	%rbp, %rsp
100002b95: 48 81 c4 00 04 00 00        	addq	$0x400, %rsp            ## imm = 0x400
100002b9c: 5d                          	popq	%rbp
100002b9d: c3                          	retq
100002b9e: 55                          	pushq	%rbp
100002b9f: 48 89 e5                    	movq	%rsp, %rbp
100002ba2: 48 81 ec b0 01 00 00        	subq	$0x1b0, %rsp            ## imm = 0x1B0
100002ba9: 48 89 e5                    	movq	%rsp, %rbp
100002bac: 48 89 95 18 00 00 00        	movq	%rdx, 0x18(%rbp)
100002bb3: 48 8b 86 00 00 00 00        	movq	(%rsi), %rax
100002bba: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100002bc1: 48 8b 86 08 00 00 00        	movq	0x8(%rsi), %rax
100002bc8: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
100002bcf: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
100002bd6: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002be0: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002be5: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002bef: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100002bf6: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002bfd: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002c04: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100002c0b: 48 8b 8d 30 00 00 00        	movq	0x30(%rbp), %rcx
100002c12: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002c19: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100002c20: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
100002c2a: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
100002c31: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002c38: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100002c3f: 48 39 c8                    	cmpq	%rcx, %rax
100002c42: 0f 9c c0                    	setl	%al
100002c45: 48 0f b6 c0                 	movzbq	%al, %rax
100002c49: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100002c50: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002c57: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100002c5e: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
100002c65: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002c6c: 66 48 0f 7e f0              	movq	%xmm6, %rax
100002c71: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002c78: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
100002c7f: 48 85 c0                    	testq	%rax, %rax
100002c82: 0f 84 39 00 00 00           	je	0x100002cc1 <__text+0x1cc1>
100002c88: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100002c92: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100002c99: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
100002ca0: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100002ca7: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
100002cae: 48 89 85 90 01 00 00        	movq	%rax, 0x190(%rbp)
100002cb5: 66 48 0f 7e f0              	movq	%xmm6, %rax
100002cba: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
100002cc1: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002cc8: 48 8b 8d 38 00 00 00        	movq	0x38(%rbp), %rcx
100002ccf: 48 39 c8                    	cmpq	%rcx, %rax
100002cd2: 0f 84 8c 05 00 00           	je	0x100003264 <__text+0x2264>
100002cd8: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002cdf: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002ce6: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100002ced: 48 8b 9d 60 00 00 00        	movq	0x60(%rbp), %rbx
100002cf4: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100002cfb: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100002d02: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002d09: 48 85 c0                    	testq	%rax, %rax
100002d0c: 0f 89 03 00 00 00           	jns	0x100002d15 <__text+0x1d15>
100002d12: 48 01 c8                    	addq	%rcx, %rax
100002d15: 48 39 c8                    	cmpq	%rcx, %rax
100002d18: 0f 82 0f 00 00 00           	jb	0x100002d2d <__text+0x1d2d>
100002d1e: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002d28: e9 53 05 00 00              	jmp	0x100003280 <__text+0x2280>
100002d2d: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002d34: 48 01 c3                    	addq	%rax, %rbx
100002d37: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002d3e: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100002d45: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002d4c: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100002d53: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002d5a: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100002d61: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100002d68: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100002d6f: 4c 8d bd 88 00 00 00        	leaq	0x88(%rbp), %r15
100002d76: 48 8d bd 68 00 00 00        	leaq	0x68(%rbp), %rdi
100002d7d: 48 8d b5 08 00 00 00        	leaq	0x8(%rbp), %rsi
100002d84: e8 77 f5 ff ff              	callq	0x100002300 <__text+0x1300>
100002d89: 48 85 d2                    	testq	%rdx, %rdx
100002d8c: 0f 85 ee 04 00 00           	jne	0x100003280 <__text+0x2280>
100002d92: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
100002d99: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002d9e: 48 8b 85 88 00 00 00        	movq	0x88(%rbp), %rax
100002da5: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002daa: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002db2: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002db6: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002db9: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002dbd: f3 0f 11 85 b0 00 00 00     	movss	%xmm0, 0xb0(%rbp)
100002dc5: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100002dcc: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002dd1: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100002dd8: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002ddd: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002de5: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002de9: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002dec: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002df0: f3 0f 11 85 d0 00 00 00     	movss	%xmm0, 0xd0(%rbp)
100002df8: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100002dff: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002e04: f3 0f 10 85 b0 00 00 00     	movss	0xb0(%rbp), %xmm0
100002e0c: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002e14: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002e17: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002e1b: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002e1e: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002e22: f3 0f 11 85 e8 00 00 00     	movss	%xmm0, 0xe8(%rbp)
100002e2a: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
100002e31: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002e36: f3 0f 10 85 d0 00 00 00     	movss	0xd0(%rbp), %xmm0
100002e3e: f3 0f 10 8d 18 00 00 00     	movss	0x18(%rbp), %xmm1
100002e46: 0f 28 f8                    	movaps	%xmm0, %xmm7
100002e49: f3 0f 59 f9                 	mulss	%xmm1, %xmm7
100002e4d: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002e50: f3 0f 58 c7                 	addss	%xmm7, %xmm0
100002e54: f3 0f 11 85 00 01 00 00     	movss	%xmm0, 0x100(%rbp)
100002e5c: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002e63: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002e6a: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100002e71: 48 8b 9d 08 01 00 00        	movq	0x108(%rbp), %rbx
100002e78: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100002e7f: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100002e86: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100002e8d: 48 85 c0                    	testq	%rax, %rax
100002e90: 0f 89 03 00 00 00           	jns	0x100002e99 <__text+0x1e99>
100002e96: 48 01 c8                    	addq	%rcx, %rax
100002e99: 48 39 c8                    	cmpq	%rcx, %rax
100002e9c: 0f 82 0f 00 00 00           	jb	0x100002eb1 <__text+0x1eb1>
100002ea2: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002eac: e9 cf 03 00 00              	jmp	0x100003280 <__text+0x2280>
100002eb1: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002eb8: 48 01 c3                    	addq	%rax, %rbx
100002ebb: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
100002ec2: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100002ec9: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002ed0: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100002ed7: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100002ede: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100002ee5: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100002eec: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100002ef3: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100002efa: 48 89 85 30 01 00 00        	movq	%rax, 0x130(%rbp)
100002f01: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
100002f08: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
100002f0f: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100002f16: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
100002f1d: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
100002f24: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
100002f2b: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100002f32: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100002f39: 48 89 85 50 01 00 00        	movq	%rax, 0x150(%rbp)
100002f40: 48 8b 9d 50 01 00 00        	movq	0x150(%rbp), %rbx
100002f47: 4c 8b a3 00 00 00 00        	movq	(%rbx), %r12
100002f4e: 4c 8b ad 88 01 00 00        	movq	0x188(%rbp), %r13
100002f55: 4d 85 ed                    	testq	%r13, %r13
100002f58: 0f 89 03 00 00 00           	jns	0x100002f61 <__text+0x1f61>
100002f5e: 4d 01 e5                    	addq	%r12, %r13
100002f61: 4d 39 e5                    	cmpq	%r12, %r13
100002f64: 0f 82 0f 00 00 00           	jb	0x100002f79 <__text+0x1f79>
100002f6a: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100002f74: e9 07 03 00 00              	jmp	0x100003280 <__text+0x2280>
100002f79: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
100002f80: 4c 8b 9b 10 00 00 00        	movq	0x10(%rbx), %r11
100002f87: 4c 01 d8                    	addq	%r11, %rax
100002f8a: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100002f94: 48 39 c8                    	cmpq	%rcx, %rax
100002f97: 0f 85 5b 00 00 00           	jne	0x100002ff8 <__text+0x1ff8>
100002f9d: 49 89 de                    	movq	%rbx, %r14
100002fa0: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
100002fa7: 4c 89 e8                    	movq	%r13, %rax
100002faa: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100002fb1: 49 01 c6                    	addq	%rax, %r14
100002fb4: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
100002fbb: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100002fc2: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
100002fc9: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100002fd0: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100002fd7: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100002fde: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100002fe5: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
100002fec: 48 89 9d 58 01 00 00        	movq	%rbx, 0x158(%rbp)
100002ff3: e9 ed 01 00 00              	jmp	0x1000031e5 <__text+0x21e5>
100002ff8: 4c 89 e6                    	movq	%r12, %rsi
100002ffb: 48 b9 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rcx
100003005: 48 0f af f1                 	imulq	%rcx, %rsi
100003009: 48 81 c6 28 00 00 00        	addq	$0x28, %rsi
100003010: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
10000301a: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003024: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
10000302e: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
100003038: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
100003042: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
10000304c: 0f 05                       	syscall
10000304e: 0f 83 0f 00 00 00           	jae	0x100003063 <__text+0x2063>
100003054: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000305e: e9 1d 02 00 00              	jmp	0x100003280 <__text+0x2280>
100003063: 49 89 c7                    	movq	%rax, %r15
100003066: 4d 89 a7 00 00 00 00        	movq	%r12, (%r15)
10000306d: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003077: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
10000307e: 49 89 87 10 00 00 00        	movq	%rax, 0x10(%r15)
100003085: 49 89 87 20 00 00 00        	movq	%rax, 0x20(%r15)
10000308c: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
100003096: 49 89 87 08 00 00 00        	movq	%rax, 0x8(%r15)
10000309d: 49 89 b7 18 00 00 00        	movq	%rsi, 0x18(%r15)
1000030a4: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000030ab: 4d 89 fe                    	movq	%r15, %r14
1000030ae: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000030b5: 4c 89 e6                    	movq	%r12, %rsi
1000030b8: 48 b9 04 00 00 00 00 00 00 00       	movabsq	$0x4, %rcx
1000030c2: 48 0f af f1                 	imulq	%rcx, %rsi
1000030c6: 48 85 f6                    	testq	%rsi, %rsi
1000030c9: 0f 84 20 00 00 00           	je	0x1000030ef <__text+0x20ef>
1000030cf: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000030d6: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
1000030dd: 48 83 c3 08                 	addq	$0x8, %rbx
1000030e1: 49 83 c6 08                 	addq	$0x8, %r14
1000030e5: 48 83 ee 01                 	subq	$0x1, %rsi
1000030e9: 0f 85 e0 ff ff ff           	jne	0x1000030cf <__text+0x20cf>
1000030ef: 4d 89 fe                    	movq	%r15, %r14
1000030f2: 49 81 c6 28 00 00 00        	addq	$0x28, %r14
1000030f9: 4c 89 e8                    	movq	%r13, %rax
1000030fc: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003103: 49 01 c6                    	addq	%rax, %r14
100003106: 48 8b 85 30 01 00 00        	movq	0x130(%rbp), %rax
10000310d: 49 89 86 00 00 00 00        	movq	%rax, (%r14)
100003114: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
10000311b: 49 89 86 08 00 00 00        	movq	%rax, 0x8(%r14)
100003122: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
100003129: 49 89 86 10 00 00 00        	movq	%rax, 0x10(%r14)
100003130: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
100003137: 49 89 86 18 00 00 00        	movq	%rax, 0x18(%r14)
10000313e: 4c 89 bd 58 01 00 00        	movq	%r15, 0x158(%rbp)
100003145: 4c 8b 95 50 01 00 00        	movq	0x150(%rbp), %r10
10000314c: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003153: 48 85 c0                    	testq	%rax, %rax
100003156: 0f 84 89 00 00 00           	je	0x1000031e5 <__text+0x21e5>
10000315c: 49 89 c3                    	movq	%rax, %r11
10000315f: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003166: f0                          	lock
100003167: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
10000316c: 0f 85 da ff ff ff           	jne	0x10000314c <__text+0x214c>
100003172: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003179: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003180: 4c 01 d8                    	addq	%r11, %rax
100003183: 48 85 c0                    	testq	%rax, %rax
100003186: 0f 85 59 00 00 00           	jne	0x1000031e5 <__text+0x21e5>
10000318c: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003193: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
10000319d: 48 39 c8                    	cmpq	%rcx, %rax
1000031a0: 0f 84 e6 ff ff ff           	je	0x10000318c <__text+0x218c>
1000031a6: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000031b0: 48 39 c8                    	cmpq	%rcx, %rax
1000031b3: 0f 84 2c 00 00 00           	je	0x1000031e5 <__text+0x21e5>
1000031b9: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000031c3: f0                          	lock
1000031c4: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000031c9: 0f 85 bd ff ff ff           	jne	0x10000318c <__text+0x218c>
1000031cf: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000031d6: 4c 89 d7                    	movq	%r10, %rdi
1000031d9: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
1000031e3: 0f 05                       	syscall
1000031e5: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
1000031ec: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
1000031f3: 48 89 81 00 00 00 00        	movq	%rax, (%rcx)
1000031fa: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
100003201: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003206: f3 0f 10 85 e8 00 00 00     	movss	0xe8(%rbp), %xmm0
10000320e: f3 0f 10 8d 00 01 00 00     	movss	0x100(%rbp), %xmm1
100003216: 0f 28 f8                    	movaps	%xmm0, %xmm7
100003219: f3 0f 58 f9                 	addss	%xmm1, %xmm7
10000321d: f3 0f 58 f7                 	addss	%xmm7, %xmm6
100003221: 48 8b 85 88 01 00 00        	movq	0x188(%rbp), %rax
100003228: 48 8b 8d 90 01 00 00        	movq	0x190(%rbp), %rcx
10000322f: 48 01 c8                    	addq	%rcx, %rax
100003232: 71 0a                       	jno	0x10000323e <__text+0x223e>
100003234: ba 01 00 00 00              	movl	$0x1, %edx
100003239: e9 42 00 00 00              	jmp	0x100003280 <__text+0x2280>
10000323e: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
100003245: 48 8b 85 78 01 00 00        	movq	0x178(%rbp), %rax
10000324c: 48 89 85 88 01 00 00        	movq	%rax, 0x188(%rbp)
100003253: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003258: 48 89 85 98 01 00 00        	movq	%rax, 0x198(%rbp)
10000325f: e9 5d fa ff ff              	jmp	0x100002cc1 <__text+0x1cc1>
100003264: 48 8b 85 98 01 00 00        	movq	0x198(%rbp), %rax
10000326b: 48 89 85 80 01 00 00        	movq	%rax, 0x180(%rbp)
100003272: 48 8b 85 80 01 00 00        	movq	0x180(%rbp), %rax
100003279: 31 d2                       	xorl	%edx, %edx
10000327b: e9 00 00 00 00              	jmp	0x100003280 <__text+0x2280>
100003280: 48 89 ec                    	movq	%rbp, %rsp
100003283: 48 81 c4 b0 01 00 00        	addq	$0x1b0, %rsp            ## imm = 0x1B0
10000328a: 5d                          	popq	%rbp
10000328b: c3                          	retq
10000328c: 55                          	pushq	%rbp
10000328d: 48 89 e5                    	movq	%rsp, %rbp
100003290: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
100003297: 48 89 e5                    	movq	%rsp, %rbp
10000329a: 48 89 b5 10 00 00 00        	movq	%rsi, 0x10(%rbp)
1000032a1: 48 8b 87 00 00 00 00        	movq	(%rdi), %rax
1000032a8: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
1000032af: 48 8b 87 08 00 00 00        	movq	0x8(%rdi), %rax
1000032b6: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
1000032bd: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000032c7: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000032cc: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000032d6: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
1000032dd: 48 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %rax
1000032e7: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000032ee: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
1000032f5: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
1000032fc: 48 39 c8                    	cmpq	%rcx, %rax
1000032ff: 0f 9c c0                    	setl	%al
100003302: 48 0f b6 c0                 	movzbq	%al, %rax
100003306: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
10000330d: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100003314: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
10000331b: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
100003322: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003329: 66 48 0f 7e f0              	movq	%xmm6, %rax
10000332e: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003335: 48 8b 85 40 00 00 00        	movq	0x40(%rbp), %rax
10000333c: 48 85 c0                    	testq	%rax, %rax
10000333f: 0f 84 39 00 00 00           	je	0x10000337e <__text+0x237e>
100003345: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000334f: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003356: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
10000335d: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100003364: 48 8b 85 48 00 00 00        	movq	0x48(%rbp), %rax
10000336b: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100003372: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003377: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
10000337e: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100003385: 48 8b 8d 10 00 00 00        	movq	0x10(%rbp), %rcx
10000338c: 48 39 c8                    	cmpq	%rcx, %rax
10000338f: 0f 84 93 00 00 00           	je	0x100003428 <__text+0x2428>
100003395: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
10000339c: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
1000033a3: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
1000033aa: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
1000033b1: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000033bb: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000033c2: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000033c9: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
1000033d0: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
1000033d7: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000033de: e9 61 00 00 00              	jmp	0x100003444 <__text+0x2444>
1000033e3: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
1000033ea: 48 8b 8d 10 01 00 00        	movq	0x110(%rbp), %rcx
1000033f1: 48 01 c8                    	addq	%rcx, %rax
1000033f4: 71 0a                       	jno	0x100003400 <__text+0x2400>
1000033f6: ba 01 00 00 00              	movl	$0x1, %edx
1000033fb: e9 9c 01 00 00              	jmp	0x10000359c <__text+0x259c>
100003400: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
100003407: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
10000340e: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
100003415: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
10000341c: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003423: e9 56 ff ff ff              	jmp	0x10000337e <__text+0x237e>
100003428: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
10000342f: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100003436: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
10000343d: 31 d2                       	xorl	%edx, %edx
10000343f: e9 58 01 00 00              	jmp	0x10000359c <__text+0x259c>
100003444: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
10000344b: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100003452: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100003459: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100003460: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100003467: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
10000346e: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
100003475: 48 8b 8d 70 00 00 00        	movq	0x70(%rbp), %rcx
10000347c: 48 39 c8                    	cmpq	%rcx, %rax
10000347f: 0f 8d 5e ff ff ff           	jge	0x1000033e3 <__text+0x23e3>
100003485: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
10000348c: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100003493: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
10000349a: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000034a1: 48 8b 9d 80 00 00 00        	movq	0x80(%rbp), %rbx
1000034a8: 48 8b 8d 88 00 00 00        	movq	0x88(%rbp), %rcx
1000034af: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
1000034b6: 48 85 c0                    	testq	%rax, %rax
1000034b9: 0f 89 03 00 00 00           	jns	0x1000034c2 <__text+0x24c2>
1000034bf: 48 01 c8                    	addq	%rcx, %rax
1000034c2: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000034c9: 48 01 c3                    	addq	%rax, %rbx
1000034cc: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
1000034d3: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
1000034da: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
1000034e1: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
1000034e8: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
1000034ef: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
1000034f6: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
1000034fd: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100003504: 4c 8d bd b0 00 00 00        	leaq	0xb0(%rbp), %r15
10000350b: 48 8d bd 90 00 00 00        	leaq	0x90(%rbp), %rdi
100003512: 48 8d b5 00 00 00 00        	leaq	(%rbp), %rsi
100003519: e8 e2 ed ff ff              	callq	0x100002300 <__text+0x1300>
10000351e: 48 85 d2                    	testq	%rdx, %rdx
100003521: 0f 85 75 00 00 00           	jne	0x10000359c <__text+0x259c>
100003527: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
10000352e: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003533: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
10000353a: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000353f: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
100003546: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000354b: f3 41 0f 58 f8              	addss	%xmm8, %xmm7
100003550: f3 0f 58 f7                 	addss	%xmm7, %xmm6
100003554: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000355e: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003565: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
10000356c: 48 8b 8d f0 00 00 00        	movq	0xf0(%rbp), %rcx
100003573: 48 01 c8                    	addq	%rcx, %rax
100003576: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
10000357d: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100003584: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
10000358b: 66 48 0f 7e f0              	movq	%xmm6, %rax
100003590: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
100003597: e9 a8 fe ff ff              	jmp	0x100003444 <__text+0x2444>
10000359c: 48 89 ec                    	movq	%rbp, %rsp
10000359f: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
1000035a6: 5d                          	popq	%rbp
1000035a7: c3                          	retq
1000035a8: 55                          	pushq	%rbp
1000035a9: 48 89 e5                    	movq	%rsp, %rbp
1000035ac: 48 81 ec 40 01 00 00        	subq	$0x140, %rsp            ## imm = 0x140
1000035b3: 48 89 e5                    	movq	%rsp, %rbp
1000035b6: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
1000035c0: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
1000035c7: 48 8b bd 00 00 00 00        	movq	(%rbp), %rdi
1000035ce: e8 2d da ff ff              	callq	0x100001000 <__text>
1000035d3: 48 85 d2                    	testq	%rdx, %rdx
1000035d6: 0f 85 f1 05 00 00           	jne	0x100003bcd <__text+0x2bcd>
1000035dc: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
1000035e3: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000035ed: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
1000035f4: 48 8b 8d 08 00 00 00        	movq	0x8(%rbp), %rcx
1000035fb: 48 8b 81 00 00 00 00        	movq	(%rcx), %rax
100003602: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
100003609: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
100003610: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
100003617: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
10000361e: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
100003625: 48 85 c0                    	testq	%rax, %rax
100003628: 0f 89 03 00 00 00           	jns	0x100003631 <__text+0x2631>
10000362e: 48 01 c8                    	addq	%rcx, %rax
100003631: 48 85 c0                    	testq	%rax, %rax
100003634: 0f 89 0a 00 00 00           	jns	0x100003644 <__text+0x2644>
10000363a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003644: 48 39 c8                    	cmpq	%rcx, %rax
100003647: 0f 8e 03 00 00 00           	jle	0x100003650 <__text+0x2650>
10000364d: 48 89 c8                    	movq	%rcx, %rax
100003650: 48 8b 95 18 00 00 00        	movq	0x18(%rbp), %rdx
100003657: 48 85 d2                    	testq	%rdx, %rdx
10000365a: 0f 89 03 00 00 00           	jns	0x100003663 <__text+0x2663>
100003660: 48 01 ca                    	addq	%rcx, %rdx
100003663: 48 85 d2                    	testq	%rdx, %rdx
100003666: 0f 89 0a 00 00 00           	jns	0x100003676 <__text+0x2676>
10000366c: 48 ba 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdx
100003676: 48 39 ca                    	cmpq	%rcx, %rdx
100003679: 0f 8e 03 00 00 00           	jle	0x100003682 <__text+0x2682>
10000367f: 48 89 ca                    	movq	%rcx, %rdx
100003682: 49 bb 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r11
10000368c: 48 39 d0                    	cmpq	%rdx, %rax
10000368f: 0f 8d 06 00 00 00           	jge	0x10000369b <__text+0x269b>
100003695: 49 89 d3                    	movq	%rdx, %r11
100003698: 49 29 c3                    	subq	%rax, %r11
10000369b: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
1000036a2: 48 01 c3                    	addq	%rax, %rbx
1000036a5: 48 89 9d 20 00 00 00        	movq	%rbx, 0x20(%rbp)
1000036ac: 4c 89 9d 28 00 00 00        	movq	%r11, 0x28(%rbp)
1000036b3: 48 b8 e8 03 00 00 00 00 00 00       	movabsq	$0x3e8, %rax    ## imm = 0x3E8
1000036bd: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
1000036c4: 48 8b bd 30 00 00 00        	movq	0x30(%rbp), %rdi
1000036cb: e8 30 d9 ff ff              	callq	0x100001000 <__text>
1000036d0: 48 85 d2                    	testq	%rdx, %rdx
1000036d3: 0f 85 f4 04 00 00           	jne	0x100003bcd <__text+0x2bcd>
1000036d9: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
1000036e0: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
1000036e7: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000036ee: 48 b8 20 00 00 00 00 00 00 00       	movabsq	$0x20, %rax
1000036f8: 48 89 85 40 00 00 00        	movq	%rax, 0x40(%rbp)
1000036ff: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
100003706: 48 8b b5 40 00 00 00        	movq	0x40(%rbp), %rsi
10000370d: e8 e1 e1 ff ff              	callq	0x1000018f3 <__text+0x8f3>
100003712: 48 85 d2                    	testq	%rdx, %rdx
100003715: 0f 85 b2 04 00 00           	jne	0x100003bcd <__text+0x2bcd>
10000371b: 48 89 85 48 00 00 00        	movq	%rax, 0x48(%rbp)
100003722: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000372c: 66 48 0f 6e f0              	movq	%rax, %xmm6
100003731: f3 0f 10 85 48 00 00 00     	movss	0x48(%rbp), %xmm0
100003739: 0f 2e c6                    	ucomiss	%xmm6, %xmm0
10000373c: 0f 97 c0                    	seta	%al
10000373f: 48 0f b6 c0                 	movzbq	%al, %rax
100003743: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
10000374a: 48 b8 00 01 00 00 00 00 00 00       	movabsq	$0x100, %rax    ## imm = 0x100
100003754: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
10000375b: 48 8d bd 20 00 00 00        	leaq	0x20(%rbp), %rdi
100003762: 48 8b b5 60 00 00 00        	movq	0x60(%rbp), %rsi
100003769: e8 1e fb ff ff              	callq	0x10000328c <__text+0x228c>
10000376e: 48 85 d2                    	testq	%rdx, %rdx
100003771: 0f 85 56 04 00 00           	jne	0x100003bcd <__text+0x2bcd>
100003777: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
10000377e: f3 0f 10 85 68 00 00 00     	movss	0x68(%rbp), %xmm0
100003786: f3 0f 10 8d 68 00 00 00     	movss	0x68(%rbp), %xmm1
10000378e: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
100003791: 0f 94 c0                    	sete	%al
100003794: 0f 9b c1                    	setnp	%cl
100003797: 20 c8                       	andb	%cl, %al
100003799: 48 0f b6 c0                 	movzbq	%al, %rax
10000379d: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
1000037a4: 48 b8 89 88 08 3c 00 00 00 00       	movabsq	$0x3c088889, %rax ## imm = 0x3C088889
1000037ae: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
1000037b5: 48 8d 85 28 01 00 00        	leaq	0x128(%rbp), %rax
1000037bc: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
1000037c3: 48 8b bd 80 00 00 00        	movq	0x80(%rbp), %rdi
1000037ca: 48 8d b5 20 00 00 00        	leaq	0x20(%rbp), %rsi
1000037d1: 48 8b 95 78 00 00 00        	movq	0x78(%rbp), %rdx
1000037d8: e8 c1 f3 ff ff              	callq	0x100002b9e <__text+0x1b9e>
1000037dd: 48 85 d2                    	testq	%rdx, %rdx
1000037e0: 0f 85 e7 03 00 00           	jne	0x100003bcd <__text+0x2bcd>
1000037e6: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000037ed: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000037f7: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000037fc: f3 0f 10 85 88 00 00 00     	movss	0x88(%rbp), %xmm0
100003804: 0f 2e c6                    	ucomiss	%xmm6, %xmm0
100003807: 0f 86 75 01 00 00           	jbe	0x100003982 <__text+0x2982>
10000380d: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003814: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
10000381b: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100003825: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
10000382c: 48 8b 9d a8 00 00 00        	movq	0xa8(%rbp), %rbx
100003833: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
10000383a: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100003841: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100003848: 48 85 c0                    	testq	%rax, %rax
10000384b: 0f 89 03 00 00 00           	jns	0x100003854 <__text+0x2854>
100003851: 48 01 c8                    	addq	%rcx, %rax
100003854: 48 39 c8                    	cmpq	%rcx, %rax
100003857: 0f 82 0f 00 00 00           	jb	0x10000386c <__text+0x286c>
10000385d: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003867: e9 61 03 00 00              	jmp	0x100003bcd <__text+0x2bcd>
10000386c: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003873: 48 01 c3                    	addq	%rax, %rbx
100003876: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000387d: 48 89 85 b8 00 00 00        	movq	%rax, 0xb8(%rbp)
100003884: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
10000388b: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100003892: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003899: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
1000038a0: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
1000038a7: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
1000038ae: 48 8b 85 b8 00 00 00        	movq	0xb8(%rbp), %rax
1000038b5: 66 48 0f 6e f0              	movq	%rax, %xmm6
1000038ba: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000038c4: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
1000038cb: 48 8b 9d 08 00 00 00        	movq	0x8(%rbp), %rbx
1000038d2: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
1000038d9: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
1000038e0: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
1000038e7: 48 85 c0                    	testq	%rax, %rax
1000038ea: 0f 89 03 00 00 00           	jns	0x1000038f3 <__text+0x28f3>
1000038f0: 48 01 c8                    	addq	%rcx, %rax
1000038f3: 48 39 c8                    	cmpq	%rcx, %rax
1000038f6: 0f 82 0f 00 00 00           	jb	0x10000390b <__text+0x290b>
1000038fc: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100003906: e9 c2 02 00 00              	jmp	0x100003bcd <__text+0x2bcd>
10000390b: 48 69 c0 20 00 00 00        	imulq	$0x20, %rax, %rax
100003912: 48 01 c3                    	addq	%rax, %rbx
100003915: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000391c: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
100003923: 48 8b 83 08 00 00 00        	movq	0x8(%rbx), %rax
10000392a: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
100003931: 48 8b 83 10 00 00 00        	movq	0x10(%rbx), %rax
100003938: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
10000393f: 48 8b 83 18 00 00 00        	movq	0x18(%rbx), %rax
100003946: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
10000394d: 48 8b 85 e8 00 00 00        	movq	0xe8(%rbp), %rax
100003954: 66 48 0f 6e f8              	movq	%rax, %xmm7
100003959: 0f 2e f7                    	ucomiss	%xmm7, %xmm6
10000395c: 0f 95 c0                    	setne	%al
10000395f: 0f 9a c1                    	setp	%cl
100003962: 08 c8                       	orb	%cl, %al
100003964: 48 0f b6 c0                 	movzbq	%al, %rax
100003968: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
10000396f: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
100003976: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
10000397d: e9 11 00 00 00              	jmp	0x100003993 <__text+0x2993>
100003982: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000398c: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100003993: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
10000399a: 48 85 c0                    	testq	%rax, %rax
10000399d: 0f 84 23 00 00 00           	je	0x1000039c6 <__text+0x29c6>
1000039a3: 48 8b 85 70 00 00 00        	movq	0x70(%rbp), %rax
1000039aa: 48 85 c0                    	testq	%rax, %rax
1000039ad: 0f 84 13 00 00 00           	je	0x1000039c6 <__text+0x29c6>
1000039b3: 48 8b 85 a0 00 00 00        	movq	0xa0(%rbp), %rax
1000039ba: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
1000039c1: e9 11 00 00 00              	jmp	0x1000039d7 <__text+0x29d7>
1000039c6: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000039d0: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
1000039d7: 48 8b 85 18 01 00 00        	movq	0x118(%rbp), %rax
1000039de: 48 85 c0                    	testq	%rax, %rax
1000039e1: 0f 84 33 00 00 00           	je	0x100003a1a <__text+0x2a1a>
1000039e7: 48 8d 35 22 06 00 00        	leaq	0x622(%rip), %rsi       ## 0x100004010
1000039ee: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000039f5: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000039fc: 4c 89 c2                    	movq	%r8, %rdx
1000039ff: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003a09: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003a13: 0f 05                       	syscall
100003a15: e9 2e 00 00 00              	jmp	0x100003a48 <__text+0x2a48>
100003a1a: 48 8d 35 ff 05 00 00        	leaq	0x5ff(%rip), %rsi       ## 0x100004020
100003a21: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003a28: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003a2f: 4c 89 c2                    	movq	%r8, %rdx
100003a32: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003a3c: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003a46: 0f 05                       	syscall
100003a48: 48 8d 35 b1 05 00 00        	leaq	0x5b1(%rip), %rsi       ## 0x100004000
100003a4f: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100003a56: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100003a5d: 4c 89 c2                    	movq	%r8, %rdx
100003a60: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100003a6a: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100003a74: 0f 05                       	syscall
100003a76: 48 8b 85 28 01 00 00        	movq	0x128(%rbp), %rax
100003a7d: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100003a84: 4c 8b 95 20 01 00 00        	movq	0x120(%rbp), %r10
100003a8b: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003a92: 48 85 c0                    	testq	%rax, %rax
100003a95: 0f 84 89 00 00 00           	je	0x100003b24 <__text+0x2b24>
100003a9b: 49 89 c3                    	movq	%rax, %r11
100003a9e: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003aa5: f0                          	lock
100003aa6: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003aab: 0f 85 da ff ff ff           	jne	0x100003a8b <__text+0x2a8b>
100003ab1: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003ab8: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003abf: 4c 01 d8                    	addq	%r11, %rax
100003ac2: 48 85 c0                    	testq	%rax, %rax
100003ac5: 0f 85 59 00 00 00           	jne	0x100003b24 <__text+0x2b24>
100003acb: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003ad2: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003adc: 48 39 c8                    	cmpq	%rcx, %rax
100003adf: 0f 84 e6 ff ff ff           	je	0x100003acb <__text+0x2acb>
100003ae5: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003aef: 48 39 c8                    	cmpq	%rcx, %rax
100003af2: 0f 84 2c 00 00 00           	je	0x100003b24 <__text+0x2b24>
100003af8: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100003b02: f0                          	lock
100003b03: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003b08: 0f 85 bd ff ff ff           	jne	0x100003acb <__text+0x2acb>
100003b0e: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100003b15: 4c 89 d7                    	movq	%r10, %rdi
100003b18: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100003b22: 0f 05                       	syscall
100003b24: 4c 8b 95 08 00 00 00        	movq	0x8(%rbp), %r10
100003b2b: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003b32: 48 85 c0                    	testq	%rax, %rax
100003b35: 0f 84 89 00 00 00           	je	0x100003bc4 <__text+0x2bc4>
100003b3b: 49 89 c3                    	movq	%rax, %r11
100003b3e: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100003b45: f0                          	lock
100003b46: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100003b4b: 0f 85 da ff ff ff           	jne	0x100003b2b <__text+0x2b2b>
100003b51: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100003b58: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100003b5f: 4c 01 d8                    	addq	%r11, %rax
100003b62: 48 85 c0                    	testq	%rax, %rax
100003b65: 0f 85 59 00 00 00           	jne	0x100003bc4 <__text+0x2bc4>
100003b6b: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
100003b72: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100003b7c: 48 39 c8                    	cmpq	%rcx, %rax
100003b7f: 0f 84 e6 ff ff ff           	je	0x100003b6b <__text+0x2b6b>
100003b85: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100003b8f: 48 39 c8                    	cmpq	%rcx, %rax
100003b92: 0f 84 2c 00 00 00           	je	0x100003bc4 <__text+0x2bc4>
100003b98: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100003ba2: f0                          	lock
100003ba3: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
100003ba8: 0f 85 bd ff ff ff           	jne	0x100003b6b <__text+0x2b6b>
100003bae: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
100003bb5: 4c 89 d7                    	movq	%r10, %rdi
100003bb8: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100003bc2: 0f 05                       	syscall
100003bc4: 31 c0                       	xorl	%eax, %eax
100003bc6: 31 d2                       	xorl	%edx, %edx
100003bc8: e9 00 00 00 00              	jmp	0x100003bcd <__text+0x2bcd>
100003bcd: 48 89 ec                    	movq	%rbp, %rsp
100003bd0: 48 81 c4 40 01 00 00        	addq	$0x140, %rsp            ## imm = 0x140
100003bd7: 5d                          	popq	%rbp
100003bd8: c3                          	retq
100003bd9: 53                          	pushq	%rbx
100003bda: 41 54                       	pushq	%r12
100003bdc: 41 55                       	pushq	%r13
100003bde: 41 56                       	pushq	%r14
100003be0: 41 57                       	pushq	%r15
100003be2: e8 c1 f9 ff ff              	callq	0x1000035a8 <__text+0x25a8>
100003be7: 48 85 d2                    	testq	%rdx, %rdx
100003bea: 0f 95 c2                    	setne	%dl
100003bed: 0f b6 d2                    	movzbl	%dl, %edx
100003bf0: 48 89 d0                    	movq	%rdx, %rax
100003bf3: 41 5f                       	popq	%r15
100003bf5: 41 5e                       	popq	%r14
100003bf7: 41 5d                       	popq	%r13
100003bf9: 41 5c                       	popq	%r12
100003bfb: 5b                          	popq	%rbx
100003bfc: c3                          	retq
		...
100003ffd: 00 00                       	addb	%al, (%rax)
100003fff: 00                          	<unknown>
