
/private/tmp/silex-part03-evidence/901c6f5-intel/benchmark-before/objects-release:	file format mach-o 64-bit x86-64

Disassembly of section __TEXT,__text:

0000000100001000 <__text>:
100001000: 55                          	pushq	%rbp
100001001: 48 89 e5                    	movq	%rsp, %rbp
100001004: 48 81 ec b0 01 00 00        	subq	$0x1b0, %rsp            ## imm = 0x1B0
10000100b: 48 89 e5                    	movq	%rsp, %rbp
10000100e: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
100001015: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000101f: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100001026: 48 be 28 00 00 00 00 00 00 00       	movabsq	$0x28, %rsi
100001030: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
10000103a: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001044: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
10000104e: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
100001058: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
100001062: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
10000106c: 0f 05                       	syscall
10000106e: 0f 83 0f 00 00 00           	jae	0x100001083 <__text+0x83>
100001074: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
10000107e: e9 47 07 00 00              	jmp	0x1000017ca <__text+0x7ca>
100001083: 48 89 c3                    	movq	%rax, %rbx
100001086: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
100001090: 48 89 8b 00 00 00 00        	movq	%rcx, (%rbx)
100001097: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000010a1: 48 89 83 08 00 00 00        	movq	%rax, 0x8(%rbx)
1000010a8: 48 89 83 10 00 00 00        	movq	%rax, 0x10(%rbx)
1000010af: 48 89 83 18 00 00 00        	movq	%rax, 0x18(%rbx)
1000010b6: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
1000010bd: 48 89 83 20 00 00 00        	movq	%rax, 0x20(%rbx)
1000010c4: 48 89 9d 10 00 00 00        	movq	%rbx, 0x10(%rbp)
1000010cb: 4c 8b 95 10 00 00 00        	movq	0x10(%rbp), %r10
1000010d2: f0                          	lock
1000010d3: 49 ff 42 08                 	incq	0x8(%r10)
1000010d7: 48 8b 85 10 00 00 00        	movq	0x10(%rbp), %rax
1000010de: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
1000010e5: 48 b8 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rax
1000010ef: 48 89 85 18 00 00 00        	movq	%rax, 0x18(%rbp)
1000010f6: 48 b8 05 00 00 00 00 00 00 00       	movabsq	$0x5, %rax
100001100: 48 89 85 20 00 00 00        	movq	%rax, 0x20(%rbp)
100001107: 48 b8 07 00 00 00 00 00 00 00       	movabsq	$0x7, %rax
100001111: 48 89 85 28 00 00 00        	movq	%rax, 0x28(%rbp)
100001118: 48 b8 0b 00 00 00 00 00 00 00       	movabsq	$0xb, %rax
100001122: 48 89 85 30 00 00 00        	movq	%rax, 0x30(%rbp)
100001129: 48 be 48 00 00 00 00 00 00 00       	movabsq	$0x48, %rsi
100001133: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
10000113d: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001147: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
100001151: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
10000115b: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
100001165: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
10000116f: 0f 05                       	syscall
100001171: 0f 83 0f 00 00 00           	jae	0x100001186 <__text+0x186>
100001177: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001181: e9 44 06 00 00              	jmp	0x1000017ca <__text+0x7ca>
100001186: 49 89 c2                    	movq	%rax, %r10
100001189: 49 bc 04 00 00 00 00 00 00 00       	movabsq	$0x4, %r12
100001193: 4d 89 a2 00 00 00 00        	movq	%r12, (%r10)
10000119a: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
1000011a4: 49 89 82 08 00 00 00        	movq	%rax, 0x8(%r10)
1000011ab: 49 89 82 10 00 00 00        	movq	%rax, 0x10(%r10)
1000011b2: 49 89 82 20 00 00 00        	movq	%rax, 0x20(%r10)
1000011b9: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000011c3: 49 89 82 08 00 00 00        	movq	%rax, 0x8(%r10)
1000011ca: 49 89 b2 18 00 00 00        	movq	%rsi, 0x18(%r10)
1000011d1: 48 8b 85 18 00 00 00        	movq	0x18(%rbp), %rax
1000011d8: 49 89 82 28 00 00 00        	movq	%rax, 0x28(%r10)
1000011df: 48 8b 85 20 00 00 00        	movq	0x20(%rbp), %rax
1000011e6: 49 89 82 30 00 00 00        	movq	%rax, 0x30(%r10)
1000011ed: 48 8b 85 28 00 00 00        	movq	0x28(%rbp), %rax
1000011f4: 49 89 82 38 00 00 00        	movq	%rax, 0x38(%r10)
1000011fb: 48 8b 85 30 00 00 00        	movq	0x30(%rbp), %rax
100001202: 49 89 82 40 00 00 00        	movq	%rax, 0x40(%r10)
100001209: 4c 89 95 38 00 00 00        	movq	%r10, 0x38(%rbp)
100001210: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000121a: 49 89 c0                    	movq	%rax, %r8
10000121d: 4c 89 c0                    	movq	%r8, %rax
100001220: 48 8b 8d 00 00 00 00        	movq	(%rbp), %rcx
100001227: 48 39 c8                    	cmpq	%rcx, %rax
10000122a: 0f 8d 56 00 00 00           	jge	0x100001286 <__text+0x286>
100001230: 4c 89 c0                    	movq	%r8, %rax
100001233: 48 89 c2                    	movq	%rax, %rdx
100001236: 48 c1 fa 3f                 	sarq	$0x3f, %rdx
10000123a: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100001244: 48 21 ca                    	andq	%rcx, %rdx
100001247: 48 01 c2                    	addq	%rax, %rdx
10000124a: 48 c1 fa 01                 	sarq	$0x1, %rdx
10000124e: 48 b8 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rax
100001258: 48 0f af d0                 	imulq	%rax, %rdx
10000125c: 4c 89 c1                    	movq	%r8, %rcx
10000125f: 48 29 d1                    	subq	%rdx, %rcx
100001262: 49 89 ca                    	movq	%rcx, %r10
100001265: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
10000126f: 49 89 c1                    	movq	%rax, %r9
100001272: 4c 89 d0                    	movq	%r10, %rax
100001275: 4c 89 c9                    	movq	%r9, %rcx
100001278: 48 39 c8                    	cmpq	%rcx, %rax
10000127b: 0f 84 86 00 00 00           	je	0x100001307 <__text+0x307>
100001281: e9 8e 01 00 00              	jmp	0x100001414 <__text+0x414>
100001286: 48 8b 85 78 01 00 00        	movq	0x178(%rbp), %rax
10000128d: 48 89 85 c0 00 00 00        	movq	%rax, 0xc0(%rbp)
100001294: 48 8b 9d c0 00 00 00        	movq	0xc0(%rbp), %rbx
10000129b: 48 8b 83 20 00 00 00        	movq	0x20(%rbx), %rax
1000012a2: 48 89 85 38 01 00 00        	movq	%rax, 0x138(%rbp)
1000012a9: 48 8b 85 38 01 00 00        	movq	0x138(%rbp), %rax
1000012b0: 48 89 85 c8 00 00 00        	movq	%rax, 0xc8(%rbp)
1000012b7: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000012c1: 48 89 85 d0 00 00 00        	movq	%rax, 0xd0(%rbp)
1000012c8: 48 8b 85 c8 00 00 00        	movq	0xc8(%rbp), %rax
1000012cf: 48 89 85 d8 00 00 00        	movq	%rax, 0xd8(%rbp)
1000012d6: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
1000012dd: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000012e7: 48 39 c8                    	cmpq	%rcx, %rax
1000012ea: 0f 94 c0                    	sete	%al
1000012ed: 48 0f b6 c0                 	movzbq	%al, %rax
1000012f1: 48 89 85 e0 00 00 00        	movq	%rax, 0xe0(%rbp)
1000012f8: 48 8b 85 e0 00 00 00        	movq	0xe0(%rbp), %rax
1000012ff: 48 85 c0                    	testq	%rax, %rax
100001302: e9 ab 01 00 00              	jmp	0x1000014b2 <__text+0x4b2>
100001307: 48 8b 85 78 01 00 00        	movq	0x178(%rbp), %rax
10000130e: 48 89 85 70 00 00 00        	movq	%rax, 0x70(%rbp)
100001315: 4c 89 c0                    	movq	%r8, %rax
100001318: 48 89 c2                    	movq	%rax, %rdx
10000131b: 48 c1 fa 3f                 	sarq	$0x3f, %rdx
10000131f: 48 b9 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rcx
100001329: 48 21 ca                    	andq	%rcx, %rdx
10000132c: 48 01 c2                    	addq	%rax, %rdx
10000132f: 48 c1 fa 02                 	sarq	$0x2, %rdx
100001333: 48 b8 04 00 00 00 00 00 00 00       	movabsq	$0x4, %rax
10000133d: 48 0f af d0                 	imulq	%rax, %rdx
100001341: 4c 89 c1                    	movq	%r8, %rcx
100001344: 48 29 d1                    	subq	%rdx, %rcx
100001347: 48 89 8d 80 00 00 00        	movq	%rcx, 0x80(%rbp)
10000134e: 48 8b 9d 38 00 00 00        	movq	0x38(%rbp), %rbx
100001355: 48 8b 8b 00 00 00 00        	movq	(%rbx), %rcx
10000135c: 48 81 c3 28 00 00 00        	addq	$0x28, %rbx
100001363: 48 8b 85 80 00 00 00        	movq	0x80(%rbp), %rax
10000136a: 48 85 c0                    	testq	%rax, %rax
10000136d: 0f 89 03 00 00 00           	jns	0x100001376 <__text+0x376>
100001373: 48 01 c8                    	addq	%rcx, %rax
100001376: 48 39 c8                    	cmpq	%rcx, %rax
100001379: 0f 82 0f 00 00 00           	jb	0x10000138e <__text+0x38e>
10000137f: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001389: e9 3c 04 00 00              	jmp	0x1000017ca <__text+0x7ca>
10000138e: 48 69 c0 08 00 00 00        	imulq	$0x8, %rax, %rax
100001395: 48 01 c3                    	addq	%rax, %rbx
100001398: 48 8b 83 00 00 00 00        	movq	(%rbx), %rax
10000139f: 48 89 85 88 00 00 00        	movq	%rax, 0x88(%rbp)
1000013a6: 48 8b 9d 70 00 00 00        	movq	0x70(%rbp), %rbx
1000013ad: 48 8b 83 20 00 00 00        	movq	0x20(%rbx), %rax
1000013b4: 48 89 85 40 01 00 00        	movq	%rax, 0x140(%rbp)
1000013bb: 48 8b 85 40 01 00 00        	movq	0x140(%rbp), %rax
1000013c2: 48 8b 8d 88 00 00 00        	movq	0x88(%rbp), %rcx
1000013c9: 48 01 c8                    	addq	%rcx, %rax
1000013cc: 71 0a                       	jno	0x1000013d8 <__text+0x3d8>
1000013ce: ba 01 00 00 00              	movl	$0x1, %edx
1000013d3: e9 f2 03 00 00              	jmp	0x1000017ca <__text+0x7ca>
1000013d8: 48 89 85 48 01 00 00        	movq	%rax, 0x148(%rbp)
1000013df: 48 8b 9d 70 00 00 00        	movq	0x70(%rbp), %rbx
1000013e6: 48 89 9d 50 01 00 00        	movq	%rbx, 0x150(%rbp)
1000013ed: 48 8b 85 48 01 00 00        	movq	0x148(%rbp), %rax
1000013f4: 48 89 83 20 00 00 00        	movq	%rax, 0x20(%rbx)
1000013fb: 48 8b 85 50 01 00 00        	movq	0x150(%rbp), %rax
100001402: 49 89 c1                    	movq	%rax, %r9
100001405: 4c 89 c8                    	movq	%r9, %rax
100001408: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
10000140f: e9 80 00 00 00              	jmp	0x100001494 <__text+0x494>
100001414: 48 8b 85 78 01 00 00        	movq	0x178(%rbp), %rax
10000141b: 48 89 85 98 00 00 00        	movq	%rax, 0x98(%rbp)
100001422: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000142c: 49 89 c1                    	movq	%rax, %r9
10000142f: 48 8b 9d 98 00 00 00        	movq	0x98(%rbp), %rbx
100001436: 48 8b 83 20 00 00 00        	movq	0x20(%rbx), %rax
10000143d: 48 89 85 58 01 00 00        	movq	%rax, 0x158(%rbp)
100001444: 48 8b 85 58 01 00 00        	movq	0x158(%rbp), %rax
10000144b: 4c 89 c9                    	movq	%r9, %rcx
10000144e: 48 01 c8                    	addq	%rcx, %rax
100001451: 71 0a                       	jno	0x10000145d <__text+0x45d>
100001453: ba 01 00 00 00              	movl	$0x1, %edx
100001458: e9 6d 03 00 00              	jmp	0x1000017ca <__text+0x7ca>
10000145d: 48 89 85 60 01 00 00        	movq	%rax, 0x160(%rbp)
100001464: 48 8b 9d 98 00 00 00        	movq	0x98(%rbp), %rbx
10000146b: 48 89 9d 68 01 00 00        	movq	%rbx, 0x168(%rbp)
100001472: 48 8b 85 60 01 00 00        	movq	0x160(%rbp), %rax
100001479: 48 89 83 20 00 00 00        	movq	%rax, 0x20(%rbx)
100001480: 48 8b 85 68 01 00 00        	movq	0x168(%rbp), %rax
100001487: 49 89 c1                    	movq	%rax, %r9
10000148a: 4c 89 c8                    	movq	%r9, %rax
10000148d: 48 89 85 78 01 00 00        	movq	%rax, 0x178(%rbp)
100001494: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
10000149e: 49 89 c1                    	movq	%rax, %r9
1000014a1: 4c 89 c0                    	movq	%r8, %rax
1000014a4: 4c 89 c9                    	movq	%r9, %rcx
1000014a7: 48 01 c8                    	addq	%rcx, %rax
1000014aa: 49 89 c0                    	movq	%rax, %r8
1000014ad: e9 6b fd ff ff              	jmp	0x10000121d <__text+0x21d>
1000014b2: 48 8b 85 d0 00 00 00        	movq	0xd0(%rbp), %rax
1000014b9: 48 89 85 e8 00 00 00        	movq	%rax, 0xe8(%rbp)
1000014c0: 48 8b 85 d8 00 00 00        	movq	0xd8(%rbp), %rax
1000014c7: 48 89 85 f0 00 00 00        	movq	%rax, 0xf0(%rbp)
1000014ce: 48 8b 85 f0 00 00 00        	movq	0xf0(%rbp), %rax
1000014d5: 48 89 85 08 01 00 00        	movq	%rax, 0x108(%rbp)
1000014dc: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
1000014e3: 48 89 85 70 01 00 00        	movq	%rax, 0x170(%rbp)
1000014ea: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000014f4: 48 89 85 f8 00 00 00        	movq	%rax, 0xf8(%rbp)
1000014fb: 48 8b 85 08 01 00 00        	movq	0x108(%rbp), %rax
100001502: 48 89 85 00 01 00 00        	movq	%rax, 0x100(%rbp)
100001509: 48 8b 85 f8 00 00 00        	movq	0xf8(%rbp), %rax
100001510: 48 89 85 10 01 00 00        	movq	%rax, 0x110(%rbp)
100001517: 48 8b 85 00 01 00 00        	movq	0x100(%rbp), %rax
10000151e: 48 89 85 18 01 00 00        	movq	%rax, 0x118(%rbp)
100001525: 48 8b 85 10 01 00 00        	movq	0x110(%rbp), %rax
10000152c: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100001536: 48 39 c8                    	cmpq	%rcx, %rax
100001539: 0f 94 c0                    	sete	%al
10000153c: 48 0f b6 c0                 	movzbq	%al, %rax
100001540: 48 89 85 20 01 00 00        	movq	%rax, 0x120(%rbp)
100001547: 48 8b 85 20 01 00 00        	movq	0x120(%rbp), %rax
10000154e: 48 85 c0                    	testq	%rax, %rax
100001551: 4c 8b 95 38 00 00 00        	movq	0x38(%rbp), %r10
100001558: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
10000155f: 48 85 c0                    	testq	%rax, %rax
100001562: 0f 84 89 00 00 00           	je	0x1000015f1 <__text+0x5f1>
100001568: 49 89 c3                    	movq	%rax, %r11
10000156b: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100001572: f0                          	lock
100001573: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100001578: 0f 85 da ff ff ff           	jne	0x100001558 <__text+0x558>
10000157e: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100001585: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
10000158c: 4c 01 d8                    	addq	%r11, %rax
10000158f: 48 85 c0                    	testq	%rax, %rax
100001592: 0f 85 59 00 00 00           	jne	0x1000015f1 <__text+0x5f1>
100001598: 49 8b 82 20 00 00 00        	movq	0x20(%r10), %rax
10000159f: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
1000015a9: 48 39 c8                    	cmpq	%rcx, %rax
1000015ac: 0f 84 e6 ff ff ff           	je	0x100001598 <__text+0x598>
1000015b2: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
1000015bc: 48 39 c8                    	cmpq	%rcx, %rax
1000015bf: 0f 84 2c 00 00 00           	je	0x1000015f1 <__text+0x5f1>
1000015c5: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
1000015cf: f0                          	lock
1000015d0: 4d 0f b1 5a 20              	cmpxchgq	%r11, 0x20(%r10)
1000015d5: 0f 85 bd ff ff ff           	jne	0x100001598 <__text+0x598>
1000015db: 49 8b b2 18 00 00 00        	movq	0x18(%r10), %rsi
1000015e2: 4c 89 d7                    	movq	%r10, %rdi
1000015e5: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
1000015ef: 0f 05                       	syscall
1000015f1: 48 8b 85 78 01 00 00        	movq	0x178(%rbp), %rax
1000015f8: 48 89 85 28 01 00 00        	movq	%rax, 0x128(%rbp)
1000015ff: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001609: 48 89 85 a0 01 00 00        	movq	%rax, 0x1a0(%rbp)
100001610: 4c 8b 95 28 01 00 00        	movq	0x128(%rbp), %r10
100001617: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
10000161e: 48 85 c0                    	testq	%rax, %rax
100001621: 0f 84 95 01 00 00           	je	0x1000017bc <__text+0x7bc>
100001627: 49 89 c3                    	movq	%rax, %r11
10000162a: 49 81 eb 01 00 00 00        	subq	$0x1, %r11
100001631: f0                          	lock
100001632: 4d 0f b1 5a 08              	cmpxchgq	%r11, 0x8(%r10)
100001637: 0f 85 da ff ff ff           	jne	0x100001617 <__text+0x617>
10000163d: 49 8b 82 08 00 00 00        	movq	0x8(%r10), %rax
100001644: 48 85 c0                    	testq	%rax, %rax
100001647: 0f 85 6f 01 00 00           	jne	0x1000017bc <__text+0x7bc>
10000164d: 4d 8b 9a 10 00 00 00        	movq	0x10(%r10), %r11
100001654: 4d 85 db                    	testq	%r11, %r11
100001657: 0f 85 48 00 00 00           	jne	0x1000016a5 <__text+0x6a5>
10000165d: 49 8b 82 18 00 00 00        	movq	0x18(%r10), %rax
100001664: 48 b9 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rcx
10000166e: 48 39 c8                    	cmpq	%rcx, %rax
100001671: 0f 84 e6 ff ff ff           	je	0x10000165d <__text+0x65d>
100001677: 48 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rcx
100001681: 48 39 c8                    	cmpq	%rcx, %rax
100001684: 0f 84 32 01 00 00           	je	0x1000017bc <__text+0x7bc>
10000168a: 49 bb 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r11
100001694: f0                          	lock
100001695: 4d 0f b1 5a 18              	cmpxchgq	%r11, 0x18(%r10)
10000169a: 0f 85 bd ff ff ff           	jne	0x10000165d <__text+0x65d>
1000016a0: e9 6b 00 00 00              	jmp	0x100001710 <__text+0x710>
1000016a5: 4c 8b 95 28 01 00 00        	movq	0x128(%rbp), %r10
1000016ac: 49 8b 82 18 00 00 00        	movq	0x18(%r10), %rax
1000016b3: 48 85 c0                    	testq	%rax, %rax
1000016b6: 0f 85 00 01 00 00           	jne	0x1000017bc <__text+0x7bc>
1000016bc: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
1000016c6: 48 8b b5 28 01 00 00        	movq	0x128(%rbp), %rsi
1000016cd: 48 8d 15 0c 4a 00 00        	leaq	0x4a0c(%rip), %rdx      ## 0x1000060e0
1000016d4: 48 b9 02 01 00 00 00 00 00 00       	movabsq	$0x102, %rcx    ## imm = 0x102
1000016de: 4c 8d 05 38 02 00 00        	leaq	0x238(%rip), %r8        ## 0x10000191d <__text+0x91d>
1000016e5: 4c 8d 0d 7c 02 00 00        	leaq	0x27c(%rip), %r9        ## 0x100001968 <__text+0x968>
1000016ec: e8 47 0d 00 00              	callq	0x100002438 <__text+0x1438>
1000016f1: 48 85 c0                    	testq	%rax, %rax
1000016f4: 48 ba 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdx
1000016fe: 0f 84 b8 00 00 00           	je	0x1000017bc <__text+0x7bc>
100001704: 48 89 85 a0 01 00 00        	movq	%rax, 0x1a0(%rbp)
10000170b: e9 00 00 00 00              	jmp	0x100001710 <__text+0x710>
100001710: 4c 8b 95 28 01 00 00        	movq	0x128(%rbp), %r10
100001717: 4d 8b a2 00 00 00 00        	movq	(%r10), %r12
10000171e: 48 b8 02 00 00 00 00 00 00 00       	movabsq	$0x2, %rax
100001728: 49 39 c4                    	cmpq	%rax, %r12
10000172b: 0f 85 3a 00 00 00           	jne	0x10000176b <__text+0x76b>
100001731: 48 8b bd 28 01 00 00        	movq	0x128(%rbp), %rdi
100001738: e8 8f 01 00 00              	callq	0x1000018cc <__text+0x8cc>
10000173d: 48 85 d2                    	testq	%rdx, %rdx
100001740: 0f 85 84 00 00 00           	jne	0x1000017ca <__text+0x7ca>
100001746: 4c 8b 95 28 01 00 00        	movq	0x128(%rbp), %r10
10000174d: 48 be 28 00 00 00 00 00 00 00       	movabsq	$0x28, %rsi
100001757: 4c 89 d7                    	movq	%r10, %rdi
10000175a: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100001764: 0f 05                       	syscall
100001766: e9 00 00 00 00              	jmp	0x10000176b <__text+0x76b>
10000176b: 48 8b b5 a0 01 00 00        	movq	0x1a0(%rbp), %rsi
100001772: 48 85 f6                    	testq	%rsi, %rsi
100001775: 0f 84 41 00 00 00           	je	0x1000017bc <__text+0x7bc>
10000177b: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
100001785: 48 ba 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdx
10000178f: 48 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rcx
100001799: 49 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r8
1000017a3: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
1000017ad: e8 86 0c 00 00              	callq	0x100002438 <__text+0x1438>
1000017b2: 48 ba 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdx
1000017bc: 48 8b 85 70 01 00 00        	movq	0x170(%rbp), %rax
1000017c3: 31 d2                       	xorl	%edx, %edx
1000017c5: e9 00 00 00 00              	jmp	0x1000017ca <__text+0x7ca>
1000017ca: 48 89 ec                    	movq	%rbp, %rsp
1000017cd: 48 81 c4 b0 01 00 00        	addq	$0x1b0, %rsp            ## imm = 0x1B0
1000017d4: 5d                          	popq	%rbp
1000017d5: c3                          	retq
1000017d6: 55                          	pushq	%rbp
1000017d7: 48 89 e5                    	movq	%rsp, %rbp
1000017da: 48 81 ec 20 00 00 00        	subq	$0x20, %rsp
1000017e1: 48 89 e5                    	movq	%rsp, %rbp
1000017e4: 48 b8 80 84 1e 00 00 00 00 00       	movabsq	$0x1e8480, %rax ## imm = 0x1E8480
1000017ee: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
1000017f5: 48 8b bd 00 00 00 00        	movq	(%rbp), %rdi
1000017fc: e8 ff f7 ff ff              	callq	0x100001000 <__text>
100001801: 48 85 d2                    	testq	%rdx, %rdx
100001804: 0f 85 b6 00 00 00           	jne	0x1000018c0 <__text+0x8c0>
10000180a: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100001811: 48 83 ec 28                 	subq	$0x28, %rsp
100001815: 48 8d 74 24 27              	leaq	0x27(%rsp), %rsi
10000181a: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
100001821: c6 06 0a                    	movb	$0xa, (%rsi)
100001824: 49 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r8
10000182e: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
100001838: 48 85 c0                    	testq	%rax, %rax
10000183b: 0f 89 0d 00 00 00           	jns	0x10000184e <__text+0x84e>
100001841: 49 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r9
10000184b: 48 f7 d8                    	negq	%rax
10000184e: 48 85 c0                    	testq	%rax, %rax
100001851: 0f 85 0e 00 00 00           	jne	0x100001865 <__text+0x865>
100001857: 48 ff ce                    	decq	%rsi
10000185a: c6 06 30                    	movb	$0x30, (%rsi)
10000185d: 49 ff c0                    	incq	%r8
100001860: e9 23 00 00 00              	jmp	0x100001888 <__text+0x888>
100001865: 48 b9 0a 00 00 00 00 00 00 00       	movabsq	$0xa, %rcx
10000186f: 31 d2                       	xorl	%edx, %edx
100001871: 48 f7 f1                    	divq	%rcx
100001874: 80 c2 30                    	addb	$0x30, %dl
100001877: 48 ff ce                    	decq	%rsi
10000187a: 88 16                       	movb	%dl, (%rsi)
10000187c: 49 ff c0                    	incq	%r8
10000187f: 48 85 c0                    	testq	%rax, %rax
100001882: 0f 85 dd ff ff ff           	jne	0x100001865 <__text+0x865>
100001888: 4d 85 c9                    	testq	%r9, %r9
10000188b: 0f 84 09 00 00 00           	je	0x10000189a <__text+0x89a>
100001891: 48 ff ce                    	decq	%rsi
100001894: c6 06 2d                    	movb	$0x2d, (%rsi)
100001897: 49 ff c0                    	incq	%r8
10000189a: 4c 89 c2                    	movq	%r8, %rdx
10000189d: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000018a7: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000018b1: 0f 05                       	syscall
1000018b3: 48 83 c4 28                 	addq	$0x28, %rsp
1000018b7: 31 c0                       	xorl	%eax, %eax
1000018b9: 31 d2                       	xorl	%edx, %edx
1000018bb: e9 00 00 00 00              	jmp	0x1000018c0 <__text+0x8c0>
1000018c0: 48 89 ec                    	movq	%rbp, %rsp
1000018c3: 48 81 c4 20 00 00 00        	addq	$0x20, %rsp
1000018ca: 5d                          	popq	%rbp
1000018cb: c3                          	retq
1000018cc: 55                          	pushq	%rbp
1000018cd: 48 89 e5                    	movq	%rsp, %rbp
1000018d0: 48 81 ec 10 00 00 00        	subq	$0x10, %rsp
1000018d7: 48 89 e5                    	movq	%rsp, %rbp
1000018da: 48 81 ed 08 00 00 00        	subq	$0x8, %rbp
1000018e1: 49 89 f8                    	movq	%rdi, %r8
1000018e4: 31 c0                       	xorl	%eax, %eax
1000018e6: 31 d2                       	xorl	%edx, %edx
1000018e8: e9 00 00 00 00              	jmp	0x1000018ed <__text+0x8ed>
1000018ed: 48 89 ec                    	movq	%rbp, %rsp
1000018f0: 48 81 c4 18 00 00 00        	addq	$0x18, %rsp
1000018f7: 5d                          	popq	%rbp
1000018f8: c3                          	retq
1000018f9: 53                          	pushq	%rbx
1000018fa: 41 54                       	pushq	%r12
1000018fc: 41 55                       	pushq	%r13
1000018fe: 41 56                       	pushq	%r14
100001900: 41 57                       	pushq	%r15
100001902: e8 cf fe ff ff              	callq	0x1000017d6 <__text+0x7d6>
100001907: 48 85 d2                    	testq	%rdx, %rdx
10000190a: 0f 95 c2                    	setne	%dl
10000190d: 0f b6 d2                    	movzbl	%dl, %edx
100001910: 48 89 d0                    	movq	%rdx, %rax
100001913: 41 5f                       	popq	%r15
100001915: 41 5e                       	popq	%r14
100001917: 41 5d                       	popq	%r13
100001919: 41 5c                       	popq	%r12
10000191b: 5b                          	popq	%rbx
10000191c: c3                          	retq
10000191d: 48 89 fe                    	movq	%rdi, %rsi
100001920: 48 bf 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdi
10000192a: 48 ba 03 00 00 00 00 00 00 00       	movabsq	$0x3, %rdx
100001934: 49 ba 02 10 00 00 00 00 00 00       	movabsq	$0x1002, %r10   ## imm = 0x1002
10000193e: 49 b8 ff ff ff ff ff ff ff ff       	movabsq	$-0x1, %r8
100001948: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
100001952: 48 b8 c5 00 00 02 00 00 00 00       	movabsq	$0x20000c5, %rax ## imm = 0x20000C5
10000195c: 0f 05                       	syscall
10000195e: 0f 83 03 00 00 00           	jae	0x100001967 <__text+0x967>
100001964: 31 c0                       	xorl	%eax, %eax
100001966: c3                          	retq
100001967: c3                          	retq
100001968: 48 b8 49 00 00 02 00 00 00 00       	movabsq	$0x2000049, %rax ## imm = 0x2000049
100001972: 0f 05                       	syscall
100001974: c3                          	retq
		...
100002435: 00 00                       	addb	%al, (%rax)
100002437: 00 55 48                    	addb	%dl, 0x48(%rbp)
10000243a: 89 e5                       	movl	%esp, %ebp
10000243c: 5d                          	popq	%rbp
10000243d: e9 00 00 00 00              	jmp	0x100002442 <__text+0x1442>
100002442: 55                          	pushq	%rbp
100002443: 48 89 e5                    	movq	%rsp, %rbp
100002446: 41 57                       	pushq	%r15
100002448: 41 56                       	pushq	%r14
10000244a: 41 55                       	pushq	%r13
10000244c: 41 54                       	pushq	%r12
10000244e: 53                          	pushq	%rbx
10000244f: 48 81 ec 58 08 00 00        	subq	$0x858, %rsp            ## imm = 0x858
100002456: 48 89 f3                    	movq	%rsi, %rbx
100002459: 48 85 ff                    	testq	%rdi, %rdi
10000245c: 74 0d                       	je	0x10000246b <__text+0x146b>
10000245e: 48 89 df                    	movq	%rbx, %rdi
100002461: e8 16 02 00 00              	callq	0x10000267c <__text+0x167c>
100002466: 45 31 f6                    	xorl	%r14d, %r14d
100002469: eb 1f                       	jmp	0x10000248a <__text+0x148a>
10000246b: 4d 89 c7                    	movq	%r8, %r15
10000246e: 49 89 c8                    	movq	%rcx, %r8
100002471: 45 31 f6                    	xorl	%r14d, %r14d
100002474: 6a 02                       	pushq	$0x2
100002476: 59                          	popq	%rcx
100002477: 31 c0                       	xorl	%eax, %eax
100002479: f0                          	lock
10000247a: 48 0f b1 4b 18              	cmpxchgq	%rcx, 0x18(%rbx)
10000247f: 0f 95 45 d0                 	setne	-0x30(%rbp)
100002483: 0f 95 c0                    	setne	%al
100002486: 84 c0                       	testb	%al, %al
100002488: 74 15                       	je	0x10000249f <__text+0x149f>
10000248a: 4c 89 f0                    	movq	%r14, %rax
10000248d: 48 81 c4 58 08 00 00        	addq	$0x858, %rsp            ## imm = 0x858
100002494: 5b                          	popq	%rbx
100002495: 41 5c                       	popq	%r12
100002497: 41 5d                       	popq	%r13
100002499: 41 5e                       	popq	%r14
10000249b: 41 5f                       	popq	%r15
10000249d: 5d                          	popq	%rbp
10000249e: c3                          	retq
10000249f: 48 8b 43 08                 	movq	0x8(%rbx), %rax
1000024a3: 6a 04                       	pushq	$0x4
1000024a5: 41 5e                       	popq	%r14
1000024a7: 48 85 c0                    	testq	%rax, %rax
1000024aa: 0f 85 70 01 00 00           	jne	0x100002620 <__text+0x1620>
1000024b0: 4d 89 cd                    	movq	%r9, %r13
1000024b3: 49 89 d4                    	movq	%rdx, %r12
1000024b6: 48 89 55 90                 	movq	%rdx, -0x70(%rbp)
1000024ba: 48 83 65 a0 00              	andq	$0x0, -0x60(%rbp)
1000024bf: 48 83 65 a8 00              	andq	$0x0, -0x58(%rbp)
1000024c4: 48 83 65 b0 00              	andq	$0x0, -0x50(%rbp)
1000024c9: 4c 89 7d b8                 	movq	%r15, -0x48(%rbp)
1000024cd: 4c 89 4d c0                 	movq	%r9, -0x40(%rbp)
1000024d1: 4c 89 c0                    	movq	%r8, %rax
1000024d4: 48 c1 e0 05                 	shlq	$0x5, %rax
1000024d8: 48 8b 84 02 18 e0 ff ff     	movq	-0x1fe8(%rdx,%rax), %rax
1000024e0: 48 8d 04 c2                 	leaq	(%rdx,%rax,8), %rax
1000024e4: 48 8b 38                    	movq	(%rax), %rdi
1000024e7: 6a 01                       	pushq	$0x1
1000024e9: 5e                          	popq	%rsi
1000024ea: 48 83 ef 01                 	subq	$0x1, %rdi
1000024ee: 0f 82 29 01 00 00           	jb	0x10000261d <__text+0x161d>
1000024f4: 48 8b 0c f0                 	movq	(%rax,%rsi,8), %rcx
1000024f8: 48 8b 54 f0 10              	movq	0x10(%rax,%rsi,8), %rdx
1000024fd: 48 83 c6 03                 	addq	$0x3, %rsi
100002501: 48 3b 0b                    	cmpq	(%rbx), %rcx
100002504: 74 05                       	je	0x10000250b <__text+0x150b>
100002506: 48 01 d6                    	addq	%rdx, %rsi
100002509: eb df                       	jmp	0x1000024ea <__text+0x14ea>
10000250b: 4c 89 45 c8                 	movq	%r8, -0x38(%rbp)
10000250f: 4c 8d 85 88 f7 ff ff        	leaq	-0x878(%rbp), %r8
100002516: 49 83 a0 00 08 00 00 00     	andq	$0x0, 0x800(%r8)
10000251e: 48 8d 34 f0                 	leaq	(%rax,%rsi,8), %rsi
100002522: 48 8d 7d 90                 	leaq	-0x70(%rbp), %rdi
100002526: 6a 01                       	pushq	$0x1
100002528: 41 59                       	popq	%r9
10000252a: e8 7f 08 00 00              	callq	0x100002dae <__text+0x1dae>
10000252f: a8 03                       	testb	$0x3, %al
100002531: 0f 84 e9 00 00 00           	je	0x100002620 <__text+0x1620>
100002537: 0f b6 c0                    	movzbl	%al, %eax
10000253a: 83 e0 03                    	andl	$0x3, %eax
10000253d: 83 f8 01                    	cmpl	$0x1, %eax
100002540: 0f 85 d7 00 00 00           	jne	0x10000261d <__text+0x161d>
100002546: bf 00 40 00 00              	movl	$0x4000, %edi           ## imm = 0x4000
10000254b: 41 ff d7                    	callq	*%r15
10000254e: 48 85 c0                    	testq	%rax, %rax
100002551: 0f 84 c6 00 00 00           	je	0x10000261d <__text+0x161d>
100002557: 49 89 c6                    	movq	%rax, %r14
10000255a: bf 00 40 00 00              	movl	$0x4000, %edi           ## imm = 0x4000
10000255f: 41 ff d7                    	callq	*%r15
100002562: 48 85 c0                    	testq	%rax, %rax
100002565: 0f 84 a7 00 00 00           	je	0x100002612 <__text+0x1612>
10000256b: 4d 89 26                    	movq	%r12, (%r14)
10000256e: 49 89 46 08                 	movq	%rax, 0x8(%r14)
100002572: 49 83 66 10 00              	andq	$0x0, 0x10(%r14)
100002577: 49 c7 46 18 24 01 00 00     	movq	$0x124, 0x18(%r14)      ## imm = 0x124
10000257f: 49 c7 46 20 00 40 00 00     	movq	$0x4000, 0x20(%r14)     ## imm = 0x4000
100002587: 4d 89 7e 28                 	movq	%r15, 0x28(%r14)
10000258b: 4d 89 6e 30                 	movq	%r13, 0x30(%r14)
10000258f: 4c 89 f7                    	movq	%r14, %rdi
100002592: 48 89 de                    	movq	%rbx, %rsi
100002595: 4c 8b 7d c8                 	movq	-0x38(%rbp), %r15
100002599: 4c 89 fa                    	movq	%r15, %rdx
10000259c: 31 c9                       	xorl	%ecx, %ecx
10000259e: e8 e1 01 00 00              	callq	0x100002784 <__text+0x1784>
1000025a3: a8 03                       	testb	$0x3, %al
1000025a5: 75 59                       	jne	0x100002600 <__text+0x1600>
1000025a7: 4c 89 f7                    	movq	%r14, %rdi
1000025aa: 48 89 de                    	movq	%rbx, %rsi
1000025ad: 4c 89 fa                    	movq	%r15, %rdx
1000025b0: e8 2d 01 00 00              	callq	0x1000026e2 <__text+0x16e2>
1000025b5: a8 01                       	testb	$0x1, %al
1000025b7: 74 47                       	je	0x100002600 <__text+0x1600>
1000025b9: 49 8b 46 08                 	movq	0x8(%r14), %rax
1000025bd: 49 8b 4e 10                 	movq	0x10(%r14), %rcx
1000025c1: 48 ff c1                    	incq	%rcx
1000025c4: 6a 01                       	pushq	$0x1
1000025c6: 41 59                       	popq	%r9
1000025c8: 48 ff c9                    	decq	%rcx
1000025cb: 74 5c                       	je	0x100002629 <__text+0x1629>
1000025cd: 48 8b 30                    	movq	(%rax), %rsi
1000025d0: 48 8b 50 18                 	movq	0x18(%rax), %rdx
1000025d4: 48 8b 7e 08                 	movq	0x8(%rsi), %rdi
1000025d8: 48 8b 76 10                 	movq	0x10(%rsi), %rsi
1000025dc: 48 85 ff                    	testq	%rdi, %rdi
1000025df: 75 09                       	jne	0x1000025ea <__text+0x15ea>
1000025e1: 48 83 c0 38                 	addq	$0x38, %rax
1000025e5: 48 39 d6                    	cmpq	%rdx, %rsi
1000025e8: 74 de                       	je	0x1000025c8 <__text+0x15c8>
1000025ea: 4c 89 f7                    	movq	%r14, %rdi
1000025ed: e8 b2 00 00 00              	callq	0x1000026a4 <__text+0x16a4>
1000025f2: 4c 89 f7                    	movq	%r14, %rdi
1000025f5: e8 82 00 00 00              	callq	0x10000267c <__text+0x167c>
1000025fa: 6a 04                       	pushq	$0x4
1000025fc: 41 5e                       	popq	%r14
1000025fe: eb 20                       	jmp	0x100002620 <__text+0x1620>
100002600: 4c 89 f7                    	movq	%r14, %rdi
100002603: e8 9c 00 00 00              	callq	0x1000026a4 <__text+0x16a4>
100002608: 4c 89 f7                    	movq	%r14, %rdi
10000260b: e8 6c 00 00 00              	callq	0x10000267c <__text+0x167c>
100002610: eb 0b                       	jmp	0x10000261d <__text+0x161d>
100002612: be 00 40 00 00              	movl	$0x4000, %esi           ## imm = 0x4000
100002617: 4c 89 f7                    	movq	%r14, %rdi
10000261a: 41 ff d5                    	callq	*%r13
10000261d: 45 31 f6                    	xorl	%r14d, %r14d
100002620: 4c 89 73 18                 	movq	%r14, 0x18(%rbx)
100002624: e9 3d fe ff ff              	jmp	0x100002466 <__text+0x1466>
100002629: 49 8b 46 08                 	movq	0x8(%r14), %rax
10000262d: 49 8b 4e 10                 	movq	0x10(%r14), %rcx
100002631: 48 83 c0 28                 	addq	$0x28, %rax
100002635: 6a 04                       	pushq	$0x4
100002637: 5a                          	popq	%rdx
100002638: 48 83 e9 01                 	subq	$0x1, %rcx
10000263c: 0f 82 48 fe ff ff           	jb	0x10000248a <__text+0x148a>
100002642: 48 8b 70 d8                 	movq	-0x28(%rax), %rsi
100002646: 4c 8b 40 f8                 	movq	-0x8(%rax), %r8
10000264a: 48 8b 38                    	movq	(%rax), %rdi
10000264d: 4d 85 c0                    	testq	%r8, %r8
100002650: 74 05                       	je	0x100002657 <__text+0x1657>
100002652: f0                          	lock
100002653: 4c 29 46 10                 	subq	%r8, 0x10(%rsi)
100002657: 45 31 c0                    	xorl	%r8d, %r8d
10000265a: 48 83 ff 01                 	cmpq	$0x1, %rdi
10000265e: 41 0f 94 c0                 	sete	%r8b
100002662: 89 d7                       	movl	%edx, %edi
100002664: 44 29 c7                    	subl	%r8d, %edi
100002667: 48 39 de                    	cmpq	%rbx, %rsi
10000266a: 4f 8d 04 40                 	leaq	(%r8,%r8,2), %r8
10000266e: 4d 0f 44 c1                 	cmoveq	%r9, %r8
100002672: 4c 89 04 fe                 	movq	%r8, (%rsi,%rdi,8)
100002676: 48 83 c0 38                 	addq	$0x38, %rax
10000267a: eb bc                       	jmp	0x100002638 <__text+0x1638>
10000267c: 55                          	pushq	%rbp
10000267d: 48 89 e5                    	movq	%rsp, %rbp
100002680: 53                          	pushq	%rbx
100002681: 50                          	pushq	%rax
100002682: 48 89 fb                    	movq	%rdi, %rbx
100002685: 48 8b 7f 08                 	movq	0x8(%rdi), %rdi
100002689: 48 8b 73 20                 	movq	0x20(%rbx), %rsi
10000268d: ff 53 30                    	callq	*0x30(%rbx)
100002690: 48 8b 43 30                 	movq	0x30(%rbx), %rax
100002694: be 00 40 00 00              	movl	$0x4000, %esi           ## imm = 0x4000
100002699: 48 89 df                    	movq	%rbx, %rdi
10000269c: 48 83 c4 08                 	addq	$0x8, %rsp
1000026a0: 5b                          	popq	%rbx
1000026a1: 5d                          	popq	%rbp
1000026a2: ff e0                       	jmpq	*%rax
1000026a4: 55                          	pushq	%rbp
1000026a5: 48 89 e5                    	movq	%rsp, %rbp
1000026a8: 48 8b 47 08                 	movq	0x8(%rdi), %rax
1000026ac: 48 8b 4f 10                 	movq	0x10(%rdi), %rcx
1000026b0: 48 83 e9 01                 	subq	$0x1, %rcx
1000026b4: 72 2a                       	jb	0x1000026e0 <__text+0x16e0>
1000026b6: 31 d2                       	xorl	%edx, %edx
1000026b8: 48 83 78 28 01              	cmpq	$0x1, 0x28(%rax)
1000026bd: 48 8b 30                    	movq	(%rax), %rsi
1000026c0: 0f 95 c2                    	setne	%dl
1000026c3: 48 8b 7c d6 18              	movq	0x18(%rsi,%rdx,8), %rdi
1000026c8: 48 83 ff 02                 	cmpq	$0x2, %rdi
1000026cc: 75 0c                       	jne	0x1000026da <__text+0x16da>
1000026ce: 48 83 c2 03                 	addq	$0x3, %rdx
1000026d2: 48 c7 04 d6 00 00 00 00     	movq	$0x0, (%rsi,%rdx,8)
1000026da: 48 83 c0 38                 	addq	$0x38, %rax
1000026de: eb d0                       	jmp	0x1000026b0 <__text+0x16b0>
1000026e0: 5d                          	popq	%rbp
1000026e1: c3                          	retq
1000026e2: 55                          	pushq	%rbp
1000026e3: 48 89 e5                    	movq	%rsp, %rbp
1000026e6: 41 57                       	pushq	%r15
1000026e8: 41 56                       	pushq	%r14
1000026ea: 53                          	pushq	%rbx
1000026eb: 50                          	pushq	%rax
1000026ec: 49 89 d7                    	movq	%rdx, %r15
1000026ef: 48 89 f3                    	movq	%rsi, %rbx
1000026f2: 49 89 fe                    	movq	%rdi, %r14
1000026f5: e8 89 06 00 00              	callq	0x100002d83 <__text+0x1d83>
1000026fa: 48 85 c0                    	testq	%rax, %rax
1000026fd: 74 3a                       	je	0x100002739 <__text+0x1739>
1000026ff: c6 40 30 01                 	movb	$0x1, 0x30(%rax)
100002703: 49 8b 06                    	movq	(%r14), %rax
100002706: 49 c1 e7 05                 	shlq	$0x5, %r15
10000270a: 4a 8b 8c 38 18 e0 ff ff     	movq	-0x1fe8(%rax,%r15), %rcx
100002712: 48 8d 04 c8                 	leaq	(%rax,%rcx,8), %rax
100002716: 48 8b 30                    	movq	(%rax), %rsi
100002719: 6a 01                       	pushq	$0x1
10000271b: 5a                          	popq	%rdx
10000271c: 48 83 ee 01                 	subq	$0x1, %rsi
100002720: 72 1c                       	jb	0x10000273e <__text+0x173e>
100002722: 48 8b 3c d0                 	movq	(%rax,%rdx,8), %rdi
100002726: 48 8b 4c d0 10              	movq	0x10(%rax,%rdx,8), %rcx
10000272b: 48 83 c2 03                 	addq	$0x3, %rdx
10000272f: 48 3b 3b                    	cmpq	(%rbx), %rdi
100002732: 74 1a                       	je	0x10000274e <__text+0x174e>
100002734: 48 01 ca                    	addq	%rcx, %rdx
100002737: eb e3                       	jmp	0x10000271c <__text+0x171c>
100002739: 45 31 ff                    	xorl	%r15d, %r15d
10000273c: eb 37                       	jmp	0x100002775 <__text+0x1775>
10000273e: 4c 89 f7                    	movq	%r14, %rdi
100002741: 48 89 de                    	movq	%rbx, %rsi
100002744: e8 3a 06 00 00              	callq	0x100002d83 <__text+0x1d83>
100002749: 45 31 ff                    	xorl	%r15d, %r15d
10000274c: eb 1e                       	jmp	0x10000276c <__text+0x176c>
10000274e: 48 8d 73 20                 	leaq	0x20(%rbx), %rsi
100002752: 48 8d 14 d0                 	leaq	(%rax,%rdx,8), %rdx
100002756: 4c 89 f7                    	movq	%r14, %rdi
100002759: e8 5f 02 00 00              	callq	0x1000029bd <__text+0x19bd>
10000275e: 41 89 c7                    	movl	%eax, %r15d
100002761: 4c 89 f7                    	movq	%r14, %rdi
100002764: 48 89 de                    	movq	%rbx, %rsi
100002767: e8 17 06 00 00              	callq	0x100002d83 <__text+0x1d83>
10000276c: 48 85 c0                    	testq	%rax, %rax
10000276f: 74 04                       	je	0x100002775 <__text+0x1775>
100002771: c6 40 30 00                 	movb	$0x0, 0x30(%rax)
100002775: 44 89 f8                    	movl	%r15d, %eax
100002778: 48 83 c4 08                 	addq	$0x8, %rsp
10000277c: 5b                          	popq	%rbx
10000277d: 41 5e                       	popq	%r14
10000277f: 41 5f                       	popq	%r15
100002781: 5d                          	popq	%rbp
100002782: c3                          	retq
100002783: cc                          	int3
100002784: 55                          	pushq	%rbp
100002785: 48 89 e5                    	movq	%rsp, %rbp
100002788: 41 57                       	pushq	%r15
10000278a: 41 56                       	pushq	%r14
10000278c: 41 55                       	pushq	%r13
10000278e: 41 54                       	pushq	%r12
100002790: 53                          	pushq	%rbx
100002791: 48 83 ec 38                 	subq	$0x38, %rsp
100002795: 49 89 f6                    	movq	%rsi, %r14
100002798: 48 89 fb                    	movq	%rdi, %rbx
10000279b: 48 8b 7f 08                 	movq	0x8(%rdi), %rdi
10000279f: 48 8b 43 10                 	movq	0x10(%rbx), %rax
1000027a3: 48 83 c7 e0                 	addq	$-0x20, %rdi
1000027a7: 6a ff                       	pushq	$-0x1
1000027a9: 41 58                       	popq	%r8
1000027ab: 49 ff c0                    	incq	%r8
1000027ae: 4c 39 c0                    	cmpq	%r8, %rax
1000027b1: 74 2f                       	je	0x1000027e2 <__text+0x17e2>
1000027b3: 48 8d 77 38                 	leaq	0x38(%rdi), %rsi
1000027b7: 4c 39 77 20                 	cmpq	%r14, 0x20(%rdi)
1000027bb: 48 89 f7                    	movq	%rsi, %rdi
1000027be: 75 eb                       	jne	0x1000027ab <__text+0x17ab>
1000027c0: 41 b0 01                    	movb	$0x1, %r8b
1000027c3: f6 c1 01                    	testb	$0x1, %cl
1000027c6: 0f 84 df 01 00 00           	je	0x1000029ab <__text+0x19ab>
1000027cc: 48 ff 06                    	incq	(%rsi)
1000027cf: 80 7e 18 01                 	cmpb	$0x1, 0x18(%rsi)
1000027d3: 0f 85 d2 01 00 00           	jne	0x1000029ab <__text+0x19ab>
1000027d9: 48 ff 46 08                 	incq	0x8(%rsi)
1000027dd: e9 c9 01 00 00              	jmp	0x1000029ab <__text+0x19ab>
1000027e2: 48 8b 3b                    	movq	(%rbx), %rdi
1000027e5: 49 89 d4                    	movq	%rdx, %r12
1000027e8: 49 c1 e4 05                 	shlq	$0x5, %r12
1000027ec: 4e 8b 94 27 08 e0 ff ff     	movq	-0x1ff8(%rdi,%r12), %r10
1000027f4: 41 b0 02                    	movb	$0x2, %r8b
1000027f7: 4c 89 d6                    	movq	%r10, %rsi
1000027fa: 48 83 ce 02                 	orq	$0x2, %rsi
1000027fe: 48 83 fe 03                 	cmpq	$0x3, %rsi
100002802: 0f 85 a3 01 00 00           	jne	0x1000029ab <__text+0x19ab>
100002808: 45 31 ed                    	xorl	%r13d, %r13d
10000280b: 4c 89 d6                    	movq	%r10, %rsi
10000280e: 48 83 f6 01                 	xorq	$0x1, %rsi
100002812: 41 0f 95 c5                 	setne	%r13b
100002816: 49 83 c5 03                 	addq	$0x3, %r13
10000281a: 48 09 f0                    	orq	%rsi, %rax
10000281d: 41 0f 95 c3                 	setne	%r11b
100002821: 74 1e                       	je	0x100002841 <__text+0x1841>
100002823: 31 c0                       	xorl	%eax, %eax
100002825: 6a 02                       	pushq	$0x2
100002827: 5e                          	popq	%rsi
100002828: f0                          	lock
100002829: 4b 0f b1 34 ee              	cmpxchgq	%rsi, (%r14,%r13,8)
10000282e: 0f 95 45 d0                 	setne	-0x30(%rbp)
100002832: 74 11                       	je	0x100002845 <__text+0x1845>
100002834: 48 a9 fb ff ff ff           	testq	$-0x5, %rax
10000283a: 74 ec                       	je	0x100002828 <__text+0x1828>
10000283c: e9 6a 01 00 00              	jmp	0x1000029ab <__text+0x19ab>
100002841: 31 c0                       	xorl	%eax, %eax
100002843: eb 04                       	jmp	0x100002849 <__text+0x1849>
100002845: 48 8b 43 10                 	movq	0x10(%rbx), %rax
100002849: 48 3b 43 18                 	cmpq	0x18(%rbx), %rax
10000284d: 0f 85 bc 00 00 00           	jne	0x10000290f <__text+0x190f>
100002853: 48 89 7d b0                 	movq	%rdi, -0x50(%rbp)
100002857: 44 88 5d d7                 	movb	%r11b, -0x29(%rbp)
10000285b: 4c 89 55 a8                 	movq	%r10, -0x58(%rbp)
10000285f: 48 89 55 a0                 	movq	%rdx, -0x60(%rbp)
100002863: 89 4d cc                    	movl	%ecx, -0x34(%rbp)
100002866: 48 8b 43 20                 	movq	0x20(%rbx), %rax
10000286a: 48 8d 3c 00                 	leaq	(%rax,%rax), %rdi
10000286e: 6a 1c                       	pushq	$0x1c
100002870: 59                          	popq	%rcx
100002871: 31 d2                       	xorl	%edx, %edx
100002873: 48 f7 f1                    	divq	%rcx
100002876: 48 89 45 c0                 	movq	%rax, -0x40(%rbp)
10000287a: 48 89 7d b8                 	movq	%rdi, -0x48(%rbp)
10000287e: ff 53 28                    	callq	*0x28(%rbx)
100002881: 48 85 c0                    	testq	%rax, %rax
100002884: 0f 84 10 01 00 00           	je	0x10000299a <__text+0x199a>
10000288a: 49 89 c7                    	movq	%rax, %r15
10000288d: 48 8b 43 08                 	movq	0x8(%rbx), %rax
100002891: 48 8b 4b 10                 	movq	0x10(%rbx), %rcx
100002895: 6a 30                       	pushq	$0x30
100002897: 5a                          	popq	%rdx
100002898: 48 83 e9 01                 	subq	$0x1, %rcx
10000289c: 72 3c                       	jb	0x1000028da <__text+0x18da>
10000289e: 48 8b 74 10 d0              	movq	-0x30(%rax,%rdx), %rsi
1000028a3: 48 8b 7c 10 f8              	movq	-0x8(%rax,%rdx), %rdi
1000028a8: 44 8a 04 10                 	movb	(%rax,%rdx), %r8b
1000028ac: 0f 10 44 10 d8              	movups	-0x28(%rax,%rdx), %xmm0
1000028b1: 0f 10 4c 10 e8              	movups	-0x18(%rax,%rdx), %xmm1
1000028b6: 49 89 74 17 d0              	movq	%rsi, -0x30(%r15,%rdx)
1000028bb: 41 0f 11 44 17 d8           	movups	%xmm0, -0x28(%r15,%rdx)
1000028c1: 41 0f 11 4c 17 e8           	movups	%xmm1, -0x18(%r15,%rdx)
1000028c7: 41 80 e0 01                 	andb	$0x1, %r8b
1000028cb: 45 88 04 17                 	movb	%r8b, (%r15,%rdx)
1000028cf: 49 89 7c 17 f8              	movq	%rdi, -0x8(%r15,%rdx)
1000028d4: 48 83 c2 38                 	addq	$0x38, %rdx
1000028d8: eb be                       	jmp	0x100002898 <__text+0x1898>
1000028da: 48 8b 7b 08                 	movq	0x8(%rbx), %rdi
1000028de: 48 8b 73 20                 	movq	0x20(%rbx), %rsi
1000028e2: ff 53 30                    	callq	*0x30(%rbx)
1000028e5: 4c 89 7b 08                 	movq	%r15, 0x8(%rbx)
1000028e9: 48 8b 45 c0                 	movq	-0x40(%rbp), %rax
1000028ed: 48 89 43 18                 	movq	%rax, 0x18(%rbx)
1000028f1: 48 8b 45 b8                 	movq	-0x48(%rbp), %rax
1000028f5: 48 89 43 20                 	movq	%rax, 0x20(%rbx)
1000028f9: 8b 4d cc                    	movl	-0x34(%rbp), %ecx
1000028fc: 41 b0 02                    	movb	$0x2, %r8b
1000028ff: 48 8b 55 a0                 	movq	-0x60(%rbp), %rdx
100002903: 4c 8b 55 a8                 	movq	-0x58(%rbp), %r10
100002907: 44 8a 5d d7                 	movb	-0x29(%rbp), %r11b
10000290b: 48 8b 7d b0                 	movq	-0x50(%rbp), %rdi
10000290f: 49 83 fa 01                 	cmpq	$0x1, %r10
100002913: 74 06                       	je	0x10000291b <__text+0x191b>
100002915: 49 8b 46 18                 	movq	0x18(%r14), %rax
100002919: eb 44                       	jmp	0x10000295f <__text+0x195f>
10000291b: 48 8b 03                    	movq	(%rbx), %rax
10000291e: 4a 8b b4 27 18 e0 ff ff     	movq	-0x1fe8(%rdi,%r12), %rsi
100002926: 48 8d 04 f0                 	leaq	(%rax,%rsi,8), %rax
10000292a: 4c 8b 08                    	movq	(%rax), %r9
10000292d: 6a 01                       	pushq	$0x1
10000292f: 5f                          	popq	%rdi
100002930: 49 83 e9 01                 	subq	$0x1, %r9
100002934: 72 15                       	jb	0x10000294b <__text+0x194b>
100002936: 48 8b 34 f8                 	movq	(%rax,%rdi,8), %rsi
10000293a: 49 3b 36                    	cmpq	(%r14), %rsi
10000293d: 74 13                       	je	0x100002952 <__text+0x1952>
10000293f: 48 8b 74 f8 10              	movq	0x10(%rax,%rdi,8), %rsi
100002944: 48 8d 7c 37 03              	leaq	0x3(%rdi,%rsi), %rdi
100002949: eb e5                       	jmp	0x100002930 <__text+0x1930>
10000294b: 45 84 db                    	testb	%r11b, %r11b
10000294e: 75 53                       	jne	0x1000029a3 <__text+0x19a3>
100002950: eb 59                       	jmp	0x1000029ab <__text+0x19ab>
100002952: 48 8b 44 f8 08              	movq	0x8(%rax,%rdi,8), %rax
100002957: 48 8d 04 c5 20 00 00 00     	leaq	0x20(,%rax,8), %rax
10000295f: 48 8b 73 08                 	movq	0x8(%rbx), %rsi
100002963: 48 6b 7b 10 38              	imulq	$0x38, 0x10(%rbx), %rdi
100002968: 4c 89 34 3e                 	movq	%r14, (%rsi,%rdi)
10000296c: 48 89 54 3e 08              	movq	%rdx, 0x8(%rsi,%rdi)
100002971: 48 89 44 3e 10              	movq	%rax, 0x10(%rsi,%rdi)
100002976: 0f b6 c1                    	movzbl	%cl, %eax
100002979: 83 e0 01                    	andl	$0x1, %eax
10000297c: 48 89 44 3e 18              	movq	%rax, 0x18(%rsi,%rdi)
100002981: 48 83 64 3e 20 00           	andq	$0x0, 0x20(%rsi,%rdi)
100002987: c6 44 3e 30 00              	movb	$0x0, 0x30(%rsi,%rdi)
10000298c: 4c 89 54 3e 28              	movq	%r10, 0x28(%rsi,%rdi)
100002991: 48 ff 43 10                 	incq	0x10(%rbx)
100002995: 45 31 c0                    	xorl	%r8d, %r8d
100002998: eb 11                       	jmp	0x1000029ab <__text+0x19ab>
10000299a: 80 7d d7 00                 	cmpb	$0x0, -0x29(%rbp)
10000299e: 41 b0 02                    	movb	$0x2, %r8b
1000029a1: 74 08                       	je	0x1000029ab <__text+0x19ab>
1000029a3: 4b c7 04 ee 00 00 00 00     	movq	$0x0, (%r14,%r13,8)
1000029ab: 44 89 c0                    	movl	%r8d, %eax
1000029ae: 48 83 c4 38                 	addq	$0x38, %rsp
1000029b2: 5b                          	popq	%rbx
1000029b3: 41 5c                       	popq	%r12
1000029b5: 41 5d                       	popq	%r13
1000029b7: 41 5e                       	popq	%r14
1000029b9: 41 5f                       	popq	%r15
1000029bb: 5d                          	popq	%rbp
1000029bc: c3                          	retq
1000029bd: 55                          	pushq	%rbp
1000029be: 48 89 e5                    	movq	%rsp, %rbp
1000029c1: 41 57                       	pushq	%r15
1000029c3: 41 56                       	pushq	%r14
1000029c5: 41 55                       	pushq	%r13
1000029c7: 41 54                       	pushq	%r12
1000029c9: 53                          	pushq	%rbx
1000029ca: 50                          	pushq	%rax
1000029cb: 48 89 cb                    	movq	%rcx, %rbx
1000029ce: 49 89 d6                    	movq	%rdx, %r14
1000029d1: 48 89 75 d0                 	movq	%rsi, -0x30(%rbp)
1000029d5: 49 89 fc                    	movq	%rdi, %r12
1000029d8: 45 31 ed                    	xorl	%r13d, %r13d
1000029db: 45 31 ff                    	xorl	%r15d, %r15d
1000029de: 4c 39 fb                    	cmpq	%r15, %rbx
1000029e1: 74 2c                       	je	0x100002a0f <__text+0x1a0f>
1000029e3: 48 8b 45 d0                 	movq	-0x30(%rbp), %rax
1000029e7: 4a 8d 34 e8                 	leaq	(%rax,%r13,8), %rsi
1000029eb: 4b 8b 14 fe                 	movq	(%r14,%r15,8), %rdx
1000029ef: 4c 89 e7                    	movq	%r12, %rdi
1000029f2: e8 a8 00 00 00              	callq	0x100002a9f <__text+0x1a9f>
1000029f7: a8 01                       	testb	$0x1, %al
1000029f9: 74 14                       	je	0x100002a0f <__text+0x1a0f>
1000029fb: 4b 8b 34 fe                 	movq	(%r14,%r15,8), %rsi
1000029ff: 4c 89 e7                    	movq	%r12, %rdi
100002a02: e8 1d 00 00 00              	callq	0x100002a24 <__text+0x1a24>
100002a07: 49 01 c5                    	addq	%rax, %r13
100002a0a: 49 ff c7                    	incq	%r15
100002a0d: eb cf                       	jmp	0x1000029de <__text+0x19de>
100002a0f: 49 39 df                    	cmpq	%rbx, %r15
100002a12: 0f 93 c0                    	setae	%al
100002a15: 48 83 c4 08                 	addq	$0x8, %rsp
100002a19: 5b                          	popq	%rbx
100002a1a: 41 5c                       	popq	%r12
100002a1c: 41 5d                       	popq	%r13
100002a1e: 41 5e                       	popq	%r14
100002a20: 41 5f                       	popq	%r15
100002a22: 5d                          	popq	%rbp
100002a23: c3                          	retq
100002a24: 55                          	pushq	%rbp
100002a25: 48 89 e5                    	movq	%rsp, %rbp
100002a28: 41 57                       	pushq	%r15
100002a2a: 41 56                       	pushq	%r14
100002a2c: 41 54                       	pushq	%r12
100002a2e: 53                          	pushq	%rbx
100002a2f: 48 83 ec 10                 	subq	$0x10, %rsp
100002a33: 48 89 f3                    	movq	%rsi, %rbx
100002a36: 49 89 fe                    	movq	%rdi, %r14
100002a39: 45 31 e4                    	xorl	%r12d, %r12d
100002a3c: 4c 8d 7d d0                 	leaq	-0x30(%rbp), %r15
100002a40: 4c 89 ff                    	movq	%r15, %rdi
100002a43: 48 89 de                    	movq	%rbx, %rsi
100002a46: e8 f5 02 00 00              	callq	0x100002d40 <__text+0x1d40>
100002a4b: 80 7d d8 00                 	cmpb	$0x0, -0x28(%rbp)
100002a4f: 74 09                       	je	0x100002a5a <__text+0x1a5a>
100002a51: 48 8b 5d d0                 	movq	-0x30(%rbp), %rbx
100002a55: 49 ff c4                    	incq	%r12
100002a58: eb e6                       	jmp	0x100002a40 <__text+0x1a40>
100002a5a: 48 83 fb 0d                 	cmpq	$0xd, %rbx
100002a5e: 77 0a                       	ja	0x100002a6a <__text+0x1a6a>
100002a60: 31 c0                       	xorl	%eax, %eax
100002a62: 48 85 db                    	testq	%rbx, %rbx
100002a65: 0f 95 c0                    	setne	%al
100002a68: eb 25                       	jmp	0x100002a8f <__text+0x1a8f>
100002a6a: 48 89 d8                    	movq	%rbx, %rax
100002a6d: 48 25 00 00 c0 ff           	andq	$-0x400000, %rax        ## imm = 0xFFC00000
100002a73: 48 3d 00 00 40 00           	cmpq	$0x400000, %rax         ## imm = 0x400000
100002a79: 75 05                       	jne	0x100002a80 <__text+0x1a80>
100002a7b: 6a 02                       	pushq	$0x2
100002a7d: 58                          	popq	%rax
100002a7e: eb 0f                       	jmp	0x100002a8f <__text+0x1a8f>
100002a80: 49 8b 06                    	movq	(%r14), %rax
100002a83: 48 c1 e3 05                 	shlq	$0x5, %rbx
100002a87: 48 8b 84 18 10 e0 ff ff     	movq	-0x1ff0(%rax,%rbx), %rax
100002a8f: 4c 01 e0                    	addq	%r12, %rax
100002a92: 48 83 c4 10                 	addq	$0x10, %rsp
100002a96: 5b                          	popq	%rbx
100002a97: 41 5c                       	popq	%r12
100002a99: 41 5e                       	popq	%r14
100002a9b: 41 5f                       	popq	%r15
100002a9d: 5d                          	popq	%rbp
100002a9e: c3                          	retq
100002a9f: 55                          	pushq	%rbp
100002aa0: 48 89 e5                    	movq	%rsp, %rbp
100002aa3: 41 57                       	pushq	%r15
100002aa5: 41 56                       	pushq	%r14
100002aa7: 41 55                       	pushq	%r13
100002aa9: 41 54                       	pushq	%r12
100002aab: 53                          	pushq	%rbx
100002aac: 48 83 ec 28                 	subq	$0x28, %rsp
100002ab0: 49 89 d4                    	movq	%rdx, %r12
100002ab3: 49 89 f7                    	movq	%rsi, %r15
100002ab6: 48 89 7d d0                 	movq	%rdi, -0x30(%rbp)
100002aba: 4c 8d 6d b8                 	leaq	-0x48(%rbp), %r13
100002abe: 48 8d 1d 65 02 00 00        	leaq	0x265(%rip), %rbx       ## 0x100002d2a <__text+0x1d2a>
100002ac5: 4c 89 ef                    	movq	%r13, %rdi
100002ac8: 4c 89 e6                    	movq	%r12, %rsi
100002acb: e8 70 02 00 00              	callq	0x100002d40 <__text+0x1d40>
100002ad0: 80 7d c0 00                 	cmpb	$0x0, -0x40(%rbp)
100002ad4: 74 16                       	je	0x100002aec <__text+0x1aec>
100002ad6: 49 83 3f 00                 	cmpq	$0x0, (%r15)
100002ada: 4c 89 e8                    	movq	%r13, %rax
100002add: 0f 84 9b 00 00 00           	je	0x100002b7e <__text+0x1b7e>
100002ae3: 4c 8b 20                    	movq	(%rax), %r12
100002ae6: 49 83 c7 08                 	addq	$0x8, %r15
100002aea: eb d9                       	jmp	0x100002ac5 <__text+0x1ac5>
100002aec: 41 b6 01                    	movb	$0x1, %r14b
100002aef: 49 83 fc 0e                 	cmpq	$0xe, %r12
100002af3: 0f 82 a6 01 00 00           	jb	0x100002c9f <__text+0x1c9f>
100002af9: 4c 89 e0                    	movq	%r12, %rax
100002afc: 48 25 00 00 c0 ff           	andq	$-0x400000, %rax        ## imm = 0xFFC00000
100002b02: 48 3d 00 00 40 00           	cmpq	$0x400000, %rax         ## imm = 0x400000
100002b08: 0f 84 91 01 00 00           	je	0x100002c9f <__text+0x1c9f>
100002b0e: 49 8d 84 24 00 00 c0 ff     	leaq	-0x400000(%r12), %rax
100002b16: 48 3d 00 01 c0 ff           	cmpq	$-0x3fff00, %rax        ## imm = 0xFFC00100
100002b1c: 0f 82 7a 01 00 00           	jb	0x100002c9c <__text+0x1c9c>
100002b22: 48 8b 7d d0                 	movq	-0x30(%rbp), %rdi
100002b26: 48 8b 07                    	movq	(%rdi), %rax
100002b29: 4c 89 e1                    	movq	%r12, %rcx
100002b2c: 48 c1 e1 05                 	shlq	$0x5, %rcx
100002b30: 4c 8b 84 08 08 e0 ff ff     	movq	-0x1ff8(%rax,%rcx), %r8
100002b38: 48 8b b4 08 18 e0 ff ff     	movq	-0x1fe8(%rax,%rcx), %rsi
100002b40: 48 8d 14 f0                 	leaq	(%rax,%rsi,8), %rdx
100002b44: 49 83 f8 04                 	cmpq	$0x4, %r8
100002b48: 0f 87 63 01 00 00           	ja	0x100002cb1 <__text+0x1cb1>
100002b4e: 4e 63 04 83                 	movslq	(%rbx,%r8,4), %r8
100002b52: 49 01 d8                    	addq	%rbx, %r8
100002b55: 41 ff e0                    	jmpq	*%r8
100002b58: 48 8d 44 f0 10              	leaq	0x10(%rax,%rsi,8), %rax
100002b5d: 48 8b 48 f0                 	movq	-0x10(%rax), %rcx
100002b61: 48 83 e9 01                 	subq	$0x1, %rcx
100002b65: 0f 82 31 01 00 00           	jb	0x100002c9c <__text+0x1c9c>
100002b6b: 48 8b 50 f8                 	movq	-0x8(%rax), %rdx
100002b6f: 49 3b 17                    	cmpq	(%r15), %rdx
100002b72: 0f 84 6b ff ff ff           	je	0x100002ae3 <__text+0x1ae3>
100002b78: 48 83 c0 10                 	addq	$0x10, %rax
100002b7c: eb e3                       	jmp	0x100002b61 <__text+0x1b61>
100002b7e: 41 b6 01                    	movb	$0x1, %r14b
100002b81: e9 19 01 00 00              	jmp	0x100002c9f <__text+0x1c9f>
100002b86: 48 8b 8c 08 20 e0 ff ff     	movq	-0x1fe0(%rax,%rcx), %rcx
100002b8e: e9 48 01 00 00              	jmp	0x100002cdb <__text+0x1cdb>
100002b93: 4d 8b 3f                    	movq	(%r15), %r15
100002b96: 4d 85 ff                    	testq	%r15, %r15
100002b99: 0f 84 fd 00 00 00           	je	0x100002c9c <__text+0x1c9c>
100002b9f: 4c 8b 2a                    	movq	(%rdx), %r13
100002ba2: 6a 01                       	pushq	$0x1
100002ba4: 59                          	popq	%rcx
100002ba5: 4c 89 fe                    	movq	%r15, %rsi
100002ba8: 4c 89 e2                    	movq	%r12, %rdx
100002bab: 48 89 fb                    	movq	%rdi, %rbx
100002bae: e8 d1 fb ff ff              	callq	0x100002784 <__text+0x1784>
100002bb3: a8 03                       	testb	$0x3, %al
100002bb5: 0f 85 d6 00 00 00           	jne	0x100002c91 <__text+0x1c91>
100002bbb: 48 89 df                    	movq	%rbx, %rdi
100002bbe: 4c 89 fe                    	movq	%r15, %rsi
100002bc1: e8 bd 01 00 00              	callq	0x100002d83 <__text+0x1d83>
100002bc6: 48 85 c0                    	testq	%rax, %rax
100002bc9: 0f 84 cd 00 00 00           	je	0x100002c9c <__text+0x1c9c>
100002bcf: c6 40 30 01                 	movb	$0x1, 0x30(%rax)
100002bd3: 48 89 df                    	movq	%rbx, %rdi
100002bd6: 4c 89 fb                    	movq	%r15, %rbx
100002bd9: 4d 89 ef                    	movq	%r13, %r15
100002bdc: 4c 89 ee                    	movq	%r13, %rsi
100002bdf: e8 40 fe ff ff              	callq	0x100002a24 <__text+0x1a24>
100002be4: 49 89 c4                    	movq	%rax, %r12
100002be7: 48 89 d8                    	movq	%rbx, %rax
100002bea: 48 8b 1b                    	movq	(%rbx), %rbx
100002bed: 48 89 45 c8                 	movq	%rax, -0x38(%rbp)
100002bf1: 48 8d 70 28                 	leaq	0x28(%rax), %rsi
100002bf5: 48 ff c3                    	incq	%rbx
100002bf8: 49 c1 e4 03                 	shlq	$0x3, %r12
100002bfc: 48 ff cb                    	decq	%rbx
100002bff: 0f 84 08 01 00 00           	je	0x100002d0d <__text+0x1d0d>
100002c05: 4e 8d 2c 26                 	leaq	(%rsi,%r12), %r13
100002c09: 48 8b 7d d0                 	movq	-0x30(%rbp), %rdi
100002c0d: 4c 89 fa                    	movq	%r15, %rdx
100002c10: e8 8a fe ff ff              	callq	0x100002a9f <__text+0x1a9f>
100002c15: 4c 89 ee                    	movq	%r13, %rsi
100002c18: a8 01                       	testb	$0x1, %al
100002c1a: 75 e0                       	jne	0x100002bfc <__text+0x1bfc>
100002c1c: 48 8b 7d d0                 	movq	-0x30(%rbp), %rdi
100002c20: 48 8b 75 c8                 	movq	-0x38(%rbp), %rsi
100002c24: e8 5a 01 00 00              	callq	0x100002d83 <__text+0x1d83>
100002c29: 48 85 c0                    	testq	%rax, %rax
100002c2c: 74 6e                       	je	0x100002c9c <__text+0x1c9c>
100002c2e: c6 40 30 00                 	movb	$0x0, 0x30(%rax)
100002c32: eb 68                       	jmp	0x100002c9c <__text+0x1c9c>
100002c34: 48 8b 32                    	movq	(%rdx), %rsi
100002c37: 48 8b 5a 08                 	movq	0x8(%rdx), %rbx
100002c3b: 48 89 75 c8                 	movq	%rsi, -0x38(%rbp)
100002c3f: e8 e0 fd ff ff              	callq	0x100002a24 <__text+0x1a24>
100002c44: 49 89 c5                    	movq	%rax, %r13
100002c47: 48 ff c3                    	incq	%rbx
100002c4a: 49 c1 e5 03                 	shlq	$0x3, %r13
100002c4e: 48 ff cb                    	decq	%rbx
100002c51: 41 0f 94 c6                 	sete	%r14b
100002c55: 74 48                       	je	0x100002c9f <__text+0x1c9f>
100002c57: 4f 8d 24 2f                 	leaq	(%r15,%r13), %r12
100002c5b: 48 8b 7d d0                 	movq	-0x30(%rbp), %rdi
100002c5f: 4c 89 fe                    	movq	%r15, %rsi
100002c62: 48 8b 55 c8                 	movq	-0x38(%rbp), %rdx
100002c66: e8 34 fe ff ff              	callq	0x100002a9f <__text+0x1a9f>
100002c6b: 4d 89 e7                    	movq	%r12, %r15
100002c6e: a8 01                       	testb	$0x1, %al
100002c70: 75 dc                       	jne	0x100002c4e <__text+0x1c4e>
100002c72: eb 2b                       	jmp	0x100002c9f <__text+0x1c9f>
100002c74: 4d 8b 3f                    	movq	(%r15), %r15
100002c77: 4d 85 ff                    	testq	%r15, %r15
100002c7a: 74 20                       	je	0x100002c9c <__text+0x1c9c>
100002c7c: 6a 01                       	pushq	$0x1
100002c7e: 59                          	popq	%rcx
100002c7f: 4c 89 fe                    	movq	%r15, %rsi
100002c82: 4c 89 e2                    	movq	%r12, %rdx
100002c85: 48 89 fb                    	movq	%rdi, %rbx
100002c88: e8 f7 fa ff ff              	callq	0x100002784 <__text+0x1784>
100002c8d: a8 03                       	testb	$0x3, %al
100002c8f: 74 60                       	je	0x100002cf1 <__text+0x1cf1>
100002c91: 0f b6 c0                    	movzbl	%al, %eax
100002c94: 83 e0 03                    	andl	$0x3, %eax
100002c97: 83 f8 01                    	cmpl	$0x1, %eax
100002c9a: 74 03                       	je	0x100002c9f <__text+0x1c9f>
100002c9c: 45 31 f6                    	xorl	%r14d, %r14d
100002c9f: 44 89 f0                    	movl	%r14d, %eax
100002ca2: 48 83 c4 28                 	addq	$0x28, %rsp
100002ca6: 5b                          	popq	%rbx
100002ca7: 41 5c                       	popq	%r12
100002ca9: 41 5d                       	popq	%r13
100002cab: 41 5e                       	popq	%r14
100002cad: 41 5f                       	popq	%r15
100002caf: 5d                          	popq	%rbp
100002cb0: c3                          	retq
100002cb1: 48 8b 32                    	movq	(%rdx), %rsi
100002cb4: 6a 01                       	pushq	$0x1
100002cb6: 58                          	popq	%rax
100002cb7: 45 31 c0                    	xorl	%r8d, %r8d
100002cba: 4c 39 c6                    	cmpq	%r8, %rsi
100002cbd: 74 dd                       	je	0x100002c9c <__text+0x1c9c>
100002cbf: 48 8b 0c c2                 	movq	(%rdx,%rax,8), %rcx
100002cc3: 48 ff c0                    	incq	%rax
100002cc6: 4d 3b 07                    	cmpq	(%r15), %r8
100002cc9: 74 08                       	je	0x100002cd3 <__text+0x1cd3>
100002ccb: 48 01 c8                    	addq	%rcx, %rax
100002cce: 49 ff c0                    	incq	%r8
100002cd1: eb e7                       	jmp	0x100002cba <__text+0x1cba>
100002cd3: 49 83 c7 08                 	addq	$0x8, %r15
100002cd7: 48 8d 14 c2                 	leaq	(%rdx,%rax,8), %rdx
100002cdb: 4c 89 fe                    	movq	%r15, %rsi
100002cde: 48 83 c4 28                 	addq	$0x28, %rsp
100002ce2: 5b                          	popq	%rbx
100002ce3: 41 5c                       	popq	%r12
100002ce5: 41 5d                       	popq	%r13
100002ce7: 41 5e                       	popq	%r14
100002ce9: 41 5f                       	popq	%r15
100002ceb: 5d                          	popq	%rbp
100002cec: e9 cc fc ff ff              	jmp	0x1000029bd <__text+0x19bd>
100002cf1: 48 89 df                    	movq	%rbx, %rdi
100002cf4: 4c 89 fe                    	movq	%r15, %rsi
100002cf7: 4c 89 e2                    	movq	%r12, %rdx
100002cfa: 48 83 c4 28                 	addq	$0x28, %rsp
100002cfe: 5b                          	popq	%rbx
100002cff: 41 5c                       	popq	%r12
100002d01: 41 5d                       	popq	%r13
100002d03: 41 5e                       	popq	%r14
100002d05: 41 5f                       	popq	%r15
100002d07: 5d                          	popq	%rbp
100002d08: e9 d5 f9 ff ff              	jmp	0x1000026e2 <__text+0x16e2>
100002d0d: 48 8b 7d d0                 	movq	-0x30(%rbp), %rdi
100002d11: 48 8b 75 c8                 	movq	-0x38(%rbp), %rsi
100002d15: e8 69 00 00 00              	callq	0x100002d83 <__text+0x1d83>
100002d1a: 48 85 c0                    	testq	%rax, %rax
100002d1d: 74 80                       	je	0x100002c9f <__text+0x1c9f>
100002d1f: c6 40 30 00                 	movb	$0x0, 0x30(%rax)
100002d23: e9 77 ff ff ff              	jmp	0x100002c9f <__text+0x1c9f>
100002d28: 66 90                       	nop
100002d2a: 5c                          	popq	%rsp
100002d2b: fe ff                       	<unknown>
100002d2d: ff 4a ff                    	decl	-0x1(%rdx)
100002d30: ff ff                       	<unknown>
100002d32: 2e fe ff                    	<unknown>
100002d35: ff 69 fe                    	ljmpl	*-0x2(%rcx)
100002d38: ff ff                       	<unknown>
100002d3a: 0a ff                       	orb	%bh, %bh
100002d3c: ff ff                       	<unknown>
100002d3e: cc                          	int3
100002d3f: cc                          	int3
100002d40: 55                          	pushq	%rbp
100002d41: 48 89 e5                    	movq	%rsp, %rbp
100002d44: 48 83 ec 10                 	subq	$0x10, %rsp
100002d48: 48 89 f8                    	movq	%rdi, %rax
100002d4b: 48 81 fe ff ff ff 00        	cmpq	$0xffffff, %rsi         ## imm = 0xFFFFFF
100002d52: 77 09                       	ja	0x100002d5d <__text+0x1d5d>
100002d54: 48 8d 0d d5 03 00 00        	leaq	0x3d5(%rip), %rcx       ## 0x100003130 <__text+0x2130>
100002d5b: eb 12                       	jmp	0x100002d6f <__text+0x1d6f>
100002d5d: 48 81 c6 00 00 00 ff        	addq	$-0x1000000, %rsi       ## imm = 0xFF000000
100002d64: 48 8d 4d f0                 	leaq	-0x10(%rbp), %rcx
100002d68: 48 89 31                    	movq	%rsi, (%rcx)
100002d6b: c6 41 08 01                 	movb	$0x1, 0x8(%rcx)
100002d6f: 48 8b 11                    	movq	(%rcx), %rdx
100002d72: 48 8b 49 08                 	movq	0x8(%rcx), %rcx
100002d76: 48 89 48 08                 	movq	%rcx, 0x8(%rax)
100002d7a: 48 89 10                    	movq	%rdx, (%rax)
100002d7d: 48 83 c4 10                 	addq	$0x10, %rsp
100002d81: 5d                          	popq	%rbp
100002d82: c3                          	retq
100002d83: 55                          	pushq	%rbp
100002d84: 48 89 e5                    	movq	%rsp, %rbp
100002d87: 48 8b 57 08                 	movq	0x8(%rdi), %rdx
100002d8b: 48 8b 4f 10                 	movq	0x10(%rdi), %rcx
100002d8f: 48 ff c1                    	incq	%rcx
100002d92: 48 83 c2 c8                 	addq	$-0x38, %rdx
100002d96: 48 ff c9                    	decq	%rcx
100002d99: 74 0f                       	je	0x100002daa <__text+0x1daa>
100002d9b: 48 8d 42 38                 	leaq	0x38(%rdx), %rax
100002d9f: 48 39 72 38                 	cmpq	%rsi, 0x38(%rdx)
100002da3: 48 89 c2                    	movq	%rax, %rdx
100002da6: 75 ee                       	jne	0x100002d96 <__text+0x1d96>
100002da8: eb 02                       	jmp	0x100002dac <__text+0x1dac>
100002daa: 31 c0                       	xorl	%eax, %eax
100002dac: 5d                          	popq	%rbp
100002dad: c3                          	retq
100002dae: 55                          	pushq	%rbp
100002daf: 48 89 e5                    	movq	%rsp, %rbp
100002db2: 41 57                       	pushq	%r15
100002db4: 41 56                       	pushq	%r14
100002db6: 41 55                       	pushq	%r13
100002db8: 41 54                       	pushq	%r12
100002dba: 53                          	pushq	%rbx
100002dbb: 48 83 ec 28                 	subq	$0x28, %rsp
100002dbf: 4c 89 cb                    	movq	%r9, %rbx
100002dc2: 4c 89 45 b8                 	movq	%r8, -0x48(%rbp)
100002dc6: 48 89 4d c0                 	movq	%rcx, -0x40(%rbp)
100002dca: 49 89 d4                    	movq	%rdx, %r12
100002dcd: 49 89 f5                    	movq	%rsi, %r13
100002dd0: 49 89 fe                    	movq	%rdi, %r14
100002dd3: 48 ff c3                    	incq	%rbx
100002dd6: 48 c7 45 c8 00 00 00 00     	movq	$0x0, -0x38(%rbp)
100002dde: 45 31 ff                    	xorl	%r15d, %r15d
100002de1: 4d 39 fc                    	cmpq	%r15, %r12
100002de4: 74 32                       	je	0x100002e18 <__text+0x1e18>
100002de6: 4b 8b 74 fd 00              	movq	(%r13,%r15,8), %rsi
100002deb: 4c 89 f7                    	movq	%r14, %rdi
100002dee: 48 8b 55 c0                 	movq	-0x40(%rbp), %rdx
100002df2: 48 8b 4d b8                 	movq	-0x48(%rbp), %rcx
100002df6: 49 89 d8                    	movq	%rbx, %r8
100002df9: e8 32 00 00 00              	callq	0x100002e30 <__text+0x1e30>
100002dfe: a8 03                       	testb	$0x3, %al
100002e00: 74 11                       	je	0x100002e13 <__text+0x1e13>
100002e02: 0f b6 c8                    	movzbl	%al, %ecx
100002e05: 83 e1 03                    	andl	$0x3, %ecx
100002e08: 83 f9 01                    	cmpl	$0x1, %ecx
100002e0b: 75 14                       	jne	0x100002e21 <__text+0x1e21>
100002e0d: b0 01                       	movb	$0x1, %al
100002e0f: 48 89 45 c8                 	movq	%rax, -0x38(%rbp)
100002e13: 49 ff c7                    	incq	%r15
100002e16: eb c9                       	jmp	0x100002de1 <__text+0x1de1>
100002e18: 48 8b 45 c8                 	movq	-0x38(%rbp), %rax
100002e1c: 24 03                       	andb	$0x3, %al
100002e1e: 88 45 d7                    	movb	%al, -0x29(%rbp)
100002e21: 48 83 c4 28                 	addq	$0x28, %rsp
100002e25: 5b                          	popq	%rbx
100002e26: 41 5c                       	popq	%r12
100002e28: 41 5d                       	popq	%r13
100002e2a: 41 5e                       	popq	%r14
100002e2c: 41 5f                       	popq	%r15
100002e2e: 5d                          	popq	%rbp
100002e2f: c3                          	retq
100002e30: 55                          	pushq	%rbp
100002e31: 48 89 e5                    	movq	%rsp, %rbp
100002e34: 41 57                       	pushq	%r15
100002e36: 41 56                       	pushq	%r14
100002e38: 41 55                       	pushq	%r13
100002e3a: 41 54                       	pushq	%r12
100002e3c: 53                          	pushq	%rbx
100002e3d: 48 83 ec 38                 	subq	$0x38, %rsp
100002e41: 4d 89 c6                    	movq	%r8, %r14
100002e44: 48 89 cb                    	movq	%rcx, %rbx
100002e47: 48 89 55 c0                 	movq	%rdx, -0x40(%rbp)
100002e4b: 49 89 f7                    	movq	%rsi, %r15
100002e4e: 48 89 7d c8                 	movq	%rdi, -0x38(%rbp)
100002e52: 4c 8d 65 a0                 	leaq	-0x60(%rbp), %r12
100002e56: 41 b5 02                    	movb	$0x2, %r13b
100002e59: 49 81 fe 00 01 00 00        	cmpq	$0x100, %r14            ## imm = 0x100
100002e60: 0f 87 9f 02 00 00           	ja	0x100003105 <__text+0x2105>
100002e66: 4c 89 e7                    	movq	%r12, %rdi
100002e69: 4c 89 fe                    	movq	%r15, %rsi
100002e6c: e8 cf fe ff ff              	callq	0x100002d40 <__text+0x1d40>
100002e71: 80 7d a8 00                 	cmpb	$0x0, -0x58(%rbp)
100002e75: 74 09                       	je	0x100002e80 <__text+0x1e80>
100002e77: 4c 8b 7d a0                 	movq	-0x60(%rbp), %r15
100002e7b: 49 ff c6                    	incq	%r14
100002e7e: eb d6                       	jmp	0x100002e56 <__text+0x1e56>
100002e80: 49 83 ff 0e                 	cmpq	$0xe, %r15
100002e84: 0f 92 c0                    	setb	%al
100002e87: 4c 89 f9                    	movq	%r15, %rcx
100002e8a: 48 81 e1 00 00 c0 ff        	andq	$-0x400000, %rcx        ## imm = 0xFFC00000
100002e91: 48 81 f9 00 00 40 00        	cmpq	$0x400000, %rcx         ## imm = 0x400000
100002e98: 0f 94 c1                    	sete	%cl
100002e9b: 08 c1                       	orb	%al, %cl
100002e9d: 74 08                       	je	0x100002ea7 <__text+0x1ea7>
100002e9f: 45 31 ed                    	xorl	%r13d, %r13d
100002ea2: e9 5e 02 00 00              	jmp	0x100003105 <__text+0x2105>
100002ea7: 49 8d 87 00 00 c0 ff        	leaq	-0x400000(%r15), %rax
100002eae: 48 3d 00 01 c0 ff           	cmpq	$-0x3fff00, %rax        ## imm = 0xFFC00100
100002eb4: 0f 82 4b 02 00 00           	jb	0x100003105 <__text+0x2105>
100002eba: 48 8b 83 00 08 00 00        	movq	0x800(%rbx), %rax
100002ec1: 48 89 c1                    	movq	%rax, %rcx
100002ec4: 48 f7 d9                    	negq	%rcx
100002ec7: 6a ff                       	pushq	$-0x1
100002ec9: 5a                          	popq	%rdx
100002eca: 48 8d 34 11                 	leaq	(%rcx,%rdx), %rsi
100002ece: 48 83 fe ff                 	cmpq	$-0x1, %rsi
100002ed2: 74 13                       	je	0x100002ee7 <__text+0x1ee7>
100002ed4: 48 8d 72 01                 	leaq	0x1(%rdx), %rsi
100002ed8: 4c 39 7c d3 08              	cmpq	%r15, 0x8(%rbx,%rdx,8)
100002edd: 48 89 f2                    	movq	%rsi, %rdx
100002ee0: 75 e8                       	jne	0x100002eca <__text+0x1eca>
100002ee2: 48 39 c6                    	cmpq	%rax, %rsi
100002ee5: 72 b8                       	jb	0x100002e9f <__text+0x1e9f>
100002ee7: 48 3d 00 01 00 00           	cmpq	$0x100, %rax            ## imm = 0x100
100002eed: 0f 84 12 02 00 00           	je	0x100003105 <__text+0x2105>
100002ef3: 4c 89 3c c3                 	movq	%r15, (%rbx,%rax,8)
100002ef7: 48 ff 83 00 08 00 00        	incq	0x800(%rbx)
100002efe: 48 8b 45 c8                 	movq	-0x38(%rbp), %rax
100002f02: 48 8b 00                    	movq	(%rax), %rax
100002f05: 49 c1 e7 05                 	shlq	$0x5, %r15
100002f09: 4a 8b 94 38 08 e0 ff ff     	movq	-0x1ff8(%rax,%r15), %rdx
100002f11: 4a 8b 8c 38 18 e0 ff ff     	movq	-0x1fe8(%rax,%r15), %rcx
100002f19: 48 8d 34 c8                 	leaq	(%rax,%rcx,8), %rsi
100002f1d: 48 83 fa 04                 	cmpq	$0x4, %rdx
100002f21: 48 89 75 b0                 	movq	%rsi, -0x50(%rbp)
100002f25: 0f 87 4c 01 00 00           	ja	0x100003077 <__text+0x2077>
100002f2b: 48 8d 3d e6 01 00 00        	leaq	0x1e6(%rip), %rdi       ## 0x100003118 <__text+0x2118>
100002f32: 48 63 14 97                 	movslq	(%rdi,%rdx,4), %rdx
100002f36: 48 01 fa                    	addq	%rdi, %rdx
100002f39: ff e2                       	jmpq	*%rdx
100002f3b: 48 8b 36                    	movq	(%rsi), %rsi
100002f3e: 49 ff c6                    	incq	%r14
100002f41: 48 8b 7d c8                 	movq	-0x38(%rbp), %rdi
100002f45: 48 8b 55 c0                 	movq	-0x40(%rbp), %rdx
100002f49: 48 89 d9                    	movq	%rbx, %rcx
100002f4c: 4d 89 f0                    	movq	%r14, %r8
100002f4f: e8 dc fe ff ff              	callq	0x100002e30 <__text+0x1e30>
100002f54: e9 8a 00 00 00              	jmp	0x100002fe3 <__text+0x1fe3>
100002f59: c6 45 d7 00                 	movb	$0x0, -0x29(%rbp)
100002f5d: 4c 8d 7c c8 10              	leaq	0x10(%rax,%rcx,8), %r15
100002f62: 4d 8b 67 f0                 	movq	-0x10(%r15), %r12
100002f66: 49 83 c6 02                 	addq	$0x2, %r14
100002f6a: 44 8a 6d d7                 	movb	-0x29(%rbp), %r13b
100002f6e: 49 83 ec 01                 	subq	$0x1, %r12
100002f72: 0f 82 86 01 00 00           	jb	0x1000030fe <__text+0x20fe>
100002f78: 41 80 e5 03                 	andb	$0x3, %r13b
100002f7c: 49 8b 37                    	movq	(%r15), %rsi
100002f7f: 48 8b 7d c8                 	movq	-0x38(%rbp), %rdi
100002f83: 48 8b 55 c0                 	movq	-0x40(%rbp), %rdx
100002f87: 48 89 d9                    	movq	%rbx, %rcx
100002f8a: 4d 89 f0                    	movq	%r14, %r8
100002f8d: e8 9e fe ff ff              	callq	0x100002e30 <__text+0x1e30>
100002f92: 24 03                       	andb	$0x3, %al
100002f94: 41 80 fd 01                 	cmpb	$0x1, %r13b
100002f98: 0f 94 c1                    	sete	%cl
100002f9b: 3c 01                       	cmpb	$0x1, %al
100002f9d: 0f 94 c2                    	sete	%dl
100002fa0: 08 ca                       	orb	%cl, %dl
100002fa2: 3c 02                       	cmpb	$0x2, %al
100002fa4: 0f b6 c2                    	movzbl	%dl, %eax
100002fa7: 6a 02                       	pushq	$0x2
100002fa9: 59                          	popq	%rcx
100002faa: 0f 44 c1                    	cmovel	%ecx, %eax
100002fad: 41 80 fd 02                 	cmpb	$0x2, %r13b
100002fb1: 0f 44 c1                    	cmovel	%ecx, %eax
100002fb4: 88 45 d7                    	movb	%al, -0x29(%rbp)
100002fb7: 3c 02                       	cmpb	$0x2, %al
100002fb9: 0f 84 31 01 00 00           	je	0x1000030f0 <__text+0x20f0>
100002fbf: 49 83 c7 10                 	addq	$0x10, %r15
100002fc3: eb a5                       	jmp	0x100002f6a <__text+0x1f6a>
100002fc5: 4a 8b 94 38 20 e0 ff ff     	movq	-0x1fe0(%rax,%r15), %rdx
100002fcd: 49 ff c6                    	incq	%r14
100002fd0: 48 8b 7d c8                 	movq	-0x38(%rbp), %rdi
100002fd4: 48 8b 4d c0                 	movq	-0x40(%rbp), %rcx
100002fd8: 49 89 d8                    	movq	%rbx, %r8
100002fdb: 4d 89 f1                    	movq	%r14, %r9
100002fde: e8 cb fd ff ff              	callq	0x100002dae <__text+0x1dae>
100002fe3: 41 89 c5                    	movl	%eax, %r13d
100002fe6: e9 13 01 00 00              	jmp	0x1000030fe <__text+0x20fe>
100002feb: c6 45 d7 00                 	movb	$0x0, -0x29(%rbp)
100002fef: 48 8b 06                    	movq	(%rsi), %rax
100002ff2: 49 83 c6 02                 	addq	$0x2, %r14
100002ff6: 6a 01                       	pushq	$0x1
100002ff8: 41 5d                       	popq	%r13
100002ffa: 48 83 e8 01                 	subq	$0x1, %rax
100002ffe: 48 8b 4d c0                 	movq	-0x40(%rbp), %rcx
100003002: 0f 82 ed 00 00 00           	jb	0x1000030f5 <__text+0x20f5>
100003008: 4a 39 0c ee                 	cmpq	%rcx, (%rsi,%r13,8)
10000300c: 0f 84 e9 00 00 00           	je	0x1000030fb <__text+0x20fb>
100003012: 48 89 45 b8                 	movq	%rax, -0x48(%rbp)
100003016: 4e 8b 7c ee 10              	movq	0x10(%rsi,%r13,8), %r15
10000301b: 49 83 c5 03                 	addq	$0x3, %r13
10000301f: 44 8a 65 d7                 	movb	-0x29(%rbp), %r12b
100003023: 41 80 e4 03                 	andb	$0x3, %r12b
100003027: 4a 8d 34 ee                 	leaq	(%rsi,%r13,8), %rsi
10000302b: 48 8b 7d c8                 	movq	-0x38(%rbp), %rdi
10000302f: 4c 89 fa                    	movq	%r15, %rdx
100003032: 49 89 d8                    	movq	%rbx, %r8
100003035: 4d 89 f1                    	movq	%r14, %r9
100003038: e8 71 fd ff ff              	callq	0x100002dae <__text+0x1dae>
10000303d: 24 03                       	andb	$0x3, %al
10000303f: 41 80 fc 01                 	cmpb	$0x1, %r12b
100003043: 0f 94 c1                    	sete	%cl
100003046: 3c 01                       	cmpb	$0x1, %al
100003048: 0f 94 c2                    	sete	%dl
10000304b: 08 ca                       	orb	%cl, %dl
10000304d: 3c 02                       	cmpb	$0x2, %al
10000304f: 0f b6 c2                    	movzbl	%dl, %eax
100003052: 6a 02                       	pushq	$0x2
100003054: 59                          	popq	%rcx
100003055: 0f 44 c1                    	cmovel	%ecx, %eax
100003058: 41 80 fc 02                 	cmpb	$0x2, %r12b
10000305c: 0f 44 c1                    	cmovel	%ecx, %eax
10000305f: 88 45 d7                    	movb	%al, -0x29(%rbp)
100003062: 3c 02                       	cmpb	$0x2, %al
100003064: 0f 84 86 00 00 00           	je	0x1000030f0 <__text+0x20f0>
10000306a: 4d 01 fd                    	addq	%r15, %r13
10000306d: 48 8b 75 b0                 	movq	-0x50(%rbp), %rsi
100003071: 48 8b 45 b8                 	movq	-0x48(%rbp), %rax
100003075: eb 83                       	jmp	0x100002ffa <__text+0x1ffa>
100003077: c6 45 d7 00                 	movb	$0x0, -0x29(%rbp)
10000307b: 48 8b 06                    	movq	(%rsi), %rax
10000307e: 49 83 c6 02                 	addq	$0x2, %r14
100003082: 6a 01                       	pushq	$0x1
100003084: 41 5c                       	popq	%r12
100003086: 48 83 e8 01                 	subq	$0x1, %rax
10000308a: 72 69                       	jb	0x1000030f5 <__text+0x20f5>
10000308c: 48 89 45 b8                 	movq	%rax, -0x48(%rbp)
100003090: 4a 8d 74 e6 08              	leaq	0x8(%rsi,%r12,8), %rsi
100003095: 4c 8b 7e f8                 	movq	-0x8(%rsi), %r15
100003099: 44 8a 6d d7                 	movb	-0x29(%rbp), %r13b
10000309d: 41 80 e5 03                 	andb	$0x3, %r13b
1000030a1: 48 8b 7d c8                 	movq	-0x38(%rbp), %rdi
1000030a5: 4c 89 fa                    	movq	%r15, %rdx
1000030a8: 48 8b 4d c0                 	movq	-0x40(%rbp), %rcx
1000030ac: 49 89 d8                    	movq	%rbx, %r8
1000030af: 4d 89 f1                    	movq	%r14, %r9
1000030b2: e8 f7 fc ff ff              	callq	0x100002dae <__text+0x1dae>
1000030b7: 24 03                       	andb	$0x3, %al
1000030b9: 41 80 fd 01                 	cmpb	$0x1, %r13b
1000030bd: 0f 94 c1                    	sete	%cl
1000030c0: 3c 01                       	cmpb	$0x1, %al
1000030c2: 0f 94 c2                    	sete	%dl
1000030c5: 08 ca                       	orb	%cl, %dl
1000030c7: 3c 02                       	cmpb	$0x2, %al
1000030c9: 0f b6 c2                    	movzbl	%dl, %eax
1000030cc: 6a 02                       	pushq	$0x2
1000030ce: 59                          	popq	%rcx
1000030cf: 0f 44 c1                    	cmovel	%ecx, %eax
1000030d2: 41 80 fd 02                 	cmpb	$0x2, %r13b
1000030d6: 0f 44 c1                    	cmovel	%ecx, %eax
1000030d9: 88 45 d7                    	movb	%al, -0x29(%rbp)
1000030dc: 3c 02                       	cmpb	$0x2, %al
1000030de: 74 10                       	je	0x1000030f0 <__text+0x20f0>
1000030e0: 49 ff c4                    	incq	%r12
1000030e3: 4d 01 fc                    	addq	%r15, %r12
1000030e6: 48 8b 75 b0                 	movq	-0x50(%rbp), %rsi
1000030ea: 48 8b 45 b8                 	movq	-0x48(%rbp), %rax
1000030ee: eb 96                       	jmp	0x100003086 <__text+0x2086>
1000030f0: 41 b5 02                    	movb	$0x2, %r13b
1000030f3: eb 09                       	jmp	0x1000030fe <__text+0x20fe>
1000030f5: 44 8a 6d d7                 	movb	-0x29(%rbp), %r13b
1000030f9: eb 03                       	jmp	0x1000030fe <__text+0x20fe>
1000030fb: 41 b5 01                    	movb	$0x1, %r13b
1000030fe: 48 ff 8b 00 08 00 00        	decq	0x800(%rbx)
100003105: 44 89 e8                    	movl	%r13d, %eax
100003108: 48 83 c4 38                 	addq	$0x38, %rsp
10000310c: 5b                          	popq	%rbx
10000310d: 41 5c                       	popq	%r12
10000310f: 41 5d                       	popq	%r13
100003111: 41 5e                       	popq	%r14
100003113: 41 5f                       	popq	%r15
100003115: 5d                          	popq	%rbp
100003116: c3                          	retq
100003117: 90                          	nop
100003118: ad                          	lodsl	(%rsi), %eax
100003119: fe ff                       	<unknown>
10000311b: ff d3                       	callq	*%rbx
10000311d: fe ff                       	<unknown>
10000311f: ff 41 fe                    	incl	-0x2(%rcx)
100003122: ff ff                       	<unknown>
100003124: 23 fe                       	andl	%esi, %edi
100003126: ff ff                       	<unknown>
100003128: 23 fe                       	andl	%esi, %edi
10000312a: ff ff                       	<unknown>
		...
