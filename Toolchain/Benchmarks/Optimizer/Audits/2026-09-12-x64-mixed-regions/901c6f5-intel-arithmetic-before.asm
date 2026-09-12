
/private/tmp/silex-part03-evidence/901c6f5-intel/benchmark-before/arithmetic-release:	file format mach-o 64-bit x86-64

Disassembly of section __TEXT,__text:

0000000100001000 <__text>:
100001000: 55                          	pushq	%rbp
100001001: 48 89 e5                    	movq	%rsp, %rbp
100001004: 48 81 ec 80 00 00 00        	subq	$0x80, %rsp
10000100b: 48 89 e5                    	movq	%rsp, %rbp
10000100e: 48 b8 40 42 0f 00 00 00 00 00       	movabsq	$0xf4240, %rax  ## imm = 0xF4240
100001018: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
10000101f: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001029: 49 89 c1                    	movq	%rax, %r9
10000102c: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001036: 49 89 c0                    	movq	%rax, %r8
100001039: 4c 89 c0                    	movq	%r8, %rax
10000103c: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100001043: 48 39 c8                    	cmpq	%rcx, %rax
100001046: 0f 8d 8b 00 00 00           	jge	0x1000010d7 <__text+0xd7>
10000104c: 4c 89 c0                    	movq	%r8, %rax
10000104f: 48 b9 e9 a8 c0 17 57 3f e8 a8       	movabsq	$-0x5717c0a8e83f5717, %rcx ## imm = 0xA8E83F5717C0A8E9
100001059: 48 f7 e9                    	imulq	%rcx
10000105c: 4c 89 c1                    	movq	%r8, %rcx
10000105f: 48 01 ca                    	addq	%rcx, %rdx
100001062: 48 c1 fa 06                 	sarq	$0x6, %rdx
100001066: 48 89 d0                    	movq	%rdx, %rax
100001069: 48 c1 e8 3f                 	shrq	$0x3f, %rax
10000106d: 48 01 c2                    	addq	%rax, %rdx
100001070: 48 b8 61 00 00 00 00 00 00 00       	movabsq	$0x61, %rax
10000107a: 48 0f af d0                 	imulq	%rax, %rdx
10000107e: 4c 89 c1                    	movq	%r8, %rcx
100001081: 48 29 d1                    	subq	%rdx, %rcx
100001084: 49 89 cb                    	movq	%rcx, %r11
100001087: 48 b8 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rax
100001091: 49 89 c2                    	movq	%rax, %r10
100001094: 4c 89 d8                    	movq	%r11, %rax
100001097: 4c 89 d1                    	movq	%r10, %rcx
10000109a: 48 0f af c1                 	imulq	%rcx, %rax
10000109e: 49 89 c3                    	movq	%rax, %r11
1000010a1: 4c 89 c8                    	movq	%r9, %rax
1000010a4: 4c 89 d9                    	movq	%r11, %rcx
1000010a7: 48 01 c8                    	addq	%rcx, %rax
1000010aa: 71 0a                       	jno	0x1000010b6 <__text+0xb6>
1000010ac: ba 01 00 00 00              	movl	$0x1, %edx
1000010b1: e9 cc 00 00 00              	jmp	0x100001182 <__text+0x182>
1000010b6: 49 89 c1                    	movq	%rax, %r9
1000010b9: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000010c3: 49 89 c2                    	movq	%rax, %r10
1000010c6: 4c 89 c0                    	movq	%r8, %rax
1000010c9: 4c 89 d1                    	movq	%r10, %rcx
1000010cc: 48 01 c8                    	addq	%rcx, %rax
1000010cf: 49 89 c0                    	movq	%rax, %r8
1000010d2: e9 62 ff ff ff              	jmp	0x100001039 <__text+0x39>
1000010d7: 48 83 ec 28                 	subq	$0x28, %rsp
1000010db: 48 8d 74 24 27              	leaq	0x27(%rsp), %rsi
1000010e0: 4c 89 c8                    	movq	%r9, %rax
1000010e3: c6 06 0a                    	movb	$0xa, (%rsi)
1000010e6: 49 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r8
1000010f0: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
1000010fa: 48 85 c0                    	testq	%rax, %rax
1000010fd: 0f 89 0d 00 00 00           	jns	0x100001110 <__text+0x110>
100001103: 49 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r9
10000110d: 48 f7 d8                    	negq	%rax
100001110: 48 85 c0                    	testq	%rax, %rax
100001113: 0f 85 0e 00 00 00           	jne	0x100001127 <__text+0x127>
100001119: 48 ff ce                    	decq	%rsi
10000111c: c6 06 30                    	movb	$0x30, (%rsi)
10000111f: 49 ff c0                    	incq	%r8
100001122: e9 23 00 00 00              	jmp	0x10000114a <__text+0x14a>
100001127: 48 b9 0a 00 00 00 00 00 00 00       	movabsq	$0xa, %rcx
100001131: 31 d2                       	xorl	%edx, %edx
100001133: 48 f7 f1                    	divq	%rcx
100001136: 80 c2 30                    	addb	$0x30, %dl
100001139: 48 ff ce                    	decq	%rsi
10000113c: 88 16                       	movb	%dl, (%rsi)
10000113e: 49 ff c0                    	incq	%r8
100001141: 48 85 c0                    	testq	%rax, %rax
100001144: 0f 85 dd ff ff ff           	jne	0x100001127 <__text+0x127>
10000114a: 4d 85 c9                    	testq	%r9, %r9
10000114d: 0f 84 09 00 00 00           	je	0x10000115c <__text+0x15c>
100001153: 48 ff ce                    	decq	%rsi
100001156: c6 06 2d                    	movb	$0x2d, (%rsi)
100001159: 49 ff c0                    	incq	%r8
10000115c: 4c 89 c2                    	movq	%r8, %rdx
10000115f: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001169: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001173: 0f 05                       	syscall
100001175: 48 83 c4 28                 	addq	$0x28, %rsp
100001179: 31 c0                       	xorl	%eax, %eax
10000117b: 31 d2                       	xorl	%edx, %edx
10000117d: e9 00 00 00 00              	jmp	0x100001182 <__text+0x182>
100001182: 48 89 ec                    	movq	%rbp, %rsp
100001185: 48 81 c4 80 00 00 00        	addq	$0x80, %rsp
10000118c: 5d                          	popq	%rbp
10000118d: c3                          	retq
10000118e: 53                          	pushq	%rbx
10000118f: 41 54                       	pushq	%r12
100001191: 41 55                       	pushq	%r13
100001193: 41 56                       	pushq	%r14
100001195: 41 57                       	pushq	%r15
100001197: e8 64 fe ff ff              	callq	0x100001000 <__text>
10000119c: 48 85 d2                    	testq	%rdx, %rdx
10000119f: 0f 95 c2                    	setne	%dl
1000011a2: 0f b6 d2                    	movzbl	%dl, %edx
1000011a5: 48 89 d0                    	movq	%rdx, %rax
1000011a8: 41 5f                       	popq	%r15
1000011aa: 41 5e                       	popq	%r14
1000011ac: 41 5d                       	popq	%r13
1000011ae: 41 5c                       	popq	%r12
1000011b0: 5b                          	popq	%rbx
1000011b1: c3                          	retq
		...
100001ffe: 00 00                       	addb	%al, (%rax)
