
/private/tmp/silex-part03-evidence/collection-results-arithmetic-macos-x64:	file format mach-o 64-bit x86-64

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
100001039: 4c 89 c8                    	movq	%r9, %rax
10000103c: 49 89 c1                    	movq	%rax, %r9
10000103f: 4c 89 c0                    	movq	%r8, %rax
100001042: 49 89 c0                    	movq	%rax, %r8
100001045: 4c 89 c0                    	movq	%r8, %rax
100001048: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
10000104f: 48 39 c8                    	cmpq	%rcx, %rax
100001052: 0f 8d 97 00 00 00           	jge	0x1000010ef <__text+0xef>
100001058: 4c 89 c0                    	movq	%r8, %rax
10000105b: 48 b9 e9 a8 c0 17 57 3f e8 a8       	movabsq	$-0x5717c0a8e83f5717, %rcx ## imm = 0xA8E83F5717C0A8E9
100001065: 48 f7 e9                    	imulq	%rcx
100001068: 4c 89 c1                    	movq	%r8, %rcx
10000106b: 48 01 ca                    	addq	%rcx, %rdx
10000106e: 48 c1 fa 06                 	sarq	$0x6, %rdx
100001072: 48 89 d0                    	movq	%rdx, %rax
100001075: 48 c1 e8 3f                 	shrq	$0x3f, %rax
100001079: 48 01 c2                    	addq	%rax, %rdx
10000107c: 48 b8 61 00 00 00 00 00 00 00       	movabsq	$0x61, %rax
100001086: 48 0f af d0                 	imulq	%rax, %rdx
10000108a: 4c 89 c1                    	movq	%r8, %rcx
10000108d: 48 29 d1                    	subq	%rdx, %rcx
100001090: 49 89 cb                    	movq	%rcx, %r11
100001093: 48 b8 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rax
10000109d: 49 89 c2                    	movq	%rax, %r10
1000010a0: 4c 89 d8                    	movq	%r11, %rax
1000010a3: 4c 89 d1                    	movq	%r10, %rcx
1000010a6: 48 0f af c1                 	imulq	%rcx, %rax
1000010aa: 49 89 c3                    	movq	%rax, %r11
1000010ad: 4c 89 c8                    	movq	%r9, %rax
1000010b0: 4c 89 d9                    	movq	%r11, %rcx
1000010b3: 48 01 c8                    	addq	%rcx, %rax
1000010b6: 71 0a                       	jno	0x1000010c2 <__text+0xc2>
1000010b8: ba 01 00 00 00              	movl	$0x1, %edx
1000010bd: e9 d8 00 00 00              	jmp	0x10000119a <__text+0x19a>
1000010c2: 49 89 c1                    	movq	%rax, %r9
1000010c5: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000010cf: 49 89 c2                    	movq	%rax, %r10
1000010d2: 4c 89 c0                    	movq	%r8, %rax
1000010d5: 4c 89 d1                    	movq	%r10, %rcx
1000010d8: 48 01 c8                    	addq	%rcx, %rax
1000010db: 49 89 c0                    	movq	%rax, %r8
1000010de: 4c 89 c8                    	movq	%r9, %rax
1000010e1: 49 89 c1                    	movq	%rax, %r9
1000010e4: 4c 89 c0                    	movq	%r8, %rax
1000010e7: 49 89 c0                    	movq	%rax, %r8
1000010ea: e9 56 ff ff ff              	jmp	0x100001045 <__text+0x45>
1000010ef: 48 83 ec 28                 	subq	$0x28, %rsp
1000010f3: 48 8d 74 24 27              	leaq	0x27(%rsp), %rsi
1000010f8: 4c 89 c8                    	movq	%r9, %rax
1000010fb: c6 06 0a                    	movb	$0xa, (%rsi)
1000010fe: 49 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r8
100001108: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
100001112: 48 85 c0                    	testq	%rax, %rax
100001115: 0f 89 0d 00 00 00           	jns	0x100001128 <__text+0x128>
10000111b: 49 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r9
100001125: 48 f7 d8                    	negq	%rax
100001128: 48 85 c0                    	testq	%rax, %rax
10000112b: 0f 85 0e 00 00 00           	jne	0x10000113f <__text+0x13f>
100001131: 48 ff ce                    	decq	%rsi
100001134: c6 06 30                    	movb	$0x30, (%rsi)
100001137: 49 ff c0                    	incq	%r8
10000113a: e9 23 00 00 00              	jmp	0x100001162 <__text+0x162>
10000113f: 48 b9 0a 00 00 00 00 00 00 00       	movabsq	$0xa, %rcx
100001149: 31 d2                       	xorl	%edx, %edx
10000114b: 48 f7 f1                    	divq	%rcx
10000114e: 80 c2 30                    	addb	$0x30, %dl
100001151: 48 ff ce                    	decq	%rsi
100001154: 88 16                       	movb	%dl, (%rsi)
100001156: 49 ff c0                    	incq	%r8
100001159: 48 85 c0                    	testq	%rax, %rax
10000115c: 0f 85 dd ff ff ff           	jne	0x10000113f <__text+0x13f>
100001162: 4d 85 c9                    	testq	%r9, %r9
100001165: 0f 84 09 00 00 00           	je	0x100001174 <__text+0x174>
10000116b: 48 ff ce                    	decq	%rsi
10000116e: c6 06 2d                    	movb	$0x2d, (%rsi)
100001171: 49 ff c0                    	incq	%r8
100001174: 4c 89 c2                    	movq	%r8, %rdx
100001177: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
100001181: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
10000118b: 0f 05                       	syscall
10000118d: 48 83 c4 28                 	addq	$0x28, %rsp
100001191: 31 c0                       	xorl	%eax, %eax
100001193: 31 d2                       	xorl	%edx, %edx
100001195: e9 00 00 00 00              	jmp	0x10000119a <__text+0x19a>
10000119a: 48 89 ec                    	movq	%rbp, %rsp
10000119d: 48 81 c4 80 00 00 00        	addq	$0x80, %rsp
1000011a4: 5d                          	popq	%rbp
1000011a5: c3                          	retq
1000011a6: 53                          	pushq	%rbx
1000011a7: 41 54                       	pushq	%r12
1000011a9: 41 55                       	pushq	%r13
1000011ab: 41 56                       	pushq	%r14
1000011ad: 41 57                       	pushq	%r15
1000011af: e8 4c fe ff ff              	callq	0x100001000 <__text>
1000011b4: 48 85 d2                    	testq	%rdx, %rdx
1000011b7: 0f 95 c2                    	setne	%dl
1000011ba: 0f b6 d2                    	movzbl	%dl, %edx
1000011bd: 48 89 d0                    	movq	%rdx, %rax
1000011c0: 41 5f                       	popq	%r15
1000011c2: 41 5e                       	popq	%r14
1000011c4: 41 5d                       	popq	%r13
1000011c6: 41 5c                       	popq	%r12
1000011c8: 5b                          	popq	%rbx
1000011c9: c3                          	retq
		...
100001ffe: 00 00                       	addb	%al, (%rax)
