
/private/tmp/damping-minimal:	file format mach-o arm64

Disassembly of section __TEXT,__text:

0000000100000400 <_silex_function_0>:
100000400:     	stp	x29, x30, [sp, #-0x10]!
100000404:     	mov	x29, sp
100000408:     	sub	sp, sp, #0x70
10000040c:     	str	x0, [sp]
100000410:     	str	x1, [sp, #0x8]
100000414:     	str	x2, [sp, #0x10]
100000418:     	str	x3, [sp, #0x18]
10000041c:     	str	x4, [sp, #0x20]

0000000100000420 <_silex$DampingDiagnostic.calc$Silex/Toolchain/Benchmarks/Optimizer/DampingDiagnostic.sx:2:5>:
100000420:     	ldr	s9, [sp]
100000424:     	ldr	s10, [sp, #0x10]
100000428:     	fmul	s11, s9, s10
10000042c:     	str	s11, [sp, #0x28]
100000430:     	ldr	s9, [sp]
100000434:     	ldr	s10, [sp, #0x8]
100000438:     	fmul	s11, s9, s10
10000043c:     	str	s11, [sp, #0x30]
100000440:     	fmov	s9, #10.00000000
100000444:     	str	s9, [sp, #0x38]
100000448:     	ldr	s9, [sp, #0x38]
10000044c:     	ldr	s10, [sp, #0x30]
100000450:     	fnmul	s11, s9, s10
100000454:     	str	s11, [sp, #0x48]
100000458:     	ldr	s9, [sp, #0x30]
10000045c:     	ldr	s10, [sp, #0x40]
100000460:     	ldr	s11, [sp, #0x28]
100000464:     	fmadd	s12, s9, s10, s11
100000468:     	str	s12, [sp, #0x50]
10000046c:     	ldr	s9, [sp, #0x18]
100000470:     	ldr	s10, [sp, #0x20]
100000474:     	ldr	s11, [sp, #0x50]
100000478:     	fmadd	s12, s9, s10, s11
10000047c:     	str	s12, [sp, #0x60]
100000480:     	ldr	s9, [sp, #0x60]
100000484:     	fmov	w0, s9
100000488:     	mov	w8, #0x0                ; =0
10000048c:     	add	sp, sp, #0x70
100000490:     	ldp	x29, x30, [sp], #0x10
100000494:     	ret
100000498:     	mov	w8, #0x1                ; =1
10000049c:     	b	0x10000048c <_silex$DampingDiagnostic.calc$Silex/Toolchain/Benchmarks/Optimizer/DampingDiagnostic.sx:2:5+0x6c>
1000004a0:     	mov	w8, #0x2                ; =2
1000004a4:     	b	0x10000048c <_silex$DampingDiagnostic.calc$Silex/Toolchain/Benchmarks/Optimizer/DampingDiagnostic.sx:2:5+0x6c>

00000001000004a8 <_silex_function_1>:
1000004a8:     	stp	x29, x30, [sp, #-0x10]!
1000004ac:     	mov	x29, sp
1000004b0:     	sub	sp, sp, #0x70

00000001000004b4 <_silex$main$Silex/Toolchain/Benchmarks/Optimizer/DampingDiagnostic.sx:4:15>:
1000004b4:     	fmov	s9, #0.12500000
1000004b8:     	str	s9, [sp]
1000004bc:     	fmov	s9, #1.00000000
1000004c0:     	str	s9, [sp, #0x8]
1000004c4:     	fmov	s9, #2.00000000
1000004c8:     	str	s9, [sp, #0x10]
1000004cc:     	ldr	s9, [sp, #0x10]
1000004d0:     	fneg	s10, s9
1000004d4:     	str	s10, [sp, #0x18]
1000004d8:     	fmov	s9, #0.50000000
1000004dc:     	str	s9, [sp, #0x20]
1000004e0:     	fmov	s9, #2.00000000
1000004e4:     	str	s9, [sp, #0x28]
1000004e8:     	ldr	x0, [sp]
1000004ec:     	ldr	x1, [sp, #0x8]
1000004f0:     	ldr	x2, [sp, #0x18]
1000004f4:     	ldr	x3, [sp, #0x20]
1000004f8:     	ldr	x4, [sp, #0x28]
1000004fc:     	bl	0x100000400 <_silex_function_0>
100000500:     	str	x0, [sp, #0x30]
100000504:     	ldr	x0, [sp, #0x30]
100000508:     	sub	sp, sp, #0x160
10000050c:     	mov	x1, sp
100000510:     	mov	w2, #0x0                ; =0
100000514:     	bl	0x100000958 <_main+0x338>
100000518:     	mov	w8, #0x0                ; =0
10000051c:     	mov	x2, x0
100000520:     	mov	w0, #0x1                ; =1
100000524:     	mov	x1, sp
100000528:     	mov	w16, #0x4               ; =4
10000052c:     	svc	#0x80
100000530:     	add	sp, sp, #0x160
100000534:     	mov	w0, #0x1                ; =1
100000538:     	adrp	x1, 0x100001000 <_main+0x9e0>
10000053c:     	add	x1, x1, #0xe20
100000540:     	mov	x2, #0x1                ; =1
100000544:     	movk	x2, #0x0, lsl #16
100000548:     	movk	x2, #0x0, lsl #32
10000054c:     	movk	x2, #0x0, lsl #48
100000550:     	mov	w16, #0x4               ; =4
100000554:     	svc	#0x80

0000000100000558 <_silex$main$Silex/Toolchain/Benchmarks/Optimizer/DampingDiagnostic.sx:4:56>:
100000558:     	fmov	s9, #0.12500000
10000055c:     	str	s9, [sp, #0x38]
100000560:     	movi	d9, #0000000000000000
100000564:     	str	s9, [sp, #0x40]
100000568:     	movi	d9, #0000000000000000
10000056c:     	str	s9, [sp, #0x48]
100000570:     	fmov	s9, #1.00000000
100000574:     	str	s9, [sp, #0x50]
100000578:     	fmov	s9, #2.00000000
10000057c:     	str	s9, [sp, #0x58]
100000580:     	ldr	s9, [sp, #0x58]
100000584:     	fneg	s10, s9
100000588:     	str	s10, [sp, #0x60]
10000058c:     	ldr	x0, [sp, #0x38]
100000590:     	ldr	x1, [sp, #0x40]
100000594:     	ldr	x2, [sp, #0x48]
100000598:     	ldr	x3, [sp, #0x50]
10000059c:     	ldr	x4, [sp, #0x60]
1000005a0:     	bl	0x100000400 <_silex_function_0>
1000005a4:     	str	x0, [sp, #0x68]
1000005a8:     	ldr	x0, [sp, #0x68]
1000005ac:     	sub	sp, sp, #0x160
1000005b0:     	mov	x1, sp
1000005b4:     	mov	w2, #0x0                ; =0
1000005b8:     	bl	0x100000958 <_main+0x338>
1000005bc:     	mov	w8, #0x0                ; =0
1000005c0:     	mov	x2, x0
1000005c4:     	mov	w0, #0x1                ; =1
1000005c8:     	mov	x1, sp
1000005cc:     	mov	w16, #0x4               ; =4
1000005d0:     	svc	#0x80
1000005d4:     	add	sp, sp, #0x160
1000005d8:     	mov	w0, #0x1                ; =1
1000005dc:     	adrp	x1, 0x100001000 <_main+0x9e0>
1000005e0:     	add	x1, x1, #0xe20
1000005e4:     	mov	x2, #0x1                ; =1
1000005e8:     	movk	x2, #0x0, lsl #16
1000005ec:     	movk	x2, #0x0, lsl #32
1000005f0:     	movk	x2, #0x0, lsl #48
1000005f4:     	mov	w16, #0x4               ; =4
1000005f8:     	svc	#0x80
1000005fc:     	mov	w0, #0x0                ; =0
100000600:     	mov	w8, #0x0                ; =0
100000604:     	add	sp, sp, #0x70
100000608:     	ldp	x29, x30, [sp], #0x10
10000060c:     	ret
100000610:     	mov	w8, #0x1                ; =1
100000614:     	b	0x100000604 <_silex$main$Silex/Toolchain/Benchmarks/Optimizer/DampingDiagnostic.sx:4:56+0xac>
100000618:     	mov	w8, #0x2                ; =2
10000061c:     	b	0x100000604 <_silex$main$Silex/Toolchain/Benchmarks/Optimizer/DampingDiagnostic.sx:4:56+0xac>

0000000100000620 <_main>:
100000620:     	stp	x29, x30, [sp, #-0x10]!
100000624:     	mov	x29, sp
100000628:     	bl	0x1000004a8 <_silex_function_1>
10000062c:     	cbz	w8, 0x10000063c <_main+0x1c>
100000630:     	mov	w0, #0x1                ; =1
100000634:     	ldp	x29, x30, [sp], #0x10
100000638:     	ret
10000063c:     	mov	w0, #0x0                ; =0
100000640:     	ldp	x29, x30, [sp], #0x10
100000644:     	ret
		...
100000898:     	orr	x10, x2, x3
10000089c:     	cbz	x10, 0x100000930 <_main+0x310>
1000008a0:     	mov	x8, x1
1000008a4:     	mov	x9, x0
1000008a8:     	mov	x13, #0x0               ; =0
1000008ac:     	mov	x14, #0x0               ; =0
1000008b0:     	mov	x0, #0x0                ; =0
1000008b4:     	mov	x1, #0x0                ; =0
1000008b8:     	mov	w10, #0x80              ; =128
1000008bc:     	lsl	x11, x8, #1
1000008c0:     	mov	w12, #0x1               ; =1
1000008c4:     	tst	w10, #0xff
1000008c8:     	b.eq	0x100000938 <_main+0x318>
1000008cc:     	sub	w10, w10, #0x1
1000008d0:     	extr	x14, x14, x13, #0x3f
1000008d4:     	lsr	x15, x9, x10
1000008d8:     	mvn	w16, w10
1000008dc:     	lsl	x16, x11, x16
1000008e0:     	orr	x15, x16, x15
1000008e4:     	lsr	x16, x8, x10
1000008e8:     	and	x17, x10, #0xff
1000008ec:     	tst	x17, #0x40
1000008f0:     	csel	x15, x16, x15, ne
1000008f4:     	bfi	x15, x13, #1, #63
1000008f8:     	lsl	x13, x12, x10
1000008fc:     	csel	x16, x13, xzr, ne
100000900:     	csel	x13, xzr, x13, ne
100000904:     	cmp	x15, x2
100000908:     	sbcs	xzr, x14, x3
10000090c:     	csel	x17, xzr, x3, lo
100000910:     	csel	x4, xzr, x2, lo
100000914:     	csel	x5, xzr, x13, lo
100000918:     	csel	x16, xzr, x16, lo
10000091c:     	subs	x13, x15, x4
100000920:     	sbc	x14, x14, x17
100000924:     	orr	x1, x16, x1
100000928:     	orr	x0, x5, x0
10000092c:     	b	0x1000008c4 <_main+0x2a4>
100000930:     	mov	x0, #0x0                ; =0
100000934:     	mov	x1, #0x0                ; =0
100000938:     	ret
10000093c:     	mov	x8, #0x0                ; =0
100000940:     	cmp	x2, x8
100000944:     	b.eq	0x100000954 <_main+0x334>
100000948:     	strb	w1, [x0, x8]
10000094c:     	add	x8, x8, #0x1
100000950:     	b	0x100000940 <_main+0x320>
100000954:     	ret
100000958:     	sub	sp, sp, #0x50
10000095c:     	stp	x20, x19, [sp, #0x30]
100000960:     	stp	x29, x30, [sp, #0x40]
100000964:     	mov	x19, x1
100000968:     	cbz	x2, 0x1000009ac <_main+0x38c>
10000096c:     	fmov	d0, x0
100000970:     	fcmp	d0, d0
100000974:     	b.vs	0x100000b4c <_main+0x52c>
100000978:     	mov	x8, #0x7ff0000000000000 ; =9218868437227405312
10000097c:     	fmov	d1, x8
100000980:     	fcmp	d0, d1
100000984:     	b.eq	0x1000009c8 <_main+0x3a8>
100000988:     	mov	x8, #-0x10000000000000  ; =-4503599627370496
10000098c:     	fmov	d1, x8
100000990:     	fcmp	d0, d1
100000994:     	b.eq	0x1000009f0 <_main+0x3d0>
100000998:     	fcmp	d0, #0.0
10000099c:     	b.ne	0x100000a44 <_main+0x424>
1000009a0:     	bl	0x100001a6c <_main+0x144c>
1000009a4:     	cmp	x0, #0x0
1000009a8:     	b	0x100000a18 <_main+0x3f8>
1000009ac:     	fmov	s0, w0
1000009b0:     	fcmp	s0, s0
1000009b4:     	b.vs	0x100000b4c <_main+0x52c>
1000009b8:     	mov	w8, #0x7f800000         ; =2139095040
1000009bc:     	fmov	s1, w8
1000009c0:     	fcmp	s0, s1
1000009c4:     	b.ne	0x1000009e0 <_main+0x3c0>
1000009c8:     	adrp	x1, 0x100001000 <_main+0x9e0>
1000009cc:     	add	x1, x1, #0xe04
1000009d0:     	mov	w20, #0x3               ; =3
1000009d4:     	mov	x0, x19
1000009d8:     	mov	w2, #0x3                ; =3
1000009dc:     	b	0x100000a2c <_main+0x40c>
1000009e0:     	mov	w8, #-0x800000          ; =-8388608
1000009e4:     	fmov	s1, w8
1000009e8:     	fcmp	s0, s1
1000009ec:     	b.ne	0x100000a08 <_main+0x3e8>
1000009f0:     	adrp	x1, 0x100001000 <_main+0x9e0>
1000009f4:     	add	x1, x1, #0xe08
1000009f8:     	mov	w20, #0x4               ; =4
1000009fc:     	mov	x0, x19
100000a00:     	mov	w2, #0x4                ; =4
100000a04:     	b	0x100000a2c <_main+0x40c>
100000a08:     	fcmp	s0, #0.0
100000a0c:     	b.ne	0x100000a74 <_main+0x454>
100000a10:     	bl	0x100001a6c <_main+0x144c>
100000a14:     	cmp	w0, #0x0
100000a18:     	csel	x1, x9, x8, lt
100000a1c:     	mov	w8, #0x3                ; =3
100000a20:     	cinc	x20, x8, lt
100000a24:     	mov	x0, x19
100000a28:     	mov	x2, x20
100000a2c:     	bl	0x100001964 <_main+0x1344>
100000a30:     	mov	x0, x20
100000a34:     	ldp	x29, x30, [sp, #0x40]
100000a38:     	ldp	x20, x19, [sp, #0x30]
100000a3c:     	add	sp, sp, #0x50
100000a40:     	ret
100000a44:     	adrp	x8, 0x100001000 <_main+0x9e0>
100000a48:     	ldrb	w20, [x8, #0xab0]
100000a4c:     	add	x8, sp, #0x8
100000a50:     	mov	w1, #0x34               ; =52
100000a54:     	mov	w2, #0xb                ; =11
100000a58:     	bl	0x1000013e4 <_main+0xdc4>
100000a5c:     	adrp	x2, 0x100001000 <_main+0x9e0>
100000a60:     	add	x2, x2, #0xaa0
100000a64:     	tbz	w20, #0x0, 0x100000aa8 <_main+0x488>
100000a68:     	bl	0x1000019a4 <_main+0x1384>
100000a6c:     	bl	0x100000b58 <_main+0x538>
100000a70:     	b	0x100000ab0 <_main+0x490>
100000a74:     	adrp	x8, 0x100001000 <_main+0x9e0>
100000a78:     	ldrb	w20, [x8, #0xab0]
100000a7c:     	mov	w0, w0
100000a80:     	add	x8, sp, #0x8
100000a84:     	mov	w1, #0x17               ; =23
100000a88:     	mov	w2, #0x8                ; =8
100000a8c:     	bl	0x1000013e4 <_main+0xdc4>
100000a90:     	adrp	x2, 0x100001000 <_main+0x9e0>
100000a94:     	add	x2, x2, #0xaa0
100000a98:     	tbz	w20, #0x0, 0x100000aec <_main+0x4cc>
100000a9c:     	bl	0x1000019a4 <_main+0x1384>
100000aa0:     	bl	0x100000b58 <_main+0x538>
100000aa4:     	b	0x100000af4 <_main+0x4d4>
100000aa8:     	bl	0x1000019a4 <_main+0x1384>
100000aac:     	bl	0x100000da0 <_main+0x780>
100000ab0:     	ldrh	w8, [x20, #0x10]
100000ab4:     	cbnz	w8, 0x100000afc <_main+0x4dc>
100000ab8:     	bl	0x100001a20 <_main+0x1400>
100000abc:     	cmp	x20, x9
100000ac0:     	b.eq	0x100000b38 <_main+0x518>
100000ac4:     	ldrb	w13, [x10, x9]
100000ac8:     	sub	w13, w13, #0x2e
100000acc:     	cmp	w13, #0x37
100000ad0:     	lsl	x13, x11, x13
100000ad4:     	and	x13, x13, x12
100000ad8:     	ccmp	x13, #0x0, #0x4, ls
100000adc:     	b.eq	0x100000ae4 <_main+0x4c4>
100000ae0:     	mov	w8, #0x1                ; =1
100000ae4:     	add	x9, x9, #0x1
100000ae8:     	b	0x100000abc <_main+0x49c>
100000aec:     	bl	0x1000019a4 <_main+0x1384>
100000af0:     	bl	0x100000da0 <_main+0x780>
100000af4:     	ldrh	w8, [x20, #0x10]
100000af8:     	cbz	w8, 0x100000b04 <_main+0x4e4>
100000afc:     	mov	x20, #0x0               ; =0
100000b00:     	b	0x100000a30 <_main+0x410>
100000b04:     	bl	0x100001a20 <_main+0x1400>
100000b08:     	cmp	x20, x9
100000b0c:     	b.eq	0x100000b38 <_main+0x518>
100000b10:     	ldrb	w13, [x10, x9]
100000b14:     	sub	w13, w13, #0x2e
100000b18:     	cmp	w13, #0x37
100000b1c:     	lsl	x13, x11, x13
100000b20:     	and	x13, x13, x12
100000b24:     	ccmp	x13, #0x0, #0x4, ls
100000b28:     	b.eq	0x100000b30 <_main+0x510>
100000b2c:     	mov	w8, #0x1                ; =1
100000b30:     	add	x9, x9, #0x1
100000b34:     	b	0x100000b08 <_main+0x4e8>
100000b38:     	tbnz	w8, #0x0, 0x100000a30 <_main+0x410>
100000b3c:     	mov	w8, #0x302e             ; =12334
100000b40:     	strh	w8, [x19, x20]
100000b44:     	add	x20, x20, #0x2
100000b48:     	b	0x100000a30 <_main+0x410>
100000b4c:     	adrp	x1, 0x100001000 <_main+0x9e0>
100000b50:     	add	x1, x1, #0xe00
100000b54:     	b	0x1000009d0 <_main+0x3b0>
100000b58:     	mov	x3, x30
100000b5c:     	bl	0x100001a80 <_main+0x1460>
100000b60:     	mov	x30, x3
100000b64:     	stp	x29, x30, [sp, #0x90]
100000b68:     	mov	x20, x0
100000b6c:     	mov	x19, x8
100000b70:     	ldr	x0, [x1]
100000b74:     	ldr	w25, [x1, #0x8]
100000b78:     	ldrb	w23, [x1, #0xc]
100000b7c:     	mov	w8, #0x7fffffff         ; =2147483647
100000b80:     	cmp	w25, w8
100000b84:     	b.ne	0x100000bbc <_main+0x59c>
100000b88:     	str	x0, [sp, #0x8]
100000b8c:     	str	w8, [sp, #0x10]
100000b90:     	strb	w23, [sp, #0x14]
100000b94:     	ldurh	w8, [x1, #0xd]
100000b98:     	sturh	w8, [sp, #0x15]
100000b9c:     	ldurb	w8, [x1, #0xf]
100000ba0:     	strb	w8, [sp, #0x17]
100000ba4:     	add	x1, sp, #0x8
100000ba8:     	mov	x0, x20
100000bac:     	bl	0x100001394 <_main+0xd74>
100000bb0:     	strh	wzr, [x19, #0x10]
100000bb4:     	stp	x0, x1, [x19]
100000bb8:     	b	0x100000d98 <_main+0x778>
100000bbc:     	mov	x21, x2
100000bc0:     	ldrb	w24, [x2, #0x8]
100000bc4:     	cbz	w24, 0x100000bec <_main+0x5cc>
100000bc8:     	ldr	x2, [x21]
100000bcc:     	str	x0, [sp, #0x18]
100000bd0:     	str	w25, [sp, #0x20]
100000bd4:     	bl	0x1000019b8 <_main+0x1398>
100000bd8:     	mov	w1, #0x0                ; =0
100000bdc:     	bl	0x100001264 <_main+0xc44>
100000be0:     	ldr	x0, [sp, #0x28]
100000be4:     	ldr	w25, [sp, #0x30]
100000be8:     	ldrb	w23, [sp, #0x34]
100000bec:     	str	x0, [sp, #0x38]
100000bf0:     	bl	0x1000010e4 <_main+0xac4>
100000bf4:     	mov	x22, x0
100000bf8:     	tbnz	w25, #0x1f, 0x100000c10 <_main+0x5f0>
100000bfc:     	add	w8, w25, #0x2
100000c00:     	add	x8, x8, w22, uxtw
100000c04:     	cbz	w24, 0x100000c20 <_main+0x600>
100000c08:     	ldr	x9, [x21]
100000c0c:     	b	0x100000c24 <_main+0x604>
100000c10:     	sub	w8, w22, w25
100000c14:     	cbz	w24, 0x100000c2c <_main+0x60c>
100000c18:     	ldr	x9, [x21]
100000c1c:     	b	0x100000c30 <_main+0x610>
100000c20:     	mov	x9, #0x0                ; =0
100000c24:     	add	x8, x8, x9
100000c28:     	b	0x100000c3c <_main+0x61c>
100000c2c:     	mov	x9, #0x0                ; =0
100000c30:     	cmp	x8, x9
100000c34:     	csel	x8, x8, x9, hi
100000c38:     	add	x8, x8, #0x2
100000c3c:     	cmp	x8, #0x15b
100000c40:     	b.ls	0x100000c4c <_main+0x62c>
100000c44:     	bl	0x1000019d8 <_main+0x13b8>
100000c48:     	b	0x100000d98 <_main+0x778>
100000c4c:     	tbz	w23, #0x0, 0x100000c60 <_main+0x640>
100000c50:     	mov	w8, #0x2d               ; =45
100000c54:     	strb	w8, [x20]
100000c58:     	mov	w26, #0x1               ; =1
100000c5c:     	b	0x100000c64 <_main+0x644>
100000c60:     	mov	x26, #0x0               ; =0
100000c64:     	add	w23, w22, w25
100000c68:     	cmp	w23, #0x1
100000c6c:     	b.lt	0x100000cd8 <_main+0x6b8>
100000c70:     	mov	w24, w22
100000c74:     	cmp	w23, w22
100000c78:     	b.hs	0x100000d44 <_main+0x724>
100000c7c:     	add	x27, x26, x23
100000c80:     	add	x25, x27, #0x1
100000c84:     	sub	x24, x24, x23
100000c88:     	add	x0, x20, x25
100000c8c:     	add	x1, sp, #0x38
100000c90:     	mov	x2, x24
100000c94:     	bl	0x10000105c <_main+0xa3c>
100000c98:     	mov	w8, #0x2e               ; =46
100000c9c:     	strb	w8, [x20, x27]
100000ca0:     	bl	0x1000019f4 <_main+0x13d4>
100000ca4:     	add	w8, w22, #0x1
100000ca8:     	add	x8, x26, x8
100000cac:     	ldrb	w9, [x21, #0x8]
100000cb0:     	cbz	w9, 0x100000d90 <_main+0x770>
100000cb4:     	ldr	x21, [x21]
100000cb8:     	subs	x2, x21, x24
100000cbc:     	b.ls	0x100000cc8 <_main+0x6a8>
100000cc0:     	add	x0, x20, x8
100000cc4:     	bl	0x100001a5c <_main+0x143c>
100000cc8:     	cmp	x21, #0x0
100000ccc:     	cset	w8, eq
100000cd0:     	add	x9, x21, x25
100000cd4:     	b	0x100000d3c <_main+0x71c>
100000cd8:     	mov	w8, #0x2e30             ; =11824
100000cdc:     	strh	w8, [x20, x26]
100000ce0:     	orr	x24, x26, #0x2
100000ce4:     	neg	w23, w23
100000ce8:     	add	x0, x20, x24
100000cec:     	mov	w1, #0x30               ; =48
100000cf0:     	mov	x2, x23
100000cf4:     	bl	0x10000093c <_main+0x31c>
100000cf8:     	add	x23, x24, x23
100000cfc:     	mov	w2, w22
100000d00:     	add	x0, x20, x23
100000d04:     	add	x1, sp, #0x38
100000d08:     	bl	0x10000105c <_main+0xa3c>
100000d0c:     	add	x8, x23, w22, uxtw
100000d10:     	ldrb	w9, [x21, #0x8]
100000d14:     	cbz	w9, 0x100000d90 <_main+0x770>
100000d18:     	ldr	x21, [x21]
100000d1c:     	sub	x9, x8, x24
100000d20:     	subs	x2, x21, x9
100000d24:     	b.ls	0x100000d30 <_main+0x710>
100000d28:     	add	x0, x20, x8
100000d2c:     	bl	0x100001a5c <_main+0x143c>
100000d30:     	cmp	x21, #0x0
100000d34:     	cset	w8, eq
100000d38:     	add	x9, x21, x24
100000d3c:     	sub	x8, x9, x8
100000d40:     	b	0x100000d90 <_main+0x770>
100000d44:     	add	x22, x20, x26
100000d48:     	add	x1, sp, #0x38
100000d4c:     	mov	x0, x22
100000d50:     	mov	x2, x24
100000d54:     	bl	0x10000105c <_main+0xa3c>
100000d58:     	sxtw	x2, w25
100000d5c:     	add	x0, x22, x24
100000d60:     	bl	0x100001a5c <_main+0x143c>
100000d64:     	add	x8, x26, x23
100000d68:     	ldrb	w9, [x21, #0x8]
100000d6c:     	cbz	w9, 0x100000d90 <_main+0x770>
100000d70:     	ldr	x21, [x21]
100000d74:     	cbz	x21, 0x100000d90 <_main+0x770>
100000d78:     	mov	w9, #0x2e               ; =46
100000d7c:     	strb	w9, [x20, x8]
100000d80:     	add	x22, x8, #0x1
100000d84:     	add	x0, x20, x22
100000d88:     	bl	0x100001a50 <_main+0x1430>
100000d8c:     	add	x8, x21, x22
100000d90:     	strh	wzr, [x19, #0x10]
100000d94:     	stp	x20, x8, [x19]
100000d98:     	ldp	x29, x30, [sp, #0x90]
100000d9c:     	b	0x100001988 <_main+0x1368>
100000da0:     	mov	x3, x30
100000da4:     	bl	0x100001a80 <_main+0x1460>
100000da8:     	mov	x30, x3
100000dac:     	stp	x29, x30, [sp, #0x90]
100000db0:     	mov	x20, x0
100000db4:     	mov	x19, x8
100000db8:     	ldr	x0, [x1]
100000dbc:     	ldr	w24, [x1, #0x8]
100000dc0:     	ldrb	w23, [x1, #0xc]
100000dc4:     	mov	w8, #0x7fffffff         ; =2147483647
100000dc8:     	cmp	w24, w8
100000dcc:     	b.ne	0x100000e04 <_main+0x7e4>
100000dd0:     	str	x0, [sp, #0x8]
100000dd4:     	str	w8, [sp, #0x10]
100000dd8:     	strb	w23, [sp, #0x14]
100000ddc:     	ldurh	w8, [x1, #0xd]
100000de0:     	sturh	w8, [sp, #0x15]
100000de4:     	ldurb	w8, [x1, #0xf]
100000de8:     	strb	w8, [sp, #0x17]
100000dec:     	add	x1, sp, #0x8
100000df0:     	mov	x0, x20
100000df4:     	bl	0x100001394 <_main+0xd74>
100000df8:     	strh	wzr, [x19, #0x10]
100000dfc:     	stp	x0, x1, [x19]
100000e00:     	b	0x100001054 <_main+0xa34>
100000e04:     	mov	x21, x2
100000e08:     	ldrb	w25, [x2, #0x8]
100000e0c:     	cbz	w25, 0x100000e34 <_main+0x814>
100000e10:     	ldr	x2, [x21]
100000e14:     	str	x0, [sp, #0x18]
100000e18:     	str	w24, [sp, #0x20]
100000e1c:     	bl	0x1000019b8 <_main+0x1398>
100000e20:     	mov	w1, #0x1                ; =1
100000e24:     	bl	0x100001264 <_main+0xc44>
100000e28:     	ldr	x0, [sp, #0x28]
100000e2c:     	ldr	w24, [sp, #0x30]
100000e30:     	ldrb	w23, [sp, #0x34]
100000e34:     	str	x0, [sp, #0x38]
100000e38:     	bl	0x1000010e4 <_main+0xac4>
100000e3c:     	mov	x22, x0
100000e40:     	cbz	w25, 0x100000e58 <_main+0x838>
100000e44:     	ldr	x8, [x21]
100000e48:     	cmp	x8, #0x154
100000e4c:     	b.lo	0x100000e58 <_main+0x838>
100000e50:     	bl	0x1000019d8 <_main+0x13b8>
100000e54:     	b	0x100001054 <_main+0xa34>
100000e58:     	tbz	w23, #0x0, 0x100000e6c <_main+0x84c>
100000e5c:     	mov	w8, #0x2d               ; =45
100000e60:     	strb	w8, [x20]
100000e64:     	mov	w27, #0x1               ; =1
100000e68:     	b	0x100000e70 <_main+0x850>
100000e6c:     	mov	x27, #0x0               ; =0
100000e70:     	orr	x26, x27, #0x2
100000e74:     	subs	w23, w22, #0x1
100000e78:     	add	x8, x26, x23
100000e7c:     	csinc	x25, x8, x27, hi
100000e80:     	bl	0x1000019f4 <_main+0x13d4>
100000e84:     	add	x8, x20, x27
100000e88:     	ldr	x9, [sp, #0x38]
100000e8c:     	mov	w10, #0xa               ; =10
100000e90:     	udiv	x11, x9, x10
100000e94:     	msub	w9, w11, w10, w9
100000e98:     	orr	w9, w9, #0x30
100000e9c:     	strb	w9, [x8]
100000ea0:     	mov	w9, #0x2e               ; =46
100000ea4:     	strb	w9, [x8, #0x1]
100000ea8:     	ldrb	w8, [x21, #0x8]
100000eac:     	cbz	w8, 0x100000ee4 <_main+0x8c4>
100000eb0:     	ldr	x8, [x21]
100000eb4:     	subs	x21, x8, x23
100000eb8:     	b.ls	0x100000ed4 <_main+0x8b4>
100000ebc:     	cmp	w22, #0x1
100000ec0:     	cinc	x23, x25, eq
100000ec4:     	add	x0, x20, x23
100000ec8:     	bl	0x100001a50 <_main+0x1430>
100000ecc:     	add	x25, x21, x23
100000ed0:     	b	0x100000ee4 <_main+0x8c4>
100000ed4:     	cmp	x8, #0x0
100000ed8:     	cset	w9, eq
100000edc:     	add	x8, x8, x26
100000ee0:     	sub	x25, x8, x9
100000ee4:     	mov	w8, #0x65               ; =101
100000ee8:     	strb	w8, [x20, x25]
100000eec:     	add	x8, x25, #0x1
100000ef0:     	add	w10, w22, w24
100000ef4:     	subs	w9, w10, #0x1
100000ef8:     	b.ge	0x100000f10 <_main+0x8f0>
100000efc:     	mov	w9, #0x2d               ; =45
100000f00:     	strb	w9, [x20, x8]
100000f04:     	add	x8, x25, #0x2
100000f08:     	mov	w9, #0x1                ; =1
100000f0c:     	sub	w9, w9, w10
100000f10:     	mov	w10, #0xa               ; =10
100000f14:     	mov	w11, #0xc9ff            ; =51711
100000f18:     	movk	w11, #0x3b9a, lsl #16
100000f1c:     	cmp	w9, w11
100000f20:     	b.ls	0x100000f2c <_main+0x90c>
100000f24:     	mov	w11, #0xa               ; =10
100000f28:     	b	0x100000fc8 <_main+0x9a8>
100000f2c:     	mov	w11, #0xe0ff            ; =57599
100000f30:     	movk	w11, #0x5f5, lsl #16
100000f34:     	cmp	w9, w11
100000f38:     	b.ls	0x100000f44 <_main+0x924>
100000f3c:     	mov	w11, #0x9               ; =9
100000f40:     	b	0x100000fc8 <_main+0x9a8>
100000f44:     	mov	w11, #0x967f            ; =38527
100000f48:     	movk	w11, #0x98, lsl #16
100000f4c:     	cmp	w9, w11
100000f50:     	b.ls	0x100000f5c <_main+0x93c>
100000f54:     	mov	w11, #0x8               ; =8
100000f58:     	b	0x100000fc8 <_main+0x9a8>
100000f5c:     	mov	w11, #0x423f            ; =16959
100000f60:     	movk	w11, #0xf, lsl #16
100000f64:     	cmp	w9, w11
100000f68:     	b.ls	0x100000f74 <_main+0x954>
100000f6c:     	mov	w11, #0x7               ; =7
100000f70:     	b	0x100000fc8 <_main+0x9a8>
100000f74:     	lsr	w11, w9, #5
100000f78:     	cmp	w11, #0xc34
100000f7c:     	b.ls	0x100000f88 <_main+0x968>
100000f80:     	mov	w11, #0x6               ; =6
100000f84:     	b	0x100000fc8 <_main+0x9a8>
100000f88:     	lsr	w11, w9, #4
100000f8c:     	cmp	w11, #0x270
100000f90:     	b.ls	0x100000f9c <_main+0x97c>
100000f94:     	mov	w11, #0x5               ; =5
100000f98:     	b	0x100000fc8 <_main+0x9a8>
100000f9c:     	cmp	w9, #0x3e7
100000fa0:     	b.ls	0x100000fac <_main+0x98c>
100000fa4:     	mov	w11, #0x4               ; =4
100000fa8:     	b	0x100000fc8 <_main+0x9a8>
100000fac:     	cmp	w9, #0x63
100000fb0:     	b.ls	0x100000fbc <_main+0x99c>
100000fb4:     	mov	w11, #0x3               ; =3
100000fb8:     	b	0x100000fc8 <_main+0x9a8>
100000fbc:     	cmp	w9, #0x9
100000fc0:     	mov	w11, #0x1               ; =1
100000fc4:     	cinc	x11, x11, hi
100000fc8:     	mov	x13, #0x0               ; =0
100000fcc:     	add	x12, x11, x8
100000fd0:     	sub	x12, x12, #0x1
100000fd4:     	mov	w14, #0x64              ; =100
100000fd8:     	add	x15, x13, #0x2
100000fdc:     	cmp	x15, x11
100000fe0:     	b.hs	0x10000101c <_main+0x9fc>
100000fe4:     	udiv	w13, w9, w14
100000fe8:     	msub	w9, w13, w14, w9
100000fec:     	and	w16, w9, #0xff
100000ff0:     	udiv	w16, w16, w10
100000ff4:     	orr	w17, w16, #0x30
100000ff8:     	msub	w9, w16, w10, w9
100000ffc:     	orr	w9, w9, #0x30
100001000:     	add	x16, x20, x12
100001004:     	strb	w9, [x16]
100001008:     	sturb	w17, [x16, #-0x1]
10000100c:     	sub	x12, x12, #0x2
100001010:     	mov	x9, x13
100001014:     	mov	x13, x15
100001018:     	b	0x100000fd8 <_main+0x9b8>
10000101c:     	mov	w10, #0xa               ; =10
100001020:     	cmp	x13, x11
100001024:     	b.hs	0x100001048 <_main+0xa28>
100001028:     	udiv	w14, w9, w10
10000102c:     	msub	w9, w14, w10, w9
100001030:     	orr	w9, w9, #0x30
100001034:     	strb	w9, [x20, x12]
100001038:     	add	x13, x13, #0x1
10000103c:     	sub	x12, x12, #0x1
100001040:     	mov	x9, x14
100001044:     	b	0x100001020 <_main+0xa00>
100001048:     	add	x8, x11, x8
10000104c:     	strh	wzr, [x19, #0x10]
100001050:     	stp	x20, x8, [x19]
100001054:     	ldp	x29, x30, [sp, #0x90]
100001058:     	b	0x100001988 <_main+0x1368>
10000105c:     	mov	x9, #0x0                ; =0
100001060:     	add	x8, x2, x0
100001064:     	sub	x8, x8, #0x1
100001068:     	mov	w10, #0x64              ; =100
10000106c:     	mov	w11, #0xa               ; =10
100001070:     	add	x12, x9, #0x2
100001074:     	cmp	x12, x2
100001078:     	b.hs	0x1000010b4 <_main+0xa94>
10000107c:     	ldr	x9, [x1]
100001080:     	udiv	x13, x9, x10
100001084:     	msub	w9, w13, w10, w9
100001088:     	and	w14, w9, #0xff
10000108c:     	str	x13, [x1]
100001090:     	udiv	w13, w14, w11
100001094:     	orr	w14, w13, #0x30
100001098:     	msub	w9, w13, w11, w9
10000109c:     	orr	w9, w9, #0x30
1000010a0:     	strb	w9, [x8]
1000010a4:     	sturb	w14, [x8, #-0x1]
1000010a8:     	sub	x8, x8, #0x2
1000010ac:     	mov	x9, x12
1000010b0:     	b	0x100001070 <_main+0xa50>
1000010b4:     	mov	w10, #0xa               ; =10
1000010b8:     	cmp	x9, x2
1000010bc:     	b.hs	0x1000010e0 <_main+0xac0>
1000010c0:     	ldr	x11, [x1]
1000010c4:     	udiv	x12, x11, x10
1000010c8:     	msub	w11, w12, w10, w11
1000010cc:     	str	x12, [x1]
1000010d0:     	orr	w11, w11, #0x30
1000010d4:     	strb	w11, [x8], #-0x1
1000010d8:     	add	x9, x9, #0x1
1000010dc:     	b	0x1000010b8 <_main+0xa98>
1000010e0:     	ret
1000010e4:     	mov	x8, #0x6fc10000         ; =1874919424
1000010e8:     	movk	x8, #0x86f2, lsl #32
1000010ec:     	movk	x8, #0x23, lsl #48
1000010f0:     	cmp	x0, x8
1000010f4:     	b.lo	0x100001100 <_main+0xae0>
1000010f8:     	mov	w0, #0x11               ; =17
1000010fc:     	ret
100001100:     	mov	x8, #0x7fff             ; =32767
100001104:     	movk	x8, #0xa4c6, lsl #16
100001108:     	movk	x8, #0x8d7e, lsl #32
10000110c:     	movk	x8, #0x3, lsl #48
100001110:     	cmp	x0, x8
100001114:     	b.ls	0x100001120 <_main+0xb00>
100001118:     	mov	w0, #0x10               ; =16
10000111c:     	ret
100001120:     	mov	x8, #0x3fff             ; =16383
100001124:     	movk	x8, #0x107a, lsl #16
100001128:     	movk	x8, #0x5af3, lsl #32
10000112c:     	cmp	x0, x8
100001130:     	b.ls	0x10000113c <_main+0xb1c>
100001134:     	mov	w0, #0xf                ; =15
100001138:     	ret
10000113c:     	mov	x8, #0x9fff             ; =40959
100001140:     	movk	x8, #0x4e72, lsl #16
100001144:     	movk	x8, #0x918, lsl #32
100001148:     	cmp	x0, x8
10000114c:     	b.ls	0x100001158 <_main+0xb38>
100001150:     	mov	w0, #0xe                ; =14
100001154:     	ret
100001158:     	mov	x8, #0xfff              ; =4095
10000115c:     	movk	x8, #0xd4a5, lsl #16
100001160:     	movk	x8, #0xe8, lsl #32
100001164:     	cmp	x0, x8
100001168:     	b.ls	0x100001174 <_main+0xb54>
10000116c:     	mov	w0, #0xd                ; =13
100001170:     	ret
100001174:     	mov	x8, #0xe7ff             ; =59391
100001178:     	movk	x8, #0x4876, lsl #16
10000117c:     	movk	x8, #0x17, lsl #32
100001180:     	cmp	x0, x8
100001184:     	b.ls	0x100001190 <_main+0xb70>
100001188:     	mov	w0, #0xc                ; =12
10000118c:     	ret
100001190:     	mov	x8, #0xe3ff             ; =58367
100001194:     	movk	x8, #0x540b, lsl #16
100001198:     	movk	x8, #0x2, lsl #32
10000119c:     	cmp	x0, x8
1000011a0:     	b.ls	0x1000011ac <_main+0xb8c>
1000011a4:     	mov	w0, #0xb                ; =11
1000011a8:     	ret
1000011ac:     	mov	w8, #0xc9ff             ; =51711
1000011b0:     	movk	w8, #0x3b9a, lsl #16
1000011b4:     	cmp	x0, x8
1000011b8:     	b.ls	0x1000011c4 <_main+0xba4>
1000011bc:     	mov	w0, #0xa                ; =10
1000011c0:     	ret
1000011c4:     	mov	w8, #0xe0ff             ; =57599
1000011c8:     	movk	w8, #0x5f5, lsl #16
1000011cc:     	cmp	x0, x8
1000011d0:     	b.ls	0x1000011dc <_main+0xbbc>
1000011d4:     	mov	w0, #0x9                ; =9
1000011d8:     	ret
1000011dc:     	mov	w8, #0x967f             ; =38527
1000011e0:     	movk	w8, #0x98, lsl #16
1000011e4:     	cmp	x0, x8
1000011e8:     	b.ls	0x1000011f4 <_main+0xbd4>
1000011ec:     	mov	w0, #0x8                ; =8
1000011f0:     	ret
1000011f4:     	mov	w8, #0x423f             ; =16959
1000011f8:     	movk	w8, #0xf, lsl #16
1000011fc:     	cmp	x0, x8
100001200:     	b.ls	0x10000120c <_main+0xbec>
100001204:     	mov	w0, #0x7                ; =7
100001208:     	ret
10000120c:     	lsr	x8, x0, #5
100001210:     	cmp	x8, #0xc34
100001214:     	b.ls	0x100001220 <_main+0xc00>
100001218:     	mov	w0, #0x6                ; =6
10000121c:     	ret
100001220:     	lsr	x8, x0, #4
100001224:     	cmp	x8, #0x270
100001228:     	b.ls	0x100001234 <_main+0xc14>
10000122c:     	mov	w0, #0x5                ; =5
100001230:     	ret
100001234:     	cmp	x0, #0x3e7
100001238:     	b.ls	0x100001244 <_main+0xc24>
10000123c:     	mov	w0, #0x4                ; =4
100001240:     	ret
100001244:     	cmp	x0, #0x63
100001248:     	b.ls	0x100001254 <_main+0xc34>
10000124c:     	mov	w0, #0x3                ; =3
100001250:     	ret
100001254:     	cmp	x0, #0x9
100001258:     	mov	w8, #0x1                ; =1
10000125c:     	cinc	w0, w8, hi
100001260:     	ret
100001264:     	stp	x26, x25, [sp, #-0x50]!
100001268:     	stp	x24, x23, [sp, #0x10]
10000126c:     	stp	x22, x21, [sp, #0x20]
100001270:     	stp	x20, x19, [sp, #0x30]
100001274:     	stp	x29, x30, [sp, #0x40]
100001278:     	mov	x21, x2
10000127c:     	mov	x22, x1
100001280:     	mov	x19, x8
100001284:     	ldr	x20, [x0]
100001288:     	ldr	w23, [x0, #0x8]
10000128c:     	ldrb	w24, [x0, #0xc]
100001290:     	mov	x0, x20
100001294:     	bl	0x1000010e4 <_main+0xac4>
100001298:     	sub	w8, w0, #0x1
10000129c:     	add	x9, x21, x23
1000012a0:     	add	x8, x9, x8
1000012a4:     	add	x9, x21, w0, uxtw
1000012a8:     	neg	w10, w23
1000012ac:     	subs	x9, x9, x10
1000012b0:     	csel	x9, xzr, x9, lo
1000012b4:     	cmp	w23, #0x0
1000012b8:     	csel	x8, x8, x9, gt
1000012bc:     	tst	w22, #0x1
1000012c0:     	csinc	x8, x8, x21, eq
1000012c4:     	cmp	x8, w0, uxtw
1000012c8:     	b.hs	0x10000136c <_main+0xd4c>
1000012cc:     	mov	w9, w0
1000012d0:     	mvn	x8, x8
1000012d4:     	add	x8, x8, x9
1000012d8:     	mov	w9, #0xa                ; =10
1000012dc:     	cbz	x8, 0x1000012f0 <_main+0xcd0>
1000012e0:     	add	w23, w23, #0x1
1000012e4:     	sub	x8, x8, #0x1
1000012e8:     	udiv	x20, x20, x9
1000012ec:     	cbnz	x8, 0x1000012e0 <_main+0xcc0>
1000012f0:     	mov	w9, #0xa                ; =10
1000012f4:     	udiv	x8, x20, x9
1000012f8:     	msub	x9, x8, x9, x20
1000012fc:     	cmp	x9, #0x5
100001300:     	b.lo	0x10000136c <_main+0xd4c>
100001304:     	mov	x21, #0x0               ; =0
100001308:     	add	x20, x8, #0x1
10000130c:     	mov	w25, #0xa               ; =10
100001310:     	mov	x22, x20
100001314:     	orr	x26, x22, x21
100001318:     	mov	x0, x22
10000131c:     	mov	x1, x21
100001320:     	mov	w2, #0xa                ; =10
100001324:     	mov	x3, #0x0                ; =0
100001328:     	bl	0x100000898 <_main+0x278>
10000132c:     	umulh	x8, x0, x25
100001330:     	madd	x9, x1, x25, x8
100001334:     	add	x8, x0, x0, lsl #2
100001338:     	subs	x8, x22, x8, lsl #1
10000133c:     	sbc	x9, x21, x9
100001340:     	cbz	x26, 0x100001354 <_main+0xd34>
100001344:     	mov	x22, x0
100001348:     	mov	x21, x1
10000134c:     	orr	x8, x8, x9
100001350:     	cbz	x8, 0x100001314 <_main+0xcf4>
100001354:     	cbz	x26, 0x100001360 <_main+0xd40>
100001358:     	add	w23, w23, #0x1
10000135c:     	b	0x10000136c <_main+0xd4c>
100001360:     	mov	w8, #0xa                ; =10
100001364:     	add	w23, w23, #0x2
100001368:     	udiv	x20, x20, x8
10000136c:     	str	x20, [x19]
100001370:     	str	w23, [x19, #0x8]
100001374:     	and	w8, w24, #0x1
100001378:     	strb	w8, [x19, #0xc]
10000137c:     	ldp	x29, x30, [sp, #0x40]
100001380:     	ldp	x20, x19, [sp, #0x30]
100001384:     	ldp	x22, x21, [sp, #0x20]
100001388:     	ldp	x24, x23, [sp, #0x10]
10000138c:     	ldp	x26, x25, [sp], #0x50
100001390:     	ret
100001394:     	ldr	x9, [x1]
100001398:     	ldrb	w8, [x1, #0xc]
10000139c:     	tbz	w8, #0x0, 0x1000013a8 <_main+0xd88>
1000013a0:     	mov	w10, #0x2d              ; =45
1000013a4:     	strb	w10, [x0]
1000013a8:     	and	x10, x8, #0x1
1000013ac:     	add	x10, x0, x10
1000013b0:     	cbz	x9, 0x1000013c4 <_main+0xda4>
1000013b4:     	mov	w9, #0x6e               ; =110
1000013b8:     	strb	w9, [x10, #0x2]
1000013bc:     	mov	w9, #0x616e             ; =24942
1000013c0:     	b	0x1000013d0 <_main+0xdb0>
1000013c4:     	mov	w9, #0x66               ; =102
1000013c8:     	strb	w9, [x10, #0x2]
1000013cc:     	mov	w9, #0x6e69             ; =28265
1000013d0:     	strh	w9, [x10]
1000013d4:     	tst	w8, #0x1
1000013d8:     	mov	w8, #0x3                ; =3
1000013dc:     	cinc	x1, x8, ne
1000013e0:     	ret
1000013e4:     	mov	x3, x30
1000013e8:     	bl	0x100001a80 <_main+0x1460>
1000013ec:     	mov	x30, x3
1000013f0:     	stp	x29, x30, [sp, #0x90]
1000013f4:     	mov	x22, x2
1000013f8:     	mov	x21, x1
1000013fc:     	mov	x20, x0
100001400:     	mov	x19, x8
100001404:     	mov	w8, #0x1                ; =1
100001408:     	lsl	x8, x8, x1
10000140c:     	sub	x9, x8, #0x1
100001410:     	and	x9, x9, x0
100001414:     	lsr	x10, x0, x1
100001418:     	and	x11, x2, #0x1f
10000141c:     	mov	x12, #-0x1              ; =-1
100001420:     	lsl	x11, x12, x11
100001424:     	bic	x11, x10, x11
100001428:     	orr	x10, x11, x9
10000142c:     	cbnz	x10, 0x10000143c <_main+0xe1c>
100001430:     	str	xzr, [x19]
100001434:     	str	wzr, [x19, #0x8]
100001438:     	b	0x1000018d0 <_main+0x12b0>
10000143c:     	mov	w10, #-0x1              ; =-1
100001440:     	lsl	w12, w10, w22
100001444:     	eor	w12, w12, w11
100001448:     	cmn	w12, #0x1
10000144c:     	b.eq	0x100001500 <_main+0xee0>
100001450:     	sub	w12, w22, #0x1
100001454:     	lsl	w10, w10, w12
100001458:     	and	w12, w21, #0x3f
10000145c:     	mvn	w13, w12
100001460:     	add	w13, w10, w13
100001464:     	add	w13, w13, w11
100001468:     	orr	x8, x9, x8
10000146c:     	sub	w10, w10, w12
100001470:     	cmp	x11, #0x0
100001474:     	csel	x12, x8, x9, ne
100001478:     	csel	w10, w13, w10, ne
10000147c:     	str	x12, [sp, #0x18]
100001480:     	mov	x8, #0xcd1b             ; =52507
100001484:     	movk	x8, #0x784b, lsl #16
100001488:     	movk	x8, #0x949a, lsl #32
10000148c:     	lsl	x24, x12, #2
100001490:     	cmp	x9, #0x0
100001494:     	ccmp	x11, #0x0, #0x4, eq
100001498:     	cset	w28, eq
10000149c:     	tbnz	w10, #0x1f, 0x10000150c <_main+0xeec>
1000014a0:     	mov	x9, #0xfbcf             ; =64463
1000014a4:     	movk	x9, #0x9a84, lsl #16
1000014a8:     	movk	x9, #0x9a20, lsl #32
1000014ac:     	mul	x9, x10, x9
1000014b0:     	lsr	x9, x9, #49
1000014b4:     	cmp	w10, #0x3
1000014b8:     	cset	w11, hi
1000014bc:     	sub	w23, w9, w11
1000014c0:     	sub	w10, w23, w10
1000014c4:     	mul	x9, x23, x8
1000014c8:     	lsr	x9, x9, #46
1000014cc:     	add	w26, w10, w9
1000014d0:     	add	w10, w23, #0x19
1000014d4:     	and	w10, w10, #0xffff
1000014d8:     	mov	w11, #0x1a              ; =26
1000014dc:     	udiv	w12, w10, w11
1000014e0:     	mul	w10, w12, w11
1000014e4:     	adrp	x11, 0x100001000 <_main+0x9e0>
1000014e8:     	add	x11, x11, #0xc40
1000014ec:     	add	x11, x11, w12, uxtw #4
1000014f0:     	subs	w12, w10, w23
1000014f4:     	b.ne	0x100001578 <_main+0xf58>
1000014f8:     	ldp	x8, x9, [x11]
1000014fc:     	b	0x100001630 <_main+0x1010>
100001500:     	str	x9, [x19]
100001504:     	mov	w8, #0x7fffffff         ; =2147483647
100001508:     	b	0x1000018cc <_main+0x12ac>
10000150c:     	str	w28, [sp, #0x14]
100001510:     	neg	w9, w10
100001514:     	mov	x11, #0x8218            ; =33304
100001518:     	movk	x11, #0xb2bd, lsl #16
10000151c:     	movk	x11, #0xb2ef, lsl #32
100001520:     	mul	x11, x9, x11
100001524:     	lsr	x11, x11, #48
100001528:     	cmn	w10, #0x1
10000152c:     	cset	w12, ne
100001530:     	sub	w28, w11, w12
100001534:     	add	w14, w28, w10
100001538:     	sub	w9, w9, w28
10000153c:     	mul	x10, x9, x8
100001540:     	lsr	x10, x10, #46
100001544:     	sub	w26, w28, w10
100001548:     	and	w11, w9, #0xffff
10000154c:     	mov	w12, #0x1a              ; =26
100001550:     	udiv	w13, w11, w12
100001554:     	mul	w11, w13, w12
100001558:     	adrp	x12, 0x100001000 <_main+0x9e0>
10000155c:     	add	x12, x12, #0xd30
100001560:     	add	x12, x12, w13, uxtw #4
100001564:     	subs	w13, w9, w11
100001568:     	str	x14, [sp, #0x8]
10000156c:     	b.ne	0x1000016ac <_main+0x108c>
100001570:     	ldp	x8, x9, [x12]
100001574:     	b	0x100001760 <_main+0x1140>
100001578:     	adrp	x13, 0x100001000 <_main+0x9e0>
10000157c:     	add	x13, x13, #0xad0
100001580:     	ldr	x12, [x13, w12, uxtw #3]
100001584:     	ldp	x13, x11, [x11]
100001588:     	sub	x13, x13, #0x1
10000158c:     	umulh	x14, x13, x12
100001590:     	mul	x13, x13, x12
100001594:     	mul	x15, x11, x12
100001598:     	umulh	x11, x11, x12
10000159c:     	mul	x8, x10, x8
1000015a0:     	lsr	x8, x8, #46
1000015a4:     	sub	w8, w8, w9
1000015a8:     	mvn	w9, w8
1000015ac:     	lsr	x10, x13, x8
1000015b0:     	lsl	x12, x14, #1
1000015b4:     	lsl	x9, x12, x9
1000015b8:     	orr	x9, x9, x10
1000015bc:     	lsr	x10, x14, x8
1000015c0:     	tst	x8, #0x40
1000015c4:     	csel	x9, x10, x9, ne
1000015c8:     	csel	x10, xzr, x10, ne
1000015cc:     	mov	w12, #0x40              ; =64
1000015d0:     	sub	w8, w12, w8
1000015d4:     	mvn	w12, w8
1000015d8:     	lsl	x11, x11, x8
1000015dc:     	lsr	x13, x15, #1
1000015e0:     	lsr	x12, x13, x12
1000015e4:     	orr	x11, x11, x12
1000015e8:     	lsl	x12, x15, x8
1000015ec:     	and	x8, x8, #0x7f
1000015f0:     	tst	x8, #0x40
1000015f4:     	csel	x8, x12, x11, ne
1000015f8:     	csel	x11, xzr, x12, ne
1000015fc:     	adrp	x12, 0x100001000 <_main+0x9e0>
100001600:     	add	x12, x12, #0xbf4
100001604:     	lsr	w13, w23, #4
100001608:     	ldr	w12, [x12, w13, uxtw #2]
10000160c:     	ubfiz	w13, w23, #1, #4
100001610:     	lsr	w12, w12, w13
100001614:     	and	w12, w12, #0x3
100001618:     	adds	x9, x11, x9
10000161c:     	adc	x8, x8, x10
100001620:     	adds	x9, x9, x12
100001624:     	cinc	x10, x8, hs
100001628:     	adds	x8, x9, #0x1
10000162c:     	cinc	x9, x10, hs
100001630:     	stp	x8, x9, [sp, #0x20]
100001634:     	add	x1, sp, #0x20
100001638:     	add	w2, w26, #0x7d
10000163c:     	mov	x0, x24
100001640:     	bl	0x100001924 <_main+0x1304>
100001644:     	mov	x25, x0
100001648:     	orr	x0, x24, #0x2
10000164c:     	bl	0x100001a38 <_main+0x1418>
100001650:     	mov	x27, x0
100001654:     	cmp	w28, #0x0
100001658:     	mov	x8, #-0x2               ; =-2
10000165c:     	cinc	x28, x8, eq
100001660:     	add	x0, x28, x24
100001664:     	bl	0x100001a38 <_main+0x1418>
100001668:     	mov	x26, x0
10000166c:     	cmp	w23, #0x16
100001670:     	b.hs	0x1000016a0 <_main+0x1080>
100001674:     	mov	w8, #0x5                ; =5
100001678:     	udiv	x8, x24, x8
10000167c:     	add	x8, x8, x8, lsl #2
100001680:     	cmp	x24, x8
100001684:     	ldr	x8, [sp, #0x18]
100001688:     	b.eq	0x1000017e8 <_main+0x11c8>
10000168c:     	tbnz	w8, #0x0, 0x100001800 <_main+0x11e0>
100001690:     	add	x0, x28, x24
100001694:     	bl	0x100001a64 <_main+0x1444>
100001698:     	mov	w8, #0x0                ; =0
10000169c:     	b	0x10000181c <_main+0x11fc>
1000016a0:     	mov	w8, #0x0                ; =0
1000016a4:     	mov	w0, #0x0                ; =0
1000016a8:     	b	0x10000181c <_main+0x11fc>
1000016ac:     	adrp	x14, 0x100001000 <_main+0x9e0>
1000016b0:     	add	x14, x14, #0xad0
1000016b4:     	ldr	x13, [x14, w13, uxtw #3]
1000016b8:     	ldp	x14, x12, [x12]
1000016bc:     	umulh	x15, x14, x13
1000016c0:     	mul	x14, x14, x13
1000016c4:     	mul	x16, x12, x13
1000016c8:     	umulh	x12, x12, x13
1000016cc:     	mul	x8, x11, x8
1000016d0:     	lsr	x8, x8, #46
1000016d4:     	sub	w8, w10, w8
1000016d8:     	mvn	w10, w8
1000016dc:     	lsr	x11, x14, x8
1000016e0:     	lsl	x13, x15, #1
1000016e4:     	lsl	x10, x13, x10
1000016e8:     	orr	x10, x10, x11
1000016ec:     	lsr	x11, x15, x8
1000016f0:     	tst	x8, #0x40
1000016f4:     	csel	x10, x11, x10, ne
1000016f8:     	csel	x11, xzr, x11, ne
1000016fc:     	mov	w13, #0x40              ; =64
100001700:     	sub	w8, w13, w8
100001704:     	mvn	w13, w8
100001708:     	lsl	x12, x12, x8
10000170c:     	lsr	x14, x16, #1
100001710:     	lsr	x13, x14, x13
100001714:     	orr	x12, x12, x13
100001718:     	lsl	x13, x16, x8
10000171c:     	and	x8, x8, #0x7f
100001720:     	tst	x8, #0x40
100001724:     	csel	x8, x13, x12, ne
100001728:     	csel	x12, xzr, x13, ne
10000172c:     	adrp	x13, 0x100001000 <_main+0x9e0>
100001730:     	add	x13, x13, #0xba0
100001734:     	lsr	w14, w9, #4
100001738:     	ldr	w13, [x13, w14, uxtw #2]
10000173c:     	ubfiz	w9, w9, #1, #4
100001740:     	lsr	w9, w13, w9
100001744:     	and	w9, w9, #0x3
100001748:     	adds	x10, x10, x12
10000174c:     	adc	x8, x11, x8
100001750:     	adds	x9, x10, x9
100001754:     	cinc	x10, x8, hs
100001758:     	adds	x8, x9, #0x1
10000175c:     	cinc	x9, x10, hs
100001760:     	stp	x8, x9, [sp, #0x30]
100001764:     	add	x1, sp, #0x30
100001768:     	add	w2, w26, #0x7c
10000176c:     	mov	x0, x24
100001770:     	bl	0x100001924 <_main+0x1304>
100001774:     	mov	x25, x0
100001778:     	orr	x0, x24, #0x2
10000177c:     	bl	0x100001a44 <_main+0x1424>
100001780:     	mov	x27, x0
100001784:     	ldr	w23, [sp, #0x14]
100001788:     	cmp	w23, #0x0
10000178c:     	mov	x8, #-0x2               ; =-2
100001790:     	cinc	x8, x8, eq
100001794:     	add	x0, x8, x24
100001798:     	bl	0x100001a44 <_main+0x1424>
10000179c:     	mov	x26, x0
1000017a0:     	ldr	x14, [sp, #0x18]
1000017a4:     	ands	x8, x14, #0x1
1000017a8:     	cset	w9, eq
1000017ac:     	and	w9, w9, w23
1000017b0:     	sub	x10, x27, x8
1000017b4:     	mov	w8, #0x1                ; =1
1000017b8:     	mov	x11, #-0x1              ; =-1
1000017bc:     	lsl	x11, x11, x28
1000017c0:     	bics	xzr, x24, x11
1000017c4:     	cset	w11, eq
1000017c8:     	cmp	w28, #0x3e
1000017cc:     	csel	w11, wzr, w11, hi
1000017d0:     	cmp	w28, #0x2
1000017d4:     	csel	w8, w8, w11, lo
1000017d8:     	csel	w0, w9, wzr, lo
1000017dc:     	csel	x27, x10, x27, lo
1000017e0:     	ldr	x23, [sp, #0x8]
1000017e4:     	b	0x100001820 <_main+0x1200>
1000017e8:     	mov	x0, x24
1000017ec:     	bl	0x100001a64 <_main+0x1444>
1000017f0:     	ldr	x14, [sp, #0x18]
1000017f4:     	mov	x8, x0
1000017f8:     	mov	w0, #0x0                ; =0
1000017fc:     	b	0x100001820 <_main+0x1200>
100001800:     	orr	x0, x24, #0x2
100001804:     	bl	0x100001a64 <_main+0x1444>
100001808:     	mov	x9, x0
10000180c:     	mov	w8, #0x0                ; =0
100001810:     	mov	w0, #0x0                ; =0
100001814:     	and	x9, x9, #0x1
100001818:     	sub	x27, x27, x9
10000181c:     	ldr	x14, [sp, #0x18]
100001820:     	mov	w10, #0x0               ; =0
100001824:     	mov	w9, #0x0                ; =0
100001828:     	mov	w11, #0xa               ; =10
10000182c:     	udiv	x27, x27, x11
100001830:     	udiv	x12, x26, x11
100001834:     	cmp	x27, x12
100001838:     	b.ls	0x10000185c <_main+0x123c>
10000183c:     	msub	x13, x12, x11, x26
100001840:     	cmp	x13, #0x0
100001844:     	cset	w13, eq
100001848:     	and	w0, w0, w13
10000184c:     	tst	w10, #0xff
100001850:     	cset	w10, eq
100001854:     	bl	0x100001a04 <_main+0x13e4>
100001858:     	b	0x10000182c <_main+0x120c>
10000185c:     	tbz	w0, #0x0, 0x100001880 <_main+0x1260>
100001860:     	mov	w11, #0xa               ; =10
100001864:     	udiv	x12, x26, x11
100001868:     	msub	x13, x12, x11, x26
10000186c:     	cbnz	x13, 0x100001880 <_main+0x1260>
100001870:     	tst	w10, #0xff
100001874:     	cset	w10, eq
100001878:     	bl	0x100001a04 <_main+0x13e4>
10000187c:     	b	0x100001864 <_main+0x1244>
100001880:     	and	w11, w10, #0xff
100001884:     	cmp	w11, #0x5
100001888:     	cset	w11, eq
10000188c:     	tst	x25, #0x1
100001890:     	mov	w12, #0x4               ; =4
100001894:     	cinc	w12, w12, ne
100001898:     	tst	w8, w11
10000189c:     	csel	w8, w12, w10, ne
1000018a0:     	and	w8, w8, #0xff
1000018a4:     	cmp	x25, x26
1000018a8:     	cset	w10, eq
1000018ac:     	eor	w11, w0, #0x1
1000018b0:     	orr	w11, w14, w11
1000018b4:     	cmp	w8, #0x4
1000018b8:     	and	w8, w10, w11
1000018bc:     	csinc	w8, w8, wzr, ls
1000018c0:     	add	x8, x25, x8
1000018c4:     	str	x8, [x19]
1000018c8:     	add	w8, w9, w23
1000018cc:     	str	w8, [x19, #0x8]
1000018d0:     	and	w8, w22, #0x1f
1000018d4:     	add	w8, w21, w8
1000018d8:     	lsr	x8, x20, x8
1000018dc:     	and	w8, w8, #0x1
1000018e0:     	strb	w8, [x19, #0xc]
1000018e4:     	ldp	x29, x30, [sp, #0x90]
1000018e8:     	b	0x100001988 <_main+0x1368>
1000018ec:     	mov	w8, #0x0                ; =0
1000018f0:     	mov	w9, #0x5                ; =5
1000018f4:     	cbz	x0, 0x100001914 <_main+0x12f4>
1000018f8:     	udiv	x10, x0, x9
1000018fc:     	add	x11, x10, x10, lsl #2
100001900:     	cmp	x0, x11
100001904:     	b.ne	0x100001918 <_main+0x12f8>
100001908:     	add	w8, w8, #0x1
10000190c:     	mov	x0, x10
100001910:     	cbnz	x10, 0x1000018f8 <_main+0x12d8>
100001914:     	mov	w8, #0x0                ; =0
100001918:     	cmp	w8, w1
10000191c:     	cset	w0, hs
100001920:     	ret
100001924:     	cmp	w2, #0x80
100001928:     	b.hs	0x10000195c <_main+0x133c>
10000192c:     	ldp	x9, x8, [x1]
100001930:     	umulh	x10, x8, x0
100001934:     	mul	x8, x8, x0
100001938:     	umulh	x9, x9, x0
10000193c:     	adds	x8, x9, x8
100001940:     	cinc	x9, x10, hs
100001944:     	lsr	x8, x8, x2
100001948:     	lsl	x9, x9, #1
10000194c:     	mvn	w10, w2
100001950:     	lsl	x9, x9, x10
100001954:     	orr	x0, x9, x8
100001958:     	ret
10000195c:     	mov	x0, #0x0                ; =0
100001960:     	ret
100001964:     	mov	x8, #0x0                ; =0
100001968:     	cmp	x2, x8
10000196c:     	b.eq	0x100001980 <_main+0x1360>
100001970:     	ldrb	w9, [x1, x8]
100001974:     	strb	w9, [x0, x8]
100001978:     	add	x8, x8, #0x1
10000197c:     	b	0x100001968 <_main+0x1348>
100001980:     	mov	x0, x2
100001984:     	ret
100001988:     	ldp	x20, x19, [sp, #0x80]
10000198c:     	ldp	x22, x21, [sp, #0x70]
100001990:     	ldp	x24, x23, [sp, #0x60]
100001994:     	ldp	x26, x25, [sp, #0x50]
100001998:     	ldp	x28, x27, [sp, #0x40]
10000199c:     	add	sp, sp, #0xa0
1000019a0:     	ret
1000019a4:     	add	x20, sp, #0x18
1000019a8:     	add	x8, sp, #0x18
1000019ac:     	add	x1, sp, #0x8
1000019b0:     	mov	x0, x19
1000019b4:     	ret
1000019b8:     	strb	w23, [sp, #0x24]
1000019bc:     	ldurh	w8, [x1, #0xd]
1000019c0:     	sturh	w8, [sp, #0x25]
1000019c4:     	ldurb	w8, [x1, #0xf]
1000019c8:     	strb	w8, [sp, #0x27]
1000019cc:     	add	x8, sp, #0x28
1000019d0:     	add	x0, sp, #0x18
1000019d4:     	ret
1000019d8:     	adrp	x8, 0x100001000 <_main+0x9e0>
1000019dc:     	add	x8, x8, #0xab8
1000019e0:     	ldr	q0, [x8]
1000019e4:     	str	q0, [x19]
1000019e8:     	mov	w8, #0x66               ; =102
1000019ec:     	str	x8, [x19, #0x10]
1000019f0:     	ret
1000019f4:     	add	x0, x20, x26
1000019f8:     	add	x1, sp, #0x38
1000019fc:     	mov	x2, x23
100001a00:     	b	0x10000105c <_main+0xa3c>
100001a04:     	and	w8, w8, w10
100001a08:     	udiv	x13, x25, x11
100001a0c:     	msub	w10, w13, w11, w25
100001a10:     	add	w9, w9, #0x1
100001a14:     	mov	x26, x12
100001a18:     	mov	x25, x13
100001a1c:     	ret
100001a20:     	mov	x9, #0x0                ; =0
100001a24:     	ldp	x10, x20, [x20]
100001a28:     	mov	w11, #0x1               ; =1
100001a2c:     	mov	x12, #0x80000000800000  ; =36028797027352576
100001a30:     	movk	x12, #0x1
100001a34:     	ret
100001a38:     	add	x1, sp, #0x20
100001a3c:     	add	w2, w26, #0x7d
100001a40:     	b	0x100001924 <_main+0x1304>
100001a44:     	add	x1, sp, #0x30
100001a48:     	add	w2, w26, #0x7c
100001a4c:     	b	0x100001924 <_main+0x1304>
100001a50:     	mov	w1, #0x30               ; =48
100001a54:     	mov	x2, x21
100001a58:     	b	0x10000093c <_main+0x31c>
100001a5c:     	mov	w1, #0x30               ; =48
100001a60:     	b	0x10000093c <_main+0x31c>
100001a64:     	mov	x1, x23
100001a68:     	b	0x1000018ec <_main+0x12cc>
100001a6c:     	adrp	x8, 0x100001000 <_main+0x9e0>
100001a70:     	add	x8, x8, #0xe12
100001a74:     	adrp	x9, 0x100001000 <_main+0x9e0>
100001a78:     	add	x9, x9, #0xe0d
100001a7c:     	ret
100001a80:     	sub	sp, sp, #0xa0
100001a84:     	stp	x28, x27, [sp, #0x40]
100001a88:     	stp	x26, x25, [sp, #0x50]
100001a8c:     	stp	x24, x23, [sp, #0x60]
100001a90:     	stp	x22, x21, [sp, #0x70]
100001a94:     	stp	x20, x19, [sp, #0x80]
100001a98:     	ret
		...
100001ab0:     	udf	#0x1
		...
100001ac8:     	udf	#0x66
100001acc:     	udf	#0x0
100001ad0:     	udf	#0x1
100001ad4:     	udf	#0x0
100001ad8:     	udf	#0x5
100001adc:     	udf	#0x0
100001ae0:     	udf	#0x19
100001ae4:     	udf	#0x0
100001ae8:     	udf	#0x7d
100001aec:     	udf	#0x0
100001af0:     	udf	#0x271
100001af4:     	udf	#0x0
100001af8:     	udf	#0xc35
100001afc:     	udf	#0x0
100001b00:     	udf	#0x3d09
100001b04:     	udf	#0x0
100001b08:     	<unknown>
100001b0c:     	udf	#0x0
100001b10:     	<unknown>
100001b14:     	udf	#0x0
100001b18:     	<unknown>
100001b1c:     	udf	#0x0
100001b20:     	<unknown>
100001b24:     	udf	#0x0
100001b28:     	<unknown>
100001b2c:     	udf	#0x0
100001b30:     	<unknown>
100001b34:     	udf	#0x0
100001b38:     	ldlarh	w21, [x28]
100001b3c:     	udf	#0x0
100001b40:     	<unknown>
100001b44:     	udf	#0x1
100001b48:     	<unknown>
100001b4c:     	udf	#0x7
100001b50:     	<unknown>
100001b54:     	udf	#0x23
100001b58:     	<unknown>
100001b5c:     	udf	#0xb1
100001b60:     	stp	s25, s26, [x14, #-0x9c]!
100001b64:     	udf	#0x378
100001b68:     	<unknown>
100001b6c:     	udf	#0x1158
100001b70:     	<unknown>
100001b74:     	udf	#0x56bc
100001b78:     	<unknown>
100001b7c:     	<unknown>
100001b80:     	<unknown>
100001b84:     	<unknown>
100001b88:     	<unknown>
100001b8c:     	<unknown>
100001b90:     	<unknown>
100001b94:     	<unknown>
100001b98:     	<unknown>
100001b9c:     	<unknown>
		...
100001bb0:     	<unknown>
100001bb4:     	<unknown>
100001bb8:     	<unknown>
100001bbc:     	<unknown>
100001bc0:     	<unknown>
100001bc4:     	<unknown>
100001bc8:     	smlslb	z5.h, z10.b, z21.b
100001bcc:     	smlalt	z0.h, z10.b, z16.b
100001bd0:     	ssubwt	z16.h, z10.h, z21.b
100001bd4:     	<unknown>
100001bd8:     	bl	0xf9102cd8 <dyld_stub_binder+0xf9102cd8>
100001bdc:     	<unknown>
100001be0:     	b.pl	0x10008c3e8 <dyld_private+0x843e8>
100001be4:     	<unknown>
100001be8:     	<unknown>
100001bec:     	sub	w21, w10, #0x15, lsl #12 ; =0x15000
100001bf0:     	udf	#0x105
100001bf4:     	bc.mi	0x1000aa49c <dyld_private+0xa249c>
100001bf8:     	mla	z5.b, p5/m, z10.b, z5.b
100001bfc:     	adr	x0, 0x100009dfc <dyld_private+0x1dfc>
100001c00:     	<unknown>
100001c04:     	<unknown>
100001c08:     	<unknown>
100001c0c:     	udf	#0x454
100001c10:     	<unknown>
100001c14:     	<unknown>
100001c18:     	<unknown>
100001c1c:     	adr	x16, 0x10008c4a6 <dyld_private+0x844a6>
100001c20:     	<unknown>
100001c24:     	sub	w20, w10, #0x955, lsl #12 ; =0x955000
100001c28:     	<unknown>
100001c2c:     	<unknown>
100001c30:     	<unknown>
100001c34:     	sub	w17, w0, #0x455, lsl #12 ; =0x455000
100001c38:     	mov	z20.h, p5/m, #0xffaa    ; =65450
100001c3c:     	udf	#0x0
100001c40:     	udf	#0x1
		...
100001c4c:     	<unknown>
100001c50:     	<unknown>
100001c54:     	mov	wzr, #0x364a0000        ; =910819328
100001c58:     	<unknown>
100001c5c:     	ldr	w4, 0xfff86474 <dyld_stub_binder+0xfff86474>
100001c60:     	<unknown>
100001c64:     	<unknown>
100001c68:     	<unknown>
100001c6c:     	<unknown>
100001c70:     	cbnz	w14, 0x1000ae55c <dyld_private+0xa655c>
100001c74:     	bfmls	z29.h, p1/m, z3.h, z0.h
100001c78:     	ldpsw	x2, x17, [x24], #-0xc4
100001c7c:     	<unknown>
100001c80:     	<unknown>
100001c84:     	<unknown>
100001c88:     	<unknown>
100001c8c:     	b	0xfbbd898c <dyld_stub_binder+0xfbbd898c>
100001c90:     	<unknown>
100001c94:     	ldr	xzr, [sp, #0x2348]
100001c98:     	<unknown>
100001c9c:     	<unknown>
100001ca0:     	<unknown>
100001ca4:     	<unknown>
100001ca8:     	<unknown>
100001cac:     	<unknown>
100001cb0:     	<unknown>
100001cb4:     	<unknown>
100001cb8:     	<unknown>
100001cbc:     	b	0x104fb8640 <dyld_private+0x4fb0640>
100001cc0:     	sub	x14, x30, x30, sxtx
100001cc4:     	ldaxrb	w19, [x11]
100001cc8:     	<unknown>
100001ccc:     	adr	x21, 0x1000e2044 <dyld_private+0xda044>
100001cd0:     	<unknown>
100001cd4:     	b	0x104ca3480 <dyld_private+0x4c9b480>
100001cd8:     	cbz	x13, 0x10009d360 <dyld_private+0x95360>
100001cdc:     	<unknown>
100001ce0:     	stnp	d22, d13, [x20, #0x78]
100001ce4:     	ldp	q24, q25, [sp, #-0x230]!
100001ce8:     	<unknown>
100001cec:     	<unknown>
100001cf0:     	<unknown>
100001cf4:     	<unknown>
100001cf8:     	str	q17, [x20, #0xab60]
100001cfc:     	<unknown>
100001d00:     	<unknown>
100001d04:     	ldrsw	x6, 0xfff83124 <dyld_stub_binder+0xfff83124>
100001d08:     	<unknown>
100001d0c:     	b	0xfe40579c <dyld_stub_binder+0xfe40579c>
100001d10:     	subs	w14, w8, #0x25f, lsl #12 ; =0x25f000
100001d14:     	<unknown>
100001d18:     	<unknown>
100001d1c:     	and	w5, w0, #0x7e0
100001d20:     	cbz	w5, 0x1000ea4d0 <dyld_private+0xe24d0>
100001d24:     	adrp	x1, 0x186272000 <dyld_private+0x8626a000>
100001d28:     	<unknown>
100001d2c:     	ldr	s7, 0x10006dbb0 <dyld_private+0x65bb0>
		...
100001d3c:     	adr	x0, 0x100001d3c <_main+0x171c>
		...
100001d48:     	orr	w25, w5, #0xe00007ff
100001d4c:     	b	0x102b7f028 <dyld_private+0x2b77028>
100001d50:     	<unknown>
100001d54:     	<unknown>
100001d58:     	bl	0x105f4dd8c <dyld_private+0x5f45d8c>
100001d5c:     	<unknown>
100001d60:     	st1.b	{ v6 }[10], [x3], x15
100001d64:     	ldp	d6, d11, [x9, #0x68]!
100001d68:     	<unknown>
100001d6c:     	add	w2, wsp, #0x16d, lsl #12 ; =0x16d000
100001d70:     	str	q10, [x22, #0x1650]
100001d74:     	subs	x18, x12, x29, lsl #47
100001d78:     	<unknown>
100001d7c:     	b	0xf94bdcec <dyld_stub_binder+0xf94bdcec>
100001d80:     	<unknown>
100001d84:     	cbz	x11, 0xfff85484 <dyld_stub_binder+0xfff85484>
100001d88:     	<unknown>
100001d8c:     	ldr	s5, 0xfffb69cc <dyld_stub_binder+0xfffb69cc>
100001d90:     	<unknown>
100001d94:     	<unknown>
100001d98:     	<unknown>
100001d9c:     	mov	w11, #-0x2ab40001       ; =-716439553
100001da0:     	<unknown>
100001da4:     	adrp	x3, 0x15dac000 <dyld_stub_binder+0x15dac000>
100001da8:     	<unknown>
100001dac:     	ldr	w21, 0x100034a4c <dyld_private+0x2ca4c>
100001db0:     	<unknown>
100001db4:     	cbz	x10, 0xfffde01c <dyld_stub_binder+0xfffde01c>
100001db8:     	<unknown>
100001dbc:     	fnmsub	s6, s12, s5, s16
100001dc0:     	adr	x3, 0xfff869a3 <dyld_stub_binder+0xfff869a3>
100001dc4:     	b	0xf92698f0 <dyld_stub_binder+0xf92698f0>
100001dc8:     	ldr	q6, 0xfff12624 <dyld_stub_binder+0xfff12624>
100001dcc:     	b	0x10083cadc <dyld_private+0x834adc>
100001dd0:     	tbz	w16, #0x1, 0x100002a84 <_main+0x2464>
100001dd4:     	<unknown>
100001dd8:     	b	0x1032bdfec <dyld_private+0x32b5fec>
100001ddc:     	<unknown>
100001de0:     	ldrsh	x11, [x8, #0xcc4]
100001de4:     	<unknown>
100001de8:     	<unknown>
100001dec:     	adr	x21, 0xfffa1b50 <dyld_stub_binder+0xfffa1b50>
100001df0:     	<unknown>
100001df4:     	<unknown>
100001df8:     	<unknown>
100001dfc:     	b	0x106eadb0c <dyld_private+0x6ea5b0c>
100001e00:     	<unknown>
100001e04:     	<unknown>
100001e08:     	<unknown>
100001e0c:     	uqsub.8b	v0, v8, v16
100001e10:     	uaddl.8h	v16, v1, v16
100001e14:     	udf	#0x30
100001e18:     	udf	#0x1
100001e1c:     	udf	#0x0
100001e20:     	udf	#0xa
100001e24:     	udf	#0x0
100001e28:     	udf	#0x4
100001e2c:     	udf	#0x0
100001e30:     	fnmls	z20.h, p4/m, z19.h, z21.h
100001e34:     	udf	#0x0
100001e38:     	udf	#0x5
100001e3c:     	udf	#0x0
100001e40:     	<unknown>
100001e44:     	udf	#0x65
100001e48:     	udf	#0x7
100001e4c:     	udf	#0x0
100001e50:     	fcmla.8h	v5, v19, v18[1], #270
100001e54:     	<unknown>
		...
