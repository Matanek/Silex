
/private/tmp/silex-part03-evidence/direct-sse-macos-x64-release:	file format mach-o 64-bit x86-64

Disassembly of section __TEXT,__text:

0000000100001000 <__text>:
100001000: 55                          	pushq	%rbp
100001001: 48 89 e5                    	movq	%rsp, %rbp
100001004: 48 81 ec b0 00 00 00        	subq	$0xb0, %rsp
10000100b: 48 89 e5                    	movq	%rsp, %rbp
10000100e: 48 89 b5 08 00 00 00        	movq	%rsi, 0x8(%rbp)
100001015: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
10000101c: f2 0f 10 85 00 00 00 00     	movsd	(%rbp), %xmm0
100001024: f2 0f 10 8d 08 00 00 00     	movsd	0x8(%rbp), %xmm1
10000102c: 0f 28 f0                    	movaps	%xmm0, %xmm6
10000102f: f2 0f 5c f1                 	subsd	%xmm1, %xmm6
100001033: 48 b8 00 00 00 00 00 00 18 40       	movabsq	$0x4018000000000000, %rax ## imm = 0x4018000000000000
10000103d: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001042: 66 0f 2e f7                 	ucomisd	%xmm7, %xmm6
100001046: 0f 94 c0                    	sete	%al
100001049: 0f 9b c1                    	setnp	%cl
10000104c: 20 c8                       	andb	%cl, %al
10000104e: 48 0f b6 c0                 	movzbq	%al, %rax
100001052: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100001059: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
100001060: 48 85 c0                    	testq	%rax, %rax
100001063: 0f 84 33 00 00 00           	je	0x10000109c <__text+0x9c>
100001069: 48 8d 35 a0 1f 00 00        	leaq	0x1fa0(%rip), %rsi      ## 0x100003010
100001070: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001077: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000107e: 4c 89 c2                    	movq	%r8, %rdx
100001081: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000108b: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001095: 0f 05                       	syscall
100001097: e9 2e 00 00 00              	jmp	0x1000010ca <__text+0xca>
10000109c: 48 8d 35 7d 1f 00 00        	leaq	0x1f7d(%rip), %rsi      ## 0x100003020
1000010a3: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000010aa: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000010b1: 4c 89 c2                    	movq	%r8, %rdx
1000010b4: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000010be: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000010c8: 0f 05                       	syscall
1000010ca: 48 8d 35 2f 1f 00 00        	leaq	0x1f2f(%rip), %rsi      ## 0x100003000
1000010d1: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000010d8: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000010df: 4c 89 c2                    	movq	%r8, %rdx
1000010e2: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000010ec: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000010f6: 0f 05                       	syscall
1000010f8: f2 0f 10 85 08 00 00 00     	movsd	0x8(%rbp), %xmm0
100001100: f2 0f 10 8d 00 00 00 00     	movsd	(%rbp), %xmm1
100001108: 0f 28 f0                    	movaps	%xmm0, %xmm6
10000110b: f2 0f 5c f1                 	subsd	%xmm1, %xmm6
10000110f: 48 b8 00 00 00 00 00 00 18 c0       	movabsq	$-0x3fe8000000000000, %rax ## imm = 0xC018000000000000
100001119: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000111e: 66 0f 2e f7                 	ucomisd	%xmm7, %xmm6
100001122: 0f 94 c0                    	sete	%al
100001125: 0f 9b c1                    	setnp	%cl
100001128: 20 c8                       	andb	%cl, %al
10000112a: 48 0f b6 c0                 	movzbq	%al, %rax
10000112e: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
100001135: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
10000113c: 48 85 c0                    	testq	%rax, %rax
10000113f: 0f 84 33 00 00 00           	je	0x100001178 <__text+0x178>
100001145: 48 8d 35 c4 1e 00 00        	leaq	0x1ec4(%rip), %rsi      ## 0x100003010
10000114c: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001153: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000115a: 4c 89 c2                    	movq	%r8, %rdx
10000115d: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001167: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001171: 0f 05                       	syscall
100001173: e9 2e 00 00 00              	jmp	0x1000011a6 <__text+0x1a6>
100001178: 48 8d 35 a1 1e 00 00        	leaq	0x1ea1(%rip), %rsi      ## 0x100003020
10000117f: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001186: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000118d: 4c 89 c2                    	movq	%r8, %rdx
100001190: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000119a: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000011a4: 0f 05                       	syscall
1000011a6: 48 8d 35 53 1e 00 00        	leaq	0x1e53(%rip), %rsi      ## 0x100003000
1000011ad: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000011b4: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000011bb: 4c 89 c2                    	movq	%r8, %rdx
1000011be: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000011c8: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000011d2: 0f 05                       	syscall
1000011d4: f2 0f 10 85 00 00 00 00     	movsd	(%rbp), %xmm0
1000011dc: f2 0f 10 8d 08 00 00 00     	movsd	0x8(%rbp), %xmm1
1000011e4: 0f 28 f0                    	movaps	%xmm0, %xmm6
1000011e7: f2 0f 5e f1                 	divsd	%xmm1, %xmm6
1000011eb: 48 b8 00 00 00 00 00 00 10 40       	movabsq	$0x4010000000000000, %rax ## imm = 0x4010000000000000
1000011f5: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000011fa: 66 0f 2e f7                 	ucomisd	%xmm7, %xmm6
1000011fe: 0f 94 c0                    	sete	%al
100001201: 0f 9b c1                    	setnp	%cl
100001204: 20 c8                       	andb	%cl, %al
100001206: 48 0f b6 c0                 	movzbq	%al, %rax
10000120a: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100001211: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
100001218: 48 85 c0                    	testq	%rax, %rax
10000121b: 0f 84 33 00 00 00           	je	0x100001254 <__text+0x254>
100001221: 48 8d 35 e8 1d 00 00        	leaq	0x1de8(%rip), %rsi      ## 0x100003010
100001228: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000122f: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001236: 4c 89 c2                    	movq	%r8, %rdx
100001239: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001243: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
10000124d: 0f 05                       	syscall
10000124f: e9 2e 00 00 00              	jmp	0x100001282 <__text+0x282>
100001254: 48 8d 35 c5 1d 00 00        	leaq	0x1dc5(%rip), %rsi      ## 0x100003020
10000125b: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001262: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001269: 4c 89 c2                    	movq	%r8, %rdx
10000126c: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001276: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001280: 0f 05                       	syscall
100001282: 48 8d 35 77 1d 00 00        	leaq	0x1d77(%rip), %rsi      ## 0x100003000
100001289: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001290: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001297: 4c 89 c2                    	movq	%r8, %rdx
10000129a: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000012a4: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000012ae: 0f 05                       	syscall
1000012b0: f2 0f 10 85 08 00 00 00     	movsd	0x8(%rbp), %xmm0
1000012b8: f2 0f 10 8d 00 00 00 00     	movsd	(%rbp), %xmm1
1000012c0: 0f 28 f0                    	movaps	%xmm0, %xmm6
1000012c3: f2 0f 5e f1                 	divsd	%xmm1, %xmm6
1000012c7: 48 b8 00 00 00 00 00 00 d0 3f       	movabsq	$0x3fd0000000000000, %rax ## imm = 0x3FD0000000000000
1000012d1: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000012d6: 66 0f 2e f7                 	ucomisd	%xmm7, %xmm6
1000012da: 0f 94 c0                    	sete	%al
1000012dd: 0f 9b c1                    	setnp	%cl
1000012e0: 20 c8                       	andb	%cl, %al
1000012e2: 48 0f b6 c0                 	movzbq	%al, %rax
1000012e6: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
1000012ed: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
1000012f4: 48 85 c0                    	testq	%rax, %rax
1000012f7: 0f 84 33 00 00 00           	je	0x100001330 <__text+0x330>
1000012fd: 48 8d 35 0c 1d 00 00        	leaq	0x1d0c(%rip), %rsi      ## 0x100003010
100001304: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000130b: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001312: 4c 89 c2                    	movq	%r8, %rdx
100001315: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000131f: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001329: 0f 05                       	syscall
10000132b: e9 2e 00 00 00              	jmp	0x10000135e <__text+0x35e>
100001330: 48 8d 35 e9 1c 00 00        	leaq	0x1ce9(%rip), %rsi      ## 0x100003020
100001337: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000133e: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001345: 4c 89 c2                    	movq	%r8, %rdx
100001348: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001352: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
10000135c: 0f 05                       	syscall
10000135e: 48 8d 35 9b 1c 00 00        	leaq	0x1c9b(%rip), %rsi      ## 0x100003000
100001365: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000136c: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001373: 4c 89 c2                    	movq	%r8, %rdx
100001376: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001380: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
10000138a: 0f 05                       	syscall
10000138c: f2 0f 10 85 00 00 00 00     	movsd	(%rbp), %xmm0
100001394: f2 0f 10 8d 08 00 00 00     	movsd	0x8(%rbp), %xmm1
10000139c: 0f 28 f0                    	movaps	%xmm0, %xmm6
10000139f: f2 0f 58 f1                 	addsd	%xmm1, %xmm6
1000013a3: 48 b8 00 00 00 00 00 00 24 40       	movabsq	$0x4024000000000000, %rax ## imm = 0x4024000000000000
1000013ad: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000013b2: 66 0f 2e f7                 	ucomisd	%xmm7, %xmm6
1000013b6: 0f 94 c0                    	sete	%al
1000013b9: 0f 9b c1                    	setnp	%cl
1000013bc: 20 c8                       	andb	%cl, %al
1000013be: 48 0f b6 c0                 	movzbq	%al, %rax
1000013c2: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
1000013c9: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
1000013d0: 48 85 c0                    	testq	%rax, %rax
1000013d3: 0f 84 33 00 00 00           	je	0x10000140c <__text+0x40c>
1000013d9: 48 8d 35 30 1c 00 00        	leaq	0x1c30(%rip), %rsi      ## 0x100003010
1000013e0: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000013e7: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000013ee: 4c 89 c2                    	movq	%r8, %rdx
1000013f1: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000013fb: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001405: 0f 05                       	syscall
100001407: e9 2e 00 00 00              	jmp	0x10000143a <__text+0x43a>
10000140c: 48 8d 35 0d 1c 00 00        	leaq	0x1c0d(%rip), %rsi      ## 0x100003020
100001413: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000141a: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001421: 4c 89 c2                    	movq	%r8, %rdx
100001424: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000142e: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001438: 0f 05                       	syscall
10000143a: 48 8d 35 bf 1b 00 00        	leaq	0x1bbf(%rip), %rsi      ## 0x100003000
100001441: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001448: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000144f: 4c 89 c2                    	movq	%r8, %rdx
100001452: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000145c: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001466: 0f 05                       	syscall
100001468: f2 0f 10 85 00 00 00 00     	movsd	(%rbp), %xmm0
100001470: f2 0f 10 8d 08 00 00 00     	movsd	0x8(%rbp), %xmm1
100001478: 0f 28 f0                    	movaps	%xmm0, %xmm6
10000147b: f2 0f 59 f1                 	mulsd	%xmm1, %xmm6
10000147f: 48 b8 00 00 00 00 00 00 30 40       	movabsq	$0x4030000000000000, %rax ## imm = 0x4030000000000000
100001489: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000148e: 66 0f 2e f7                 	ucomisd	%xmm7, %xmm6
100001492: 0f 94 c0                    	sete	%al
100001495: 0f 9b c1                    	setnp	%cl
100001498: 20 c8                       	andb	%cl, %al
10000149a: 48 0f b6 c0                 	movzbq	%al, %rax
10000149e: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
1000014a5: 48 8b 85 98 00 00 00        	movq	0x98(%rbp), %rax
1000014ac: 48 85 c0                    	testq	%rax, %rax
1000014af: 0f 84 33 00 00 00           	je	0x1000014e8 <__text+0x4e8>
1000014b5: 48 8d 35 54 1b 00 00        	leaq	0x1b54(%rip), %rsi      ## 0x100003010
1000014bc: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000014c3: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000014ca: 4c 89 c2                    	movq	%r8, %rdx
1000014cd: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000014d7: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000014e1: 0f 05                       	syscall
1000014e3: e9 2e 00 00 00              	jmp	0x100001516 <__text+0x516>
1000014e8: 48 8d 35 31 1b 00 00        	leaq	0x1b31(%rip), %rsi      ## 0x100003020
1000014ef: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000014f6: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000014fd: 4c 89 c2                    	movq	%r8, %rdx
100001500: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000150a: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001514: 0f 05                       	syscall
100001516: 48 8d 35 e3 1a 00 00        	leaq	0x1ae3(%rip), %rsi      ## 0x100003000
10000151d: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001524: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000152b: 4c 89 c2                    	movq	%r8, %rdx
10000152e: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001538: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001542: 0f 05                       	syscall
100001544: 31 c0                       	xorl	%eax, %eax
100001546: 31 d2                       	xorl	%edx, %edx
100001548: e9 00 00 00 00              	jmp	0x10000154d <__text+0x54d>
10000154d: 48 89 ec                    	movq	%rbp, %rsp
100001550: 48 81 c4 b0 00 00 00        	addq	$0xb0, %rsp
100001557: 5d                          	popq	%rbp
100001558: c3                          	retq
100001559: 55                          	pushq	%rbp
10000155a: 48 89 e5                    	movq	%rsp, %rbp
10000155d: 48 81 ec b0 00 00 00        	subq	$0xb0, %rsp
100001564: 48 89 e5                    	movq	%rsp, %rbp
100001567: 48 89 b5 08 00 00 00        	movq	%rsi, 0x8(%rbp)
10000156e: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
100001575: f3 0f 10 85 00 00 00 00     	movss	(%rbp), %xmm0
10000157d: f3 0f 10 8d 08 00 00 00     	movss	0x8(%rbp), %xmm1
100001585: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001588: f3 0f 5c f1                 	subss	%xmm1, %xmm6
10000158c: 48 b8 00 00 c0 40 00 00 00 00       	movabsq	$0x40c00000, %rax ## imm = 0x40C00000
100001596: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000159b: 0f 2e f7                    	ucomiss	%xmm7, %xmm6
10000159e: 0f 94 c0                    	sete	%al
1000015a1: 0f 9b c1                    	setnp	%cl
1000015a4: 20 c8                       	andb	%cl, %al
1000015a6: 48 0f b6 c0                 	movzbq	%al, %rax
1000015aa: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
1000015b1: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
1000015b8: 48 85 c0                    	testq	%rax, %rax
1000015bb: 0f 84 33 00 00 00           	je	0x1000015f4 <__text+0x5f4>
1000015c1: 48 8d 35 48 1a 00 00        	leaq	0x1a48(%rip), %rsi      ## 0x100003010
1000015c8: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000015cf: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000015d6: 4c 89 c2                    	movq	%r8, %rdx
1000015d9: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000015e3: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000015ed: 0f 05                       	syscall
1000015ef: e9 2e 00 00 00              	jmp	0x100001622 <__text+0x622>
1000015f4: 48 8d 35 25 1a 00 00        	leaq	0x1a25(%rip), %rsi      ## 0x100003020
1000015fb: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001602: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001609: 4c 89 c2                    	movq	%r8, %rdx
10000160c: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001616: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001620: 0f 05                       	syscall
100001622: 48 8d 35 d7 19 00 00        	leaq	0x19d7(%rip), %rsi      ## 0x100003000
100001629: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001630: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001637: 4c 89 c2                    	movq	%r8, %rdx
10000163a: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001644: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
10000164e: 0f 05                       	syscall
100001650: f3 0f 10 85 08 00 00 00     	movss	0x8(%rbp), %xmm0
100001658: f3 0f 10 8d 00 00 00 00     	movss	(%rbp), %xmm1
100001660: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001663: f3 0f 5c f1                 	subss	%xmm1, %xmm6
100001667: 48 b8 00 00 c0 c0 00 00 00 00       	movabsq	$0xc0c00000, %rax ## imm = 0xC0C00000
100001671: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001676: 0f 2e f7                    	ucomiss	%xmm7, %xmm6
100001679: 0f 94 c0                    	sete	%al
10000167c: 0f 9b c1                    	setnp	%cl
10000167f: 20 c8                       	andb	%cl, %al
100001681: 48 0f b6 c0                 	movzbq	%al, %rax
100001685: 48 89 85 38 00 00 00        	movq	%rax, 0x38(%rbp)
10000168c: 48 8b 85 38 00 00 00        	movq	0x38(%rbp), %rax
100001693: 48 85 c0                    	testq	%rax, %rax
100001696: 0f 84 33 00 00 00           	je	0x1000016cf <__text+0x6cf>
10000169c: 48 8d 35 6d 19 00 00        	leaq	0x196d(%rip), %rsi      ## 0x100003010
1000016a3: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000016aa: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000016b1: 4c 89 c2                    	movq	%r8, %rdx
1000016b4: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000016be: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000016c8: 0f 05                       	syscall
1000016ca: e9 2e 00 00 00              	jmp	0x1000016fd <__text+0x6fd>
1000016cf: 48 8d 35 4a 19 00 00        	leaq	0x194a(%rip), %rsi      ## 0x100003020
1000016d6: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000016dd: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000016e4: 4c 89 c2                    	movq	%r8, %rdx
1000016e7: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000016f1: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000016fb: 0f 05                       	syscall
1000016fd: 48 8d 35 fc 18 00 00        	leaq	0x18fc(%rip), %rsi      ## 0x100003000
100001704: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000170b: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001712: 4c 89 c2                    	movq	%r8, %rdx
100001715: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000171f: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001729: 0f 05                       	syscall
10000172b: f3 0f 10 85 00 00 00 00     	movss	(%rbp), %xmm0
100001733: f3 0f 10 8d 08 00 00 00     	movss	0x8(%rbp), %xmm1
10000173b: 0f 28 f0                    	movaps	%xmm0, %xmm6
10000173e: f3 0f 5e f1                 	divss	%xmm1, %xmm6
100001742: 48 b8 00 00 80 40 00 00 00 00       	movabsq	$0x40800000, %rax ## imm = 0x40800000
10000174c: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001751: 0f 2e f7                    	ucomiss	%xmm7, %xmm6
100001754: 0f 94 c0                    	sete	%al
100001757: 0f 9b c1                    	setnp	%cl
10000175a: 20 c8                       	andb	%cl, %al
10000175c: 48 0f b6 c0                 	movzbq	%al, %rax
100001760: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100001767: 48 8b 85 50 00 00 00        	movq	0x50(%rbp), %rax
10000176e: 48 85 c0                    	testq	%rax, %rax
100001771: 0f 84 33 00 00 00           	je	0x1000017aa <__text+0x7aa>
100001777: 48 8d 35 92 18 00 00        	leaq	0x1892(%rip), %rsi      ## 0x100003010
10000177e: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001785: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000178c: 4c 89 c2                    	movq	%r8, %rdx
10000178f: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001799: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000017a3: 0f 05                       	syscall
1000017a5: e9 2e 00 00 00              	jmp	0x1000017d8 <__text+0x7d8>
1000017aa: 48 8d 35 6f 18 00 00        	leaq	0x186f(%rip), %rsi      ## 0x100003020
1000017b1: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000017b8: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000017bf: 4c 89 c2                    	movq	%r8, %rdx
1000017c2: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000017cc: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000017d6: 0f 05                       	syscall
1000017d8: 48 8d 35 21 18 00 00        	leaq	0x1821(%rip), %rsi      ## 0x100003000
1000017df: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000017e6: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000017ed: 4c 89 c2                    	movq	%r8, %rdx
1000017f0: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000017fa: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001804: 0f 05                       	syscall
100001806: f3 0f 10 85 08 00 00 00     	movss	0x8(%rbp), %xmm0
10000180e: f3 0f 10 8d 00 00 00 00     	movss	(%rbp), %xmm1
100001816: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001819: f3 0f 5e f1                 	divss	%xmm1, %xmm6
10000181d: 48 b8 00 00 80 3e 00 00 00 00       	movabsq	$0x3e800000, %rax ## imm = 0x3E800000
100001827: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000182c: 0f 2e f7                    	ucomiss	%xmm7, %xmm6
10000182f: 0f 94 c0                    	sete	%al
100001832: 0f 9b c1                    	setnp	%cl
100001835: 20 c8                       	andb	%cl, %al
100001837: 48 0f b6 c0                 	movzbq	%al, %rax
10000183b: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100001842: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100001849: 48 85 c0                    	testq	%rax, %rax
10000184c: 0f 84 33 00 00 00           	je	0x100001885 <__text+0x885>
100001852: 48 8d 35 b7 17 00 00        	leaq	0x17b7(%rip), %rsi      ## 0x100003010
100001859: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001860: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001867: 4c 89 c2                    	movq	%r8, %rdx
10000186a: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001874: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
10000187e: 0f 05                       	syscall
100001880: e9 2e 00 00 00              	jmp	0x1000018b3 <__text+0x8b3>
100001885: 48 8d 35 94 17 00 00        	leaq	0x1794(%rip), %rsi      ## 0x100003020
10000188c: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001893: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000189a: 4c 89 c2                    	movq	%r8, %rdx
10000189d: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000018a7: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000018b1: 0f 05                       	syscall
1000018b3: 48 8d 35 46 17 00 00        	leaq	0x1746(%rip), %rsi      ## 0x100003000
1000018ba: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000018c1: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000018c8: 4c 89 c2                    	movq	%r8, %rdx
1000018cb: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000018d5: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000018df: 0f 05                       	syscall
1000018e1: f3 0f 10 85 00 00 00 00     	movss	(%rbp), %xmm0
1000018e9: f3 0f 10 8d 08 00 00 00     	movss	0x8(%rbp), %xmm1
1000018f1: 0f 28 f0                    	movaps	%xmm0, %xmm6
1000018f4: f3 0f 58 f1                 	addss	%xmm1, %xmm6
1000018f8: 48 b8 00 00 20 41 00 00 00 00       	movabsq	$0x41200000, %rax ## imm = 0x41200000
100001902: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001907: 0f 2e f7                    	ucomiss	%xmm7, %xmm6
10000190a: 0f 94 c0                    	sete	%al
10000190d: 0f 9b c1                    	setnp	%cl
100001910: 20 c8                       	andb	%cl, %al
100001912: 48 0f b6 c0                 	movzbq	%al, %rax
100001916: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
10000191d: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100001924: 48 85 c0                    	testq	%rax, %rax
100001927: 0f 84 33 00 00 00           	je	0x100001960 <__text+0x960>
10000192d: 48 8d 35 dc 16 00 00        	leaq	0x16dc(%rip), %rsi      ## 0x100003010
100001934: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000193b: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001942: 4c 89 c2                    	movq	%r8, %rdx
100001945: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000194f: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001959: 0f 05                       	syscall
10000195b: e9 2e 00 00 00              	jmp	0x10000198e <__text+0x98e>
100001960: 48 8d 35 b9 16 00 00        	leaq	0x16b9(%rip), %rsi      ## 0x100003020
100001967: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000196e: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001975: 4c 89 c2                    	movq	%r8, %rdx
100001978: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001982: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
10000198c: 0f 05                       	syscall
10000198e: 48 8d 35 6b 16 00 00        	leaq	0x166b(%rip), %rsi      ## 0x100003000
100001995: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
10000199c: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000019a3: 4c 89 c2                    	movq	%r8, %rdx
1000019a6: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000019b0: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000019ba: 0f 05                       	syscall
1000019bc: f3 0f 10 85 00 00 00 00     	movss	(%rbp), %xmm0
1000019c4: f3 0f 10 8d 08 00 00 00     	movss	0x8(%rbp), %xmm1
1000019cc: 0f 28 f0                    	movaps	%xmm0, %xmm6
1000019cf: f3 0f 59 f1                 	mulss	%xmm1, %xmm6
1000019d3: 48 b8 00 00 80 41 00 00 00 00       	movabsq	$0x41800000, %rax ## imm = 0x41800000
1000019dd: 66 48 0f 6e f8              	movq	%rax, %xmm7
1000019e2: 0f 2e f7                    	ucomiss	%xmm7, %xmm6
1000019e5: 0f 94 c0                    	sete	%al
1000019e8: 0f 9b c1                    	setnp	%cl
1000019eb: 20 c8                       	andb	%cl, %al
1000019ed: 48 0f b6 c0                 	movzbq	%al, %rax
1000019f1: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
1000019f8: 48 8b 85 98 00 00 00        	movq	0x98(%rbp), %rax
1000019ff: 48 85 c0                    	testq	%rax, %rax
100001a02: 0f 84 33 00 00 00           	je	0x100001a3b <__text+0xa3b>
100001a08: 48 8d 35 01 16 00 00        	leaq	0x1601(%rip), %rsi      ## 0x100003010
100001a0f: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001a16: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001a1d: 4c 89 c2                    	movq	%r8, %rdx
100001a20: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001a2a: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001a34: 0f 05                       	syscall
100001a36: e9 2e 00 00 00              	jmp	0x100001a69 <__text+0xa69>
100001a3b: 48 8d 35 de 15 00 00        	leaq	0x15de(%rip), %rsi      ## 0x100003020
100001a42: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001a49: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001a50: 4c 89 c2                    	movq	%r8, %rdx
100001a53: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001a5d: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001a67: 0f 05                       	syscall
100001a69: 48 8d 35 90 15 00 00        	leaq	0x1590(%rip), %rsi      ## 0x100003000
100001a70: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001a77: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001a7e: 4c 89 c2                    	movq	%r8, %rdx
100001a81: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001a8b: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001a95: 0f 05                       	syscall
100001a97: 31 c0                       	xorl	%eax, %eax
100001a99: 31 d2                       	xorl	%edx, %edx
100001a9b: e9 00 00 00 00              	jmp	0x100001aa0 <__text+0xaa0>
100001aa0: 48 89 ec                    	movq	%rbp, %rsp
100001aa3: 48 81 c4 b0 00 00 00        	addq	$0xb0, %rsp
100001aaa: 5d                          	popq	%rbp
100001aab: c3                          	retq
100001aac: 55                          	pushq	%rbp
100001aad: 48 89 e5                    	movq	%rsp, %rbp
100001ab0: 48 81 ec d0 00 00 00        	subq	$0xd0, %rsp
100001ab7: 48 89 e5                    	movq	%rsp, %rbp
100001aba: 48 89 b5 08 00 00 00        	movq	%rsi, 0x8(%rbp)
100001ac1: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
100001ac8: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100001ad2: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001ad7: 66 48 0f 7e f0              	movq	%xmm6, %rax
100001adc: 66 0f 6e d8                 	movd	%eax, %xmm3
100001ae0: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100001ae4: 66 48 0f 7e d8              	movq	%xmm3, %rax
100001ae9: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001aee: f2 0f 10 8d 00 00 00 00     	movsd	(%rbp), %xmm1
100001af6: f2 0f 5e f9                 	divsd	%xmm1, %xmm7
100001afa: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001b04: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001b09: 66 0f 2e fe                 	ucomisd	%xmm6, %xmm7
100001b0d: 0f 92 c0                    	setb	%al
100001b10: 0f 9b c1                    	setnp	%cl
100001b13: 20 c8                       	andb	%cl, %al
100001b15: 48 0f b6 c0                 	movzbq	%al, %rax
100001b19: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100001b20: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001b27: 48 85 c0                    	testq	%rax, %rax
100001b2a: 0f 84 33 00 00 00           	je	0x100001b63 <__text+0xb63>
100001b30: 48 8d 35 d9 14 00 00        	leaq	0x14d9(%rip), %rsi      ## 0x100003010
100001b37: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001b3e: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001b45: 4c 89 c2                    	movq	%r8, %rdx
100001b48: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001b52: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001b5c: 0f 05                       	syscall
100001b5e: e9 2e 00 00 00              	jmp	0x100001b91 <__text+0xb91>
100001b63: 48 8d 35 b6 14 00 00        	leaq	0x14b6(%rip), %rsi      ## 0x100003020
100001b6a: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001b71: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001b78: 4c 89 c2                    	movq	%r8, %rdx
100001b7b: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001b85: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001b8f: 0f 05                       	syscall
100001b91: 48 8d 35 68 14 00 00        	leaq	0x1468(%rip), %rsi      ## 0x100003000
100001b98: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001b9f: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001ba6: 4c 89 c2                    	movq	%r8, %rdx
100001ba9: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001bb3: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001bbd: 0f 05                       	syscall
100001bbf: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100001bc9: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001bce: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001bd5: 48 b9 00 00 00 00 00 00 00 80       	movabsq	$-0x8000000000000000, %rcx ## imm = 0x8000000000000000
100001bdf: 48 31 c8                    	xorq	%rcx, %rax
100001be2: 66 48 0f 6e f8              	movq	%rax, %xmm7
100001be7: 66 48 0f 7e f0              	movq	%xmm6, %rax
100001bec: 66 0f 6e d8                 	movd	%eax, %xmm3
100001bf0: f3 0f 5a db                 	cvtss2sd	%xmm3, %xmm3
100001bf4: 66 48 0f 7e d8              	movq	%xmm3, %rax
100001bf9: 66 4c 0f 6e c0              	movq	%rax, %xmm8
100001bfe: f2 44 0f 5e c7              	divsd	%xmm7, %xmm8
100001c03: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001c0d: 66 48 0f 6e f0              	movq	%rax, %xmm6
100001c12: 66 44 0f 2e c6              	ucomisd	%xmm6, %xmm8
100001c17: 0f 97 c0                    	seta	%al
100001c1a: 48 0f b6 c0                 	movzbq	%al, %rax
100001c1e: 48 89 85 60 00 00 00        	movq	%rax, 0x60(%rbp)
100001c25: 48 8b 85 60 00 00 00        	movq	0x60(%rbp), %rax
100001c2c: 48 85 c0                    	testq	%rax, %rax
100001c2f: 0f 84 33 00 00 00           	je	0x100001c68 <__text+0xc68>
100001c35: 48 8d 35 d4 13 00 00        	leaq	0x13d4(%rip), %rsi      ## 0x100003010
100001c3c: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001c43: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001c4a: 4c 89 c2                    	movq	%r8, %rdx
100001c4d: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001c57: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001c61: 0f 05                       	syscall
100001c63: e9 2e 00 00 00              	jmp	0x100001c96 <__text+0xc96>
100001c68: 48 8d 35 b1 13 00 00        	leaq	0x13b1(%rip), %rsi      ## 0x100003020
100001c6f: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001c76: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001c7d: 4c 89 c2                    	movq	%r8, %rdx
100001c80: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001c8a: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001c94: 0f 05                       	syscall
100001c96: 48 8d 35 63 13 00 00        	leaq	0x1363(%rip), %rsi      ## 0x100003000
100001c9d: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001ca4: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001cab: 4c 89 c2                    	movq	%r8, %rdx
100001cae: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001cb8: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001cc2: 0f 05                       	syscall
100001cc4: f2 0f 10 85 08 00 00 00     	movsd	0x8(%rbp), %xmm0
100001ccc: f2 0f 10 8d 00 00 00 00     	movsd	(%rbp), %xmm1
100001cd4: 66 0f 2e c1                 	ucomisd	%xmm1, %xmm0
100001cd8: 0f 92 c0                    	setb	%al
100001cdb: 0f 9b c1                    	setnp	%cl
100001cde: 20 c8                       	andb	%cl, %al
100001ce0: 48 0f b6 c0                 	movzbq	%al, %rax
100001ce4: 48 89 85 68 00 00 00        	movq	%rax, 0x68(%rbp)
100001ceb: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001cf5: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100001cfc: 48 8b 85 68 00 00 00        	movq	0x68(%rbp), %rax
100001d03: 48 8b 8d 70 00 00 00        	movq	0x70(%rbp), %rcx
100001d0a: 48 39 c8                    	cmpq	%rcx, %rax
100001d0d: 0f 94 c0                    	sete	%al
100001d10: 48 0f b6 c0                 	movzbq	%al, %rax
100001d14: 48 89 85 78 00 00 00        	movq	%rax, 0x78(%rbp)
100001d1b: 48 8b 85 78 00 00 00        	movq	0x78(%rbp), %rax
100001d22: 48 85 c0                    	testq	%rax, %rax
100001d25: 0f 84 33 00 00 00           	je	0x100001d5e <__text+0xd5e>
100001d2b: 48 8d 35 de 12 00 00        	leaq	0x12de(%rip), %rsi      ## 0x100003010
100001d32: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001d39: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001d40: 4c 89 c2                    	movq	%r8, %rdx
100001d43: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001d4d: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001d57: 0f 05                       	syscall
100001d59: e9 2e 00 00 00              	jmp	0x100001d8c <__text+0xd8c>
100001d5e: 48 8d 35 bb 12 00 00        	leaq	0x12bb(%rip), %rsi      ## 0x100003020
100001d65: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001d6c: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001d73: 4c 89 c2                    	movq	%r8, %rdx
100001d76: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001d80: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001d8a: 0f 05                       	syscall
100001d8c: 48 8d 35 6d 12 00 00        	leaq	0x126d(%rip), %rsi      ## 0x100003000
100001d93: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001d9a: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001da1: 4c 89 c2                    	movq	%r8, %rdx
100001da4: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001dae: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001db8: 0f 05                       	syscall
100001dba: f2 0f 10 85 08 00 00 00     	movsd	0x8(%rbp), %xmm0
100001dc2: f2 0f 10 8d 00 00 00 00     	movsd	(%rbp), %xmm1
100001dca: 66 0f 2e c1                 	ucomisd	%xmm1, %xmm0
100001dce: 0f 97 c0                    	seta	%al
100001dd1: 48 0f b6 c0                 	movzbq	%al, %rax
100001dd5: 48 89 85 80 00 00 00        	movq	%rax, 0x80(%rbp)
100001ddc: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001de6: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
100001ded: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
100001df4: 48 8b 8d 88 00 00 00        	movq	0x88(%rbp), %rcx
100001dfb: 48 39 c8                    	cmpq	%rcx, %rax
100001dfe: 0f 94 c0                    	sete	%al
100001e01: 48 0f b6 c0                 	movzbq	%al, %rax
100001e05: 48 89 85 90 00 00 00        	movq	%rax, 0x90(%rbp)
100001e0c: 48 8b 85 90 00 00 00        	movq	0x90(%rbp), %rax
100001e13: 48 85 c0                    	testq	%rax, %rax
100001e16: 0f 84 33 00 00 00           	je	0x100001e4f <__text+0xe4f>
100001e1c: 48 8d 35 ed 11 00 00        	leaq	0x11ed(%rip), %rsi      ## 0x100003010
100001e23: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001e2a: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001e31: 4c 89 c2                    	movq	%r8, %rdx
100001e34: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001e3e: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001e48: 0f 05                       	syscall
100001e4a: e9 2e 00 00 00              	jmp	0x100001e7d <__text+0xe7d>
100001e4f: 48 8d 35 ca 11 00 00        	leaq	0x11ca(%rip), %rsi      ## 0x100003020
100001e56: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001e5d: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001e64: 4c 89 c2                    	movq	%r8, %rdx
100001e67: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001e71: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001e7b: 0f 05                       	syscall
100001e7d: 48 8d 35 7c 11 00 00        	leaq	0x117c(%rip), %rsi      ## 0x100003000
100001e84: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001e8b: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001e92: 4c 89 c2                    	movq	%r8, %rdx
100001e95: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001e9f: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001ea9: 0f 05                       	syscall
100001eab: f2 0f 10 85 08 00 00 00     	movsd	0x8(%rbp), %xmm0
100001eb3: f2 0f 10 8d 08 00 00 00     	movsd	0x8(%rbp), %xmm1
100001ebb: 66 0f 2e c1                 	ucomisd	%xmm1, %xmm0
100001ebf: 0f 94 c0                    	sete	%al
100001ec2: 0f 9b c1                    	setnp	%cl
100001ec5: 20 c8                       	andb	%cl, %al
100001ec7: 48 0f b6 c0                 	movzbq	%al, %rax
100001ecb: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
100001ed2: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001edc: 48 89 85 a0 00 00 00        	movq	%rax, 0xa0(%rbp)
100001ee3: 48 8b 85 98 00 00 00        	movq	0x98(%rbp), %rax
100001eea: 48 8b 8d a0 00 00 00        	movq	0xa0(%rbp), %rcx
100001ef1: 48 39 c8                    	cmpq	%rcx, %rax
100001ef4: 0f 94 c0                    	sete	%al
100001ef7: 48 0f b6 c0                 	movzbq	%al, %rax
100001efb: 48 89 85 a8 00 00 00        	movq	%rax, 0xa8(%rbp)
100001f02: 48 8b 85 a8 00 00 00        	movq	0xa8(%rbp), %rax
100001f09: 48 85 c0                    	testq	%rax, %rax
100001f0c: 0f 84 33 00 00 00           	je	0x100001f45 <__text+0xf45>
100001f12: 48 8d 35 f7 10 00 00        	leaq	0x10f7(%rip), %rsi      ## 0x100003010
100001f19: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001f20: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001f27: 4c 89 c2                    	movq	%r8, %rdx
100001f2a: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001f34: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001f3e: 0f 05                       	syscall
100001f40: e9 2e 00 00 00              	jmp	0x100001f73 <__text+0xf73>
100001f45: 48 8d 35 d4 10 00 00        	leaq	0x10d4(%rip), %rsi      ## 0x100003020
100001f4c: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001f53: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001f5a: 4c 89 c2                    	movq	%r8, %rdx
100001f5d: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001f67: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001f71: 0f 05                       	syscall
100001f73: 48 8d 35 86 10 00 00        	leaq	0x1086(%rip), %rsi      ## 0x100003000
100001f7a: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001f81: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001f88: 4c 89 c2                    	movq	%r8, %rdx
100001f8b: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001f95: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001f9f: 0f 05                       	syscall
100001fa1: f2 0f 10 85 08 00 00 00     	movsd	0x8(%rbp), %xmm0
100001fa9: f2 0f 10 8d 08 00 00 00     	movsd	0x8(%rbp), %xmm1
100001fb1: 66 0f 2e c1                 	ucomisd	%xmm1, %xmm0
100001fb5: 0f 95 c0                    	setne	%al
100001fb8: 0f 9a c1                    	setp	%cl
100001fbb: 08 c8                       	orb	%cl, %al
100001fbd: 48 0f b6 c0                 	movzbq	%al, %rax
100001fc1: 48 89 85 b0 00 00 00        	movq	%rax, 0xb0(%rbp)
100001fc8: 48 8b 85 b0 00 00 00        	movq	0xb0(%rbp), %rax
100001fcf: 48 85 c0                    	testq	%rax, %rax
100001fd2: 0f 84 33 00 00 00           	je	0x10000200b <__text+0x100b>
100001fd8: 48 8d 35 31 10 00 00        	leaq	0x1031(%rip), %rsi      ## 0x100003010
100001fdf: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100001fe6: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100001fed: 4c 89 c2                    	movq	%r8, %rdx
100001ff0: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001ffa: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100002004: 0f 05                       	syscall
100002006: e9 2e 00 00 00              	jmp	0x100002039 <__text+0x1039>
10000200b: 48 8d 35 0e 10 00 00        	leaq	0x100e(%rip), %rsi      ## 0x100003020
100002012: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100002019: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
100002020: 4c 89 c2                    	movq	%r8, %rdx
100002023: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000202d: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100002037: 0f 05                       	syscall
100002039: 48 8d 35 c0 0f 00 00        	leaq	0xfc0(%rip), %rsi       ## 0x100003000
100002040: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
100002047: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
10000204e: 4c 89 c2                    	movq	%r8, %rdx
100002051: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000205b: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100002065: 0f 05                       	syscall
100002067: 31 c0                       	xorl	%eax, %eax
100002069: 31 d2                       	xorl	%edx, %edx
10000206b: e9 00 00 00 00              	jmp	0x100002070 <__text+0x1070>
100002070: 48 89 ec                    	movq	%rbp, %rsp
100002073: 48 81 c4 d0 00 00 00        	addq	$0xd0, %rsp
10000207a: 5d                          	popq	%rbp
10000207b: c3                          	retq
10000207c: 55                          	pushq	%rbp
10000207d: 48 89 e5                    	movq	%rsp, %rbp
100002080: 48 81 ec 50 00 00 00        	subq	$0x50, %rsp
100002087: 48 89 e5                    	movq	%rsp, %rbp
10000208a: 48 b8 00 00 00 00 00 00 20 40       	movabsq	$0x4020000000000000, %rax ## imm = 0x4020000000000000
100002094: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
10000209b: 48 b8 00 00 00 00 00 00 00 40       	movabsq	$0x4000000000000000, %rax ## imm = 0x4000000000000000
1000020a5: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
1000020ac: 48 8b bd 00 00 00 00        	movq	(%rbp), %rdi
1000020b3: 48 8b b5 08 00 00 00        	movq	0x8(%rbp), %rsi
1000020ba: e8 41 ef ff ff              	callq	0x100001000 <__text>
1000020bf: 48 85 d2                    	testq	%rdx, %rdx
1000020c2: 0f 85 a1 00 00 00           	jne	0x100002169 <__text+0x1169>
1000020c8: 48 b8 00 00 00 41 00 00 00 00       	movabsq	$0x41000000, %rax ## imm = 0x41000000
1000020d2: 48 89 85 10 00 00 00        	movq	%rax, 0x10(%rbp)
1000020d9: 48 b8 00 00 00 40 00 00 00 00       	movabsq	$0x40000000, %rax ## imm = 0x40000000
1000020e3: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
1000020ea: 48 8b bd 10 00 00 00        	movq	0x10(%rbp), %rdi
1000020f1: 48 8b b5 18 00 00 00        	movq	0x18(%rbp), %rsi
1000020f8: e8 5c f4 ff ff              	callq	0x100001559 <__text+0x559>
1000020fd: 48 85 d2                    	testq	%rdx, %rdx
100002100: 0f 85 63 00 00 00           	jne	0x100002169 <__text+0x1169>
100002106: 48 b8 00 00 00 00 00 00 00 80       	movabsq	$-0x8000000000000000, %rax ## imm = 0x8000000000000000
100002110: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100002117: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002121: 66 48 0f 6e f0              	movq	%rax, %xmm6
100002126: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100002130: 66 48 0f 6e f8              	movq	%rax, %xmm7
100002135: 0f 28 c6                    	movaps	%xmm6, %xmm0
100002138: f2 0f 5e c7                 	divsd	%xmm7, %xmm0
10000213c: f2 0f 11 85 38 00 00 00     	movsd	%xmm0, 0x38(%rbp)
100002144: 48 8b bd 20 00 00 00        	movq	0x20(%rbp), %rdi
10000214b: 48 8b b5 38 00 00 00        	movq	0x38(%rbp), %rsi
100002152: e8 55 f9 ff ff              	callq	0x100001aac <__text+0xaac>
100002157: 48 85 d2                    	testq	%rdx, %rdx
10000215a: 0f 85 09 00 00 00           	jne	0x100002169 <__text+0x1169>
100002160: 31 c0                       	xorl	%eax, %eax
100002162: 31 d2                       	xorl	%edx, %edx
100002164: e9 00 00 00 00              	jmp	0x100002169 <__text+0x1169>
100002169: 48 89 ec                    	movq	%rbp, %rsp
10000216c: 48 81 c4 50 00 00 00        	addq	$0x50, %rsp
100002173: 5d                          	popq	%rbp
100002174: c3                          	retq
100002175: 53                          	pushq	%rbx
100002176: 41 54                       	pushq	%r12
100002178: 41 55                       	pushq	%r13
10000217a: 41 56                       	pushq	%r14
10000217c: 41 57                       	pushq	%r15
10000217e: e8 f9 fe ff ff              	callq	0x10000207c <__text+0x107c>
100002183: 48 85 d2                    	testq	%rdx, %rdx
100002186: 0f 95 c2                    	setne	%dl
100002189: 0f b6 d2                    	movzbl	%dl, %edx
10000218c: 48 89 d0                    	movq	%rdx, %rax
10000218f: 41 5f                       	popq	%r15
100002191: 41 5e                       	popq	%r14
100002193: 41 5d                       	popq	%r13
100002195: 41 5c                       	popq	%r12
100002197: 5b                          	popq	%rbx
100002198: c3                          	retq
		...
100002ffd: 00 00                       	addb	%al, (%rax)
100002fff: 00                          	<unknown>
