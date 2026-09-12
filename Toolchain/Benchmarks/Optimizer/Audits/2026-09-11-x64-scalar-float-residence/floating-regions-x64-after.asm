
/private/tmp/silex-part03-evidence/floating-regions-x64-after:	file format mach-o 64-bit x86-64

Disassembly of section __TEXT,__text:

0000000100001000 <__text>:
100001000: 55                          	pushq	%rbp
100001001: 48 89 e5                    	movq	%rsp, %rbp
100001004: 48 81 ec 20 00 00 00        	subq	$0x20, %rsp
10000100b: 48 89 e5                    	movq	%rsp, %rbp
10000100e: 48 89 bd 00 00 00 00        	movq	%rdi, (%rbp)
100001015: 48 83 ec 28                 	subq	$0x28, %rsp
100001019: 48 8d 74 24 27              	leaq	0x27(%rsp), %rsi
10000101e: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
100001025: c6 06 0a                    	movb	$0xa, (%rsi)
100001028: 49 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r8
100001032: 49 b9 00 00 00 00 00 00 00 00       	movabsq	$0x0, %r9
10000103c: 48 85 c0                    	testq	%rax, %rax
10000103f: 0f 89 0d 00 00 00           	jns	0x100001052 <__text+0x52>
100001045: 49 b9 01 00 00 00 00 00 00 00       	movabsq	$0x1, %r9
10000104f: 48 f7 d8                    	negq	%rax
100001052: 48 85 c0                    	testq	%rax, %rax
100001055: 0f 85 0e 00 00 00           	jne	0x100001069 <__text+0x69>
10000105b: 48 ff ce                    	decq	%rsi
10000105e: c6 06 30                    	movb	$0x30, (%rsi)
100001061: 49 ff c0                    	incq	%r8
100001064: e9 23 00 00 00              	jmp	0x10000108c <__text+0x8c>
100001069: 48 b9 0a 00 00 00 00 00 00 00       	movabsq	$0xa, %rcx
100001073: 31 d2                       	xorl	%edx, %edx
100001075: 48 f7 f1                    	divq	%rcx
100001078: 80 c2 30                    	addb	$0x30, %dl
10000107b: 48 ff ce                    	decq	%rsi
10000107e: 88 16                       	movb	%dl, (%rsi)
100001080: 49 ff c0                    	incq	%r8
100001083: 48 85 c0                    	testq	%rax, %rax
100001086: 0f 85 dd ff ff ff           	jne	0x100001069 <__text+0x69>
10000108c: 4d 85 c9                    	testq	%r9, %r9
10000108f: 0f 84 09 00 00 00           	je	0x10000109e <__text+0x9e>
100001095: 48 ff ce                    	decq	%rsi
100001098: c6 06 2d                    	movb	$0x2d, (%rsi)
10000109b: 49 ff c0                    	incq	%r8
10000109e: 4c 89 c2                    	movq	%r8, %rdx
1000010a1: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000010ab: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000010b5: 0f 05                       	syscall
1000010b7: 48 83 c4 28                 	addq	$0x28, %rsp
1000010bb: 48 8b 85 00 00 00 00        	movq	(%rbp), %rax
1000010c2: 31 d2                       	xorl	%edx, %edx
1000010c4: e9 00 00 00 00              	jmp	0x1000010c9 <__text+0xc9>
1000010c9: 48 89 ec                    	movq	%rbp, %rsp
1000010cc: 48 81 c4 20 00 00 00        	addq	$0x20, %rsp
1000010d3: 5d                          	popq	%rbp
1000010d4: c3                          	retq
1000010d5: 55                          	pushq	%rbp
1000010d6: 48 89 e5                    	movq	%rsp, %rbp
1000010d9: 48 81 ec 80 02 00 00        	subq	$0x280, %rsp            ## imm = 0x280
1000010e0: 48 89 e5                    	movq	%rsp, %rbp
1000010e3: 48 b8 c0 c6 2d 00 00 00 00 00       	movabsq	$0x2dc6c0, %rax ## imm = 0x2DC6C0
1000010ed: 48 89 85 00 00 00 00        	movq	%rax, (%rbp)
1000010f4: 48 8b bd 00 00 00 00        	movq	(%rbp), %rdi
1000010fb: e8 00 ff ff ff              	callq	0x100001000 <__text>
100001100: 48 85 d2                    	testq	%rdx, %rdx
100001103: 0f 85 dd 03 00 00           	jne	0x1000014e6 <__text+0x4e6>
100001109: 48 89 85 08 00 00 00        	movq	%rax, 0x8(%rbp)
100001110: 48 b8 00 00 00 3e 00 00 00 00       	movabsq	$0x3e000000, %rax ## imm = 0x3E000000
10000111a: 66 48 0f 6e f0              	movq	%rax, %xmm6
10000111f: 48 b8 00 00 80 3e 00 00 00 00       	movabsq	$0x3e800000, %rax ## imm = 0x3E800000
100001129: 66 48 0f 6e f8              	movq	%rax, %xmm7
10000112e: 48 b8 00 00 c0 3e 00 00 00 00       	movabsq	$0x3ec00000, %rax ## imm = 0x3EC00000
100001138: 66 4c 0f 6e c0              	movq	%rax, %xmm8
10000113d: 48 b8 00 00 00 3f 00 00 00 00       	movabsq	$0x3f000000, %rax ## imm = 0x3F000000
100001147: 66 4c 0f 6e c8              	movq	%rax, %xmm9
10000114c: 48 b8 00 00 20 3f 00 00 00 00       	movabsq	$0x3f200000, %rax ## imm = 0x3F200000
100001156: 66 4c 0f 6e d0              	movq	%rax, %xmm10
10000115b: 48 b8 00 00 40 3f 00 00 00 00       	movabsq	$0x3f400000, %rax ## imm = 0x3F400000
100001165: 66 4c 0f 6e d8              	movq	%rax, %xmm11
10000116a: 48 b8 00 00 60 3f 00 00 00 00       	movabsq	$0x3f600000, %rax ## imm = 0x3F600000
100001174: 66 4c 0f 6e e0              	movq	%rax, %xmm12
100001179: 48 b8 00 00 80 3f 00 00 00 00       	movabsq	$0x3f800000, %rax ## imm = 0x3F800000
100001183: 66 4c 0f 6e e8              	movq	%rax, %xmm13
100001188: 48 b8 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rax
100001192: 48 89 85 50 00 00 00        	movq	%rax, 0x50(%rbp)
100001199: 48 8b 85 08 00 00 00        	movq	0x8(%rbp), %rax
1000011a0: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
1000011a7: 48 8b 85 28 02 00 00        	movq	0x228(%rbp), %rax
1000011ae: 48 8b 8d 50 00 00 00        	movq	0x50(%rbp), %rcx
1000011b5: 48 39 c8                    	cmpq	%rcx, %rax
1000011b8: 0f 9f c0                    	setg	%al
1000011bb: 48 0f b6 c0                 	movzbq	%al, %rax
1000011bf: 48 89 85 58 00 00 00        	movq	%rax, 0x58(%rbp)
1000011c6: 48 8b 85 58 00 00 00        	movq	0x58(%rbp), %rax
1000011cd: 48 85 c0                    	testq	%rax, %rax
1000011d0: 0f 85 05 00 00 00           	jne	0x1000011db <__text+0x1db>
1000011d6: e9 24 02 00 00              	jmp	0x1000013ff <__text+0x3ff>
1000011db: 48 b8 77 be 7f 3f 00 00 00 00       	movabsq	$0x3f7fbe77, %rax ## imm = 0x3F7FBE77
1000011e5: 66 4c 0f 6e f0              	movq	%rax, %xmm14
1000011ea: 0f 28 c6                    	movaps	%xmm6, %xmm0
1000011ed: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
1000011f1: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000011f5: 0f 28 f0                    	movaps	%xmm0, %xmm6
1000011f8: 48 b8 6f 12 83 3a 00 00 00 00       	movabsq	$0x3a83126f, %rax ## imm = 0x3A83126F
100001202: 66 4c 0f 6e f0              	movq	%rax, %xmm14
100001207: 0f 28 c6                    	movaps	%xmm6, %xmm0
10000120a: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
10000120e: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001212: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001215: 48 b8 77 be 7f 3f 00 00 00 00       	movabsq	$0x3f7fbe77, %rax ## imm = 0x3F7FBE77
10000121f: 66 4c 0f 6e f0              	movq	%rax, %xmm14
100001224: 0f 28 c7                    	movaps	%xmm7, %xmm0
100001227: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
10000122b: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000122f: 0f 28 f8                    	movaps	%xmm0, %xmm7
100001232: 48 b8 6f 12 03 3b 00 00 00 00       	movabsq	$0x3b03126f, %rax ## imm = 0x3B03126F
10000123c: 66 4c 0f 6e f0              	movq	%rax, %xmm14
100001241: 0f 28 c7                    	movaps	%xmm7, %xmm0
100001244: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
100001248: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000124c: 0f 28 f8                    	movaps	%xmm0, %xmm7
10000124f: 48 b8 77 be 7f 3f 00 00 00 00       	movabsq	$0x3f7fbe77, %rax ## imm = 0x3F7FBE77
100001259: 66 4c 0f 6e f0              	movq	%rax, %xmm14
10000125e: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100001262: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
100001266: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
10000126a: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
10000126e: 48 b8 a6 9b 44 3b 00 00 00 00       	movabsq	$0x3b449ba6, %rax ## imm = 0x3B449BA6
100001278: 66 4c 0f 6e f0              	movq	%rax, %xmm14
10000127d: 41 0f 28 c0                 	movaps	%xmm8, %xmm0
100001281: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
100001285: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001289: 44 0f 28 c0                 	movaps	%xmm0, %xmm8
10000128d: 48 b8 77 be 7f 3f 00 00 00 00       	movabsq	$0x3f7fbe77, %rax ## imm = 0x3F7FBE77
100001297: 66 4c 0f 6e f0              	movq	%rax, %xmm14
10000129c: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000012a0: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
1000012a4: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000012a8: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000012ac: 48 b8 6f 12 83 3b 00 00 00 00       	movabsq	$0x3b83126f, %rax ## imm = 0x3B83126F
1000012b6: 66 4c 0f 6e f0              	movq	%rax, %xmm14
1000012bb: 41 0f 28 c1                 	movaps	%xmm9, %xmm0
1000012bf: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
1000012c3: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000012c7: 44 0f 28 c8                 	movaps	%xmm0, %xmm9
1000012cb: 48 b8 77 be 7f 3f 00 00 00 00       	movabsq	$0x3f7fbe77, %rax ## imm = 0x3F7FBE77
1000012d5: 66 4c 0f 6e f0              	movq	%rax, %xmm14
1000012da: 41 0f 28 c2                 	movaps	%xmm10, %xmm0
1000012de: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
1000012e2: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000012e6: 44 0f 28 d0                 	movaps	%xmm0, %xmm10
1000012ea: 48 b8 0a d7 a3 3b 00 00 00 00       	movabsq	$0x3ba3d70a, %rax ## imm = 0x3BA3D70A
1000012f4: 66 4c 0f 6e f0              	movq	%rax, %xmm14
1000012f9: 41 0f 28 c2                 	movaps	%xmm10, %xmm0
1000012fd: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
100001301: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001305: 44 0f 28 d0                 	movaps	%xmm0, %xmm10
100001309: 48 b8 77 be 7f 3f 00 00 00 00       	movabsq	$0x3f7fbe77, %rax ## imm = 0x3F7FBE77
100001313: 66 4c 0f 6e f0              	movq	%rax, %xmm14
100001318: 41 0f 28 c3                 	movaps	%xmm11, %xmm0
10000131c: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
100001320: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001324: 44 0f 28 d8                 	movaps	%xmm0, %xmm11
100001328: 48 b8 a6 9b c4 3b 00 00 00 00       	movabsq	$0x3bc49ba6, %rax ## imm = 0x3BC49BA6
100001332: 66 4c 0f 6e f0              	movq	%rax, %xmm14
100001337: 41 0f 28 c3                 	movaps	%xmm11, %xmm0
10000133b: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
10000133f: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001343: 44 0f 28 d8                 	movaps	%xmm0, %xmm11
100001347: 48 b8 77 be 7f 3f 00 00 00 00       	movabsq	$0x3f7fbe77, %rax ## imm = 0x3F7FBE77
100001351: 66 4c 0f 6e f0              	movq	%rax, %xmm14
100001356: 41 0f 28 c4                 	movaps	%xmm12, %xmm0
10000135a: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
10000135e: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
100001362: 44 0f 28 e0                 	movaps	%xmm0, %xmm12
100001366: 48 b8 42 60 e5 3b 00 00 00 00       	movabsq	$0x3be56042, %rax ## imm = 0x3BE56042
100001370: 66 4c 0f 6e f0              	movq	%rax, %xmm14
100001375: 41 0f 28 c4                 	movaps	%xmm12, %xmm0
100001379: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
10000137d: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001381: 44 0f 28 e0                 	movaps	%xmm0, %xmm12
100001385: 48 b8 77 be 7f 3f 00 00 00 00       	movabsq	$0x3f7fbe77, %rax ## imm = 0x3F7FBE77
10000138f: 66 4c 0f 6e f0              	movq	%rax, %xmm14
100001394: 41 0f 28 c5                 	movaps	%xmm13, %xmm0
100001398: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
10000139c: f3 0f 59 c1                 	mulss	%xmm1, %xmm0
1000013a0: 44 0f 28 e8                 	movaps	%xmm0, %xmm13
1000013a4: 48 b8 6f 12 03 3c 00 00 00 00       	movabsq	$0x3c03126f, %rax ## imm = 0x3C03126F
1000013ae: 66 4c 0f 6e f0              	movq	%rax, %xmm14
1000013b3: 41 0f 28 c5                 	movaps	%xmm13, %xmm0
1000013b7: 41 0f 28 ce                 	movaps	%xmm14, %xmm1
1000013bb: f3 0f 58 c1                 	addss	%xmm1, %xmm0
1000013bf: 44 0f 28 e8                 	movaps	%xmm0, %xmm13
1000013c3: 48 b8 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rax
1000013cd: 48 89 85 a0 01 00 00        	movq	%rax, 0x1a0(%rbp)
1000013d4: 48 8b 85 28 02 00 00        	movq	0x228(%rbp), %rax
1000013db: 48 8b 8d a0 01 00 00        	movq	0x1a0(%rbp), %rcx
1000013e2: 48 29 c8                    	subq	%rcx, %rax
1000013e5: 48 89 85 a8 01 00 00        	movq	%rax, 0x1a8(%rbp)
1000013ec: 48 8b 85 a8 01 00 00        	movq	0x1a8(%rbp), %rax
1000013f3: 48 89 85 28 02 00 00        	movq	%rax, 0x228(%rbp)
1000013fa: e9 a8 fd ff ff              	jmp	0x1000011a7 <__text+0x1a7>
1000013ff: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001402: 0f 28 cf                    	movaps	%xmm7, %xmm1
100001405: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001409: 0f 28 f0                    	movaps	%xmm0, %xmm6
10000140c: 0f 28 c6                    	movaps	%xmm6, %xmm0
10000140f: 41 0f 28 c8                 	movaps	%xmm8, %xmm1
100001413: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001417: 0f 28 f0                    	movaps	%xmm0, %xmm6
10000141a: 0f 28 c6                    	movaps	%xmm6, %xmm0
10000141d: 41 0f 28 c9                 	movaps	%xmm9, %xmm1
100001421: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001425: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001428: 0f 28 c6                    	movaps	%xmm6, %xmm0
10000142b: 41 0f 28 ca                 	movaps	%xmm10, %xmm1
10000142f: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001433: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001436: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001439: 41 0f 28 cb                 	movaps	%xmm11, %xmm1
10000143d: f3 0f 58 c1                 	addss	%xmm1, %xmm0
100001441: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001444: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001447: 41 0f 28 cc                 	movaps	%xmm12, %xmm1
10000144b: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000144f: 0f 28 f0                    	movaps	%xmm0, %xmm6
100001452: 0f 28 c6                    	movaps	%xmm6, %xmm0
100001455: 41 0f 28 cd                 	movaps	%xmm13, %xmm1
100001459: f3 0f 58 c1                 	addss	%xmm1, %xmm0
10000145d: f3 0f 11 85 20 02 00 00     	movss	%xmm0, 0x220(%rbp)
100001465: 48 81 ec 80 01 00 00        	subq	$0x180, %rsp            ## imm = 0x180
10000146c: 48 8b bd 20 02 00 00        	movq	0x220(%rbp), %rdi
100001473: 48 8d 74 24 20              	leaq	0x20(%rsp), %rsi
100001478: 48 ba 00 00 00 00 00 00 00 00       	movabsq	$0x0, %rdx
100001482: e8 73 11 00 00              	callq	0x1000025fa <__text+0x15fa>
100001487: 49 89 c0                    	movq	%rax, %r8
10000148a: 48 8d 74 24 20              	leaq	0x20(%rsp), %rsi
10000148f: 4c 89 c2                    	movq	%r8, %rdx
100001492: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
10000149c: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000014a6: 0f 05                       	syscall
1000014a8: 48 81 c4 80 01 00 00        	addq	$0x180, %rsp            ## imm = 0x180
1000014af: 48 8d 35 4a 4b 00 00        	leaq	0x4b4a(%rip), %rsi      ## 0x100006000
1000014b6: 4c 8b 86 00 00 00 00        	movq	(%rsi), %r8
1000014bd: 48 81 c6 08 00 00 00        	addq	$0x8, %rsi
1000014c4: 4c 89 c2                    	movq	%r8, %rdx
1000014c7: 48 b8 04 00 00 02 00 00 00 00       	movabsq	$0x2000004, %rax ## imm = 0x2000004
1000014d1: 48 bf 01 00 00 00 00 00 00 00       	movabsq	$0x1, %rdi
1000014db: 0f 05                       	syscall
1000014dd: 31 c0                       	xorl	%eax, %eax
1000014df: 31 d2                       	xorl	%edx, %edx
1000014e1: e9 00 00 00 00              	jmp	0x1000014e6 <__text+0x4e6>
1000014e6: 48 89 ec                    	movq	%rbp, %rsp
1000014e9: 48 81 c4 80 02 00 00        	addq	$0x280, %rsp            ## imm = 0x280
1000014f0: 5d                          	popq	%rbp
1000014f1: c3                          	retq
1000014f2: 53                          	pushq	%rbx
1000014f3: 41 54                       	pushq	%r12
1000014f5: 41 55                       	pushq	%r13
1000014f7: 41 56                       	pushq	%r14
1000014f9: 41 57                       	pushq	%r15
1000014fb: e8 d5 fb ff ff              	callq	0x1000010d5 <__text+0xd5>
100001500: 48 85 d2                    	testq	%rdx, %rdx
100001503: 0f 95 c2                    	setne	%dl
100001506: 0f b6 d2                    	movzbl	%dl, %edx
100001509: 48 89 d0                    	movq	%rdx, %rax
10000150c: 41 5f                       	popq	%r15
10000150e: 41 5e                       	popq	%r14
100001510: 41 5d                       	popq	%r13
100001512: 41 5c                       	popq	%r12
100001514: 5b                          	popq	%rbx
100001515: c3                          	retq
		...
100002486: 00 00                       	addb	%al, (%rax)
100002488: 55                          	pushq	%rbp
100002489: 48 89 e5                    	movq	%rsp, %rbp
10000248c: 85 d2                       	testl	%edx, %edx
10000248e: 7e 28                       	jle	0x1000024b8 <__text+0x14b8>
100002490: 31 c0                       	xorl	%eax, %eax
100002492: b9 00 00 00 00              	movl	$0x0, %ecx
100002497: 83 fa 7f                    	cmpl	$0x7f, %edx
10000249a: 77 2e                       	ja	0x1000024ca <__text+0x14ca>
10000249c: 83 fa 40                    	cmpl	$0x40, %edx
10000249f: 73 1f                       	jae	0x1000024c0 <__text+0x14c0>
1000024a1: 89 d1                       	movl	%edx, %ecx
1000024a3: 48 d3 ef                    	shrq	%cl, %rdi
1000024a6: f6 d9                       	negb	%cl
1000024a8: 48 89 f0                    	movq	%rsi, %rax
1000024ab: 48 d3 e0                    	shlq	%cl, %rax
1000024ae: 48 09 f8                    	orq	%rdi, %rax
1000024b1: 89 d1                       	movl	%edx, %ecx
1000024b3: 48 d3 ee                    	shrq	%cl, %rsi
1000024b6: eb 03                       	jmp	0x1000024bb <__text+0x14bb>
1000024b8: 48 89 f8                    	movq	%rdi, %rax
1000024bb: 48 89 f1                    	movq	%rsi, %rcx
1000024be: eb 0a                       	jmp	0x1000024ca <__text+0x14ca>
1000024c0: 89 d1                       	movl	%edx, %ecx
1000024c2: 48 d3 ee                    	shrq	%cl, %rsi
1000024c5: 31 c9                       	xorl	%ecx, %ecx
1000024c7: 48 89 f0                    	movq	%rsi, %rax
1000024ca: 48 89 ca                    	movq	%rcx, %rdx
1000024cd: 5d                          	popq	%rbp
1000024ce: c3                          	retq
1000024cf: 55                          	pushq	%rbp
1000024d0: 48 89 e5                    	movq	%rsp, %rbp
1000024d3: 85 d2                       	testl	%edx, %edx
1000024d5: 7e 28                       	jle	0x1000024ff <__text+0x14ff>
1000024d7: 31 c0                       	xorl	%eax, %eax
1000024d9: b9 00 00 00 00              	movl	$0x0, %ecx
1000024de: 83 fa 7f                    	cmpl	$0x7f, %edx
1000024e1: 77 2e                       	ja	0x100002511 <__text+0x1511>
1000024e3: 83 fa 40                    	cmpl	$0x40, %edx
1000024e6: 73 1f                       	jae	0x100002507 <__text+0x1507>
1000024e8: 48 89 f8                    	movq	%rdi, %rax
1000024eb: 89 d1                       	movl	%edx, %ecx
1000024ed: 48 d3 e0                    	shlq	%cl, %rax
1000024f0: 48 d3 e6                    	shlq	%cl, %rsi
1000024f3: f6 da                       	negb	%dl
1000024f5: 89 d1                       	movl	%edx, %ecx
1000024f7: 48 d3 ef                    	shrq	%cl, %rdi
1000024fa: 48 09 f7                    	orq	%rsi, %rdi
1000024fd: eb 0f                       	jmp	0x10000250e <__text+0x150e>
1000024ff: 48 89 f8                    	movq	%rdi, %rax
100002502: 48 89 f1                    	movq	%rsi, %rcx
100002505: eb 0a                       	jmp	0x100002511 <__text+0x1511>
100002507: 89 d1                       	movl	%edx, %ecx
100002509: 48 d3 e7                    	shlq	%cl, %rdi
10000250c: 31 c0                       	xorl	%eax, %eax
10000250e: 48 89 f9                    	movq	%rdi, %rcx
100002511: 48 89 ca                    	movq	%rcx, %rdx
100002514: 5d                          	popq	%rbp
100002515: c3                          	retq
100002516: 55                          	pushq	%rbp
100002517: 48 89 e5                    	movq	%rsp, %rbp
10000251a: 41 57                       	pushq	%r15
10000251c: 41 56                       	pushq	%r14
10000251e: 41 55                       	pushq	%r13
100002520: 41 54                       	pushq	%r12
100002522: 53                          	pushq	%rbx
100002523: 48 83 ec 28                 	subq	$0x28, %rsp
100002527: 48 89 75 b8                 	movq	%rsi, -0x48(%rbp)
10000252b: 48 89 7d c0                 	movq	%rdi, -0x40(%rbp)
10000252f: 48 89 55 d0                 	movq	%rdx, -0x30(%rbp)
100002533: 48 89 d0                    	movq	%rdx, %rax
100002536: 48 89 4d c8                 	movq	%rcx, -0x38(%rbp)
10000253a: 48 09 c8                    	orq	%rcx, %rax
10000253d: 0f 84 87 00 00 00           	je	0x1000025ca <__text+0x15ca>
100002543: b3 7f                       	movb	$0x7f, %bl
100002545: 45 31 f6                    	xorl	%r14d, %r14d
100002548: 45 31 ed                    	xorl	%r13d, %r13d
10000254b: 31 c0                       	xorl	%eax, %eax
10000254d: 45 31 ff                    	xorl	%r15d, %r15d
100002550: 80 fb ff                    	cmpb	$-0x1, %bl
100002553: 74 7a                       	je	0x1000025cf <__text+0x15cf>
100002555: 48 89 45 b0                 	movq	%rax, -0x50(%rbp)
100002559: 4d 0f a4 f5 01              	shldq	$0x1, %r14, %r13
10000255e: 44 0f b6 e3                 	movzbl	%bl, %r12d
100002562: 48 8b 7d c0                 	movq	-0x40(%rbp), %rdi
100002566: 48 8b 75 b8                 	movq	-0x48(%rbp), %rsi
10000256a: 44 89 e2                    	movl	%r12d, %edx
10000256d: e8 16 ff ff ff              	callq	0x100002488 <__text+0x1488>
100002572: 83 e0 01                    	andl	$0x1, %eax
100002575: 4e 8d 34 70                 	leaq	(%rax,%r14,2), %r14
100002579: 6a 01                       	pushq	$0x1
10000257b: 5f                          	popq	%rdi
10000257c: 31 f6                       	xorl	%esi, %esi
10000257e: 44 89 e2                    	movl	%r12d, %edx
100002581: e8 49 ff ff ff              	callq	0x1000024cf <__text+0x14cf>
100002586: 4c 3b 75 d0                 	cmpq	-0x30(%rbp), %r14
10000258a: 4c 89 e9                    	movq	%r13, %rcx
10000258d: 48 1b 4d c8                 	sbbq	-0x38(%rbp), %rcx
100002591: b9 00 00 00 00              	movl	$0x0, %ecx
100002596: bf 00 00 00 00              	movl	$0x0, %edi
10000259b: be 00 00 00 00              	movl	$0x0, %esi
1000025a0: 41 b8 00 00 00 00           	movl	$0x0, %r8d
1000025a6: 72 0e                       	jb	0x1000025b6 <__text+0x15b6>
1000025a8: 48 8b 4d c8                 	movq	-0x38(%rbp), %rcx
1000025ac: 48 8b 7d d0                 	movq	-0x30(%rbp), %rdi
1000025b0: 48 89 c6                    	movq	%rax, %rsi
1000025b3: 49 89 d0                    	movq	%rdx, %r8
1000025b6: 49 29 fe                    	subq	%rdi, %r14
1000025b9: 49 19 cd                    	sbbq	%rcx, %r13
1000025bc: 4d 09 c7                    	orq	%r8, %r15
1000025bf: 48 8b 45 b0                 	movq	-0x50(%rbp), %rax
1000025c3: 48 09 f0                    	orq	%rsi, %rax
1000025c6: fe cb                       	decb	%bl
1000025c8: eb 86                       	jmp	0x100002550 <__text+0x1550>
1000025ca: 31 c0                       	xorl	%eax, %eax
1000025cc: 45 31 ff                    	xorl	%r15d, %r15d
1000025cf: 4c 89 fa                    	movq	%r15, %rdx
1000025d2: 48 83 c4 28                 	addq	$0x28, %rsp
1000025d6: 5b                          	popq	%rbx
1000025d7: 41 5c                       	popq	%r12
1000025d9: 41 5d                       	popq	%r13
1000025db: 41 5e                       	popq	%r14
1000025dd: 41 5f                       	popq	%r15
1000025df: 5d                          	popq	%rbp
1000025e0: c3                          	retq
1000025e1: 55                          	pushq	%rbp
1000025e2: 48 89 e5                    	movq	%rsp, %rbp
1000025e5: 48 89 f8                    	movq	%rdi, %rax
1000025e8: 31 c9                       	xorl	%ecx, %ecx
1000025ea: 48 39 ca                    	cmpq	%rcx, %rdx
1000025ed: 74 09                       	je	0x1000025f8 <__text+0x15f8>
1000025ef: 40 88 34 08                 	movb	%sil, (%rax,%rcx)
1000025f3: 48 ff c1                    	incq	%rcx
1000025f6: eb f2                       	jmp	0x1000025ea <__text+0x15ea>
1000025f8: 5d                          	popq	%rbp
1000025f9: c3                          	retq
1000025fa: 55                          	pushq	%rbp
1000025fb: 48 89 e5                    	movq	%rsp, %rbp
1000025fe: 41 56                       	pushq	%r14
100002600: 53                          	pushq	%rbx
100002601: 48 83 ec 30                 	subq	$0x30, %rsp
100002605: 48 89 f3                    	movq	%rsi, %rbx
100002608: 49 89 fe                    	movq	%rdi, %r14
10000260b: 48 85 d2                    	testq	%rdx, %rdx
10000260e: 74 56                       	je	0x100002666 <__text+0x1666>
100002610: 66 49 0f 6e c6              	movq	%r14, %xmm0
100002615: 66 0f 2e c0                 	ucomisd	%xmm0, %xmm0
100002619: 0f 8a d0 01 00 00           	jp	0x1000027ef <__text+0x17ef>
10000261f: 66 0f 2e 05 69 10 00 00     	ucomisd	0x1069(%rip), %xmm0     ## 0x100003690 <__text+0x2690>
100002627: 73 54                       	jae	0x10000267d <__text+0x167d>
100002629: f2 0f 10 0d 67 10 00 00     	movsd	0x1067(%rip), %xmm1     ## 0x100003698 <__text+0x2698>
100002631: 66 0f 2e c8                 	ucomisd	%xmm0, %xmm1
100002635: 73 5e                       	jae	0x100002695 <__text+0x1695>
100002637: 66 0f 57 c9                 	xorpd	%xmm1, %xmm1
10000263b: 66 0f 2e c1                 	ucomisd	%xmm1, %xmm0
10000263f: 0f 85 9b 00 00 00           	jne	0x1000026e0 <__text+0x16e0>
100002645: 0f 8a 95 00 00 00           	jp	0x1000026e0 <__text+0x16e0>
10000264b: 4d 85 f6                    	testq	%r14, %r14
10000264e: 48 8d 05 a8 13 00 00        	leaq	0x13a8(%rip), %rax      ## 0x1000039fd <__text+0x29fd>
100002655: 48 8d 35 a6 13 00 00        	leaq	0x13a6(%rip), %rsi      ## 0x100003a02 <__text+0x2a02>
10000265c: 48 0f 48 f0                 	cmovsq	%rax, %rsi
100002660: 49 c1 ee 3f                 	shrq	$0x3f, %r14
100002664: eb 74                       	jmp	0x1000026da <__text+0x16da>
100002666: 66 41 0f 6e c6              	movd	%r14d, %xmm0
10000266b: 0f 2e c0                    	ucomiss	%xmm0, %xmm0
10000266e: 0f 8a 7b 01 00 00           	jp	0x1000027ef <__text+0x17ef>
100002674: 0f 2e 05 25 10 00 00        	ucomiss	0x1025(%rip), %xmm0     ## 0x1000036a0 <__text+0x26a0>
10000267b: 72 0b                       	jb	0x100002688 <__text+0x1688>
10000267d: 48 8d 35 70 13 00 00        	leaq	0x1370(%rip), %rsi      ## 0x1000039f4 <__text+0x29f4>
100002684: 6a 03                       	pushq	$0x3
100002686: eb 16                       	jmp	0x10000269e <__text+0x169e>
100002688: f3 0f 10 0d 14 10 00 00     	movss	0x1014(%rip), %xmm1     ## 0x1000036a4 <__text+0x26a4>
100002690: 0f 2e c8                    	ucomiss	%xmm0, %xmm1
100002693: 72 22                       	jb	0x1000026b7 <__text+0x16b7>
100002695: 48 8d 35 5c 13 00 00        	leaq	0x135c(%rip), %rsi      ## 0x1000039f8 <__text+0x29f8>
10000269c: 6a 04                       	pushq	$0x4
10000269e: 41 5e                       	popq	%r14
1000026a0: 48 89 df                    	movq	%rbx, %rdi
1000026a3: 4c 89 f2                    	movq	%r14, %rdx
1000026a6: e8 c5 0f 00 00              	callq	0x100003670 <__text+0x2670>
1000026ab: 4c 89 f0                    	movq	%r14, %rax
1000026ae: 48 83 c4 30                 	addq	$0x30, %rsp
1000026b2: 5b                          	popq	%rbx
1000026b3: 41 5e                       	popq	%r14
1000026b5: 5d                          	popq	%rbp
1000026b6: c3                          	retq
1000026b7: 0f 57 c9                    	xorps	%xmm1, %xmm1
1000026ba: 0f 2e c1                    	ucomiss	%xmm1, %xmm0
1000026bd: 75 58                       	jne	0x100002717 <__text+0x1717>
1000026bf: 7a 56                       	jp	0x100002717 <__text+0x1717>
1000026c1: 45 85 f6                    	testl	%r14d, %r14d
1000026c4: 48 8d 05 32 13 00 00        	leaq	0x1332(%rip), %rax      ## 0x1000039fd <__text+0x29fd>
1000026cb: 48 8d 35 30 13 00 00        	leaq	0x1330(%rip), %rsi      ## 0x100003a02 <__text+0x2a02>
1000026d2: 48 0f 48 f0                 	cmovsq	%rax, %rsi
1000026d6: 41 c1 ee 1f                 	shrl	$0x1f, %r14d
1000026da: 49 83 c6 03                 	addq	$0x3, %r14
1000026de: eb c0                       	jmp	0x1000026a0 <__text+0x16a0>
1000026e0: 48 8d 7d e0                 	leaq	-0x20(%rbp), %rdi
1000026e4: 6a 34                       	pushq	$0x34
1000026e6: 5a                          	popq	%rdx
1000026e7: 6a 0b                       	pushq	$0xb
1000026e9: 59                          	popq	%rcx
1000026ea: 4c 89 f6                    	movq	%r14, %rsi
1000026ed: e8 8a 09 00 00              	callq	0x10000307c <__text+0x207c>
1000026f2: 48 8d 0d af 0f 00 00        	leaq	0xfaf(%rip), %rcx       ## 0x1000036a8 <__text+0x26a8>
1000026f9: 4c 8d 75 c8                 	leaq	-0x38(%rbp), %r14
1000026fd: 48 8d 55 e0                 	leaq	-0x20(%rbp), %rdx
100002701: 4c 89 f7                    	movq	%r14, %rdi
100002704: 48 89 de                    	movq	%rbx, %rsi
100002707: f6 05 aa 0f 00 00 01        	testb	$0x1, 0xfaa(%rip)       ## 0x1000036b8 <__text+0x26b8>
10000270e: 74 3e                       	je	0x10000274e <__text+0x174e>
100002710: e8 e6 00 00 00              	callq	0x1000027fb <__text+0x17fb>
100002715: eb 3c                       	jmp	0x100002753 <__text+0x1753>
100002717: 44 89 f6                    	movl	%r14d, %esi
10000271a: 48 8d 7d e0                 	leaq	-0x20(%rbp), %rdi
10000271e: 6a 17                       	pushq	$0x17
100002720: 5a                          	popq	%rdx
100002721: 6a 08                       	pushq	$0x8
100002723: 59                          	popq	%rcx
100002724: e8 53 09 00 00              	callq	0x10000307c <__text+0x207c>
100002729: 48 8d 0d 78 0f 00 00        	leaq	0xf78(%rip), %rcx       ## 0x1000036a8 <__text+0x26a8>
100002730: 4c 8d 75 c8                 	leaq	-0x38(%rbp), %r14
100002734: 48 8d 55 e0                 	leaq	-0x20(%rbp), %rdx
100002738: 4c 89 f7                    	movq	%r14, %rdi
10000273b: 48 89 de                    	movq	%rbx, %rsi
10000273e: f6 05 73 0f 00 00 01        	testb	$0x1, 0xf73(%rip)       ## 0x1000036b8 <__text+0x26b8>
100002745: 74 47                       	je	0x10000278e <__text+0x178e>
100002747: e8 af 00 00 00              	callq	0x1000027fb <__text+0x17fb>
10000274c: eb 45                       	jmp	0x100002793 <__text+0x1793>
10000274e: e8 6e 03 00 00              	callq	0x100002ac1 <__text+0x1ac1>
100002753: 66 41 83 7e 10 00           	cmpw	$0x0, 0x10(%r14)
100002759: 75 40                       	jne	0x10000279b <__text+0x179b>
10000275b: 49 8b 06                    	movq	(%r14), %rax
10000275e: 4d 8b 76 08                 	movq	0x8(%r14), %r14
100002762: 31 c9                       	xorl	%ecx, %ecx
100002764: 48 ba 01 00 80 00 00 00 80 00       	movabsq	$0x80000000800001, %rdx ## imm = 0x80000000800001
10000276e: 31 f6                       	xorl	%esi, %esi
100002770: 49 39 f6                    	cmpq	%rsi, %r14
100002773: 74 61                       	je	0x1000027d6 <__text+0x17d6>
100002775: 0f b6 3c 30                 	movzbl	(%rax,%rsi), %edi
100002779: 83 c7 d2                    	addl	$-0x2e, %edi
10000277c: 83 ff 37                    	cmpl	$0x37, %edi
10000277f: 77 08                       	ja	0x100002789 <__text+0x1789>
100002781: 48 0f a3 fa                 	btq	%rdi, %rdx
100002785: 73 02                       	jae	0x100002789 <__text+0x1789>
100002787: b1 01                       	movb	$0x1, %cl
100002789: 48 ff c6                    	incq	%rsi
10000278c: eb e2                       	jmp	0x100002770 <__text+0x1770>
10000278e: e8 2e 03 00 00              	callq	0x100002ac1 <__text+0x1ac1>
100002793: 66 41 83 7e 10 00           	cmpw	$0x0, 0x10(%r14)
100002799: 74 08                       	je	0x1000027a3 <__text+0x17a3>
10000279b: 45 31 f6                    	xorl	%r14d, %r14d
10000279e: e9 08 ff ff ff              	jmp	0x1000026ab <__text+0x16ab>
1000027a3: 49 8b 06                    	movq	(%r14), %rax
1000027a6: 4d 8b 76 08                 	movq	0x8(%r14), %r14
1000027aa: 31 c9                       	xorl	%ecx, %ecx
1000027ac: 48 ba 01 00 80 00 00 00 80 00       	movabsq	$0x80000000800001, %rdx ## imm = 0x80000000800001
1000027b6: 31 f6                       	xorl	%esi, %esi
1000027b8: 49 39 f6                    	cmpq	%rsi, %r14
1000027bb: 74 19                       	je	0x1000027d6 <__text+0x17d6>
1000027bd: 0f b6 3c 30                 	movzbl	(%rax,%rsi), %edi
1000027c1: 83 c7 d2                    	addl	$-0x2e, %edi
1000027c4: 83 ff 37                    	cmpl	$0x37, %edi
1000027c7: 77 08                       	ja	0x1000027d1 <__text+0x17d1>
1000027c9: 48 0f a3 fa                 	btq	%rdi, %rdx
1000027cd: 73 02                       	jae	0x1000027d1 <__text+0x17d1>
1000027cf: b1 01                       	movb	$0x1, %cl
1000027d1: 48 ff c6                    	incq	%rsi
1000027d4: eb e2                       	jmp	0x1000027b8 <__text+0x17b8>
1000027d6: f6 c1 01                    	testb	$0x1, %cl
1000027d9: 0f 85 cc fe ff ff           	jne	0x1000026ab <__text+0x16ab>
1000027df: 66 42 c7 04 33 2e 30        	movw	$0x302e, (%rbx,%r14)    ## imm = 0x302E
1000027e6: 49 83 c6 02                 	addq	$0x2, %r14
1000027ea: e9 bc fe ff ff              	jmp	0x1000026ab <__text+0x16ab>
1000027ef: 48 8d 35 fa 11 00 00        	leaq	0x11fa(%rip), %rsi      ## 0x1000039f0 <__text+0x29f0>
1000027f6: e9 89 fe ff ff              	jmp	0x100002684 <__text+0x1684>
1000027fb: 55                          	pushq	%rbp
1000027fc: 48 89 e5                    	movq	%rsp, %rbp
1000027ff: 41 57                       	pushq	%r15
100002801: 41 56                       	pushq	%r14
100002803: 41 55                       	pushq	%r13
100002805: 41 54                       	pushq	%r12
100002807: 53                          	pushq	%rbx
100002808: 48 83 ec 58                 	subq	$0x58, %rsp
10000280c: 49 89 cf                    	movq	%rcx, %r15
10000280f: 48 89 f1                    	movq	%rsi, %rcx
100002812: 48 89 fb                    	movq	%rdi, %rbx
100002815: 48 8b 3a                    	movq	(%rdx), %rdi
100002818: 44 8b 6a 08                 	movl	0x8(%rdx), %r13d
10000281c: 44 8a 72 0c                 	movb	0xc(%rdx), %r14b
100002820: 48 83 c2 0d                 	addq	$0xd, %rdx
100002824: 41 81 fd ff ff ff 7f        	cmpl	$0x7fffffff, %r13d      ## imm = 0x7FFFFFFF
10000282b: 75 38                       	jne	0x100002865 <__text+0x1865>
10000282d: 48 8d 75 a8                 	leaq	-0x58(%rbp), %rsi
100002831: 48 89 3e                    	movq	%rdi, (%rsi)
100002834: c7 46 08 ff ff ff 7f        	movl	$0x7fffffff, 0x8(%rsi)  ## imm = 0x7FFFFFFF
10000283b: 44 88 76 0c                 	movb	%r14b, 0xc(%rsi)
10000283f: 0f b7 02                    	movzwl	(%rdx), %eax
100002842: 66 89 46 0d                 	movw	%ax, 0xd(%rsi)
100002846: 8a 42 02                    	movb	0x2(%rdx), %al
100002849: 88 46 0f                    	movb	%al, 0xf(%rsi)
10000284c: 48 89 cf                    	movq	%rcx, %rdi
10000284f: e8 e8 07 00 00              	callq	0x10000303c <__text+0x203c>
100002854: 66 83 63 10 00              	andw	$0x0, 0x10(%rbx)
100002859: 48 89 03                    	movq	%rax, (%rbx)
10000285c: 48 89 53 08                 	movq	%rdx, 0x8(%rbx)
100002860: e9 4a 02 00 00              	jmp	0x100002aaf <__text+0x1aaf>
100002865: 48 89 4d d0                 	movq	%rcx, -0x30(%rbp)
100002869: 45 8a 67 08                 	movb	0x8(%r15), %r12b
10000286d: 45 84 e4                    	testb	%r12b, %r12b
100002870: 74 38                       	je	0x1000028aa <__text+0x18aa>
100002872: 49 8b 0f                    	movq	(%r15), %rcx
100002875: 48 8d 75 98                 	leaq	-0x68(%rbp), %rsi
100002879: 48 89 3e                    	movq	%rdi, (%rsi)
10000287c: 44 89 6e 08                 	movl	%r13d, 0x8(%rsi)
100002880: 44 88 76 0c                 	movb	%r14b, 0xc(%rsi)
100002884: 0f b7 02                    	movzwl	(%rdx), %eax
100002887: 66 89 46 0d                 	movw	%ax, 0xd(%rsi)
10000288b: 8a 42 02                    	movb	0x2(%rdx), %al
10000288e: 88 46 0f                    	movb	%al, 0xf(%rsi)
100002891: 4c 8d 75 88                 	leaq	-0x78(%rbp), %r14
100002895: 4c 89 f7                    	movq	%r14, %rdi
100002898: 31 d2                       	xorl	%edx, %edx
10000289a: e8 54 06 00 00              	callq	0x100002ef3 <__text+0x1ef3>
10000289f: 49 8b 3e                    	movq	(%r14), %rdi
1000028a2: 45 8b 6e 08                 	movl	0x8(%r14), %r13d
1000028a6: 45 8a 76 0c                 	movb	0xc(%r14), %r14b
1000028aa: 48 89 7d c8                 	movq	%rdi, -0x38(%rbp)
1000028ae: e8 36 05 00 00              	callq	0x100002de9 <__text+0x1de9>
1000028b3: 41 89 c0                    	movl	%eax, %r8d
1000028b6: 45 85 ed                    	testl	%r13d, %r13d
1000028b9: 78 12                       	js	0x1000028cd <__text+0x18cd>
1000028bb: 44 89 e9                    	movl	%r13d, %ecx
1000028be: 4a 8d 4c 01 02              	leaq	0x2(%rcx,%r8), %rcx
1000028c3: 45 84 e4                    	testb	%r12b, %r12b
1000028c6: 74 14                       	je	0x1000028dc <__text+0x18dc>
1000028c8: 49 8b 17                    	movq	(%r15), %rdx
1000028cb: eb 11                       	jmp	0x1000028de <__text+0x18de>
1000028cd: 89 c2                       	movl	%eax, %edx
1000028cf: 44 29 ea                    	subl	%r13d, %edx
1000028d2: 45 84 e4                    	testb	%r12b, %r12b
1000028d5: 74 0c                       	je	0x1000028e3 <__text+0x18e3>
1000028d7: 49 8b 0f                    	movq	(%r15), %rcx
1000028da: eb 09                       	jmp	0x1000028e5 <__text+0x18e5>
1000028dc: 31 d2                       	xorl	%edx, %edx
1000028de: 48 01 d1                    	addq	%rdx, %rcx
1000028e1: eb 0f                       	jmp	0x1000028f2 <__text+0x18f2>
1000028e3: 31 c9                       	xorl	%ecx, %ecx
1000028e5: 89 d2                       	movl	%edx, %edx
1000028e7: 48 39 ca                    	cmpq	%rcx, %rdx
1000028ea: 48 0f 47 ca                 	cmovaq	%rdx, %rcx
1000028ee: 48 83 c1 02                 	addq	$0x2, %rcx
1000028f2: 48 81 f9 5b 01 00 00        	cmpq	$0x15b, %rcx            ## imm = 0x15B
1000028f9: 76 16                       	jbe	0x100002911 <__text+0x1911>
1000028fb: 48 c7 43 10 66 00 00 00     	movq	$0x66, 0x10(%rbx)
100002903: 48 83 63 08 00              	andq	$0x0, 0x8(%rbx)
100002908: 48 83 23 00                 	andq	$0x0, (%rbx)
10000290c: e9 9e 01 00 00              	jmp	0x100002aaf <__text+0x1aaf>
100002911: 41 f6 c6 01                 	testb	$0x1, %r14b
100002915: 74 0c                       	je	0x100002923 <__text+0x1923>
100002917: 48 8b 4d d0                 	movq	-0x30(%rbp), %rcx
10000291b: c6 01 2d                    	movb	$0x2d, (%rcx)
10000291e: 6a 01                       	pushq	$0x1
100002920: 5a                          	popq	%rdx
100002921: eb 06                       	jmp	0x100002929 <__text+0x1929>
100002923: 31 d2                       	xorl	%edx, %edx
100002925: 48 8b 4d d0                 	movq	-0x30(%rbp), %rcx
100002929: 41 89 c6                    	movl	%eax, %r14d
10000292c: 45 01 ee                    	addl	%r13d, %r14d
10000292f: 4c 89 45 b8                 	movq	%r8, -0x48(%rbp)
100002933: 0f 8e 8a 00 00 00           	jle	0x1000029c3 <__text+0x19c3>
100002939: 45 89 f4                    	movl	%r14d, %r12d
10000293c: 41 39 c6                    	cmpl	%eax, %r14d
10000293f: 0f 83 f9 00 00 00           	jae	0x100002a3e <__text+0x1a3e>
100002945: 4a 8d 04 22                 	leaq	(%rdx,%r12), %rax
100002949: 48 8d 7c 01 01              	leaq	0x1(%rcx,%rax), %rdi
10000294e: 48 89 7d c0                 	movq	%rdi, -0x40(%rbp)
100002952: 4d 89 c6                    	movq	%r8, %r14
100002955: 4d 29 e6                    	subq	%r12, %r14
100002958: 48 8d 75 c8                 	leaq	-0x38(%rbp), %rsi
10000295c: 49 89 d5                    	movq	%rdx, %r13
10000295f: 4c 89 f2                    	movq	%r14, %rdx
100002962: e8 19 04 00 00              	callq	0x100002d80 <__text+0x1d80>
100002967: 48 8b 45 c0                 	movq	-0x40(%rbp), %rax
10000296b: c6 40 ff 2e                 	movb	$0x2e, -0x1(%rax)
10000296f: 48 8b 45 d0                 	movq	-0x30(%rbp), %rax
100002973: 4a 8d 3c 28                 	leaq	(%rax,%r13), %rdi
100002977: 48 8d 75 c8                 	leaq	-0x38(%rbp), %rsi
10000297b: 4c 89 e2                    	movq	%r12, %rdx
10000297e: e8 fd 03 00 00              	callq	0x100002d80 <__text+0x1d80>
100002983: 48 8b 45 b8                 	movq	-0x48(%rbp), %rax
100002987: 4a 8d 7c 28 01              	leaq	0x1(%rax,%r13), %rdi
10000298c: 41 80 7f 08 00              	cmpb	$0x0, 0x8(%r15)
100002991: 0f 84 05 01 00 00           	je	0x100002a9c <__text+0x1a9c>
100002997: 4f 8d 64 25 01              	leaq	0x1(%r13,%r12), %r12
10000299c: 4d 8b 3f                    	movq	(%r15), %r15
10000299f: 4c 89 fa                    	movq	%r15, %rdx
1000029a2: 4c 29 f2                    	subq	%r14, %rdx
1000029a5: 76 0c                       	jbe	0x1000029b3 <__text+0x19b3>
1000029a7: 48 03 7d d0                 	addq	-0x30(%rbp), %rdi
1000029ab: 6a 30                       	pushq	$0x30
1000029ad: 5e                          	popq	%rsi
1000029ae: e8 2e fc ff ff              	callq	0x1000025e1 <__text+0x15e1>
1000029b3: 4d 01 fc                    	addq	%r15, %r12
1000029b6: 49 83 ff 01                 	cmpq	$0x1, %r15
1000029ba: 49 83 dc 00                 	sbbq	$0x0, %r12
1000029be: e9 dc 00 00 00              	jmp	0x100002a9f <__text+0x1a9f>
1000029c3: 48 8d 7c 11 02              	leaq	0x2(%rcx,%rdx), %rdi
1000029c8: 66 c7 47 fe 30 2e           	movw	$0x2e30, -0x2(%rdi)     ## imm = 0x2E30
1000029ce: 41 f7 de                    	negl	%r14d
1000029d1: 49 89 d5                    	movq	%rdx, %r13
1000029d4: 6a 30                       	pushq	$0x30
1000029d6: 5e                          	popq	%rsi
1000029d7: 4c 89 f2                    	movq	%r14, %rdx
1000029da: e8 02 fc ff ff              	callq	0x1000025e1 <__text+0x15e1>
1000029df: 4f 8d 64 35 02              	leaq	0x2(%r13,%r14), %r12
1000029e4: 48 8b 45 d0                 	movq	-0x30(%rbp), %rax
1000029e8: 4a 8d 3c 20                 	leaq	(%rax,%r12), %rdi
1000029ec: 48 8d 75 c8                 	leaq	-0x38(%rbp), %rsi
1000029f0: 4c 8b 75 b8                 	movq	-0x48(%rbp), %r14
1000029f4: 4c 89 f2                    	movq	%r14, %rdx
1000029f7: e8 84 03 00 00              	callq	0x100002d80 <__text+0x1d80>
1000029fc: 4d 01 f4                    	addq	%r14, %r12
1000029ff: 41 80 7f 08 00              	cmpb	$0x0, 0x8(%r15)
100002a04: 0f 84 95 00 00 00           	je	0x100002a9f <__text+0x1a9f>
100002a0a: 49 83 cd 02                 	orq	$0x2, %r13
100002a0e: 4d 8b 37                    	movq	(%r15), %r14
100002a11: 4c 89 e0                    	movq	%r12, %rax
100002a14: 4c 29 e8                    	subq	%r13, %rax
100002a17: 4c 89 f2                    	movq	%r14, %rdx
100002a1a: 48 29 c2                    	subq	%rax, %rdx
100002a1d: 76 0f                       	jbe	0x100002a2e <__text+0x1a2e>
100002a1f: 4c 03 65 d0                 	addq	-0x30(%rbp), %r12
100002a23: 6a 30                       	pushq	$0x30
100002a25: 5e                          	popq	%rsi
100002a26: 4c 89 e7                    	movq	%r12, %rdi
100002a29: e8 b3 fb ff ff              	callq	0x1000025e1 <__text+0x15e1>
100002a2e: 4d 01 f5                    	addq	%r14, %r13
100002a31: 49 83 fe 01                 	cmpq	$0x1, %r14
100002a35: 49 83 dd 00                 	sbbq	$0x0, %r13
100002a39: 4d 89 ec                    	movq	%r13, %r12
100002a3c: eb 61                       	jmp	0x100002a9f <__text+0x1a9f>
100002a3e: 4c 8d 34 11                 	leaq	(%rcx,%rdx), %r14
100002a42: 48 89 55 c0                 	movq	%rdx, -0x40(%rbp)
100002a46: 48 8d 75 c8                 	leaq	-0x38(%rbp), %rsi
100002a4a: 4c 89 f7                    	movq	%r14, %rdi
100002a4d: 4c 89 c2                    	movq	%r8, %rdx
100002a50: e8 2b 03 00 00              	callq	0x100002d80 <__text+0x1d80>
100002a55: 49 63 d5                    	movslq	%r13d, %rdx
100002a58: 4c 03 75 b8                 	addq	-0x48(%rbp), %r14
100002a5c: 6a 30                       	pushq	$0x30
100002a5e: 5e                          	popq	%rsi
100002a5f: 4c 89 f7                    	movq	%r14, %rdi
100002a62: e8 7a fb ff ff              	callq	0x1000025e1 <__text+0x15e1>
100002a67: 4c 03 65 c0                 	addq	-0x40(%rbp), %r12
100002a6b: 41 80 7f 08 00              	cmpb	$0x0, 0x8(%r15)
100002a70: 74 2d                       	je	0x100002a9f <__text+0x1a9f>
100002a72: 4d 8b 37                    	movq	(%r15), %r14
100002a75: 4d 85 f6                    	testq	%r14, %r14
100002a78: 74 25                       	je	0x100002a9f <__text+0x1a9f>
100002a7a: 4c 8b 7d d0                 	movq	-0x30(%rbp), %r15
100002a7e: 4b 8d 7c 27 01              	leaq	0x1(%r15,%r12), %rdi
100002a83: c6 47 ff 2e                 	movb	$0x2e, -0x1(%rdi)
100002a87: 6a 30                       	pushq	$0x30
100002a89: 5e                          	popq	%rsi
100002a8a: 4c 89 f2                    	movq	%r14, %rdx
100002a8d: e8 4f fb ff ff              	callq	0x1000025e1 <__text+0x15e1>
100002a92: 4c 89 f8                    	movq	%r15, %rax
100002a95: 4f 8d 64 26 01              	leaq	0x1(%r14,%r12), %r12
100002a9a: eb 07                       	jmp	0x100002aa3 <__text+0x1aa3>
100002a9c: 49 89 fc                    	movq	%rdi, %r12
100002a9f: 48 8b 45 d0                 	movq	-0x30(%rbp), %rax
100002aa3: 66 83 63 10 00              	andw	$0x0, 0x10(%rbx)
100002aa8: 48 89 03                    	movq	%rax, (%rbx)
100002aab: 4c 89 63 08                 	movq	%r12, 0x8(%rbx)
100002aaf: 48 89 d8                    	movq	%rbx, %rax
100002ab2: 48 83 c4 58                 	addq	$0x58, %rsp
100002ab6: 5b                          	popq	%rbx
100002ab7: 41 5c                       	popq	%r12
100002ab9: 41 5d                       	popq	%r13
100002abb: 41 5e                       	popq	%r14
100002abd: 41 5f                       	popq	%r15
100002abf: 5d                          	popq	%rbp
100002ac0: c3                          	retq
100002ac1: 55                          	pushq	%rbp
100002ac2: 48 89 e5                    	movq	%rsp, %rbp
100002ac5: 41 57                       	pushq	%r15
100002ac7: 41 56                       	pushq	%r14
100002ac9: 41 55                       	pushq	%r13
100002acb: 41 54                       	pushq	%r12
100002acd: 53                          	pushq	%rbx
100002ace: 48 83 ec 58                 	subq	$0x58, %rsp
100002ad2: 49 89 cf                    	movq	%rcx, %r15
100002ad5: 48 89 f1                    	movq	%rsi, %rcx
100002ad8: 49 89 fd                    	movq	%rdi, %r13
100002adb: 48 8b 3a                    	movq	(%rdx), %rdi
100002ade: 8b 42 08                    	movl	0x8(%rdx), %eax
100002ae1: 8a 5a 0c                    	movb	0xc(%rdx), %bl
100002ae4: 48 83 c2 0d                 	addq	$0xd, %rdx
100002ae8: 3d ff ff ff 7f              	cmpl	$0x7fffffff, %eax       ## imm = 0x7FFFFFFF
100002aed: 75 39                       	jne	0x100002b28 <__text+0x1b28>
100002aef: 48 8d 75 a0                 	leaq	-0x60(%rbp), %rsi
100002af3: 48 89 3e                    	movq	%rdi, (%rsi)
100002af6: c7 46 08 ff ff ff 7f        	movl	$0x7fffffff, 0x8(%rsi)  ## imm = 0x7FFFFFFF
100002afd: 88 5e 0c                    	movb	%bl, 0xc(%rsi)
100002b00: 0f b7 02                    	movzwl	(%rdx), %eax
100002b03: 66 89 46 0d                 	movw	%ax, 0xd(%rsi)
100002b07: 8a 42 02                    	movb	0x2(%rdx), %al
100002b0a: 88 46 0f                    	movb	%al, 0xf(%rsi)
100002b0d: 48 89 cf                    	movq	%rcx, %rdi
100002b10: e8 27 05 00 00              	callq	0x10000303c <__text+0x203c>
100002b15: 66 41 83 65 10 00           	andw	$0x0, 0x10(%r13)
100002b1b: 49 89 45 00                 	movq	%rax, (%r13)
100002b1f: 49 89 55 08                 	movq	%rdx, 0x8(%r13)
100002b23: e9 36 02 00 00              	jmp	0x100002d5e <__text+0x1d5e>
100002b28: 45 8a 77 08                 	movb	0x8(%r15), %r14b
100002b2c: 45 84 f6                    	testb	%r14b, %r14b
100002b2f: 48 89 4d d0                 	movq	%rcx, -0x30(%rbp)
100002b33: 74 40                       	je	0x100002b75 <__text+0x1b75>
100002b35: 49 8b 0f                    	movq	(%r15), %rcx
100002b38: 48 8d 75 90                 	leaq	-0x70(%rbp), %rsi
100002b3c: 48 89 3e                    	movq	%rdi, (%rsi)
100002b3f: 89 46 08                    	movl	%eax, 0x8(%rsi)
100002b42: 88 5e 0c                    	movb	%bl, 0xc(%rsi)
100002b45: 0f b7 02                    	movzwl	(%rdx), %eax
100002b48: 66 89 46 0d                 	movw	%ax, 0xd(%rsi)
100002b4c: 8a 42 02                    	movb	0x2(%rdx), %al
100002b4f: 88 46 0f                    	movb	%al, 0xf(%rsi)
100002b52: 4c 8d 65 80                 	leaq	-0x80(%rbp), %r12
100002b56: 6a 01                       	pushq	$0x1
100002b58: 5a                          	popq	%rdx
100002b59: 4c 89 e7                    	movq	%r12, %rdi
100002b5c: e8 92 03 00 00              	callq	0x100002ef3 <__text+0x1ef3>
100002b61: 49 8b 3c 24                 	movq	(%r12), %rdi
100002b65: 41 8b 44 24 08              	movl	0x8(%r12), %eax
100002b6a: 48 89 45 c8                 	movq	%rax, -0x38(%rbp)
100002b6e: 41 8a 5c 24 0c              	movb	0xc(%r12), %bl
100002b73: eb 04                       	jmp	0x100002b79 <__text+0x1b79>
100002b75: 48 89 45 c8                 	movq	%rax, -0x38(%rbp)
100002b79: 48 89 7d b0                 	movq	%rdi, -0x50(%rbp)
100002b7d: e8 67 02 00 00              	callq	0x100002de9 <__text+0x1de9>
100002b82: 45 84 f6                    	testb	%r14b, %r14b
100002b85: 74 20                       	je	0x100002ba7 <__text+0x1ba7>
100002b87: 49 81 3f 54 01 00 00        	cmpq	$0x154, (%r15)          ## imm = 0x154
100002b8e: 72 17                       	jb	0x100002ba7 <__text+0x1ba7>
100002b90: 49 c7 45 10 66 00 00 00     	movq	$0x66, 0x10(%r13)
100002b98: 49 83 65 08 00              	andq	$0x0, 0x8(%r13)
100002b9d: 49 83 65 00 00              	andq	$0x0, (%r13)
100002ba2: e9 b7 01 00 00              	jmp	0x100002d5e <__text+0x1d5e>
100002ba7: 6a 01                       	pushq	$0x1
100002ba9: 59                          	popq	%rcx
100002baa: f6 c3 01                    	testb	$0x1, %bl
100002bad: 4c 89 6d c0                 	movq	%r13, -0x40(%rbp)
100002bb1: 74 0c                       	je	0x100002bbf <__text+0x1bbf>
100002bb3: 48 8b 55 d0                 	movq	-0x30(%rbp), %rdx
100002bb7: c6 02 2d                    	movb	$0x2d, (%rdx)
100002bba: 48 89 cb                    	movq	%rcx, %rbx
100002bbd: eb 06                       	jmp	0x100002bc5 <__text+0x1bc5>
100002bbf: 31 db                       	xorl	%ebx, %ebx
100002bc1: 48 8b 55 d0                 	movq	-0x30(%rbp), %rdx
100002bc5: 4c 8d 74 1a 02              	leaq	0x2(%rdx,%rbx), %r14
100002bca: 44 8d 68 ff                 	leal	-0x1(%rax), %r13d
100002bce: 4c 8d 65 b0                 	leaq	-0x50(%rbp), %r12
100002bd2: 4c 89 f7                    	movq	%r14, %rdi
100002bd5: 4c 89 e6                    	movq	%r12, %rsi
100002bd8: 48 89 45 b8                 	movq	%rax, -0x48(%rbp)
100002bdc: 4c 89 ea                    	movq	%r13, %rdx
100002bdf: e8 9c 01 00 00              	callq	0x100002d80 <__text+0x1d80>
100002be4: 49 8b 04 24                 	movq	(%r12), %rax
100002be8: 6a 0a                       	pushq	$0xa
100002bea: 41 5c                       	popq	%r12
100002bec: 31 d2                       	xorl	%edx, %edx
100002bee: 49 f7 f4                    	divq	%r12
100002bf1: 80 ca 30                    	orb	$0x30, %dl
100002bf4: 41 88 56 fe                 	movb	%dl, -0x2(%r14)
100002bf8: 48 8b 55 b8                 	movq	-0x48(%rbp), %rdx
100002bfc: 41 c6 46 ff 2e              	movb	$0x2e, -0x1(%r14)
100002c01: 48 8d 43 01                 	leaq	0x1(%rbx), %rax
100002c05: 83 fa 02                    	cmpl	$0x2, %edx
100002c08: 4e 8d 74 2b 02              	leaq	0x2(%rbx,%r13), %r14
100002c0d: 4c 0f 42 f0                 	cmovbq	%rax, %r14
100002c11: 41 80 7f 08 00              	cmpb	$0x0, 0x8(%r15)
100002c16: 74 4b                       	je	0x100002c63 <__text+0x1c63>
100002c18: 49 8b 07                    	movq	(%r15), %rax
100002c1b: 49 89 c7                    	movq	%rax, %r15
100002c1e: 4d 29 ef                    	subq	%r13, %r15
100002c21: 76 2e                       	jbe	0x100002c51 <__text+0x1c51>
100002c23: 31 c0                       	xorl	%eax, %eax
100002c25: 83 fa 01                    	cmpl	$0x1, %edx
100002c28: 0f 94 c0                    	sete	%al
100002c2b: 49 01 c6                    	addq	%rax, %r14
100002c2e: 48 8b 5d d0                 	movq	-0x30(%rbp), %rbx
100002c32: 4a 8d 3c 33                 	leaq	(%rbx,%r14), %rdi
100002c36: 6a 30                       	pushq	$0x30
100002c38: 5e                          	popq	%rsi
100002c39: 4c 89 fa                    	movq	%r15, %rdx
100002c3c: e8 a0 f9 ff ff              	callq	0x1000025e1 <__text+0x15e1>
100002c41: 48 8b 55 b8                 	movq	-0x48(%rbp), %rdx
100002c45: 49 89 db                    	movq	%rbx, %r11
100002c48: 4d 01 fe                    	addq	%r15, %r14
100002c4b: 4c 8b 6d c0                 	movq	-0x40(%rbp), %r13
100002c4f: eb 1a                       	jmp	0x100002c6b <__text+0x1c6b>
100002c51: 48 83 cb 02                 	orq	$0x2, %rbx
100002c55: 48 01 c3                    	addq	%rax, %rbx
100002c58: 48 83 f8 01                 	cmpq	$0x1, %rax
100002c5c: 48 83 db 00                 	sbbq	$0x0, %rbx
100002c60: 49 89 de                    	movq	%rbx, %r14
100002c63: 4c 8b 6d c0                 	movq	-0x40(%rbp), %r13
100002c67: 4c 8b 5d d0                 	movq	-0x30(%rbp), %r11
100002c6b: 48 8b 4d c8                 	movq	-0x38(%rbp), %rcx
100002c6f: 43 c6 04 33 65              	movb	$0x65, (%r11,%r14)
100002c74: 8d 04 0a                    	leal	(%rdx,%rcx), %eax
100002c77: 85 c0                       	testl	%eax, %eax
100002c79: 7e 09                       	jle	0x100002c84 <__text+0x1c84>
100002c7b: 49 ff c6                    	incq	%r14
100002c7e: 8d 4c 0a ff                 	leal	-0x1(%rdx,%rcx), %ecx
100002c82: eb 0f                       	jmp	0x100002c93 <__text+0x1c93>
100002c84: 6a 01                       	pushq	$0x1
100002c86: 59                          	popq	%rcx
100002c87: 43 c6 44 33 01 2d           	movb	$0x2d, 0x1(%r11,%r14)
100002c8d: 49 83 c6 02                 	addq	$0x2, %r14
100002c91: 29 c1                       	subl	%eax, %ecx
100002c93: 81 f9 ff c9 9a 3b           	cmpl	$0x3b9ac9ff, %ecx       ## imm = 0x3B9AC9FF
100002c99: 77 55                       	ja	0x100002cf0 <__text+0x1cf0>
100002c9b: 81 f9 ff e0 f5 05           	cmpl	$0x5f5e0ff, %ecx        ## imm = 0x5F5E0FF
100002ca1: 76 04                       	jbe	0x100002ca7 <__text+0x1ca7>
100002ca3: 6a 09                       	pushq	$0x9
100002ca5: eb 47                       	jmp	0x100002cee <__text+0x1cee>
100002ca7: 81 f9 7f 96 98 00           	cmpl	$0x98967f, %ecx         ## imm = 0x98967F
100002cad: 76 04                       	jbe	0x100002cb3 <__text+0x1cb3>
100002caf: 6a 08                       	pushq	$0x8
100002cb1: eb 3b                       	jmp	0x100002cee <__text+0x1cee>
100002cb3: 81 f9 3f 42 0f 00           	cmpl	$0xf423f, %ecx          ## imm = 0xF423F
100002cb9: 76 04                       	jbe	0x100002cbf <__text+0x1cbf>
100002cbb: 6a 07                       	pushq	$0x7
100002cbd: eb 2f                       	jmp	0x100002cee <__text+0x1cee>
100002cbf: 81 f9 9f 86 01 00           	cmpl	$0x1869f, %ecx          ## imm = 0x1869F
100002cc5: 76 04                       	jbe	0x100002ccb <__text+0x1ccb>
100002cc7: 6a 06                       	pushq	$0x6
100002cc9: eb 23                       	jmp	0x100002cee <__text+0x1cee>
100002ccb: 81 f9 0f 27 00 00           	cmpl	$0x270f, %ecx           ## imm = 0x270F
100002cd1: 76 04                       	jbe	0x100002cd7 <__text+0x1cd7>
100002cd3: 6a 05                       	pushq	$0x5
100002cd5: eb 17                       	jmp	0x100002cee <__text+0x1cee>
100002cd7: 81 f9 e7 03 00 00           	cmpl	$0x3e7, %ecx            ## imm = 0x3E7
100002cdd: 76 04                       	jbe	0x100002ce3 <__text+0x1ce3>
100002cdf: 6a 04                       	pushq	$0x4
100002ce1: eb 0b                       	jmp	0x100002cee <__text+0x1cee>
100002ce3: 83 f9 63                    	cmpl	$0x63, %ecx
100002ce6: 0f 86 84 00 00 00           	jbe	0x100002d70 <__text+0x1d70>
100002cec: 6a 03                       	pushq	$0x3
100002cee: 41 5c                       	popq	%r12
100002cf0: 4d 01 e6                    	addq	%r12, %r14
100002cf3: 4b 8d 74 33 ff              	leaq	-0x1(%r11,%r14), %rsi
100002cf8: 31 ff                       	xorl	%edi, %edi
100002cfa: 6a 64                       	pushq	$0x64
100002cfc: 41 58                       	popq	%r8
100002cfe: 41 b1 0a                    	movb	$0xa, %r9b
100002d01: 4c 8d 57 02                 	leaq	0x2(%rdi), %r10
100002d05: 4d 39 e2                    	cmpq	%r12, %r10
100002d08: 73 27                       	jae	0x100002d31 <__text+0x1d31>
100002d0a: 89 c8                       	movl	%ecx, %eax
100002d0c: 31 d2                       	xorl	%edx, %edx
100002d0e: 41 f7 f0                    	divl	%r8d
100002d11: 0f b6 d2                    	movzbl	%dl, %edx
100002d14: 89 c1                       	movl	%eax, %ecx
100002d16: 89 d0                       	movl	%edx, %eax
100002d18: 41 f6 f1                    	divb	%r9b
100002d1b: 0f b6 d4                    	movzbl	%ah, %edx
100002d1e: 0c 30                       	orb	$0x30, %al
100002d20: 80 ca 30                    	orb	$0x30, %dl
100002d23: 88 16                       	movb	%dl, (%rsi)
100002d25: 88 46 ff                    	movb	%al, -0x1(%rsi)
100002d28: 48 83 c6 fe                 	addq	$-0x2, %rsi
100002d2c: 4c 89 d7                    	movq	%r10, %rdi
100002d2f: eb d0                       	jmp	0x100002d01 <__text+0x1d01>
100002d31: 6a 0a                       	pushq	$0xa
100002d33: 41 58                       	popq	%r8
100002d35: 4c 39 e7                    	cmpq	%r12, %rdi
100002d38: 73 16                       	jae	0x100002d50 <__text+0x1d50>
100002d3a: 89 c8                       	movl	%ecx, %eax
100002d3c: 31 d2                       	xorl	%edx, %edx
100002d3e: 41 f7 f0                    	divl	%r8d
100002d41: 80 ca 30                    	orb	$0x30, %dl
100002d44: 88 16                       	movb	%dl, (%rsi)
100002d46: 48 ff c7                    	incq	%rdi
100002d49: 48 ff ce                    	decq	%rsi
100002d4c: 89 c1                       	movl	%eax, %ecx
100002d4e: eb e5                       	jmp	0x100002d35 <__text+0x1d35>
100002d50: 66 41 83 65 10 00           	andw	$0x0, 0x10(%r13)
100002d56: 4d 89 5d 00                 	movq	%r11, (%r13)
100002d5a: 4d 89 75 08                 	movq	%r14, 0x8(%r13)
100002d5e: 4c 89 e8                    	movq	%r13, %rax
100002d61: 48 83 c4 58                 	addq	$0x58, %rsp
100002d65: 5b                          	popq	%rbx
100002d66: 41 5c                       	popq	%r12
100002d68: 41 5d                       	popq	%r13
100002d6a: 41 5e                       	popq	%r14
100002d6c: 41 5f                       	popq	%r15
100002d6e: 5d                          	popq	%rbp
100002d6f: c3                          	retq
100002d70: 83 f9 0a                    	cmpl	$0xa, %ecx
100002d73: 6a 01                       	pushq	$0x1
100002d75: 41 5c                       	popq	%r12
100002d77: 49 83 dc ff                 	sbbq	$-0x1, %r12
100002d7b: e9 70 ff ff ff              	jmp	0x100002cf0 <__text+0x1cf0>
100002d80: 55                          	pushq	%rbp
100002d81: 48 89 e5                    	movq	%rsp, %rbp
100002d84: 48 89 d1                    	movq	%rdx, %rcx
100002d87: 48 8d 7c 3a ff              	leaq	-0x1(%rdx,%rdi), %rdi
100002d8c: 45 31 c0                    	xorl	%r8d, %r8d
100002d8f: 6a 64                       	pushq	$0x64
100002d91: 41 59                       	popq	%r9
100002d93: 41 b2 0a                    	movb	$0xa, %r10b
100002d96: 4d 8d 58 02                 	leaq	0x2(%r8), %r11
100002d9a: 49 39 cb                    	cmpq	%rcx, %r11
100002d9d: 73 27                       	jae	0x100002dc6 <__text+0x1dc6>
100002d9f: 48 8b 06                    	movq	(%rsi), %rax
100002da2: 31 d2                       	xorl	%edx, %edx
100002da4: 49 f7 f1                    	divq	%r9
100002da7: 48 89 06                    	movq	%rax, (%rsi)
100002daa: 0f b6 c2                    	movzbl	%dl, %eax
100002dad: 41 f6 f2                    	divb	%r10b
100002db0: 0f b6 d4                    	movzbl	%ah, %edx
100002db3: 0c 30                       	orb	$0x30, %al
100002db5: 80 ca 30                    	orb	$0x30, %dl
100002db8: 88 17                       	movb	%dl, (%rdi)
100002dba: 88 47 ff                    	movb	%al, -0x1(%rdi)
100002dbd: 48 83 c7 fe                 	addq	$-0x2, %rdi
100002dc1: 4d 89 d8                    	movq	%r11, %r8
100002dc4: eb d0                       	jmp	0x100002d96 <__text+0x1d96>
100002dc6: 6a 0a                       	pushq	$0xa
100002dc8: 41 59                       	popq	%r9
100002dca: 49 39 c8                    	cmpq	%rcx, %r8
100002dcd: 73 18                       	jae	0x100002de7 <__text+0x1de7>
100002dcf: 48 8b 06                    	movq	(%rsi), %rax
100002dd2: 31 d2                       	xorl	%edx, %edx
100002dd4: 49 f7 f1                    	divq	%r9
100002dd7: 48 89 06                    	movq	%rax, (%rsi)
100002dda: 80 ca 30                    	orb	$0x30, %dl
100002ddd: 88 17                       	movb	%dl, (%rdi)
100002ddf: 49 ff c0                    	incq	%r8
100002de2: 48 ff cf                    	decq	%rdi
100002de5: eb e3                       	jmp	0x100002dca <__text+0x1dca>
100002de7: 5d                          	popq	%rbp
100002de8: c3                          	retq
100002de9: 55                          	pushq	%rbp
100002dea: 48 89 e5                    	movq	%rsp, %rbp
100002ded: 48 b8 00 00 c1 6f f2 86 23 00       	movabsq	$0x2386f26fc10000, %rax ## imm = 0x2386F26FC10000
100002df7: 48 39 c7                    	cmpq	%rax, %rdi
100002dfa: 72 07                       	jb	0x100002e03 <__text+0x1e03>
100002dfc: 6a 11                       	pushq	$0x11
100002dfe: e9 e1 00 00 00              	jmp	0x100002ee4 <__text+0x1ee4>
100002e03: 48 b8 ff 7f c6 a4 7e 8d 03 00       	movabsq	$0x38d7ea4c67fff, %rax ## imm = 0x38D7EA4C67FFF
100002e0d: 48 39 c7                    	cmpq	%rax, %rdi
100002e10: 76 07                       	jbe	0x100002e19 <__text+0x1e19>
100002e12: 6a 10                       	pushq	$0x10
100002e14: e9 cb 00 00 00              	jmp	0x100002ee4 <__text+0x1ee4>
100002e19: 48 b8 ff 3f 7a 10 f3 5a 00 00       	movabsq	$0x5af3107a3fff, %rax ## imm = 0x5AF3107A3FFF
100002e23: 48 39 c7                    	cmpq	%rax, %rdi
100002e26: 76 07                       	jbe	0x100002e2f <__text+0x1e2f>
100002e28: 6a 0f                       	pushq	$0xf
100002e2a: e9 b5 00 00 00              	jmp	0x100002ee4 <__text+0x1ee4>
100002e2f: 48 89 f8                    	movq	%rdi, %rax
100002e32: 48 c1 e8 0d                 	shrq	$0xd, %rax
100002e36: 48 3d 94 73 c2 48           	cmpq	$0x48c27394, %rax       ## imm = 0x48C27394
100002e3c: 76 07                       	jbe	0x100002e45 <__text+0x1e45>
100002e3e: 6a 0e                       	pushq	$0xe
100002e40: e9 9f 00 00 00              	jmp	0x100002ee4 <__text+0x1ee4>
100002e45: 48 89 f8                    	movq	%rdi, %rax
100002e48: 48 c1 e8 0c                 	shrq	$0xc, %rax
100002e4c: 48 3d 50 4a 8d 0e           	cmpq	$0xe8d4a50, %rax        ## imm = 0xE8D4A50
100002e52: 76 07                       	jbe	0x100002e5b <__text+0x1e5b>
100002e54: 6a 0d                       	pushq	$0xd
100002e56: e9 89 00 00 00              	jmp	0x100002ee4 <__text+0x1ee4>
100002e5b: 48 89 f8                    	movq	%rdi, %rax
100002e5e: 48 c1 e8 0b                 	shrq	$0xb, %rax
100002e62: 48 3d dc 0e e9 02           	cmpq	$0x2e90edc, %rax        ## imm = 0x2E90EDC
100002e68: 76 04                       	jbe	0x100002e6e <__text+0x1e6e>
100002e6a: 6a 0c                       	pushq	$0xc
100002e6c: eb 76                       	jmp	0x100002ee4 <__text+0x1ee4>
100002e6e: 48 89 f8                    	movq	%rdi, %rax
100002e71: 48 c1 e8 0a                 	shrq	$0xa, %rax
100002e75: 48 3d f8 02 95 00           	cmpq	$0x9502f8, %rax         ## imm = 0x9502F8
100002e7b: 76 04                       	jbe	0x100002e81 <__text+0x1e81>
100002e7d: 6a 0b                       	pushq	$0xb
100002e7f: eb 63                       	jmp	0x100002ee4 <__text+0x1ee4>
100002e81: 48 81 ff ff c9 9a 3b        	cmpq	$0x3b9ac9ff, %rdi       ## imm = 0x3B9AC9FF
100002e88: 76 04                       	jbe	0x100002e8e <__text+0x1e8e>
100002e8a: 6a 0a                       	pushq	$0xa
100002e8c: eb 56                       	jmp	0x100002ee4 <__text+0x1ee4>
100002e8e: 48 81 ff ff e0 f5 05        	cmpq	$0x5f5e0ff, %rdi        ## imm = 0x5F5E0FF
100002e95: 76 04                       	jbe	0x100002e9b <__text+0x1e9b>
100002e97: 6a 09                       	pushq	$0x9
100002e99: eb 49                       	jmp	0x100002ee4 <__text+0x1ee4>
100002e9b: 48 81 ff 7f 96 98 00        	cmpq	$0x98967f, %rdi         ## imm = 0x98967F
100002ea2: 76 04                       	jbe	0x100002ea8 <__text+0x1ea8>
100002ea4: 6a 08                       	pushq	$0x8
100002ea6: eb 3c                       	jmp	0x100002ee4 <__text+0x1ee4>
100002ea8: 48 81 ff 3f 42 0f 00        	cmpq	$0xf423f, %rdi          ## imm = 0xF423F
100002eaf: 76 04                       	jbe	0x100002eb5 <__text+0x1eb5>
100002eb1: 6a 07                       	pushq	$0x7
100002eb3: eb 2f                       	jmp	0x100002ee4 <__text+0x1ee4>
100002eb5: 48 81 ff 9f 86 01 00        	cmpq	$0x1869f, %rdi          ## imm = 0x1869F
100002ebc: 76 04                       	jbe	0x100002ec2 <__text+0x1ec2>
100002ebe: 6a 06                       	pushq	$0x6
100002ec0: eb 22                       	jmp	0x100002ee4 <__text+0x1ee4>
100002ec2: 48 81 ff 0f 27 00 00        	cmpq	$0x270f, %rdi           ## imm = 0x270F
100002ec9: 76 04                       	jbe	0x100002ecf <__text+0x1ecf>
100002ecb: 6a 05                       	pushq	$0x5
100002ecd: eb 15                       	jmp	0x100002ee4 <__text+0x1ee4>
100002ecf: 48 81 ff e7 03 00 00        	cmpq	$0x3e7, %rdi            ## imm = 0x3E7
100002ed6: 76 04                       	jbe	0x100002edc <__text+0x1edc>
100002ed8: 6a 04                       	pushq	$0x4
100002eda: eb 08                       	jmp	0x100002ee4 <__text+0x1ee4>
100002edc: 48 83 ff 63                 	cmpq	$0x63, %rdi
100002ee0: 76 05                       	jbe	0x100002ee7 <__text+0x1ee7>
100002ee2: 6a 03                       	pushq	$0x3
100002ee4: 58                          	popq	%rax
100002ee5: 5d                          	popq	%rbp
100002ee6: c3                          	retq
100002ee7: 48 83 ff 0a                 	cmpq	$0xa, %rdi
100002eeb: 6a 01                       	pushq	$0x1
100002eed: 58                          	popq	%rax
100002eee: 83 d8 ff                    	sbbl	$-0x1, %eax
100002ef1: eb f2                       	jmp	0x100002ee5 <__text+0x1ee5>
100002ef3: 55                          	pushq	%rbp
100002ef4: 48 89 e5                    	movq	%rsp, %rbp
100002ef7: 41 57                       	pushq	%r15
100002ef9: 41 56                       	pushq	%r14
100002efb: 41 55                       	pushq	%r13
100002efd: 41 54                       	pushq	%r12
100002eff: 53                          	pushq	%rbx
100002f00: 48 83 ec 28                 	subq	$0x28, %rsp
100002f04: 49 89 cc                    	movq	%rcx, %r12
100002f07: 41 89 d7                    	movl	%edx, %r15d
100002f0a: 48 89 7d c0                 	movq	%rdi, -0x40(%rbp)
100002f0e: 4c 8b 36                    	movq	(%rsi), %r14
100002f11: 44 8b 6e 08                 	movl	0x8(%rsi), %r13d
100002f15: 44 89 e8                    	movl	%r13d, %eax
100002f18: 48 89 45 c8                 	movq	%rax, -0x38(%rbp)
100002f1c: 8a 5e 0c                    	movb	0xc(%rsi), %bl
100002f1f: 4c 89 f7                    	movq	%r14, %rdi
100002f22: e8 c2 fe ff ff              	callq	0x100002de9 <__text+0x1de9>
100002f27: 89 c1                       	movl	%eax, %ecx
100002f29: 41 f6 c7 01                 	testb	$0x1, %r15b
100002f2d: 74 05                       	je	0x100002f34 <__text+0x1f34>
100002f2f: 49 ff c4                    	incq	%r12
100002f32: eb 24                       	jmp	0x100002f58 <__text+0x1f58>
100002f34: 45 85 ed                    	testl	%r13d, %r13d
100002f37: 7e 0e                       	jle	0x100002f47 <__text+0x1f47>
100002f39: ff c8                       	decl	%eax
100002f3b: 48 8b 7d c8                 	movq	-0x38(%rbp), %rdi
100002f3f: 49 01 fc                    	addq	%rdi, %r12
100002f42: 49 01 c4                    	addq	%rax, %r12
100002f45: eb 15                       	jmp	0x100002f5c <__text+0x1f5c>
100002f47: 44 89 e8                    	movl	%r13d, %eax
100002f4a: f7 d8                       	negl	%eax
100002f4c: 49 01 cc                    	addq	%rcx, %r12
100002f4f: 31 d2                       	xorl	%edx, %edx
100002f51: 49 29 c4                    	subq	%rax, %r12
100002f54: 4c 0f 42 e2                 	cmovbq	%rdx, %r12
100002f58: 48 8b 7d c8                 	movq	-0x38(%rbp), %rdi
100002f5c: 49 29 cc                    	subq	%rcx, %r12
100002f5f: 0f 83 98 00 00 00           	jae	0x100002ffd <__text+0x1ffd>
100002f65: 88 5d d7                    	movb	%bl, -0x29(%rbp)
100002f68: 49 ff c4                    	incq	%r12
100002f6b: 31 db                       	xorl	%ebx, %ebx
100002f6d: 6a 0a                       	pushq	$0xa
100002f6f: 41 5f                       	popq	%r15
100002f71: 49 39 dc                    	cmpq	%rbx, %r12
100002f74: 74 10                       	je	0x100002f86 <__text+0x1f86>
100002f76: 4c 89 f0                    	movq	%r14, %rax
100002f79: 31 d2                       	xorl	%edx, %edx
100002f7b: 49 f7 f7                    	divq	%r15
100002f7e: 48 ff cb                    	decq	%rbx
100002f81: 49 89 c6                    	movq	%rax, %r14
100002f84: eb eb                       	jmp	0x100002f71 <__text+0x1f71>
100002f86: 4c 89 f0                    	movq	%r14, %rax
100002f89: 31 d2                       	xorl	%edx, %edx
100002f8b: 49 f7 f7                    	divq	%r15
100002f8e: 48 29 df                    	subq	%rbx, %rdi
100002f91: 48 83 fa 04                 	cmpq	$0x4, %rdx
100002f95: 76 60                       	jbe	0x100002ff7 <__text+0x1ff7>
100002f97: 48 89 c1                    	movq	%rax, %rcx
100002f9a: 48 89 7d c8                 	movq	%rdi, -0x38(%rbp)
100002f9e: 44 89 6d bc                 	movl	%r13d, -0x44(%rbp)
100002fa2: 48 ff c1                    	incq	%rcx
100002fa5: 49 89 ce                    	movq	%rcx, %r14
100002fa8: 31 f6                       	xorl	%esi, %esi
100002faa: 49 89 f4                    	movq	%rsi, %r12
100002fad: 49 89 cd                    	movq	%rcx, %r13
100002fb0: 48 89 cf                    	movq	%rcx, %rdi
100002fb3: 4c 89 fa                    	movq	%r15, %rdx
100002fb6: 31 c9                       	xorl	%ecx, %ecx
100002fb8: e8 59 f5 ff ff              	callq	0x100002516 <__text+0x1516>
100002fbd: 48 89 c1                    	movq	%rax, %rcx
100002fc0: 48 89 d6                    	movq	%rdx, %rsi
100002fc3: 49 f7 e7                    	mulq	%r15
100002fc6: 48 6b fe 0a                 	imulq	$0xa, %rsi, %rdi
100002fca: 48 01 d7                    	addq	%rdx, %rdi
100002fcd: 4c 89 ea                    	movq	%r13, %rdx
100002fd0: 48 29 c2                    	subq	%rax, %rdx
100002fd3: 4c 89 e0                    	movq	%r12, %rax
100002fd6: 48 19 f8                    	sbbq	%rdi, %rax
100002fd9: 4c 89 ef                    	movq	%r13, %rdi
100002fdc: 4c 09 e7                    	orq	%r12, %rdi
100002fdf: 74 05                       	je	0x100002fe6 <__text+0x1fe6>
100002fe1: 48 09 c2                    	orq	%rax, %rdx
100002fe4: 74 c4                       	je	0x100002faa <__text+0x1faa>
100002fe6: 4d 09 e5                    	orq	%r12, %r13
100002fe9: 74 18                       	je	0x100003003 <__text+0x2003>
100002feb: 48 8b 45 c8                 	movq	-0x38(%rbp), %rax
100002fef: 48 ff c0                    	incq	%rax
100002ff2: 41 89 c5                    	movl	%eax, %r13d
100002ff5: eb 22                       	jmp	0x100003019 <__text+0x2019>
100002ff7: 41 89 fd                    	movl	%edi, %r13d
100002ffa: 8a 5d d7                    	movb	-0x29(%rbp), %bl
100002ffd: 48 8b 45 c0                 	movq	-0x40(%rbp), %rax
100003001: eb 1d                       	jmp	0x100003020 <__text+0x2020>
100003003: 4c 89 f0                    	movq	%r14, %rax
100003006: 31 d2                       	xorl	%edx, %edx
100003008: 49 f7 f7                    	divq	%r15
10000300b: 44 8b 6d bc                 	movl	-0x44(%rbp), %r13d
10000300f: 41 29 dd                    	subl	%ebx, %r13d
100003012: 41 83 c5 02                 	addl	$0x2, %r13d
100003016: 49 89 c6                    	movq	%rax, %r14
100003019: 48 8b 45 c0                 	movq	-0x40(%rbp), %rax
10000301d: 8a 5d d7                    	movb	-0x29(%rbp), %bl
100003020: 4c 89 30                    	movq	%r14, (%rax)
100003023: 44 89 68 08                 	movl	%r13d, 0x8(%rax)
100003027: 80 e3 01                    	andb	$0x1, %bl
10000302a: 88 58 0c                    	movb	%bl, 0xc(%rax)
10000302d: 48 83 c4 28                 	addq	$0x28, %rsp
100003031: 5b                          	popq	%rbx
100003032: 41 5c                       	popq	%r12
100003034: 41 5d                       	popq	%r13
100003036: 41 5e                       	popq	%r14
100003038: 41 5f                       	popq	%r15
10000303a: 5d                          	popq	%rbp
10000303b: c3                          	retq
10000303c: 55                          	pushq	%rbp
10000303d: 48 89 e5                    	movq	%rsp, %rbp
100003040: 48 89 f8                    	movq	%rdi, %rax
100003043: 48 8b 0e                    	movq	(%rsi), %rcx
100003046: 0f b6 56 0c                 	movzbl	0xc(%rsi), %edx
10000304a: f6 c2 01                    	testb	$0x1, %dl
10000304d: 74 03                       	je	0x100003052 <__text+0x2052>
10000304f: c6 00 2d                    	movb	$0x2d, (%rax)
100003052: 89 d6                       	movl	%edx, %esi
100003054: 83 e6 01                    	andl	$0x1, %esi
100003057: 48 01 c6                    	addq	%rax, %rsi
10000305a: 48 85 c9                    	testq	%rcx, %rcx
10000305d: 74 0b                       	je	0x10000306a <__text+0x206a>
10000305f: c6 46 02 6e                 	movb	$0x6e, 0x2(%rsi)
100003063: 66 c7 06 6e 61              	movw	$0x616e, (%rsi)         ## imm = 0x616E
100003068: eb 09                       	jmp	0x100003073 <__text+0x2073>
10000306a: c6 46 02 66                 	movb	$0x66, 0x2(%rsi)
10000306e: 66 c7 06 69 6e              	movw	$0x6e69, (%rsi)         ## imm = 0x6E69
100003073: 83 e2 01                    	andl	$0x1, %edx
100003076: 48 83 c2 03                 	addq	$0x3, %rdx
10000307a: 5d                          	popq	%rbp
10000307b: c3                          	retq
10000307c: 55                          	pushq	%rbp
10000307d: 48 89 e5                    	movq	%rsp, %rbp
100003080: 41 57                       	pushq	%r15
100003082: 41 56                       	pushq	%r14
100003084: 41 55                       	pushq	%r13
100003086: 41 54                       	pushq	%r12
100003088: 53                          	pushq	%rbx
100003089: 48 81 ec 88 00 00 00        	subq	$0x88, %rsp
100003090: 41 89 cb                    	movl	%ecx, %r11d
100003093: 41 89 d2                    	movl	%edx, %r10d
100003096: 48 89 f8                    	movq	%rdi, %rax
100003099: 41 8d 4b ff                 	leal	-0x1(%r11), %ecx
10000309d: 6a ff                       	pushq	$-0x1
10000309f: 41 58                       	popq	%r8
1000030a1: 45 89 c4                    	movl	%r8d, %r12d
1000030a4: 41 d3 e4                    	shll	%cl, %r12d
1000030a7: 6a 01                       	pushq	$0x1
1000030a9: 5b                          	popq	%rbx
1000030aa: 44 89 d1                    	movl	%r10d, %ecx
1000030ad: 48 d3 e3                    	shlq	%cl, %rbx
1000030b0: 4c 8d 4b ff                 	leaq	-0x1(%rbx), %r9
1000030b4: 49 21 f1                    	andq	%rsi, %r9
1000030b7: 48 89 f2                    	movq	%rsi, %rdx
1000030ba: 48 d3 ea                    	shrq	%cl, %rdx
1000030bd: 44 89 c7                    	movl	%r8d, %edi
1000030c0: 44 89 d9                    	movl	%r11d, %ecx
1000030c3: d3 e7                       	shll	%cl, %edi
1000030c5: f7 d7                       	notl	%edi
1000030c7: 21 fa                       	andl	%edi, %edx
1000030c9: 48 89 d1                    	movq	%rdx, %rcx
1000030cc: 4c 09 c9                    	orq	%r9, %rcx
1000030cf: 75 0d                       	jne	0x1000030de <__text+0x20de>
1000030d1: 48 83 20 00                 	andq	$0x0, (%rax)
1000030d5: 83 60 08 00                 	andl	$0x0, 0x8(%rax)
1000030d9: e9 0b 05 00 00              	jmp	0x1000035e9 <__text+0x25e9>
1000030de: 44 89 d9                    	movl	%r11d, %ecx
1000030e1: 41 d3 e0                    	shll	%cl, %r8d
1000030e4: 41 31 d0                    	xorl	%edx, %r8d
1000030e7: 41 83 f8 ff                 	cmpl	$-0x1, %r8d
1000030eb: 74 24                       	je	0x100003111 <__text+0x2111>
1000030ed: 41 0f b6 ca                 	movzbl	%r10b, %ecx
1000030f1: 83 e1 3f                    	andl	$0x3f, %ecx
1000030f4: 48 85 d2                    	testq	%rdx, %rdx
1000030f7: 48 89 85 78 ff ff ff        	movq	%rax, -0x88(%rbp)
1000030fe: 48 89 75 80                 	movq	%rsi, -0x80(%rbp)
100003102: 74 1c                       	je	0x100003120 <__text+0x2120>
100003104: f7 d1                       	notl	%ecx
100003106: 41 01 cc                    	addl	%ecx, %r12d
100003109: 41 01 d4                    	addl	%edx, %r12d
10000310c: 4c 09 cb                    	orq	%r9, %rbx
10000310f: eb 15                       	jmp	0x100003126 <__text+0x2126>
100003111: 4c 89 08                    	movq	%r9, (%rax)
100003114: c7 40 08 ff ff ff 7f        	movl	$0x7fffffff, 0x8(%rax)  ## imm = 0x7FFFFFFF
10000311b: e9 c9 04 00 00              	jmp	0x1000035e9 <__text+0x25e9>
100003120: 41 29 cc                    	subl	%ecx, %r12d
100003123: 4c 89 cb                    	movq	%r9, %rbx
100003126: 4c 89 5d b8                 	movq	%r11, -0x48(%rbp)
10000312a: 44 89 55 94                 	movl	%r10d, -0x6c(%rbp)
10000312e: 48 85 d2                    	testq	%rdx, %rdx
100003131: 0f 94 c1                    	sete	%cl
100003134: 49 b8 1b cd 4b 78 9a 94 00 00       	movabsq	$0x949a784bcd1b, %r8 ## imm = 0x949A784BCD1B
10000313e: 48 8d 3c 9d 00 00 00 00     	leaq	(,%rbx,4), %rdi
100003146: 4d 85 c9                    	testq	%r9, %r9
100003149: 0f 95 c0                    	setne	%al
10000314c: 08 c8                       	orb	%cl, %al
10000314e: 45 85 e4                    	testl	%r12d, %r12d
100003151: 48 89 5d c0                 	movq	%rbx, -0x40(%rbp)
100003155: 88 45 d7                    	movb	%al, -0x29(%rbp)
100003158: 78 71                       	js	0x1000031cb <__text+0x21cb>
10000315a: 44 89 e0                    	movl	%r12d, %eax
10000315d: 48 b9 cf fb 84 9a 20 9a 00 00       	movabsq	$0x9a209a84fbcf, %rcx ## imm = 0x9A209A84FBCF
100003167: 48 0f af c8                 	imulq	%rax, %rcx
10000316b: 48 c1 e9 31                 	shrq	$0x31, %rcx
10000316f: 41 83 fc 04                 	cmpl	$0x4, %r12d
100003173: 83 d1 ff                    	adcl	$-0x1, %ecx
100003176: 49 89 c9                    	movq	%rcx, %r9
100003179: 4d 0f af c8                 	imulq	%r8, %r9
10000317d: 49 c1 e9 2e                 	shrq	$0x2e, %r9
100003181: 89 c8                       	movl	%ecx, %eax
100003183: 44 29 e0                    	subl	%r12d, %eax
100003186: 49 89 cc                    	movq	%rcx, %r12
100003189: 42 8d 44 08 7d              	leal	0x7d(%rax,%r9), %eax
10000318e: 89 45 b0                    	movl	%eax, -0x50(%rbp)
100003191: 8d 41 19                    	leal	0x19(%rcx), %eax
100003194: 66 b9 1a 00                 	movw	$0x1a, %cx
100003198: 31 d2                       	xorl	%edx, %edx
10000319a: 66 f7 f1                    	divw	%cx
10000319d: 0f b7 c0                    	movzwl	%ax, %eax
1000031a0: 44 6b d0 1a                 	imull	$0x1a, %eax, %r10d
1000031a4: c1 e0 04                    	shll	$0x4, %eax
1000031a7: 4c 8d 1d 82 06 00 00        	leaq	0x682(%rip), %r11       ## 0x100003830 <__text+0x2830>
1000031ae: 49 01 c3                    	addq	%rax, %r11
1000031b1: 44 89 d0                    	movl	%r10d, %eax
1000031b4: 44 29 e0                    	subl	%r12d, %eax
1000031b7: 4c 89 65 98                 	movq	%r12, -0x68(%rbp)
1000031bb: 0f 85 80 00 00 00           	jne	0x100003241 <__text+0x2241>
1000031c1: f3 41 0f 6f 03              	movdqu	(%r11), %xmm0
1000031c6: e9 1c 01 00 00              	jmp	0x1000032e7 <__text+0x22e7>
1000031cb: 45 89 e6                    	movl	%r12d, %r14d
1000031ce: 41 f7 de                    	negl	%r14d
1000031d1: 48 be 18 82 bd b2 ef b2 00 00       	movabsq	$0xb2efb2bd8218, %rsi ## imm = 0xB2EFB2BD8218
1000031db: 49 0f af f6                 	imulq	%r14, %rsi
1000031df: 48 c1 ee 30                 	shrq	$0x30, %rsi
1000031e3: 31 c0                       	xorl	%eax, %eax
1000031e5: 41 83 fc ff                 	cmpl	$-0x1, %r12d
1000031e9: 0f 95 c0                    	setne	%al
1000031ec: 29 c6                       	subl	%eax, %esi
1000031ee: 41 29 f6                    	subl	%esi, %r14d
1000031f1: 4d 89 f1                    	movq	%r14, %r9
1000031f4: 4d 0f af c8                 	imulq	%r8, %r9
1000031f8: 49 c1 e9 2e                 	shrq	$0x2e, %r9
1000031fc: 89 f0                       	movl	%esi, %eax
1000031fe: 44 29 c8                    	subl	%r9d, %eax
100003201: 83 c0 7c                    	addl	$0x7c, %eax
100003204: 89 45 98                    	movl	%eax, -0x68(%rbp)
100003207: 66 b9 1a 00                 	movw	$0x1a, %cx
10000320b: 44 89 f0                    	movl	%r14d, %eax
10000320e: 31 d2                       	xorl	%edx, %edx
100003210: 66 f7 f1                    	divw	%cx
100003213: 0f b7 c0                    	movzwl	%ax, %eax
100003216: 44 6b d0 1a                 	imull	$0x1a, %eax, %r10d
10000321a: c1 e0 04                    	shll	$0x4, %eax
10000321d: 4c 8d 1d fc 06 00 00        	leaq	0x6fc(%rip), %r11       ## 0x100003920 <__text+0x2920>
100003224: 49 01 c3                    	addq	%rax, %r11
100003227: 44 89 f0                    	movl	%r14d, %eax
10000322a: 44 29 d0                    	subl	%r10d, %eax
10000322d: 48 89 75 b0                 	movq	%rsi, -0x50(%rbp)
100003231: 0f 85 5c 01 00 00           	jne	0x100003393 <__text+0x2393>
100003237: f3 41 0f 6f 03              	movdqu	(%r11), %xmm0
10000323c: e9 fc 01 00 00              	jmp	0x10000343d <__text+0x243d>
100003241: 48 8d 0d 78 04 00 00        	leaq	0x478(%rip), %rcx       ## 0x1000036c0 <__text+0x26c0>
100003248: 48 8b 0c c1                 	movq	(%rcx,%rax,8), %rcx
10000324c: 49 8b 03                    	movq	(%r11), %rax
10000324f: 48 ff c8                    	decq	%rax
100003252: 48 f7 e1                    	mulq	%rcx
100003255: 48 89 d6                    	movq	%rdx, %rsi
100003258: 48 89 7d c8                 	movq	%rdi, -0x38(%rbp)
10000325c: 48 89 c7                    	movq	%rax, %rdi
10000325f: 48 89 c8                    	movq	%rcx, %rax
100003262: 49 f7 63 08                 	mulq	0x8(%r11)
100003266: 48 89 45 a0                 	movq	%rax, -0x60(%rbp)
10000326a: 48 89 55 a8                 	movq	%rdx, -0x58(%rbp)
10000326e: 44 89 d0                    	movl	%r10d, %eax
100003271: 49 0f af c0                 	imulq	%r8, %rax
100003275: 48 c1 e8 2e                 	shrq	$0x2e, %rax
100003279: 44 29 c8                    	subl	%r9d, %eax
10000327c: 43 8d 1c 24                 	leal	(%r12,%r12), %ebx
100003280: 44 0f b6 f8                 	movzbl	%al, %r15d
100003284: 44 89 fa                    	movl	%r15d, %edx
100003287: e8 fc f1 ff ff              	callq	0x100002488 <__text+0x1488>
10000328c: 49 89 c6                    	movq	%rax, %r14
10000328f: 49 89 d5                    	movq	%rdx, %r13
100003292: b0 40                       	movb	$0x40, %al
100003294: 44 28 f8                    	subb	%r15b, %al
100003297: 24 7f                       	andb	$0x7f, %al
100003299: 0f b6 d0                    	movzbl	%al, %edx
10000329c: 48 8b 7d a0                 	movq	-0x60(%rbp), %rdi
1000032a0: 48 8b 75 a8                 	movq	-0x58(%rbp), %rsi
1000032a4: e8 26 f2 ff ff              	callq	0x1000024cf <__text+0x14cf>
1000032a9: 48 8b 7d c8                 	movq	-0x38(%rbp), %rdi
1000032ad: 44 89 e1                    	movl	%r12d, %ecx
1000032b0: c1 e9 04                    	shrl	$0x4, %ecx
1000032b3: 48 8d 35 2a 05 00 00        	leaq	0x52a(%rip), %rsi       ## 0x1000037e4 <__text+0x27e4>
1000032ba: 8b 34 8e                    	movl	(%rsi,%rcx,4), %esi
1000032bd: 89 d9                       	movl	%ebx, %ecx
1000032bf: d3 ee                       	shrl	%cl, %esi
1000032c1: 83 e6 03                    	andl	$0x3, %esi
1000032c4: 4c 01 f0                    	addq	%r14, %rax
1000032c7: 4c 11 ea                    	adcq	%r13, %rdx
1000032ca: 48 01 f0                    	addq	%rsi, %rax
1000032cd: 48 83 d2 00                 	adcq	$0x0, %rdx
1000032d1: 48 83 c0 01                 	addq	$0x1, %rax
1000032d5: 48 83 d2 00                 	adcq	$0x0, %rdx
1000032d9: 66 48 0f 6e ca              	movq	%rdx, %xmm1
1000032de: 66 48 0f 6e c0              	movq	%rax, %xmm0
1000032e3: 66 0f 6c c1                 	punpcklqdq	%xmm1, %xmm0    ## xmm0 = xmm0[0],xmm1[0]
1000032e7: 4c 8d a5 60 ff ff ff        	leaq	-0xa0(%rbp), %r12
1000032ee: 66 41 0f 7f 04 24           	movdqa	%xmm0, (%r12)
1000032f4: 49 89 ff                    	movq	%rdi, %r15
1000032f7: 4c 89 e6                    	movq	%r12, %rsi
1000032fa: 8b 5d b0                    	movl	-0x50(%rbp), %ebx
1000032fd: 89 da                       	movl	%ebx, %edx
1000032ff: e8 37 03 00 00              	callq	0x10000363b <__text+0x263b>
100003304: 49 89 c6                    	movq	%rax, %r14
100003307: 4c 89 ff                    	movq	%r15, %rdi
10000330a: 48 83 cf 02                 	orq	$0x2, %rdi
10000330e: 48 89 7d c8                 	movq	%rdi, -0x38(%rbp)
100003312: 4c 89 e6                    	movq	%r12, %rsi
100003315: 89 da                       	movl	%ebx, %edx
100003317: e8 1f 03 00 00              	callq	0x10000363b <__text+0x263b>
10000331c: 49 89 c5                    	movq	%rax, %r13
10000331f: 44 0f b6 65 d7              	movzbl	-0x29(%rbp), %r12d
100003324: 49 f7 d4                    	notq	%r12
100003327: 4d 01 fc                    	addq	%r15, %r12
10000332a: 4c 89 e7                    	movq	%r12, %rdi
10000332d: 48 8d b5 60 ff ff ff        	leaq	-0xa0(%rbp), %rsi
100003334: 89 da                       	movl	%ebx, %edx
100003336: e8 00 03 00 00              	callq	0x10000363b <__text+0x263b>
10000333b: 48 89 c3                    	movq	%rax, %rbx
10000333e: 48 8b 45 98                 	movq	-0x68(%rbp), %rax
100003342: 49 89 c0                    	movq	%rax, %r8
100003345: 83 f8 16                    	cmpl	$0x16, %eax
100003348: 73 35                       	jae	0x10000337f <__text+0x237f>
10000334a: 6a 05                       	pushq	$0x5
10000334c: 59                          	popq	%rcx
10000334d: 4c 89 f8                    	movq	%r15, %rax
100003350: 31 d2                       	xorl	%edx, %edx
100003352: 48 f7 f1                    	divq	%rcx
100003355: 48 85 d2                    	testq	%rdx, %rdx
100003358: 0f 84 80 01 00 00           	je	0x1000034de <__text+0x24de>
10000335e: f6 45 c0 01                 	testb	$0x1, -0x40(%rbp)
100003362: 0f 85 88 01 00 00           	jne	0x1000034f0 <__text+0x24f0>
100003368: 4c 89 e7                    	movq	%r12, %rdi
10000336b: 4d 89 c4                    	movq	%r8, %r12
10000336e: 44 89 e6                    	movl	%r12d, %esi
100003371: e8 98 02 00 00              	callq	0x10000360e <__text+0x260e>
100003376: 89 c1                       	movl	%eax, %ecx
100003378: 31 f6                       	xorl	%esi, %esi
10000337a: e9 8d 01 00 00              	jmp	0x10000350c <__text+0x250c>
10000337f: 31 f6                       	xorl	%esi, %esi
100003381: 31 c9                       	xorl	%ecx, %ecx
100003383: 4c 8b 5d b8                 	movq	-0x48(%rbp), %r11
100003387: 4c 8b 7d c0                 	movq	-0x40(%rbp), %r15
10000338b: 4d 89 c4                    	movq	%r8, %r12
10000338e: e9 87 01 00 00              	jmp	0x10000351a <__text+0x251a>
100003393: 48 8d 0d 26 03 00 00        	leaq	0x326(%rip), %rcx       ## 0x1000036c0 <__text+0x26c0>
10000339a: 48 8b 0c c1                 	movq	(%rcx,%rax,8), %rcx
10000339e: 48 89 c8                    	movq	%rcx, %rax
1000033a1: 49 f7 23                    	mulq	(%r11)
1000033a4: 48 89 d6                    	movq	%rdx, %rsi
1000033a7: 48 89 fb                    	movq	%rdi, %rbx
1000033aa: 48 89 c7                    	movq	%rax, %rdi
1000033ad: 48 89 c8                    	movq	%rcx, %rax
1000033b0: 49 f7 63 08                 	mulq	0x8(%r11)
1000033b4: 48 89 45 c8                 	movq	%rax, -0x38(%rbp)
1000033b8: 48 89 55 a0                 	movq	%rdx, -0x60(%rbp)
1000033bc: 44 89 d0                    	movl	%r10d, %eax
1000033bf: 49 0f af c0                 	imulq	%r8, %rax
1000033c3: 48 c1 e8 2e                 	shrq	$0x2e, %rax
1000033c7: 41 29 c1                    	subl	%eax, %r9d
1000033ca: 43 8d 04 36                 	leal	(%r14,%r14), %eax
1000033ce: 89 45 a8                    	movl	%eax, -0x58(%rbp)
1000033d1: 45 0f b6 e9                 	movzbl	%r9b, %r13d
1000033d5: 44 89 ea                    	movl	%r13d, %edx
1000033d8: e8 ab f0 ff ff              	callq	0x100002488 <__text+0x1488>
1000033dd: 49 89 c7                    	movq	%rax, %r15
1000033e0: 48 89 55 88                 	movq	%rdx, -0x78(%rbp)
1000033e4: b0 40                       	movb	$0x40, %al
1000033e6: 44 28 e8                    	subb	%r13b, %al
1000033e9: 24 7f                       	andb	$0x7f, %al
1000033eb: 0f b6 d0                    	movzbl	%al, %edx
1000033ee: 48 8b 7d c8                 	movq	-0x38(%rbp), %rdi
1000033f2: 48 8b 75 a0                 	movq	-0x60(%rbp), %rsi
1000033f6: e8 d4 f0 ff ff              	callq	0x1000024cf <__text+0x14cf>
1000033fb: 48 89 df                    	movq	%rbx, %rdi
1000033fe: 41 c1 ee 04                 	shrl	$0x4, %r14d
100003402: 48 8d 0d 87 03 00 00        	leaq	0x387(%rip), %rcx       ## 0x100003790 <__text+0x2790>
100003409: 42 8b 34 b1                 	movl	(%rcx,%r14,4), %esi
10000340d: 8b 4d a8                    	movl	-0x58(%rbp), %ecx
100003410: d3 ee                       	shrl	%cl, %esi
100003412: 83 e6 03                    	andl	$0x3, %esi
100003415: 4c 01 f8                    	addq	%r15, %rax
100003418: 48 13 55 88                 	adcq	-0x78(%rbp), %rdx
10000341c: 48 01 f0                    	addq	%rsi, %rax
10000341f: 48 8b 75 b0                 	movq	-0x50(%rbp), %rsi
100003423: 48 83 d2 00                 	adcq	$0x0, %rdx
100003427: 48 83 c0 01                 	addq	$0x1, %rax
10000342b: 48 83 d2 00                 	adcq	$0x0, %rdx
10000342f: 66 48 0f 6e ca              	movq	%rdx, %xmm1
100003434: 66 48 0f 6e c0              	movq	%rax, %xmm0
100003439: 66 0f 6c c1                 	punpcklqdq	%xmm1, %xmm0    ## xmm0 = xmm0[0],xmm1[0]
10000343d: 41 01 f4                    	addl	%esi, %r12d
100003440: 4c 8d ad 50 ff ff ff        	leaq	-0xb0(%rbp), %r13
100003447: 66 41 0f 7f 45 00           	movdqa	%xmm0, (%r13)
10000344d: 48 89 fb                    	movq	%rdi, %rbx
100003450: 4c 89 ee                    	movq	%r13, %rsi
100003453: 44 8b 7d 98                 	movl	-0x68(%rbp), %r15d
100003457: 44 89 fa                    	movl	%r15d, %edx
10000345a: e8 dc 01 00 00              	callq	0x10000363b <__text+0x263b>
10000345f: 49 89 c6                    	movq	%rax, %r14
100003462: 48 89 df                    	movq	%rbx, %rdi
100003465: 48 83 cf 02                 	orq	$0x2, %rdi
100003469: 4c 89 ee                    	movq	%r13, %rsi
10000346c: 44 89 fa                    	movl	%r15d, %edx
10000346f: e8 c7 01 00 00              	callq	0x10000363b <__text+0x263b>
100003474: 49 89 c5                    	movq	%rax, %r13
100003477: 0f b6 7d d7                 	movzbl	-0x29(%rbp), %edi
10000347b: 48 f7 d7                    	notq	%rdi
10000347e: 48 89 5d c8                 	movq	%rbx, -0x38(%rbp)
100003482: 48 01 df                    	addq	%rbx, %rdi
100003485: 48 8d b5 50 ff ff ff        	leaq	-0xb0(%rbp), %rsi
10000348c: 44 89 fa                    	movl	%r15d, %edx
10000348f: e8 a7 01 00 00              	callq	0x10000363b <__text+0x263b>
100003494: 48 8b 4d b0                 	movq	-0x50(%rbp), %rcx
100003498: 48 89 c3                    	movq	%rax, %rbx
10000349b: 83 f9 02                    	cmpl	$0x2, %ecx
10000349e: 73 1e                       	jae	0x1000034be <__text+0x24be>
1000034a0: 48 8b 55 c0                 	movq	-0x40(%rbp), %rdx
1000034a4: 89 d0                       	movl	%edx, %eax
1000034a6: 83 e0 01                    	andl	$0x1, %eax
1000034a9: 0f 94 c1                    	sete	%cl
1000034ac: 22 4d d7                    	andb	-0x29(%rbp), %cl
1000034af: 49 89 d7                    	movq	%rdx, %r15
1000034b2: 49 29 c5                    	subq	%rax, %r13
1000034b5: 40 b6 01                    	movb	$0x1, %sil
1000034b8: 4c 8b 5d b8                 	movq	-0x48(%rbp), %r11
1000034bc: eb 5c                       	jmp	0x10000351a <__text+0x251a>
1000034be: 83 f9 3e                    	cmpl	$0x3e, %ecx
1000034c1: 4c 8b 5d b8                 	movq	-0x48(%rbp), %r11
1000034c5: 4c 8b 7d c0                 	movq	-0x40(%rbp), %r15
1000034c9: 77 4b                       	ja	0x100003516 <__text+0x2516>
1000034cb: 6a ff                       	pushq	$-0x1
1000034cd: 58                          	popq	%rax
1000034ce: 48 d3 e0                    	shlq	%cl, %rax
1000034d1: 48 f7 d0                    	notq	%rax
1000034d4: 48 85 45 c8                 	testq	%rax, -0x38(%rbp)
1000034d8: 40 0f 94 c6                 	sete	%sil
1000034dc: eb 3a                       	jmp	0x100003518 <__text+0x2518>
1000034de: 4c 89 ff                    	movq	%r15, %rdi
1000034e1: 4d 89 c4                    	movq	%r8, %r12
1000034e4: 44 89 e6                    	movl	%r12d, %esi
1000034e7: e8 22 01 00 00              	callq	0x10000360e <__text+0x260e>
1000034ec: 89 c6                       	movl	%eax, %esi
1000034ee: eb 1a                       	jmp	0x10000350a <__text+0x250a>
1000034f0: 48 8b 7d c8                 	movq	-0x38(%rbp), %rdi
1000034f4: 4d 89 c4                    	movq	%r8, %r12
1000034f7: 44 89 e6                    	movl	%r12d, %esi
1000034fa: e8 0f 01 00 00              	callq	0x10000360e <__text+0x260e>
1000034ff: 0f b6 c0                    	movzbl	%al, %eax
100003502: 83 e0 01                    	andl	$0x1, %eax
100003505: 49 29 c5                    	subq	%rax, %r13
100003508: 31 f6                       	xorl	%esi, %esi
10000350a: 31 c9                       	xorl	%ecx, %ecx
10000350c: 4c 8b 5d b8                 	movq	-0x48(%rbp), %r11
100003510: 4c 8b 7d c0                 	movq	-0x40(%rbp), %r15
100003514: eb 04                       	jmp	0x10000351a <__text+0x251a>
100003516: 31 f6                       	xorl	%esi, %esi
100003518: 31 c9                       	xorl	%ecx, %ecx
10000351a: 31 ff                       	xorl	%edi, %edi
10000351c: 6a 0a                       	pushq	$0xa
10000351e: 41 5a                       	popq	%r10
100003520: 45 31 c9                    	xorl	%r9d, %r9d
100003523: 4c 89 e8                    	movq	%r13, %rax
100003526: 31 d2                       	xorl	%edx, %edx
100003528: 49 f7 f2                    	divq	%r10
10000352b: 49 89 c5                    	movq	%rax, %r13
10000352e: 48 89 d8                    	movq	%rbx, %rax
100003531: 31 d2                       	xorl	%edx, %edx
100003533: 49 f7 f2                    	divq	%r10
100003536: 49 39 c5                    	cmpq	%rax, %r13
100003539: 76 2a                       	jbe	0x100003565 <__text+0x2565>
10000353b: 49 89 c0                    	movq	%rax, %r8
10000353e: 48 85 d2                    	testq	%rdx, %rdx
100003541: 0f 94 c0                    	sete	%al
100003544: 20 c1                       	andb	%al, %cl
100003546: 40 84 ff                    	testb	%dil, %dil
100003549: 0f 94 c0                    	sete	%al
10000354c: 40 20 c6                    	andb	%al, %sil
10000354f: 4c 89 f0                    	movq	%r14, %rax
100003552: 31 d2                       	xorl	%edx, %edx
100003554: 49 f7 f2                    	divq	%r10
100003557: 41 ff c1                    	incl	%r9d
10000355a: 4c 89 c3                    	movq	%r8, %rbx
10000355d: 49 89 c6                    	movq	%rax, %r14
100003560: 48 89 d7                    	movq	%rdx, %rdi
100003563: eb be                       	jmp	0x100003523 <__text+0x2523>
100003565: f6 c1 01                    	testb	$0x1, %cl
100003568: 74 2f                       	je	0x100003599 <__text+0x2599>
10000356a: 48 89 d8                    	movq	%rbx, %rax
10000356d: 31 d2                       	xorl	%edx, %edx
10000356f: 49 f7 f2                    	divq	%r10
100003572: 48 85 d2                    	testq	%rdx, %rdx
100003575: 75 22                       	jne	0x100003599 <__text+0x2599>
100003577: 49 89 c0                    	movq	%rax, %r8
10000357a: 40 84 ff                    	testb	%dil, %dil
10000357d: 0f 94 c0                    	sete	%al
100003580: 40 20 c6                    	andb	%al, %sil
100003583: 4c 89 f0                    	movq	%r14, %rax
100003586: 31 d2                       	xorl	%edx, %edx
100003588: 49 f7 f2                    	divq	%r10
10000358b: 41 ff c1                    	incl	%r9d
10000358e: 4c 89 c3                    	movq	%r8, %rbx
100003591: 49 89 c6                    	movq	%rax, %r14
100003594: 48 89 d7                    	movq	%rdx, %rdi
100003597: eb d1                       	jmp	0x10000356a <__text+0x256a>
100003599: 44 89 f0                    	movl	%r14d, %eax
10000359c: 24 01                       	andb	$0x1, %al
10000359e: 0c 04                       	orb	$0x4, %al
1000035a0: 40 80 ff 05                 	cmpb	$0x5, %dil
1000035a4: 40 0f b6 d7                 	movzbl	%dil, %edx
1000035a8: 0f b6 c0                    	movzbl	%al, %eax
1000035ab: 0f 45 c2                    	cmovnel	%edx, %eax
1000035ae: 40 f6 c6 01                 	testb	$0x1, %sil
1000035b2: 0f 44 c2                    	cmovel	%edx, %eax
1000035b5: 49 39 de                    	cmpq	%rbx, %r14
1000035b8: 0f 94 c2                    	sete	%dl
1000035bb: 80 f1 01                    	xorb	$0x1, %cl
1000035be: 44 08 f9                    	orb	%r15b, %cl
1000035c1: 3c 05                       	cmpb	$0x5, %al
1000035c3: 0f 93 c0                    	setae	%al
1000035c6: 20 d1                       	andb	%dl, %cl
1000035c8: 08 c1                       	orb	%al, %cl
1000035ca: 0f b6 c9                    	movzbl	%cl, %ecx
1000035cd: 4c 01 f1                    	addq	%r14, %rcx
1000035d0: 48 8b 85 78 ff ff ff        	movq	-0x88(%rbp), %rax
1000035d7: 48 89 08                    	movq	%rcx, (%rax)
1000035da: 45 01 e1                    	addl	%r12d, %r9d
1000035dd: 44 89 48 08                 	movl	%r9d, 0x8(%rax)
1000035e1: 48 8b 75 80                 	movq	-0x80(%rbp), %rsi
1000035e5: 44 8b 55 94                 	movl	-0x6c(%rbp), %r10d
1000035e9: 41 80 e3 1f                 	andb	$0x1f, %r11b
1000035ed: 45 00 da                    	addb	%r11b, %r10b
1000035f0: 41 0f b6 ca                 	movzbl	%r10b, %ecx
1000035f4: 48 0f a3 ce                 	btq	%rcx, %rsi
1000035f8: 0f 92 40 0c                 	setb	0xc(%rax)
1000035fc: 48 81 c4 88 00 00 00        	addq	$0x88, %rsp
100003603: 5b                          	popq	%rbx
100003604: 41 5c                       	popq	%r12
100003606: 41 5d                       	popq	%r13
100003608: 41 5e                       	popq	%r14
10000360a: 41 5f                       	popq	%r15
10000360c: 5d                          	popq	%rbp
10000360d: c3                          	retq
10000360e: 55                          	pushq	%rbp
10000360f: 48 89 e5                    	movq	%rsp, %rbp
100003612: 48 89 f8                    	movq	%rdi, %rax
100003615: 31 c9                       	xorl	%ecx, %ecx
100003617: 6a 05                       	pushq	$0x5
100003619: 5f                          	popq	%rdi
10000361a: 45 31 c0                    	xorl	%r8d, %r8d
10000361d: 48 85 c0                    	testq	%rax, %rax
100003620: 74 12                       	je	0x100003634 <__text+0x2634>
100003622: 31 d2                       	xorl	%edx, %edx
100003624: 48 f7 f7                    	divq	%rdi
100003627: 48 85 d2                    	testq	%rdx, %rdx
10000362a: 75 05                       	jne	0x100003631 <__text+0x2631>
10000362c: 41 ff c0                    	incl	%r8d
10000362f: eb ec                       	jmp	0x10000361d <__text+0x261d>
100003631: 44 89 c1                    	movl	%r8d, %ecx
100003634: 39 f1                       	cmpl	%esi, %ecx
100003636: 0f 93 c0                    	setae	%al
100003639: 5d                          	popq	%rbp
10000363a: c3                          	retq
10000363b: 55                          	pushq	%rbp
10000363c: 48 89 e5                    	movq	%rsp, %rbp
10000363f: 81 fa 80 00 00 00           	cmpl	$0x80, %edx
100003645: 73 25                       	jae	0x10000366c <__text+0x266c>
100003647: 89 d1                       	movl	%edx, %ecx
100003649: 48 89 f8                    	movq	%rdi, %rax
10000364c: 48 f7 66 08                 	mulq	0x8(%rsi)
100003650: 49 89 d0                    	movq	%rdx, %r8
100003653: 49 89 c1                    	movq	%rax, %r9
100003656: 48 89 f8                    	movq	%rdi, %rax
100003659: 48 f7 26                    	mulq	(%rsi)
10000365c: 48 89 d0                    	movq	%rdx, %rax
10000365f: 4c 01 c8                    	addq	%r9, %rax
100003662: 49 83 d0 00                 	adcq	$0x0, %r8
100003666: 4c 0f ad c0                 	shrdq	%cl, %r8, %rax
10000366a: eb 02                       	jmp	0x10000366e <__text+0x266e>
10000366c: 31 c0                       	xorl	%eax, %eax
10000366e: 5d                          	popq	%rbp
10000366f: c3                          	retq
100003670: 55                          	pushq	%rbp
100003671: 48 89 e5                    	movq	%rsp, %rbp
100003674: 48 89 d0                    	movq	%rdx, %rax
100003677: 31 c9                       	xorl	%ecx, %ecx
100003679: 48 39 c8                    	cmpq	%rcx, %rax
10000367c: 74 0b                       	je	0x100003689 <__text+0x2689>
10000367e: 8a 14 0e                    	movb	(%rsi,%rcx), %dl
100003681: 88 14 0f                    	movb	%dl, (%rdi,%rcx)
100003684: 48 ff c1                    	incq	%rcx
100003687: eb f0                       	jmp	0x100003679 <__text+0x2679>
100003689: 5d                          	popq	%rbp
10000368a: c3                          	retq
		...
100003693: 00 00                       	addb	%al, (%rax)
100003695: 00 f0                       	addb	%dh, %al
100003697: 7f 00                       	jg	0x100003699 <__text+0x2699>
100003699: 00 00                       	addb	%al, (%rax)
10000369b: 00 00                       	addb	%al, (%rax)
10000369d: 00 f0                       	addb	%dh, %al
10000369f: ff 00                       	incl	(%rax)
1000036a1: 00 80 7f 00 00 80           	addb	%al, -0x7fffff81(%rax)
1000036a7: ff 00                       	incl	(%rax)
		...
1000036b5: 00 00                       	addb	%al, (%rax)
1000036b7: 00 01                       	addb	%al, (%rcx)
1000036b9: 00 00                       	addb	%al, (%rax)
1000036bb: 00 00                       	addb	%al, (%rax)
1000036bd: 00 00                       	addb	%al, (%rax)
1000036bf: 00 01                       	addb	%al, (%rcx)
1000036c1: 00 00                       	addb	%al, (%rax)
1000036c3: 00 00                       	addb	%al, (%rax)
1000036c5: 00 00                       	addb	%al, (%rax)
1000036c7: 00 05 00 00 00 00           	addb	%al, (%rip)             ## 0x1000036cd <__text+0x26cd>
1000036cd: 00 00                       	addb	%al, (%rax)
1000036cf: 00 19                       	addb	%bl, (%rcx)
1000036d1: 00 00                       	addb	%al, (%rax)
1000036d3: 00 00                       	addb	%al, (%rax)
1000036d5: 00 00                       	addb	%al, (%rax)
1000036d7: 00 7d 00                    	addb	%bh, (%rbp)
1000036da: 00 00                       	addb	%al, (%rax)
1000036dc: 00 00                       	addb	%al, (%rax)
1000036de: 00 00                       	addb	%al, (%rax)
1000036e0: 71 02                       	jno	0x1000036e4 <__text+0x26e4>
1000036e2: 00 00                       	addb	%al, (%rax)
1000036e4: 00 00                       	addb	%al, (%rax)
1000036e6: 00 00                       	addb	%al, (%rax)
1000036e8: 35 0c 00 00 00              	xorl	$0xc, %eax
1000036ed: 00 00                       	addb	%al, (%rax)
1000036ef: 00 09                       	addb	%cl, (%rcx)
1000036f1: 3d 00 00 00 00              	cmpl	$0x0, %eax
1000036f6: 00 00                       	addb	%al, (%rax)
1000036f8: 2d 31 01 00 00              	subl	$0x131, %eax            ## imm = 0x131
1000036fd: 00 00                       	addb	%al, (%rax)
1000036ff: 00 e1                       	addb	%ah, %cl
100003701: f5                          	cmc
100003702: 05 00 00 00 00              	addl	$0x0, %eax
100003707: 00 65 cd                    	addb	%ah, -0x33(%rbp)
10000370a: 1d 00 00 00 00              	sbbl	$0x0, %eax
10000370f: 00 f9                       	addb	%bh, %cl
100003711: 02 95 00 00 00 00           	addb	(%rbp), %dl
100003717: 00 dd                       	addb	%bl, %ch
100003719: 0e                          	<unknown>
10000371a: e9 02 00 00 00              	jmp	0x100003721 <__text+0x2721>
10000371f: 00 51 4a                    	addb	%dl, 0x4a(%rcx)
100003722: 8d 0e                       	leal	(%rsi), %ecx
100003724: 00 00                       	addb	%al, (%rax)
100003726: 00 00                       	addb	%al, (%rax)
100003728: 95                          	xchgl	%ebp, %eax
100003729: 73 c2                       	jae	0x1000036ed <__text+0x26ed>
10000372b: 48 00 00                    	addb	%al, (%rax)
10000372e: 00 00                       	addb	%al, (%rax)
100003730: e9 41 cc 6b 01              	jmp	0x1016c0376
100003735: 00 00                       	addb	%al, (%rax)
100003737: 00 8d 49 fd 1a 07           	addb	%cl, 0x71afd49(%rbp)
10000373d: 00 00                       	addb	%al, (%rax)
10000373f: 00 c1                       	addb	%al, %cl
100003741: 6f                          	outsl	(%rsi), %dx
100003742: f2                          	xacquire
100003743: 86 23                       	xchgb	%ah, (%rbx)
100003745: 00 00                       	addb	%al, (%rax)
100003747: 00 c5                       	addb	%al, %ch
100003749: 2e bc a2 b1 00 00           	movl	$0xb1a2, %esp           ## imm = 0xB1A2
10000374f: 00 d9                       	addb	%bl, %cl
100003751: e9 ac 2d 78 03              	jmp	0x103786502
100003756: 00 00                       	addb	%al, (%rax)
100003758: 3d 91 60 e4 58              	cmpl	$0x58e46091, %eax       ## imm = 0x58E46091
10000375d: 11 00                       	adcl	%eax, (%rax)
10000375f: 00 31                       	addb	%dh, (%rcx)
100003761: d6                          	<unknown>
100003762: e2 75                       	loop	0x1000037d9 <__text+0x27d9>
100003764: bc 56 00 00 f5              	movl	$0xf5000056, %esp       ## imm = 0xF5000056
100003769: 2e 6e                       	outsb	%cs:(%rsi), %dx
10000376b: 4d ae                       	scasb	%es:(%rdi), %al
10000376d: b1 01                       	movb	$0x1, %cl
10000376f: 00 c9                       	addb	%cl, %cl
100003771: ea                          	<unknown>
100003772: 26 83 67 78 08              	andl	$0x8, %es:0x78(%rdi)
100003777: 00 ed                       	addb	%ch, %ch
100003779: 95                          	xchgl	%ebp, %eax
10000377a: c2 8f 05                    	retq	$0x58f                  ## imm = 0x58F
10000377d: 5a                          	popq	%rdx
10000377e: 2a 00                       	subb	(%rax), %al
100003780: a1 ed cc ce 1b c2 d3 00 25  	movabsl	0x2500d3c21bcecced, %eax
100003789: a4                          	movsb	(%rsi), %es:(%rdi)
10000378a: 00 0a                       	addb	%cl, (%rdx)
10000378c: 8b ca                       	movl	%edx, %ecx
10000378e: 22 04 00                    	andb	(%rax,%rax), %al
		...
1000037a1: 00 00                       	addb	%al, (%rax)
1000037a3: 40 95                       	xchgl	%ebp, %eax
1000037a5: 59                          	popq	%rcx
1000037a6: 69 59 55 55 54 55 15        	imull	$0x15555455, 0x55(%rcx), %ebx ## imm = 0x15555455
1000037ad: 55                          	pushq	%rbp
1000037ae: 55                          	pushq	%rbp
1000037af: 56                          	pushq	%rsi
1000037b0: 04 05                       	addb	$0x5, %al
1000037b2: 15 41 10 54 55              	adcl	$0x55541041, %eax       ## imm = 0x55541041
1000037b7: 40 45                       	<unknown>
1000037b9: 51                          	pushq	%rcx
1000037ba: 55                          	pushq	%rbp
1000037bb: 44 40                       	<unknown>
1000037bd: 45 50                       	pushq	%r8
1000037bf: 44 50                       	pushq	%rax
1000037c1: 55                          	pushq	%rbp
1000037c2: 55                          	pushq	%rbp
1000037c3: 45 00 40 00                 	addb	%r8b, (%r8)
1000037c7: 40 40                       	<unknown>
1000037c9: 04 44                       	addb	$0x44, %al
1000037cb: 96                          	xchgl	%esi, %eax
1000037cc: 65 55                       	pushq	%rbp
1000037ce: 56                          	pushq	%rsi
1000037cf: 55                          	pushq	%rbp
1000037d0: 45 40                       	<unknown>
1000037d2: 45 54                       	pushq	%r12
1000037d4: 51                          	pushq	%rcx
1000037d5: 41 15 40 55 91 55           	adcl	$0x55915540, %eax       ## imm = 0x55915540
1000037db: 55                          	pushq	%rbp
1000037dc: 55                          	pushq	%rbp
1000037dd: 55                          	pushq	%rbp
1000037de: 40 51                       	pushq	%rcx
1000037e0: 05 01 00 00 54              	addl	$0x54000001, %eax       ## imm = 0x54000001
1000037e5: 45 54                       	pushq	%r12
1000037e7: 54                          	pushq	%rsp
1000037e8: 45 55                       	pushq	%r13
1000037ea: 05 04 00 10 04              	addl	$0x4100004, %eax        ## imm = 0x4100004
1000037ef: 10 14 04                    	adcb	%dl, (%rsp,%rax)
1000037f2: 40 00 00                    	addb	%al, (%rax)
1000037f5: 00 01                       	addb	%al, (%rcx)
1000037f7: 40 55                       	pushq	%rbp
1000037f9: 55                          	pushq	%rbp
1000037fa: 15 41 54 04 00              	adcl	$0x45441, %eax          ## imm = 0x45441
1000037ff: 00 44 00 01                 	addb	%al, 0x1(%rax,%rax)
100003803: 00 00                       	addb	%al, (%rax)
100003805: 00 00                       	addb	%al, (%rax)
100003807: 40 41                       	<unknown>
100003809: 00 00                       	addb	%al, (%rax)
10000380b: 44 50                       	pushq	%rax
10000380d: 44 45                       	<unknown>
10000380f: 50                          	pushq	%rax
100003810: 54                          	pushq	%rsp
100003811: 00 55 55                    	addb	%dl, 0x55(%rbp)
100003814: 54                          	pushq	%rsp
100003815: 55                          	pushq	%rbp
100003816: 65 51                       	pushq	%rcx
100003818: 00 40 00                    	addb	%al, (%rax)
10000381b: 40 01 00                    	addl	%eax, (%rax)
10000381e: 00 01                       	addb	%al, (%rcx)
100003820: 00 05 01 00 11 54           	addb	%al, 0x54110001(%rip)   ## 0x154113827
100003826: 51                          	pushq	%rcx
100003827: 51                          	pushq	%rcx
100003828: 54                          	pushq	%rsp
100003829: 55                          	pushq	%rbp
10000382a: 55                          	pushq	%rbp
10000382b: 05 00 00 00 00              	addl	$0x0, %eax
100003830: 01 00                       	addl	%eax, (%rax)
		...
10000383e: 00 20                       	addb	%ah, (%rax)
100003840: 34 50                       	xorb	$0x50, %al
100003842: 65 c0 5f c9 a6              	rcrb	$0xa6, %gs:-0x37(%rdi)
100003847: 52                          	pushq	%rdx
100003848: bb 13 cb ae c4              	movl	$0xc4aecb13, %ebx       ## imm = 0xC4AECB13
10000384d: 40 c2 18 06                 	retq	$0x618                  ## imm = 0x618
100003851: c8 df 71 00                 	enter	$0x71df, $0x0           ## imm = 0x71DF
100003855: d5 a8 7c                    	<unknown>
100003858: f5                          	cmc
100003859: 6f                          	outsl	(%rsi), %dx
10000385a: 0f da 58 fc                 	pminub	-0x4(%rax), %mm3
10000385e: 27                          	<unknown>
10000385f: 13 6e 47                    	adcl	0x47(%rsi), %ebp
100003862: 56                          	pushq	%rsi
100003863: 35 7d 24 20 65              	xorl	$0x6520247d, %eax       ## imm = 0x6520247D
100003868: 02 c7                       	addb	%bh, %al
10000386a: e7 68                       	outl	%eax, $0x68
10000386c: e4 8c                       	inb	$0x8c, %al
10000386e: a4                          	movsb	(%rsi), %es:(%rdi)
10000386f: 1d e9 e6 02 68              	sbbl	$0x6802e6e9, %eax       ## imm = 0x6802E6E9
100003874: d7                          	xlatb
100003875: cd 39                       	int	$0x39
100003877: 61                          	<unknown>
100003878: 79 77                       	jns	0x1000038f1 <__text+0x28f1>
10000387a: fc                          	cld
10000387b: c2 40 5b                    	retq	$0x5b40                 ## imm = 0x5B40
10000387e: ef                          	outl	%eax, %dx
10000387f: 16                          	<unknown>
100003880: 79 8c                       	jns	0x10000380e <__text+0x280e>
100003882: de 43 ff                    	fiadds	-0x1(%rbx)
100003885: a7                          	cmpsl	%es:(%rdi), (%rsi)
100003886: 51                          	pushq	%rcx
100003887: f9                          	stc
100003888: 91                          	xchgl	%ecx, %eax
100003889: f3 b2 78                    	rep		movb	$0x78, %dl
10000388c: f5                          	cmc
10000388d: bd be 11 e8 57              	movl	$0x57e811be, %ebp       ## imm = 0x57E811BE
100003892: e9 d6 e8 be e8              	jmp	0xe8bf216d
100003897: 7b b0                       	jnp	0x100003849 <__text+0x2849>
100003899: 54                          	pushq	%rsp
10000389a: ac                          	lodsb	(%rsi), %al
10000389b: 8f 84 8d 75 1b ea 23        	popq	0x23ea1b75(%rbp,%rcx,4)
1000038a2: a4                          	movsb	(%rsi), %es:(%rdi)
1000038a3: 99                          	cltd
1000038a4: e9 f9 d3 8b b7              	jmp	0xb78c0ca2
1000038a9: a3 71 40 61 da 3e 15 ce e3  	movabsl	%eax, -0x1c31eac1259ebf8f
1000038b2: 3e cb                       	lretl
1000038b4: 73 f9                       	jae	0x1000038af <__text+0x28af>
1000038b6: 48 08 8c 97 b4 27 d5 1b     	orb	%cl, 0x1bd527b4(%rdi,%rdx,4)
1000038be: 70 10                       	jo	0x1000038d0 <__text+0x28d0>
1000038c0: a2 bf ef b9 eb 85 32 15 4d  	movabsb	%al, 0x4d153285ebb9efbf
1000038c9: b4 4d                       	movb	$0x4d, %ah
1000038cb: b4 9b                       	movb	$-0x65, %ah
1000038cd: bb 6f 19 96 b6              	movl	$0xb696196f, %ebx       ## imm = 0xB696196F
1000038d2: 07                          	<unknown>
1000038d3: 6c                          	insb	%dx, %es:(%rdi)
1000038d4: f8                          	clc
1000038d5: e7 ee                       	outl	%eax, $0xee
1000038d7: ad                          	lodsl	(%rsi), %eax
1000038d8: 36 d9 b4 f5 91 35 ae 13     	fnstenv	%ss:0x13ae3591(%rbp,%rsi,8)
1000038e0: 22 22                       	andb	(%rdx), %ah
1000038e2: 18 af 4e 6a 68 4d           	sbbb	%ch, 0x4d686a4e(%rdi)
1000038e8: 91                          	xchgl	%ecx, %eax
1000038e9: da aa 3d 4f 40 74           	fisubrl	0x74404f3d(%rdx)
1000038ef: 1e                          	<unknown>
1000038f0: 9f                          	lahf
1000038f1: bd 9e e0 06 a1              	movl	$0xa106e09e, %ebp       ## imm = 0xA106E09E
1000038f6: c0 98 57 c2 a7 fd a4        	rcrb	$0xa4, -0x2583da9(%rax)
1000038fd: 0e                          	<unknown>
1000038fe: 90                          	nop
1000038ff: 17                          	<unknown>
100003900: 0e                          	<unknown>
100003901: 7d 49                       	jge	0x10000394c <__text+0x294c>
100003903: 71 73                       	jno	0x100003978 <__text+0x2978>
100003905: e3 20                       	jrcxz	0x100003927 <__text+0x2927>
100003907: 8f b2 20                    	<unknown>
10000390a: d8 76 05                    	fdivs	0x5(%rsi)
10000390d: 14 3b                       	adcb	$0x3b, %al
10000390f: 12 85 3d 74 34 81           	adcb	-0x7ecb8bc3(%rbp), %al
100003915: 13 43 b0                    	adcl	-0x50(%rbx), %eax
100003918: ad                          	lodsl	(%rsi), %eax
100003919: 29 7a 5f                    	subl	%edi, 0x5f(%rdx)
10000391c: 27                          	<unknown>
10000391d: f4                          	hlt
10000391e: 35 1c 00 00 00              	xorl	$0x1c, %eax
		...
10000392f: 10 00                       	adcb	%al, (%rax)
100003931: 00 00                       	addb	%al, (%rax)
100003933: 00 00                       	addb	%al, (%rax)
100003935: 00 00                       	addb	%al, (%rax)
100003937: 00 b9 34 03 32 b7           	addb	%bh, -0x48cdfccc(%rcx)
10000393d: f4                          	hlt
10000393e: ad                          	lodsl	(%rsi), %eax
10000393f: 14 10                       	adcb	$0x10, %al
100003941: db 1a                       	fistpl	(%rdx)
100003943: b3 08                       	movb	$0x8, %bl
100003945: 92                          	xchgl	%edx, %eax
100003946: 54                          	pushq	%rsp
100003947: 0e                          	<unknown>
100003948: 0d 30 7d 95 14              	orl	$0x14957d30, %eax       ## imm = 0x14957D30
10000394d: 47 ba 1a 66 08 8f           	movl	$0x8f08661a, %r10d      ## imm = 0x8F08661A
100003953: 4d 26                       	es
100003955: ad                          	lodsl	(%rsi), %eax
100003956: c6 6d f5                    	<unknown>
100003959: 98                          	cwtl
10000395a: bf 85 e2 b7 45              	movl	$0x45b7e285, %edi       ## imm = 0x45B7E285
10000395f: 11 ca                       	adcl	%ecx, %edx
100003961: 96                          	xchgl	%esi, %eax
100003962: 85 3d 92 bd 1d eb           	testl	%edi, -0x14e2426e(%rip) ## 0xeb1df6fa
100003968: fc                          	cld
100003969: a1 18 60 dc ef 52 16 3c 92  	movabsl	-0x6dc3e9ad10239fe8, %eax
100003972: ae                          	scasb	%es:(%rdi), %al
100003973: 22 0b                       	andb	(%rbx), %cl
100003975: b8 c1 b4 83 9d              	movl	$0x9d83b4c1, %eax       ## imm = 0x9D83B4C1
10000397a: 2d 5b 05 62 da              	subl	$0xda62055b, %eax       ## imm = 0xDA62055B
10000397f: 1c 30                       	sbbb	$0x30, %al
100003981: 4c 7e 8f                    	jle	0x100003913 <__text+0x2913>
100003984: 4e 8b b2 5b 16 f4 52        	movq	0x52f4165b(%rdx), %r14
10000398b: 9f                          	lahf
10000398c: 8b 56 a5                    	movl	-0x5b(%rsi), %edx
10000398f: 12 fb                       	adcb	%bl, %bh
100003991: d4                          	<unknown>
100003992: 82                          	<unknown>
100003993: 76 43                       	jbe	0x1000039d8 <__text+0x29d8>
100003995: ed                          	inl	%dx, %eax
100003996: 8a f0                       	movb	%al, %dh
100003998: 8f e7 f9                    	<unknown>
10000399b: 31 15 65 19 18 50           	xorl	%edx, 0x50181965(%rip)  ## 0x150185306
1000039a1: f1                          	<unknown>
1000039a2: 9b                          	wait
1000039a3: d9 4a 13                    	<unknown>
1000039a6: ee                          	outb	%al, %dx
1000039a7: b4 28                       	movb	$0x28, %ah
1000039a9: 4c f0                       	lock
1000039ab: a6                          	cmpsb	%es:(%rdi), (%rsi)
1000039ac: 86 c1                       	xchgb	%cl, %al
1000039ae: 25 1f 03 5f c2              	andl	$0xc25f031f, %eax       ## imm = 0xC25F031F
1000039b3: 70 cb                       	jo	0x100003980 <__text+0x2980>
1000039b5: 9e                          	sahf
1000039b6: 49 16                       	<unknown>
1000039b8: e6 42                       	outb	%al, $0x42
1000039ba: 88 9c 44 eb 20 14 b0        	movb	%bl, -0x4febdf15(%rsp,%rax,2)
1000039c1: 65 08 36                    	orb	%dh, %gs:(%rsi)
1000039c4: ad                          	lodsl	(%rsi), %eax
1000039c5: 6e                          	outsb	(%rsi), %dx
1000039c6: a5                          	movsl	(%rsi), %es:(%rdi)
1000039c7: 85 85 f0 ca 14 e2           	testl	%eax, -0x1deb3510(%rbp)
1000039cd: fd                          	std
1000039ce: 03 1a                       	addl	(%rdx), %ebx
1000039d0: 0b 89 99 79 d5 b1           	orl	-0x4e2a8667(%rcx), %ecx
1000039d6: 3d 09 d8 da 97              	cmpl	$0x97dad809, %eax       ## imm = 0x97DAD809
1000039db: 3a 35 eb cf 10 ac           	cmpb	-0x53ef3015(%rip), %dh  ## 0xac1109cc
1000039e1: 36 3f                       	<unknown>
1000039e3: 5e                          	popq	%rsi
1000039e4: 73 bb                       	jae	0x1000039a1 <__text+0x29a1>
1000039e6: 38 cf                       	cmpb	%cl, %bh
1000039e8: 3e 67 52                    	addr32		pushq	%rdx
1000039eb: fa                          	cli
1000039ec: 44 af                       	scasl	%es:(%rdi), %eax
1000039ee: ba 15 6e 61 6e              	movl	$0x6e616e15, %edx       ## imm = 0x6E616E15
1000039f3: 00 69 6e                    	addb	%ch, 0x6e(%rcx)
1000039f6: 66 00 2d 69 6e 66 00        	addb	%ch, 0x666e69(%rip)     ## 0x10066a866
1000039fd: 2d 30 2e 30 00              	subl	$0x302e30, %eax         ## imm = 0x302E30
100003a02: 30 2e                       	xorb	%ch, (%rsi)
100003a04: 30 00                       	xorb	%al, (%rax)
		...
100005ffe: 00 00                       	addb	%al, (%rax)
