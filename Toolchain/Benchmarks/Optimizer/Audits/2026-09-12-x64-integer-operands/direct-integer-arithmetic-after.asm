
/private/tmp/silex-part03-evidence/direct-integer-arithmetic-macos-x64:	file format mach-o 64-bit x86-64

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
100001039: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100001040: 49 39 c8                    	cmpq	%rcx, %r8
100001043: 0f 8d 70 00 00 00           	jge	0x1000010b9 <__text+0xb9>
100001049: 4c 89 c0                    	movq	%r8, %rax
10000104c: 48 b9 e9 a8 c0 17 57 3f e8 a8       	movabsq	$-0x5717c0a8e83f5717, %rcx ## imm = 0xA8E83F5717C0A8E9
100001056: 48 f7 e9                    	imulq	%rcx
100001059: 4c 89 c1                    	movq	%r8, %rcx
10000105c: 48 01 ca                    	addq	%rcx, %rdx
10000105f: 48 c1 fa 06                 	sarq	$0x6, %rdx
100001063: 48 89 d0                    	movq	%rdx, %rax
100001066: 48 c1 e8 3f                 	shrq	$0x3f, %rax
10000106a: 48 01 c2                    	addq	%rax, %rdx
10000106d: 48 b8 61 00 00 00 00 00 00 00       	movabsq	$0x61, %rax
100001077: 48 0f af d0                 	imulq	%rax, %rdx
10000107b: 4c 89 c1                    	movq	%r8, %rcx
10000107e: 48 29 d1                    	subq	%rdx, %rcx
100001081: 49 89 cb                    	movq	%rcx, %r11
100001084: 48 b8 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rax
10000108e: 49 89 c2                    	movq	%rax, %r10
100001091: 4d 0f af da                 	imulq	%r10, %r11
100001095: 4d 01 d9                    	addq	%r11, %r9
100001098: 71 0a                       	jno	0x1000010a4 <__text+0xa4>
10000109a: ba 01 00 00 00              	movl	$0x1, %edx
10000109f: e9 c0 00 00 00              	jmp	0x100001164 <__text+0x164>
1000010a4: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000010ae: 49 89 c2                    	movq	%rax, %r10
1000010b1: 4d 01 d0                    	addq	%r10, %r8
1000010b4: e9 80 ff ff ff              	jmp	0x100001039 <__text+0x39>
1000010b9: 48 83 ec 28                 	subq	$0x28, %rsp
1000010bd: 48 8d 74 24 27              	leaq	0x27(%rsp), %rsi
1000010c2: 4c 89 c8                    	movq	%r9, %rax
1000010c5: c6 06 0a                    	movb	$0xa, (%rsi)
1000010c8: 49 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r8
1000010d2: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
1000010dc: 48 85 c0                    	testq	%rax, %rax
1000010df: 0f 89 0d 00 00 00           	jns	0x1000010f2 <__text+0xf2>
1000010e5: 49 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r9
1000010ef: 48 f7 d8                    	negq	%rax
1000010f2: 48 85 c0                    	testq	%rax, %rax
1000010f5: 0f 85 0e 00 00 00           	jne	0x100001109 <__text+0x109>
1000010fb: 48 ff ce                    	decq	%rsi
1000010fe: c6 06 30                    	movb	$0x30, (%rsi)
100001101: 49 ff c0                    	incq	%r8
100001104: e9 23 00 00 00              	jmp	0x10000112c <__text+0x12c>
100001109: 48 b9 0a 00 00 00 00 00 00 00       	movabsq	$0xa, %rcx
100001113: 31 d2                       	xorl	%edx, %edx
100001115: 48 f7 f1                    	divq	%rcx
100001118: 80 c2 30                    	addb	$0x30, %dl
10000111b: 48 ff ce                    	decq	%rsi
10000111e: 88 16                       	movb	%dl, (%rsi)
100001120: 49 ff c0                    	incq	%r8
100001123: 48 85 c0                    	testq	%rax, %rax
100001126: 0f 85 dd ff ff ff           	jne	0x100001109 <__text+0x109>
10000112c: 4d 85 c9                    	testq	%r9, %r9
10000112f: 0f 84 09 00 00 00           	je	0x10000113e <__text+0x13e>
100001135: 48 ff ce                    	decq	%rsi
100001138: c6 06 2d                    	movb	$0x2d, (%rsi)
10000113b: 49 ff c0                    	incq	%r8
10000113e: 4c 89 c2                    	movq	%r8, %rdx
100001141: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000114b: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001155: 0f 05                       	syscall
100001157: 48 83 c4 28                 	addq	$0x28, %rsp
10000115b: 31 c0                       	xorl	%eax, %eax
10000115d: 31 d2                       	xorl	%edx, %edx
10000115f: e9 00 00 00 00              	jmp	0x100001164 <__text+0x164>
100001164: 48 89 ec                    	movq	%rbp, %rsp
100001167: 48 81 c4 80 00 00 00        	addq	$0x80, %rsp
10000116e: 5d                          	popq	%rbp
10000116f: c3                          	retq
100001170: 53                          	pushq	%rbx
100001171: 41 54                       	pushq	%r12
100001173: 41 55                       	pushq	%r13
100001175: 41 56                       	pushq	%r14
100001177: 41 57                       	pushq	%r15
100001179: e8 82 fe ff ff              	callq	0x100001000 <__text>
10000117e: 48 85 d2                    	testq	%rdx, %rdx
100001181: 0f 95 c2                    	setne	%dl
100001184: 0f b6 d2                    	movzbl	%dl, %edx
100001187: 48 89 d0                    	movq	%rdx, %rax
10000118a: 41 5f                       	popq	%r15
10000118c: 41 5e                       	popq	%r14
10000118e: 41 5d                       	popq	%r13
100001190: 41 5c                       	popq	%r12
100001192: 5b                          	popq	%rbx
100001193: c3                          	retq
		...
