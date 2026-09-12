
/private/tmp/silex-part03-evidence/preparation-snapshot-after:	file format mach-o arm64

Disassembly of section __TEXT,__text:

00000001000004f0 <_silex_function_0>:
1000004f0:     	stp	x29, x30, [sp, #-0x10]!
1000004f4:     	mov	x29, sp
1000004f8:     	sub	sp, sp, #0x590
1000004fc:     	str	x15, [sp, #0x10]
100000500:     	mov	x16, x0
100000504:     	mov	x17, x1
100000508:     	movi	d30, #0000000000000000
10000050c:     	movi	d31, #0000000000000000
100000510:     	movi	d0, #0000000000000000
100000514:     	movi	d26, #0000000000000000
100000518:     	cbz	w17, 0x100000520 <_silex_function_0+0x30>
10000051c:     	fmov	s26, #1.00000000
100000520:     	ldr	s22, [x16, #0x50]
100000524:     	ldr	s18, [x16, #0x40]
100000528:     	ldr	s19, [x16, #0x30]
10000052c:     	fsub	s17, s18, s19
100000530:     	ldr	s16, [x16, #0x20]
100000534:     	fmul	s23, s17, s16
100000538:     	ldr	s20, [x16, #0x48]
10000053c:     	ldr	s21, [x16, #0x38]
100000540:     	fsub	s24, s20, s21
100000544:     	ldr	s17, [x16, #0x28]
100000548:     	fmadd	s23, s24, s17, s23
10000054c:     	fsub	s4, s22, s23
100000550:     	fmul	s22, s19, s17
100000554:     	fmsub	s25, s21, s16, s22
100000558:     	fmul	s22, s18, s17
10000055c:     	fmsub	s27, s20, s16, s22
100000560:     	ldr	s22, [x16]
100000564:     	ldr	s23, [x16, #0x8]
100000568:     	fadd	s28, s22, s23
10000056c:     	ldr	s24, [x16, #0x10]
100000570:     	fmul	s29, s24, s25
100000574:     	fmadd	s1, s29, s25, s28
100000578:     	ldr	s25, [x16, #0x18]
10000057c:     	fmul	s29, s25, s27
100000580:     	fmadd	s27, s29, s27, s1
100000584:     	fcmp	s27, #0.0
100000588:     	b.le	0x100000594 <_silex_function_0+0xa4>
10000058c:     	fmov	s30, #1.00000000
100000590:     	fdiv	s30, s30, s27
100000594:     	fneg	s27, s16
100000598:     	fmul	s29, s19, s27
10000059c:     	fmsub	s29, s21, s17, s29
1000005a0:     	fmul	s1, s18, s27
1000005a4:     	fmsub	s27, s20, s17, s1
1000005a8:     	fmul	s1, s24, s29
1000005ac:     	fmadd	s28, s1, s29, s28
1000005b0:     	fmul	s29, s25, s27
1000005b4:     	fmadd	s27, s29, s27, s28
1000005b8:     	fcmp	s27, #0.0
1000005bc:     	b.le	0x1000005c8 <_silex_function_0+0xd8>
1000005c0:     	fmov	s31, #1.00000000
1000005c4:     	fdiv	s31, s31, s27
1000005c8:     	fadd	s27, s24, s25
1000005cc:     	fcmp	s27, #0.0
1000005d0:     	b.le	0x1000005dc <_silex_function_0+0xec>
1000005d4:     	fmov	s0, #1.00000000
1000005d8:     	fdiv	s0, s0, s27
1000005dc:     	ldr	s29, [x16, #0x58]
1000005e0:     	ldr	s1, [x16, #0x60]
1000005e4:     	ldr	s28, [x16, #0x68]
1000005e8:     	ldr	s2, [x16, #0x70]
1000005ec:     	ldr	s3, [x16, #0x78]
1000005f0:     	ldr	s27, [x16, #0x80]
1000005f4:     	fcmp	s22, #0.0
1000005f8:     	b.ne	0x100000608 <_silex_function_0+0x118>
1000005fc:     	movi	d29, #0000000000000000
100000600:     	movi	d1, #0000000000000000
100000604:     	movi	d28, #0000000000000000
100000608:     	fcmp	s23, #0.0
10000060c:     	b.ne	0x10000061c <_silex_function_0+0x12c>
100000610:     	movi	d2, #0000000000000000
100000614:     	movi	d3, #0000000000000000
100000618:     	movi	d27, #0000000000000000
10000061c:     	fmsub	s2, s27, s20, s2
100000620:     	fmsub	s29, s28, s21, s29
100000624:     	fsub	s2, s2, s29
100000628:     	fmul	s29, s16, s2
10000062c:     	fmadd	s3, s27, s18, s3
100000630:     	fmadd	s1, s28, s19, s1
100000634:     	fsub	s3, s3, s1
100000638:     	fmadd	s29, s17, s3, s29
10000063c:     	ldr	s27, [x16, #0x88]
100000640:     	fmul	s1, s26, s27
100000644:     	ldr	s27, [x16, #0x90]
100000648:     	fmul	s2, s26, s27
10000064c:     	ldr	s27, [x16, #0x98]
100000650:     	fmul	s3, s26, s27
100000654:     	fmov	s26, #12.00000000
100000658:     	fmov	s27, #0.75000000
10000065c:     	fmov	s28, #0.25000000
100000660:     	fcmp	s22, #0.0
100000664:     	b.eq	0x100000684 <_silex_function_0+0x194>
100000668:     	movi	d5, #0000000000000000
10000066c:     	fcmp	s23, s5
100000670:     	mov	w11, #0x0               ; =0
100000674:     	b.ne	0x10000067c <_silex_function_0+0x18c>
100000678:     	mov	w11, #0x1               ; =1
10000067c:     	mov	x0, x11
100000680:     	b	0x100000688 <_silex_function_0+0x198>
100000684:     	mov	w0, #0x1                ; =1
100000688:     	cbz	w0, 0x100000698 <_silex_function_0+0x1a8>
10000068c:     	fmov	s26, #24.00000000
100000690:     	fmov	s27, #0.87500000
100000694:     	fmov	s28, #0.12500000
100000698:     	ldr	x0, [x16, #0xa0]
10000069c:     	ldr	x1, [x16, #0xa8]
1000006a0:     	ldr	x2, [x16, #0xb0]
1000006a4:     	ldr	x3, [x16, #0xb8]
1000006a8:     	movi	d5, #0000000000000000
1000006ac:     	ldr	x14, [sp, #0x10]
1000006b0:     	str	d4, [x14]
1000006b4:     	str	d30, [x14, #0x8]
1000006b8:     	str	d31, [x14, #0x10]
1000006bc:     	str	d29, [x14, #0x18]
1000006c0:     	str	d0, [x14, #0x20]
1000006c4:     	str	d1, [x14, #0x28]
1000006c8:     	str	d2, [x14, #0x30]
1000006cc:     	str	d3, [x14, #0x38]
1000006d0:     	str	x0, [x14, #0x40]
1000006d4:     	str	x1, [x14, #0x48]
1000006d8:     	str	x2, [x14, #0x50]
1000006dc:     	str	x3, [x14, #0x58]
1000006e0:     	str	d26, [x14, #0x60]
1000006e4:     	str	d27, [x14, #0x68]
1000006e8:     	str	d28, [x14, #0x70]
1000006ec:     	str	d16, [x14, #0x78]
1000006f0:     	str	d17, [x14, #0x80]
1000006f4:     	str	d19, [x14, #0x88]
1000006f8:     	str	d21, [x14, #0x90]
1000006fc:     	str	d18, [x14, #0x98]
100000700:     	str	d20, [x14, #0xa0]
100000704:     	str	d22, [x14, #0xa8]
100000708:     	str	d23, [x14, #0xb0]
10000070c:     	str	d24, [x14, #0xb8]
100000710:     	str	d25, [x14, #0xc0]
100000714:     	str	d5, [x14, #0xc8]
100000718:     	mov	x0, #0x0                ; =0
10000071c:     	mov	w8, #0x0                ; =0
100000720:     	add	sp, sp, #0x590
100000724:     	ldp	x29, x30, [sp], #0x10
100000728:     	ret
10000072c:     	mov	w8, #0x1                ; =1
100000730:     	b	0x100000720 <_silex_function_0+0x230>
100000734:     	mov	w8, #0x2                ; =2
100000738:     	b	0x100000720 <_silex_function_0+0x230>

000000010000073c <_silex_function_1>:
10000073c:     	stp	x29, x30, [sp, #-0x10]!
100000740:     	mov	x29, sp
100000744:     	sub	sp, sp, #0x330
100000748:     	fmov	x9, d8
10000074c:     	str	x9, [sp, #0x320]
100000750:     	fmov	x9, d13
100000754:     	str	x9, [sp, #0x328]
100000758:     	str	x15, [sp, #0x10]
10000075c:     	mov	x16, x0
100000760:     	mov	x17, x1
100000764:     	asr	x13, x16, #63
100000768:     	mov	x12, #0xf               ; =15
10000076c:     	and	x13, x13, x12
100000770:     	add	x13, x16, x13
100000774:     	asr	x13, x13, #4
100000778:     	mov	x12, #0x10              ; =16
10000077c:     	msub	x1, x13, x12, x16
100000780:     	scvtf	s17, x1
100000784:     	mov	x11, #0x5f000000        ; =1593835520
100000788:     	fmov	s11, w11
10000078c:     	fcmp	s17, s11
100000790:     	b.mi	0x1000007c0 <_silex_function_1+0x84>
100000794:     	mov	w0, #0x2                ; =2
100000798:     	adrp	x1, 0x100008000 <_main+0xb80>
10000079c:     	add	x1, x1, #0xf50
1000007a0:     	mov	x2, #0x69               ; =105
1000007a4:     	movk	x2, #0x0, lsl #16
1000007a8:     	movk	x2, #0x0, lsl #32
1000007ac:     	movk	x2, #0x0, lsl #48
1000007b0:     	mov	w16, #0x4               ; =4
1000007b4:     	svc	#0x80
1000007b8:     	mov	w8, #0x3                ; =3
1000007bc:     	b	0x100000b0c <_silex_function_1+0x3d0>
1000007c0:     	fcvtzs	x11, s17
1000007c4:     	cmp	x1, x11
1000007c8:     	b.eq	0x1000007f8 <_silex_function_1+0xbc>
1000007cc:     	mov	w0, #0x2                ; =2
1000007d0:     	adrp	x1, 0x100008000 <_main+0xb80>
1000007d4:     	add	x1, x1, #0xf50
1000007d8:     	mov	x2, #0x69               ; =105
1000007dc:     	movk	x2, #0x0, lsl #16
1000007e0:     	movk	x2, #0x0, lsl #32
1000007e4:     	movk	x2, #0x0, lsl #48
1000007e8:     	mov	w16, #0x4               ; =4
1000007ec:     	svc	#0x80
1000007f0:     	mov	w8, #0x3                ; =3
1000007f4:     	b	0x100000b0c <_silex_function_1+0x3d0>
1000007f8:     	scvtf	s16, x17
1000007fc:     	mov	x11, #0x5f000000        ; =1593835520
100000800:     	fmov	s11, w11
100000804:     	fcmp	s16, s11
100000808:     	b.mi	0x100000838 <_silex_function_1+0xfc>
10000080c:     	mov	w0, #0x2                ; =2
100000810:     	adrp	x1, 0x100008000 <_main+0xb80>
100000814:     	add	x1, x1, #0xfc8
100000818:     	mov	x2, #0x69               ; =105
10000081c:     	movk	x2, #0x0, lsl #16
100000820:     	movk	x2, #0x0, lsl #32
100000824:     	movk	x2, #0x0, lsl #48
100000828:     	mov	w16, #0x4               ; =4
10000082c:     	svc	#0x80
100000830:     	mov	w8, #0x3                ; =3
100000834:     	b	0x100000b0c <_silex_function_1+0x3d0>
100000838:     	fcvtzs	x11, s16
10000083c:     	cmp	x17, x11
100000840:     	b.eq	0x100000870 <_silex_function_1+0x134>
100000844:     	mov	w0, #0x2                ; =2
100000848:     	adrp	x1, 0x100008000 <_main+0xb80>
10000084c:     	add	x1, x1, #0xfc8
100000850:     	mov	x2, #0x69               ; =105
100000854:     	movk	x2, #0x0, lsl #16
100000858:     	movk	x2, #0x0, lsl #32
10000085c:     	movk	x2, #0x0, lsl #48
100000860:     	mov	w16, #0x4               ; =4
100000864:     	svc	#0x80
100000868:     	mov	w8, #0x3                ; =3
10000086c:     	b	0x100000b0c <_silex_function_1+0x3d0>
100000870:     	fmov	s18, #1.00000000
100000874:     	fmov	s20, #0.50000000
100000878:     	fmov	s19, #0.25000000
10000087c:     	fmov	s21, #0.50000000
100000880:     	mov	x9, #0x999a             ; =39322
100000884:     	movk	x9, #0x3f19, lsl #16
100000888:     	fmov	s22, w9
10000088c:     	mov	x9, #0xcccd             ; =52429
100000890:     	movk	x9, #0x3f4c, lsl #16
100000894:     	fmov	s23, w9
100000898:     	fmov	s24, #0.12500000
10000089c:     	mov	x9, #0x3c000000         ; =1006632960
1000008a0:     	fmov	s25, w9
1000008a4:     	fmadd	s24, s16, s25, s24
1000008a8:     	mov	x9, #0x3d800000         ; =1031798784
1000008ac:     	fmov	s25, w9
1000008b0:     	mov	x9, #0x3b800000         ; =998244352
1000008b4:     	fmov	s26, w9
1000008b8:     	fmadd	s25, s16, s26, s25
1000008bc:     	fmov	s26, #8.00000000
1000008c0:     	fsub	s27, s17, s26
1000008c4:     	mov	x9, #0x3d000000         ; =1023410176
1000008c8:     	fmov	s26, w9
1000008cc:     	fmul	s27, s27, s26
1000008d0:     	mov	x9, #0x3b000000         ; =989855744
1000008d4:     	fmov	s26, w9
1000008d8:     	fmadd	s27, s16, s26, s27
1000008dc:     	fmov	s26, #0.12500000
1000008e0:     	fmul	s28, s17, s26
1000008e4:     	fmov	s26, #-0.50000000
1000008e8:     	mov	x9, #0x3d800000         ; =1031798784
1000008ec:     	fmov	s29, w9
1000008f0:     	fmsub	s26, s16, s29, s26
1000008f4:     	mov	x9, #0x3d800000         ; =1031798784
1000008f8:     	fmov	s29, w9
1000008fc:     	fmul	s30, s17, s29
100000900:     	fmov	s29, #1.00000000
100000904:     	fsub	s30, s30, s29
100000908:     	fmov	s29, #-0.50000000
10000090c:     	mov	x9, #0x3d000000         ; =1023410176
100000910:     	fmov	s31, w9
100000914:     	fmadd	s29, s16, s31, s29
100000918:     	fmov	s31, #0.12500000
10000091c:     	mov	x9, #0x3c800000         ; =1015021568
100000920:     	fmov	s0, w9
100000924:     	fmadd	s31, s16, s0, s31
100000928:     	asr	x13, x16, #63
10000092c:     	mov	x12, #0x3               ; =3
100000930:     	and	x13, x13, x12
100000934:     	add	x13, x16, x13
100000938:     	asr	x13, x13, #2
10000093c:     	mov	x12, #0x4               ; =4
100000940:     	msub	x1, x13, x12, x16
100000944:     	scvtf	s16, x1
100000948:     	mov	x11, #0x5f000000        ; =1593835520
10000094c:     	fmov	s11, w11
100000950:     	fcmp	s16, s11
100000954:     	b.mi	0x100000984 <_silex_function_1+0x248>
100000958:     	mov	w0, #0x2                ; =2
10000095c:     	adrp	x1, 0x100009000 <_main+0x1b80>
100000960:     	add	x1, x1, #0x40
100000964:     	mov	x2, #0x69               ; =105
100000968:     	movk	x2, #0x0, lsl #16
10000096c:     	movk	x2, #0x0, lsl #32
100000970:     	movk	x2, #0x0, lsl #48
100000974:     	mov	w16, #0x4               ; =4
100000978:     	svc	#0x80
10000097c:     	mov	w8, #0x3                ; =3
100000980:     	b	0x100000b0c <_silex_function_1+0x3d0>
100000984:     	fcvtzs	x11, s16
100000988:     	cmp	x1, x11
10000098c:     	b.eq	0x1000009bc <_silex_function_1+0x280>
100000990:     	mov	w0, #0x2                ; =2
100000994:     	adrp	x1, 0x100009000 <_main+0x1b80>
100000998:     	add	x1, x1, #0x40
10000099c:     	mov	x2, #0x69               ; =105
1000009a0:     	movk	x2, #0x0, lsl #16
1000009a4:     	movk	x2, #0x0, lsl #32
1000009a8:     	movk	x2, #0x0, lsl #48
1000009ac:     	mov	w16, #0x4               ; =4
1000009b0:     	svc	#0x80
1000009b4:     	mov	w8, #0x3                ; =3
1000009b8:     	b	0x100000b0c <_silex_function_1+0x3d0>
1000009bc:     	fmov	s0, #0.25000000
1000009c0:     	fmul	s16, s16, s0
1000009c4:     	mov	x9, #0x3d800000         ; =1031798784
1000009c8:     	fmov	s0, w9
1000009cc:     	fmul	s1, s17, s0
1000009d0:     	fmov	s0, #8.00000000
1000009d4:     	fsub	s17, s17, s0
1000009d8:     	fmov	s0, #0.12500000
1000009dc:     	fmul	s17, s17, s0
1000009e0:     	asr	x13, x16, #63
1000009e4:     	mov	x12, #0x3               ; =3
1000009e8:     	and	x13, x13, x12
1000009ec:     	add	x13, x16, x13
1000009f0:     	asr	x13, x13, #2
1000009f4:     	mov	x12, #0x4               ; =4
1000009f8:     	msub	x1, x13, x12, x16
1000009fc:     	cmp	x1, xzr
100000a00:     	b.ne	0x100000a0c <_silex_function_1+0x2d0>
100000a04:     	movi	d18, #0000000000000000
100000a08:     	movi	d19, #0000000000000000
100000a0c:     	asr	x13, x16, #63
100000a10:     	mov	x12, #0x7               ; =7
100000a14:     	and	x13, x13, x12
100000a18:     	add	x13, x16, x13
100000a1c:     	asr	x13, x13, #3
100000a20:     	mov	x12, #0x8               ; =8
100000a24:     	msub	x16, x13, x12, x16
100000a28:     	cmp	x16, xzr
100000a2c:     	b.ne	0x100000a38 <_silex_function_1+0x2fc>
100000a30:     	movi	d20, #0000000000000000
100000a34:     	movi	d21, #0000000000000000
100000a38:     	asr	x13, x17, #63
100000a3c:     	mov	x12, #0x1               ; =1
100000a40:     	and	x13, x13, x12
100000a44:     	add	x13, x17, x13
100000a48:     	asr	x13, x13, #1
100000a4c:     	mov	x12, #0x2               ; =2
100000a50:     	msub	x17, x13, x12, x17
100000a54:     	mov	x0, #0x1                ; =1
100000a58:     	cmp	x17, x0
100000a5c:     	b.ne	0x100000a78 <_silex_function_1+0x33c>
100000a60:     	mov	x9, #0xcccd             ; =52429
100000a64:     	movk	x9, #0x3f4c, lsl #16
100000a68:     	fmov	s22, w9
100000a6c:     	mov	x9, #0x999a             ; =39322
100000a70:     	movk	x9, #0xbf19, lsl #16
100000a74:     	fmov	s23, w9
100000a78:     	mov	x9, #0xbd800000         ; =3179282432
100000a7c:     	fmov	s0, w9
100000a80:     	fmov	s2, #-0.12500000
100000a84:     	fmov	s3, #0.25000000
100000a88:     	fmov	s4, #-0.25000000
100000a8c:     	mov	x9, #0x3d000000         ; =1023410176
100000a90:     	fmov	s5, w9
100000a94:     	mov	x9, #0xbc800000         ; =3162505216
100000a98:     	fmov	s8, w9
100000a9c:     	fmov	s13, #0.12500000
100000aa0:     	ldr	x14, [sp, #0x10]
100000aa4:     	str	d18, [x14]
100000aa8:     	str	d20, [x14, #0x8]
100000aac:     	str	d19, [x14, #0x10]
100000ab0:     	str	d21, [x14, #0x18]
100000ab4:     	str	d22, [x14, #0x20]
100000ab8:     	str	d23, [x14, #0x28]
100000abc:     	str	d24, [x14, #0x30]
100000ac0:     	str	d0, [x14, #0x38]
100000ac4:     	str	d2, [x14, #0x40]
100000ac8:     	str	d25, [x14, #0x48]
100000acc:     	str	d27, [x14, #0x50]
100000ad0:     	str	d28, [x14, #0x58]
100000ad4:     	str	d26, [x14, #0x60]
100000ad8:     	str	d3, [x14, #0x68]
100000adc:     	str	d4, [x14, #0x70]
100000ae0:     	str	d30, [x14, #0x78]
100000ae4:     	str	d29, [x14, #0x80]
100000ae8:     	str	d31, [x14, #0x88]
100000aec:     	str	d5, [x14, #0x90]
100000af0:     	str	d8, [x14, #0x98]
100000af4:     	str	d16, [x14, #0xa0]
100000af8:     	str	d1, [x14, #0xa8]
100000afc:     	str	d17, [x14, #0xb0]
100000b00:     	str	d13, [x14, #0xb8]
100000b04:     	mov	x0, #0x0                ; =0
100000b08:     	mov	w8, #0x0                ; =0
100000b0c:     	ldr	x9, [sp, #0x320]
100000b10:     	fmov	d8, x9
100000b14:     	ldr	x9, [sp, #0x328]
100000b18:     	fmov	d13, x9
100000b1c:     	add	sp, sp, #0x330
100000b20:     	ldp	x29, x30, [sp], #0x10
100000b24:     	ret
100000b28:     	mov	w8, #0x1                ; =1
100000b2c:     	b	0x100000b0c <_silex_function_1+0x3d0>
100000b30:     	mov	w8, #0x2                ; =2
100000b34:     	b	0x100000b0c <_silex_function_1+0x3d0>

0000000100000b38 <_silex_function_2>:
100000b38:     	stp	x29, x30, [sp, #-0x10]!
100000b3c:     	mov	x29, sp
100000b40:     	sub	sp, sp, #0xff0
100000b44:     	sub	sp, sp, #0x260
100000b48:     	mov	x13, sp
100000b4c:     	add	x13, x13, #0xff0
100000b50:     	add	x13, x13, #0x210
100000b54:     	str	x19, [x13]
100000b58:     	mov	x13, sp
100000b5c:     	add	x13, x13, #0xff0
100000b60:     	add	x13, x13, #0x218
100000b64:     	str	x20, [x13]
100000b68:     	mov	x13, sp
100000b6c:     	add	x13, x13, #0xff0
100000b70:     	add	x13, x13, #0x220
100000b74:     	str	x21, [x13]
100000b78:     	mov	x13, sp
100000b7c:     	add	x13, x13, #0xff0
100000b80:     	add	x13, x13, #0x228
100000b84:     	str	x22, [x13]
100000b88:     	mov	x13, sp
100000b8c:     	add	x13, x13, #0xff0
100000b90:     	add	x13, x13, #0x230
100000b94:     	str	x23, [x13]
100000b98:     	mov	x13, sp
100000b9c:     	add	x13, x13, #0xff0
100000ba0:     	add	x13, x13, #0x238
100000ba4:     	str	x24, [x13]
100000ba8:     	fmov	x9, d8
100000bac:     	mov	x13, sp
100000bb0:     	add	x13, x13, #0xff0
100000bb4:     	add	x13, x13, #0x240
100000bb8:     	str	x9, [x13]
100000bbc:     	fmov	x9, d13
100000bc0:     	mov	x13, sp
100000bc4:     	add	x13, x13, #0xff0
100000bc8:     	add	x13, x13, #0x248
100000bcc:     	str	x9, [x13]
100000bd0:     	fmov	x9, d14
100000bd4:     	mov	x13, sp
100000bd8:     	add	x13, x13, #0xff0
100000bdc:     	add	x13, x13, #0x250
100000be0:     	str	x9, [x13]
100000be4:     	fmov	x9, d15
100000be8:     	mov	x13, sp
100000bec:     	add	x13, x13, #0xff0
100000bf0:     	add	x13, x13, #0x258
100000bf4:     	str	x9, [x13]
100000bf8:     	mov	w9, #0x0                ; =0
100000bfc:     	str	x9, [sp]
100000c00:     	mov	w9, #0x0                ; =0
100000c04:     	str	x9, [sp, #0x8]
100000c08:     	add	x15, sp, #0x10
100000c0c:     	bl	0x1000039bc <_silex_function_3>
100000c10:     	cbnz	w8, 0x100003554 <_silex_function_2+0x2a1c>
100000c14:     	ldr	x9, [sp, #0x10]
100000c18:     	mov	x10, #0x1               ; =1
100000c1c:     	cmp	x9, x10
100000c20:     	mov	w11, #0x0               ; =0
100000c24:     	b.ne	0x100000c2c <_silex_function_2+0xf4>
100000c28:     	mov	w11, #0x1               ; =1
100000c2c:     	str	x11, [sp, #0x40]
100000c30:     	ldr	x9, [sp, #0x40]
100000c34:     	cbz	w9, 0x100000cc4 <_silex_function_2+0x18c>
100000c38:     	ldr	x9, [sp, #0x38]
100000c3c:     	mov	x19, x9
100000c40:     	mov	x9, x19
100000c44:     	str	x9, [sp, #0x70]
100000c48:     	mov	w0, #0x2                ; =2
100000c4c:     	adrp	x1, 0x100009000 <_main+0x1b80>
100000c50:     	add	x1, x1, #0xb8
100000c54:     	mov	x2, #0x4e               ; =78
100000c58:     	movk	x2, #0x0, lsl #16
100000c5c:     	movk	x2, #0x0, lsl #32
100000c60:     	movk	x2, #0x0, lsl #48
100000c64:     	mov	w16, #0x4               ; =4
100000c68:     	svc	#0x80
100000c6c:     	ldr	x9, [sp, #0x70]
100000c70:     	ldr	x2, [x9]
100000c74:     	mov	x10, #0xffff            ; =65535
100000c78:     	movk	x10, #0xffff, lsl #16
100000c7c:     	movk	x10, #0xffff, lsl #32
100000c80:     	movk	x10, #0x7fff, lsl #48
100000c84:     	and	x2, x2, x10
100000c88:     	add	x1, x9, #0x8
100000c8c:     	mov	w0, #0x2                ; =2
100000c90:     	mov	w16, #0x4               ; =4
100000c94:     	svc	#0x80
100000c98:     	mov	w0, #0x2                ; =2
100000c9c:     	adrp	x1, 0x100008000 <_main+0xb80>
100000ca0:     	add	x1, x1, #0xf10
100000ca4:     	mov	x2, #0x1                ; =1
100000ca8:     	movk	x2, #0x0, lsl #16
100000cac:     	movk	x2, #0x0, lsl #32
100000cb0:     	movk	x2, #0x0, lsl #48
100000cb4:     	mov	w16, #0x4               ; =4
100000cb8:     	svc	#0x80
100000cbc:     	mov	w8, #0x3                ; =3
100000cc0:     	b	0x100003554 <_silex_function_2+0x2a1c>
100000cc4:     	ldr	x9, [sp, #0x18]
100000cc8:     	str	x9, [sp, #0x78]
100000ccc:     	ldr	x9, [sp, #0x78]
100000cd0:     	str	x9, [sp, #0x11d8]
100000cd4:     	movz	x19, #0x0, lsl #48
100000cd8:     	ldr	x9, [sp]
100000cdc:     	str	x9, [sp, #0xdc0]
100000ce0:     	mov	x9, x19
100000ce4:     	str	x9, [sp, #0xdd0]
100000ce8:     	ldr	x9, [sp, #0x8]
100000cec:     	str	x9, [sp, #0xdc8]
100000cf0:     	ldr	x9, [sp, #0x11d8]
100000cf4:     	mov	x20, x9
100000cf8:     	mov	x9, x20
100000cfc:     	ldr	x10, [x9]
100000d00:     	mov	x19, x10
100000d04:     	ldr	x9, [sp, #0xdd0]
100000d08:     	cmp	x9, x19
100000d0c:     	b.ge	0x100000df8 <_silex_function_2+0x2c0>
100000d10:     	ldr	x9, [sp, #0x11d8]
100000d14:     	mov	x19, x9
100000d18:     	mov	x10, x19
100000d1c:     	add	x10, x10, #0x28
100000d20:     	ldr	x9, [sp, #0xdd0]
100000d24:     	add	x10, x10, x9, lsl #3
100000d28:     	ldr	x12, [x10]
100000d2c:     	str	x12, [sp, #0xa8]
100000d30:     	ldr	x10, [sp, #0xa8]
100000d34:     	ldr	x9, [x10]
100000d38:     	mov	x11, #0x0               ; =0
100000d3c:     	movk	x11, #0x0, lsl #16
100000d40:     	movk	x11, #0x0, lsl #32
100000d44:     	movk	x11, #0x8000, lsl #48
100000d48:     	and	x9, x9, x11
100000d4c:     	cbz	x9, 0x100000d64 <_silex_function_2+0x22c>
100000d50:     	sub	x10, x10, #0x10
100000d54:     	ldaxr	x9, [x10]
100000d58:     	add	x9, x9, #0x1
100000d5c:     	stlxr	w11, x9, [x10]
100000d60:     	cbnz	w11, 0x100000d54 <_silex_function_2+0x21c>
100000d64:     	adrp	x9, 0x100009000 <_main+0x1b80>
100000d68:     	add	x9, x9, #0x198
100000d6c:     	str	x9, [sp, #0xb0]
100000d70:     	ldr	x9, [sp, #0xa8]
100000d74:     	ldr	x10, [sp, #0xb0]
100000d78:     	ldr	x11, [x9]
100000d7c:     	mov	x14, #0xffff            ; =65535
100000d80:     	movk	x14, #0xffff, lsl #16
100000d84:     	movk	x14, #0xffff, lsl #32
100000d88:     	movk	x14, #0x7fff, lsl #48
100000d8c:     	and	x11, x11, x14
100000d90:     	ldr	x12, [x10]
100000d94:     	mov	x14, #0xffff            ; =65535
100000d98:     	movk	x14, #0xffff, lsl #16
100000d9c:     	movk	x14, #0xffff, lsl #32
100000da0:     	movk	x14, #0x7fff, lsl #48
100000da4:     	and	x12, x12, x14
100000da8:     	mov	w13, #0x0               ; =0
100000dac:     	cmp	x11, x12
100000db0:     	b.ne	0x100000de4 <_silex_function_2+0x2ac>
100000db4:     	add	x9, x9, #0x8
100000db8:     	add	x10, x10, #0x8
100000dbc:     	cbz	x11, 0x100000de0 <_silex_function_2+0x2a8>
100000dc0:     	ldrb	w14, [x9]
100000dc4:     	ldrb	w15, [x10]
100000dc8:     	cmp	x14, x15
100000dcc:     	b.ne	0x100000de4 <_silex_function_2+0x2ac>
100000dd0:     	add	x9, x9, #0x1
100000dd4:     	add	x10, x10, #0x1
100000dd8:     	sub	x11, x11, #0x1
100000ddc:     	cbnz	x11, 0x100000dc0 <_silex_function_2+0x288>
100000de0:     	mov	w13, #0x1               ; =1
100000de4:     	str	x13, [sp, #0xb8]
100000de8:     	ldr	x9, [sp, #0xb8]
100000dec:     	cbz	w9, 0x100000df4 <_silex_function_2+0x2bc>
100000df0:     	b	0x100000e10 <_silex_function_2+0x2d8>
100000df4:     	b	0x100000e1c <_silex_function_2+0x2e4>
100000df8:     	ldr	x9, [sp, #0x78]
100000dfc:     	ldr	x10, [x9]
100000e00:     	mov	x19, x10
100000e04:     	mov	x9, x19
100000e08:     	str	x9, [sp, #0xdd8]
100000e0c:     	b	0x100000f20 <_silex_function_2+0x3e8>
100000e10:     	mov	w19, #0x1               ; =1
100000e14:     	mov	x9, x19
100000e18:     	str	x9, [sp, #0xdc0]
100000e1c:     	adrp	x9, 0x100009000 <_main+0x1b80>
100000e20:     	add	x9, x9, #0x1a8
100000e24:     	str	x9, [sp, #0xc8]
100000e28:     	ldr	x9, [sp, #0xa8]
100000e2c:     	ldr	x10, [sp, #0xc8]
100000e30:     	ldr	x11, [x9]
100000e34:     	mov	x14, #0xffff            ; =65535
100000e38:     	movk	x14, #0xffff, lsl #16
100000e3c:     	movk	x14, #0xffff, lsl #32
100000e40:     	movk	x14, #0x7fff, lsl #48
100000e44:     	and	x11, x11, x14
100000e48:     	ldr	x12, [x10]
100000e4c:     	mov	x14, #0xffff            ; =65535
100000e50:     	movk	x14, #0xffff, lsl #16
100000e54:     	movk	x14, #0xffff, lsl #32
100000e58:     	movk	x14, #0x7fff, lsl #48
100000e5c:     	and	x12, x12, x14
100000e60:     	mov	w13, #0x0               ; =0
100000e64:     	cmp	x11, x12
100000e68:     	b.ne	0x100000e9c <_silex_function_2+0x364>
100000e6c:     	add	x9, x9, #0x8
100000e70:     	add	x10, x10, #0x8
100000e74:     	cbz	x11, 0x100000e98 <_silex_function_2+0x360>
100000e78:     	ldrb	w14, [x9]
100000e7c:     	ldrb	w15, [x10]
100000e80:     	cmp	x14, x15
100000e84:     	b.ne	0x100000e9c <_silex_function_2+0x364>
100000e88:     	add	x9, x9, #0x1
100000e8c:     	add	x10, x10, #0x1
100000e90:     	sub	x11, x11, #0x1
100000e94:     	cbnz	x11, 0x100000e78 <_silex_function_2+0x340>
100000e98:     	mov	w13, #0x1               ; =1
100000e9c:     	str	x13, [sp, #0xd0]
100000ea0:     	ldr	x9, [sp, #0xd0]
100000ea4:     	cbz	w9, 0x100000ec0 <_silex_function_2+0x388>
100000ea8:     	mov	w19, #0x1               ; =1
100000eac:     	mov	w20, #0x1               ; =1
100000eb0:     	mov	x9, x19
100000eb4:     	str	x9, [sp, #0xdc0]
100000eb8:     	mov	x9, x20
100000ebc:     	str	x9, [sp, #0xdc8]
100000ec0:     	ldr	x10, [sp, #0xa8]
100000ec4:     	ldr	x9, [x10]
100000ec8:     	mov	x11, #0x0               ; =0
100000ecc:     	movk	x11, #0x0, lsl #16
100000ed0:     	movk	x11, #0x0, lsl #32
100000ed4:     	movk	x11, #0x8000, lsl #48
100000ed8:     	and	x9, x9, x11
100000edc:     	cbz	x9, 0x100000f0c <_silex_function_2+0x3d4>
100000ee0:     	sub	x10, x10, #0x10
100000ee4:     	ldaxr	x9, [x10]
100000ee8:     	cbz	x9, 0x100000f0c <_silex_function_2+0x3d4>
100000eec:     	sub	x9, x9, #0x1
100000ef0:     	stlxr	w11, x9, [x10]
100000ef4:     	cbnz	w11, 0x100000ee4 <_silex_function_2+0x3ac>
100000ef8:     	cbnz	x9, 0x100000f0c <_silex_function_2+0x3d4>
100000efc:     	ldr	x1, [x10, #0x8]
100000f00:     	mov	x0, x10
100000f04:     	mov	w16, #0x49              ; =73
100000f08:     	svc	#0x80
100000f0c:     	ldr	x9, [sp, #0xdd0]
100000f10:     	add	x19, x9, #0x1
100000f14:     	mov	x9, x19
100000f18:     	str	x9, [sp, #0xdd0]
100000f1c:     	b	0x100000cf0 <_silex_function_2+0x1b8>
100000f20:     	ldr	x9, [sp, #0xdd8]
100000f24:     	cmp	x9, xzr
100000f28:     	b.eq	0x100001158 <_silex_function_2+0x620>
100000f2c:     	ldr	x9, [sp, #0xdd8]
100000f30:     	sub	x11, x9, #0x1
100000f34:     	str	x11, [sp, #0x118]
100000f38:     	ldr	x10, [sp, #0x78]
100000f3c:     	ldr	x13, [x10]
100000f40:     	ldr	x9, [sp, #0x118]
100000f44:     	cmp	x9, xzr
100000f48:     	b.ge	0x100000f50 <_silex_function_2+0x418>
100000f4c:     	add	x9, x9, x13
100000f50:     	cmp	x9, xzr
100000f54:     	b.lt	0x100000f74 <_silex_function_2+0x43c>
100000f58:     	cmp	x9, x13
100000f5c:     	b.ge	0x100000f74 <_silex_function_2+0x43c>
100000f60:     	add	x10, x10, #0x28
100000f64:     	add	x10, x10, x9, lsl #3
100000f68:     	ldr	x12, [x10]
100000f6c:     	str	x12, [sp, #0x120]
100000f70:     	b	0x1000010f8 <_silex_function_2+0x5c0>
100000f74:     	str	x13, [sp, #0x120]
100000f78:     	mov	w0, #0x2                ; =2
100000f7c:     	adrp	x1, 0x100009000 <_main+0x1b80>
100000f80:     	add	x1, x1, #0x1c8
100000f84:     	mov	x2, #0x9e               ; =158
100000f88:     	movk	x2, #0x0, lsl #16
100000f8c:     	movk	x2, #0x0, lsl #32
100000f90:     	movk	x2, #0x0, lsl #48
100000f94:     	mov	w16, #0x4               ; =4
100000f98:     	svc	#0x80
100000f9c:     	ldr	x9, [sp, #0x118]
100000fa0:     	sub	sp, sp, #0x20
100000fa4:     	add	x11, sp, #0x20
100000fa8:     	mov	w12, #0x0               ; =0
100000fac:     	cbnz	x9, 0x100000fc4 <_silex_function_2+0x48c>
100000fb0:     	sub	x11, x11, #0x1
100000fb4:     	mov	w10, #0x30              ; =48
100000fb8:     	strb	w10, [x11]
100000fbc:     	add	x12, x12, #0x1
100000fc0:     	b	0x100001018 <_silex_function_2+0x4e0>
100000fc4:     	mov	w3, #0x0                ; =0
100000fc8:     	cmp	x9, xzr
100000fcc:     	b.lt	0x100000fd8 <_silex_function_2+0x4a0>
100000fd0:     	negs	x9, x9
100000fd4:     	b	0x100000fdc <_silex_function_2+0x4a4>
100000fd8:     	mov	w3, #0x1                ; =1
100000fdc:     	mov	w10, #0xa               ; =10
100000fe0:     	sdiv	x4, x9, x10
100000fe4:     	msub	x5, x4, x10, x9
100000fe8:     	mov	w6, #0x30               ; =48
100000fec:     	subs	x6, x6, x5
100000ff0:     	sub	x11, x11, #0x1
100000ff4:     	strb	w6, [x11]
100000ff8:     	add	x12, x12, #0x1
100000ffc:     	mov	x9, x4
100001000:     	cbnz	x9, 0x100000fdc <_silex_function_2+0x4a4>
100001004:     	cbz	w3, 0x100001018 <_silex_function_2+0x4e0>
100001008:     	sub	x11, x11, #0x1
10000100c:     	mov	w10, #0x2d              ; =45
100001010:     	strb	w10, [x11]
100001014:     	add	x12, x12, #0x1
100001018:     	mov	w0, #0x2                ; =2
10000101c:     	mov	x1, x11
100001020:     	mov	x2, x12
100001024:     	mov	w16, #0x4               ; =4
100001028:     	svc	#0x80
10000102c:     	add	sp, sp, #0x20
100001030:     	mov	w0, #0x2                ; =2
100001034:     	adrp	x1, 0x100009000 <_main+0x1b80>
100001038:     	add	x1, x1, #0x178
10000103c:     	mov	x2, #0x1c               ; =28
100001040:     	movk	x2, #0x0, lsl #16
100001044:     	movk	x2, #0x0, lsl #32
100001048:     	movk	x2, #0x0, lsl #48
10000104c:     	mov	w16, #0x4               ; =4
100001050:     	svc	#0x80
100001054:     	ldr	x9, [sp, #0x120]
100001058:     	sub	sp, sp, #0x20
10000105c:     	add	x11, sp, #0x1f
100001060:     	mov	w10, #0xa               ; =10
100001064:     	strb	w10, [x11]
100001068:     	mov	w12, #0x1               ; =1
10000106c:     	cbnz	x9, 0x100001084 <_silex_function_2+0x54c>
100001070:     	sub	x11, x11, #0x1
100001074:     	mov	w10, #0x30              ; =48
100001078:     	strb	w10, [x11]
10000107c:     	add	x12, x12, #0x1
100001080:     	b	0x1000010d8 <_silex_function_2+0x5a0>
100001084:     	mov	w3, #0x0                ; =0
100001088:     	cmp	x9, xzr
10000108c:     	b.lt	0x100001098 <_silex_function_2+0x560>
100001090:     	negs	x9, x9
100001094:     	b	0x10000109c <_silex_function_2+0x564>
100001098:     	mov	w3, #0x1                ; =1
10000109c:     	mov	w10, #0xa               ; =10
1000010a0:     	sdiv	x4, x9, x10
1000010a4:     	msub	x5, x4, x10, x9
1000010a8:     	mov	w6, #0x30               ; =48
1000010ac:     	subs	x6, x6, x5
1000010b0:     	sub	x11, x11, #0x1
1000010b4:     	strb	w6, [x11]
1000010b8:     	add	x12, x12, #0x1
1000010bc:     	mov	x9, x4
1000010c0:     	cbnz	x9, 0x10000109c <_silex_function_2+0x564>
1000010c4:     	cbz	w3, 0x1000010d8 <_silex_function_2+0x5a0>
1000010c8:     	sub	x11, x11, #0x1
1000010cc:     	mov	w10, #0x2d              ; =45
1000010d0:     	strb	w10, [x11]
1000010d4:     	add	x12, x12, #0x1
1000010d8:     	mov	w0, #0x2                ; =2
1000010dc:     	mov	x1, x11
1000010e0:     	mov	x2, x12
1000010e4:     	mov	w16, #0x4               ; =4
1000010e8:     	svc	#0x80
1000010ec:     	add	sp, sp, #0x20
1000010f0:     	mov	w8, #0x3                ; =3
1000010f4:     	b	0x100003554 <_silex_function_2+0x2a1c>
1000010f8:     	ldr	x10, [sp, #0x120]
1000010fc:     	ldr	x9, [x10]
100001100:     	mov	x11, #0x0               ; =0
100001104:     	movk	x11, #0x0, lsl #16
100001108:     	movk	x11, #0x0, lsl #32
10000110c:     	movk	x11, #0x8000, lsl #48
100001110:     	and	x9, x9, x11
100001114:     	cbz	x9, 0x100001144 <_silex_function_2+0x60c>
100001118:     	sub	x10, x10, #0x10
10000111c:     	ldaxr	x9, [x10]
100001120:     	cbz	x9, 0x100001144 <_silex_function_2+0x60c>
100001124:     	sub	x9, x9, #0x1
100001128:     	stlxr	w11, x9, [x10]
10000112c:     	cbnz	w11, 0x10000111c <_silex_function_2+0x5e4>
100001130:     	cbnz	x9, 0x100001144 <_silex_function_2+0x60c>
100001134:     	ldr	x1, [x10, #0x8]
100001138:     	mov	x0, x10
10000113c:     	mov	w16, #0x49              ; =73
100001140:     	svc	#0x80
100001144:     	ldr	x9, [sp, #0x118]
100001148:     	str	x9, [sp, #0xdd8]
10000114c:     	ldr	x9, [sp, #0xdd8]
100001150:     	cmp	x9, xzr
100001154:     	b.ne	0x100000f2c <_silex_function_2+0x3f4>
100001158:     	ldr	x10, [sp, #0x78]
10000115c:     	add	x14, x10, #0x8
100001160:     	ldaxr	x9, [x14]
100001164:     	cbz	x9, 0x1000011bc <_silex_function_2+0x684>
100001168:     	sub	x9, x9, #0x1
10000116c:     	stlxr	w11, x9, [x14]
100001170:     	cbnz	w11, 0x100001160 <_silex_function_2+0x628>
100001174:     	ldr	x11, [x10, #0x10]
100001178:     	add	x9, x9, x11
10000117c:     	cbnz	x9, 0x1000011bc <_silex_function_2+0x684>
100001180:     	add	x14, x10, #0x20
100001184:     	ldaxr	x9, [x14]
100001188:     	mov	x11, #0x2               ; =2
10000118c:     	cmp	x9, x11
100001190:     	b.eq	0x100001184 <_silex_function_2+0x64c>
100001194:     	mov	x11, #0x1               ; =1
100001198:     	cmp	x9, x11
10000119c:     	b.eq	0x1000011bc <_silex_function_2+0x684>
1000011a0:     	mov	x9, #0x1                ; =1
1000011a4:     	stlxr	w11, x9, [x14]
1000011a8:     	cbnz	w11, 0x100001184 <_silex_function_2+0x64c>
1000011ac:     	ldr	x1, [x10, #0x18]
1000011b0:     	mov	x0, x10
1000011b4:     	mov	w16, #0x49              ; =73
1000011b8:     	svc	#0x80
1000011bc:     	mov	x20, #0x2000            ; =8192
1000011c0:     	mov	x19, #0x800             ; =2048
1000011c4:     	mov	x9, x20
1000011c8:     	str	x9, [sp, #0xde0]
1000011cc:     	mov	x9, x19
1000011d0:     	str	x9, [sp, #0xde8]
1000011d4:     	ldr	x9, [sp, #0xdc0]
1000011d8:     	cbz	w9, 0x100001214 <_silex_function_2+0x6dc>
1000011dc:     	mov	x20, #0x10              ; =16
1000011e0:     	mov	w21, #0x0               ; =0
1000011e4:     	ldr	x9, [sp, #0xdc8]
1000011e8:     	cmp	x9, x21
1000011ec:     	mov	x9, x20
1000011f0:     	str	x9, [sp, #0xde0]
1000011f4:     	mov	x9, x19
1000011f8:     	str	x9, [sp, #0xde8]
1000011fc:     	b.ne	0x100001214 <_silex_function_2+0x6dc>
100001200:     	mov	x19, #0x8               ; =8
100001204:     	mov	x9, x20
100001208:     	str	x9, [sp, #0xde0]
10000120c:     	mov	x9, x19
100001210:     	str	x9, [sp, #0xde8]
100001214:     	mov	x1, #0x4000             ; =16384
100001218:     	mov	w0, #0x0                ; =0
10000121c:     	mov	w2, #0x3                ; =3
100001220:     	mov	w3, #0x1002             ; =4098
100001224:     	mov	x4, #0xffff             ; =65535
100001228:     	movk	x4, #0xffff, lsl #16
10000122c:     	movk	x4, #0xffff, lsl #32
100001230:     	movk	x4, #0xffff, lsl #48
100001234:     	mov	w5, #0x0                ; =0
100001238:     	mov	w16, #0xc5              ; =197
10000123c:     	svc	#0x80
100001240:     	b.hs	0x10000126c <_silex_function_2+0x734>
100001244:     	mov	x15, x0
100001248:     	mov	x9, #0x0                ; =0
10000124c:     	str	x9, [x15]
100001250:     	mov	x9, #0x1                ; =1
100001254:     	str	x9, [x15, #0x8]
100001258:     	mov	x9, #0x4000             ; =16384
10000125c:     	str	x9, [x15, #0x18]
100001260:     	add	x14, x15, #0x28
100001264:     	str	x15, [sp, #0x158]
100001268:     	b	0x100001274 <_silex_function_2+0x73c>
10000126c:     	mov	w8, #0x3                ; =3
100001270:     	b	0x100003554 <_silex_function_2+0x2a1c>
100001274:     	ldr	x9, [sp, #0x158]
100001278:     	str	x9, [sp, #0x11e0]
10000127c:     	mov	x1, #0x4000             ; =16384
100001280:     	mov	w0, #0x0                ; =0
100001284:     	mov	w2, #0x3                ; =3
100001288:     	mov	w3, #0x1002             ; =4098
10000128c:     	mov	x4, #0xffff             ; =65535
100001290:     	movk	x4, #0xffff, lsl #16
100001294:     	movk	x4, #0xffff, lsl #32
100001298:     	movk	x4, #0xffff, lsl #48
10000129c:     	mov	w5, #0x0                ; =0
1000012a0:     	mov	w16, #0xc5              ; =197
1000012a4:     	svc	#0x80
1000012a8:     	b.hs	0x1000012d4 <_silex_function_2+0x79c>
1000012ac:     	mov	x15, x0
1000012b0:     	mov	x9, #0x0                ; =0
1000012b4:     	str	x9, [x15]
1000012b8:     	mov	x9, #0x1                ; =1
1000012bc:     	str	x9, [x15, #0x8]
1000012c0:     	mov	x9, #0x4000             ; =16384
1000012c4:     	str	x9, [x15, #0x18]
1000012c8:     	add	x14, x15, #0x28
1000012cc:     	str	x15, [sp, #0x160]
1000012d0:     	b	0x1000012dc <_silex_function_2+0x7a4>
1000012d4:     	mov	w8, #0x3                ; =3
1000012d8:     	b	0x100003554 <_silex_function_2+0x2a1c>
1000012dc:     	ldr	x9, [sp, #0x160]
1000012e0:     	str	x9, [sp, #0x11e8]
1000012e4:     	movz	x19, #0x0, lsl #48
1000012e8:     	mov	x9, x19
1000012ec:     	str	x9, [sp, #0xdf0]
1000012f0:     	mov	x19, #0x10              ; =16
1000012f4:     	ldr	x9, [sp, #0xdf0]
1000012f8:     	cmp	x9, x19
1000012fc:     	b.ge	0x100001310 <_silex_function_2+0x7d8>
100001300:     	movz	x19, #0x0, lsl #48
100001304:     	mov	x9, x19
100001308:     	str	x9, [sp, #0xdf8]
10000130c:     	b	0x100001320 <_silex_function_2+0x7e8>
100001310:     	movz	x19, #0x0, lsl #48
100001314:     	mov	x9, x19
100001318:     	str	x9, [sp, #0xe00]
10000131c:     	b	0x1000016d8 <_silex_function_2+0xba0>
100001320:     	ldr	x9, [sp, #0xdf8]
100001324:     	ldr	x10, [sp, #0xde0]
100001328:     	cmp	x9, x10
10000132c:     	b.ge	0x1000016c4 <_silex_function_2+0xb8c>
100001330:     	ldr	x9, [sp, #0x11e0]
100001334:     	str	x9, [sp, #0x190]
100001338:     	ldr	x0, [sp, #0xdf8]
10000133c:     	ldr	x1, [sp, #0xdf0]
100001340:     	add	x15, sp, #0x198
100001344:     	bl	0x10000073c <_silex_function_1>
100001348:     	cbnz	w8, 0x100003554 <_silex_function_2+0x2a1c>
10000134c:     	ldr	x10, [sp, #0x190]
100001350:     	ldr	x13, [x10]
100001354:     	mov	w9, #0x0                ; =0
100001358:     	mov	x12, x13
10000135c:     	add	x12, x12, #0x1
100001360:     	ldr	x11, [x10, #0x8]
100001364:     	ldr	x5, [x10, #0x10]
100001368:     	add	x11, x11, x5
10000136c:     	mov	x5, #0x1                ; =1
100001370:     	cmp	x11, x5
100001374:     	b.ne	0x10000146c <_silex_function_2+0x934>
100001378:     	mov	x11, #0xc0              ; =192
10000137c:     	mul	x5, x12, x11
100001380:     	add	x5, x5, #0x28
100001384:     	ldr	x11, [x10, #0x18]
100001388:     	cmp	x5, x11
10000138c:     	b.hi	0x10000146c <_silex_function_2+0x934>
100001390:     	add	x14, x10, #0x28
100001394:     	mov	x11, #0xc0              ; =192
100001398:     	mul	x5, x13, x11
10000139c:     	add	x14, x14, x5
1000013a0:     	ldr	x5, [sp, #0x198]
1000013a4:     	str	x5, [x14]
1000013a8:     	ldr	x5, [sp, #0x1a0]
1000013ac:     	str	x5, [x14, #0x8]
1000013b0:     	ldr	x5, [sp, #0x1a8]
1000013b4:     	str	x5, [x14, #0x10]
1000013b8:     	ldr	x5, [sp, #0x1b0]
1000013bc:     	str	x5, [x14, #0x18]
1000013c0:     	ldr	x5, [sp, #0x1b8]
1000013c4:     	str	x5, [x14, #0x20]
1000013c8:     	ldr	x5, [sp, #0x1c0]
1000013cc:     	str	x5, [x14, #0x28]
1000013d0:     	ldr	x5, [sp, #0x1c8]
1000013d4:     	str	x5, [x14, #0x30]
1000013d8:     	ldr	x5, [sp, #0x1d0]
1000013dc:     	str	x5, [x14, #0x38]
1000013e0:     	ldr	x5, [sp, #0x1d8]
1000013e4:     	str	x5, [x14, #0x40]
1000013e8:     	ldr	x5, [sp, #0x1e0]
1000013ec:     	str	x5, [x14, #0x48]
1000013f0:     	ldr	x5, [sp, #0x1e8]
1000013f4:     	str	x5, [x14, #0x50]
1000013f8:     	ldr	x5, [sp, #0x1f0]
1000013fc:     	str	x5, [x14, #0x58]
100001400:     	ldr	x5, [sp, #0x1f8]
100001404:     	str	x5, [x14, #0x60]
100001408:     	ldr	x5, [sp, #0x200]
10000140c:     	str	x5, [x14, #0x68]
100001410:     	ldr	x5, [sp, #0x208]
100001414:     	str	x5, [x14, #0x70]
100001418:     	ldr	x5, [sp, #0x210]
10000141c:     	str	x5, [x14, #0x78]
100001420:     	ldr	x5, [sp, #0x218]
100001424:     	str	x5, [x14, #0x80]
100001428:     	ldr	x5, [sp, #0x220]
10000142c:     	str	x5, [x14, #0x88]
100001430:     	ldr	x5, [sp, #0x228]
100001434:     	str	x5, [x14, #0x90]
100001438:     	ldr	x5, [sp, #0x230]
10000143c:     	str	x5, [x14, #0x98]
100001440:     	ldr	x5, [sp, #0x238]
100001444:     	str	x5, [x14, #0xa0]
100001448:     	ldr	x5, [sp, #0x240]
10000144c:     	str	x5, [x14, #0xa8]
100001450:     	ldr	x5, [sp, #0x248]
100001454:     	str	x5, [x14, #0xb0]
100001458:     	ldr	x5, [sp, #0x250]
10000145c:     	str	x5, [x14, #0xb8]
100001460:     	str	x12, [x10]
100001464:     	str	x10, [sp, #0x258]
100001468:     	b	0x10000168c <_silex_function_2+0xb54>
10000146c:     	sub	sp, sp, #0x30
100001470:     	str	x10, [sp]
100001474:     	str	x13, [sp, #0x8]
100001478:     	str	x9, [sp, #0x10]
10000147c:     	str	x12, [sp, #0x18]
100001480:     	str	x7, [sp, #0x20]
100001484:     	str	x6, [sp, #0x28]
100001488:     	mov	x11, #0xc0              ; =192
10000148c:     	mul	x1, x12, x11
100001490:     	add	x1, x1, #0x28
100001494:     	mov	x5, #0x4000             ; =16384
100001498:     	cmp	x1, x5
10000149c:     	b.hs	0x1000014a4 <_silex_function_2+0x96c>
1000014a0:     	mov	x1, x5
1000014a4:     	add	x1, x1, x1
1000014a8:     	mov	w0, #0x0                ; =0
1000014ac:     	mov	w2, #0x3                ; =3
1000014b0:     	mov	w3, #0x1002             ; =4098
1000014b4:     	mov	x4, #0xffff             ; =65535
1000014b8:     	movk	x4, #0xffff, lsl #16
1000014bc:     	movk	x4, #0xffff, lsl #32
1000014c0:     	movk	x4, #0xffff, lsl #48
1000014c4:     	mov	w5, #0x0                ; =0
1000014c8:     	mov	w16, #0xc5              ; =197
1000014cc:     	svc	#0x80
1000014d0:     	b.hs	0x100001690 <_silex_function_2+0xb58>
1000014d4:     	mov	x15, x0
1000014d8:     	ldr	x10, [sp]
1000014dc:     	ldr	x13, [sp, #0x8]
1000014e0:     	ldr	x9, [sp, #0x10]
1000014e4:     	ldr	x12, [sp, #0x18]
1000014e8:     	ldr	x7, [sp, #0x20]
1000014ec:     	ldr	x6, [sp, #0x28]
1000014f0:     	str	x12, [x15]
1000014f4:     	mov	x5, #0x1                ; =1
1000014f8:     	str	x5, [x15, #0x8]
1000014fc:     	mov	x11, #0xc0              ; =192
100001500:     	mul	x11, x12, x11
100001504:     	add	x11, x11, #0x28
100001508:     	mov	x5, #0x4000             ; =16384
10000150c:     	cmp	x11, x5
100001510:     	b.hs	0x100001518 <_silex_function_2+0x9e0>
100001514:     	mov	x11, x5
100001518:     	add	x11, x11, x11
10000151c:     	str	x11, [x15, #0x18]
100001520:     	add	x10, x10, #0x28
100001524:     	add	x14, x15, #0x28
100001528:     	mov	x11, #0x18              ; =24
10000152c:     	mul	x12, x13, x11
100001530:     	cbz	x12, 0x10000154c <_silex_function_2+0xa14>
100001534:     	ldr	x11, [x10]
100001538:     	str	x11, [x14]
10000153c:     	add	x10, x10, #0x8
100001540:     	add	x14, x14, #0x8
100001544:     	sub	x12, x12, #0x1
100001548:     	cbnz	x12, 0x100001534 <_silex_function_2+0x9fc>
10000154c:     	add	sp, sp, #0x30
100001550:     	mov	x9, x13
100001554:     	add	x14, x15, #0x28
100001558:     	mov	x11, #0xc0              ; =192
10000155c:     	mul	x9, x9, x11
100001560:     	add	x14, x14, x9
100001564:     	ldr	x12, [sp, #0x198]
100001568:     	str	x12, [x14]
10000156c:     	ldr	x12, [sp, #0x1a0]
100001570:     	str	x12, [x14, #0x8]
100001574:     	ldr	x12, [sp, #0x1a8]
100001578:     	str	x12, [x14, #0x10]
10000157c:     	ldr	x12, [sp, #0x1b0]
100001580:     	str	x12, [x14, #0x18]
100001584:     	ldr	x12, [sp, #0x1b8]
100001588:     	str	x12, [x14, #0x20]
10000158c:     	ldr	x12, [sp, #0x1c0]
100001590:     	str	x12, [x14, #0x28]
100001594:     	ldr	x12, [sp, #0x1c8]
100001598:     	str	x12, [x14, #0x30]
10000159c:     	ldr	x12, [sp, #0x1d0]
1000015a0:     	str	x12, [x14, #0x38]
1000015a4:     	ldr	x12, [sp, #0x1d8]
1000015a8:     	str	x12, [x14, #0x40]
1000015ac:     	ldr	x12, [sp, #0x1e0]
1000015b0:     	str	x12, [x14, #0x48]
1000015b4:     	ldr	x12, [sp, #0x1e8]
1000015b8:     	str	x12, [x14, #0x50]
1000015bc:     	ldr	x12, [sp, #0x1f0]
1000015c0:     	str	x12, [x14, #0x58]
1000015c4:     	ldr	x12, [sp, #0x1f8]
1000015c8:     	str	x12, [x14, #0x60]
1000015cc:     	ldr	x12, [sp, #0x200]
1000015d0:     	str	x12, [x14, #0x68]
1000015d4:     	ldr	x12, [sp, #0x208]
1000015d8:     	str	x12, [x14, #0x70]
1000015dc:     	ldr	x12, [sp, #0x210]
1000015e0:     	str	x12, [x14, #0x78]
1000015e4:     	ldr	x12, [sp, #0x218]
1000015e8:     	str	x12, [x14, #0x80]
1000015ec:     	ldr	x12, [sp, #0x220]
1000015f0:     	str	x12, [x14, #0x88]
1000015f4:     	ldr	x12, [sp, #0x228]
1000015f8:     	str	x12, [x14, #0x90]
1000015fc:     	ldr	x12, [sp, #0x230]
100001600:     	str	x12, [x14, #0x98]
100001604:     	ldr	x12, [sp, #0x238]
100001608:     	str	x12, [x14, #0xa0]
10000160c:     	ldr	x12, [sp, #0x240]
100001610:     	str	x12, [x14, #0xa8]
100001614:     	ldr	x12, [sp, #0x248]
100001618:     	str	x12, [x14, #0xb0]
10000161c:     	ldr	x12, [sp, #0x250]
100001620:     	str	x12, [x14, #0xb8]
100001624:     	str	x15, [sp, #0x258]
100001628:     	ldr	x10, [sp, #0x190]
10000162c:     	add	x14, x10, #0x8
100001630:     	ldaxr	x9, [x14]
100001634:     	cbz	x9, 0x10000168c <_silex_function_2+0xb54>
100001638:     	sub	x9, x9, #0x1
10000163c:     	stlxr	w11, x9, [x14]
100001640:     	cbnz	w11, 0x100001630 <_silex_function_2+0xaf8>
100001644:     	ldr	x11, [x10, #0x10]
100001648:     	add	x9, x9, x11
10000164c:     	cbnz	x9, 0x10000168c <_silex_function_2+0xb54>
100001650:     	add	x14, x10, #0x20
100001654:     	ldaxr	x9, [x14]
100001658:     	mov	x11, #0x2               ; =2
10000165c:     	cmp	x9, x11
100001660:     	b.eq	0x100001654 <_silex_function_2+0xb1c>
100001664:     	mov	x11, #0x1               ; =1
100001668:     	cmp	x9, x11
10000166c:     	b.eq	0x10000168c <_silex_function_2+0xb54>
100001670:     	mov	x9, #0x1                ; =1
100001674:     	stlxr	w11, x9, [x14]
100001678:     	cbnz	w11, 0x100001654 <_silex_function_2+0xb1c>
10000167c:     	ldr	x1, [x10, #0x18]
100001680:     	mov	x0, x10
100001684:     	mov	w16, #0x49              ; =73
100001688:     	svc	#0x80
10000168c:     	b	0x10000169c <_silex_function_2+0xb64>
100001690:     	add	sp, sp, #0x30
100001694:     	mov	w8, #0x3                ; =3
100001698:     	b	0x100003554 <_silex_function_2+0x2a1c>
10000169c:     	ldr	x9, [sp, #0x258]
1000016a0:     	str	x9, [sp, #0x11e0]
1000016a4:     	ldr	x9, [sp, #0xdf8]
1000016a8:     	add	x20, x9, #0x1
1000016ac:     	mov	x9, x20
1000016b0:     	str	x9, [sp, #0xdf8]
1000016b4:     	ldr	x9, [sp, #0xdf8]
1000016b8:     	ldr	x10, [sp, #0xde0]
1000016bc:     	cmp	x9, x10
1000016c0:     	b.lt	0x100001330 <_silex_function_2+0x7f8>
1000016c4:     	ldr	x9, [sp, #0xdf0]
1000016c8:     	add	x20, x9, #0x1
1000016cc:     	mov	x9, x20
1000016d0:     	str	x9, [sp, #0xdf0]
1000016d4:     	b	0x1000012f0 <_silex_function_2+0x7b8>
1000016d8:     	ldr	x9, [sp, #0xe00]
1000016dc:     	ldr	x10, [sp, #0xde0]
1000016e0:     	cmp	x9, x10
1000016e4:     	b.ge	0x100001b58 <_silex_function_2+0x1020>
1000016e8:     	ldr	x9, [sp, #0x11e8]
1000016ec:     	str	x9, [sp, #0x290]
1000016f0:     	movi	d16, #0000000000000000
1000016f4:     	movi	d17, #0000000000000000
1000016f8:     	movi	d18, #0000000000000000
1000016fc:     	movi	d19, #0000000000000000
100001700:     	movi	d20, #0000000000000000
100001704:     	movi	d21, #0000000000000000
100001708:     	movi	d22, #0000000000000000
10000170c:     	movi	d23, #0000000000000000
100001710:     	movi	d24, #0000000000000000
100001714:     	movi	d25, #0000000000000000
100001718:     	movi	d26, #0000000000000000
10000171c:     	movi	d27, #0000000000000000
100001720:     	movi	d28, #0000000000000000
100001724:     	movi	d29, #0000000000000000
100001728:     	movi	d30, #0000000000000000
10000172c:     	movi	d31, #0000000000000000
100001730:     	movi	d0, #0000000000000000
100001734:     	movi	d1, #0000000000000000
100001738:     	movi	d2, #0000000000000000
10000173c:     	movi	d3, #0000000000000000
100001740:     	movi	d4, #0000000000000000
100001744:     	movi	d5, #0000000000000000
100001748:     	movi	d8, #0000000000000000
10000174c:     	movi	d13, #0000000000000000
100001750:     	movi	d14, #0000000000000000
100001754:     	movi	d15, #0000000000000000
100001758:     	str	d16, [sp, #0x368]
10000175c:     	str	d17, [sp, #0x370]
100001760:     	str	d18, [sp, #0x378]
100001764:     	str	d19, [sp, #0x380]
100001768:     	str	d20, [sp, #0x388]
10000176c:     	str	d21, [sp, #0x390]
100001770:     	str	d22, [sp, #0x398]
100001774:     	str	d23, [sp, #0x3a0]
100001778:     	str	d24, [sp, #0x3a8]
10000177c:     	str	d25, [sp, #0x3b0]
100001780:     	str	d26, [sp, #0x3b8]
100001784:     	str	d27, [sp, #0x3c0]
100001788:     	str	d28, [sp, #0x3c8]
10000178c:     	str	d29, [sp, #0x3d0]
100001790:     	str	d30, [sp, #0x3d8]
100001794:     	str	d31, [sp, #0x3e0]
100001798:     	str	d0, [sp, #0x3e8]
10000179c:     	str	d1, [sp, #0x3f0]
1000017a0:     	str	d2, [sp, #0x3f8]
1000017a4:     	str	d3, [sp, #0x400]
1000017a8:     	str	d4, [sp, #0x408]
1000017ac:     	str	d5, [sp, #0x410]
1000017b0:     	str	d8, [sp, #0x418]
1000017b4:     	str	d13, [sp, #0x420]
1000017b8:     	str	d14, [sp, #0x428]
1000017bc:     	str	d15, [sp, #0x430]
1000017c0:     	ldr	x10, [sp, #0x290]
1000017c4:     	ldr	x13, [x10]
1000017c8:     	mov	w9, #0x0                ; =0
1000017cc:     	mov	x12, x13
1000017d0:     	add	x12, x12, #0x1
1000017d4:     	ldr	x11, [x10, #0x8]
1000017d8:     	ldr	x5, [x10, #0x10]
1000017dc:     	add	x11, x11, x5
1000017e0:     	mov	x5, #0x1                ; =1
1000017e4:     	cmp	x11, x5
1000017e8:     	b.ne	0x1000018f0 <_silex_function_2+0xdb8>
1000017ec:     	mov	x11, #0xd0              ; =208
1000017f0:     	mul	x5, x12, x11
1000017f4:     	add	x5, x5, #0x28
1000017f8:     	ldr	x11, [x10, #0x18]
1000017fc:     	cmp	x5, x11
100001800:     	b.hi	0x1000018f0 <_silex_function_2+0xdb8>
100001804:     	add	x14, x10, #0x28
100001808:     	mov	x11, #0xd0              ; =208
10000180c:     	mul	x5, x13, x11
100001810:     	add	x14, x14, x5
100001814:     	ldr	x5, [sp, #0x368]
100001818:     	str	x5, [x14]
10000181c:     	ldr	x5, [sp, #0x370]
100001820:     	str	x5, [x14, #0x8]
100001824:     	ldr	x5, [sp, #0x378]
100001828:     	str	x5, [x14, #0x10]
10000182c:     	ldr	x5, [sp, #0x380]
100001830:     	str	x5, [x14, #0x18]
100001834:     	ldr	x5, [sp, #0x388]
100001838:     	str	x5, [x14, #0x20]
10000183c:     	ldr	x5, [sp, #0x390]
100001840:     	str	x5, [x14, #0x28]
100001844:     	ldr	x5, [sp, #0x398]
100001848:     	str	x5, [x14, #0x30]
10000184c:     	ldr	x5, [sp, #0x3a0]
100001850:     	str	x5, [x14, #0x38]
100001854:     	ldr	x5, [sp, #0x3a8]
100001858:     	str	x5, [x14, #0x40]
10000185c:     	ldr	x5, [sp, #0x3b0]
100001860:     	str	x5, [x14, #0x48]
100001864:     	ldr	x5, [sp, #0x3b8]
100001868:     	str	x5, [x14, #0x50]
10000186c:     	ldr	x5, [sp, #0x3c0]
100001870:     	str	x5, [x14, #0x58]
100001874:     	ldr	x5, [sp, #0x3c8]
100001878:     	str	x5, [x14, #0x60]
10000187c:     	ldr	x5, [sp, #0x3d0]
100001880:     	str	x5, [x14, #0x68]
100001884:     	ldr	x5, [sp, #0x3d8]
100001888:     	str	x5, [x14, #0x70]
10000188c:     	ldr	x5, [sp, #0x3e0]
100001890:     	str	x5, [x14, #0x78]
100001894:     	ldr	x5, [sp, #0x3e8]
100001898:     	str	x5, [x14, #0x80]
10000189c:     	ldr	x5, [sp, #0x3f0]
1000018a0:     	str	x5, [x14, #0x88]
1000018a4:     	ldr	x5, [sp, #0x3f8]
1000018a8:     	str	x5, [x14, #0x90]
1000018ac:     	ldr	x5, [sp, #0x400]
1000018b0:     	str	x5, [x14, #0x98]
1000018b4:     	ldr	x5, [sp, #0x408]
1000018b8:     	str	x5, [x14, #0xa0]
1000018bc:     	ldr	x5, [sp, #0x410]
1000018c0:     	str	x5, [x14, #0xa8]
1000018c4:     	ldr	x5, [sp, #0x418]
1000018c8:     	str	x5, [x14, #0xb0]
1000018cc:     	ldr	x5, [sp, #0x420]
1000018d0:     	str	x5, [x14, #0xb8]
1000018d4:     	ldr	x5, [sp, #0x428]
1000018d8:     	str	x5, [x14, #0xc0]
1000018dc:     	ldr	x5, [sp, #0x430]
1000018e0:     	str	x5, [x14, #0xc8]
1000018e4:     	str	x12, [x10]
1000018e8:     	str	x10, [sp, #0x438]
1000018ec:     	b	0x100001b20 <_silex_function_2+0xfe8>
1000018f0:     	sub	sp, sp, #0x30
1000018f4:     	str	x10, [sp]
1000018f8:     	str	x13, [sp, #0x8]
1000018fc:     	str	x9, [sp, #0x10]
100001900:     	str	x12, [sp, #0x18]
100001904:     	str	x7, [sp, #0x20]
100001908:     	str	x6, [sp, #0x28]
10000190c:     	mov	x11, #0xd0              ; =208
100001910:     	mul	x1, x12, x11
100001914:     	add	x1, x1, #0x28
100001918:     	mov	x5, #0x4000             ; =16384
10000191c:     	cmp	x1, x5
100001920:     	b.hs	0x100001928 <_silex_function_2+0xdf0>
100001924:     	mov	x1, x5
100001928:     	add	x1, x1, x1
10000192c:     	mov	w0, #0x0                ; =0
100001930:     	mov	w2, #0x3                ; =3
100001934:     	mov	w3, #0x1002             ; =4098
100001938:     	mov	x4, #0xffff             ; =65535
10000193c:     	movk	x4, #0xffff, lsl #16
100001940:     	movk	x4, #0xffff, lsl #32
100001944:     	movk	x4, #0xffff, lsl #48
100001948:     	mov	w5, #0x0                ; =0
10000194c:     	mov	w16, #0xc5              ; =197
100001950:     	svc	#0x80
100001954:     	b.hs	0x100001b24 <_silex_function_2+0xfec>
100001958:     	mov	x15, x0
10000195c:     	ldr	x10, [sp]
100001960:     	ldr	x13, [sp, #0x8]
100001964:     	ldr	x9, [sp, #0x10]
100001968:     	ldr	x12, [sp, #0x18]
10000196c:     	ldr	x7, [sp, #0x20]
100001970:     	ldr	x6, [sp, #0x28]
100001974:     	str	x12, [x15]
100001978:     	mov	x5, #0x1                ; =1
10000197c:     	str	x5, [x15, #0x8]
100001980:     	mov	x11, #0xd0              ; =208
100001984:     	mul	x11, x12, x11
100001988:     	add	x11, x11, #0x28
10000198c:     	mov	x5, #0x4000             ; =16384
100001990:     	cmp	x11, x5
100001994:     	b.hs	0x10000199c <_silex_function_2+0xe64>
100001998:     	mov	x11, x5
10000199c:     	add	x11, x11, x11
1000019a0:     	str	x11, [x15, #0x18]
1000019a4:     	add	x10, x10, #0x28
1000019a8:     	add	x14, x15, #0x28
1000019ac:     	mov	x11, #0x1a              ; =26
1000019b0:     	mul	x12, x13, x11
1000019b4:     	cbz	x12, 0x1000019d0 <_silex_function_2+0xe98>
1000019b8:     	ldr	x11, [x10]
1000019bc:     	str	x11, [x14]
1000019c0:     	add	x10, x10, #0x8
1000019c4:     	add	x14, x14, #0x8
1000019c8:     	sub	x12, x12, #0x1
1000019cc:     	cbnz	x12, 0x1000019b8 <_silex_function_2+0xe80>
1000019d0:     	add	sp, sp, #0x30
1000019d4:     	mov	x9, x13
1000019d8:     	add	x14, x15, #0x28
1000019dc:     	mov	x11, #0xd0              ; =208
1000019e0:     	mul	x9, x9, x11
1000019e4:     	add	x14, x14, x9
1000019e8:     	ldr	x12, [sp, #0x368]
1000019ec:     	str	x12, [x14]
1000019f0:     	ldr	x12, [sp, #0x370]
1000019f4:     	str	x12, [x14, #0x8]
1000019f8:     	ldr	x12, [sp, #0x378]
1000019fc:     	str	x12, [x14, #0x10]
100001a00:     	ldr	x12, [sp, #0x380]
100001a04:     	str	x12, [x14, #0x18]
100001a08:     	ldr	x12, [sp, #0x388]
100001a0c:     	str	x12, [x14, #0x20]
100001a10:     	ldr	x12, [sp, #0x390]
100001a14:     	str	x12, [x14, #0x28]
100001a18:     	ldr	x12, [sp, #0x398]
100001a1c:     	str	x12, [x14, #0x30]
100001a20:     	ldr	x12, [sp, #0x3a0]
100001a24:     	str	x12, [x14, #0x38]
100001a28:     	ldr	x12, [sp, #0x3a8]
100001a2c:     	str	x12, [x14, #0x40]
100001a30:     	ldr	x12, [sp, #0x3b0]
100001a34:     	str	x12, [x14, #0x48]
100001a38:     	ldr	x12, [sp, #0x3b8]
100001a3c:     	str	x12, [x14, #0x50]
100001a40:     	ldr	x12, [sp, #0x3c0]
100001a44:     	str	x12, [x14, #0x58]
100001a48:     	ldr	x12, [sp, #0x3c8]
100001a4c:     	str	x12, [x14, #0x60]
100001a50:     	ldr	x12, [sp, #0x3d0]
100001a54:     	str	x12, [x14, #0x68]
100001a58:     	ldr	x12, [sp, #0x3d8]
100001a5c:     	str	x12, [x14, #0x70]
100001a60:     	ldr	x12, [sp, #0x3e0]
100001a64:     	str	x12, [x14, #0x78]
100001a68:     	ldr	x12, [sp, #0x3e8]
100001a6c:     	str	x12, [x14, #0x80]
100001a70:     	ldr	x12, [sp, #0x3f0]
100001a74:     	str	x12, [x14, #0x88]
100001a78:     	ldr	x12, [sp, #0x3f8]
100001a7c:     	str	x12, [x14, #0x90]
100001a80:     	ldr	x12, [sp, #0x400]
100001a84:     	str	x12, [x14, #0x98]
100001a88:     	ldr	x12, [sp, #0x408]
100001a8c:     	str	x12, [x14, #0xa0]
100001a90:     	ldr	x12, [sp, #0x410]
100001a94:     	str	x12, [x14, #0xa8]
100001a98:     	ldr	x12, [sp, #0x418]
100001a9c:     	str	x12, [x14, #0xb0]
100001aa0:     	ldr	x12, [sp, #0x420]
100001aa4:     	str	x12, [x14, #0xb8]
100001aa8:     	ldr	x12, [sp, #0x428]
100001aac:     	str	x12, [x14, #0xc0]
100001ab0:     	ldr	x12, [sp, #0x430]
100001ab4:     	str	x12, [x14, #0xc8]
100001ab8:     	str	x15, [sp, #0x438]
100001abc:     	ldr	x10, [sp, #0x290]
100001ac0:     	add	x14, x10, #0x8
100001ac4:     	ldaxr	x9, [x14]
100001ac8:     	cbz	x9, 0x100001b20 <_silex_function_2+0xfe8>
100001acc:     	sub	x9, x9, #0x1
100001ad0:     	stlxr	w11, x9, [x14]
100001ad4:     	cbnz	w11, 0x100001ac4 <_silex_function_2+0xf8c>
100001ad8:     	ldr	x11, [x10, #0x10]
100001adc:     	add	x9, x9, x11
100001ae0:     	cbnz	x9, 0x100001b20 <_silex_function_2+0xfe8>
100001ae4:     	add	x14, x10, #0x20
100001ae8:     	ldaxr	x9, [x14]
100001aec:     	mov	x11, #0x2               ; =2
100001af0:     	cmp	x9, x11
100001af4:     	b.eq	0x100001ae8 <_silex_function_2+0xfb0>
100001af8:     	mov	x11, #0x1               ; =1
100001afc:     	cmp	x9, x11
100001b00:     	b.eq	0x100001b20 <_silex_function_2+0xfe8>
100001b04:     	mov	x9, #0x1                ; =1
100001b08:     	stlxr	w11, x9, [x14]
100001b0c:     	cbnz	w11, 0x100001ae8 <_silex_function_2+0xfb0>
100001b10:     	ldr	x1, [x10, #0x18]
100001b14:     	mov	x0, x10
100001b18:     	mov	w16, #0x49              ; =73
100001b1c:     	svc	#0x80
100001b20:     	b	0x100001b30 <_silex_function_2+0xff8>
100001b24:     	add	sp, sp, #0x30
100001b28:     	mov	w8, #0x3                ; =3
100001b2c:     	b	0x100003554 <_silex_function_2+0x2a1c>
100001b30:     	ldr	x9, [sp, #0x438]
100001b34:     	str	x9, [sp, #0x11e8]
100001b38:     	ldr	x9, [sp, #0xe00]
100001b3c:     	add	x20, x9, #0x1
100001b40:     	mov	x9, x20
100001b44:     	str	x9, [sp, #0xe00]
100001b48:     	ldr	x9, [sp, #0xe00]
100001b4c:     	ldr	x10, [sp, #0xde0]
100001b50:     	cmp	x9, x10
100001b54:     	b.lt	0x1000016e8 <_silex_function_2+0xbb0>
100001b58:     	ldr	x9, [sp, #0x11e0]
100001b5c:     	str	x9, [sp, #0x450]
100001b60:     	movz	x9, #0x0, lsl #48
100001b64:     	str	x9, [sp, #0x458]
100001b68:     	ldr	x9, [sp, #0x11e0]
100001b6c:     	mov	x19, x9
100001b70:     	mov	x9, x19
100001b74:     	ldr	x10, [x9]
100001b78:     	str	x10, [sp, #0x468]
100001b7c:     	ldr	x10, [sp, #0x450]
100001b80:     	ldr	x13, [x10]
100001b84:     	add	x10, x10, #0x28
100001b88:     	ldr	x9, [sp, #0x458]
100001b8c:     	cmp	x9, xzr
100001b90:     	b.ge	0x100001b98 <_silex_function_2+0x1060>
100001b94:     	add	x9, x9, x13
100001b98:     	cmp	x9, xzr
100001b9c:     	b.ge	0x100001ba4 <_silex_function_2+0x106c>
100001ba0:     	mov	w9, #0x0                ; =0
100001ba4:     	cmp	x9, x13
100001ba8:     	b.le	0x100001bb0 <_silex_function_2+0x1078>
100001bac:     	mov	x9, x13
100001bb0:     	ldr	x8, [sp, #0x468]
100001bb4:     	cmp	x8, xzr
100001bb8:     	b.ge	0x100001bc0 <_silex_function_2+0x1088>
100001bbc:     	add	x8, x8, x13
100001bc0:     	cmp	x8, xzr
100001bc4:     	b.ge	0x100001bcc <_silex_function_2+0x1094>
100001bc8:     	mov	w8, #0x0                ; =0
100001bcc:     	cmp	x8, x13
100001bd0:     	b.le	0x100001bd8 <_silex_function_2+0x10a0>
100001bd4:     	mov	x8, x13
100001bd8:     	mov	w12, #0x0               ; =0
100001bdc:     	cmp	x9, x8
100001be0:     	b.ge	0x100001be8 <_silex_function_2+0x10b0>
100001be4:     	subs	x12, x8, x9
100001be8:     	mov	x11, #0xc0              ; =192
100001bec:     	mul	x9, x9, x11
100001bf0:     	add	x10, x10, x9
100001bf4:     	str	x10, [sp, #0x470]
100001bf8:     	str	x12, [sp, #0x478]
100001bfc:     	ldr	x9, [sp, #0x11e8]
100001c00:     	str	x9, [sp, #0x480]
100001c04:     	mov	x14, #0x11e8            ; =4584
100001c08:     	mov	x9, sp
100001c0c:     	add	x9, x9, x14
100001c10:     	str	x9, [sp, #0x488]
100001c14:     	movz	x9, #0x0, lsl #48
100001c18:     	str	x9, [sp, #0x490]
100001c1c:     	ldr	x9, [sp, #0x11e8]
100001c20:     	mov	x19, x9
100001c24:     	mov	x9, x19
100001c28:     	ldr	x10, [x9]
100001c2c:     	str	x10, [sp, #0x4a0]
100001c30:     	ldr	x10, [sp, #0x488]
100001c34:     	ldr	x14, [x10]
100001c38:     	ldr	x13, [x14]
100001c3c:     	ldr	x11, [x14, #0x8]
100001c40:     	ldr	x5, [x14, #0x10]
100001c44:     	add	x11, x11, x5
100001c48:     	mov	x5, #0x1                ; =1
100001c4c:     	cmp	x11, x5
100001c50:     	b.eq	0x100001df8 <_silex_function_2+0x12c0>
100001c54:     	sub	sp, sp, #0x20
100001c58:     	str	x10, [sp]
100001c5c:     	str	x14, [sp, #0x8]
100001c60:     	str	x13, [sp, #0x10]
100001c64:     	mov	x11, #0xd0              ; =208
100001c68:     	mul	x1, x13, x11
100001c6c:     	add	x1, x1, #0x28
100001c70:     	mov	w0, #0x0                ; =0
100001c74:     	mov	w2, #0x3                ; =3
100001c78:     	mov	w3, #0x1002             ; =4098
100001c7c:     	mov	x4, #0xffff             ; =65535
100001c80:     	movk	x4, #0xffff, lsl #16
100001c84:     	movk	x4, #0xffff, lsl #32
100001c88:     	movk	x4, #0xffff, lsl #48
100001c8c:     	mov	w5, #0x0                ; =0
100001c90:     	mov	w16, #0xc5              ; =197
100001c94:     	svc	#0x80
100001c98:     	b.hs	0x100001dec <_silex_function_2+0x12b4>
100001c9c:     	mov	x15, x0
100001ca0:     	ldr	x10, [sp]
100001ca4:     	ldr	x14, [sp, #0x8]
100001ca8:     	ldr	x13, [sp, #0x10]
100001cac:     	str	x13, [x15]
100001cb0:     	mov	x11, #0x1               ; =1
100001cb4:     	str	x11, [x15, #0x8]
100001cb8:     	mov	x11, #0xd0              ; =208
100001cbc:     	mul	x11, x13, x11
100001cc0:     	add	x11, x11, #0x28
100001cc4:     	str	x11, [x15, #0x18]
100001cc8:     	add	x10, x14, #0x28
100001ccc:     	add	x14, x15, #0x28
100001cd0:     	mov	x11, #0x1a              ; =26
100001cd4:     	mul	x12, x13, x11
100001cd8:     	cbz	x12, 0x100001cf4 <_silex_function_2+0x11bc>
100001cdc:     	ldr	x11, [x10]
100001ce0:     	str	x11, [x14]
100001ce4:     	add	x10, x10, #0x8
100001ce8:     	add	x14, x14, #0x8
100001cec:     	sub	x12, x12, #0x1
100001cf0:     	cbnz	x12, 0x100001cdc <_silex_function_2+0x11a4>
100001cf4:     	ldr	x10, [sp]
100001cf8:     	ldr	x14, [sp, #0x8]
100001cfc:     	ldaxr	x9, [x10]
100001d00:     	cmp	x9, x14
100001d04:     	b.ne	0x100001d7c <_silex_function_2+0x1244>
100001d08:     	stlxr	w11, x15, [x10]
100001d0c:     	cbnz	w11, 0x100001cfc <_silex_function_2+0x11c4>
100001d10:     	ldr	x10, [sp, #0x8]
100001d14:     	add	x14, x10, #0x8
100001d18:     	ldaxr	x9, [x14]
100001d1c:     	cbz	x9, 0x100001d74 <_silex_function_2+0x123c>
100001d20:     	sub	x9, x9, #0x1
100001d24:     	stlxr	w11, x9, [x14]
100001d28:     	cbnz	w11, 0x100001d18 <_silex_function_2+0x11e0>
100001d2c:     	ldr	x11, [x10, #0x10]
100001d30:     	add	x9, x9, x11
100001d34:     	cbnz	x9, 0x100001d74 <_silex_function_2+0x123c>
100001d38:     	add	x14, x10, #0x20
100001d3c:     	ldaxr	x9, [x14]
100001d40:     	mov	x11, #0x2               ; =2
100001d44:     	cmp	x9, x11
100001d48:     	b.eq	0x100001d3c <_silex_function_2+0x1204>
100001d4c:     	mov	x11, #0x1               ; =1
100001d50:     	cmp	x9, x11
100001d54:     	b.eq	0x100001d74 <_silex_function_2+0x123c>
100001d58:     	mov	x9, #0x1                ; =1
100001d5c:     	stlxr	w11, x9, [x14]
100001d60:     	cbnz	w11, 0x100001d3c <_silex_function_2+0x1204>
100001d64:     	ldr	x1, [x10, #0x18]
100001d68:     	mov	x0, x10
100001d6c:     	mov	w16, #0x49              ; =73
100001d70:     	svc	#0x80
100001d74:     	add	sp, sp, #0x20
100001d78:     	b	0x100001df8 <_silex_function_2+0x12c0>
100001d7c:     	clrex
100001d80:     	mov	x10, x15
100001d84:     	add	x14, x10, #0x8
100001d88:     	ldaxr	x9, [x14]
100001d8c:     	cbz	x9, 0x100001de4 <_silex_function_2+0x12ac>
100001d90:     	sub	x9, x9, #0x1
100001d94:     	stlxr	w11, x9, [x14]
100001d98:     	cbnz	w11, 0x100001d88 <_silex_function_2+0x1250>
100001d9c:     	ldr	x11, [x10, #0x10]
100001da0:     	add	x9, x9, x11
100001da4:     	cbnz	x9, 0x100001de4 <_silex_function_2+0x12ac>
100001da8:     	add	x14, x10, #0x20
100001dac:     	ldaxr	x9, [x14]
100001db0:     	mov	x11, #0x2               ; =2
100001db4:     	cmp	x9, x11
100001db8:     	b.eq	0x100001dac <_silex_function_2+0x1274>
100001dbc:     	mov	x11, #0x1               ; =1
100001dc0:     	cmp	x9, x11
100001dc4:     	b.eq	0x100001de4 <_silex_function_2+0x12ac>
100001dc8:     	mov	x9, #0x1                ; =1
100001dcc:     	stlxr	w11, x9, [x14]
100001dd0:     	cbnz	w11, 0x100001dac <_silex_function_2+0x1274>
100001dd4:     	ldr	x1, [x10, #0x18]
100001dd8:     	mov	x0, x10
100001ddc:     	mov	w16, #0x49              ; =73
100001de0:     	svc	#0x80
100001de4:     	add	sp, sp, #0x20
100001de8:     	b	0x100001c30 <_silex_function_2+0x10f8>
100001dec:     	add	sp, sp, #0x20
100001df0:     	mov	w8, #0x3                ; =3
100001df4:     	b	0x100003554 <_silex_function_2+0x2a1c>
100001df8:     	ldr	x10, [sp, #0x488]
100001dfc:     	ldr	x10, [x10]
100001e00:     	ldr	x13, [x10]
100001e04:     	add	x10, x10, #0x28
100001e08:     	ldr	x9, [sp, #0x490]
100001e0c:     	cmp	x9, xzr
100001e10:     	b.ge	0x100001e18 <_silex_function_2+0x12e0>
100001e14:     	add	x9, x9, x13
100001e18:     	cmp	x9, xzr
100001e1c:     	b.ge	0x100001e24 <_silex_function_2+0x12ec>
100001e20:     	mov	w9, #0x0                ; =0
100001e24:     	cmp	x9, x13
100001e28:     	b.le	0x100001e30 <_silex_function_2+0x12f8>
100001e2c:     	mov	x9, x13
100001e30:     	ldr	x8, [sp, #0x4a0]
100001e34:     	cmp	x8, xzr
100001e38:     	b.ge	0x100001e40 <_silex_function_2+0x1308>
100001e3c:     	add	x8, x8, x13
100001e40:     	cmp	x8, xzr
100001e44:     	b.ge	0x100001e4c <_silex_function_2+0x1314>
100001e48:     	mov	w8, #0x0                ; =0
100001e4c:     	cmp	x8, x13
100001e50:     	b.le	0x100001e58 <_silex_function_2+0x1320>
100001e54:     	mov	x8, x13
100001e58:     	mov	w12, #0x0               ; =0
100001e5c:     	cmp	x9, x8
100001e60:     	b.ge	0x100001e68 <_silex_function_2+0x1330>
100001e64:     	subs	x12, x8, x9
100001e68:     	mov	x11, #0xd0              ; =208
100001e6c:     	mul	x9, x9, x11
100001e70:     	add	x10, x10, x9
100001e74:     	str	x10, [sp, #0x4a8]
100001e78:     	str	x12, [sp, #0x4b0]
100001e7c:     	ldr	x9, [sp, #0x4a8]
100001e80:     	str	x9, [sp, #0x11f0]
100001e84:     	ldr	x9, [sp, #0x4b0]
100001e88:     	str	x9, [sp, #0x11f8]
100001e8c:     	movi	d8, #0000000000000000
100001e90:     	movz	x19, #0x0, lsl #48
100001e94:     	mov	w20, #0x0               ; =0
100001e98:     	mov	w21, #0x0               ; =0
100001e9c:     	movi	d16, #0000000000000000
100001ea0:     	movi	d17, #0000000000000000
100001ea4:     	fmov	s18, #1.00000000
100001ea8:     	mov	x9, x19
100001eac:     	str	x9, [sp, #0x4d8]
100001eb0:     	str	d16, [sp, #0x4e0]
100001eb4:     	str	d17, [sp, #0x4e8]
100001eb8:     	str	d18, [sp, #0x4f0]
100001ebc:     	mov	x9, x20
100001ec0:     	str	x9, [sp, #0x4f8]
100001ec4:     	mov	x9, x21
100001ec8:     	str	x9, [sp, #0x500]
100001ecc:     	add	x0, sp, #0x4d8
100001ed0:     	add	x15, sp, #0x508
100001ed4:     	bl	0x100006f30 <_silex_function_12>
100001ed8:     	cbnz	w8, 0x100003554 <_silex_function_2+0x2a1c>
100001edc:     	ldr	x9, [sp, #0x508]
100001ee0:     	mov	x19, x9
100001ee4:     	ldr	x9, [sp, #0x510]
100001ee8:     	mov	x20, x9
100001eec:     	ldr	x9, [sp, #0x518]
100001ef0:     	mov	x21, x9
100001ef4:     	ldr	x9, [sp, #0x520]
100001ef8:     	mov	x22, x9
100001efc:     	ldr	x9, [sp, #0x528]
100001f00:     	mov	x23, x9
100001f04:     	ldr	x9, [sp, #0x530]
100001f08:     	mov	x24, x9
100001f0c:     	mov	x9, x19
100001f10:     	str	x9, [sp, #0xe38]
100001f14:     	mov	x9, x20
100001f18:     	str	x9, [sp, #0xe40]
100001f1c:     	mov	x9, x21
100001f20:     	str	x9, [sp, #0xe48]
100001f24:     	mov	x9, x22
100001f28:     	str	x9, [sp, #0xe50]
100001f2c:     	mov	x9, x23
100001f30:     	str	x9, [sp, #0xe58]
100001f34:     	mov	x9, x24
100001f38:     	str	x9, [sp, #0xe60]
100001f3c:     	movz	x19, #0x0, lsl #48
100001f40:     	mov	x9, x19
100001f44:     	str	x9, [sp, #0xe08]
100001f48:     	str	d8, [sp, #0xe88]
100001f4c:     	ldr	x9, [sp, #0xe08]
100001f50:     	ldr	x10, [sp, #0xde8]
100001f54:     	cmp	x9, x10
100001f58:     	b.ge	0x100001f94 <_silex_function_2+0x145c>
100001f5c:     	ldr	x9, [sp, #0xe08]
100001f60:     	asr	x13, x9, #63
100001f64:     	mov	x12, #0xf               ; =15
100001f68:     	and	x13, x13, x12
100001f6c:     	add	x13, x9, x13
100001f70:     	asr	x13, x13, #4
100001f74:     	mov	x12, #0x10              ; =16
100001f78:     	msub	x20, x13, x12, x9
100001f7c:     	ldr	x10, [sp, #0xde0]
100001f80:     	mul	x23, x20, x10
100001f84:     	movz	x19, #0x0, lsl #48
100001f88:     	mov	x9, x19
100001f8c:     	str	x9, [sp, #0xe10]
100001f90:     	b	0x100001fa8 <_silex_function_2+0x1470>
100001f94:     	mov	w19, #0x0               ; =0
100001f98:     	ldr	x9, [sp, #0xdc0]
100001f9c:     	cmp	x9, x19
100001fa0:     	b.ne	0x100003474 <_silex_function_2+0x293c>
100001fa4:     	b	0x100003174 <_silex_function_2+0x263c>
100001fa8:     	ldr	x9, [sp, #0xe10]
100001fac:     	ldr	x10, [sp, #0xde0]
100001fb0:     	cmp	x9, x10
100001fb4:     	b.ge	0x1000020b4 <_silex_function_2+0x157c>
100001fb8:     	ldr	x9, [sp, #0x11f0]
100001fbc:     	str	x9, [sp, #0x5a8]
100001fc0:     	ldr	x9, [sp, #0x11f8]
100001fc4:     	str	x9, [sp, #0x5b0]
100001fc8:     	ldr	x10, [sp, #0x5a8]
100001fcc:     	ldr	x13, [sp, #0x5b0]
100001fd0:     	ldr	x9, [sp, #0xe10]
100001fd4:     	cmp	x9, xzr
100001fd8:     	b.ge	0x100001fe0 <_silex_function_2+0x14a8>
100001fdc:     	add	x9, x9, x13
100001fe0:     	cmp	x9, xzr
100001fe4:     	b.lt	0x100003614 <_silex_function_2+0x2adc>
100001fe8:     	cmp	x9, x13
100001fec:     	b.ge	0x100003614 <_silex_function_2+0x2adc>
100001ff0:     	mov	x11, #0xd0              ; =208
100001ff4:     	madd	x10, x9, x11, x10
100001ff8:     	str	x10, [sp, #0x6b8]
100001ffc:     	ldr	x10, [sp, #0xe10]
100002000:     	adds	x19, x23, x10
100002004:     	b.vs	0x1000039ac <_silex_function_2+0x2e74>
100002008:     	ldr	x10, [sp, #0x470]
10000200c:     	ldr	x13, [sp, #0x478]
100002010:     	cmp	x19, xzr
100002014:     	b.ge	0x100002038 <_silex_function_2+0x1500>
100002018:     	add	x9, x19, x13
10000201c:     	cmp	x9, xzr
100002020:     	b.lt	0x1000036f8 <_silex_function_2+0x2bc0>
100002024:     	cmp	x9, x13
100002028:     	b.ge	0x1000036f8 <_silex_function_2+0x2bc0>
10000202c:     	mov	x11, #0xc0              ; =192
100002030:     	madd	x20, x9, x11, x10
100002034:     	b	0x100002048 <_silex_function_2+0x1510>
100002038:     	cmp	x19, x13
10000203c:     	b.ge	0x1000037e0 <_silex_function_2+0x2ca8>
100002040:     	mov	x11, #0xc0              ; =192
100002044:     	madd	x20, x19, x11, x10
100002048:     	ldr	x9, [sp, #0xe08]
10000204c:     	tst	x9, #0x1
100002050:     	cset	w22, eq
100002054:     	mov	x0, x20
100002058:     	mov	x1, x22
10000205c:     	ldr	x15, [sp, #0x6b8]
100002060:     	bl	0x1000004f0 <_silex_function_0>
100002064:     	ldr	x9, [sp, #0x11f0]
100002068:     	str	x9, [sp, #0x788]
10000206c:     	ldr	x9, [sp, #0x11f8]
100002070:     	str	x9, [sp, #0x790]
100002074:     	ldr	x9, [sp, #0x788]
100002078:     	str	x9, [sp, #0x798]
10000207c:     	ldr	x9, [sp, #0x790]
100002080:     	str	x9, [sp, #0x7a0]
100002084:     	ldr	x9, [sp, #0x798]
100002088:     	str	x9, [sp, #0x11f0]
10000208c:     	ldr	x9, [sp, #0x7a0]
100002090:     	str	x9, [sp, #0x11f8]
100002094:     	ldr	x9, [sp, #0xe10]
100002098:     	add	x20, x9, #0x1
10000209c:     	mov	x9, x20
1000020a0:     	str	x9, [sp, #0xe10]
1000020a4:     	ldr	x9, [sp, #0xe10]
1000020a8:     	ldr	x10, [sp, #0xde0]
1000020ac:     	cmp	x9, x10
1000020b0:     	b.lt	0x100001fb8 <_silex_function_2+0x1480>
1000020b4:     	movz	x19, #0x0, lsl #48
1000020b8:     	ldr	x9, [sp, #0x11f0]
1000020bc:     	str	x9, [sp, #0xe80]
1000020c0:     	mov	x9, x19
1000020c4:     	str	x9, [sp, #0xe18]
1000020c8:     	ldr	x9, [sp, #0xe88]
1000020cc:     	str	x9, [sp, #0xe90]
1000020d0:     	ldr	x9, [sp, #0xe18]
1000020d4:     	ldr	x10, [sp, #0xde0]
1000020d8:     	cmp	x9, x10
1000020dc:     	b.ge	0x10000210c <_silex_function_2+0x15d4>
1000020e0:     	ldr	x9, [sp, #0x11f0]
1000020e4:     	mov	x19, x9
1000020e8:     	ldr	x9, [sp, #0x11f8]
1000020ec:     	mov	x20, x9
1000020f0:     	ldr	x9, [sp, #0xe18]
1000020f4:     	cmp	x9, x20
1000020f8:     	b.ge	0x1000038c8 <_silex_function_2+0x2d90>
1000020fc:     	ldr	x9, [sp, #0xdc0]
100002100:     	cbz	w9, 0x100002108 <_silex_function_2+0x15d0>
100002104:     	b	0x100002128 <_silex_function_2+0x15f0>
100002108:     	b	0x100002f80 <_silex_function_2+0x2448>
10000210c:     	ldr	x9, [sp, #0xe08]
100002110:     	add	x20, x9, #0x1
100002114:     	mov	x9, x20
100002118:     	str	x9, [sp, #0xe08]
10000211c:     	ldr	x9, [sp, #0xe90]
100002120:     	str	x9, [sp, #0xe88]
100002124:     	b	0x100001f4c <_silex_function_2+0x1414>
100002128:     	ldr	x9, [sp, #0xe80]
10000212c:     	ldr	x10, [x9]
100002130:     	str	x10, [sp, #0xea0]
100002134:     	ldr	x9, [sp, #0xe80]
100002138:     	ldr	x10, [x9, #0x8]
10000213c:     	str	x10, [sp, #0xeb0]
100002140:     	ldr	x9, [sp, #0xe80]
100002144:     	ldr	x10, [x9, #0x10]
100002148:     	str	x10, [sp, #0xec0]
10000214c:     	ldr	x9, [sp, #0xe80]
100002150:     	ldr	x10, [x9, #0x18]
100002154:     	str	x10, [sp, #0xed0]
100002158:     	ldr	x9, [sp, #0xe80]
10000215c:     	ldr	x10, [x9, #0x20]
100002160:     	str	x10, [sp, #0xee0]
100002164:     	ldr	x9, [sp, #0xe80]
100002168:     	ldr	x10, [x9, #0x28]
10000216c:     	str	x10, [sp, #0xef0]
100002170:     	ldr	x9, [sp, #0xe80]
100002174:     	ldr	x10, [x9, #0x30]
100002178:     	str	x10, [sp, #0xf00]
10000217c:     	ldr	x9, [sp, #0xe80]
100002180:     	ldr	x10, [x9, #0x38]
100002184:     	str	x10, [sp, #0xf10]
100002188:     	ldr	x9, [sp, #0xe80]
10000218c:     	ldr	x10, [x9, #0x40]
100002190:     	str	x10, [sp, #0xf20]
100002194:     	ldr	x9, [sp, #0xe80]
100002198:     	ldr	x10, [x9, #0x48]
10000219c:     	str	x10, [sp, #0xf30]
1000021a0:     	ldr	x9, [sp, #0xe80]
1000021a4:     	ldr	x10, [x9, #0x50]
1000021a8:     	str	x10, [sp, #0xf40]
1000021ac:     	ldr	x9, [sp, #0xe80]
1000021b0:     	ldr	x10, [x9, #0x58]
1000021b4:     	str	x10, [sp, #0xf50]
1000021b8:     	ldr	x9, [sp, #0xe80]
1000021bc:     	ldr	x10, [x9, #0x60]
1000021c0:     	str	x10, [sp, #0xf60]
1000021c4:     	ldr	x9, [sp, #0xe80]
1000021c8:     	ldr	x10, [x9, #0x68]
1000021cc:     	str	x10, [sp, #0xf70]
1000021d0:     	ldr	x9, [sp, #0xe80]
1000021d4:     	ldr	x10, [x9, #0x70]
1000021d8:     	str	x10, [sp, #0xf80]
1000021dc:     	ldr	x9, [sp, #0xe80]
1000021e0:     	ldr	x10, [x9, #0x78]
1000021e4:     	str	x10, [sp, #0xf90]
1000021e8:     	ldr	x9, [sp, #0xe80]
1000021ec:     	ldr	x10, [x9, #0x80]
1000021f0:     	str	x10, [sp, #0xfa0]
1000021f4:     	ldr	x9, [sp, #0xe80]
1000021f8:     	ldr	x10, [x9, #0x88]
1000021fc:     	str	x10, [sp, #0xfb0]
100002200:     	ldr	x9, [sp, #0xe80]
100002204:     	ldr	x10, [x9, #0x90]
100002208:     	str	x10, [sp, #0xfc0]
10000220c:     	ldr	x9, [sp, #0xe80]
100002210:     	ldr	x10, [x9, #0x98]
100002214:     	str	x10, [sp, #0xfd0]
100002218:     	ldr	x9, [sp, #0xe80]
10000221c:     	ldr	x10, [x9, #0xa0]
100002220:     	str	x10, [sp, #0xfe0]
100002224:     	ldr	x9, [sp, #0xe80]
100002228:     	ldr	x10, [x9, #0xa8]
10000222c:     	str	x10, [sp, #0xff0]
100002230:     	ldr	x9, [sp, #0xe80]
100002234:     	ldr	x10, [x9, #0xb0]
100002238:     	str	x10, [sp, #0x1000]
10000223c:     	ldr	x9, [sp, #0xe80]
100002240:     	ldr	x10, [x9, #0xb8]
100002244:     	str	x10, [sp, #0x1010]
100002248:     	ldr	x9, [sp, #0xe80]
10000224c:     	ldr	x10, [x9, #0xc0]
100002250:     	str	x10, [sp, #0x1020]
100002254:     	ldr	x9, [sp, #0xe80]
100002258:     	ldr	x10, [x9, #0xc8]
10000225c:     	str	x10, [sp, #0x1030]
100002260:     	adrp	x9, 0x100009000 <_main+0x1b80>
100002264:     	add	x9, x9, #0x470
100002268:     	str	x9, [sp, #0x7d8]
10000226c:     	adrp	x9, 0x100009000 <_main+0x1b80>
100002270:     	add	x9, x9, #0x480
100002274:     	str	x9, [sp, #0x7e0]
100002278:     	adrp	x9, 0x100009000 <_main+0x1b80>
10000227c:     	add	x9, x9, #0x480
100002280:     	str	x9, [sp, #0x7e8]
100002284:     	ldr	x9, [sp, #0xea0]
100002288:     	str	x9, [sp, #0x7f0]
10000228c:     	adrp	x9, 0x100009000 <_main+0x1b80>
100002290:     	add	x9, x9, #0x480
100002294:     	str	x9, [sp, #0x7f8]
100002298:     	ldr	x9, [sp, #0xeb0]
10000229c:     	str	x9, [sp, #0x800]
1000022a0:     	adrp	x9, 0x100009000 <_main+0x1b80>
1000022a4:     	add	x9, x9, #0x480
1000022a8:     	str	x9, [sp, #0x808]
1000022ac:     	ldr	x9, [sp, #0xec0]
1000022b0:     	str	x9, [sp, #0x810]
1000022b4:     	adrp	x9, 0x100009000 <_main+0x1b80>
1000022b8:     	add	x9, x9, #0x480
1000022bc:     	str	x9, [sp, #0x818]
1000022c0:     	ldr	x9, [sp, #0xed0]
1000022c4:     	str	x9, [sp, #0x820]
1000022c8:     	adrp	x9, 0x100009000 <_main+0x1b80>
1000022cc:     	add	x9, x9, #0x480
1000022d0:     	str	x9, [sp, #0x828]
1000022d4:     	ldr	x9, [sp, #0xee0]
1000022d8:     	str	x9, [sp, #0x830]
1000022dc:     	adrp	x9, 0x100009000 <_main+0x1b80>
1000022e0:     	add	x9, x9, #0x480
1000022e4:     	str	x9, [sp, #0x838]
1000022e8:     	ldr	x9, [sp, #0xef0]
1000022ec:     	str	x9, [sp, #0x840]
1000022f0:     	adrp	x9, 0x100009000 <_main+0x1b80>
1000022f4:     	add	x9, x9, #0x480
1000022f8:     	str	x9, [sp, #0x848]
1000022fc:     	ldr	x9, [sp, #0xf00]
100002300:     	str	x9, [sp, #0x850]
100002304:     	adrp	x9, 0x100009000 <_main+0x1b80>
100002308:     	add	x9, x9, #0x480
10000230c:     	str	x9, [sp, #0x858]
100002310:     	ldr	x9, [sp, #0xf10]
100002314:     	str	x9, [sp, #0x860]
100002318:     	adrp	x9, 0x100009000 <_main+0x1b80>
10000231c:     	add	x9, x9, #0x480
100002320:     	str	x9, [sp, #0x868]
100002324:     	ldr	x9, [sp, #0xf20]
100002328:     	str	x9, [sp, #0x870]
10000232c:     	adrp	x9, 0x100009000 <_main+0x1b80>
100002330:     	add	x9, x9, #0x480
100002334:     	str	x9, [sp, #0x878]
100002338:     	ldr	x9, [sp, #0xf30]
10000233c:     	str	x9, [sp, #0x880]
100002340:     	adrp	x9, 0x100009000 <_main+0x1b80>
100002344:     	add	x9, x9, #0x480
100002348:     	str	x9, [sp, #0x888]
10000234c:     	ldr	x9, [sp, #0xf40]
100002350:     	str	x9, [sp, #0x890]
100002354:     	adrp	x9, 0x100009000 <_main+0x1b80>
100002358:     	add	x9, x9, #0x480
10000235c:     	str	x9, [sp, #0x898]
100002360:     	ldr	x9, [sp, #0xf50]
100002364:     	str	x9, [sp, #0x8a0]
100002368:     	adrp	x9, 0x100009000 <_main+0x1b80>
10000236c:     	add	x9, x9, #0x480
100002370:     	str	x9, [sp, #0x8a8]
100002374:     	ldr	x9, [sp, #0xf60]
100002378:     	str	x9, [sp, #0x8b0]
10000237c:     	adrp	x9, 0x100009000 <_main+0x1b80>
100002380:     	add	x9, x9, #0x480
100002384:     	str	x9, [sp, #0x8b8]
100002388:     	ldr	x9, [sp, #0xf70]
10000238c:     	str	x9, [sp, #0x8c0]
100002390:     	adrp	x9, 0x100009000 <_main+0x1b80>
100002394:     	add	x9, x9, #0x480
100002398:     	str	x9, [sp, #0x8c8]
10000239c:     	ldr	x9, [sp, #0xf80]
1000023a0:     	str	x9, [sp, #0x8d0]
1000023a4:     	adrp	x9, 0x100009000 <_main+0x1b80>
1000023a8:     	add	x9, x9, #0x480
1000023ac:     	str	x9, [sp, #0x8d8]
1000023b0:     	ldr	x9, [sp, #0xf90]
1000023b4:     	str	x9, [sp, #0x8e0]
1000023b8:     	adrp	x9, 0x100009000 <_main+0x1b80>
1000023bc:     	add	x9, x9, #0x480
1000023c0:     	str	x9, [sp, #0x8e8]
1000023c4:     	ldr	x9, [sp, #0xfa0]
1000023c8:     	str	x9, [sp, #0x8f0]
1000023cc:     	adrp	x9, 0x100009000 <_main+0x1b80>
1000023d0:     	add	x9, x9, #0x480
1000023d4:     	str	x9, [sp, #0x8f8]
1000023d8:     	ldr	x9, [sp, #0xfb0]
1000023dc:     	str	x9, [sp, #0x900]
1000023e0:     	adrp	x9, 0x100009000 <_main+0x1b80>
1000023e4:     	add	x9, x9, #0x480
1000023e8:     	str	x9, [sp, #0x908]
1000023ec:     	ldr	x9, [sp, #0xfc0]
1000023f0:     	str	x9, [sp, #0x910]
1000023f4:     	adrp	x9, 0x100009000 <_main+0x1b80>
1000023f8:     	add	x9, x9, #0x480
1000023fc:     	str	x9, [sp, #0x918]
100002400:     	ldr	x9, [sp, #0xfd0]
100002404:     	str	x9, [sp, #0x920]
100002408:     	adrp	x9, 0x100009000 <_main+0x1b80>
10000240c:     	add	x9, x9, #0x480
100002410:     	str	x9, [sp, #0x928]
100002414:     	ldr	x9, [sp, #0xfe0]
100002418:     	str	x9, [sp, #0x930]
10000241c:     	adrp	x9, 0x100009000 <_main+0x1b80>
100002420:     	add	x9, x9, #0x480
100002424:     	str	x9, [sp, #0x938]
100002428:     	ldr	x9, [sp, #0xff0]
10000242c:     	str	x9, [sp, #0x940]
100002430:     	adrp	x9, 0x100009000 <_main+0x1b80>
100002434:     	add	x9, x9, #0x480
100002438:     	str	x9, [sp, #0x948]
10000243c:     	ldr	x9, [sp, #0x1000]
100002440:     	str	x9, [sp, #0x950]
100002444:     	adrp	x9, 0x100009000 <_main+0x1b80>
100002448:     	add	x9, x9, #0x480
10000244c:     	str	x9, [sp, #0x958]
100002450:     	ldr	x9, [sp, #0x1010]
100002454:     	str	x9, [sp, #0x960]
100002458:     	adrp	x9, 0x100009000 <_main+0x1b80>
10000245c:     	add	x9, x9, #0x480
100002460:     	str	x9, [sp, #0x968]
100002464:     	ldr	x9, [sp, #0x1020]
100002468:     	str	x9, [sp, #0x970]
10000246c:     	adrp	x9, 0x100009000 <_main+0x1b80>
100002470:     	add	x9, x9, #0x480
100002474:     	str	x9, [sp, #0x978]
100002478:     	ldr	x9, [sp, #0x1030]
10000247c:     	str	x9, [sp, #0x980]
100002480:     	ldr	x9, [sp, #0x7d8]
100002484:     	ldr	x2, [x9]
100002488:     	mov	x10, #0xffff            ; =65535
10000248c:     	movk	x10, #0xffff, lsl #16
100002490:     	movk	x10, #0xffff, lsl #32
100002494:     	movk	x10, #0x7fff, lsl #48
100002498:     	and	x2, x2, x10
10000249c:     	add	x1, x9, #0x8
1000024a0:     	mov	w0, #0x1                ; =1
1000024a4:     	mov	w16, #0x4               ; =4
1000024a8:     	svc	#0x80
1000024ac:     	ldr	x9, [sp, #0xe08]
1000024b0:     	sub	sp, sp, #0x20
1000024b4:     	add	x11, sp, #0x20
1000024b8:     	mov	w12, #0x0               ; =0
1000024bc:     	cbnz	x9, 0x1000024d4 <_silex_function_2+0x199c>
1000024c0:     	sub	x11, x11, #0x1
1000024c4:     	mov	w10, #0x30              ; =48
1000024c8:     	strb	w10, [x11]
1000024cc:     	add	x12, x12, #0x1
1000024d0:     	b	0x100002528 <_silex_function_2+0x19f0>
1000024d4:     	mov	w3, #0x0                ; =0
1000024d8:     	cmp	x9, xzr
1000024dc:     	b.lt	0x1000024e8 <_silex_function_2+0x19b0>
1000024e0:     	negs	x9, x9
1000024e4:     	b	0x1000024ec <_silex_function_2+0x19b4>
1000024e8:     	mov	w3, #0x1                ; =1
1000024ec:     	mov	w10, #0xa               ; =10
1000024f0:     	sdiv	x4, x9, x10
1000024f4:     	msub	x5, x4, x10, x9
1000024f8:     	mov	w6, #0x30               ; =48
1000024fc:     	subs	x6, x6, x5
100002500:     	sub	x11, x11, #0x1
100002504:     	strb	w6, [x11]
100002508:     	add	x12, x12, #0x1
10000250c:     	mov	x9, x4
100002510:     	cbnz	x9, 0x1000024ec <_silex_function_2+0x19b4>
100002514:     	cbz	w3, 0x100002528 <_silex_function_2+0x19f0>
100002518:     	sub	x11, x11, #0x1
10000251c:     	mov	w10, #0x2d              ; =45
100002520:     	strb	w10, [x11]
100002524:     	add	x12, x12, #0x1
100002528:     	mov	w0, #0x1                ; =1
10000252c:     	mov	x1, x11
100002530:     	mov	x2, x12
100002534:     	mov	w16, #0x4               ; =4
100002538:     	svc	#0x80
10000253c:     	add	sp, sp, #0x20
100002540:     	ldr	x9, [sp, #0x7e0]
100002544:     	ldr	x2, [x9]
100002548:     	mov	x10, #0xffff            ; =65535
10000254c:     	movk	x10, #0xffff, lsl #16
100002550:     	movk	x10, #0xffff, lsl #32
100002554:     	movk	x10, #0x7fff, lsl #48
100002558:     	and	x2, x2, x10
10000255c:     	add	x1, x9, #0x8
100002560:     	mov	w0, #0x1                ; =1
100002564:     	mov	w16, #0x4               ; =4
100002568:     	svc	#0x80
10000256c:     	ldr	x9, [sp, #0xe18]
100002570:     	sub	sp, sp, #0x20
100002574:     	add	x11, sp, #0x20
100002578:     	mov	w12, #0x0               ; =0
10000257c:     	cbnz	x9, 0x100002594 <_silex_function_2+0x1a5c>
100002580:     	sub	x11, x11, #0x1
100002584:     	mov	w10, #0x30              ; =48
100002588:     	strb	w10, [x11]
10000258c:     	add	x12, x12, #0x1
100002590:     	b	0x1000025e8 <_silex_function_2+0x1ab0>
100002594:     	mov	w3, #0x0                ; =0
100002598:     	cmp	x9, xzr
10000259c:     	b.lt	0x1000025a8 <_silex_function_2+0x1a70>
1000025a0:     	negs	x9, x9
1000025a4:     	b	0x1000025ac <_silex_function_2+0x1a74>
1000025a8:     	mov	w3, #0x1                ; =1
1000025ac:     	mov	w10, #0xa               ; =10
1000025b0:     	sdiv	x4, x9, x10
1000025b4:     	msub	x5, x4, x10, x9
1000025b8:     	mov	w6, #0x30               ; =48
1000025bc:     	subs	x6, x6, x5
1000025c0:     	sub	x11, x11, #0x1
1000025c4:     	strb	w6, [x11]
1000025c8:     	add	x12, x12, #0x1
1000025cc:     	mov	x9, x4
1000025d0:     	cbnz	x9, 0x1000025ac <_silex_function_2+0x1a74>
1000025d4:     	cbz	w3, 0x1000025e8 <_silex_function_2+0x1ab0>
1000025d8:     	sub	x11, x11, #0x1
1000025dc:     	mov	w10, #0x2d              ; =45
1000025e0:     	strb	w10, [x11]
1000025e4:     	add	x12, x12, #0x1
1000025e8:     	mov	w0, #0x1                ; =1
1000025ec:     	mov	x1, x11
1000025f0:     	mov	x2, x12
1000025f4:     	mov	w16, #0x4               ; =4
1000025f8:     	svc	#0x80
1000025fc:     	add	sp, sp, #0x20
100002600:     	ldr	x9, [sp, #0x7e8]
100002604:     	ldr	x2, [x9]
100002608:     	mov	x10, #0xffff            ; =65535
10000260c:     	movk	x10, #0xffff, lsl #16
100002610:     	movk	x10, #0xffff, lsl #32
100002614:     	movk	x10, #0x7fff, lsl #48
100002618:     	and	x2, x2, x10
10000261c:     	add	x1, x9, #0x8
100002620:     	mov	w0, #0x1                ; =1
100002624:     	mov	w16, #0x4               ; =4
100002628:     	svc	#0x80
10000262c:     	ldr	x0, [sp, #0x7f0]
100002630:     	sub	sp, sp, #0x160
100002634:     	mov	x1, sp
100002638:     	mov	w2, #0x0                ; =0
10000263c:     	bl	0x100007a48 <_main+0x5c8>
100002640:     	mov	w8, #0x0                ; =0
100002644:     	mov	x2, x0
100002648:     	mov	w0, #0x1                ; =1
10000264c:     	mov	x1, sp
100002650:     	mov	w16, #0x4               ; =4
100002654:     	svc	#0x80
100002658:     	add	sp, sp, #0x160
10000265c:     	ldr	x9, [sp, #0x7f8]
100002660:     	ldr	x2, [x9]
100002664:     	mov	x10, #0xffff            ; =65535
100002668:     	movk	x10, #0xffff, lsl #16
10000266c:     	movk	x10, #0xffff, lsl #32
100002670:     	movk	x10, #0x7fff, lsl #48
100002674:     	and	x2, x2, x10
100002678:     	add	x1, x9, #0x8
10000267c:     	mov	w0, #0x1                ; =1
100002680:     	mov	w16, #0x4               ; =4
100002684:     	svc	#0x80
100002688:     	ldr	x0, [sp, #0x800]
10000268c:     	sub	sp, sp, #0x160
100002690:     	mov	x1, sp
100002694:     	mov	w2, #0x0                ; =0
100002698:     	bl	0x100007a48 <_main+0x5c8>
10000269c:     	mov	w8, #0x0                ; =0
1000026a0:     	mov	x2, x0
1000026a4:     	mov	w0, #0x1                ; =1
1000026a8:     	mov	x1, sp
1000026ac:     	mov	w16, #0x4               ; =4
1000026b0:     	svc	#0x80
1000026b4:     	add	sp, sp, #0x160
1000026b8:     	ldr	x9, [sp, #0x808]
1000026bc:     	ldr	x2, [x9]
1000026c0:     	mov	x10, #0xffff            ; =65535
1000026c4:     	movk	x10, #0xffff, lsl #16
1000026c8:     	movk	x10, #0xffff, lsl #32
1000026cc:     	movk	x10, #0x7fff, lsl #48
1000026d0:     	and	x2, x2, x10
1000026d4:     	add	x1, x9, #0x8
1000026d8:     	mov	w0, #0x1                ; =1
1000026dc:     	mov	w16, #0x4               ; =4
1000026e0:     	svc	#0x80
1000026e4:     	ldr	x0, [sp, #0x810]
1000026e8:     	sub	sp, sp, #0x160
1000026ec:     	mov	x1, sp
1000026f0:     	mov	w2, #0x0                ; =0
1000026f4:     	bl	0x100007a48 <_main+0x5c8>
1000026f8:     	mov	w8, #0x0                ; =0
1000026fc:     	mov	x2, x0
100002700:     	mov	w0, #0x1                ; =1
100002704:     	mov	x1, sp
100002708:     	mov	w16, #0x4               ; =4
10000270c:     	svc	#0x80
100002710:     	add	sp, sp, #0x160
100002714:     	ldr	x9, [sp, #0x818]
100002718:     	ldr	x2, [x9]
10000271c:     	mov	x10, #0xffff            ; =65535
100002720:     	movk	x10, #0xffff, lsl #16
100002724:     	movk	x10, #0xffff, lsl #32
100002728:     	movk	x10, #0x7fff, lsl #48
10000272c:     	and	x2, x2, x10
100002730:     	add	x1, x9, #0x8
100002734:     	mov	w0, #0x1                ; =1
100002738:     	mov	w16, #0x4               ; =4
10000273c:     	svc	#0x80
100002740:     	ldr	x0, [sp, #0x820]
100002744:     	sub	sp, sp, #0x160
100002748:     	mov	x1, sp
10000274c:     	mov	w2, #0x0                ; =0
100002750:     	bl	0x100007a48 <_main+0x5c8>
100002754:     	mov	w8, #0x0                ; =0
100002758:     	mov	x2, x0
10000275c:     	mov	w0, #0x1                ; =1
100002760:     	mov	x1, sp
100002764:     	mov	w16, #0x4               ; =4
100002768:     	svc	#0x80
10000276c:     	add	sp, sp, #0x160
100002770:     	ldr	x9, [sp, #0x828]
100002774:     	ldr	x2, [x9]
100002778:     	mov	x10, #0xffff            ; =65535
10000277c:     	movk	x10, #0xffff, lsl #16
100002780:     	movk	x10, #0xffff, lsl #32
100002784:     	movk	x10, #0x7fff, lsl #48
100002788:     	and	x2, x2, x10
10000278c:     	add	x1, x9, #0x8
100002790:     	mov	w0, #0x1                ; =1
100002794:     	mov	w16, #0x4               ; =4
100002798:     	svc	#0x80
10000279c:     	ldr	x0, [sp, #0x830]
1000027a0:     	sub	sp, sp, #0x160
1000027a4:     	mov	x1, sp
1000027a8:     	mov	w2, #0x0                ; =0
1000027ac:     	bl	0x100007a48 <_main+0x5c8>
1000027b0:     	mov	w8, #0x0                ; =0
1000027b4:     	mov	x2, x0
1000027b8:     	mov	w0, #0x1                ; =1
1000027bc:     	mov	x1, sp
1000027c0:     	mov	w16, #0x4               ; =4
1000027c4:     	svc	#0x80
1000027c8:     	add	sp, sp, #0x160
1000027cc:     	ldr	x9, [sp, #0x838]
1000027d0:     	ldr	x2, [x9]
1000027d4:     	mov	x10, #0xffff            ; =65535
1000027d8:     	movk	x10, #0xffff, lsl #16
1000027dc:     	movk	x10, #0xffff, lsl #32
1000027e0:     	movk	x10, #0x7fff, lsl #48
1000027e4:     	and	x2, x2, x10
1000027e8:     	add	x1, x9, #0x8
1000027ec:     	mov	w0, #0x1                ; =1
1000027f0:     	mov	w16, #0x4               ; =4
1000027f4:     	svc	#0x80
1000027f8:     	ldr	x0, [sp, #0x840]
1000027fc:     	sub	sp, sp, #0x160
100002800:     	mov	x1, sp
100002804:     	mov	w2, #0x0                ; =0
100002808:     	bl	0x100007a48 <_main+0x5c8>
10000280c:     	mov	w8, #0x0                ; =0
100002810:     	mov	x2, x0
100002814:     	mov	w0, #0x1                ; =1
100002818:     	mov	x1, sp
10000281c:     	mov	w16, #0x4               ; =4
100002820:     	svc	#0x80
100002824:     	add	sp, sp, #0x160
100002828:     	ldr	x9, [sp, #0x848]
10000282c:     	ldr	x2, [x9]
100002830:     	mov	x10, #0xffff            ; =65535
100002834:     	movk	x10, #0xffff, lsl #16
100002838:     	movk	x10, #0xffff, lsl #32
10000283c:     	movk	x10, #0x7fff, lsl #48
100002840:     	and	x2, x2, x10
100002844:     	add	x1, x9, #0x8
100002848:     	mov	w0, #0x1                ; =1
10000284c:     	mov	w16, #0x4               ; =4
100002850:     	svc	#0x80
100002854:     	ldr	x0, [sp, #0x850]
100002858:     	sub	sp, sp, #0x160
10000285c:     	mov	x1, sp
100002860:     	mov	w2, #0x0                ; =0
100002864:     	bl	0x100007a48 <_main+0x5c8>
100002868:     	mov	w8, #0x0                ; =0
10000286c:     	mov	x2, x0
100002870:     	mov	w0, #0x1                ; =1
100002874:     	mov	x1, sp
100002878:     	mov	w16, #0x4               ; =4
10000287c:     	svc	#0x80
100002880:     	add	sp, sp, #0x160
100002884:     	ldr	x9, [sp, #0x858]
100002888:     	ldr	x2, [x9]
10000288c:     	mov	x10, #0xffff            ; =65535
100002890:     	movk	x10, #0xffff, lsl #16
100002894:     	movk	x10, #0xffff, lsl #32
100002898:     	movk	x10, #0x7fff, lsl #48
10000289c:     	and	x2, x2, x10
1000028a0:     	add	x1, x9, #0x8
1000028a4:     	mov	w0, #0x1                ; =1
1000028a8:     	mov	w16, #0x4               ; =4
1000028ac:     	svc	#0x80
1000028b0:     	ldr	x0, [sp, #0x860]
1000028b4:     	sub	sp, sp, #0x160
1000028b8:     	mov	x1, sp
1000028bc:     	mov	w2, #0x0                ; =0
1000028c0:     	bl	0x100007a48 <_main+0x5c8>
1000028c4:     	mov	w8, #0x0                ; =0
1000028c8:     	mov	x2, x0
1000028cc:     	mov	w0, #0x1                ; =1
1000028d0:     	mov	x1, sp
1000028d4:     	mov	w16, #0x4               ; =4
1000028d8:     	svc	#0x80
1000028dc:     	add	sp, sp, #0x160
1000028e0:     	ldr	x9, [sp, #0x868]
1000028e4:     	ldr	x2, [x9]
1000028e8:     	mov	x10, #0xffff            ; =65535
1000028ec:     	movk	x10, #0xffff, lsl #16
1000028f0:     	movk	x10, #0xffff, lsl #32
1000028f4:     	movk	x10, #0x7fff, lsl #48
1000028f8:     	and	x2, x2, x10
1000028fc:     	add	x1, x9, #0x8
100002900:     	mov	w0, #0x1                ; =1
100002904:     	mov	w16, #0x4               ; =4
100002908:     	svc	#0x80
10000290c:     	ldr	x0, [sp, #0x870]
100002910:     	sub	sp, sp, #0x160
100002914:     	mov	x1, sp
100002918:     	mov	w2, #0x0                ; =0
10000291c:     	bl	0x100007a48 <_main+0x5c8>
100002920:     	mov	w8, #0x0                ; =0
100002924:     	mov	x2, x0
100002928:     	mov	w0, #0x1                ; =1
10000292c:     	mov	x1, sp
100002930:     	mov	w16, #0x4               ; =4
100002934:     	svc	#0x80
100002938:     	add	sp, sp, #0x160
10000293c:     	ldr	x9, [sp, #0x878]
100002940:     	ldr	x2, [x9]
100002944:     	mov	x10, #0xffff            ; =65535
100002948:     	movk	x10, #0xffff, lsl #16
10000294c:     	movk	x10, #0xffff, lsl #32
100002950:     	movk	x10, #0x7fff, lsl #48
100002954:     	and	x2, x2, x10
100002958:     	add	x1, x9, #0x8
10000295c:     	mov	w0, #0x1                ; =1
100002960:     	mov	w16, #0x4               ; =4
100002964:     	svc	#0x80
100002968:     	ldr	x0, [sp, #0x880]
10000296c:     	sub	sp, sp, #0x160
100002970:     	mov	x1, sp
100002974:     	mov	w2, #0x0                ; =0
100002978:     	bl	0x100007a48 <_main+0x5c8>
10000297c:     	mov	w8, #0x0                ; =0
100002980:     	mov	x2, x0
100002984:     	mov	w0, #0x1                ; =1
100002988:     	mov	x1, sp
10000298c:     	mov	w16, #0x4               ; =4
100002990:     	svc	#0x80
100002994:     	add	sp, sp, #0x160
100002998:     	ldr	x9, [sp, #0x888]
10000299c:     	ldr	x2, [x9]
1000029a0:     	mov	x10, #0xffff            ; =65535
1000029a4:     	movk	x10, #0xffff, lsl #16
1000029a8:     	movk	x10, #0xffff, lsl #32
1000029ac:     	movk	x10, #0x7fff, lsl #48
1000029b0:     	and	x2, x2, x10
1000029b4:     	add	x1, x9, #0x8
1000029b8:     	mov	w0, #0x1                ; =1
1000029bc:     	mov	w16, #0x4               ; =4
1000029c0:     	svc	#0x80
1000029c4:     	ldr	x0, [sp, #0x890]
1000029c8:     	sub	sp, sp, #0x160
1000029cc:     	mov	x1, sp
1000029d0:     	mov	w2, #0x0                ; =0
1000029d4:     	bl	0x100007a48 <_main+0x5c8>
1000029d8:     	mov	w8, #0x0                ; =0
1000029dc:     	mov	x2, x0
1000029e0:     	mov	w0, #0x1                ; =1
1000029e4:     	mov	x1, sp
1000029e8:     	mov	w16, #0x4               ; =4
1000029ec:     	svc	#0x80
1000029f0:     	add	sp, sp, #0x160
1000029f4:     	ldr	x9, [sp, #0x898]
1000029f8:     	ldr	x2, [x9]
1000029fc:     	mov	x10, #0xffff            ; =65535
100002a00:     	movk	x10, #0xffff, lsl #16
100002a04:     	movk	x10, #0xffff, lsl #32
100002a08:     	movk	x10, #0x7fff, lsl #48
100002a0c:     	and	x2, x2, x10
100002a10:     	add	x1, x9, #0x8
100002a14:     	mov	w0, #0x1                ; =1
100002a18:     	mov	w16, #0x4               ; =4
100002a1c:     	svc	#0x80
100002a20:     	ldr	x0, [sp, #0x8a0]
100002a24:     	sub	sp, sp, #0x160
100002a28:     	mov	x1, sp
100002a2c:     	mov	w2, #0x0                ; =0
100002a30:     	bl	0x100007a48 <_main+0x5c8>
100002a34:     	mov	w8, #0x0                ; =0
100002a38:     	mov	x2, x0
100002a3c:     	mov	w0, #0x1                ; =1
100002a40:     	mov	x1, sp
100002a44:     	mov	w16, #0x4               ; =4
100002a48:     	svc	#0x80
100002a4c:     	add	sp, sp, #0x160
100002a50:     	ldr	x9, [sp, #0x8a8]
100002a54:     	ldr	x2, [x9]
100002a58:     	mov	x10, #0xffff            ; =65535
100002a5c:     	movk	x10, #0xffff, lsl #16
100002a60:     	movk	x10, #0xffff, lsl #32
100002a64:     	movk	x10, #0x7fff, lsl #48
100002a68:     	and	x2, x2, x10
100002a6c:     	add	x1, x9, #0x8
100002a70:     	mov	w0, #0x1                ; =1
100002a74:     	mov	w16, #0x4               ; =4
100002a78:     	svc	#0x80
100002a7c:     	ldr	x0, [sp, #0x8b0]
100002a80:     	sub	sp, sp, #0x160
100002a84:     	mov	x1, sp
100002a88:     	mov	w2, #0x0                ; =0
100002a8c:     	bl	0x100007a48 <_main+0x5c8>
100002a90:     	mov	w8, #0x0                ; =0
100002a94:     	mov	x2, x0
100002a98:     	mov	w0, #0x1                ; =1
100002a9c:     	mov	x1, sp
100002aa0:     	mov	w16, #0x4               ; =4
100002aa4:     	svc	#0x80
100002aa8:     	add	sp, sp, #0x160
100002aac:     	ldr	x9, [sp, #0x8b8]
100002ab0:     	ldr	x2, [x9]
100002ab4:     	mov	x10, #0xffff            ; =65535
100002ab8:     	movk	x10, #0xffff, lsl #16
100002abc:     	movk	x10, #0xffff, lsl #32
100002ac0:     	movk	x10, #0x7fff, lsl #48
100002ac4:     	and	x2, x2, x10
100002ac8:     	add	x1, x9, #0x8
100002acc:     	mov	w0, #0x1                ; =1
100002ad0:     	mov	w16, #0x4               ; =4
100002ad4:     	svc	#0x80
100002ad8:     	ldr	x0, [sp, #0x8c0]
100002adc:     	sub	sp, sp, #0x160
100002ae0:     	mov	x1, sp
100002ae4:     	mov	w2, #0x0                ; =0
100002ae8:     	bl	0x100007a48 <_main+0x5c8>
100002aec:     	mov	w8, #0x0                ; =0
100002af0:     	mov	x2, x0
100002af4:     	mov	w0, #0x1                ; =1
100002af8:     	mov	x1, sp
100002afc:     	mov	w16, #0x4               ; =4
100002b00:     	svc	#0x80
100002b04:     	add	sp, sp, #0x160
100002b08:     	ldr	x9, [sp, #0x8c8]
100002b0c:     	ldr	x2, [x9]
100002b10:     	mov	x10, #0xffff            ; =65535
100002b14:     	movk	x10, #0xffff, lsl #16
100002b18:     	movk	x10, #0xffff, lsl #32
100002b1c:     	movk	x10, #0x7fff, lsl #48
100002b20:     	and	x2, x2, x10
100002b24:     	add	x1, x9, #0x8
100002b28:     	mov	w0, #0x1                ; =1
100002b2c:     	mov	w16, #0x4               ; =4
100002b30:     	svc	#0x80
100002b34:     	ldr	x0, [sp, #0x8d0]
100002b38:     	sub	sp, sp, #0x160
100002b3c:     	mov	x1, sp
100002b40:     	mov	w2, #0x0                ; =0
100002b44:     	bl	0x100007a48 <_main+0x5c8>
100002b48:     	mov	w8, #0x0                ; =0
100002b4c:     	mov	x2, x0
100002b50:     	mov	w0, #0x1                ; =1
100002b54:     	mov	x1, sp
100002b58:     	mov	w16, #0x4               ; =4
100002b5c:     	svc	#0x80
100002b60:     	add	sp, sp, #0x160
100002b64:     	ldr	x9, [sp, #0x8d8]
100002b68:     	ldr	x2, [x9]
100002b6c:     	mov	x10, #0xffff            ; =65535
100002b70:     	movk	x10, #0xffff, lsl #16
100002b74:     	movk	x10, #0xffff, lsl #32
100002b78:     	movk	x10, #0x7fff, lsl #48
100002b7c:     	and	x2, x2, x10
100002b80:     	add	x1, x9, #0x8
100002b84:     	mov	w0, #0x1                ; =1
100002b88:     	mov	w16, #0x4               ; =4
100002b8c:     	svc	#0x80
100002b90:     	ldr	x0, [sp, #0x8e0]
100002b94:     	sub	sp, sp, #0x160
100002b98:     	mov	x1, sp
100002b9c:     	mov	w2, #0x0                ; =0
100002ba0:     	bl	0x100007a48 <_main+0x5c8>
100002ba4:     	mov	w8, #0x0                ; =0
100002ba8:     	mov	x2, x0
100002bac:     	mov	w0, #0x1                ; =1
100002bb0:     	mov	x1, sp
100002bb4:     	mov	w16, #0x4               ; =4
100002bb8:     	svc	#0x80
100002bbc:     	add	sp, sp, #0x160
100002bc0:     	ldr	x9, [sp, #0x8e8]
100002bc4:     	ldr	x2, [x9]
100002bc8:     	mov	x10, #0xffff            ; =65535
100002bcc:     	movk	x10, #0xffff, lsl #16
100002bd0:     	movk	x10, #0xffff, lsl #32
100002bd4:     	movk	x10, #0x7fff, lsl #48
100002bd8:     	and	x2, x2, x10
100002bdc:     	add	x1, x9, #0x8
100002be0:     	mov	w0, #0x1                ; =1
100002be4:     	mov	w16, #0x4               ; =4
100002be8:     	svc	#0x80
100002bec:     	ldr	x0, [sp, #0x8f0]
100002bf0:     	sub	sp, sp, #0x160
100002bf4:     	mov	x1, sp
100002bf8:     	mov	w2, #0x0                ; =0
100002bfc:     	bl	0x100007a48 <_main+0x5c8>
100002c00:     	mov	w8, #0x0                ; =0
100002c04:     	mov	x2, x0
100002c08:     	mov	w0, #0x1                ; =1
100002c0c:     	mov	x1, sp
100002c10:     	mov	w16, #0x4               ; =4
100002c14:     	svc	#0x80
100002c18:     	add	sp, sp, #0x160
100002c1c:     	ldr	x9, [sp, #0x8f8]
100002c20:     	ldr	x2, [x9]
100002c24:     	mov	x10, #0xffff            ; =65535
100002c28:     	movk	x10, #0xffff, lsl #16
100002c2c:     	movk	x10, #0xffff, lsl #32
100002c30:     	movk	x10, #0x7fff, lsl #48
100002c34:     	and	x2, x2, x10
100002c38:     	add	x1, x9, #0x8
100002c3c:     	mov	w0, #0x1                ; =1
100002c40:     	mov	w16, #0x4               ; =4
100002c44:     	svc	#0x80
100002c48:     	ldr	x0, [sp, #0x900]
100002c4c:     	sub	sp, sp, #0x160
100002c50:     	mov	x1, sp
100002c54:     	mov	w2, #0x0                ; =0
100002c58:     	bl	0x100007a48 <_main+0x5c8>
100002c5c:     	mov	w8, #0x0                ; =0
100002c60:     	mov	x2, x0
100002c64:     	mov	w0, #0x1                ; =1
100002c68:     	mov	x1, sp
100002c6c:     	mov	w16, #0x4               ; =4
100002c70:     	svc	#0x80
100002c74:     	add	sp, sp, #0x160
100002c78:     	ldr	x9, [sp, #0x908]
100002c7c:     	ldr	x2, [x9]
100002c80:     	mov	x10, #0xffff            ; =65535
100002c84:     	movk	x10, #0xffff, lsl #16
100002c88:     	movk	x10, #0xffff, lsl #32
100002c8c:     	movk	x10, #0x7fff, lsl #48
100002c90:     	and	x2, x2, x10
100002c94:     	add	x1, x9, #0x8
100002c98:     	mov	w0, #0x1                ; =1
100002c9c:     	mov	w16, #0x4               ; =4
100002ca0:     	svc	#0x80
100002ca4:     	ldr	x0, [sp, #0x910]
100002ca8:     	sub	sp, sp, #0x160
100002cac:     	mov	x1, sp
100002cb0:     	mov	w2, #0x0                ; =0
100002cb4:     	bl	0x100007a48 <_main+0x5c8>
100002cb8:     	mov	w8, #0x0                ; =0
100002cbc:     	mov	x2, x0
100002cc0:     	mov	w0, #0x1                ; =1
100002cc4:     	mov	x1, sp
100002cc8:     	mov	w16, #0x4               ; =4
100002ccc:     	svc	#0x80
100002cd0:     	add	sp, sp, #0x160
100002cd4:     	ldr	x9, [sp, #0x918]
100002cd8:     	ldr	x2, [x9]
100002cdc:     	mov	x10, #0xffff            ; =65535
100002ce0:     	movk	x10, #0xffff, lsl #16
100002ce4:     	movk	x10, #0xffff, lsl #32
100002ce8:     	movk	x10, #0x7fff, lsl #48
100002cec:     	and	x2, x2, x10
100002cf0:     	add	x1, x9, #0x8
100002cf4:     	mov	w0, #0x1                ; =1
100002cf8:     	mov	w16, #0x4               ; =4
100002cfc:     	svc	#0x80
100002d00:     	ldr	x0, [sp, #0x920]
100002d04:     	sub	sp, sp, #0x160
100002d08:     	mov	x1, sp
100002d0c:     	mov	w2, #0x0                ; =0
100002d10:     	bl	0x100007a48 <_main+0x5c8>
100002d14:     	mov	w8, #0x0                ; =0
100002d18:     	mov	x2, x0
100002d1c:     	mov	w0, #0x1                ; =1
100002d20:     	mov	x1, sp
100002d24:     	mov	w16, #0x4               ; =4
100002d28:     	svc	#0x80
100002d2c:     	add	sp, sp, #0x160
100002d30:     	ldr	x9, [sp, #0x928]
100002d34:     	ldr	x2, [x9]
100002d38:     	mov	x10, #0xffff            ; =65535
100002d3c:     	movk	x10, #0xffff, lsl #16
100002d40:     	movk	x10, #0xffff, lsl #32
100002d44:     	movk	x10, #0x7fff, lsl #48
100002d48:     	and	x2, x2, x10
100002d4c:     	add	x1, x9, #0x8
100002d50:     	mov	w0, #0x1                ; =1
100002d54:     	mov	w16, #0x4               ; =4
100002d58:     	svc	#0x80
100002d5c:     	ldr	x0, [sp, #0x930]
100002d60:     	sub	sp, sp, #0x160
100002d64:     	mov	x1, sp
100002d68:     	mov	w2, #0x0                ; =0
100002d6c:     	bl	0x100007a48 <_main+0x5c8>
100002d70:     	mov	w8, #0x0                ; =0
100002d74:     	mov	x2, x0
100002d78:     	mov	w0, #0x1                ; =1
100002d7c:     	mov	x1, sp
100002d80:     	mov	w16, #0x4               ; =4
100002d84:     	svc	#0x80
100002d88:     	add	sp, sp, #0x160
100002d8c:     	ldr	x9, [sp, #0x938]
100002d90:     	ldr	x2, [x9]
100002d94:     	mov	x10, #0xffff            ; =65535
100002d98:     	movk	x10, #0xffff, lsl #16
100002d9c:     	movk	x10, #0xffff, lsl #32
100002da0:     	movk	x10, #0x7fff, lsl #48
100002da4:     	and	x2, x2, x10
100002da8:     	add	x1, x9, #0x8
100002dac:     	mov	w0, #0x1                ; =1
100002db0:     	mov	w16, #0x4               ; =4
100002db4:     	svc	#0x80
100002db8:     	ldr	x0, [sp, #0x940]
100002dbc:     	sub	sp, sp, #0x160
100002dc0:     	mov	x1, sp
100002dc4:     	mov	w2, #0x0                ; =0
100002dc8:     	bl	0x100007a48 <_main+0x5c8>
100002dcc:     	mov	w8, #0x0                ; =0
100002dd0:     	mov	x2, x0
100002dd4:     	mov	w0, #0x1                ; =1
100002dd8:     	mov	x1, sp
100002ddc:     	mov	w16, #0x4               ; =4
100002de0:     	svc	#0x80
100002de4:     	add	sp, sp, #0x160
100002de8:     	ldr	x9, [sp, #0x948]
100002dec:     	ldr	x2, [x9]
100002df0:     	mov	x10, #0xffff            ; =65535
100002df4:     	movk	x10, #0xffff, lsl #16
100002df8:     	movk	x10, #0xffff, lsl #32
100002dfc:     	movk	x10, #0x7fff, lsl #48
100002e00:     	and	x2, x2, x10
100002e04:     	add	x1, x9, #0x8
100002e08:     	mov	w0, #0x1                ; =1
100002e0c:     	mov	w16, #0x4               ; =4
100002e10:     	svc	#0x80
100002e14:     	ldr	x0, [sp, #0x950]
100002e18:     	sub	sp, sp, #0x160
100002e1c:     	mov	x1, sp
100002e20:     	mov	w2, #0x0                ; =0
100002e24:     	bl	0x100007a48 <_main+0x5c8>
100002e28:     	mov	w8, #0x0                ; =0
100002e2c:     	mov	x2, x0
100002e30:     	mov	w0, #0x1                ; =1
100002e34:     	mov	x1, sp
100002e38:     	mov	w16, #0x4               ; =4
100002e3c:     	svc	#0x80
100002e40:     	add	sp, sp, #0x160
100002e44:     	ldr	x9, [sp, #0x958]
100002e48:     	ldr	x2, [x9]
100002e4c:     	mov	x10, #0xffff            ; =65535
100002e50:     	movk	x10, #0xffff, lsl #16
100002e54:     	movk	x10, #0xffff, lsl #32
100002e58:     	movk	x10, #0x7fff, lsl #48
100002e5c:     	and	x2, x2, x10
100002e60:     	add	x1, x9, #0x8
100002e64:     	mov	w0, #0x1                ; =1
100002e68:     	mov	w16, #0x4               ; =4
100002e6c:     	svc	#0x80
100002e70:     	ldr	x0, [sp, #0x960]
100002e74:     	sub	sp, sp, #0x160
100002e78:     	mov	x1, sp
100002e7c:     	mov	w2, #0x0                ; =0
100002e80:     	bl	0x100007a48 <_main+0x5c8>
100002e84:     	mov	w8, #0x0                ; =0
100002e88:     	mov	x2, x0
100002e8c:     	mov	w0, #0x1                ; =1
100002e90:     	mov	x1, sp
100002e94:     	mov	w16, #0x4               ; =4
100002e98:     	svc	#0x80
100002e9c:     	add	sp, sp, #0x160
100002ea0:     	ldr	x9, [sp, #0x968]
100002ea4:     	ldr	x2, [x9]
100002ea8:     	mov	x10, #0xffff            ; =65535
100002eac:     	movk	x10, #0xffff, lsl #16
100002eb0:     	movk	x10, #0xffff, lsl #32
100002eb4:     	movk	x10, #0x7fff, lsl #48
100002eb8:     	and	x2, x2, x10
100002ebc:     	add	x1, x9, #0x8
100002ec0:     	mov	w0, #0x1                ; =1
100002ec4:     	mov	w16, #0x4               ; =4
100002ec8:     	svc	#0x80
100002ecc:     	ldr	x0, [sp, #0x970]
100002ed0:     	sub	sp, sp, #0x160
100002ed4:     	mov	x1, sp
100002ed8:     	mov	w2, #0x0                ; =0
100002edc:     	bl	0x100007a48 <_main+0x5c8>
100002ee0:     	mov	w8, #0x0                ; =0
100002ee4:     	mov	x2, x0
100002ee8:     	mov	w0, #0x1                ; =1
100002eec:     	mov	x1, sp
100002ef0:     	mov	w16, #0x4               ; =4
100002ef4:     	svc	#0x80
100002ef8:     	add	sp, sp, #0x160
100002efc:     	ldr	x9, [sp, #0x978]
100002f00:     	ldr	x2, [x9]
100002f04:     	mov	x10, #0xffff            ; =65535
100002f08:     	movk	x10, #0xffff, lsl #16
100002f0c:     	movk	x10, #0xffff, lsl #32
100002f10:     	movk	x10, #0x7fff, lsl #48
100002f14:     	and	x2, x2, x10
100002f18:     	add	x1, x9, #0x8
100002f1c:     	mov	w0, #0x1                ; =1
100002f20:     	mov	w16, #0x4               ; =4
100002f24:     	svc	#0x80
100002f28:     	ldr	x0, [sp, #0x980]
100002f2c:     	sub	sp, sp, #0x160
100002f30:     	mov	x1, sp
100002f34:     	mov	w2, #0x0                ; =0
100002f38:     	bl	0x100007a48 <_main+0x5c8>
100002f3c:     	mov	w8, #0x0                ; =0
100002f40:     	mov	x2, x0
100002f44:     	mov	w0, #0x1                ; =1
100002f48:     	mov	x1, sp
100002f4c:     	mov	w16, #0x4               ; =4
100002f50:     	svc	#0x80
100002f54:     	add	sp, sp, #0x160
100002f58:     	mov	w0, #0x1                ; =1
100002f5c:     	adrp	x1, 0x100008000 <_main+0xb80>
100002f60:     	add	x1, x1, #0xf10
100002f64:     	mov	x2, #0x1                ; =1
100002f68:     	movk	x2, #0x0, lsl #16
100002f6c:     	movk	x2, #0x0, lsl #32
100002f70:     	movk	x2, #0x0, lsl #48
100002f74:     	mov	w16, #0x4               ; =4
100002f78:     	svc	#0x80
100002f7c:     	b	0x100003154 <_silex_function_2+0x261c>
100002f80:     	ldr	x9, [sp, #0xe80]
100002f84:     	ldr	s17, [x9]
100002f88:     	ldr	x9, [sp, #0xe80]
100002f8c:     	ldr	s19, [x9, #0x8]
100002f90:     	ldr	x9, [sp, #0xe80]
100002f94:     	ldr	s20, [x9, #0x10]
100002f98:     	ldr	x9, [sp, #0xe80]
100002f9c:     	ldr	s21, [x9, #0x18]
100002fa0:     	ldr	x9, [sp, #0xe80]
100002fa4:     	ldr	s22, [x9, #0x20]
100002fa8:     	ldr	x9, [sp, #0xe80]
100002fac:     	ldr	s23, [x9, #0x28]
100002fb0:     	ldr	x9, [sp, #0xe80]
100002fb4:     	ldr	s24, [x9, #0x30]
100002fb8:     	ldr	x9, [sp, #0xe80]
100002fbc:     	ldr	s25, [x9, #0x38]
100002fc0:     	ldr	x9, [sp, #0xe80]
100002fc4:     	ldr	s26, [x9, #0x40]
100002fc8:     	ldr	x9, [sp, #0xe80]
100002fcc:     	ldr	s27, [x9, #0x48]
100002fd0:     	ldr	x9, [sp, #0xe80]
100002fd4:     	ldr	s28, [x9, #0x50]
100002fd8:     	ldr	x9, [sp, #0xe80]
100002fdc:     	ldr	s29, [x9, #0x58]
100002fe0:     	ldr	x9, [sp, #0xe80]
100002fe4:     	ldr	s30, [x9, #0x60]
100002fe8:     	ldr	x9, [sp, #0xe80]
100002fec:     	ldr	s31, [x9, #0x68]
100002ff0:     	ldr	x9, [sp, #0xe80]
100002ff4:     	ldr	s0, [x9, #0x70]
100002ff8:     	ldr	x9, [sp, #0xe80]
100002ffc:     	ldr	s1, [x9, #0x78]
100003000:     	ldr	x9, [sp, #0xe80]
100003004:     	ldr	s2, [x9, #0x80]
100003008:     	ldr	x9, [sp, #0xe80]
10000300c:     	ldr	s3, [x9, #0x88]
100003010:     	ldr	x9, [sp, #0xe80]
100003014:     	ldr	s4, [x9, #0x90]
100003018:     	ldr	x9, [sp, #0xe80]
10000301c:     	ldr	s5, [x9, #0x98]
100003020:     	ldr	x9, [sp, #0xe80]
100003024:     	ldr	s8, [x9, #0xa0]
100003028:     	ldr	x9, [sp, #0xe80]
10000302c:     	ldr	s13, [x9, #0xa8]
100003030:     	ldr	x9, [sp, #0xe80]
100003034:     	ldr	s14, [x9, #0xb0]
100003038:     	ldr	x9, [sp, #0xe80]
10000303c:     	ldr	s15, [x9, #0xb8]
100003040:     	ldr	x9, [sp, #0xe80]
100003044:     	ldr	x10, [x9, #0xc0]
100003048:     	str	x10, [sp, #0x11c0]
10000304c:     	ldr	x9, [sp, #0xe80]
100003050:     	ldr	x10, [x9, #0xc8]
100003054:     	str	x10, [sp, #0x11d0]
100003058:     	ldr	d16, [sp, #0xe90]
10000305c:     	fmov	s18, #1.00000000
100003060:     	fmul	s17, s17, s18
100003064:     	fmov	s18, #2.00000000
100003068:     	fmadd	s17, s19, s18, s17
10000306c:     	fmov	s18, #3.00000000
100003070:     	fmadd	s17, s20, s18, s17
100003074:     	fmov	s18, #4.00000000
100003078:     	fmadd	s17, s21, s18, s17
10000307c:     	fmov	s18, #5.00000000
100003080:     	fmadd	s17, s22, s18, s17
100003084:     	fmov	s18, #6.00000000
100003088:     	fmadd	s17, s23, s18, s17
10000308c:     	fmov	s18, #7.00000000
100003090:     	fmadd	s17, s24, s18, s17
100003094:     	fmov	s18, #8.00000000
100003098:     	fmadd	s17, s25, s18, s17
10000309c:     	fmov	s18, #9.00000000
1000030a0:     	fmadd	s17, s26, s18, s17
1000030a4:     	fmov	s18, #10.00000000
1000030a8:     	fmadd	s17, s27, s18, s17
1000030ac:     	fmov	s18, #11.00000000
1000030b0:     	fmadd	s17, s28, s18, s17
1000030b4:     	fmov	s18, #12.00000000
1000030b8:     	fmadd	s17, s29, s18, s17
1000030bc:     	fmov	s18, #13.00000000
1000030c0:     	fmadd	s17, s30, s18, s17
1000030c4:     	fmov	s18, #14.00000000
1000030c8:     	fmadd	s17, s31, s18, s17
1000030cc:     	fmov	s18, #15.00000000
1000030d0:     	fmadd	s17, s0, s18, s17
1000030d4:     	fmov	s18, #16.00000000
1000030d8:     	fmadd	s17, s1, s18, s17
1000030dc:     	fmov	s18, #17.00000000
1000030e0:     	fmadd	s17, s2, s18, s17
1000030e4:     	fmov	s18, #18.00000000
1000030e8:     	fmadd	s17, s3, s18, s17
1000030ec:     	fmov	s18, #19.00000000
1000030f0:     	fmadd	s17, s4, s18, s17
1000030f4:     	fmov	s18, #20.00000000
1000030f8:     	fmadd	s17, s5, s18, s17
1000030fc:     	fmov	s18, #21.00000000
100003100:     	fmadd	s17, s8, s18, s17
100003104:     	fmov	s18, #22.00000000
100003108:     	fmadd	s17, s13, s18, s17
10000310c:     	fmov	s18, #23.00000000
100003110:     	fmadd	s17, s14, s18, s17
100003114:     	fmov	s18, #24.00000000
100003118:     	fmadd	s17, s15, s18, s17
10000311c:     	ldr	x9, [sp, #0x11c0]
100003120:     	str	x9, [sp, #0xc88]
100003124:     	fmov	s18, #25.00000000
100003128:     	ldr	s9, [sp, #0xc88]
10000312c:     	fmadd	s17, s9, s18, s17
100003130:     	ldr	x9, [sp, #0x11d0]
100003134:     	str	x9, [sp, #0xca8]
100003138:     	fmov	s18, #26.00000000
10000313c:     	ldr	s9, [sp, #0xca8]
100003140:     	fmadd	s17, s9, s18, s17
100003144:     	fmov	s9, s17
100003148:     	fcvt	d18, s9
10000314c:     	fadd	d16, d16, d18
100003150:     	str	d16, [sp, #0xe90]
100003154:     	ldr	x9, [sp, #0xe18]
100003158:     	add	x20, x9, #0x1
10000315c:     	ldr	x9, [sp, #0xe80]
100003160:     	add	x9, x9, #0xd0
100003164:     	str	x9, [sp, #0xe80]
100003168:     	mov	x9, x20
10000316c:     	str	x9, [sp, #0xe18]
100003170:     	b	0x1000020d0 <_silex_function_2+0x1598>
100003174:     	ldr	x9, [sp, #0xe40]
100003178:     	mov	x19, x9
10000317c:     	ldr	x9, [sp, #0xe48]
100003180:     	mov	x20, x9
100003184:     	ldr	x9, [sp, #0xe50]
100003188:     	mov	x21, x9
10000318c:     	ldr	x9, [sp, #0xe38]
100003190:     	str	x9, [sp, #0xd08]
100003194:     	mov	x9, x19
100003198:     	str	x9, [sp, #0xd10]
10000319c:     	mov	x9, x20
1000031a0:     	str	x9, [sp, #0xd18]
1000031a4:     	mov	x9, x21
1000031a8:     	str	x9, [sp, #0xd20]
1000031ac:     	ldr	x9, [sp, #0xe58]
1000031b0:     	str	x9, [sp, #0xd28]
1000031b4:     	ldr	x9, [sp, #0xe60]
1000031b8:     	str	x9, [sp, #0xd30]
1000031bc:     	add	x0, sp, #0xd08
1000031c0:     	add	x15, sp, #0xd38
1000031c4:     	bl	0x100006f30 <_silex_function_12>
1000031c8:     	cbnz	w8, 0x100003554 <_silex_function_2+0x2a1c>
1000031cc:     	ldr	d16, [sp, #0xd68]
1000031d0:     	mov	x9, #0x447a0000         ; =1148846080
1000031d4:     	fmov	s17, w9
1000031d8:     	fmul	s11, s16, s17
1000031dc:     	str	s11, [sp, #0xd80]
1000031e0:     	adrp	x9, 0x100009000 <_main+0x1b80>
1000031e4:     	add	x9, x9, #0x508
1000031e8:     	str	x9, [sp, #0xd88]
1000031ec:     	adrp	x9, 0x100009000 <_main+0x1b80>
1000031f0:     	add	x9, x9, #0x480
1000031f4:     	str	x9, [sp, #0xd90]
1000031f8:     	adrp	x9, 0x100009000 <_main+0x1b80>
1000031fc:     	add	x9, x9, #0x480
100003200:     	str	x9, [sp, #0xd98]
100003204:     	adrp	x9, 0x100009000 <_main+0x1b80>
100003208:     	add	x9, x9, #0x480
10000320c:     	str	x9, [sp, #0xda0]
100003210:     	ldr	x9, [sp, #0xe88]
100003214:     	str	x9, [sp, #0xda8]
100003218:     	ldr	x9, [sp, #0xd88]
10000321c:     	ldr	x2, [x9]
100003220:     	mov	x10, #0xffff            ; =65535
100003224:     	movk	x10, #0xffff, lsl #16
100003228:     	movk	x10, #0xffff, lsl #32
10000322c:     	movk	x10, #0x7fff, lsl #48
100003230:     	and	x2, x2, x10
100003234:     	add	x1, x9, #0x8
100003238:     	mov	w0, #0x1                ; =1
10000323c:     	mov	w16, #0x4               ; =4
100003240:     	svc	#0x80
100003244:     	ldr	x9, [sp, #0xde0]
100003248:     	sub	sp, sp, #0x20
10000324c:     	add	x11, sp, #0x20
100003250:     	mov	w12, #0x0               ; =0
100003254:     	cbnz	x9, 0x10000326c <_silex_function_2+0x2734>
100003258:     	sub	x11, x11, #0x1
10000325c:     	mov	w10, #0x30              ; =48
100003260:     	strb	w10, [x11]
100003264:     	add	x12, x12, #0x1
100003268:     	b	0x1000032c0 <_silex_function_2+0x2788>
10000326c:     	mov	w3, #0x0                ; =0
100003270:     	cmp	x9, xzr
100003274:     	b.lt	0x100003280 <_silex_function_2+0x2748>
100003278:     	negs	x9, x9
10000327c:     	b	0x100003284 <_silex_function_2+0x274c>
100003280:     	mov	w3, #0x1                ; =1
100003284:     	mov	w10, #0xa               ; =10
100003288:     	sdiv	x4, x9, x10
10000328c:     	msub	x5, x4, x10, x9
100003290:     	mov	w6, #0x30               ; =48
100003294:     	subs	x6, x6, x5
100003298:     	sub	x11, x11, #0x1
10000329c:     	strb	w6, [x11]
1000032a0:     	add	x12, x12, #0x1
1000032a4:     	mov	x9, x4
1000032a8:     	cbnz	x9, 0x100003284 <_silex_function_2+0x274c>
1000032ac:     	cbz	w3, 0x1000032c0 <_silex_function_2+0x2788>
1000032b0:     	sub	x11, x11, #0x1
1000032b4:     	mov	w10, #0x2d              ; =45
1000032b8:     	strb	w10, [x11]
1000032bc:     	add	x12, x12, #0x1
1000032c0:     	mov	w0, #0x1                ; =1
1000032c4:     	mov	x1, x11
1000032c8:     	mov	x2, x12
1000032cc:     	mov	w16, #0x4               ; =4
1000032d0:     	svc	#0x80
1000032d4:     	add	sp, sp, #0x20
1000032d8:     	ldr	x9, [sp, #0xd90]
1000032dc:     	ldr	x2, [x9]
1000032e0:     	mov	x10, #0xffff            ; =65535
1000032e4:     	movk	x10, #0xffff, lsl #16
1000032e8:     	movk	x10, #0xffff, lsl #32
1000032ec:     	movk	x10, #0x7fff, lsl #48
1000032f0:     	and	x2, x2, x10
1000032f4:     	add	x1, x9, #0x8
1000032f8:     	mov	w0, #0x1                ; =1
1000032fc:     	mov	w16, #0x4               ; =4
100003300:     	svc	#0x80
100003304:     	ldr	x9, [sp, #0xde8]
100003308:     	sub	sp, sp, #0x20
10000330c:     	add	x11, sp, #0x20
100003310:     	mov	w12, #0x0               ; =0
100003314:     	cbnz	x9, 0x10000332c <_silex_function_2+0x27f4>
100003318:     	sub	x11, x11, #0x1
10000331c:     	mov	w10, #0x30              ; =48
100003320:     	strb	w10, [x11]
100003324:     	add	x12, x12, #0x1
100003328:     	b	0x100003380 <_silex_function_2+0x2848>
10000332c:     	mov	w3, #0x0                ; =0
100003330:     	cmp	x9, xzr
100003334:     	b.lt	0x100003340 <_silex_function_2+0x2808>
100003338:     	negs	x9, x9
10000333c:     	b	0x100003344 <_silex_function_2+0x280c>
100003340:     	mov	w3, #0x1                ; =1
100003344:     	mov	w10, #0xa               ; =10
100003348:     	sdiv	x4, x9, x10
10000334c:     	msub	x5, x4, x10, x9
100003350:     	mov	w6, #0x30               ; =48
100003354:     	subs	x6, x6, x5
100003358:     	sub	x11, x11, #0x1
10000335c:     	strb	w6, [x11]
100003360:     	add	x12, x12, #0x1
100003364:     	mov	x9, x4
100003368:     	cbnz	x9, 0x100003344 <_silex_function_2+0x280c>
10000336c:     	cbz	w3, 0x100003380 <_silex_function_2+0x2848>
100003370:     	sub	x11, x11, #0x1
100003374:     	mov	w10, #0x2d              ; =45
100003378:     	strb	w10, [x11]
10000337c:     	add	x12, x12, #0x1
100003380:     	mov	w0, #0x1                ; =1
100003384:     	mov	x1, x11
100003388:     	mov	x2, x12
10000338c:     	mov	w16, #0x4               ; =4
100003390:     	svc	#0x80
100003394:     	add	sp, sp, #0x20
100003398:     	ldr	x9, [sp, #0xd98]
10000339c:     	ldr	x2, [x9]
1000033a0:     	mov	x10, #0xffff            ; =65535
1000033a4:     	movk	x10, #0xffff, lsl #16
1000033a8:     	movk	x10, #0xffff, lsl #32
1000033ac:     	movk	x10, #0x7fff, lsl #48
1000033b0:     	and	x2, x2, x10
1000033b4:     	add	x1, x9, #0x8
1000033b8:     	mov	w0, #0x1                ; =1
1000033bc:     	mov	w16, #0x4               ; =4
1000033c0:     	svc	#0x80
1000033c4:     	ldr	x0, [sp, #0xd80]
1000033c8:     	sub	sp, sp, #0x160
1000033cc:     	mov	x1, sp
1000033d0:     	mov	w2, #0x0                ; =0
1000033d4:     	bl	0x100007a48 <_main+0x5c8>
1000033d8:     	mov	w8, #0x0                ; =0
1000033dc:     	mov	x2, x0
1000033e0:     	mov	w0, #0x1                ; =1
1000033e4:     	mov	x1, sp
1000033e8:     	mov	w16, #0x4               ; =4
1000033ec:     	svc	#0x80
1000033f0:     	add	sp, sp, #0x160
1000033f4:     	ldr	x9, [sp, #0xda0]
1000033f8:     	ldr	x2, [x9]
1000033fc:     	mov	x10, #0xffff            ; =65535
100003400:     	movk	x10, #0xffff, lsl #16
100003404:     	movk	x10, #0xffff, lsl #32
100003408:     	movk	x10, #0x7fff, lsl #48
10000340c:     	and	x2, x2, x10
100003410:     	add	x1, x9, #0x8
100003414:     	mov	w0, #0x1                ; =1
100003418:     	mov	w16, #0x4               ; =4
10000341c:     	svc	#0x80
100003420:     	ldr	x0, [sp, #0xda8]
100003424:     	sub	sp, sp, #0x160
100003428:     	mov	x1, sp
10000342c:     	mov	w2, #0x1                ; =1
100003430:     	bl	0x100007a48 <_main+0x5c8>
100003434:     	mov	w8, #0x0                ; =0
100003438:     	mov	x2, x0
10000343c:     	mov	w0, #0x1                ; =1
100003440:     	mov	x1, sp
100003444:     	mov	w16, #0x4               ; =4
100003448:     	svc	#0x80
10000344c:     	add	sp, sp, #0x160
100003450:     	mov	w0, #0x1                ; =1
100003454:     	adrp	x1, 0x100008000 <_main+0xb80>
100003458:     	add	x1, x1, #0xf10
10000345c:     	mov	x2, #0x1                ; =1
100003460:     	movk	x2, #0x0, lsl #16
100003464:     	movk	x2, #0x0, lsl #32
100003468:     	movk	x2, #0x0, lsl #48
10000346c:     	mov	w16, #0x4               ; =4
100003470:     	svc	#0x80
100003474:     	ldr	x9, [sp, #0x11e8]
100003478:     	str	x9, [sp, #0xdb0]
10000347c:     	ldr	x10, [sp, #0xdb0]
100003480:     	add	x14, x10, #0x8
100003484:     	ldaxr	x9, [x14]
100003488:     	cbz	x9, 0x1000034e0 <_silex_function_2+0x29a8>
10000348c:     	sub	x9, x9, #0x1
100003490:     	stlxr	w11, x9, [x14]
100003494:     	cbnz	w11, 0x100003484 <_silex_function_2+0x294c>
100003498:     	ldr	x11, [x10, #0x10]
10000349c:     	add	x9, x9, x11
1000034a0:     	cbnz	x9, 0x1000034e0 <_silex_function_2+0x29a8>
1000034a4:     	add	x14, x10, #0x20
1000034a8:     	ldaxr	x9, [x14]
1000034ac:     	mov	x11, #0x2               ; =2
1000034b0:     	cmp	x9, x11
1000034b4:     	b.eq	0x1000034a8 <_silex_function_2+0x2970>
1000034b8:     	mov	x11, #0x1               ; =1
1000034bc:     	cmp	x9, x11
1000034c0:     	b.eq	0x1000034e0 <_silex_function_2+0x29a8>
1000034c4:     	mov	x9, #0x1                ; =1
1000034c8:     	stlxr	w11, x9, [x14]
1000034cc:     	cbnz	w11, 0x1000034a8 <_silex_function_2+0x2970>
1000034d0:     	ldr	x1, [x10, #0x18]
1000034d4:     	mov	x0, x10
1000034d8:     	mov	w16, #0x49              ; =73
1000034dc:     	svc	#0x80
1000034e0:     	ldr	x9, [sp, #0x11e0]
1000034e4:     	str	x9, [sp, #0xdb8]
1000034e8:     	ldr	x10, [sp, #0xdb8]
1000034ec:     	add	x14, x10, #0x8
1000034f0:     	ldaxr	x9, [x14]
1000034f4:     	cbz	x9, 0x10000354c <_silex_function_2+0x2a14>
1000034f8:     	sub	x9, x9, #0x1
1000034fc:     	stlxr	w11, x9, [x14]
100003500:     	cbnz	w11, 0x1000034f0 <_silex_function_2+0x29b8>
100003504:     	ldr	x11, [x10, #0x10]
100003508:     	add	x9, x9, x11
10000350c:     	cbnz	x9, 0x10000354c <_silex_function_2+0x2a14>
100003510:     	add	x14, x10, #0x20
100003514:     	ldaxr	x9, [x14]
100003518:     	mov	x11, #0x2               ; =2
10000351c:     	cmp	x9, x11
100003520:     	b.eq	0x100003514 <_silex_function_2+0x29dc>
100003524:     	mov	x11, #0x1               ; =1
100003528:     	cmp	x9, x11
10000352c:     	b.eq	0x10000354c <_silex_function_2+0x2a14>
100003530:     	mov	x9, #0x1                ; =1
100003534:     	stlxr	w11, x9, [x14]
100003538:     	cbnz	w11, 0x100003514 <_silex_function_2+0x29dc>
10000353c:     	ldr	x1, [x10, #0x18]
100003540:     	mov	x0, x10
100003544:     	mov	w16, #0x49              ; =73
100003548:     	svc	#0x80
10000354c:     	mov	w0, #0x0                ; =0
100003550:     	mov	w8, #0x0                ; =0
100003554:     	mov	x14, sp
100003558:     	add	x14, x14, #0xff0
10000355c:     	add	x14, x14, #0x210
100003560:     	ldr	x19, [x14]
100003564:     	mov	x14, sp
100003568:     	add	x14, x14, #0xff0
10000356c:     	add	x14, x14, #0x218
100003570:     	ldr	x20, [x14]
100003574:     	mov	x14, sp
100003578:     	add	x14, x14, #0xff0
10000357c:     	add	x14, x14, #0x220
100003580:     	ldr	x21, [x14]
100003584:     	mov	x14, sp
100003588:     	add	x14, x14, #0xff0
10000358c:     	add	x14, x14, #0x228
100003590:     	ldr	x22, [x14]
100003594:     	mov	x14, sp
100003598:     	add	x14, x14, #0xff0
10000359c:     	add	x14, x14, #0x230
1000035a0:     	ldr	x23, [x14]
1000035a4:     	mov	x14, sp
1000035a8:     	add	x14, x14, #0xff0
1000035ac:     	add	x14, x14, #0x238
1000035b0:     	ldr	x24, [x14]
1000035b4:     	mov	x14, sp
1000035b8:     	add	x14, x14, #0xff0
1000035bc:     	add	x14, x14, #0x240
1000035c0:     	ldr	x9, [x14]
1000035c4:     	fmov	d8, x9
1000035c8:     	mov	x14, sp
1000035cc:     	add	x14, x14, #0xff0
1000035d0:     	add	x14, x14, #0x248
1000035d4:     	ldr	x9, [x14]
1000035d8:     	fmov	d13, x9
1000035dc:     	mov	x14, sp
1000035e0:     	add	x14, x14, #0xff0
1000035e4:     	add	x14, x14, #0x250
1000035e8:     	ldr	x9, [x14]
1000035ec:     	fmov	d14, x9
1000035f0:     	mov	x14, sp
1000035f4:     	add	x14, x14, #0xff0
1000035f8:     	add	x14, x14, #0x258
1000035fc:     	ldr	x9, [x14]
100003600:     	fmov	d15, x9
100003604:     	add	sp, sp, #0xff0
100003608:     	add	sp, sp, #0x260
10000360c:     	ldp	x29, x30, [sp], #0x10
100003610:     	ret
100003614:     	mov	w0, #0x2                ; =2
100003618:     	adrp	x1, 0x100009000 <_main+0x1b80>
10000361c:     	add	x1, x1, #0x340
100003620:     	mov	x2, #0x5f               ; =95
100003624:     	movk	x2, #0x0, lsl #16
100003628:     	movk	x2, #0x0, lsl #32
10000362c:     	movk	x2, #0x0, lsl #48
100003630:     	mov	w16, #0x4               ; =4
100003634:     	svc	#0x80
100003638:     	ldr	x9, [sp, #0xe10]
10000363c:     	sub	sp, sp, #0x20
100003640:     	add	x11, sp, #0x20
100003644:     	mov	w12, #0x0               ; =0
100003648:     	cbnz	x9, 0x100003660 <_silex_function_2+0x2b28>
10000364c:     	sub	x11, x11, #0x1
100003650:     	mov	w10, #0x30              ; =48
100003654:     	strb	w10, [x11]
100003658:     	add	x12, x12, #0x1
10000365c:     	b	0x1000036b4 <_silex_function_2+0x2b7c>
100003660:     	mov	w3, #0x0                ; =0
100003664:     	cmp	x9, xzr
100003668:     	b.lt	0x100003674 <_silex_function_2+0x2b3c>
10000366c:     	negs	x9, x9
100003670:     	b	0x100003678 <_silex_function_2+0x2b40>
100003674:     	mov	w3, #0x1                ; =1
100003678:     	mov	w10, #0xa               ; =10
10000367c:     	sdiv	x4, x9, x10
100003680:     	msub	x5, x4, x10, x9
100003684:     	mov	w6, #0x30               ; =48
100003688:     	subs	x6, x6, x5
10000368c:     	sub	x11, x11, #0x1
100003690:     	strb	w6, [x11]
100003694:     	add	x12, x12, #0x1
100003698:     	mov	x9, x4
10000369c:     	cbnz	x9, 0x100003678 <_silex_function_2+0x2b40>
1000036a0:     	cbz	w3, 0x1000036b4 <_silex_function_2+0x2b7c>
1000036a4:     	sub	x11, x11, #0x1
1000036a8:     	mov	w10, #0x2d              ; =45
1000036ac:     	strb	w10, [x11]
1000036b0:     	add	x12, x12, #0x1
1000036b4:     	mov	w0, #0x2                ; =2
1000036b8:     	mov	x1, x11
1000036bc:     	mov	x2, x12
1000036c0:     	mov	w16, #0x4               ; =4
1000036c4:     	svc	#0x80
1000036c8:     	add	sp, sp, #0x20
1000036cc:     	mov	w0, #0x2                ; =2
1000036d0:     	adrp	x1, 0x100009000 <_main+0x1b80>
1000036d4:     	add	x1, x1, #0x178
1000036d8:     	mov	x2, #0x1c               ; =28
1000036dc:     	movk	x2, #0x0, lsl #16
1000036e0:     	movk	x2, #0x0, lsl #32
1000036e4:     	movk	x2, #0x0, lsl #48
1000036e8:     	mov	w16, #0x4               ; =4
1000036ec:     	svc	#0x80
1000036f0:     	mov	w8, #0x3                ; =3
1000036f4:     	b	0x100003554 <_silex_function_2+0x2a1c>
1000036f8:     	str	x19, [sp, #0x688]
1000036fc:     	mov	w0, #0x2                ; =2
100003700:     	adrp	x1, 0x100009000 <_main+0x1b80>
100003704:     	add	x1, x1, #0x3a8
100003708:     	mov	x2, #0x5f               ; =95
10000370c:     	movk	x2, #0x0, lsl #16
100003710:     	movk	x2, #0x0, lsl #32
100003714:     	movk	x2, #0x0, lsl #48
100003718:     	mov	w16, #0x4               ; =4
10000371c:     	svc	#0x80
100003720:     	ldr	x9, [sp, #0x688]
100003724:     	sub	sp, sp, #0x20
100003728:     	add	x11, sp, #0x20
10000372c:     	mov	w12, #0x0               ; =0
100003730:     	cbnz	x9, 0x100003748 <_silex_function_2+0x2c10>
100003734:     	sub	x11, x11, #0x1
100003738:     	mov	w10, #0x30              ; =48
10000373c:     	strb	w10, [x11]
100003740:     	add	x12, x12, #0x1
100003744:     	b	0x10000379c <_silex_function_2+0x2c64>
100003748:     	mov	w3, #0x0                ; =0
10000374c:     	cmp	x9, xzr
100003750:     	b.lt	0x10000375c <_silex_function_2+0x2c24>
100003754:     	negs	x9, x9
100003758:     	b	0x100003760 <_silex_function_2+0x2c28>
10000375c:     	mov	w3, #0x1                ; =1
100003760:     	mov	w10, #0xa               ; =10
100003764:     	sdiv	x4, x9, x10
100003768:     	msub	x5, x4, x10, x9
10000376c:     	mov	w6, #0x30               ; =48
100003770:     	subs	x6, x6, x5
100003774:     	sub	x11, x11, #0x1
100003778:     	strb	w6, [x11]
10000377c:     	add	x12, x12, #0x1
100003780:     	mov	x9, x4
100003784:     	cbnz	x9, 0x100003760 <_silex_function_2+0x2c28>
100003788:     	cbz	w3, 0x10000379c <_silex_function_2+0x2c64>
10000378c:     	sub	x11, x11, #0x1
100003790:     	mov	w10, #0x2d              ; =45
100003794:     	strb	w10, [x11]
100003798:     	add	x12, x12, #0x1
10000379c:     	mov	w0, #0x2                ; =2
1000037a0:     	mov	x1, x11
1000037a4:     	mov	x2, x12
1000037a8:     	mov	w16, #0x4               ; =4
1000037ac:     	svc	#0x80
1000037b0:     	add	sp, sp, #0x20
1000037b4:     	mov	w0, #0x2                ; =2
1000037b8:     	adrp	x1, 0x100009000 <_main+0x1b80>
1000037bc:     	add	x1, x1, #0x178
1000037c0:     	mov	x2, #0x1c               ; =28
1000037c4:     	movk	x2, #0x0, lsl #16
1000037c8:     	movk	x2, #0x0, lsl #32
1000037cc:     	movk	x2, #0x0, lsl #48
1000037d0:     	mov	w16, #0x4               ; =4
1000037d4:     	svc	#0x80
1000037d8:     	mov	w8, #0x3                ; =3
1000037dc:     	b	0x100003554 <_silex_function_2+0x2a1c>
1000037e0:     	str	x19, [sp, #0x688]
1000037e4:     	mov	w0, #0x2                ; =2
1000037e8:     	adrp	x1, 0x100009000 <_main+0x1b80>
1000037ec:     	add	x1, x1, #0x3a8
1000037f0:     	mov	x2, #0x5f               ; =95
1000037f4:     	movk	x2, #0x0, lsl #16
1000037f8:     	movk	x2, #0x0, lsl #32
1000037fc:     	movk	x2, #0x0, lsl #48
100003800:     	mov	w16, #0x4               ; =4
100003804:     	svc	#0x80
100003808:     	ldr	x9, [sp, #0x688]
10000380c:     	sub	sp, sp, #0x20
100003810:     	add	x11, sp, #0x20
100003814:     	mov	w12, #0x0               ; =0
100003818:     	cbnz	x9, 0x100003830 <_silex_function_2+0x2cf8>
10000381c:     	sub	x11, x11, #0x1
100003820:     	mov	w10, #0x30              ; =48
100003824:     	strb	w10, [x11]
100003828:     	add	x12, x12, #0x1
10000382c:     	b	0x100003884 <_silex_function_2+0x2d4c>
100003830:     	mov	w3, #0x0                ; =0
100003834:     	cmp	x9, xzr
100003838:     	b.lt	0x100003844 <_silex_function_2+0x2d0c>
10000383c:     	negs	x9, x9
100003840:     	b	0x100003848 <_silex_function_2+0x2d10>
100003844:     	mov	w3, #0x1                ; =1
100003848:     	mov	w10, #0xa               ; =10
10000384c:     	sdiv	x4, x9, x10
100003850:     	msub	x5, x4, x10, x9
100003854:     	mov	w6, #0x30               ; =48
100003858:     	subs	x6, x6, x5
10000385c:     	sub	x11, x11, #0x1
100003860:     	strb	w6, [x11]
100003864:     	add	x12, x12, #0x1
100003868:     	mov	x9, x4
10000386c:     	cbnz	x9, 0x100003848 <_silex_function_2+0x2d10>
100003870:     	cbz	w3, 0x100003884 <_silex_function_2+0x2d4c>
100003874:     	sub	x11, x11, #0x1
100003878:     	mov	w10, #0x2d              ; =45
10000387c:     	strb	w10, [x11]
100003880:     	add	x12, x12, #0x1
100003884:     	mov	w0, #0x2                ; =2
100003888:     	mov	x1, x11
10000388c:     	mov	x2, x12
100003890:     	mov	w16, #0x4               ; =4
100003894:     	svc	#0x80
100003898:     	add	sp, sp, #0x20
10000389c:     	mov	w0, #0x2                ; =2
1000038a0:     	adrp	x1, 0x100009000 <_main+0x1b80>
1000038a4:     	add	x1, x1, #0x178
1000038a8:     	mov	x2, #0x1c               ; =28
1000038ac:     	movk	x2, #0x0, lsl #16
1000038b0:     	movk	x2, #0x0, lsl #32
1000038b4:     	movk	x2, #0x0, lsl #48
1000038b8:     	mov	w16, #0x4               ; =4
1000038bc:     	svc	#0x80
1000038c0:     	mov	w8, #0x3                ; =3
1000038c4:     	b	0x100003554 <_silex_function_2+0x2a1c>
1000038c8:     	mov	w0, #0x2                ; =2
1000038cc:     	adrp	x1, 0x100009000 <_main+0x1b80>
1000038d0:     	add	x1, x1, #0x410
1000038d4:     	mov	x2, #0x5f               ; =95
1000038d8:     	movk	x2, #0x0, lsl #16
1000038dc:     	movk	x2, #0x0, lsl #32
1000038e0:     	movk	x2, #0x0, lsl #48
1000038e4:     	mov	w16, #0x4               ; =4
1000038e8:     	svc	#0x80
1000038ec:     	ldr	x9, [sp, #0xe18]
1000038f0:     	sub	sp, sp, #0x20
1000038f4:     	add	x11, sp, #0x20
1000038f8:     	mov	w12, #0x0               ; =0
1000038fc:     	cbnz	x9, 0x100003914 <_silex_function_2+0x2ddc>
100003900:     	sub	x11, x11, #0x1
100003904:     	mov	w10, #0x30              ; =48
100003908:     	strb	w10, [x11]
10000390c:     	add	x12, x12, #0x1
100003910:     	b	0x100003968 <_silex_function_2+0x2e30>
100003914:     	mov	w3, #0x0                ; =0
100003918:     	cmp	x9, xzr
10000391c:     	b.lt	0x100003928 <_silex_function_2+0x2df0>
100003920:     	negs	x9, x9
100003924:     	b	0x10000392c <_silex_function_2+0x2df4>
100003928:     	mov	w3, #0x1                ; =1
10000392c:     	mov	w10, #0xa               ; =10
100003930:     	sdiv	x4, x9, x10
100003934:     	msub	x5, x4, x10, x9
100003938:     	mov	w6, #0x30               ; =48
10000393c:     	subs	x6, x6, x5
100003940:     	sub	x11, x11, #0x1
100003944:     	strb	w6, [x11]
100003948:     	add	x12, x12, #0x1
10000394c:     	mov	x9, x4
100003950:     	cbnz	x9, 0x10000392c <_silex_function_2+0x2df4>
100003954:     	cbz	w3, 0x100003968 <_silex_function_2+0x2e30>
100003958:     	sub	x11, x11, #0x1
10000395c:     	mov	w10, #0x2d              ; =45
100003960:     	strb	w10, [x11]
100003964:     	add	x12, x12, #0x1
100003968:     	mov	w0, #0x2                ; =2
10000396c:     	mov	x1, x11
100003970:     	mov	x2, x12
100003974:     	mov	w16, #0x4               ; =4
100003978:     	svc	#0x80
10000397c:     	add	sp, sp, #0x20
100003980:     	mov	w0, #0x2                ; =2
100003984:     	adrp	x1, 0x100009000 <_main+0x1b80>
100003988:     	add	x1, x1, #0x178
10000398c:     	mov	x2, #0x1c               ; =28
100003990:     	movk	x2, #0x0, lsl #16
100003994:     	movk	x2, #0x0, lsl #32
100003998:     	movk	x2, #0x0, lsl #48
10000399c:     	mov	w16, #0x4               ; =4
1000039a0:     	svc	#0x80
1000039a4:     	mov	w8, #0x3                ; =3
1000039a8:     	b	0x100003554 <_silex_function_2+0x2a1c>
1000039ac:     	mov	w8, #0x1                ; =1
1000039b0:     	b	0x100003554 <_silex_function_2+0x2a1c>
1000039b4:     	mov	w8, #0x2                ; =2
1000039b8:     	b	0x100003554 <_silex_function_2+0x2a1c>

00000001000039bc <_silex_function_3>:
1000039bc:     	stp	x29, x30, [sp, #-0x10]!
1000039c0:     	mov	x29, sp
1000039c4:     	sub	sp, sp, #0x150
1000039c8:     	str	x15, [sp]
1000039cc:     	add	x15, sp, #0x8
1000039d0:     	bl	0x1000043c4 <_silex_function_5>
1000039d4:     	cbnz	w8, 0x100003fc0 <_silex_function_3+0x604>
1000039d8:     	mov	w9, #0x0                ; =0
1000039dc:     	str	x9, [sp, #0x18]
1000039e0:     	str	x9, [sp, #0x20]
1000039e4:     	ldr	x9, [sp, #0x8]
1000039e8:     	ldr	x10, [sp, #0x18]
1000039ec:     	cmp	x9, x10
1000039f0:     	mov	w11, #0x0               ; =0
1000039f4:     	b.ne	0x1000039fc <_silex_function_3+0x40>
1000039f8:     	mov	w11, #0x1               ; =1
1000039fc:     	str	x11, [sp, #0x28]
100003a00:     	ldr	x9, [sp, #0x28]
100003a04:     	cbz	w9, 0x100003a48 <_silex_function_3+0x8c>
100003a08:     	ldr	x9, [sp, #0x8]
100003a0c:     	mov	x10, #0x1               ; =1
100003a10:     	cmp	x9, x10
100003a14:     	b.ne	0x100003a3c <_silex_function_3+0x80>
100003a18:     	ldr	x9, [sp, #0x10]
100003a1c:     	ldr	x10, [sp, #0x20]
100003a20:     	cmp	x9, x10
100003a24:     	mov	w11, #0x0               ; =0
100003a28:     	b.ne	0x100003a30 <_silex_function_3+0x74>
100003a2c:     	mov	w11, #0x1               ; =1
100003a30:     	str	x11, [sp, #0x28]
100003a34:     	ldr	x9, [sp, #0x28]
100003a38:     	cbz	w9, 0x100003a48 <_silex_function_3+0x8c>
100003a3c:     	mov	w9, #0x0                ; =0
100003a40:     	str	x9, [sp, #0x28]
100003a44:     	b	0x100003a50 <_silex_function_3+0x94>
100003a48:     	mov	w9, #0x1                ; =1
100003a4c:     	str	x9, [sp, #0x28]
100003a50:     	ldr	x9, [sp, #0x28]
100003a54:     	cbz	w9, 0x100003e84 <_silex_function_3+0x4c8>
100003a58:     	ldr	x9, [sp, #0x10]
100003a5c:     	str	x9, [sp, #0x30]
100003a60:     	ldr	x10, [sp, #0x30]
100003a64:     	add	x14, x10, #0x8
100003a68:     	ldaxr	x9, [x14]
100003a6c:     	add	x9, x9, #0x1
100003a70:     	stlxr	w11, x9, [x14]
100003a74:     	cbnz	w11, 0x100003a68 <_silex_function_3+0xac>
100003a78:     	movz	x9, #0x0, lsl #48
100003a7c:     	str	x9, [sp, #0x38]
100003a80:     	mov	x16, x9
100003a84:     	ldr	x9, [sp, #0x30]
100003a88:     	ldr	x10, [x9]
100003a8c:     	str	x10, [sp, #0x40]
100003a90:     	ldr	x9, [sp, #0x38]
100003a94:     	str	x9, [sp, #0x140]
100003a98:     	mov	x16, x9
100003a9c:     	ldr	x9, [sp, #0x140]
100003aa0:     	ldr	x10, [sp, #0x40]
100003aa4:     	cmp	x9, x10
100003aa8:     	mov	w11, #0x0               ; =0
100003aac:     	b.ge	0x100003ab4 <_silex_function_3+0xf8>
100003ab0:     	mov	w11, #0x1               ; =1
100003ab4:     	str	x11, [sp, #0x48]
100003ab8:     	mov	x16, x11
100003abc:     	ldr	x9, [sp, #0x48]
100003ac0:     	cbz	w9, 0x100003b30 <_silex_function_3+0x174>
100003ac4:     	ldr	x10, [sp, #0x30]
100003ac8:     	add	x10, x10, #0x28
100003acc:     	ldr	x9, [sp, #0x140]
100003ad0:     	add	x10, x10, x9, lsl #3
100003ad4:     	ldr	x12, [x10]
100003ad8:     	str	x12, [sp, #0x50]
100003adc:     	ldr	x10, [sp, #0x50]
100003ae0:     	ldr	x9, [x10]
100003ae4:     	mov	x11, #0x0               ; =0
100003ae8:     	movk	x11, #0x0, lsl #16
100003aec:     	movk	x11, #0x0, lsl #32
100003af0:     	movk	x11, #0x8000, lsl #48
100003af4:     	and	x9, x9, x11
100003af8:     	cbz	x9, 0x100003b10 <_silex_function_3+0x154>
100003afc:     	sub	x10, x10, #0x10
100003b00:     	ldaxr	x9, [x10]
100003b04:     	add	x9, x9, #0x1
100003b08:     	stlxr	w11, x9, [x10]
100003b0c:     	cbnz	w11, 0x100003b00 <_silex_function_3+0x144>
100003b10:     	ldr	x9, [sp, #0x140]
100003b14:     	add	x11, x9, #0x1
100003b18:     	str	x11, [sp, #0x60]
100003b1c:     	mov	x16, x11
100003b20:     	mov	x9, x16
100003b24:     	str	x9, [sp, #0x140]
100003b28:     	mov	x17, x9
100003b2c:     	b	0x100003a9c <_silex_function_3+0xe0>
100003b30:     	movz	x9, #0x0, lsl #48
100003b34:     	str	x9, [sp, #0x68]
100003b38:     	mov	w9, #0x0                ; =0
100003b3c:     	str	x9, [sp, #0x70]
100003b40:     	mov	w9, #0x0                ; =0
100003b44:     	str	x9, [sp, #0x78]
100003b48:     	mov	w9, #0x0                ; =0
100003b4c:     	str	x9, [sp, #0x80]
100003b50:     	mov	w9, #0x0                ; =0
100003b54:     	str	x9, [sp, #0x88]
100003b58:     	mov	w9, #0x0                ; =0
100003b5c:     	str	x9, [sp, #0x90]
100003b60:     	ldr	x9, [sp, #0x30]
100003b64:     	str	x9, [sp, #0x70]
100003b68:     	ldr	x9, [sp, #0x30]
100003b6c:     	ldr	x10, [x9]
100003b70:     	str	x10, [sp, #0x98]
100003b74:     	ldr	x9, [sp, #0x98]
100003b78:     	str	x9, [sp, #0x148]
100003b7c:     	mov	x16, x9
100003b80:     	movz	x9, #0x0, lsl #48
100003b84:     	str	x9, [sp, #0xa0]
100003b88:     	mov	x16, x9
100003b8c:     	ldr	x9, [sp, #0x148]
100003b90:     	ldr	x10, [sp, #0xa0]
100003b94:     	cmp	x9, x10
100003b98:     	mov	w11, #0x0               ; =0
100003b9c:     	b.eq	0x100003ba4 <_silex_function_3+0x1e8>
100003ba0:     	mov	w11, #0x1               ; =1
100003ba4:     	str	x11, [sp, #0xa8]
100003ba8:     	mov	x17, x11
100003bac:     	ldr	x9, [sp, #0xa8]
100003bb0:     	cbz	w9, 0x100003de0 <_silex_function_3+0x424>
100003bb4:     	ldr	x9, [sp, #0x148]
100003bb8:     	sub	x11, x9, #0x1
100003bbc:     	str	x11, [sp, #0xb8]
100003bc0:     	mov	x16, x11
100003bc4:     	ldr	x10, [sp, #0x30]
100003bc8:     	ldr	x13, [x10]
100003bcc:     	ldr	x9, [sp, #0xb8]
100003bd0:     	cmp	x9, xzr
100003bd4:     	b.ge	0x100003bdc <_silex_function_3+0x220>
100003bd8:     	add	x9, x9, x13
100003bdc:     	cmp	x9, xzr
100003be0:     	b.lt	0x100003c00 <_silex_function_3+0x244>
100003be4:     	cmp	x9, x13
100003be8:     	b.ge	0x100003c00 <_silex_function_3+0x244>
100003bec:     	add	x10, x10, #0x28
100003bf0:     	add	x10, x10, x9, lsl #3
100003bf4:     	ldr	x12, [x10]
100003bf8:     	str	x12, [sp, #0xc0]
100003bfc:     	b	0x100003d84 <_silex_function_3+0x3c8>
100003c00:     	str	x13, [sp, #0xc0]
100003c04:     	mov	w0, #0x2                ; =2
100003c08:     	adrp	x1, 0x100009000 <_main+0x1b80>
100003c0c:     	add	x1, x1, #0x1c8
100003c10:     	mov	x2, #0x9e               ; =158
100003c14:     	movk	x2, #0x0, lsl #16
100003c18:     	movk	x2, #0x0, lsl #32
100003c1c:     	movk	x2, #0x0, lsl #48
100003c20:     	mov	w16, #0x4               ; =4
100003c24:     	svc	#0x80
100003c28:     	ldr	x9, [sp, #0xb8]
100003c2c:     	sub	sp, sp, #0x20
100003c30:     	add	x11, sp, #0x20
100003c34:     	mov	w12, #0x0               ; =0
100003c38:     	cbnz	x9, 0x100003c50 <_silex_function_3+0x294>
100003c3c:     	sub	x11, x11, #0x1
100003c40:     	mov	w10, #0x30              ; =48
100003c44:     	strb	w10, [x11]
100003c48:     	add	x12, x12, #0x1
100003c4c:     	b	0x100003ca4 <_silex_function_3+0x2e8>
100003c50:     	mov	w3, #0x0                ; =0
100003c54:     	cmp	x9, xzr
100003c58:     	b.lt	0x100003c64 <_silex_function_3+0x2a8>
100003c5c:     	negs	x9, x9
100003c60:     	b	0x100003c68 <_silex_function_3+0x2ac>
100003c64:     	mov	w3, #0x1                ; =1
100003c68:     	mov	w10, #0xa               ; =10
100003c6c:     	sdiv	x4, x9, x10
100003c70:     	msub	x5, x4, x10, x9
100003c74:     	mov	w6, #0x30               ; =48
100003c78:     	subs	x6, x6, x5
100003c7c:     	sub	x11, x11, #0x1
100003c80:     	strb	w6, [x11]
100003c84:     	add	x12, x12, #0x1
100003c88:     	mov	x9, x4
100003c8c:     	cbnz	x9, 0x100003c68 <_silex_function_3+0x2ac>
100003c90:     	cbz	w3, 0x100003ca4 <_silex_function_3+0x2e8>
100003c94:     	sub	x11, x11, #0x1
100003c98:     	mov	w10, #0x2d              ; =45
100003c9c:     	strb	w10, [x11]
100003ca0:     	add	x12, x12, #0x1
100003ca4:     	mov	w0, #0x2                ; =2
100003ca8:     	mov	x1, x11
100003cac:     	mov	x2, x12
100003cb0:     	mov	w16, #0x4               ; =4
100003cb4:     	svc	#0x80
100003cb8:     	add	sp, sp, #0x20
100003cbc:     	mov	w0, #0x2                ; =2
100003cc0:     	adrp	x1, 0x100009000 <_main+0x1b80>
100003cc4:     	add	x1, x1, #0x178
100003cc8:     	mov	x2, #0x1c               ; =28
100003ccc:     	movk	x2, #0x0, lsl #16
100003cd0:     	movk	x2, #0x0, lsl #32
100003cd4:     	movk	x2, #0x0, lsl #48
100003cd8:     	mov	w16, #0x4               ; =4
100003cdc:     	svc	#0x80
100003ce0:     	ldr	x9, [sp, #0xc0]
100003ce4:     	sub	sp, sp, #0x20
100003ce8:     	add	x11, sp, #0x1f
100003cec:     	mov	w10, #0xa               ; =10
100003cf0:     	strb	w10, [x11]
100003cf4:     	mov	w12, #0x1               ; =1
100003cf8:     	cbnz	x9, 0x100003d10 <_silex_function_3+0x354>
100003cfc:     	sub	x11, x11, #0x1
100003d00:     	mov	w10, #0x30              ; =48
100003d04:     	strb	w10, [x11]
100003d08:     	add	x12, x12, #0x1
100003d0c:     	b	0x100003d64 <_silex_function_3+0x3a8>
100003d10:     	mov	w3, #0x0                ; =0
100003d14:     	cmp	x9, xzr
100003d18:     	b.lt	0x100003d24 <_silex_function_3+0x368>
100003d1c:     	negs	x9, x9
100003d20:     	b	0x100003d28 <_silex_function_3+0x36c>
100003d24:     	mov	w3, #0x1                ; =1
100003d28:     	mov	w10, #0xa               ; =10
100003d2c:     	sdiv	x4, x9, x10
100003d30:     	msub	x5, x4, x10, x9
100003d34:     	mov	w6, #0x30               ; =48
100003d38:     	subs	x6, x6, x5
100003d3c:     	sub	x11, x11, #0x1
100003d40:     	strb	w6, [x11]
100003d44:     	add	x12, x12, #0x1
100003d48:     	mov	x9, x4
100003d4c:     	cbnz	x9, 0x100003d28 <_silex_function_3+0x36c>
100003d50:     	cbz	w3, 0x100003d64 <_silex_function_3+0x3a8>
100003d54:     	sub	x11, x11, #0x1
100003d58:     	mov	w10, #0x2d              ; =45
100003d5c:     	strb	w10, [x11]
100003d60:     	add	x12, x12, #0x1
100003d64:     	mov	w0, #0x2                ; =2
100003d68:     	mov	x1, x11
100003d6c:     	mov	x2, x12
100003d70:     	mov	w16, #0x4               ; =4
100003d74:     	svc	#0x80
100003d78:     	add	sp, sp, #0x20
100003d7c:     	mov	w8, #0x3                ; =3
100003d80:     	b	0x100003fc0 <_silex_function_3+0x604>
100003d84:     	ldr	x10, [sp, #0xc0]
100003d88:     	ldr	x9, [x10]
100003d8c:     	mov	x11, #0x0               ; =0
100003d90:     	movk	x11, #0x0, lsl #16
100003d94:     	movk	x11, #0x0, lsl #32
100003d98:     	movk	x11, #0x8000, lsl #48
100003d9c:     	and	x9, x9, x11
100003da0:     	cbz	x9, 0x100003dd0 <_silex_function_3+0x414>
100003da4:     	sub	x10, x10, #0x10
100003da8:     	ldaxr	x9, [x10]
100003dac:     	cbz	x9, 0x100003dd0 <_silex_function_3+0x414>
100003db0:     	sub	x9, x9, #0x1
100003db4:     	stlxr	w11, x9, [x10]
100003db8:     	cbnz	w11, 0x100003da8 <_silex_function_3+0x3ec>
100003dbc:     	cbnz	x9, 0x100003dd0 <_silex_function_3+0x414>
100003dc0:     	ldr	x1, [x10, #0x8]
100003dc4:     	mov	x0, x10
100003dc8:     	mov	w16, #0x49              ; =73
100003dcc:     	svc	#0x80
100003dd0:     	ldr	x9, [sp, #0xb8]
100003dd4:     	str	x9, [sp, #0x148]
100003dd8:     	mov	x16, x9
100003ddc:     	b	0x100003b80 <_silex_function_3+0x1c4>
100003de0:     	ldr	x10, [sp, #0x30]
100003de4:     	add	x14, x10, #0x8
100003de8:     	ldaxr	x9, [x14]
100003dec:     	cbz	x9, 0x100003e44 <_silex_function_3+0x488>
100003df0:     	sub	x9, x9, #0x1
100003df4:     	stlxr	w11, x9, [x14]
100003df8:     	cbnz	w11, 0x100003de8 <_silex_function_3+0x42c>
100003dfc:     	ldr	x11, [x10, #0x10]
100003e00:     	add	x9, x9, x11
100003e04:     	cbnz	x9, 0x100003e44 <_silex_function_3+0x488>
100003e08:     	add	x14, x10, #0x20
100003e0c:     	ldaxr	x9, [x14]
100003e10:     	mov	x11, #0x2               ; =2
100003e14:     	cmp	x9, x11
100003e18:     	b.eq	0x100003e0c <_silex_function_3+0x450>
100003e1c:     	mov	x11, #0x1               ; =1
100003e20:     	cmp	x9, x11
100003e24:     	b.eq	0x100003e44 <_silex_function_3+0x488>
100003e28:     	mov	x9, #0x1                ; =1
100003e2c:     	stlxr	w11, x9, [x14]
100003e30:     	cbnz	w11, 0x100003e0c <_silex_function_3+0x450>
100003e34:     	ldr	x1, [x10, #0x18]
100003e38:     	mov	x0, x10
100003e3c:     	mov	w16, #0x49              ; =73
100003e40:     	svc	#0x80
100003e44:     	ldr	x14, [sp]
100003e48:     	ldr	x9, [sp, #0x68]
100003e4c:     	str	x9, [x14]
100003e50:     	ldr	x9, [sp, #0x70]
100003e54:     	str	x9, [x14, #0x8]
100003e58:     	ldr	x9, [sp, #0x78]
100003e5c:     	str	x9, [x14, #0x10]
100003e60:     	ldr	x9, [sp, #0x80]
100003e64:     	str	x9, [x14, #0x18]
100003e68:     	ldr	x9, [sp, #0x88]
100003e6c:     	str	x9, [x14, #0x20]
100003e70:     	ldr	x9, [sp, #0x90]
100003e74:     	str	x9, [x14, #0x28]
100003e78:     	mov	x0, #0x0                ; =0
100003e7c:     	mov	w8, #0x0                ; =0
100003e80:     	b	0x100003fc0 <_silex_function_3+0x604>
100003e84:     	adrp	x9, 0x100009000 <_main+0x1b80>
100003e88:     	add	x9, x9, #0x538
100003e8c:     	str	x9, [sp, #0xc8]
100003e90:     	mov	w9, #0x0                ; =0
100003e94:     	str	x9, [sp, #0xd0]
100003e98:     	str	x9, [sp, #0xd8]
100003e9c:     	adrp	x9, 0x100009000 <_main+0x1b80>
100003ea0:     	add	x9, x9, #0x558
100003ea4:     	str	x9, [sp, #0xe0]
100003ea8:     	ldr	x10, [sp, #0xc8]
100003eac:     	ldr	x9, [x10]
100003eb0:     	mov	x11, #0x0               ; =0
100003eb4:     	movk	x11, #0x0, lsl #16
100003eb8:     	movk	x11, #0x0, lsl #32
100003ebc:     	movk	x11, #0x8000, lsl #48
100003ec0:     	and	x9, x9, x11
100003ec4:     	cbz	x9, 0x100003edc <_silex_function_3+0x520>
100003ec8:     	sub	x10, x10, #0x10
100003ecc:     	ldaxr	x9, [x10]
100003ed0:     	add	x9, x9, #0x1
100003ed4:     	stlxr	w11, x9, [x10]
100003ed8:     	cbnz	w11, 0x100003ecc <_silex_function_3+0x510>
100003edc:     	ldr	x10, [sp, #0xe0]
100003ee0:     	ldr	x9, [x10]
100003ee4:     	mov	x11, #0x0               ; =0
100003ee8:     	movk	x11, #0x0, lsl #16
100003eec:     	movk	x11, #0x0, lsl #32
100003ef0:     	movk	x11, #0x8000, lsl #48
100003ef4:     	and	x9, x9, x11
100003ef8:     	cbz	x9, 0x100003f10 <_silex_function_3+0x554>
100003efc:     	sub	x10, x10, #0x10
100003f00:     	ldaxr	x9, [x10]
100003f04:     	add	x9, x9, #0x1
100003f08:     	stlxr	w11, x9, [x10]
100003f0c:     	cbnz	w11, 0x100003f00 <_silex_function_3+0x544>
100003f10:     	ldr	x0, [sp, #0xc8]
100003f14:     	ldr	x1, [sp, #0xd0]
100003f18:     	ldr	x2, [sp, #0xd8]
100003f1c:     	ldr	x3, [sp, #0xe0]
100003f20:     	add	x15, sp, #0xe8
100003f24:     	bl	0x100003fdc <_silex_function_4>
100003f28:     	cbnz	w8, 0x100003fc0 <_silex_function_3+0x604>
100003f2c:     	mov	x9, #0x1                ; =1
100003f30:     	str	x9, [sp, #0x110]
100003f34:     	mov	w9, #0x0                ; =0
100003f38:     	str	x9, [sp, #0x118]
100003f3c:     	mov	w9, #0x0                ; =0
100003f40:     	str	x9, [sp, #0x120]
100003f44:     	mov	w9, #0x0                ; =0
100003f48:     	str	x9, [sp, #0x128]
100003f4c:     	mov	w9, #0x0                ; =0
100003f50:     	str	x9, [sp, #0x130]
100003f54:     	mov	w9, #0x0                ; =0
100003f58:     	str	x9, [sp, #0x138]
100003f5c:     	ldr	x9, [sp, #0xe8]
100003f60:     	str	x9, [sp, #0x118]
100003f64:     	ldr	x9, [sp, #0xf0]
100003f68:     	str	x9, [sp, #0x120]
100003f6c:     	ldr	x9, [sp, #0xf8]
100003f70:     	str	x9, [sp, #0x128]
100003f74:     	ldr	x9, [sp, #0x100]
100003f78:     	str	x9, [sp, #0x130]
100003f7c:     	ldr	x9, [sp, #0x108]
100003f80:     	str	x9, [sp, #0x138]
100003f84:     	ldr	x14, [sp]
100003f88:     	ldr	x9, [sp, #0x110]
100003f8c:     	str	x9, [x14]
100003f90:     	ldr	x9, [sp, #0x118]
100003f94:     	str	x9, [x14, #0x8]
100003f98:     	ldr	x9, [sp, #0x120]
100003f9c:     	str	x9, [x14, #0x10]
100003fa0:     	ldr	x9, [sp, #0x128]
100003fa4:     	str	x9, [x14, #0x18]
100003fa8:     	ldr	x9, [sp, #0x130]
100003fac:     	str	x9, [x14, #0x20]
100003fb0:     	ldr	x9, [sp, #0x138]
100003fb4:     	str	x9, [x14, #0x28]
100003fb8:     	mov	x0, #0x0                ; =0
100003fbc:     	mov	w8, #0x0                ; =0
100003fc0:     	add	sp, sp, #0x150
100003fc4:     	ldp	x29, x30, [sp], #0x10
100003fc8:     	ret
100003fcc:     	mov	w8, #0x1                ; =1
100003fd0:     	b	0x100003fc0 <_silex_function_3+0x604>
100003fd4:     	mov	w8, #0x2                ; =2
100003fd8:     	b	0x100003fc0 <_silex_function_3+0x604>

0000000100003fdc <_silex_function_4>:
100003fdc:     	stp	x29, x30, [sp, #-0x10]!
100003fe0:     	mov	x29, sp
100003fe4:     	sub	sp, sp, #0xa0
100003fe8:     	str	x15, [sp, #0x20]
100003fec:     	str	x0, [sp]
100003ff0:     	str	x1, [sp, #0x8]
100003ff4:     	str	x2, [sp, #0x10]
100003ff8:     	str	x3, [sp, #0x18]
100003ffc:     	mov	x9, #0x1e               ; =30
100004000:     	str	x9, [sp, #0x28]
100004004:     	ldr	x10, [sp]
100004008:     	ldr	x9, [x10]
10000400c:     	mov	x11, #0x0               ; =0
100004010:     	movk	x11, #0x0, lsl #16
100004014:     	movk	x11, #0x0, lsl #32
100004018:     	movk	x11, #0x8000, lsl #48
10000401c:     	and	x9, x9, x11
100004020:     	cbz	x9, 0x100004038 <_silex_function_4+0x5c>
100004024:     	sub	x10, x10, #0x10
100004028:     	ldaxr	x9, [x10]
10000402c:     	add	x9, x9, #0x1
100004030:     	stlxr	w11, x9, [x10]
100004034:     	cbnz	w11, 0x100004028 <_silex_function_4+0x4c>
100004038:     	mov	w9, #0x0                ; =0
10000403c:     	str	x9, [sp, #0x30]
100004040:     	str	x9, [sp, #0x38]
100004044:     	ldr	x9, [sp, #0x8]
100004048:     	ldr	x10, [sp, #0x30]
10000404c:     	cmp	x9, x10
100004050:     	mov	w11, #0x0               ; =0
100004054:     	b.ne	0x10000405c <_silex_function_4+0x80>
100004058:     	mov	w11, #0x1               ; =1
10000405c:     	str	x11, [sp, #0x40]
100004060:     	ldr	x9, [sp, #0x40]
100004064:     	cbz	w9, 0x100004104 <_silex_function_4+0x128>
100004068:     	ldr	x9, [sp, #0x8]
10000406c:     	mov	x10, #0x1               ; =1
100004070:     	cmp	x9, x10
100004074:     	b.ne	0x1000040f8 <_silex_function_4+0x11c>
100004078:     	ldr	x9, [sp, #0x10]
10000407c:     	ldr	x10, [sp, #0x38]
100004080:     	ldr	x11, [x9]
100004084:     	mov	x14, #0xffff            ; =65535
100004088:     	movk	x14, #0xffff, lsl #16
10000408c:     	movk	x14, #0xffff, lsl #32
100004090:     	movk	x14, #0x7fff, lsl #48
100004094:     	and	x11, x11, x14
100004098:     	ldr	x12, [x10]
10000409c:     	mov	x14, #0xffff            ; =65535
1000040a0:     	movk	x14, #0xffff, lsl #16
1000040a4:     	movk	x14, #0xffff, lsl #32
1000040a8:     	movk	x14, #0x7fff, lsl #48
1000040ac:     	and	x12, x12, x14
1000040b0:     	mov	w13, #0x0               ; =0
1000040b4:     	cmp	x11, x12
1000040b8:     	b.ne	0x1000040ec <_silex_function_4+0x110>
1000040bc:     	add	x9, x9, #0x8
1000040c0:     	add	x10, x10, #0x8
1000040c4:     	cbz	x11, 0x1000040e8 <_silex_function_4+0x10c>
1000040c8:     	ldrb	w14, [x9]
1000040cc:     	ldrb	w15, [x10]
1000040d0:     	cmp	x14, x15
1000040d4:     	b.ne	0x1000040ec <_silex_function_4+0x110>
1000040d8:     	add	x9, x9, #0x1
1000040dc:     	add	x10, x10, #0x1
1000040e0:     	sub	x11, x11, #0x1
1000040e4:     	cbnz	x11, 0x1000040c8 <_silex_function_4+0xec>
1000040e8:     	mov	w13, #0x1               ; =1
1000040ec:     	str	x13, [sp, #0x40]
1000040f0:     	ldr	x9, [sp, #0x40]
1000040f4:     	cbz	w9, 0x100004104 <_silex_function_4+0x128>
1000040f8:     	mov	w9, #0x0                ; =0
1000040fc:     	str	x9, [sp, #0x40]
100004100:     	b	0x10000410c <_silex_function_4+0x130>
100004104:     	mov	w9, #0x1                ; =1
100004108:     	str	x9, [sp, #0x40]
10000410c:     	ldr	x9, [sp, #0x40]
100004110:     	cbz	w9, 0x100004150 <_silex_function_4+0x174>
100004114:     	ldr	x9, [sp, #0x10]
100004118:     	str	x9, [sp, #0x48]
10000411c:     	ldr	x10, [sp, #0x48]
100004120:     	ldr	x9, [x10]
100004124:     	mov	x11, #0x0               ; =0
100004128:     	movk	x11, #0x0, lsl #16
10000412c:     	movk	x11, #0x0, lsl #32
100004130:     	movk	x11, #0x8000, lsl #48
100004134:     	and	x9, x9, x11
100004138:     	cbz	x9, 0x100004150 <_silex_function_4+0x174>
10000413c:     	sub	x10, x10, #0x10
100004140:     	ldaxr	x9, [x10]
100004144:     	add	x9, x9, #0x1
100004148:     	stlxr	w11, x9, [x10]
10000414c:     	cbnz	w11, 0x100004140 <_silex_function_4+0x164>
100004150:     	ldr	x10, [sp, #0x18]
100004154:     	ldr	x9, [x10]
100004158:     	mov	x11, #0x0               ; =0
10000415c:     	movk	x11, #0x0, lsl #16
100004160:     	movk	x11, #0x0, lsl #32
100004164:     	movk	x11, #0x8000, lsl #48
100004168:     	and	x9, x9, x11
10000416c:     	cbz	x9, 0x100004184 <_silex_function_4+0x1a8>
100004170:     	sub	x10, x10, #0x10
100004174:     	ldaxr	x9, [x10]
100004178:     	add	x9, x9, #0x1
10000417c:     	stlxr	w11, x9, [x10]
100004180:     	cbnz	w11, 0x100004174 <_silex_function_4+0x198>
100004184:     	ldr	x9, [sp, #0x28]
100004188:     	str	x9, [sp, #0x50]
10000418c:     	ldr	x9, [sp]
100004190:     	str	x9, [sp, #0x58]
100004194:     	ldr	x9, [sp, #0x8]
100004198:     	str	x9, [sp, #0x60]
10000419c:     	ldr	x9, [sp, #0x10]
1000041a0:     	str	x9, [sp, #0x68]
1000041a4:     	ldr	x9, [sp, #0x18]
1000041a8:     	str	x9, [sp, #0x70]
1000041ac:     	ldr	x10, [sp, #0x18]
1000041b0:     	ldr	x9, [x10]
1000041b4:     	mov	x11, #0x0               ; =0
1000041b8:     	movk	x11, #0x0, lsl #16
1000041bc:     	movk	x11, #0x0, lsl #32
1000041c0:     	movk	x11, #0x8000, lsl #48
1000041c4:     	and	x9, x9, x11
1000041c8:     	cbz	x9, 0x1000041f8 <_silex_function_4+0x21c>
1000041cc:     	sub	x10, x10, #0x10
1000041d0:     	ldaxr	x9, [x10]
1000041d4:     	cbz	x9, 0x1000041f8 <_silex_function_4+0x21c>
1000041d8:     	sub	x9, x9, #0x1
1000041dc:     	stlxr	w11, x9, [x10]
1000041e0:     	cbnz	w11, 0x1000041d0 <_silex_function_4+0x1f4>
1000041e4:     	cbnz	x9, 0x1000041f8 <_silex_function_4+0x21c>
1000041e8:     	ldr	x1, [x10, #0x8]
1000041ec:     	mov	x0, x10
1000041f0:     	mov	w16, #0x49              ; =73
1000041f4:     	svc	#0x80
1000041f8:     	mov	w9, #0x0                ; =0
1000041fc:     	str	x9, [sp, #0x78]
100004200:     	str	x9, [sp, #0x80]
100004204:     	ldr	x9, [sp, #0x8]
100004208:     	ldr	x10, [sp, #0x78]
10000420c:     	cmp	x9, x10
100004210:     	mov	w11, #0x0               ; =0
100004214:     	b.ne	0x10000421c <_silex_function_4+0x240>
100004218:     	mov	w11, #0x1               ; =1
10000421c:     	str	x11, [sp, #0x88]
100004220:     	ldr	x9, [sp, #0x88]
100004224:     	cbz	w9, 0x1000042c4 <_silex_function_4+0x2e8>
100004228:     	ldr	x9, [sp, #0x8]
10000422c:     	mov	x10, #0x1               ; =1
100004230:     	cmp	x9, x10
100004234:     	b.ne	0x1000042b8 <_silex_function_4+0x2dc>
100004238:     	ldr	x9, [sp, #0x10]
10000423c:     	ldr	x10, [sp, #0x80]
100004240:     	ldr	x11, [x9]
100004244:     	mov	x14, #0xffff            ; =65535
100004248:     	movk	x14, #0xffff, lsl #16
10000424c:     	movk	x14, #0xffff, lsl #32
100004250:     	movk	x14, #0x7fff, lsl #48
100004254:     	and	x11, x11, x14
100004258:     	ldr	x12, [x10]
10000425c:     	mov	x14, #0xffff            ; =65535
100004260:     	movk	x14, #0xffff, lsl #16
100004264:     	movk	x14, #0xffff, lsl #32
100004268:     	movk	x14, #0x7fff, lsl #48
10000426c:     	and	x12, x12, x14
100004270:     	mov	w13, #0x0               ; =0
100004274:     	cmp	x11, x12
100004278:     	b.ne	0x1000042ac <_silex_function_4+0x2d0>
10000427c:     	add	x9, x9, #0x8
100004280:     	add	x10, x10, #0x8
100004284:     	cbz	x11, 0x1000042a8 <_silex_function_4+0x2cc>
100004288:     	ldrb	w14, [x9]
10000428c:     	ldrb	w15, [x10]
100004290:     	cmp	x14, x15
100004294:     	b.ne	0x1000042ac <_silex_function_4+0x2d0>
100004298:     	add	x9, x9, #0x1
10000429c:     	add	x10, x10, #0x1
1000042a0:     	sub	x11, x11, #0x1
1000042a4:     	cbnz	x11, 0x100004288 <_silex_function_4+0x2ac>
1000042a8:     	mov	w13, #0x1               ; =1
1000042ac:     	str	x13, [sp, #0x88]
1000042b0:     	ldr	x9, [sp, #0x88]
1000042b4:     	cbz	w9, 0x1000042c4 <_silex_function_4+0x2e8>
1000042b8:     	mov	w9, #0x0                ; =0
1000042bc:     	str	x9, [sp, #0x88]
1000042c0:     	b	0x1000042cc <_silex_function_4+0x2f0>
1000042c4:     	mov	w9, #0x1                ; =1
1000042c8:     	str	x9, [sp, #0x88]
1000042cc:     	ldr	x9, [sp, #0x88]
1000042d0:     	cbz	w9, 0x100004328 <_silex_function_4+0x34c>
1000042d4:     	ldr	x9, [sp, #0x10]
1000042d8:     	str	x9, [sp, #0x90]
1000042dc:     	ldr	x10, [sp, #0x90]
1000042e0:     	ldr	x9, [x10]
1000042e4:     	mov	x11, #0x0               ; =0
1000042e8:     	movk	x11, #0x0, lsl #16
1000042ec:     	movk	x11, #0x0, lsl #32
1000042f0:     	movk	x11, #0x8000, lsl #48
1000042f4:     	and	x9, x9, x11
1000042f8:     	cbz	x9, 0x100004328 <_silex_function_4+0x34c>
1000042fc:     	sub	x10, x10, #0x10
100004300:     	ldaxr	x9, [x10]
100004304:     	cbz	x9, 0x100004328 <_silex_function_4+0x34c>
100004308:     	sub	x9, x9, #0x1
10000430c:     	stlxr	w11, x9, [x10]
100004310:     	cbnz	w11, 0x100004300 <_silex_function_4+0x324>
100004314:     	cbnz	x9, 0x100004328 <_silex_function_4+0x34c>
100004318:     	ldr	x1, [x10, #0x8]
10000431c:     	mov	x0, x10
100004320:     	mov	w16, #0x49              ; =73
100004324:     	svc	#0x80
100004328:     	ldr	x10, [sp]
10000432c:     	ldr	x9, [x10]
100004330:     	mov	x11, #0x0               ; =0
100004334:     	movk	x11, #0x0, lsl #16
100004338:     	movk	x11, #0x0, lsl #32
10000433c:     	movk	x11, #0x8000, lsl #48
100004340:     	and	x9, x9, x11
100004344:     	cbz	x9, 0x100004374 <_silex_function_4+0x398>
100004348:     	sub	x10, x10, #0x10
10000434c:     	ldaxr	x9, [x10]
100004350:     	cbz	x9, 0x100004374 <_silex_function_4+0x398>
100004354:     	sub	x9, x9, #0x1
100004358:     	stlxr	w11, x9, [x10]
10000435c:     	cbnz	w11, 0x10000434c <_silex_function_4+0x370>
100004360:     	cbnz	x9, 0x100004374 <_silex_function_4+0x398>
100004364:     	ldr	x1, [x10, #0x8]
100004368:     	mov	x0, x10
10000436c:     	mov	w16, #0x49              ; =73
100004370:     	svc	#0x80
100004374:     	ldr	x14, [sp, #0x20]
100004378:     	ldr	x9, [sp, #0x50]
10000437c:     	str	x9, [x14]
100004380:     	ldr	x9, [sp, #0x58]
100004384:     	str	x9, [x14, #0x8]
100004388:     	ldr	x9, [sp, #0x60]
10000438c:     	str	x9, [x14, #0x10]
100004390:     	ldr	x9, [sp, #0x68]
100004394:     	str	x9, [x14, #0x18]
100004398:     	ldr	x9, [sp, #0x70]
10000439c:     	str	x9, [x14, #0x20]
1000043a0:     	mov	x0, #0x0                ; =0
1000043a4:     	mov	w8, #0x0                ; =0
1000043a8:     	add	sp, sp, #0xa0
1000043ac:     	ldp	x29, x30, [sp], #0x10
1000043b0:     	ret
1000043b4:     	mov	w8, #0x1                ; =1
1000043b8:     	b	0x1000043a8 <_silex_function_4+0x3cc>
1000043bc:     	mov	w8, #0x2                ; =2
1000043c0:     	b	0x1000043a8 <_silex_function_4+0x3cc>

00000001000043c4 <_silex_function_5>:
1000043c4:     	stp	x29, x30, [sp, #-0x10]!
1000043c8:     	mov	x29, sp
1000043cc:     	sub	sp, sp, #0x310
1000043d0:     	str	x15, [sp]
1000043d4:     	mov	x1, #0x4000             ; =16384
1000043d8:     	mov	w0, #0x0                ; =0
1000043dc:     	mov	w2, #0x3                ; =3
1000043e0:     	mov	w3, #0x1002             ; =4098
1000043e4:     	mov	x4, #0xffff             ; =65535
1000043e8:     	movk	x4, #0xffff, lsl #16
1000043ec:     	movk	x4, #0xffff, lsl #32
1000043f0:     	movk	x4, #0xffff, lsl #48
1000043f4:     	mov	w5, #0x0                ; =0
1000043f8:     	mov	w16, #0xc5              ; =197
1000043fc:     	svc	#0x80
100004400:     	b.hs	0x10000442c <_silex_function_5+0x68>
100004404:     	mov	x15, x0
100004408:     	mov	x9, #0x0                ; =0
10000440c:     	str	x9, [x15]
100004410:     	mov	x9, #0x1                ; =1
100004414:     	str	x9, [x15, #0x8]
100004418:     	mov	x9, #0x4000             ; =16384
10000441c:     	str	x9, [x15, #0x18]
100004420:     	add	x14, x15, #0x28
100004424:     	str	x15, [sp, #0x10]
100004428:     	b	0x100004434 <_silex_function_5+0x70>
10000442c:     	mov	w8, #0x3                ; =3
100004430:     	b	0x1000055c8 <_silex_function_5+0x1204>
100004434:     	ldr	x9, [sp, #0x10]
100004438:     	str	x9, [sp, #0x8]
10000443c:     	mov	x16, x9
100004440:     	bl	0x10000a7f4 <dyld_stub_binder+0x10000a7f4>
100004444:     	nop
100004448:     	nop
10000444c:     	mov	w8, #0x0                ; =0
100004450:     	str	x0, [sp, #0x18]
100004454:     	ldr	x9, [sp, #0x18]
100004458:     	str	x9, [sp, #0x20]
10000445c:     	mov	x16, x9
100004460:     	bl	0x10000a800 <dyld_stub_binder+0x10000a800>
100004464:     	nop
100004468:     	nop
10000446c:     	mov	w8, #0x0                ; =0
100004470:     	str	x0, [sp, #0x28]
100004474:     	ldr	x9, [sp, #0x28]
100004478:     	str	x9, [sp, #0x30]
10000447c:     	mov	x16, x9
100004480:     	movz	x9, #0x0, lsl #48
100004484:     	str	x9, [sp, #0x38]
100004488:     	mov	x17, x9
10000448c:     	ldr	x9, [sp, #0x20]
100004490:     	ldr	x10, [sp, #0x38]
100004494:     	cmp	x9, x10
100004498:     	mov	w11, #0x0               ; =0
10000449c:     	b.ne	0x1000044a4 <_silex_function_5+0xe0>
1000044a0:     	mov	w11, #0x1               ; =1
1000044a4:     	str	x11, [sp, #0x40]
1000044a8:     	mov	x16, x11
1000044ac:     	ldr	x9, [sp, #0x40]
1000044b0:     	cbnz	w9, 0x1000044f0 <_silex_function_5+0x12c>
1000044b4:     	movz	x9, #0x0, lsl #48
1000044b8:     	str	x9, [sp, #0x50]
1000044bc:     	mov	x16, x9
1000044c0:     	ldr	x9, [sp, #0x30]
1000044c4:     	ldr	x10, [sp, #0x50]
1000044c8:     	cmp	x9, x10
1000044cc:     	mov	w11, #0x0               ; =0
1000044d0:     	b.ne	0x1000044d8 <_silex_function_5+0x114>
1000044d4:     	mov	w11, #0x1               ; =1
1000044d8:     	str	x11, [sp, #0x58]
1000044dc:     	mov	x17, x11
1000044e0:     	mov	x9, x17
1000044e4:     	str	x9, [sp, #0x48]
1000044e8:     	mov	x16, x9
1000044ec:     	b	0x1000044fc <_silex_function_5+0x138>
1000044f0:     	mov	w9, #0x1                ; =1
1000044f4:     	str	x9, [sp, #0x48]
1000044f8:     	mov	x16, x9
1000044fc:     	ldr	x9, [sp, #0x48]
100004500:     	cbz	w9, 0x100004988 <_silex_function_5+0x5c4>
100004504:     	ldr	x9, [sp, #0x8]
100004508:     	str	x9, [sp, #0x60]
10000450c:     	mov	x16, x9
100004510:     	mov	w9, #0x1                ; =1
100004514:     	str	x9, [sp, #0x68]
100004518:     	ldr	x9, [sp, #0x60]
10000451c:     	str	x9, [sp, #0x70]
100004520:     	mov	w9, #0x0                ; =0
100004524:     	str	x9, [sp, #0x78]
100004528:     	str	x9, [sp, #0x80]
10000452c:     	ldr	x9, [sp, #0x68]
100004530:     	ldr	x10, [sp, #0x78]
100004534:     	cmp	x9, x10
100004538:     	mov	w11, #0x0               ; =0
10000453c:     	b.ne	0x100004544 <_silex_function_5+0x180>
100004540:     	mov	w11, #0x1               ; =1
100004544:     	str	x11, [sp, #0x88]
100004548:     	ldr	x9, [sp, #0x88]
10000454c:     	cbz	w9, 0x100004590 <_silex_function_5+0x1cc>
100004550:     	ldr	x9, [sp, #0x68]
100004554:     	mov	x10, #0x1               ; =1
100004558:     	cmp	x9, x10
10000455c:     	b.ne	0x100004584 <_silex_function_5+0x1c0>
100004560:     	ldr	x9, [sp, #0x70]
100004564:     	ldr	x10, [sp, #0x80]
100004568:     	cmp	x9, x10
10000456c:     	mov	w11, #0x0               ; =0
100004570:     	b.ne	0x100004578 <_silex_function_5+0x1b4>
100004574:     	mov	w11, #0x1               ; =1
100004578:     	str	x11, [sp, #0x88]
10000457c:     	ldr	x9, [sp, #0x88]
100004580:     	cbz	w9, 0x100004590 <_silex_function_5+0x1cc>
100004584:     	mov	w9, #0x0                ; =0
100004588:     	str	x9, [sp, #0x88]
10000458c:     	b	0x100004598 <_silex_function_5+0x1d4>
100004590:     	mov	w9, #0x1                ; =1
100004594:     	str	x9, [sp, #0x88]
100004598:     	ldr	x9, [sp, #0x88]
10000459c:     	cbz	w9, 0x1000045e8 <_silex_function_5+0x224>
1000045a0:     	ldr	x9, [sp, #0x70]
1000045a4:     	str	x9, [sp, #0x90]
1000045a8:     	ldr	x10, [sp, #0x90]
1000045ac:     	add	x14, x10, #0x8
1000045b0:     	ldaxr	x9, [x14]
1000045b4:     	add	x9, x9, #0x1
1000045b8:     	stlxr	w11, x9, [x14]
1000045bc:     	cbnz	w11, 0x1000045b0 <_silex_function_5+0x1ec>
1000045c0:     	movz	x9, #0x0, lsl #48
1000045c4:     	str	x9, [sp, #0x98]
1000045c8:     	mov	x16, x9
1000045cc:     	ldr	x9, [sp, #0x90]
1000045d0:     	ldr	x10, [x9]
1000045d4:     	str	x10, [sp, #0xa0]
1000045d8:     	ldr	x9, [sp, #0x98]
1000045dc:     	str	x9, [sp, #0x2d0]
1000045e0:     	mov	x16, x9
1000045e4:     	b	0x100004610 <_silex_function_5+0x24c>
1000045e8:     	ldr	x9, [sp, #0x8]
1000045ec:     	str	x9, [sp, #0xc8]
1000045f0:     	mov	x16, x9
1000045f4:     	ldr	x9, [sp, #0xc8]
1000045f8:     	ldr	x10, [x9]
1000045fc:     	str	x10, [sp, #0xd0]
100004600:     	ldr	x9, [sp, #0xd0]
100004604:     	str	x9, [sp, #0x2d8]
100004608:     	mov	x16, x9
10000460c:     	b	0x1000046a4 <_silex_function_5+0x2e0>
100004610:     	ldr	x9, [sp, #0x2d0]
100004614:     	ldr	x10, [sp, #0xa0]
100004618:     	cmp	x9, x10
10000461c:     	mov	w11, #0x0               ; =0
100004620:     	b.ge	0x100004628 <_silex_function_5+0x264>
100004624:     	mov	w11, #0x1               ; =1
100004628:     	str	x11, [sp, #0xa8]
10000462c:     	mov	x16, x11
100004630:     	ldr	x9, [sp, #0xa8]
100004634:     	cbz	w9, 0x1000045e8 <_silex_function_5+0x224>
100004638:     	ldr	x10, [sp, #0x90]
10000463c:     	add	x10, x10, #0x28
100004640:     	ldr	x9, [sp, #0x2d0]
100004644:     	add	x10, x10, x9, lsl #3
100004648:     	ldr	x12, [x10]
10000464c:     	str	x12, [sp, #0xb0]
100004650:     	ldr	x10, [sp, #0xb0]
100004654:     	ldr	x9, [x10]
100004658:     	mov	x11, #0x0               ; =0
10000465c:     	movk	x11, #0x0, lsl #16
100004660:     	movk	x11, #0x0, lsl #32
100004664:     	movk	x11, #0x8000, lsl #48
100004668:     	and	x9, x9, x11
10000466c:     	cbz	x9, 0x100004684 <_silex_function_5+0x2c0>
100004670:     	sub	x10, x10, #0x10
100004674:     	ldaxr	x9, [x10]
100004678:     	add	x9, x9, #0x1
10000467c:     	stlxr	w11, x9, [x10]
100004680:     	cbnz	w11, 0x100004674 <_silex_function_5+0x2b0>
100004684:     	ldr	x9, [sp, #0x2d0]
100004688:     	add	x11, x9, #0x1
10000468c:     	str	x11, [sp, #0xc0]
100004690:     	mov	x16, x11
100004694:     	mov	x9, x16
100004698:     	str	x9, [sp, #0x2d0]
10000469c:     	mov	x17, x9
1000046a0:     	b	0x100004610 <_silex_function_5+0x24c>
1000046a4:     	movz	x9, #0x0, lsl #48
1000046a8:     	str	x9, [sp, #0xd8]
1000046ac:     	mov	x16, x9
1000046b0:     	ldr	x9, [sp, #0x2d8]
1000046b4:     	ldr	x10, [sp, #0xd8]
1000046b8:     	cmp	x9, x10
1000046bc:     	mov	w11, #0x0               ; =0
1000046c0:     	b.eq	0x1000046c8 <_silex_function_5+0x304>
1000046c4:     	mov	w11, #0x1               ; =1
1000046c8:     	str	x11, [sp, #0xe0]
1000046cc:     	mov	x17, x11
1000046d0:     	ldr	x9, [sp, #0xe0]
1000046d4:     	cbz	w9, 0x100004904 <_silex_function_5+0x540>
1000046d8:     	ldr	x9, [sp, #0x2d8]
1000046dc:     	sub	x11, x9, #0x1
1000046e0:     	str	x11, [sp, #0xf0]
1000046e4:     	mov	x16, x11
1000046e8:     	ldr	x10, [sp, #0xc8]
1000046ec:     	ldr	x13, [x10]
1000046f0:     	ldr	x9, [sp, #0xf0]
1000046f4:     	cmp	x9, xzr
1000046f8:     	b.ge	0x100004700 <_silex_function_5+0x33c>
1000046fc:     	add	x9, x9, x13
100004700:     	cmp	x9, xzr
100004704:     	b.lt	0x100004724 <_silex_function_5+0x360>
100004708:     	cmp	x9, x13
10000470c:     	b.ge	0x100004724 <_silex_function_5+0x360>
100004710:     	add	x10, x10, #0x28
100004714:     	add	x10, x10, x9, lsl #3
100004718:     	ldr	x12, [x10]
10000471c:     	str	x12, [sp, #0xf8]
100004720:     	b	0x1000048a8 <_silex_function_5+0x4e4>
100004724:     	str	x13, [sp, #0xf8]
100004728:     	mov	w0, #0x2                ; =2
10000472c:     	adrp	x1, 0x100009000 <_main+0x1b80>
100004730:     	add	x1, x1, #0x1c8
100004734:     	mov	x2, #0x9e               ; =158
100004738:     	movk	x2, #0x0, lsl #16
10000473c:     	movk	x2, #0x0, lsl #32
100004740:     	movk	x2, #0x0, lsl #48
100004744:     	mov	w16, #0x4               ; =4
100004748:     	svc	#0x80
10000474c:     	ldr	x9, [sp, #0xf0]
100004750:     	sub	sp, sp, #0x20
100004754:     	add	x11, sp, #0x20
100004758:     	mov	w12, #0x0               ; =0
10000475c:     	cbnz	x9, 0x100004774 <_silex_function_5+0x3b0>
100004760:     	sub	x11, x11, #0x1
100004764:     	mov	w10, #0x30              ; =48
100004768:     	strb	w10, [x11]
10000476c:     	add	x12, x12, #0x1
100004770:     	b	0x1000047c8 <_silex_function_5+0x404>
100004774:     	mov	w3, #0x0                ; =0
100004778:     	cmp	x9, xzr
10000477c:     	b.lt	0x100004788 <_silex_function_5+0x3c4>
100004780:     	negs	x9, x9
100004784:     	b	0x10000478c <_silex_function_5+0x3c8>
100004788:     	mov	w3, #0x1                ; =1
10000478c:     	mov	w10, #0xa               ; =10
100004790:     	sdiv	x4, x9, x10
100004794:     	msub	x5, x4, x10, x9
100004798:     	mov	w6, #0x30               ; =48
10000479c:     	subs	x6, x6, x5
1000047a0:     	sub	x11, x11, #0x1
1000047a4:     	strb	w6, [x11]
1000047a8:     	add	x12, x12, #0x1
1000047ac:     	mov	x9, x4
1000047b0:     	cbnz	x9, 0x10000478c <_silex_function_5+0x3c8>
1000047b4:     	cbz	w3, 0x1000047c8 <_silex_function_5+0x404>
1000047b8:     	sub	x11, x11, #0x1
1000047bc:     	mov	w10, #0x2d              ; =45
1000047c0:     	strb	w10, [x11]
1000047c4:     	add	x12, x12, #0x1
1000047c8:     	mov	w0, #0x2                ; =2
1000047cc:     	mov	x1, x11
1000047d0:     	mov	x2, x12
1000047d4:     	mov	w16, #0x4               ; =4
1000047d8:     	svc	#0x80
1000047dc:     	add	sp, sp, #0x20
1000047e0:     	mov	w0, #0x2                ; =2
1000047e4:     	adrp	x1, 0x100009000 <_main+0x1b80>
1000047e8:     	add	x1, x1, #0x178
1000047ec:     	mov	x2, #0x1c               ; =28
1000047f0:     	movk	x2, #0x0, lsl #16
1000047f4:     	movk	x2, #0x0, lsl #32
1000047f8:     	movk	x2, #0x0, lsl #48
1000047fc:     	mov	w16, #0x4               ; =4
100004800:     	svc	#0x80
100004804:     	ldr	x9, [sp, #0xf8]
100004808:     	sub	sp, sp, #0x20
10000480c:     	add	x11, sp, #0x1f
100004810:     	mov	w10, #0xa               ; =10
100004814:     	strb	w10, [x11]
100004818:     	mov	w12, #0x1               ; =1
10000481c:     	cbnz	x9, 0x100004834 <_silex_function_5+0x470>
100004820:     	sub	x11, x11, #0x1
100004824:     	mov	w10, #0x30              ; =48
100004828:     	strb	w10, [x11]
10000482c:     	add	x12, x12, #0x1
100004830:     	b	0x100004888 <_silex_function_5+0x4c4>
100004834:     	mov	w3, #0x0                ; =0
100004838:     	cmp	x9, xzr
10000483c:     	b.lt	0x100004848 <_silex_function_5+0x484>
100004840:     	negs	x9, x9
100004844:     	b	0x10000484c <_silex_function_5+0x488>
100004848:     	mov	w3, #0x1                ; =1
10000484c:     	mov	w10, #0xa               ; =10
100004850:     	sdiv	x4, x9, x10
100004854:     	msub	x5, x4, x10, x9
100004858:     	mov	w6, #0x30               ; =48
10000485c:     	subs	x6, x6, x5
100004860:     	sub	x11, x11, #0x1
100004864:     	strb	w6, [x11]
100004868:     	add	x12, x12, #0x1
10000486c:     	mov	x9, x4
100004870:     	cbnz	x9, 0x10000484c <_silex_function_5+0x488>
100004874:     	cbz	w3, 0x100004888 <_silex_function_5+0x4c4>
100004878:     	sub	x11, x11, #0x1
10000487c:     	mov	w10, #0x2d              ; =45
100004880:     	strb	w10, [x11]
100004884:     	add	x12, x12, #0x1
100004888:     	mov	w0, #0x2                ; =2
10000488c:     	mov	x1, x11
100004890:     	mov	x2, x12
100004894:     	mov	w16, #0x4               ; =4
100004898:     	svc	#0x80
10000489c:     	add	sp, sp, #0x20
1000048a0:     	mov	w8, #0x3                ; =3
1000048a4:     	b	0x1000055c8 <_silex_function_5+0x1204>
1000048a8:     	ldr	x10, [sp, #0xf8]
1000048ac:     	ldr	x9, [x10]
1000048b0:     	mov	x11, #0x0               ; =0
1000048b4:     	movk	x11, #0x0, lsl #16
1000048b8:     	movk	x11, #0x0, lsl #32
1000048bc:     	movk	x11, #0x8000, lsl #48
1000048c0:     	and	x9, x9, x11
1000048c4:     	cbz	x9, 0x1000048f4 <_silex_function_5+0x530>
1000048c8:     	sub	x10, x10, #0x10
1000048cc:     	ldaxr	x9, [x10]
1000048d0:     	cbz	x9, 0x1000048f4 <_silex_function_5+0x530>
1000048d4:     	sub	x9, x9, #0x1
1000048d8:     	stlxr	w11, x9, [x10]
1000048dc:     	cbnz	w11, 0x1000048cc <_silex_function_5+0x508>
1000048e0:     	cbnz	x9, 0x1000048f4 <_silex_function_5+0x530>
1000048e4:     	ldr	x1, [x10, #0x8]
1000048e8:     	mov	x0, x10
1000048ec:     	mov	w16, #0x49              ; =73
1000048f0:     	svc	#0x80
1000048f4:     	ldr	x9, [sp, #0xf0]
1000048f8:     	str	x9, [sp, #0x2d8]
1000048fc:     	mov	x16, x9
100004900:     	b	0x1000046a4 <_silex_function_5+0x2e0>
100004904:     	ldr	x10, [sp, #0xc8]
100004908:     	add	x14, x10, #0x8
10000490c:     	ldaxr	x9, [x14]
100004910:     	cbz	x9, 0x100004968 <_silex_function_5+0x5a4>
100004914:     	sub	x9, x9, #0x1
100004918:     	stlxr	w11, x9, [x14]
10000491c:     	cbnz	w11, 0x10000490c <_silex_function_5+0x548>
100004920:     	ldr	x11, [x10, #0x10]
100004924:     	add	x9, x9, x11
100004928:     	cbnz	x9, 0x100004968 <_silex_function_5+0x5a4>
10000492c:     	add	x14, x10, #0x20
100004930:     	ldaxr	x9, [x14]
100004934:     	mov	x11, #0x2               ; =2
100004938:     	cmp	x9, x11
10000493c:     	b.eq	0x100004930 <_silex_function_5+0x56c>
100004940:     	mov	x11, #0x1               ; =1
100004944:     	cmp	x9, x11
100004948:     	b.eq	0x100004968 <_silex_function_5+0x5a4>
10000494c:     	mov	x9, #0x1                ; =1
100004950:     	stlxr	w11, x9, [x14]
100004954:     	cbnz	w11, 0x100004930 <_silex_function_5+0x56c>
100004958:     	ldr	x1, [x10, #0x18]
10000495c:     	mov	x0, x10
100004960:     	mov	w16, #0x49              ; =73
100004964:     	svc	#0x80
100004968:     	ldr	x14, [sp]
10000496c:     	ldr	x9, [sp, #0x68]
100004970:     	str	x9, [x14]
100004974:     	ldr	x9, [sp, #0x70]
100004978:     	str	x9, [x14, #0x8]
10000497c:     	mov	x0, #0x0                ; =0
100004980:     	mov	w8, #0x0                ; =0
100004984:     	b	0x1000055c8 <_silex_function_5+0x1204>
100004988:     	movz	x9, #0x0, lsl #48
10000498c:     	str	x9, [sp, #0x100]
100004990:     	mov	x16, x9
100004994:     	ldr	x9, [sp, #0x20]
100004998:     	ldr	x10, [sp, #0x100]
10000499c:     	add	x9, x9, x10
1000049a0:     	ldr	w9, [x9]
1000049a4:     	sxtw	x9, w9
1000049a8:     	str	x9, [sp, #0x108]
1000049ac:     	movz	x9, #0x0, lsl #48
1000049b0:     	str	x9, [sp, #0x110]
1000049b4:     	mov	x16, x9
1000049b8:     	ldr	x9, [sp, #0x30]
1000049bc:     	ldr	x10, [sp, #0x110]
1000049c0:     	add	x9, x9, x10
1000049c4:     	ldr	x9, [x9]
1000049c8:     	str	x9, [sp, #0x118]
1000049cc:     	movz	x9, #0x0, lsl #48
1000049d0:     	str	x9, [sp, #0x120]
1000049d4:     	mov	x16, x9
1000049d8:     	mov	x9, x16
1000049dc:     	str	x9, [sp, #0x2e0]
1000049e0:     	mov	x17, x9
1000049e4:     	ldr	x9, [sp, #0x108]
1000049e8:     	str	x9, [sp, #0x128]
1000049ec:     	ldr	x9, [sp, #0x2e0]
1000049f0:     	ldr	x10, [sp, #0x128]
1000049f4:     	cmp	x9, x10
1000049f8:     	mov	w11, #0x0               ; =0
1000049fc:     	b.ge	0x100004a04 <_silex_function_5+0x640>
100004a00:     	mov	w11, #0x1               ; =1
100004a04:     	str	x11, [sp, #0x130]
100004a08:     	mov	x16, x11
100004a0c:     	ldr	x9, [sp, #0x130]
100004a10:     	cbz	w9, 0x100004a94 <_silex_function_5+0x6d0>
100004a14:     	ldr	x9, [sp, #0x2e0]
100004a18:     	str	x9, [sp, #0x138]
100004a1c:     	mov	x9, #0x8                ; =8
100004a20:     	str	x9, [sp, #0x140]
100004a24:     	mov	x16, x9
100004a28:     	ldr	x9, [sp, #0x138]
100004a2c:     	ldr	x10, [sp, #0x140]
100004a30:     	mul	x11, x9, x10
100004a34:     	umulh	x12, x9, x10
100004a38:     	cbnz	x12, 0x1000055d4 <_silex_function_5+0x1210>
100004a3c:     	str	x11, [sp, #0x148]
100004a40:     	mov	x17, x11
100004a44:     	ldr	x9, [sp, #0x118]
100004a48:     	ldr	x10, [sp, #0x148]
100004a4c:     	add	x9, x9, x10
100004a50:     	ldr	x9, [x9]
100004a54:     	str	x9, [sp, #0x150]
100004a58:     	movz	x9, #0x0, lsl #48
100004a5c:     	str	x9, [sp, #0x158]
100004a60:     	mov	x16, x9
100004a64:     	ldr	x9, [sp, #0x150]
100004a68:     	ldr	x10, [sp, #0x158]
100004a6c:     	cmp	x9, x10
100004a70:     	mov	w11, #0x0               ; =0
100004a74:     	b.ne	0x100004a7c <_silex_function_5+0x6b8>
100004a78:     	mov	w11, #0x1               ; =1
100004a7c:     	str	x11, [sp, #0x160]
100004a80:     	mov	x17, x11
100004a84:     	ldr	x9, [sp, #0x160]
100004a88:     	cbz	w9, 0x100004a90 <_silex_function_5+0x6cc>
100004a8c:     	b	0x100004b38 <_silex_function_5+0x774>
100004a90:     	b	0x100004fbc <_silex_function_5+0xbf8>
100004a94:     	ldr	x9, [sp, #0x8]
100004a98:     	str	x9, [sp, #0x230]
100004a9c:     	mov	x16, x9
100004aa0:     	mov	w9, #0x1                ; =1
100004aa4:     	str	x9, [sp, #0x238]
100004aa8:     	ldr	x9, [sp, #0x230]
100004aac:     	str	x9, [sp, #0x240]
100004ab0:     	mov	w9, #0x0                ; =0
100004ab4:     	str	x9, [sp, #0x248]
100004ab8:     	str	x9, [sp, #0x250]
100004abc:     	ldr	x9, [sp, #0x238]
100004ac0:     	ldr	x10, [sp, #0x248]
100004ac4:     	cmp	x9, x10
100004ac8:     	mov	w11, #0x0               ; =0
100004acc:     	b.ne	0x100004ad4 <_silex_function_5+0x710>
100004ad0:     	mov	w11, #0x1               ; =1
100004ad4:     	str	x11, [sp, #0x258]
100004ad8:     	ldr	x9, [sp, #0x258]
100004adc:     	cbz	w9, 0x100004b20 <_silex_function_5+0x75c>
100004ae0:     	ldr	x9, [sp, #0x238]
100004ae4:     	mov	x10, #0x1               ; =1
100004ae8:     	cmp	x9, x10
100004aec:     	b.ne	0x100004b14 <_silex_function_5+0x750>
100004af0:     	ldr	x9, [sp, #0x240]
100004af4:     	ldr	x10, [sp, #0x250]
100004af8:     	cmp	x9, x10
100004afc:     	mov	w11, #0x0               ; =0
100004b00:     	b.ne	0x100004b08 <_silex_function_5+0x744>
100004b04:     	mov	w11, #0x1               ; =1
100004b08:     	str	x11, [sp, #0x258]
100004b0c:     	ldr	x9, [sp, #0x258]
100004b10:     	cbz	w9, 0x100004b20 <_silex_function_5+0x75c>
100004b14:     	mov	w9, #0x0                ; =0
100004b18:     	str	x9, [sp, #0x258]
100004b1c:     	b	0x100004b28 <_silex_function_5+0x764>
100004b20:     	mov	w9, #0x1                ; =1
100004b24:     	str	x9, [sp, #0x258]
100004b28:     	ldr	x9, [sp, #0x258]
100004b2c:     	cbz	w9, 0x100004b34 <_silex_function_5+0x770>
100004b30:     	b	0x1000051e4 <_silex_function_5+0xe20>
100004b34:     	b	0x10000522c <_silex_function_5+0xe68>
100004b38:     	ldr	x9, [sp, #0x8]
100004b3c:     	str	x9, [sp, #0x168]
100004b40:     	mov	x16, x9
100004b44:     	mov	w9, #0x1                ; =1
100004b48:     	str	x9, [sp, #0x170]
100004b4c:     	ldr	x9, [sp, #0x168]
100004b50:     	str	x9, [sp, #0x178]
100004b54:     	mov	w9, #0x0                ; =0
100004b58:     	str	x9, [sp, #0x180]
100004b5c:     	str	x9, [sp, #0x188]
100004b60:     	ldr	x9, [sp, #0x170]
100004b64:     	ldr	x10, [sp, #0x180]
100004b68:     	cmp	x9, x10
100004b6c:     	mov	w11, #0x0               ; =0
100004b70:     	b.ne	0x100004b78 <_silex_function_5+0x7b4>
100004b74:     	mov	w11, #0x1               ; =1
100004b78:     	str	x11, [sp, #0x190]
100004b7c:     	ldr	x9, [sp, #0x190]
100004b80:     	cbz	w9, 0x100004bc4 <_silex_function_5+0x800>
100004b84:     	ldr	x9, [sp, #0x170]
100004b88:     	mov	x10, #0x1               ; =1
100004b8c:     	cmp	x9, x10
100004b90:     	b.ne	0x100004bb8 <_silex_function_5+0x7f4>
100004b94:     	ldr	x9, [sp, #0x178]
100004b98:     	ldr	x10, [sp, #0x188]
100004b9c:     	cmp	x9, x10
100004ba0:     	mov	w11, #0x0               ; =0
100004ba4:     	b.ne	0x100004bac <_silex_function_5+0x7e8>
100004ba8:     	mov	w11, #0x1               ; =1
100004bac:     	str	x11, [sp, #0x190]
100004bb0:     	ldr	x9, [sp, #0x190]
100004bb4:     	cbz	w9, 0x100004bc4 <_silex_function_5+0x800>
100004bb8:     	mov	w9, #0x0                ; =0
100004bbc:     	str	x9, [sp, #0x190]
100004bc0:     	b	0x100004bcc <_silex_function_5+0x808>
100004bc4:     	mov	w9, #0x1                ; =1
100004bc8:     	str	x9, [sp, #0x190]
100004bcc:     	ldr	x9, [sp, #0x190]
100004bd0:     	cbz	w9, 0x100004c1c <_silex_function_5+0x858>
100004bd4:     	ldr	x9, [sp, #0x178]
100004bd8:     	str	x9, [sp, #0x198]
100004bdc:     	ldr	x10, [sp, #0x198]
100004be0:     	add	x14, x10, #0x8
100004be4:     	ldaxr	x9, [x14]
100004be8:     	add	x9, x9, #0x1
100004bec:     	stlxr	w11, x9, [x14]
100004bf0:     	cbnz	w11, 0x100004be4 <_silex_function_5+0x820>
100004bf4:     	movz	x9, #0x0, lsl #48
100004bf8:     	str	x9, [sp, #0x1a0]
100004bfc:     	mov	x16, x9
100004c00:     	ldr	x9, [sp, #0x198]
100004c04:     	ldr	x10, [x9]
100004c08:     	str	x10, [sp, #0x1a8]
100004c0c:     	ldr	x9, [sp, #0x1a0]
100004c10:     	str	x9, [sp, #0x2e8]
100004c14:     	mov	x16, x9
100004c18:     	b	0x100004c44 <_silex_function_5+0x880>
100004c1c:     	ldr	x9, [sp, #0x8]
100004c20:     	str	x9, [sp, #0x1d0]
100004c24:     	mov	x16, x9
100004c28:     	ldr	x9, [sp, #0x1d0]
100004c2c:     	ldr	x10, [x9]
100004c30:     	str	x10, [sp, #0x1d8]
100004c34:     	ldr	x9, [sp, #0x1d8]
100004c38:     	str	x9, [sp, #0x2f0]
100004c3c:     	mov	x16, x9
100004c40:     	b	0x100004cd8 <_silex_function_5+0x914>
100004c44:     	ldr	x9, [sp, #0x2e8]
100004c48:     	ldr	x10, [sp, #0x1a8]
100004c4c:     	cmp	x9, x10
100004c50:     	mov	w11, #0x0               ; =0
100004c54:     	b.ge	0x100004c5c <_silex_function_5+0x898>
100004c58:     	mov	w11, #0x1               ; =1
100004c5c:     	str	x11, [sp, #0x1b0]
100004c60:     	mov	x16, x11
100004c64:     	ldr	x9, [sp, #0x1b0]
100004c68:     	cbz	w9, 0x100004c1c <_silex_function_5+0x858>
100004c6c:     	ldr	x10, [sp, #0x198]
100004c70:     	add	x10, x10, #0x28
100004c74:     	ldr	x9, [sp, #0x2e8]
100004c78:     	add	x10, x10, x9, lsl #3
100004c7c:     	ldr	x12, [x10]
100004c80:     	str	x12, [sp, #0x1b8]
100004c84:     	ldr	x10, [sp, #0x1b8]
100004c88:     	ldr	x9, [x10]
100004c8c:     	mov	x11, #0x0               ; =0
100004c90:     	movk	x11, #0x0, lsl #16
100004c94:     	movk	x11, #0x0, lsl #32
100004c98:     	movk	x11, #0x8000, lsl #48
100004c9c:     	and	x9, x9, x11
100004ca0:     	cbz	x9, 0x100004cb8 <_silex_function_5+0x8f4>
100004ca4:     	sub	x10, x10, #0x10
100004ca8:     	ldaxr	x9, [x10]
100004cac:     	add	x9, x9, #0x1
100004cb0:     	stlxr	w11, x9, [x10]
100004cb4:     	cbnz	w11, 0x100004ca8 <_silex_function_5+0x8e4>
100004cb8:     	ldr	x9, [sp, #0x2e8]
100004cbc:     	add	x11, x9, #0x1
100004cc0:     	str	x11, [sp, #0x1c8]
100004cc4:     	mov	x16, x11
100004cc8:     	mov	x9, x16
100004ccc:     	str	x9, [sp, #0x2e8]
100004cd0:     	mov	x17, x9
100004cd4:     	b	0x100004c44 <_silex_function_5+0x880>
100004cd8:     	movz	x9, #0x0, lsl #48
100004cdc:     	str	x9, [sp, #0x1e0]
100004ce0:     	mov	x16, x9
100004ce4:     	ldr	x9, [sp, #0x2f0]
100004ce8:     	ldr	x10, [sp, #0x1e0]
100004cec:     	cmp	x9, x10
100004cf0:     	mov	w11, #0x0               ; =0
100004cf4:     	b.eq	0x100004cfc <_silex_function_5+0x938>
100004cf8:     	mov	w11, #0x1               ; =1
100004cfc:     	str	x11, [sp, #0x1e8]
100004d00:     	mov	x17, x11
100004d04:     	ldr	x9, [sp, #0x1e8]
100004d08:     	cbz	w9, 0x100004f38 <_silex_function_5+0xb74>
100004d0c:     	ldr	x9, [sp, #0x2f0]
100004d10:     	sub	x11, x9, #0x1
100004d14:     	str	x11, [sp, #0x1f8]
100004d18:     	mov	x16, x11
100004d1c:     	ldr	x10, [sp, #0x1d0]
100004d20:     	ldr	x13, [x10]
100004d24:     	ldr	x9, [sp, #0x1f8]
100004d28:     	cmp	x9, xzr
100004d2c:     	b.ge	0x100004d34 <_silex_function_5+0x970>
100004d30:     	add	x9, x9, x13
100004d34:     	cmp	x9, xzr
100004d38:     	b.lt	0x100004d58 <_silex_function_5+0x994>
100004d3c:     	cmp	x9, x13
100004d40:     	b.ge	0x100004d58 <_silex_function_5+0x994>
100004d44:     	add	x10, x10, #0x28
100004d48:     	add	x10, x10, x9, lsl #3
100004d4c:     	ldr	x12, [x10]
100004d50:     	str	x12, [sp, #0x200]
100004d54:     	b	0x100004edc <_silex_function_5+0xb18>
100004d58:     	str	x13, [sp, #0x200]
100004d5c:     	mov	w0, #0x2                ; =2
100004d60:     	adrp	x1, 0x100009000 <_main+0x1b80>
100004d64:     	add	x1, x1, #0x1c8
100004d68:     	mov	x2, #0x9e               ; =158
100004d6c:     	movk	x2, #0x0, lsl #16
100004d70:     	movk	x2, #0x0, lsl #32
100004d74:     	movk	x2, #0x0, lsl #48
100004d78:     	mov	w16, #0x4               ; =4
100004d7c:     	svc	#0x80
100004d80:     	ldr	x9, [sp, #0x1f8]
100004d84:     	sub	sp, sp, #0x20
100004d88:     	add	x11, sp, #0x20
100004d8c:     	mov	w12, #0x0               ; =0
100004d90:     	cbnz	x9, 0x100004da8 <_silex_function_5+0x9e4>
100004d94:     	sub	x11, x11, #0x1
100004d98:     	mov	w10, #0x30              ; =48
100004d9c:     	strb	w10, [x11]
100004da0:     	add	x12, x12, #0x1
100004da4:     	b	0x100004dfc <_silex_function_5+0xa38>
100004da8:     	mov	w3, #0x0                ; =0
100004dac:     	cmp	x9, xzr
100004db0:     	b.lt	0x100004dbc <_silex_function_5+0x9f8>
100004db4:     	negs	x9, x9
100004db8:     	b	0x100004dc0 <_silex_function_5+0x9fc>
100004dbc:     	mov	w3, #0x1                ; =1
100004dc0:     	mov	w10, #0xa               ; =10
100004dc4:     	sdiv	x4, x9, x10
100004dc8:     	msub	x5, x4, x10, x9
100004dcc:     	mov	w6, #0x30               ; =48
100004dd0:     	subs	x6, x6, x5
100004dd4:     	sub	x11, x11, #0x1
100004dd8:     	strb	w6, [x11]
100004ddc:     	add	x12, x12, #0x1
100004de0:     	mov	x9, x4
100004de4:     	cbnz	x9, 0x100004dc0 <_silex_function_5+0x9fc>
100004de8:     	cbz	w3, 0x100004dfc <_silex_function_5+0xa38>
100004dec:     	sub	x11, x11, #0x1
100004df0:     	mov	w10, #0x2d              ; =45
100004df4:     	strb	w10, [x11]
100004df8:     	add	x12, x12, #0x1
100004dfc:     	mov	w0, #0x2                ; =2
100004e00:     	mov	x1, x11
100004e04:     	mov	x2, x12
100004e08:     	mov	w16, #0x4               ; =4
100004e0c:     	svc	#0x80
100004e10:     	add	sp, sp, #0x20
100004e14:     	mov	w0, #0x2                ; =2
100004e18:     	adrp	x1, 0x100009000 <_main+0x1b80>
100004e1c:     	add	x1, x1, #0x178
100004e20:     	mov	x2, #0x1c               ; =28
100004e24:     	movk	x2, #0x0, lsl #16
100004e28:     	movk	x2, #0x0, lsl #32
100004e2c:     	movk	x2, #0x0, lsl #48
100004e30:     	mov	w16, #0x4               ; =4
100004e34:     	svc	#0x80
100004e38:     	ldr	x9, [sp, #0x200]
100004e3c:     	sub	sp, sp, #0x20
100004e40:     	add	x11, sp, #0x1f
100004e44:     	mov	w10, #0xa               ; =10
100004e48:     	strb	w10, [x11]
100004e4c:     	mov	w12, #0x1               ; =1
100004e50:     	cbnz	x9, 0x100004e68 <_silex_function_5+0xaa4>
100004e54:     	sub	x11, x11, #0x1
100004e58:     	mov	w10, #0x30              ; =48
100004e5c:     	strb	w10, [x11]
100004e60:     	add	x12, x12, #0x1
100004e64:     	b	0x100004ebc <_silex_function_5+0xaf8>
100004e68:     	mov	w3, #0x0                ; =0
100004e6c:     	cmp	x9, xzr
100004e70:     	b.lt	0x100004e7c <_silex_function_5+0xab8>
100004e74:     	negs	x9, x9
100004e78:     	b	0x100004e80 <_silex_function_5+0xabc>
100004e7c:     	mov	w3, #0x1                ; =1
100004e80:     	mov	w10, #0xa               ; =10
100004e84:     	sdiv	x4, x9, x10
100004e88:     	msub	x5, x4, x10, x9
100004e8c:     	mov	w6, #0x30               ; =48
100004e90:     	subs	x6, x6, x5
100004e94:     	sub	x11, x11, #0x1
100004e98:     	strb	w6, [x11]
100004e9c:     	add	x12, x12, #0x1
100004ea0:     	mov	x9, x4
100004ea4:     	cbnz	x9, 0x100004e80 <_silex_function_5+0xabc>
100004ea8:     	cbz	w3, 0x100004ebc <_silex_function_5+0xaf8>
100004eac:     	sub	x11, x11, #0x1
100004eb0:     	mov	w10, #0x2d              ; =45
100004eb4:     	strb	w10, [x11]
100004eb8:     	add	x12, x12, #0x1
100004ebc:     	mov	w0, #0x2                ; =2
100004ec0:     	mov	x1, x11
100004ec4:     	mov	x2, x12
100004ec8:     	mov	w16, #0x4               ; =4
100004ecc:     	svc	#0x80
100004ed0:     	add	sp, sp, #0x20
100004ed4:     	mov	w8, #0x3                ; =3
100004ed8:     	b	0x1000055c8 <_silex_function_5+0x1204>
100004edc:     	ldr	x10, [sp, #0x200]
100004ee0:     	ldr	x9, [x10]
100004ee4:     	mov	x11, #0x0               ; =0
100004ee8:     	movk	x11, #0x0, lsl #16
100004eec:     	movk	x11, #0x0, lsl #32
100004ef0:     	movk	x11, #0x8000, lsl #48
100004ef4:     	and	x9, x9, x11
100004ef8:     	cbz	x9, 0x100004f28 <_silex_function_5+0xb64>
100004efc:     	sub	x10, x10, #0x10
100004f00:     	ldaxr	x9, [x10]
100004f04:     	cbz	x9, 0x100004f28 <_silex_function_5+0xb64>
100004f08:     	sub	x9, x9, #0x1
100004f0c:     	stlxr	w11, x9, [x10]
100004f10:     	cbnz	w11, 0x100004f00 <_silex_function_5+0xb3c>
100004f14:     	cbnz	x9, 0x100004f28 <_silex_function_5+0xb64>
100004f18:     	ldr	x1, [x10, #0x8]
100004f1c:     	mov	x0, x10
100004f20:     	mov	w16, #0x49              ; =73
100004f24:     	svc	#0x80
100004f28:     	ldr	x9, [sp, #0x1f8]
100004f2c:     	str	x9, [sp, #0x2f0]
100004f30:     	mov	x16, x9
100004f34:     	b	0x100004cd8 <_silex_function_5+0x914>
100004f38:     	ldr	x10, [sp, #0x1d0]
100004f3c:     	add	x14, x10, #0x8
100004f40:     	ldaxr	x9, [x14]
100004f44:     	cbz	x9, 0x100004f9c <_silex_function_5+0xbd8>
100004f48:     	sub	x9, x9, #0x1
100004f4c:     	stlxr	w11, x9, [x14]
100004f50:     	cbnz	w11, 0x100004f40 <_silex_function_5+0xb7c>
100004f54:     	ldr	x11, [x10, #0x10]
100004f58:     	add	x9, x9, x11
100004f5c:     	cbnz	x9, 0x100004f9c <_silex_function_5+0xbd8>
100004f60:     	add	x14, x10, #0x20
100004f64:     	ldaxr	x9, [x14]
100004f68:     	mov	x11, #0x2               ; =2
100004f6c:     	cmp	x9, x11
100004f70:     	b.eq	0x100004f64 <_silex_function_5+0xba0>
100004f74:     	mov	x11, #0x1               ; =1
100004f78:     	cmp	x9, x11
100004f7c:     	b.eq	0x100004f9c <_silex_function_5+0xbd8>
100004f80:     	mov	x9, #0x1                ; =1
100004f84:     	stlxr	w11, x9, [x14]
100004f88:     	cbnz	w11, 0x100004f64 <_silex_function_5+0xba0>
100004f8c:     	ldr	x1, [x10, #0x18]
100004f90:     	mov	x0, x10
100004f94:     	mov	w16, #0x49              ; =73
100004f98:     	svc	#0x80
100004f9c:     	ldr	x14, [sp]
100004fa0:     	ldr	x9, [sp, #0x170]
100004fa4:     	str	x9, [x14]
100004fa8:     	ldr	x9, [sp, #0x178]
100004fac:     	str	x9, [x14, #0x8]
100004fb0:     	mov	x0, #0x0                ; =0
100004fb4:     	mov	w8, #0x0                ; =0
100004fb8:     	b	0x1000055c8 <_silex_function_5+0x1204>
100004fbc:     	ldr	x9, [sp, #0x8]
100004fc0:     	str	x9, [sp, #0x208]
100004fc4:     	mov	x16, x9
100004fc8:     	ldr	x0, [sp, #0x150]
100004fcc:     	bl	0x1000055e4 <_silex_function_6>
100004fd0:     	cbnz	w8, 0x1000055c8 <_silex_function_5+0x1204>
100004fd4:     	str	x0, [sp, #0x210]
100004fd8:     	ldr	x10, [sp, #0x208]
100004fdc:     	ldr	x13, [x10]
100004fe0:     	mov	w9, #0x0                ; =0
100004fe4:     	mov	x12, x13
100004fe8:     	add	x12, x12, #0x1
100004fec:     	ldr	x11, [x10, #0x8]
100004ff0:     	ldr	x5, [x10, #0x10]
100004ff4:     	add	x11, x11, x5
100004ff8:     	mov	x5, #0x1                ; =1
100004ffc:     	cmp	x11, x5
100005000:     	b.ne	0x100005040 <_silex_function_5+0xc7c>
100005004:     	mov	x11, #0x8               ; =8
100005008:     	mul	x5, x12, x11
10000500c:     	add	x5, x5, #0x28
100005010:     	ldr	x11, [x10, #0x18]
100005014:     	cmp	x5, x11
100005018:     	b.hi	0x100005040 <_silex_function_5+0xc7c>
10000501c:     	add	x14, x10, #0x28
100005020:     	mov	x11, #0x8               ; =8
100005024:     	mul	x5, x13, x11
100005028:     	add	x14, x14, x5
10000502c:     	ldr	x5, [sp, #0x210]
100005030:     	str	x5, [x14]
100005034:     	str	x12, [x10]
100005038:     	str	x10, [sp, #0x218]
10000503c:     	b	0x1000051a8 <_silex_function_5+0xde4>
100005040:     	sub	sp, sp, #0x30
100005044:     	str	x10, [sp]
100005048:     	str	x13, [sp, #0x8]
10000504c:     	str	x9, [sp, #0x10]
100005050:     	str	x12, [sp, #0x18]
100005054:     	str	x7, [sp, #0x20]
100005058:     	str	x6, [sp, #0x28]
10000505c:     	mov	x11, #0x8               ; =8
100005060:     	mul	x1, x12, x11
100005064:     	add	x1, x1, #0x28
100005068:     	mov	x5, #0x4000             ; =16384
10000506c:     	cmp	x1, x5
100005070:     	b.hs	0x100005078 <_silex_function_5+0xcb4>
100005074:     	mov	x1, x5
100005078:     	add	x1, x1, x1
10000507c:     	mov	w0, #0x0                ; =0
100005080:     	mov	w2, #0x3                ; =3
100005084:     	mov	w3, #0x1002             ; =4098
100005088:     	mov	x4, #0xffff             ; =65535
10000508c:     	movk	x4, #0xffff, lsl #16
100005090:     	movk	x4, #0xffff, lsl #32
100005094:     	movk	x4, #0xffff, lsl #48
100005098:     	mov	w5, #0x0                ; =0
10000509c:     	mov	w16, #0xc5              ; =197
1000050a0:     	svc	#0x80
1000050a4:     	b.hs	0x1000051ac <_silex_function_5+0xde8>
1000050a8:     	mov	x15, x0
1000050ac:     	ldr	x10, [sp]
1000050b0:     	ldr	x13, [sp, #0x8]
1000050b4:     	ldr	x9, [sp, #0x10]
1000050b8:     	ldr	x12, [sp, #0x18]
1000050bc:     	ldr	x7, [sp, #0x20]
1000050c0:     	ldr	x6, [sp, #0x28]
1000050c4:     	str	x12, [x15]
1000050c8:     	mov	x5, #0x1                ; =1
1000050cc:     	str	x5, [x15, #0x8]
1000050d0:     	mov	x11, #0x8               ; =8
1000050d4:     	mul	x11, x12, x11
1000050d8:     	add	x11, x11, #0x28
1000050dc:     	mov	x5, #0x4000             ; =16384
1000050e0:     	cmp	x11, x5
1000050e4:     	b.hs	0x1000050ec <_silex_function_5+0xd28>
1000050e8:     	mov	x11, x5
1000050ec:     	add	x11, x11, x11
1000050f0:     	str	x11, [x15, #0x18]
1000050f4:     	add	x10, x10, #0x28
1000050f8:     	add	x14, x15, #0x28
1000050fc:     	mov	x11, #0x1               ; =1
100005100:     	mul	x12, x13, x11
100005104:     	cbz	x12, 0x100005120 <_silex_function_5+0xd5c>
100005108:     	ldr	x11, [x10]
10000510c:     	str	x11, [x14]
100005110:     	add	x10, x10, #0x8
100005114:     	add	x14, x14, #0x8
100005118:     	sub	x12, x12, #0x1
10000511c:     	cbnz	x12, 0x100005108 <_silex_function_5+0xd44>
100005120:     	add	sp, sp, #0x30
100005124:     	mov	x9, x13
100005128:     	add	x14, x15, #0x28
10000512c:     	mov	x11, #0x8               ; =8
100005130:     	mul	x9, x9, x11
100005134:     	add	x14, x14, x9
100005138:     	ldr	x12, [sp, #0x210]
10000513c:     	str	x12, [x14]
100005140:     	str	x15, [sp, #0x218]
100005144:     	ldr	x10, [sp, #0x208]
100005148:     	add	x14, x10, #0x8
10000514c:     	ldaxr	x9, [x14]
100005150:     	cbz	x9, 0x1000051a8 <_silex_function_5+0xde4>
100005154:     	sub	x9, x9, #0x1
100005158:     	stlxr	w11, x9, [x14]
10000515c:     	cbnz	w11, 0x10000514c <_silex_function_5+0xd88>
100005160:     	ldr	x11, [x10, #0x10]
100005164:     	add	x9, x9, x11
100005168:     	cbnz	x9, 0x1000051a8 <_silex_function_5+0xde4>
10000516c:     	add	x14, x10, #0x20
100005170:     	ldaxr	x9, [x14]
100005174:     	mov	x11, #0x2               ; =2
100005178:     	cmp	x9, x11
10000517c:     	b.eq	0x100005170 <_silex_function_5+0xdac>
100005180:     	mov	x11, #0x1               ; =1
100005184:     	cmp	x9, x11
100005188:     	b.eq	0x1000051a8 <_silex_function_5+0xde4>
10000518c:     	mov	x9, #0x1                ; =1
100005190:     	stlxr	w11, x9, [x14]
100005194:     	cbnz	w11, 0x100005170 <_silex_function_5+0xdac>
100005198:     	ldr	x1, [x10, #0x18]
10000519c:     	mov	x0, x10
1000051a0:     	mov	w16, #0x49              ; =73
1000051a4:     	svc	#0x80
1000051a8:     	b	0x1000051b8 <_silex_function_5+0xdf4>
1000051ac:     	add	sp, sp, #0x30
1000051b0:     	mov	w8, #0x3                ; =3
1000051b4:     	b	0x1000055c8 <_silex_function_5+0x1204>
1000051b8:     	ldr	x9, [sp, #0x218]
1000051bc:     	str	x9, [sp, #0x8]
1000051c0:     	mov	x16, x9
1000051c4:     	ldr	x9, [sp, #0x2e0]
1000051c8:     	add	x11, x9, #0x1
1000051cc:     	str	x11, [sp, #0x228]
1000051d0:     	mov	x17, x11
1000051d4:     	mov	x9, x17
1000051d8:     	str	x9, [sp, #0x2e0]
1000051dc:     	mov	x16, x9
1000051e0:     	b	0x1000049e4 <_silex_function_5+0x620>
1000051e4:     	ldr	x9, [sp, #0x240]
1000051e8:     	str	x9, [sp, #0x260]
1000051ec:     	ldr	x10, [sp, #0x260]
1000051f0:     	add	x14, x10, #0x8
1000051f4:     	ldaxr	x9, [x14]
1000051f8:     	add	x9, x9, #0x1
1000051fc:     	stlxr	w11, x9, [x14]
100005200:     	cbnz	w11, 0x1000051f4 <_silex_function_5+0xe30>
100005204:     	movz	x9, #0x0, lsl #48
100005208:     	str	x9, [sp, #0x268]
10000520c:     	mov	x16, x9
100005210:     	ldr	x9, [sp, #0x260]
100005214:     	ldr	x10, [x9]
100005218:     	str	x10, [sp, #0x270]
10000521c:     	ldr	x9, [sp, #0x268]
100005220:     	str	x9, [sp, #0x2f8]
100005224:     	mov	x16, x9
100005228:     	b	0x100005254 <_silex_function_5+0xe90>
10000522c:     	ldr	x9, [sp, #0x8]
100005230:     	str	x9, [sp, #0x298]
100005234:     	mov	x16, x9
100005238:     	ldr	x9, [sp, #0x298]
10000523c:     	ldr	x10, [x9]
100005240:     	str	x10, [sp, #0x2a0]
100005244:     	ldr	x9, [sp, #0x2a0]
100005248:     	str	x9, [sp, #0x300]
10000524c:     	mov	x16, x9
100005250:     	b	0x1000052e8 <_silex_function_5+0xf24>
100005254:     	ldr	x9, [sp, #0x2f8]
100005258:     	ldr	x10, [sp, #0x270]
10000525c:     	cmp	x9, x10
100005260:     	mov	w11, #0x0               ; =0
100005264:     	b.ge	0x10000526c <_silex_function_5+0xea8>
100005268:     	mov	w11, #0x1               ; =1
10000526c:     	str	x11, [sp, #0x278]
100005270:     	mov	x16, x11
100005274:     	ldr	x9, [sp, #0x278]
100005278:     	cbz	w9, 0x10000522c <_silex_function_5+0xe68>
10000527c:     	ldr	x10, [sp, #0x260]
100005280:     	add	x10, x10, #0x28
100005284:     	ldr	x9, [sp, #0x2f8]
100005288:     	add	x10, x10, x9, lsl #3
10000528c:     	ldr	x12, [x10]
100005290:     	str	x12, [sp, #0x280]
100005294:     	ldr	x10, [sp, #0x280]
100005298:     	ldr	x9, [x10]
10000529c:     	mov	x11, #0x0               ; =0
1000052a0:     	movk	x11, #0x0, lsl #16
1000052a4:     	movk	x11, #0x0, lsl #32
1000052a8:     	movk	x11, #0x8000, lsl #48
1000052ac:     	and	x9, x9, x11
1000052b0:     	cbz	x9, 0x1000052c8 <_silex_function_5+0xf04>
1000052b4:     	sub	x10, x10, #0x10
1000052b8:     	ldaxr	x9, [x10]
1000052bc:     	add	x9, x9, #0x1
1000052c0:     	stlxr	w11, x9, [x10]
1000052c4:     	cbnz	w11, 0x1000052b8 <_silex_function_5+0xef4>
1000052c8:     	ldr	x9, [sp, #0x2f8]
1000052cc:     	add	x11, x9, #0x1
1000052d0:     	str	x11, [sp, #0x290]
1000052d4:     	mov	x16, x11
1000052d8:     	mov	x9, x16
1000052dc:     	str	x9, [sp, #0x2f8]
1000052e0:     	mov	x17, x9
1000052e4:     	b	0x100005254 <_silex_function_5+0xe90>
1000052e8:     	movz	x9, #0x0, lsl #48
1000052ec:     	str	x9, [sp, #0x2a8]
1000052f0:     	mov	x16, x9
1000052f4:     	ldr	x9, [sp, #0x300]
1000052f8:     	ldr	x10, [sp, #0x2a8]
1000052fc:     	cmp	x9, x10
100005300:     	mov	w11, #0x0               ; =0
100005304:     	b.eq	0x10000530c <_silex_function_5+0xf48>
100005308:     	mov	w11, #0x1               ; =1
10000530c:     	str	x11, [sp, #0x2b0]
100005310:     	mov	x17, x11
100005314:     	ldr	x9, [sp, #0x2b0]
100005318:     	cbz	w9, 0x100005548 <_silex_function_5+0x1184>
10000531c:     	ldr	x9, [sp, #0x300]
100005320:     	sub	x11, x9, #0x1
100005324:     	str	x11, [sp, #0x2c0]
100005328:     	mov	x16, x11
10000532c:     	ldr	x10, [sp, #0x298]
100005330:     	ldr	x13, [x10]
100005334:     	ldr	x9, [sp, #0x2c0]
100005338:     	cmp	x9, xzr
10000533c:     	b.ge	0x100005344 <_silex_function_5+0xf80>
100005340:     	add	x9, x9, x13
100005344:     	cmp	x9, xzr
100005348:     	b.lt	0x100005368 <_silex_function_5+0xfa4>
10000534c:     	cmp	x9, x13
100005350:     	b.ge	0x100005368 <_silex_function_5+0xfa4>
100005354:     	add	x10, x10, #0x28
100005358:     	add	x10, x10, x9, lsl #3
10000535c:     	ldr	x12, [x10]
100005360:     	str	x12, [sp, #0x2c8]
100005364:     	b	0x1000054ec <_silex_function_5+0x1128>
100005368:     	str	x13, [sp, #0x2c8]
10000536c:     	mov	w0, #0x2                ; =2
100005370:     	adrp	x1, 0x100009000 <_main+0x1b80>
100005374:     	add	x1, x1, #0x1c8
100005378:     	mov	x2, #0x9e               ; =158
10000537c:     	movk	x2, #0x0, lsl #16
100005380:     	movk	x2, #0x0, lsl #32
100005384:     	movk	x2, #0x0, lsl #48
100005388:     	mov	w16, #0x4               ; =4
10000538c:     	svc	#0x80
100005390:     	ldr	x9, [sp, #0x2c0]
100005394:     	sub	sp, sp, #0x20
100005398:     	add	x11, sp, #0x20
10000539c:     	mov	w12, #0x0               ; =0
1000053a0:     	cbnz	x9, 0x1000053b8 <_silex_function_5+0xff4>
1000053a4:     	sub	x11, x11, #0x1
1000053a8:     	mov	w10, #0x30              ; =48
1000053ac:     	strb	w10, [x11]
1000053b0:     	add	x12, x12, #0x1
1000053b4:     	b	0x10000540c <_silex_function_5+0x1048>
1000053b8:     	mov	w3, #0x0                ; =0
1000053bc:     	cmp	x9, xzr
1000053c0:     	b.lt	0x1000053cc <_silex_function_5+0x1008>
1000053c4:     	negs	x9, x9
1000053c8:     	b	0x1000053d0 <_silex_function_5+0x100c>
1000053cc:     	mov	w3, #0x1                ; =1
1000053d0:     	mov	w10, #0xa               ; =10
1000053d4:     	sdiv	x4, x9, x10
1000053d8:     	msub	x5, x4, x10, x9
1000053dc:     	mov	w6, #0x30               ; =48
1000053e0:     	subs	x6, x6, x5
1000053e4:     	sub	x11, x11, #0x1
1000053e8:     	strb	w6, [x11]
1000053ec:     	add	x12, x12, #0x1
1000053f0:     	mov	x9, x4
1000053f4:     	cbnz	x9, 0x1000053d0 <_silex_function_5+0x100c>
1000053f8:     	cbz	w3, 0x10000540c <_silex_function_5+0x1048>
1000053fc:     	sub	x11, x11, #0x1
100005400:     	mov	w10, #0x2d              ; =45
100005404:     	strb	w10, [x11]
100005408:     	add	x12, x12, #0x1
10000540c:     	mov	w0, #0x2                ; =2
100005410:     	mov	x1, x11
100005414:     	mov	x2, x12
100005418:     	mov	w16, #0x4               ; =4
10000541c:     	svc	#0x80
100005420:     	add	sp, sp, #0x20
100005424:     	mov	w0, #0x2                ; =2
100005428:     	adrp	x1, 0x100009000 <_main+0x1b80>
10000542c:     	add	x1, x1, #0x178
100005430:     	mov	x2, #0x1c               ; =28
100005434:     	movk	x2, #0x0, lsl #16
100005438:     	movk	x2, #0x0, lsl #32
10000543c:     	movk	x2, #0x0, lsl #48
100005440:     	mov	w16, #0x4               ; =4
100005444:     	svc	#0x80
100005448:     	ldr	x9, [sp, #0x2c8]
10000544c:     	sub	sp, sp, #0x20
100005450:     	add	x11, sp, #0x1f
100005454:     	mov	w10, #0xa               ; =10
100005458:     	strb	w10, [x11]
10000545c:     	mov	w12, #0x1               ; =1
100005460:     	cbnz	x9, 0x100005478 <_silex_function_5+0x10b4>
100005464:     	sub	x11, x11, #0x1
100005468:     	mov	w10, #0x30              ; =48
10000546c:     	strb	w10, [x11]
100005470:     	add	x12, x12, #0x1
100005474:     	b	0x1000054cc <_silex_function_5+0x1108>
100005478:     	mov	w3, #0x0                ; =0
10000547c:     	cmp	x9, xzr
100005480:     	b.lt	0x10000548c <_silex_function_5+0x10c8>
100005484:     	negs	x9, x9
100005488:     	b	0x100005490 <_silex_function_5+0x10cc>
10000548c:     	mov	w3, #0x1                ; =1
100005490:     	mov	w10, #0xa               ; =10
100005494:     	sdiv	x4, x9, x10
100005498:     	msub	x5, x4, x10, x9
10000549c:     	mov	w6, #0x30               ; =48
1000054a0:     	subs	x6, x6, x5
1000054a4:     	sub	x11, x11, #0x1
1000054a8:     	strb	w6, [x11]
1000054ac:     	add	x12, x12, #0x1
1000054b0:     	mov	x9, x4
1000054b4:     	cbnz	x9, 0x100005490 <_silex_function_5+0x10cc>
1000054b8:     	cbz	w3, 0x1000054cc <_silex_function_5+0x1108>
1000054bc:     	sub	x11, x11, #0x1
1000054c0:     	mov	w10, #0x2d              ; =45
1000054c4:     	strb	w10, [x11]
1000054c8:     	add	x12, x12, #0x1
1000054cc:     	mov	w0, #0x2                ; =2
1000054d0:     	mov	x1, x11
1000054d4:     	mov	x2, x12
1000054d8:     	mov	w16, #0x4               ; =4
1000054dc:     	svc	#0x80
1000054e0:     	add	sp, sp, #0x20
1000054e4:     	mov	w8, #0x3                ; =3
1000054e8:     	b	0x1000055c8 <_silex_function_5+0x1204>
1000054ec:     	ldr	x10, [sp, #0x2c8]
1000054f0:     	ldr	x9, [x10]
1000054f4:     	mov	x11, #0x0               ; =0
1000054f8:     	movk	x11, #0x0, lsl #16
1000054fc:     	movk	x11, #0x0, lsl #32
100005500:     	movk	x11, #0x8000, lsl #48
100005504:     	and	x9, x9, x11
100005508:     	cbz	x9, 0x100005538 <_silex_function_5+0x1174>
10000550c:     	sub	x10, x10, #0x10
100005510:     	ldaxr	x9, [x10]
100005514:     	cbz	x9, 0x100005538 <_silex_function_5+0x1174>
100005518:     	sub	x9, x9, #0x1
10000551c:     	stlxr	w11, x9, [x10]
100005520:     	cbnz	w11, 0x100005510 <_silex_function_5+0x114c>
100005524:     	cbnz	x9, 0x100005538 <_silex_function_5+0x1174>
100005528:     	ldr	x1, [x10, #0x8]
10000552c:     	mov	x0, x10
100005530:     	mov	w16, #0x49              ; =73
100005534:     	svc	#0x80
100005538:     	ldr	x9, [sp, #0x2c0]
10000553c:     	str	x9, [sp, #0x300]
100005540:     	mov	x16, x9
100005544:     	b	0x1000052e8 <_silex_function_5+0xf24>
100005548:     	ldr	x10, [sp, #0x298]
10000554c:     	add	x14, x10, #0x8
100005550:     	ldaxr	x9, [x14]
100005554:     	cbz	x9, 0x1000055ac <_silex_function_5+0x11e8>
100005558:     	sub	x9, x9, #0x1
10000555c:     	stlxr	w11, x9, [x14]
100005560:     	cbnz	w11, 0x100005550 <_silex_function_5+0x118c>
100005564:     	ldr	x11, [x10, #0x10]
100005568:     	add	x9, x9, x11
10000556c:     	cbnz	x9, 0x1000055ac <_silex_function_5+0x11e8>
100005570:     	add	x14, x10, #0x20
100005574:     	ldaxr	x9, [x14]
100005578:     	mov	x11, #0x2               ; =2
10000557c:     	cmp	x9, x11
100005580:     	b.eq	0x100005574 <_silex_function_5+0x11b0>
100005584:     	mov	x11, #0x1               ; =1
100005588:     	cmp	x9, x11
10000558c:     	b.eq	0x1000055ac <_silex_function_5+0x11e8>
100005590:     	mov	x9, #0x1                ; =1
100005594:     	stlxr	w11, x9, [x14]
100005598:     	cbnz	w11, 0x100005574 <_silex_function_5+0x11b0>
10000559c:     	ldr	x1, [x10, #0x18]
1000055a0:     	mov	x0, x10
1000055a4:     	mov	w16, #0x49              ; =73
1000055a8:     	svc	#0x80
1000055ac:     	ldr	x14, [sp]
1000055b0:     	ldr	x9, [sp, #0x238]
1000055b4:     	str	x9, [x14]
1000055b8:     	ldr	x9, [sp, #0x240]
1000055bc:     	str	x9, [x14, #0x8]
1000055c0:     	mov	x0, #0x0                ; =0
1000055c4:     	mov	w8, #0x0                ; =0
1000055c8:     	add	sp, sp, #0x310
1000055cc:     	ldp	x29, x30, [sp], #0x10
1000055d0:     	ret
1000055d4:     	mov	w8, #0x1                ; =1
1000055d8:     	b	0x1000055c8 <_silex_function_5+0x1204>
1000055dc:     	mov	w8, #0x2                ; =2
1000055e0:     	b	0x1000055c8 <_silex_function_5+0x1204>

00000001000055e4 <_silex_function_6>:
1000055e4:     	stp	x29, x30, [sp, #-0x10]!
1000055e8:     	mov	x29, sp
1000055ec:     	sub	sp, sp, #0xe0
1000055f0:     	str	x0, [sp]
1000055f4:     	mov	x1, #0x4000             ; =16384
1000055f8:     	mov	w0, #0x0                ; =0
1000055fc:     	mov	w2, #0x3                ; =3
100005600:     	mov	w3, #0x1002             ; =4098
100005604:     	mov	x4, #0xffff             ; =65535
100005608:     	movk	x4, #0xffff, lsl #16
10000560c:     	movk	x4, #0xffff, lsl #32
100005610:     	movk	x4, #0xffff, lsl #48
100005614:     	mov	w5, #0x0                ; =0
100005618:     	mov	w16, #0xc5              ; =197
10000561c:     	svc	#0x80
100005620:     	b.hs	0x10000564c <_silex_function_6+0x68>
100005624:     	mov	x15, x0
100005628:     	mov	x9, #0x0                ; =0
10000562c:     	str	x9, [x15]
100005630:     	mov	x9, #0x1                ; =1
100005634:     	str	x9, [x15, #0x8]
100005638:     	mov	x9, #0x4000             ; =16384
10000563c:     	str	x9, [x15, #0x18]
100005640:     	add	x14, x15, #0x28
100005644:     	str	x15, [sp, #0x8]
100005648:     	b	0x100005654 <_silex_function_6+0x70>
10000564c:     	mov	w8, #0x3                ; =3
100005650:     	b	0x100005c14 <_silex_function_6+0x630>
100005654:     	ldr	x9, [sp, #0x8]
100005658:     	str	x9, [sp, #0xd8]
10000565c:     	mov	x16, x9
100005660:     	movz	x9, #0x0, lsl #48
100005664:     	str	x9, [sp, #0x10]
100005668:     	mov	x17, x9
10000566c:     	mov	x9, x17
100005670:     	str	x9, [sp, #0xd0]
100005674:     	mov	x16, x9
100005678:     	mov	x9, #0x1000             ; =4096
10000567c:     	str	x9, [sp, #0x18]
100005680:     	mov	x16, x9
100005684:     	ldr	x9, [sp, #0xd0]
100005688:     	ldr	x10, [sp, #0x18]
10000568c:     	cmp	x9, x10
100005690:     	mov	w11, #0x0               ; =0
100005694:     	b.hs	0x10000569c <_silex_function_6+0xb8>
100005698:     	mov	w11, #0x1               ; =1
10000569c:     	str	x11, [sp, #0x20]
1000056a0:     	mov	x17, x11
1000056a4:     	ldr	x9, [sp, #0x20]
1000056a8:     	cbz	w9, 0x1000056fc <_silex_function_6+0x118>
1000056ac:     	ldr	x9, [sp]
1000056b0:     	ldr	x10, [sp, #0xd0]
1000056b4:     	add	x9, x9, x10
1000056b8:     	ldrb	w9, [x9]
1000056bc:     	str	x9, [sp, #0x28]
1000056c0:     	movz	x9, #0x0, lsl #48
1000056c4:     	str	x9, [sp, #0x30]
1000056c8:     	mov	x16, x9
1000056cc:     	ldr	x9, [sp, #0x28]
1000056d0:     	ldr	x10, [sp, #0x30]
1000056d4:     	cmp	x9, x10
1000056d8:     	mov	w11, #0x0               ; =0
1000056dc:     	b.ne	0x1000056e4 <_silex_function_6+0x100>
1000056e0:     	mov	w11, #0x1               ; =1
1000056e4:     	str	x11, [sp, #0x38]
1000056e8:     	mov	x17, x11
1000056ec:     	ldr	x9, [sp, #0x38]
1000056f0:     	cbz	w9, 0x1000056f8 <_silex_function_6+0x114>
1000056f4:     	b	0x100005784 <_silex_function_6+0x1a0>
1000056f8:     	b	0x1000059fc <_silex_function_6+0x418>
1000056fc:     	adrp	x9, 0x100009000 <_main+0x1b80>
100005700:     	add	x9, x9, #0x7c8
100005704:     	str	x9, [sp, #0xc8]
100005708:     	mov	w0, #0x2                ; =2
10000570c:     	adrp	x1, 0x100009000 <_main+0x1b80>
100005710:     	add	x1, x1, #0x800
100005714:     	mov	x2, #0x9d               ; =157
100005718:     	movk	x2, #0x0, lsl #16
10000571c:     	movk	x2, #0x0, lsl #32
100005720:     	movk	x2, #0x0, lsl #48
100005724:     	mov	w16, #0x4               ; =4
100005728:     	svc	#0x80
10000572c:     	ldr	x9, [sp, #0xc8]
100005730:     	ldr	x2, [x9]
100005734:     	mov	x10, #0xffff            ; =65535
100005738:     	movk	x10, #0xffff, lsl #16
10000573c:     	movk	x10, #0xffff, lsl #32
100005740:     	movk	x10, #0x7fff, lsl #48
100005744:     	and	x2, x2, x10
100005748:     	add	x1, x9, #0x8
10000574c:     	mov	w0, #0x2                ; =2
100005750:     	mov	w16, #0x4               ; =4
100005754:     	svc	#0x80
100005758:     	mov	w0, #0x2                ; =2
10000575c:     	adrp	x1, 0x100008000 <_main+0xb80>
100005760:     	add	x1, x1, #0xf10
100005764:     	mov	x2, #0x1                ; =1
100005768:     	movk	x2, #0x0, lsl #16
10000576c:     	movk	x2, #0x0, lsl #32
100005770:     	movk	x2, #0x0, lsl #48
100005774:     	mov	w16, #0x4               ; =4
100005778:     	svc	#0x80
10000577c:     	mov	w8, #0x3                ; =3
100005780:     	b	0x100005c14 <_silex_function_6+0x630>
100005784:     	ldr	x9, [sp, #0xd8]
100005788:     	str	x9, [sp, #0x40]
10000578c:     	mov	x16, x9
100005790:     	movz	x9, #0x0, lsl #48
100005794:     	str	x9, [sp, #0x48]
100005798:     	mov	x17, x9
10000579c:     	ldr	x9, [sp, #0xd8]
1000057a0:     	str	x9, [sp, #0x50]
1000057a4:     	mov	x16, x9
1000057a8:     	ldr	x9, [sp, #0x50]
1000057ac:     	ldr	x10, [x9]
1000057b0:     	str	x10, [sp, #0x58]
1000057b4:     	ldr	x10, [sp, #0x40]
1000057b8:     	ldr	x13, [x10]
1000057bc:     	add	x10, x10, #0x28
1000057c0:     	ldr	x9, [sp, #0x48]
1000057c4:     	cmp	x9, xzr
1000057c8:     	b.ge	0x1000057d0 <_silex_function_6+0x1ec>
1000057cc:     	add	x9, x9, x13
1000057d0:     	cmp	x9, xzr
1000057d4:     	b.ge	0x1000057dc <_silex_function_6+0x1f8>
1000057d8:     	mov	w9, #0x0                ; =0
1000057dc:     	cmp	x9, x13
1000057e0:     	b.le	0x1000057e8 <_silex_function_6+0x204>
1000057e4:     	mov	x9, x13
1000057e8:     	ldr	x8, [sp, #0x58]
1000057ec:     	cmp	x8, xzr
1000057f0:     	b.ge	0x1000057f8 <_silex_function_6+0x214>
1000057f4:     	add	x8, x8, x13
1000057f8:     	cmp	x8, xzr
1000057fc:     	b.ge	0x100005804 <_silex_function_6+0x220>
100005800:     	mov	w8, #0x0                ; =0
100005804:     	cmp	x8, x13
100005808:     	b.le	0x100005810 <_silex_function_6+0x22c>
10000580c:     	mov	x8, x13
100005810:     	mov	w12, #0x0               ; =0
100005814:     	cmp	x9, x8
100005818:     	b.ge	0x100005820 <_silex_function_6+0x23c>
10000581c:     	subs	x12, x8, x9
100005820:     	mov	x11, #0x8               ; =8
100005824:     	mul	x9, x9, x11
100005828:     	add	x10, x10, x9
10000582c:     	str	x10, [sp, #0x60]
100005830:     	str	x12, [sp, #0x68]
100005834:     	ldr	x0, [sp, #0x60]
100005838:     	ldr	x1, [sp, #0x68]
10000583c:     	add	x15, sp, #0x70
100005840:     	bl	0x100005c30 <_silex_function_7>
100005844:     	cbnz	w8, 0x100005c14 <_silex_function_6+0x630>
100005848:     	ldr	x9, [sp, #0x70]
10000584c:     	movz	x10, #0x0, lsl #48
100005850:     	cmp	x9, x10
100005854:     	mov	w11, #0x0               ; =0
100005858:     	b.ne	0x100005860 <_silex_function_6+0x27c>
10000585c:     	mov	w11, #0x1               ; =1
100005860:     	str	x11, [sp, #0x88]
100005864:     	ldr	x9, [sp, #0x88]
100005868:     	cbz	w9, 0x100005974 <_silex_function_6+0x390>
10000586c:     	ldr	x9, [sp, #0x78]
100005870:     	str	x9, [sp, #0x90]
100005874:     	mov	x16, x9
100005878:     	ldr	x10, [sp, #0x90]
10000587c:     	ldr	x9, [x10]
100005880:     	mov	x11, #0x0               ; =0
100005884:     	movk	x11, #0x0, lsl #16
100005888:     	movk	x11, #0x0, lsl #32
10000588c:     	movk	x11, #0x8000, lsl #48
100005890:     	and	x9, x9, x11
100005894:     	cbz	x9, 0x1000058ac <_silex_function_6+0x2c8>
100005898:     	sub	x10, x10, #0x10
10000589c:     	ldaxr	x9, [x10]
1000058a0:     	add	x9, x9, #0x1
1000058a4:     	stlxr	w11, x9, [x10]
1000058a8:     	cbnz	w11, 0x10000589c <_silex_function_6+0x2b8>
1000058ac:     	ldr	x10, [sp, #0x90]
1000058b0:     	ldr	x9, [x10]
1000058b4:     	mov	x11, #0x0               ; =0
1000058b8:     	movk	x11, #0x0, lsl #16
1000058bc:     	movk	x11, #0x0, lsl #32
1000058c0:     	movk	x11, #0x8000, lsl #48
1000058c4:     	and	x9, x9, x11
1000058c8:     	cbz	x9, 0x1000058f8 <_silex_function_6+0x314>
1000058cc:     	sub	x10, x10, #0x10
1000058d0:     	ldaxr	x9, [x10]
1000058d4:     	cbz	x9, 0x1000058f8 <_silex_function_6+0x314>
1000058d8:     	sub	x9, x9, #0x1
1000058dc:     	stlxr	w11, x9, [x10]
1000058e0:     	cbnz	w11, 0x1000058d0 <_silex_function_6+0x2ec>
1000058e4:     	cbnz	x9, 0x1000058f8 <_silex_function_6+0x314>
1000058e8:     	ldr	x1, [x10, #0x8]
1000058ec:     	mov	x0, x10
1000058f0:     	mov	w16, #0x49              ; =73
1000058f4:     	svc	#0x80
1000058f8:     	ldr	x9, [sp, #0xd8]
1000058fc:     	str	x9, [sp, #0x98]
100005900:     	mov	x16, x9
100005904:     	ldr	x10, [sp, #0x98]
100005908:     	add	x14, x10, #0x8
10000590c:     	ldaxr	x9, [x14]
100005910:     	cbz	x9, 0x100005968 <_silex_function_6+0x384>
100005914:     	sub	x9, x9, #0x1
100005918:     	stlxr	w11, x9, [x14]
10000591c:     	cbnz	w11, 0x10000590c <_silex_function_6+0x328>
100005920:     	ldr	x11, [x10, #0x10]
100005924:     	add	x9, x9, x11
100005928:     	cbnz	x9, 0x100005968 <_silex_function_6+0x384>
10000592c:     	add	x14, x10, #0x20
100005930:     	ldaxr	x9, [x14]
100005934:     	mov	x11, #0x2               ; =2
100005938:     	cmp	x9, x11
10000593c:     	b.eq	0x100005930 <_silex_function_6+0x34c>
100005940:     	mov	x11, #0x1               ; =1
100005944:     	cmp	x9, x11
100005948:     	b.eq	0x100005968 <_silex_function_6+0x384>
10000594c:     	mov	x9, #0x1                ; =1
100005950:     	stlxr	w11, x9, [x14]
100005954:     	cbnz	w11, 0x100005930 <_silex_function_6+0x34c>
100005958:     	ldr	x1, [x10, #0x18]
10000595c:     	mov	x0, x10
100005960:     	mov	w16, #0x49              ; =73
100005964:     	svc	#0x80
100005968:     	ldr	x0, [sp, #0x90]
10000596c:     	mov	w8, #0x0                ; =0
100005970:     	b	0x100005c14 <_silex_function_6+0x630>
100005974:     	adrp	x9, 0x100009000 <_main+0x1b80>
100005978:     	add	x9, x9, #0x8a0
10000597c:     	str	x9, [sp, #0xa0]
100005980:     	mov	w0, #0x2                ; =2
100005984:     	adrp	x1, 0x100009000 <_main+0x1b80>
100005988:     	add	x1, x1, #0x8e0
10000598c:     	mov	x2, #0x9e               ; =158
100005990:     	movk	x2, #0x0, lsl #16
100005994:     	movk	x2, #0x0, lsl #32
100005998:     	movk	x2, #0x0, lsl #48
10000599c:     	mov	w16, #0x4               ; =4
1000059a0:     	svc	#0x80
1000059a4:     	ldr	x9, [sp, #0xa0]
1000059a8:     	ldr	x2, [x9]
1000059ac:     	mov	x10, #0xffff            ; =65535
1000059b0:     	movk	x10, #0xffff, lsl #16
1000059b4:     	movk	x10, #0xffff, lsl #32
1000059b8:     	movk	x10, #0x7fff, lsl #48
1000059bc:     	and	x2, x2, x10
1000059c0:     	add	x1, x9, #0x8
1000059c4:     	mov	w0, #0x2                ; =2
1000059c8:     	mov	w16, #0x4               ; =4
1000059cc:     	svc	#0x80
1000059d0:     	mov	w0, #0x2                ; =2
1000059d4:     	adrp	x1, 0x100008000 <_main+0xb80>
1000059d8:     	add	x1, x1, #0xf10
1000059dc:     	mov	x2, #0x1                ; =1
1000059e0:     	movk	x2, #0x0, lsl #16
1000059e4:     	movk	x2, #0x0, lsl #32
1000059e8:     	movk	x2, #0x0, lsl #48
1000059ec:     	mov	w16, #0x4               ; =4
1000059f0:     	svc	#0x80
1000059f4:     	mov	w8, #0x3                ; =3
1000059f8:     	b	0x100005c14 <_silex_function_6+0x630>
1000059fc:     	ldr	x9, [sp, #0xd8]
100005a00:     	str	x9, [sp, #0xa8]
100005a04:     	mov	x16, x9
100005a08:     	ldr	x10, [sp, #0xa8]
100005a0c:     	ldr	x13, [x10]
100005a10:     	mov	w9, #0x0                ; =0
100005a14:     	mov	x12, x13
100005a18:     	add	x12, x12, #0x1
100005a1c:     	ldr	x11, [x10, #0x8]
100005a20:     	ldr	x5, [x10, #0x10]
100005a24:     	add	x11, x11, x5
100005a28:     	mov	x5, #0x1                ; =1
100005a2c:     	cmp	x11, x5
100005a30:     	b.ne	0x100005a70 <_silex_function_6+0x48c>
100005a34:     	mov	x11, #0x8               ; =8
100005a38:     	mul	x5, x12, x11
100005a3c:     	add	x5, x5, #0x28
100005a40:     	ldr	x11, [x10, #0x18]
100005a44:     	cmp	x5, x11
100005a48:     	b.hi	0x100005a70 <_silex_function_6+0x48c>
100005a4c:     	add	x14, x10, #0x28
100005a50:     	mov	x11, #0x8               ; =8
100005a54:     	mul	x5, x13, x11
100005a58:     	add	x14, x14, x5
100005a5c:     	ldr	x5, [sp, #0x28]
100005a60:     	str	x5, [x14]
100005a64:     	str	x12, [x10]
100005a68:     	str	x10, [sp, #0xb0]
100005a6c:     	b	0x100005bd8 <_silex_function_6+0x5f4>
100005a70:     	sub	sp, sp, #0x30
100005a74:     	str	x10, [sp]
100005a78:     	str	x13, [sp, #0x8]
100005a7c:     	str	x9, [sp, #0x10]
100005a80:     	str	x12, [sp, #0x18]
100005a84:     	str	x7, [sp, #0x20]
100005a88:     	str	x6, [sp, #0x28]
100005a8c:     	mov	x11, #0x8               ; =8
100005a90:     	mul	x1, x12, x11
100005a94:     	add	x1, x1, #0x28
100005a98:     	mov	x5, #0x4000             ; =16384
100005a9c:     	cmp	x1, x5
100005aa0:     	b.hs	0x100005aa8 <_silex_function_6+0x4c4>
100005aa4:     	mov	x1, x5
100005aa8:     	add	x1, x1, x1
100005aac:     	mov	w0, #0x0                ; =0
100005ab0:     	mov	w2, #0x3                ; =3
100005ab4:     	mov	w3, #0x1002             ; =4098
100005ab8:     	mov	x4, #0xffff             ; =65535
100005abc:     	movk	x4, #0xffff, lsl #16
100005ac0:     	movk	x4, #0xffff, lsl #32
100005ac4:     	movk	x4, #0xffff, lsl #48
100005ac8:     	mov	w5, #0x0                ; =0
100005acc:     	mov	w16, #0xc5              ; =197
100005ad0:     	svc	#0x80
100005ad4:     	b.hs	0x100005bdc <_silex_function_6+0x5f8>
100005ad8:     	mov	x15, x0
100005adc:     	ldr	x10, [sp]
100005ae0:     	ldr	x13, [sp, #0x8]
100005ae4:     	ldr	x9, [sp, #0x10]
100005ae8:     	ldr	x12, [sp, #0x18]
100005aec:     	ldr	x7, [sp, #0x20]
100005af0:     	ldr	x6, [sp, #0x28]
100005af4:     	str	x12, [x15]
100005af8:     	mov	x5, #0x1                ; =1
100005afc:     	str	x5, [x15, #0x8]
100005b00:     	mov	x11, #0x8               ; =8
100005b04:     	mul	x11, x12, x11
100005b08:     	add	x11, x11, #0x28
100005b0c:     	mov	x5, #0x4000             ; =16384
100005b10:     	cmp	x11, x5
100005b14:     	b.hs	0x100005b1c <_silex_function_6+0x538>
100005b18:     	mov	x11, x5
100005b1c:     	add	x11, x11, x11
100005b20:     	str	x11, [x15, #0x18]
100005b24:     	add	x10, x10, #0x28
100005b28:     	add	x14, x15, #0x28
100005b2c:     	mov	x11, #0x1               ; =1
100005b30:     	mul	x12, x13, x11
100005b34:     	cbz	x12, 0x100005b50 <_silex_function_6+0x56c>
100005b38:     	ldr	x11, [x10]
100005b3c:     	str	x11, [x14]
100005b40:     	add	x10, x10, #0x8
100005b44:     	add	x14, x14, #0x8
100005b48:     	sub	x12, x12, #0x1
100005b4c:     	cbnz	x12, 0x100005b38 <_silex_function_6+0x554>
100005b50:     	add	sp, sp, #0x30
100005b54:     	mov	x9, x13
100005b58:     	add	x14, x15, #0x28
100005b5c:     	mov	x11, #0x8               ; =8
100005b60:     	mul	x9, x9, x11
100005b64:     	add	x14, x14, x9
100005b68:     	ldr	x12, [sp, #0x28]
100005b6c:     	str	x12, [x14]
100005b70:     	str	x15, [sp, #0xb0]
100005b74:     	ldr	x10, [sp, #0xa8]
100005b78:     	add	x14, x10, #0x8
100005b7c:     	ldaxr	x9, [x14]
100005b80:     	cbz	x9, 0x100005bd8 <_silex_function_6+0x5f4>
100005b84:     	sub	x9, x9, #0x1
100005b88:     	stlxr	w11, x9, [x14]
100005b8c:     	cbnz	w11, 0x100005b7c <_silex_function_6+0x598>
100005b90:     	ldr	x11, [x10, #0x10]
100005b94:     	add	x9, x9, x11
100005b98:     	cbnz	x9, 0x100005bd8 <_silex_function_6+0x5f4>
100005b9c:     	add	x14, x10, #0x20
100005ba0:     	ldaxr	x9, [x14]
100005ba4:     	mov	x11, #0x2               ; =2
100005ba8:     	cmp	x9, x11
100005bac:     	b.eq	0x100005ba0 <_silex_function_6+0x5bc>
100005bb0:     	mov	x11, #0x1               ; =1
100005bb4:     	cmp	x9, x11
100005bb8:     	b.eq	0x100005bd8 <_silex_function_6+0x5f4>
100005bbc:     	mov	x9, #0x1                ; =1
100005bc0:     	stlxr	w11, x9, [x14]
100005bc4:     	cbnz	w11, 0x100005ba0 <_silex_function_6+0x5bc>
100005bc8:     	ldr	x1, [x10, #0x18]
100005bcc:     	mov	x0, x10
100005bd0:     	mov	w16, #0x49              ; =73
100005bd4:     	svc	#0x80
100005bd8:     	b	0x100005be8 <_silex_function_6+0x604>
100005bdc:     	add	sp, sp, #0x30
100005be0:     	mov	w8, #0x3                ; =3
100005be4:     	b	0x100005c14 <_silex_function_6+0x630>
100005be8:     	ldr	x9, [sp, #0xb0]
100005bec:     	str	x9, [sp, #0xd8]
100005bf0:     	mov	x16, x9
100005bf4:     	ldr	x9, [sp, #0xd0]
100005bf8:     	add	x11, x9, #0x1
100005bfc:     	str	x11, [sp, #0xc0]
100005c00:     	mov	x17, x11
100005c04:     	mov	x9, x17
100005c08:     	str	x9, [sp, #0xd0]
100005c0c:     	mov	x16, x9
100005c10:     	b	0x100005678 <_silex_function_6+0x94>
100005c14:     	add	sp, sp, #0xe0
100005c18:     	ldp	x29, x30, [sp], #0x10
100005c1c:     	ret
100005c20:     	mov	w8, #0x1                ; =1
100005c24:     	b	0x100005c14 <_silex_function_6+0x630>
100005c28:     	mov	w8, #0x2                ; =2
100005c2c:     	b	0x100005c14 <_silex_function_6+0x630>

0000000100005c30 <_silex_function_7>:
100005c30:     	stp	x29, x30, [sp, #-0x10]!
100005c34:     	mov	x29, sp
100005c38:     	sub	sp, sp, #0x390
100005c3c:     	str	x15, [sp, #0x10]
100005c40:     	str	x0, [sp]
100005c44:     	str	x1, [sp, #0x8]
100005c48:     	movz	x9, #0x0, lsl #48
100005c4c:     	str	x9, [sp, #0x18]
100005c50:     	mov	x16, x9
100005c54:     	mov	x9, x16
100005c58:     	str	x9, [sp, #0x370]
100005c5c:     	mov	x17, x9
100005c60:     	ldr	x10, [sp, #0x8]
100005c64:     	str	x10, [sp, #0x20]
100005c68:     	ldr	x9, [sp, #0x370]
100005c6c:     	ldr	x10, [sp, #0x20]
100005c70:     	cmp	x9, x10
100005c74:     	mov	w11, #0x0               ; =0
100005c78:     	b.ge	0x100005c80 <_silex_function_7+0x50>
100005c7c:     	mov	w11, #0x1               ; =1
100005c80:     	str	x11, [sp, #0x28]
100005c84:     	mov	x16, x11
100005c88:     	ldr	x9, [sp, #0x28]
100005c8c:     	cbz	w9, 0x100005e88 <_silex_function_7+0x258>
100005c90:     	ldr	x10, [sp]
100005c94:     	ldr	x13, [sp, #0x8]
100005c98:     	ldr	x9, [sp, #0x370]
100005c9c:     	cmp	x9, xzr
100005ca0:     	b.ge	0x100005ca8 <_silex_function_7+0x78>
100005ca4:     	add	x9, x9, x13
100005ca8:     	cmp	x9, xzr
100005cac:     	b.lt	0x100005cc8 <_silex_function_7+0x98>
100005cb0:     	cmp	x9, x13
100005cb4:     	b.ge	0x100005cc8 <_silex_function_7+0x98>
100005cb8:     	add	x10, x10, x9, lsl #3
100005cbc:     	ldr	x12, [x10]
100005cc0:     	str	x12, [sp, #0x30]
100005cc4:     	b	0x100005e4c <_silex_function_7+0x21c>
100005cc8:     	str	x13, [sp, #0x30]
100005ccc:     	mov	w0, #0x2                ; =2
100005cd0:     	adrp	x1, 0x100009000 <_main+0x1b80>
100005cd4:     	add	x1, x1, #0xa40
100005cd8:     	mov	x2, #0xa2               ; =162
100005cdc:     	movk	x2, #0x0, lsl #16
100005ce0:     	movk	x2, #0x0, lsl #32
100005ce4:     	movk	x2, #0x0, lsl #48
100005ce8:     	mov	w16, #0x4               ; =4
100005cec:     	svc	#0x80
100005cf0:     	ldr	x9, [sp, #0x370]
100005cf4:     	sub	sp, sp, #0x20
100005cf8:     	add	x11, sp, #0x20
100005cfc:     	mov	w12, #0x0               ; =0
100005d00:     	cbnz	x9, 0x100005d18 <_silex_function_7+0xe8>
100005d04:     	sub	x11, x11, #0x1
100005d08:     	mov	w10, #0x30              ; =48
100005d0c:     	strb	w10, [x11]
100005d10:     	add	x12, x12, #0x1
100005d14:     	b	0x100005d6c <_silex_function_7+0x13c>
100005d18:     	mov	w3, #0x0                ; =0
100005d1c:     	cmp	x9, xzr
100005d20:     	b.lt	0x100005d2c <_silex_function_7+0xfc>
100005d24:     	negs	x9, x9
100005d28:     	b	0x100005d30 <_silex_function_7+0x100>
100005d2c:     	mov	w3, #0x1                ; =1
100005d30:     	mov	w10, #0xa               ; =10
100005d34:     	sdiv	x4, x9, x10
100005d38:     	msub	x5, x4, x10, x9
100005d3c:     	mov	w6, #0x30               ; =48
100005d40:     	subs	x6, x6, x5
100005d44:     	sub	x11, x11, #0x1
100005d48:     	strb	w6, [x11]
100005d4c:     	add	x12, x12, #0x1
100005d50:     	mov	x9, x4
100005d54:     	cbnz	x9, 0x100005d30 <_silex_function_7+0x100>
100005d58:     	cbz	w3, 0x100005d6c <_silex_function_7+0x13c>
100005d5c:     	sub	x11, x11, #0x1
100005d60:     	mov	w10, #0x2d              ; =45
100005d64:     	strb	w10, [x11]
100005d68:     	add	x12, x12, #0x1
100005d6c:     	mov	w0, #0x2                ; =2
100005d70:     	mov	x1, x11
100005d74:     	mov	x2, x12
100005d78:     	mov	w16, #0x4               ; =4
100005d7c:     	svc	#0x80
100005d80:     	add	sp, sp, #0x20
100005d84:     	mov	w0, #0x2                ; =2
100005d88:     	adrp	x1, 0x100009000 <_main+0x1b80>
100005d8c:     	add	x1, x1, #0x178
100005d90:     	mov	x2, #0x1c               ; =28
100005d94:     	movk	x2, #0x0, lsl #16
100005d98:     	movk	x2, #0x0, lsl #32
100005d9c:     	movk	x2, #0x0, lsl #48
100005da0:     	mov	w16, #0x4               ; =4
100005da4:     	svc	#0x80
100005da8:     	ldr	x9, [sp, #0x30]
100005dac:     	sub	sp, sp, #0x20
100005db0:     	add	x11, sp, #0x1f
100005db4:     	mov	w10, #0xa               ; =10
100005db8:     	strb	w10, [x11]
100005dbc:     	mov	w12, #0x1               ; =1
100005dc0:     	cbnz	x9, 0x100005dd8 <_silex_function_7+0x1a8>
100005dc4:     	sub	x11, x11, #0x1
100005dc8:     	mov	w10, #0x30              ; =48
100005dcc:     	strb	w10, [x11]
100005dd0:     	add	x12, x12, #0x1
100005dd4:     	b	0x100005e2c <_silex_function_7+0x1fc>
100005dd8:     	mov	w3, #0x0                ; =0
100005ddc:     	cmp	x9, xzr
100005de0:     	b.lt	0x100005dec <_silex_function_7+0x1bc>
100005de4:     	negs	x9, x9
100005de8:     	b	0x100005df0 <_silex_function_7+0x1c0>
100005dec:     	mov	w3, #0x1                ; =1
100005df0:     	mov	w10, #0xa               ; =10
100005df4:     	sdiv	x4, x9, x10
100005df8:     	msub	x5, x4, x10, x9
100005dfc:     	mov	w6, #0x30               ; =48
100005e00:     	subs	x6, x6, x5
100005e04:     	sub	x11, x11, #0x1
100005e08:     	strb	w6, [x11]
100005e0c:     	add	x12, x12, #0x1
100005e10:     	mov	x9, x4
100005e14:     	cbnz	x9, 0x100005df0 <_silex_function_7+0x1c0>
100005e18:     	cbz	w3, 0x100005e2c <_silex_function_7+0x1fc>
100005e1c:     	sub	x11, x11, #0x1
100005e20:     	mov	w10, #0x2d              ; =45
100005e24:     	strb	w10, [x11]
100005e28:     	add	x12, x12, #0x1
100005e2c:     	mov	w0, #0x2                ; =2
100005e30:     	mov	x1, x11
100005e34:     	mov	x2, x12
100005e38:     	mov	w16, #0x4               ; =4
100005e3c:     	svc	#0x80
100005e40:     	add	sp, sp, #0x20
100005e44:     	mov	w8, #0x3                ; =3
100005e48:     	b	0x100006b60 <_silex_function_7+0xf30>
100005e4c:     	mov	x9, #0x7f               ; =127
100005e50:     	str	x9, [sp, #0x38]
100005e54:     	mov	x16, x9
100005e58:     	ldr	x9, [sp, #0x30]
100005e5c:     	ldr	x10, [sp, #0x38]
100005e60:     	cmp	x9, x10
100005e64:     	mov	w11, #0x0               ; =0
100005e68:     	b.hi	0x100005e70 <_silex_function_7+0x240>
100005e6c:     	mov	w11, #0x1               ; =1
100005e70:     	str	x11, [sp, #0x40]
100005e74:     	mov	x17, x11
100005e78:     	ldr	x9, [sp, #0x40]
100005e7c:     	cbz	w9, 0x100005e84 <_silex_function_7+0x254>
100005e80:     	b	0x100005fc0 <_silex_function_7+0x390>
100005e84:     	b	0x100005fe4 <_silex_function_7+0x3b4>
100005e88:     	ldr	x10, [sp]
100005e8c:     	ldr	x11, [sp, #0x8]
100005e90:     	mov	w9, #0x18               ; =24
100005e94:     	adds	x1, x11, x9
100005e98:     	b.hs	0x100005f3c <_silex_function_7+0x30c>
100005e9c:     	sub	sp, sp, #0x20
100005ea0:     	str	x10, [sp]
100005ea4:     	str	x11, [sp, #0x8]
100005ea8:     	mov	w0, #0x0                ; =0
100005eac:     	mov	w2, #0x3                ; =3
100005eb0:     	mov	w3, #0x1002             ; =4098
100005eb4:     	mov	x4, #0xffff             ; =65535
100005eb8:     	movk	x4, #0xffff, lsl #16
100005ebc:     	movk	x4, #0xffff, lsl #32
100005ec0:     	movk	x4, #0xffff, lsl #48
100005ec4:     	mov	w5, #0x0                ; =0
100005ec8:     	mov	w16, #0xc5              ; =197
100005ecc:     	svc	#0x80
100005ed0:     	b.hs	0x100005f38 <_silex_function_7+0x308>
100005ed4:     	mov	x15, x0
100005ed8:     	ldr	x10, [sp, #0x8]
100005edc:     	mov	w9, #0x1                ; =1
100005ee0:     	str	x9, [x15]
100005ee4:     	add	x9, x10, #0x18
100005ee8:     	str	x9, [x15, #0x8]
100005eec:     	add	x15, x15, #0x10
100005ef0:     	mov	x9, #0x0                ; =0
100005ef4:     	movk	x9, #0x0, lsl #16
100005ef8:     	movk	x9, #0x0, lsl #32
100005efc:     	movk	x9, #0x8000, lsl #48
100005f00:     	add	x9, x10, x9
100005f04:     	str	x9, [x15]
100005f08:     	ldr	x11, [sp]
100005f0c:     	add	x12, x15, #0x8
100005f10:     	cbz	x10, 0x100005f2c <_silex_function_7+0x2fc>
100005f14:     	ldrb	w9, [x11]
100005f18:     	strb	w9, [x12]
100005f1c:     	add	x11, x11, #0x8
100005f20:     	add	x12, x12, #0x1
100005f24:     	sub	x10, x10, #0x1
100005f28:     	cbnz	x10, 0x100005f14 <_silex_function_7+0x2e4>
100005f2c:     	add	sp, sp, #0x20
100005f30:     	str	x15, [sp, #0x350]
100005f34:     	b	0x100005f44 <_silex_function_7+0x314>
100005f38:     	add	sp, sp, #0x20
100005f3c:     	mov	w8, #0x3                ; =3
100005f40:     	b	0x100006b60 <_silex_function_7+0xf30>
100005f44:     	ldr	x10, [sp, #0x350]
100005f48:     	ldr	x9, [x10]
100005f4c:     	mov	x11, #0x0               ; =0
100005f50:     	movk	x11, #0x0, lsl #16
100005f54:     	movk	x11, #0x0, lsl #32
100005f58:     	movk	x11, #0x8000, lsl #48
100005f5c:     	and	x9, x9, x11
100005f60:     	cbz	x9, 0x100005f78 <_silex_function_7+0x348>
100005f64:     	sub	x10, x10, #0x10
100005f68:     	ldaxr	x9, [x10]
100005f6c:     	add	x9, x9, #0x1
100005f70:     	stlxr	w11, x9, [x10]
100005f74:     	cbnz	w11, 0x100005f68 <_silex_function_7+0x338>
100005f78:     	movz	x9, #0x0, lsl #48
100005f7c:     	str	x9, [sp, #0x358]
100005f80:     	mov	w9, #0x0                ; =0
100005f84:     	str	x9, [sp, #0x360]
100005f88:     	mov	w9, #0x0                ; =0
100005f8c:     	str	x9, [sp, #0x368]
100005f90:     	ldr	x9, [sp, #0x350]
100005f94:     	str	x9, [sp, #0x360]
100005f98:     	ldr	x14, [sp, #0x10]
100005f9c:     	ldr	x9, [sp, #0x358]
100005fa0:     	str	x9, [x14]
100005fa4:     	ldr	x9, [sp, #0x360]
100005fa8:     	str	x9, [x14, #0x8]
100005fac:     	ldr	x9, [sp, #0x368]
100005fb0:     	str	x9, [x14, #0x10]
100005fb4:     	mov	x0, #0x0                ; =0
100005fb8:     	mov	w8, #0x0                ; =0
100005fbc:     	b	0x100006b60 <_silex_function_7+0xf30>
100005fc0:     	ldr	x9, [sp, #0x370]
100005fc4:     	adds	x11, x9, #0x1
100005fc8:     	b.vs	0x100006b6c <_silex_function_7+0xf3c>
100005fcc:     	str	x11, [sp, #0x50]
100005fd0:     	mov	x16, x11
100005fd4:     	mov	x9, x16
100005fd8:     	str	x9, [sp, #0x370]
100005fdc:     	mov	x17, x9
100005fe0:     	b	0x100005c60 <_silex_function_7+0x30>
100005fe4:     	mov	x9, #0xc2               ; =194
100005fe8:     	str	x9, [sp, #0x58]
100005fec:     	mov	x16, x9
100005ff0:     	ldr	x9, [sp, #0x30]
100005ff4:     	ldr	x10, [sp, #0x58]
100005ff8:     	cmp	x9, x10
100005ffc:     	mov	w11, #0x0               ; =0
100006000:     	b.lo	0x100006008 <_silex_function_7+0x3d8>
100006004:     	mov	w11, #0x1               ; =1
100006008:     	str	x11, [sp, #0x60]
10000600c:     	mov	x17, x11
100006010:     	ldr	x9, [sp, #0x60]
100006014:     	cbz	w9, 0x100006068 <_silex_function_7+0x438>
100006018:     	mov	x9, #0xdf               ; =223
10000601c:     	str	x9, [sp, #0x68]
100006020:     	mov	x16, x9
100006024:     	ldr	x9, [sp, #0x30]
100006028:     	ldr	x10, [sp, #0x68]
10000602c:     	cmp	x9, x10
100006030:     	mov	w11, #0x0               ; =0
100006034:     	b.hi	0x10000603c <_silex_function_7+0x40c>
100006038:     	mov	w11, #0x1               ; =1
10000603c:     	str	x11, [sp, #0x70]
100006040:     	mov	x17, x11
100006044:     	ldr	x9, [sp, #0x70]
100006048:     	cbz	w9, 0x100006068 <_silex_function_7+0x438>
10000604c:     	mov	x9, #0x2                ; =2
100006050:     	str	x9, [sp, #0x78]
100006054:     	mov	x16, x9
100006058:     	mov	x9, x16
10000605c:     	str	x9, [sp, #0x378]
100006060:     	mov	x17, x9
100006064:     	b	0x10000631c <_silex_function_7+0x6ec>
100006068:     	mov	x9, #0xe0               ; =224
10000606c:     	str	x9, [sp, #0x80]
100006070:     	mov	x16, x9
100006074:     	ldr	x9, [sp, #0x30]
100006078:     	ldr	x10, [sp, #0x80]
10000607c:     	cmp	x9, x10
100006080:     	mov	w11, #0x0               ; =0
100006084:     	b.lo	0x10000608c <_silex_function_7+0x45c>
100006088:     	mov	w11, #0x1               ; =1
10000608c:     	str	x11, [sp, #0x88]
100006090:     	mov	x17, x11
100006094:     	ldr	x9, [sp, #0x88]
100006098:     	cbz	w9, 0x1000060ec <_silex_function_7+0x4bc>
10000609c:     	mov	x9, #0xef               ; =239
1000060a0:     	str	x9, [sp, #0x90]
1000060a4:     	mov	x16, x9
1000060a8:     	ldr	x9, [sp, #0x30]
1000060ac:     	ldr	x10, [sp, #0x90]
1000060b0:     	cmp	x9, x10
1000060b4:     	mov	w11, #0x0               ; =0
1000060b8:     	b.hi	0x1000060c0 <_silex_function_7+0x490>
1000060bc:     	mov	w11, #0x1               ; =1
1000060c0:     	str	x11, [sp, #0x98]
1000060c4:     	mov	x17, x11
1000060c8:     	ldr	x9, [sp, #0x98]
1000060cc:     	cbz	w9, 0x1000060ec <_silex_function_7+0x4bc>
1000060d0:     	mov	x9, #0x3                ; =3
1000060d4:     	str	x9, [sp, #0xa0]
1000060d8:     	mov	x16, x9
1000060dc:     	mov	x9, x16
1000060e0:     	str	x9, [sp, #0x378]
1000060e4:     	mov	x17, x9
1000060e8:     	b	0x10000631c <_silex_function_7+0x6ec>
1000060ec:     	mov	x9, #0xf0               ; =240
1000060f0:     	str	x9, [sp, #0xa8]
1000060f4:     	mov	x16, x9
1000060f8:     	ldr	x9, [sp, #0x30]
1000060fc:     	ldr	x10, [sp, #0xa8]
100006100:     	cmp	x9, x10
100006104:     	mov	w11, #0x0               ; =0
100006108:     	b.lo	0x100006110 <_silex_function_7+0x4e0>
10000610c:     	mov	w11, #0x1               ; =1
100006110:     	str	x11, [sp, #0xb0]
100006114:     	mov	x17, x11
100006118:     	ldr	x9, [sp, #0xb0]
10000611c:     	cbz	w9, 0x100006170 <_silex_function_7+0x540>
100006120:     	mov	x9, #0xf4               ; =244
100006124:     	str	x9, [sp, #0xb8]
100006128:     	mov	x16, x9
10000612c:     	ldr	x9, [sp, #0x30]
100006130:     	ldr	x10, [sp, #0xb8]
100006134:     	cmp	x9, x10
100006138:     	mov	w11, #0x0               ; =0
10000613c:     	b.hi	0x100006144 <_silex_function_7+0x514>
100006140:     	mov	w11, #0x1               ; =1
100006144:     	str	x11, [sp, #0xc0]
100006148:     	mov	x17, x11
10000614c:     	ldr	x9, [sp, #0xc0]
100006150:     	cbz	w9, 0x100006170 <_silex_function_7+0x540>
100006154:     	mov	x9, #0x4                ; =4
100006158:     	str	x9, [sp, #0xc8]
10000615c:     	mov	x16, x9
100006160:     	mov	x9, x16
100006164:     	str	x9, [sp, #0x378]
100006168:     	mov	x17, x9
10000616c:     	b	0x10000631c <_silex_function_7+0x6ec>
100006170:     	mov	x9, #0xc0               ; =192
100006174:     	str	x9, [sp, #0xd0]
100006178:     	mov	x16, x9
10000617c:     	ldr	x9, [sp, #0x30]
100006180:     	ldr	x10, [sp, #0xd0]
100006184:     	cmp	x9, x10
100006188:     	mov	w11, #0x0               ; =0
10000618c:     	b.ne	0x100006194 <_silex_function_7+0x564>
100006190:     	mov	w11, #0x1               ; =1
100006194:     	str	x11, [sp, #0xd8]
100006198:     	mov	x17, x11
10000619c:     	ldr	x9, [sp, #0xd8]
1000061a0:     	cbnz	w9, 0x1000061e0 <_silex_function_7+0x5b0>
1000061a4:     	mov	x9, #0xc1               ; =193
1000061a8:     	str	x9, [sp, #0xe8]
1000061ac:     	mov	x16, x9
1000061b0:     	ldr	x9, [sp, #0x30]
1000061b4:     	ldr	x10, [sp, #0xe8]
1000061b8:     	cmp	x9, x10
1000061bc:     	mov	w11, #0x0               ; =0
1000061c0:     	b.ne	0x1000061c8 <_silex_function_7+0x598>
1000061c4:     	mov	w11, #0x1               ; =1
1000061c8:     	str	x11, [sp, #0xf0]
1000061cc:     	mov	x17, x11
1000061d0:     	mov	x9, x17
1000061d4:     	str	x9, [sp, #0xe0]
1000061d8:     	mov	x16, x9
1000061dc:     	b	0x1000061ec <_silex_function_7+0x5bc>
1000061e0:     	mov	w9, #0x1                ; =1
1000061e4:     	str	x9, [sp, #0xe0]
1000061e8:     	mov	x16, x9
1000061ec:     	ldr	x9, [sp, #0xe0]
1000061f0:     	cbz	w9, 0x100006234 <_silex_function_7+0x604>
1000061f4:     	mov	x9, #0x3                ; =3
1000061f8:     	str	x9, [sp, #0xf8]
1000061fc:     	ldr	x0, [sp, #0xf8]
100006200:     	ldr	x1, [sp, #0x370]
100006204:     	add	x15, sp, #0x100
100006208:     	bl	0x100006b7c <_silex_function_8>
10000620c:     	ldr	x14, [sp, #0x10]
100006210:     	ldr	x9, [sp, #0x100]
100006214:     	str	x9, [x14]
100006218:     	ldr	x9, [sp, #0x108]
10000621c:     	str	x9, [x14, #0x8]
100006220:     	ldr	x9, [sp, #0x110]
100006224:     	str	x9, [x14, #0x10]
100006228:     	mov	x0, #0x0                ; =0
10000622c:     	mov	w8, #0x0                ; =0
100006230:     	b	0x100006b60 <_silex_function_7+0xf30>
100006234:     	mov	x9, #0xf5               ; =245
100006238:     	str	x9, [sp, #0x118]
10000623c:     	mov	x16, x9
100006240:     	ldr	x9, [sp, #0x30]
100006244:     	ldr	x10, [sp, #0x118]
100006248:     	cmp	x9, x10
10000624c:     	mov	w11, #0x0               ; =0
100006250:     	b.lo	0x100006258 <_silex_function_7+0x628>
100006254:     	mov	w11, #0x1               ; =1
100006258:     	str	x11, [sp, #0x120]
10000625c:     	mov	x17, x11
100006260:     	ldr	x9, [sp, #0x120]
100006264:     	cbz	w9, 0x1000062dc <_silex_function_7+0x6ac>
100006268:     	mov	x9, #0xf7               ; =247
10000626c:     	str	x9, [sp, #0x128]
100006270:     	mov	x16, x9
100006274:     	ldr	x9, [sp, #0x30]
100006278:     	ldr	x10, [sp, #0x128]
10000627c:     	cmp	x9, x10
100006280:     	mov	w11, #0x0               ; =0
100006284:     	b.hi	0x10000628c <_silex_function_7+0x65c>
100006288:     	mov	w11, #0x1               ; =1
10000628c:     	str	x11, [sp, #0x130]
100006290:     	mov	x17, x11
100006294:     	ldr	x9, [sp, #0x130]
100006298:     	cbz	w9, 0x1000062dc <_silex_function_7+0x6ac>
10000629c:     	mov	x9, #0x5                ; =5
1000062a0:     	str	x9, [sp, #0x138]
1000062a4:     	ldr	x0, [sp, #0x138]
1000062a8:     	ldr	x1, [sp, #0x370]
1000062ac:     	add	x15, sp, #0x140
1000062b0:     	bl	0x100006b7c <_silex_function_8>
1000062b4:     	ldr	x14, [sp, #0x10]
1000062b8:     	ldr	x9, [sp, #0x140]
1000062bc:     	str	x9, [x14]
1000062c0:     	ldr	x9, [sp, #0x148]
1000062c4:     	str	x9, [x14, #0x8]
1000062c8:     	ldr	x9, [sp, #0x150]
1000062cc:     	str	x9, [x14, #0x10]
1000062d0:     	mov	x0, #0x0                ; =0
1000062d4:     	mov	w8, #0x0                ; =0
1000062d8:     	b	0x100006b60 <_silex_function_7+0xf30>
1000062dc:     	movz	x9, #0x0, lsl #48
1000062e0:     	str	x9, [sp, #0x158]
1000062e4:     	ldr	x0, [sp, #0x158]
1000062e8:     	ldr	x1, [sp, #0x370]
1000062ec:     	add	x15, sp, #0x160
1000062f0:     	bl	0x100006b7c <_silex_function_8>
1000062f4:     	ldr	x14, [sp, #0x10]
1000062f8:     	ldr	x9, [sp, #0x160]
1000062fc:     	str	x9, [x14]
100006300:     	ldr	x9, [sp, #0x168]
100006304:     	str	x9, [x14, #0x8]
100006308:     	ldr	x9, [sp, #0x170]
10000630c:     	str	x9, [x14, #0x10]
100006310:     	mov	x0, #0x0                ; =0
100006314:     	mov	w8, #0x0                ; =0
100006318:     	b	0x100006b60 <_silex_function_7+0xf30>
10000631c:     	ldr	x9, [sp, #0x370]
100006320:     	ldr	x10, [sp, #0x378]
100006324:     	adds	x11, x9, x10
100006328:     	b.vs	0x100006b6c <_silex_function_7+0xf3c>
10000632c:     	str	x11, [sp, #0x178]
100006330:     	mov	x16, x11
100006334:     	ldr	x10, [sp, #0x8]
100006338:     	str	x10, [sp, #0x180]
10000633c:     	ldr	x9, [sp, #0x178]
100006340:     	ldr	x10, [sp, #0x180]
100006344:     	cmp	x9, x10
100006348:     	mov	w11, #0x0               ; =0
10000634c:     	b.le	0x100006354 <_silex_function_7+0x724>
100006350:     	mov	w11, #0x1               ; =1
100006354:     	str	x11, [sp, #0x188]
100006358:     	mov	x16, x11
10000635c:     	ldr	x9, [sp, #0x188]
100006360:     	cbz	w9, 0x1000063a4 <_silex_function_7+0x774>
100006364:     	mov	x9, #0x2                ; =2
100006368:     	str	x9, [sp, #0x190]
10000636c:     	ldr	x0, [sp, #0x190]
100006370:     	ldr	x1, [sp, #0x370]
100006374:     	add	x15, sp, #0x198
100006378:     	bl	0x100006b7c <_silex_function_8>
10000637c:     	ldr	x14, [sp, #0x10]
100006380:     	ldr	x9, [sp, #0x198]
100006384:     	str	x9, [x14]
100006388:     	ldr	x9, [sp, #0x1a0]
10000638c:     	str	x9, [x14, #0x8]
100006390:     	ldr	x9, [sp, #0x1a8]
100006394:     	str	x9, [x14, #0x10]
100006398:     	mov	x0, #0x0                ; =0
10000639c:     	mov	w8, #0x0                ; =0
1000063a0:     	b	0x100006b60 <_silex_function_7+0xf30>
1000063a4:     	mov	x9, #0x1                ; =1
1000063a8:     	str	x9, [sp, #0x1b0]
1000063ac:     	mov	x16, x9
1000063b0:     	mov	x9, x16
1000063b4:     	str	x9, [sp, #0x380]
1000063b8:     	mov	x17, x9
1000063bc:     	ldr	x9, [sp, #0x380]
1000063c0:     	ldr	x10, [sp, #0x378]
1000063c4:     	cmp	x9, x10
1000063c8:     	mov	w11, #0x0               ; =0
1000063cc:     	b.ge	0x1000063d4 <_silex_function_7+0x7a4>
1000063d0:     	mov	w11, #0x1               ; =1
1000063d4:     	str	x11, [sp, #0x1b8]
1000063d8:     	mov	x16, x11
1000063dc:     	ldr	x9, [sp, #0x1b8]
1000063e0:     	cbz	w9, 0x1000065f4 <_silex_function_7+0x9c4>
1000063e4:     	ldr	x9, [sp, #0x370]
1000063e8:     	ldr	x10, [sp, #0x380]
1000063ec:     	adds	x11, x9, x10
1000063f0:     	b.vs	0x100006b6c <_silex_function_7+0xf3c>
1000063f4:     	str	x11, [sp, #0x1c0]
1000063f8:     	mov	x16, x11
1000063fc:     	ldr	x10, [sp]
100006400:     	ldr	x13, [sp, #0x8]
100006404:     	ldr	x9, [sp, #0x1c0]
100006408:     	cmp	x9, xzr
10000640c:     	b.ge	0x100006414 <_silex_function_7+0x7e4>
100006410:     	add	x9, x9, x13
100006414:     	cmp	x9, xzr
100006418:     	b.lt	0x100006434 <_silex_function_7+0x804>
10000641c:     	cmp	x9, x13
100006420:     	b.ge	0x100006434 <_silex_function_7+0x804>
100006424:     	add	x10, x10, x9, lsl #3
100006428:     	ldr	x12, [x10]
10000642c:     	str	x12, [sp, #0x1c8]
100006430:     	b	0x1000065b8 <_silex_function_7+0x988>
100006434:     	str	x13, [sp, #0x1c8]
100006438:     	mov	w0, #0x2                ; =2
10000643c:     	adrp	x1, 0x100009000 <_main+0x1b80>
100006440:     	add	x1, x1, #0xaf0
100006444:     	mov	x2, #0xa2               ; =162
100006448:     	movk	x2, #0x0, lsl #16
10000644c:     	movk	x2, #0x0, lsl #32
100006450:     	movk	x2, #0x0, lsl #48
100006454:     	mov	w16, #0x4               ; =4
100006458:     	svc	#0x80
10000645c:     	ldr	x9, [sp, #0x1c0]
100006460:     	sub	sp, sp, #0x20
100006464:     	add	x11, sp, #0x20
100006468:     	mov	w12, #0x0               ; =0
10000646c:     	cbnz	x9, 0x100006484 <_silex_function_7+0x854>
100006470:     	sub	x11, x11, #0x1
100006474:     	mov	w10, #0x30              ; =48
100006478:     	strb	w10, [x11]
10000647c:     	add	x12, x12, #0x1
100006480:     	b	0x1000064d8 <_silex_function_7+0x8a8>
100006484:     	mov	w3, #0x0                ; =0
100006488:     	cmp	x9, xzr
10000648c:     	b.lt	0x100006498 <_silex_function_7+0x868>
100006490:     	negs	x9, x9
100006494:     	b	0x10000649c <_silex_function_7+0x86c>
100006498:     	mov	w3, #0x1                ; =1
10000649c:     	mov	w10, #0xa               ; =10
1000064a0:     	sdiv	x4, x9, x10
1000064a4:     	msub	x5, x4, x10, x9
1000064a8:     	mov	w6, #0x30               ; =48
1000064ac:     	subs	x6, x6, x5
1000064b0:     	sub	x11, x11, #0x1
1000064b4:     	strb	w6, [x11]
1000064b8:     	add	x12, x12, #0x1
1000064bc:     	mov	x9, x4
1000064c0:     	cbnz	x9, 0x10000649c <_silex_function_7+0x86c>
1000064c4:     	cbz	w3, 0x1000064d8 <_silex_function_7+0x8a8>
1000064c8:     	sub	x11, x11, #0x1
1000064cc:     	mov	w10, #0x2d              ; =45
1000064d0:     	strb	w10, [x11]
1000064d4:     	add	x12, x12, #0x1
1000064d8:     	mov	w0, #0x2                ; =2
1000064dc:     	mov	x1, x11
1000064e0:     	mov	x2, x12
1000064e4:     	mov	w16, #0x4               ; =4
1000064e8:     	svc	#0x80
1000064ec:     	add	sp, sp, #0x20
1000064f0:     	mov	w0, #0x2                ; =2
1000064f4:     	adrp	x1, 0x100009000 <_main+0x1b80>
1000064f8:     	add	x1, x1, #0x178
1000064fc:     	mov	x2, #0x1c               ; =28
100006500:     	movk	x2, #0x0, lsl #16
100006504:     	movk	x2, #0x0, lsl #32
100006508:     	movk	x2, #0x0, lsl #48
10000650c:     	mov	w16, #0x4               ; =4
100006510:     	svc	#0x80
100006514:     	ldr	x9, [sp, #0x1c8]
100006518:     	sub	sp, sp, #0x20
10000651c:     	add	x11, sp, #0x1f
100006520:     	mov	w10, #0xa               ; =10
100006524:     	strb	w10, [x11]
100006528:     	mov	w12, #0x1               ; =1
10000652c:     	cbnz	x9, 0x100006544 <_silex_function_7+0x914>
100006530:     	sub	x11, x11, #0x1
100006534:     	mov	w10, #0x30              ; =48
100006538:     	strb	w10, [x11]
10000653c:     	add	x12, x12, #0x1
100006540:     	b	0x100006598 <_silex_function_7+0x968>
100006544:     	mov	w3, #0x0                ; =0
100006548:     	cmp	x9, xzr
10000654c:     	b.lt	0x100006558 <_silex_function_7+0x928>
100006550:     	negs	x9, x9
100006554:     	b	0x10000655c <_silex_function_7+0x92c>
100006558:     	mov	w3, #0x1                ; =1
10000655c:     	mov	w10, #0xa               ; =10
100006560:     	sdiv	x4, x9, x10
100006564:     	msub	x5, x4, x10, x9
100006568:     	mov	w6, #0x30               ; =48
10000656c:     	subs	x6, x6, x5
100006570:     	sub	x11, x11, #0x1
100006574:     	strb	w6, [x11]
100006578:     	add	x12, x12, #0x1
10000657c:     	mov	x9, x4
100006580:     	cbnz	x9, 0x10000655c <_silex_function_7+0x92c>
100006584:     	cbz	w3, 0x100006598 <_silex_function_7+0x968>
100006588:     	sub	x11, x11, #0x1
10000658c:     	mov	w10, #0x2d              ; =45
100006590:     	strb	w10, [x11]
100006594:     	add	x12, x12, #0x1
100006598:     	mov	w0, #0x2                ; =2
10000659c:     	mov	x1, x11
1000065a0:     	mov	x2, x12
1000065a4:     	mov	w16, #0x4               ; =4
1000065a8:     	svc	#0x80
1000065ac:     	add	sp, sp, #0x20
1000065b0:     	mov	w8, #0x3                ; =3
1000065b4:     	b	0x100006b60 <_silex_function_7+0xf30>
1000065b8:     	mov	x9, #0x80               ; =128
1000065bc:     	str	x9, [sp, #0x1d0]
1000065c0:     	mov	x16, x9
1000065c4:     	ldr	x9, [sp, #0x1c8]
1000065c8:     	ldr	x10, [sp, #0x1d0]
1000065cc:     	cmp	x9, x10
1000065d0:     	mov	w11, #0x0               ; =0
1000065d4:     	b.hs	0x1000065dc <_silex_function_7+0x9ac>
1000065d8:     	mov	w11, #0x1               ; =1
1000065dc:     	str	x11, [sp, #0x1d8]
1000065e0:     	mov	x17, x11
1000065e4:     	ldr	x9, [sp, #0x1d8]
1000065e8:     	cbz	w9, 0x1000065f0 <_silex_function_7+0x9c0>
1000065ec:     	b	0x10000683c <_silex_function_7+0xc0c>
1000065f0:     	b	0x100006800 <_silex_function_7+0xbd0>
1000065f4:     	ldr	x9, [sp, #0x370]
1000065f8:     	adds	x11, x9, #0x1
1000065fc:     	b.vs	0x100006b6c <_silex_function_7+0xf3c>
100006600:     	str	x11, [sp, #0x238]
100006604:     	mov	x16, x11
100006608:     	ldr	x10, [sp]
10000660c:     	ldr	x13, [sp, #0x8]
100006610:     	ldr	x9, [sp, #0x238]
100006614:     	cmp	x9, xzr
100006618:     	b.ge	0x100006620 <_silex_function_7+0x9f0>
10000661c:     	add	x9, x9, x13
100006620:     	cmp	x9, xzr
100006624:     	b.lt	0x100006640 <_silex_function_7+0xa10>
100006628:     	cmp	x9, x13
10000662c:     	b.ge	0x100006640 <_silex_function_7+0xa10>
100006630:     	add	x10, x10, x9, lsl #3
100006634:     	ldr	x12, [x10]
100006638:     	str	x12, [sp, #0x240]
10000663c:     	b	0x1000067c4 <_silex_function_7+0xb94>
100006640:     	str	x13, [sp, #0x240]
100006644:     	mov	w0, #0x2                ; =2
100006648:     	adrp	x1, 0x100009000 <_main+0x1b80>
10000664c:     	add	x1, x1, #0xba0
100006650:     	mov	x2, #0xa2               ; =162
100006654:     	movk	x2, #0x0, lsl #16
100006658:     	movk	x2, #0x0, lsl #32
10000665c:     	movk	x2, #0x0, lsl #48
100006660:     	mov	w16, #0x4               ; =4
100006664:     	svc	#0x80
100006668:     	ldr	x9, [sp, #0x238]
10000666c:     	sub	sp, sp, #0x20
100006670:     	add	x11, sp, #0x20
100006674:     	mov	w12, #0x0               ; =0
100006678:     	cbnz	x9, 0x100006690 <_silex_function_7+0xa60>
10000667c:     	sub	x11, x11, #0x1
100006680:     	mov	w10, #0x30              ; =48
100006684:     	strb	w10, [x11]
100006688:     	add	x12, x12, #0x1
10000668c:     	b	0x1000066e4 <_silex_function_7+0xab4>
100006690:     	mov	w3, #0x0                ; =0
100006694:     	cmp	x9, xzr
100006698:     	b.lt	0x1000066a4 <_silex_function_7+0xa74>
10000669c:     	negs	x9, x9
1000066a0:     	b	0x1000066a8 <_silex_function_7+0xa78>
1000066a4:     	mov	w3, #0x1                ; =1
1000066a8:     	mov	w10, #0xa               ; =10
1000066ac:     	sdiv	x4, x9, x10
1000066b0:     	msub	x5, x4, x10, x9
1000066b4:     	mov	w6, #0x30               ; =48
1000066b8:     	subs	x6, x6, x5
1000066bc:     	sub	x11, x11, #0x1
1000066c0:     	strb	w6, [x11]
1000066c4:     	add	x12, x12, #0x1
1000066c8:     	mov	x9, x4
1000066cc:     	cbnz	x9, 0x1000066a8 <_silex_function_7+0xa78>
1000066d0:     	cbz	w3, 0x1000066e4 <_silex_function_7+0xab4>
1000066d4:     	sub	x11, x11, #0x1
1000066d8:     	mov	w10, #0x2d              ; =45
1000066dc:     	strb	w10, [x11]
1000066e0:     	add	x12, x12, #0x1
1000066e4:     	mov	w0, #0x2                ; =2
1000066e8:     	mov	x1, x11
1000066ec:     	mov	x2, x12
1000066f0:     	mov	w16, #0x4               ; =4
1000066f4:     	svc	#0x80
1000066f8:     	add	sp, sp, #0x20
1000066fc:     	mov	w0, #0x2                ; =2
100006700:     	adrp	x1, 0x100009000 <_main+0x1b80>
100006704:     	add	x1, x1, #0x178
100006708:     	mov	x2, #0x1c               ; =28
10000670c:     	movk	x2, #0x0, lsl #16
100006710:     	movk	x2, #0x0, lsl #32
100006714:     	movk	x2, #0x0, lsl #48
100006718:     	mov	w16, #0x4               ; =4
10000671c:     	svc	#0x80
100006720:     	ldr	x9, [sp, #0x240]
100006724:     	sub	sp, sp, #0x20
100006728:     	add	x11, sp, #0x1f
10000672c:     	mov	w10, #0xa               ; =10
100006730:     	strb	w10, [x11]
100006734:     	mov	w12, #0x1               ; =1
100006738:     	cbnz	x9, 0x100006750 <_silex_function_7+0xb20>
10000673c:     	sub	x11, x11, #0x1
100006740:     	mov	w10, #0x30              ; =48
100006744:     	strb	w10, [x11]
100006748:     	add	x12, x12, #0x1
10000674c:     	b	0x1000067a4 <_silex_function_7+0xb74>
100006750:     	mov	w3, #0x0                ; =0
100006754:     	cmp	x9, xzr
100006758:     	b.lt	0x100006764 <_silex_function_7+0xb34>
10000675c:     	negs	x9, x9
100006760:     	b	0x100006768 <_silex_function_7+0xb38>
100006764:     	mov	w3, #0x1                ; =1
100006768:     	mov	w10, #0xa               ; =10
10000676c:     	sdiv	x4, x9, x10
100006770:     	msub	x5, x4, x10, x9
100006774:     	mov	w6, #0x30               ; =48
100006778:     	subs	x6, x6, x5
10000677c:     	sub	x11, x11, #0x1
100006780:     	strb	w6, [x11]
100006784:     	add	x12, x12, #0x1
100006788:     	mov	x9, x4
10000678c:     	cbnz	x9, 0x100006768 <_silex_function_7+0xb38>
100006790:     	cbz	w3, 0x1000067a4 <_silex_function_7+0xb74>
100006794:     	sub	x11, x11, #0x1
100006798:     	mov	w10, #0x2d              ; =45
10000679c:     	strb	w10, [x11]
1000067a0:     	add	x12, x12, #0x1
1000067a4:     	mov	w0, #0x2                ; =2
1000067a8:     	mov	x1, x11
1000067ac:     	mov	x2, x12
1000067b0:     	mov	w16, #0x4               ; =4
1000067b4:     	svc	#0x80
1000067b8:     	add	sp, sp, #0x20
1000067bc:     	mov	w8, #0x3                ; =3
1000067c0:     	b	0x100006b60 <_silex_function_7+0xf30>
1000067c4:     	mov	x9, #0xe0               ; =224
1000067c8:     	str	x9, [sp, #0x248]
1000067cc:     	mov	x16, x9
1000067d0:     	ldr	x9, [sp, #0x30]
1000067d4:     	ldr	x10, [sp, #0x248]
1000067d8:     	cmp	x9, x10
1000067dc:     	mov	w11, #0x0               ; =0
1000067e0:     	b.ne	0x1000067e8 <_silex_function_7+0xbb8>
1000067e4:     	mov	w11, #0x1               ; =1
1000067e8:     	str	x11, [sp, #0x250]
1000067ec:     	mov	x17, x11
1000067f0:     	ldr	x9, [sp, #0x250]
1000067f4:     	cbz	w9, 0x1000067fc <_silex_function_7+0xbcc>
1000067f8:     	b	0x1000068cc <_silex_function_7+0xc9c>
1000067fc:     	b	0x100006940 <_silex_function_7+0xd10>
100006800:     	mov	x9, #0xbf               ; =191
100006804:     	str	x9, [sp, #0x1e8]
100006808:     	mov	x16, x9
10000680c:     	ldr	x9, [sp, #0x1c8]
100006810:     	ldr	x10, [sp, #0x1e8]
100006814:     	cmp	x9, x10
100006818:     	mov	w11, #0x0               ; =0
10000681c:     	b.ls	0x100006824 <_silex_function_7+0xbf4>
100006820:     	mov	w11, #0x1               ; =1
100006824:     	str	x11, [sp, #0x1f0]
100006828:     	mov	x17, x11
10000682c:     	mov	x9, x17
100006830:     	str	x9, [sp, #0x1e0]
100006834:     	mov	x16, x9
100006838:     	b	0x100006848 <_silex_function_7+0xc18>
10000683c:     	mov	w9, #0x1                ; =1
100006840:     	str	x9, [sp, #0x1e0]
100006844:     	mov	x16, x9
100006848:     	ldr	x9, [sp, #0x1e0]
10000684c:     	cbz	w9, 0x1000068a8 <_silex_function_7+0xc78>
100006850:     	mov	x9, #0x1                ; =1
100006854:     	str	x9, [sp, #0x1f8]
100006858:     	ldr	x9, [sp, #0x370]
10000685c:     	ldr	x10, [sp, #0x380]
100006860:     	adds	x11, x9, x10
100006864:     	b.vs	0x100006b6c <_silex_function_7+0xf3c>
100006868:     	str	x11, [sp, #0x200]
10000686c:     	mov	x16, x11
100006870:     	ldr	x0, [sp, #0x1f8]
100006874:     	ldr	x1, [sp, #0x200]
100006878:     	add	x15, sp, #0x208
10000687c:     	bl	0x100006b7c <_silex_function_8>
100006880:     	ldr	x14, [sp, #0x10]
100006884:     	ldr	x9, [sp, #0x208]
100006888:     	str	x9, [x14]
10000688c:     	ldr	x9, [sp, #0x210]
100006890:     	str	x9, [x14, #0x8]
100006894:     	ldr	x9, [sp, #0x218]
100006898:     	str	x9, [x14, #0x10]
10000689c:     	mov	x0, #0x0                ; =0
1000068a0:     	mov	w8, #0x0                ; =0
1000068a4:     	b	0x100006b60 <_silex_function_7+0xf30>
1000068a8:     	ldr	x9, [sp, #0x380]
1000068ac:     	adds	x11, x9, #0x1
1000068b0:     	b.vs	0x100006b6c <_silex_function_7+0xf3c>
1000068b4:     	str	x11, [sp, #0x228]
1000068b8:     	mov	x16, x11
1000068bc:     	mov	x9, x16
1000068c0:     	str	x9, [sp, #0x380]
1000068c4:     	mov	x17, x9
1000068c8:     	b	0x1000063bc <_silex_function_7+0x78c>
1000068cc:     	mov	x9, #0xa0               ; =160
1000068d0:     	str	x9, [sp, #0x258]
1000068d4:     	mov	x16, x9
1000068d8:     	ldr	x9, [sp, #0x240]
1000068dc:     	ldr	x10, [sp, #0x258]
1000068e0:     	cmp	x9, x10
1000068e4:     	mov	w11, #0x0               ; =0
1000068e8:     	b.hs	0x1000068f0 <_silex_function_7+0xcc0>
1000068ec:     	mov	w11, #0x1               ; =1
1000068f0:     	str	x11, [sp, #0x260]
1000068f4:     	mov	x17, x11
1000068f8:     	ldr	x9, [sp, #0x260]
1000068fc:     	cbz	w9, 0x100006940 <_silex_function_7+0xd10>
100006900:     	mov	x9, #0x3                ; =3
100006904:     	str	x9, [sp, #0x268]
100006908:     	ldr	x0, [sp, #0x268]
10000690c:     	ldr	x1, [sp, #0x370]
100006910:     	add	x15, sp, #0x270
100006914:     	bl	0x100006b7c <_silex_function_8>
100006918:     	ldr	x14, [sp, #0x10]
10000691c:     	ldr	x9, [sp, #0x270]
100006920:     	str	x9, [x14]
100006924:     	ldr	x9, [sp, #0x278]
100006928:     	str	x9, [x14, #0x8]
10000692c:     	ldr	x9, [sp, #0x280]
100006930:     	str	x9, [x14, #0x10]
100006934:     	mov	x0, #0x0                ; =0
100006938:     	mov	w8, #0x0                ; =0
10000693c:     	b	0x100006b60 <_silex_function_7+0xf30>
100006940:     	mov	x9, #0xed               ; =237
100006944:     	str	x9, [sp, #0x288]
100006948:     	mov	x16, x9
10000694c:     	ldr	x9, [sp, #0x30]
100006950:     	ldr	x10, [sp, #0x288]
100006954:     	cmp	x9, x10
100006958:     	mov	w11, #0x0               ; =0
10000695c:     	b.ne	0x100006964 <_silex_function_7+0xd34>
100006960:     	mov	w11, #0x1               ; =1
100006964:     	str	x11, [sp, #0x290]
100006968:     	mov	x17, x11
10000696c:     	ldr	x9, [sp, #0x290]
100006970:     	cbz	w9, 0x1000069e8 <_silex_function_7+0xdb8>
100006974:     	mov	x9, #0xa0               ; =160
100006978:     	str	x9, [sp, #0x298]
10000697c:     	mov	x16, x9
100006980:     	ldr	x9, [sp, #0x240]
100006984:     	ldr	x10, [sp, #0x298]
100006988:     	cmp	x9, x10
10000698c:     	mov	w11, #0x0               ; =0
100006990:     	b.lo	0x100006998 <_silex_function_7+0xd68>
100006994:     	mov	w11, #0x1               ; =1
100006998:     	str	x11, [sp, #0x2a0]
10000699c:     	mov	x17, x11
1000069a0:     	ldr	x9, [sp, #0x2a0]
1000069a4:     	cbz	w9, 0x1000069e8 <_silex_function_7+0xdb8>
1000069a8:     	mov	x9, #0x4                ; =4
1000069ac:     	str	x9, [sp, #0x2a8]
1000069b0:     	ldr	x0, [sp, #0x2a8]
1000069b4:     	ldr	x1, [sp, #0x370]
1000069b8:     	add	x15, sp, #0x2b0
1000069bc:     	bl	0x100006b7c <_silex_function_8>
1000069c0:     	ldr	x14, [sp, #0x10]
1000069c4:     	ldr	x9, [sp, #0x2b0]
1000069c8:     	str	x9, [x14]
1000069cc:     	ldr	x9, [sp, #0x2b8]
1000069d0:     	str	x9, [x14, #0x8]
1000069d4:     	ldr	x9, [sp, #0x2c0]
1000069d8:     	str	x9, [x14, #0x10]
1000069dc:     	mov	x0, #0x0                ; =0
1000069e0:     	mov	w8, #0x0                ; =0
1000069e4:     	b	0x100006b60 <_silex_function_7+0xf30>
1000069e8:     	mov	x9, #0xf0               ; =240
1000069ec:     	str	x9, [sp, #0x2c8]
1000069f0:     	mov	x16, x9
1000069f4:     	ldr	x9, [sp, #0x30]
1000069f8:     	ldr	x10, [sp, #0x2c8]
1000069fc:     	cmp	x9, x10
100006a00:     	mov	w11, #0x0               ; =0
100006a04:     	b.ne	0x100006a0c <_silex_function_7+0xddc>
100006a08:     	mov	w11, #0x1               ; =1
100006a0c:     	str	x11, [sp, #0x2d0]
100006a10:     	mov	x17, x11
100006a14:     	ldr	x9, [sp, #0x2d0]
100006a18:     	cbz	w9, 0x100006a90 <_silex_function_7+0xe60>
100006a1c:     	mov	x9, #0x90               ; =144
100006a20:     	str	x9, [sp, #0x2d8]
100006a24:     	mov	x16, x9
100006a28:     	ldr	x9, [sp, #0x240]
100006a2c:     	ldr	x10, [sp, #0x2d8]
100006a30:     	cmp	x9, x10
100006a34:     	mov	w11, #0x0               ; =0
100006a38:     	b.hs	0x100006a40 <_silex_function_7+0xe10>
100006a3c:     	mov	w11, #0x1               ; =1
100006a40:     	str	x11, [sp, #0x2e0]
100006a44:     	mov	x17, x11
100006a48:     	ldr	x9, [sp, #0x2e0]
100006a4c:     	cbz	w9, 0x100006a90 <_silex_function_7+0xe60>
100006a50:     	mov	x9, #0x3                ; =3
100006a54:     	str	x9, [sp, #0x2e8]
100006a58:     	ldr	x0, [sp, #0x2e8]
100006a5c:     	ldr	x1, [sp, #0x370]
100006a60:     	add	x15, sp, #0x2f0
100006a64:     	bl	0x100006b7c <_silex_function_8>
100006a68:     	ldr	x14, [sp, #0x10]
100006a6c:     	ldr	x9, [sp, #0x2f0]
100006a70:     	str	x9, [x14]
100006a74:     	ldr	x9, [sp, #0x2f8]
100006a78:     	str	x9, [x14, #0x8]
100006a7c:     	ldr	x9, [sp, #0x300]
100006a80:     	str	x9, [x14, #0x10]
100006a84:     	mov	x0, #0x0                ; =0
100006a88:     	mov	w8, #0x0                ; =0
100006a8c:     	b	0x100006b60 <_silex_function_7+0xf30>
100006a90:     	mov	x9, #0xf4               ; =244
100006a94:     	str	x9, [sp, #0x308]
100006a98:     	mov	x16, x9
100006a9c:     	ldr	x9, [sp, #0x30]
100006aa0:     	ldr	x10, [sp, #0x308]
100006aa4:     	cmp	x9, x10
100006aa8:     	mov	w11, #0x0               ; =0
100006aac:     	b.ne	0x100006ab4 <_silex_function_7+0xe84>
100006ab0:     	mov	w11, #0x1               ; =1
100006ab4:     	str	x11, [sp, #0x310]
100006ab8:     	mov	x17, x11
100006abc:     	ldr	x9, [sp, #0x310]
100006ac0:     	cbz	w9, 0x100006b38 <_silex_function_7+0xf08>
100006ac4:     	mov	x9, #0x8f               ; =143
100006ac8:     	str	x9, [sp, #0x318]
100006acc:     	mov	x16, x9
100006ad0:     	ldr	x9, [sp, #0x240]
100006ad4:     	ldr	x10, [sp, #0x318]
100006ad8:     	cmp	x9, x10
100006adc:     	mov	w11, #0x0               ; =0
100006ae0:     	b.ls	0x100006ae8 <_silex_function_7+0xeb8>
100006ae4:     	mov	w11, #0x1               ; =1
100006ae8:     	str	x11, [sp, #0x320]
100006aec:     	mov	x17, x11
100006af0:     	ldr	x9, [sp, #0x320]
100006af4:     	cbz	w9, 0x100006b38 <_silex_function_7+0xf08>
100006af8:     	mov	x9, #0x5                ; =5
100006afc:     	str	x9, [sp, #0x328]
100006b00:     	ldr	x0, [sp, #0x328]
100006b04:     	ldr	x1, [sp, #0x370]
100006b08:     	add	x15, sp, #0x330
100006b0c:     	bl	0x100006b7c <_silex_function_8>
100006b10:     	ldr	x14, [sp, #0x10]
100006b14:     	ldr	x9, [sp, #0x330]
100006b18:     	str	x9, [x14]
100006b1c:     	ldr	x9, [sp, #0x338]
100006b20:     	str	x9, [x14, #0x8]
100006b24:     	ldr	x9, [sp, #0x340]
100006b28:     	str	x9, [x14, #0x10]
100006b2c:     	mov	x0, #0x0                ; =0
100006b30:     	mov	w8, #0x0                ; =0
100006b34:     	b	0x100006b60 <_silex_function_7+0xf30>
100006b38:     	ldr	x9, [sp, #0x370]
100006b3c:     	ldr	x10, [sp, #0x378]
100006b40:     	adds	x11, x9, x10
100006b44:     	b.vs	0x100006b6c <_silex_function_7+0xf3c>
100006b48:     	str	x11, [sp, #0x348]
100006b4c:     	mov	x16, x11
100006b50:     	mov	x9, x16
100006b54:     	str	x9, [sp, #0x370]
100006b58:     	mov	x17, x9
100006b5c:     	b	0x100005c60 <_silex_function_7+0x30>
100006b60:     	add	sp, sp, #0x390
100006b64:     	ldp	x29, x30, [sp], #0x10
100006b68:     	ret
100006b6c:     	mov	w8, #0x1                ; =1
100006b70:     	b	0x100006b60 <_silex_function_7+0xf30>
100006b74:     	mov	w8, #0x2                ; =2
100006b78:     	b	0x100006b60 <_silex_function_7+0xf30>

0000000100006b7c <_silex_function_8>:
100006b7c:     	stp	x29, x30, [sp, #-0x10]!
100006b80:     	mov	x29, sp
100006b84:     	sub	sp, sp, #0x50
100006b88:     	str	x15, [sp, #0x10]
100006b8c:     	str	x0, [sp]
100006b90:     	str	x1, [sp, #0x8]
100006b94:     	ldr	x9, [sp]
100006b98:     	str	x9, [sp, #0x20]
100006b9c:     	ldr	x9, [sp, #0x8]
100006ba0:     	str	x9, [sp, #0x28]
100006ba4:     	mov	x9, #0x1                ; =1
100006ba8:     	str	x9, [sp, #0x30]
100006bac:     	mov	w9, #0x0                ; =0
100006bb0:     	str	x9, [sp, #0x38]
100006bb4:     	mov	w9, #0x0                ; =0
100006bb8:     	str	x9, [sp, #0x40]
100006bbc:     	ldr	x9, [sp, #0x20]
100006bc0:     	str	x9, [sp, #0x38]
100006bc4:     	ldr	x9, [sp, #0x28]
100006bc8:     	str	x9, [sp, #0x40]
100006bcc:     	ldr	x14, [sp, #0x10]
100006bd0:     	ldr	x9, [sp, #0x30]
100006bd4:     	str	x9, [x14]
100006bd8:     	ldr	x9, [sp, #0x38]
100006bdc:     	str	x9, [x14, #0x8]
100006be0:     	ldr	x9, [sp, #0x40]
100006be4:     	str	x9, [x14, #0x10]
100006be8:     	mov	x0, #0x0                ; =0
100006bec:     	mov	w8, #0x0                ; =0
100006bf0:     	add	sp, sp, #0x50
100006bf4:     	ldp	x29, x30, [sp], #0x10
100006bf8:     	ret
100006bfc:     	mov	w8, #0x1                ; =1
100006c00:     	b	0x100006bf0 <_silex_function_8+0x74>
100006c04:     	mov	w8, #0x2                ; =2
100006c08:     	b	0x100006bf0 <_silex_function_8+0x74>

0000000100006c0c <_silex_function_9>:
100006c0c:     	stp	x29, x30, [sp, #-0x10]!
100006c10:     	mov	x29, sp
100006c14:     	sub	sp, sp, #0x30
100006c18:     	mov	x9, #0x8                ; =8
100006c1c:     	str	x9, [sp]
100006c20:     	mov	x16, x9
100006c24:     	ldr	x0, [sp]
100006c28:     	bl	0x10000a80c <dyld_stub_binder+0x10000a80c>
100006c2c:     	nop
100006c30:     	nop
100006c34:     	mov	w8, #0x0                ; =0
100006c38:     	str	x0, [sp, #0x8]
100006c3c:     	ldr	x9, [sp, #0x8]
100006c40:     	mov	x12, #0xbe77            ; =48759
100006c44:     	movk	x12, #0x1a9f, lsl #16
100006c48:     	movk	x12, #0xdd2f, lsl #32
100006c4c:     	movk	x12, #0x624, lsl #48
100006c50:     	umulh	x13, x9, x12
100006c54:     	sub	x14, x9, x13
100006c58:     	lsr	x14, x14, #1
100006c5c:     	add	x13, x13, x14
100006c60:     	lsr	x13, x13, #9
100006c64:     	mov	x11, x13
100006c68:     	str	x11, [sp, #0x18]
100006c6c:     	mov	x16, x11
100006c70:     	ldr	x9, [sp, #0x18]
100006c74:     	mov	x10, #0xffff            ; =65535
100006c78:     	movk	x10, #0xffff, lsl #16
100006c7c:     	movk	x10, #0xffff, lsl #32
100006c80:     	movk	x10, #0x7fff, lsl #48
100006c84:     	cmp	x9, x10
100006c88:     	b.ls	0x100006cb8 <_silex_function_9+0xac>
100006c8c:     	mov	w0, #0x2                ; =2
100006c90:     	adrp	x1, 0x100009000 <_main+0x1b80>
100006c94:     	add	x1, x1, #0xc50
100006c98:     	mov	x2, #0xb6               ; =182
100006c9c:     	movk	x2, #0x0, lsl #16
100006ca0:     	movk	x2, #0x0, lsl #32
100006ca4:     	movk	x2, #0x0, lsl #48
100006ca8:     	mov	w16, #0x4               ; =4
100006cac:     	svc	#0x80
100006cb0:     	mov	w8, #0x3                ; =3
100006cb4:     	b	0x100006cc4 <_silex_function_9+0xb8>
100006cb8:     	str	x9, [sp, #0x20]
100006cbc:     	ldr	x0, [sp, #0x20]
100006cc0:     	mov	w8, #0x0                ; =0
100006cc4:     	add	sp, sp, #0x30
100006cc8:     	ldp	x29, x30, [sp], #0x10
100006ccc:     	ret
100006cd0:     	mov	w8, #0x1                ; =1
100006cd4:     	b	0x100006cc4 <_silex_function_9+0xb8>
100006cd8:     	mov	w8, #0x2                ; =2
100006cdc:     	b	0x100006cc4 <_silex_function_9+0xb8>

0000000100006ce0 <_silex_function_10>:
100006ce0:     	mov	x16, x0
100006ce4:     	mov	x17, x1
100006ce8:     	subs	x17, x17, x16
100006cec:     	b.vs	0x100006e4c <_silex_function_10+0x16c>
100006cf0:     	mov	x12, #0x34db            ; =13531
100006cf4:     	movk	x12, #0xd7b6, lsl #16
100006cf8:     	movk	x12, #0xde82, lsl #32
100006cfc:     	movk	x12, #0x431b, lsl #48
100006d00:     	smulh	x13, x17, x12
100006d04:     	asr	x13, x13, #18
100006d08:     	add	x13, x13, x13, lsr #63
100006d0c:     	mov	x1, x13
100006d10:     	mov	x12, #0x34db            ; =13531
100006d14:     	movk	x12, #0xd7b6, lsl #16
100006d18:     	movk	x12, #0xde82, lsl #32
100006d1c:     	movk	x12, #0x431b, lsl #48
100006d20:     	smulh	x13, x17, x12
100006d24:     	asr	x13, x13, #18
100006d28:     	add	x13, x13, x13, lsr #63
100006d2c:     	mov	x12, #0x4240            ; =16960
100006d30:     	movk	x12, #0xf, lsl #16
100006d34:     	msub	x17, x13, x12, x17
100006d38:     	scvtf	s16, x1
100006d3c:     	mov	x11, #0x5f000000        ; =1593835520
100006d40:     	fmov	s11, w11
100006d44:     	fcmp	s16, s11
100006d48:     	b.mi	0x100006d78 <_silex_function_10+0x98>
100006d4c:     	mov	w0, #0x2                ; =2
100006d50:     	adrp	x1, 0x100009000 <_main+0x1b80>
100006d54:     	add	x1, x1, #0xd10
100006d58:     	mov	x2, #0xaf               ; =175
100006d5c:     	movk	x2, #0x0, lsl #16
100006d60:     	movk	x2, #0x0, lsl #32
100006d64:     	movk	x2, #0x0, lsl #48
100006d68:     	mov	w16, #0x4               ; =4
100006d6c:     	svc	#0x80
100006d70:     	mov	w8, #0x3                ; =3
100006d74:     	b	0x100006e48 <_silex_function_10+0x168>
100006d78:     	fcvtzs	x11, s16
100006d7c:     	cmp	x1, x11
100006d80:     	b.eq	0x100006db0 <_silex_function_10+0xd0>
100006d84:     	mov	w0, #0x2                ; =2
100006d88:     	adrp	x1, 0x100009000 <_main+0x1b80>
100006d8c:     	add	x1, x1, #0xd10
100006d90:     	mov	x2, #0xaf               ; =175
100006d94:     	movk	x2, #0x0, lsl #16
100006d98:     	movk	x2, #0x0, lsl #32
100006d9c:     	movk	x2, #0x0, lsl #48
100006da0:     	mov	w16, #0x4               ; =4
100006da4:     	svc	#0x80
100006da8:     	mov	w8, #0x3                ; =3
100006dac:     	b	0x100006e48 <_silex_function_10+0x168>
100006db0:     	scvtf	s17, x17
100006db4:     	mov	x11, #0x5f000000        ; =1593835520
100006db8:     	fmov	s11, w11
100006dbc:     	fcmp	s17, s11
100006dc0:     	b.mi	0x100006df0 <_silex_function_10+0x110>
100006dc4:     	mov	w0, #0x2                ; =2
100006dc8:     	adrp	x1, 0x100009000 <_main+0x1b80>
100006dcc:     	add	x1, x1, #0xdc8
100006dd0:     	mov	x2, #0xaf               ; =175
100006dd4:     	movk	x2, #0x0, lsl #16
100006dd8:     	movk	x2, #0x0, lsl #32
100006ddc:     	movk	x2, #0x0, lsl #48
100006de0:     	mov	w16, #0x4               ; =4
100006de4:     	svc	#0x80
100006de8:     	mov	w8, #0x3                ; =3
100006dec:     	b	0x100006e48 <_silex_function_10+0x168>
100006df0:     	fcvtzs	x11, s17
100006df4:     	cmp	x17, x11
100006df8:     	b.eq	0x100006e28 <_silex_function_10+0x148>
100006dfc:     	mov	w0, #0x2                ; =2
100006e00:     	adrp	x1, 0x100009000 <_main+0x1b80>
100006e04:     	add	x1, x1, #0xdc8
100006e08:     	mov	x2, #0xaf               ; =175
100006e0c:     	movk	x2, #0x0, lsl #16
100006e10:     	movk	x2, #0x0, lsl #32
100006e14:     	movk	x2, #0x0, lsl #48
100006e18:     	mov	w16, #0x4               ; =4
100006e1c:     	svc	#0x80
100006e20:     	mov	w8, #0x3                ; =3
100006e24:     	b	0x100006e48 <_silex_function_10+0x168>
100006e28:     	mov	x9, #0x2400             ; =9216
100006e2c:     	movk	x9, #0x4974, lsl #16
100006e30:     	fmov	s18, w9
100006e34:     	fdiv	s17, s17, s18
100006e38:     	fadd	s16, s16, s17
100006e3c:     	fmov	s9, s16
100006e40:     	fmov	w0, s9
100006e44:     	mov	w8, #0x0                ; =0
100006e48:     	ret
100006e4c:     	mov	w8, #0x1                ; =1
100006e50:     	b	0x100006e48 <_silex_function_10+0x168>
100006e54:     	mov	w8, #0x2                ; =2
100006e58:     	b	0x100006e48 <_silex_function_10+0x168>

0000000100006e5c <_silex_function_11>:
100006e5c:     	stp	x29, x30, [sp, #-0x10]!
100006e60:     	mov	x29, sp
100006e64:     	sub	sp, sp, #0x30
100006e68:     	mov	x9, #0x8                ; =8
100006e6c:     	str	x9, [sp]
100006e70:     	mov	x16, x9
100006e74:     	ldr	x0, [sp]
100006e78:     	bl	0x10000a80c <dyld_stub_binder+0x10000a80c>
100006e7c:     	nop
100006e80:     	nop
100006e84:     	mov	w8, #0x0                ; =0
100006e88:     	str	x0, [sp, #0x8]
100006e8c:     	ldr	x9, [sp, #0x8]
100006e90:     	mov	x12, #0xbe77            ; =48759
100006e94:     	movk	x12, #0x1a9f, lsl #16
100006e98:     	movk	x12, #0xdd2f, lsl #32
100006e9c:     	movk	x12, #0x624, lsl #48
100006ea0:     	umulh	x13, x9, x12
100006ea4:     	sub	x14, x9, x13
100006ea8:     	lsr	x14, x14, #1
100006eac:     	add	x13, x13, x14
100006eb0:     	lsr	x13, x13, #9
100006eb4:     	mov	x11, x13
100006eb8:     	str	x11, [sp, #0x18]
100006ebc:     	mov	x16, x11
100006ec0:     	ldr	x9, [sp, #0x18]
100006ec4:     	mov	x10, #0xffff            ; =65535
100006ec8:     	movk	x10, #0xffff, lsl #16
100006ecc:     	movk	x10, #0xffff, lsl #32
100006ed0:     	movk	x10, #0x7fff, lsl #48
100006ed4:     	cmp	x9, x10
100006ed8:     	b.ls	0x100006f08 <_silex_function_11+0xac>
100006edc:     	mov	w0, #0x2                ; =2
100006ee0:     	adrp	x1, 0x100009000 <_main+0x1b80>
100006ee4:     	add	x1, x1, #0xc50
100006ee8:     	mov	x2, #0xb6               ; =182
100006eec:     	movk	x2, #0x0, lsl #16
100006ef0:     	movk	x2, #0x0, lsl #32
100006ef4:     	movk	x2, #0x0, lsl #48
100006ef8:     	mov	w16, #0x4               ; =4
100006efc:     	svc	#0x80
100006f00:     	mov	w8, #0x3                ; =3
100006f04:     	b	0x100006f14 <_silex_function_11+0xb8>
100006f08:     	str	x9, [sp, #0x20]
100006f0c:     	ldr	x0, [sp, #0x20]
100006f10:     	mov	w8, #0x0                ; =0
100006f14:     	add	sp, sp, #0x30
100006f18:     	ldp	x29, x30, [sp], #0x10
100006f1c:     	ret
100006f20:     	mov	w8, #0x1                ; =1
100006f24:     	b	0x100006f14 <_silex_function_11+0xb8>
100006f28:     	mov	w8, #0x2                ; =2
100006f2c:     	b	0x100006f14 <_silex_function_11+0xb8>

0000000100006f30 <_silex_function_12>:
100006f30:     	stp	x29, x30, [sp, #-0x10]!
100006f34:     	mov	x29, sp
100006f38:     	sub	sp, sp, #0x2c0
100006f3c:     	str	x15, [sp, #0x30]
100006f40:     	ldp	x9, x11, [x0]
100006f44:     	stp	x9, x11, [sp]
100006f48:     	ldp	x9, x11, [x0, #0x10]
100006f4c:     	stp	x9, x11, [sp, #0x10]
100006f50:     	ldp	x9, x11, [x0, #0x20]
100006f54:     	stp	x9, x11, [sp, #0x20]
100006f58:     	ldr	x9, [sp]
100006f5c:     	str	x9, [sp, #0x1b8]
100006f60:     	mov	x16, x9
100006f64:     	ldr	x9, [sp, #0x8]
100006f68:     	str	x9, [sp, #0x1c0]
100006f6c:     	mov	x17, x9
100006f70:     	ldr	x9, [sp, #0x10]
100006f74:     	str	x9, [sp, #0x1c8]
100006f78:     	mov	x16, x9
100006f7c:     	ldr	x9, [sp, #0x18]
100006f80:     	str	x9, [sp, #0x1d0]
100006f84:     	mov	x17, x9
100006f88:     	ldr	x9, [sp, #0x20]
100006f8c:     	str	x9, [sp, #0x1d8]
100006f90:     	mov	x16, x9
100006f94:     	ldr	x9, [sp, #0x28]
100006f98:     	str	x9, [sp, #0x1e0]
100006f9c:     	mov	x17, x9
100006fa0:     	ldr	x9, [sp, #0x1e0]
100006fa4:     	cbz	w9, 0x10000704c <_silex_function_12+0x11c>
100006fa8:     	movi	d9, #0000000000000000
100006fac:     	str	s9, [sp, #0x38]
100006fb0:     	ldr	x9, [sp, #0x1c0]
100006fb4:     	str	x9, [sp, #0x1e8]
100006fb8:     	mov	x16, x9
100006fbc:     	ldr	x9, [sp, #0x1c8]
100006fc0:     	str	x9, [sp, #0x1f0]
100006fc4:     	mov	x17, x9
100006fc8:     	ldr	x9, [sp, #0x1d0]
100006fcc:     	str	x9, [sp, #0x1f8]
100006fd0:     	mov	x16, x9
100006fd4:     	ldr	x9, [sp, #0x1b8]
100006fd8:     	str	x9, [sp, #0x40]
100006fdc:     	ldr	x9, [sp, #0x1e8]
100006fe0:     	str	x9, [sp, #0x48]
100006fe4:     	ldr	x9, [sp, #0x1f0]
100006fe8:     	str	x9, [sp, #0x50]
100006fec:     	ldr	x9, [sp, #0x1f8]
100006ff0:     	str	x9, [sp, #0x58]
100006ff4:     	ldr	x9, [sp, #0x1d8]
100006ff8:     	str	x9, [sp, #0x60]
100006ffc:     	ldr	x9, [sp, #0x1e0]
100007000:     	str	x9, [sp, #0x68]
100007004:     	ldr	x14, [sp, #0x30]
100007008:     	ldr	x9, [sp, #0x40]
10000700c:     	str	x9, [x14]
100007010:     	ldr	x9, [sp, #0x48]
100007014:     	str	x9, [x14, #0x8]
100007018:     	ldr	x9, [sp, #0x50]
10000701c:     	str	x9, [x14, #0x10]
100007020:     	ldr	x9, [sp, #0x58]
100007024:     	str	x9, [x14, #0x18]
100007028:     	ldr	x9, [sp, #0x60]
10000702c:     	str	x9, [x14, #0x20]
100007030:     	ldr	x9, [sp, #0x68]
100007034:     	str	x9, [x14, #0x28]
100007038:     	ldr	x9, [sp, #0x38]
10000703c:     	str	x9, [x14, #0x30]
100007040:     	mov	x0, #0x0                ; =0
100007044:     	mov	w8, #0x0                ; =0
100007048:     	b	0x100007464 <_silex_function_12+0x534>
10000704c:     	mov	x9, #0x8                ; =8
100007050:     	str	x9, [sp, #0x248]
100007054:     	mov	x16, x9
100007058:     	ldr	x0, [sp, #0x248]
10000705c:     	bl	0x10000a80c <dyld_stub_binder+0x10000a80c>
100007060:     	nop
100007064:     	nop
100007068:     	mov	w8, #0x0                ; =0
10000706c:     	str	x0, [sp, #0x250]
100007070:     	ldr	x9, [sp, #0x250]
100007074:     	mov	x12, #0xbe77            ; =48759
100007078:     	movk	x12, #0x1a9f, lsl #16
10000707c:     	movk	x12, #0xdd2f, lsl #32
100007080:     	movk	x12, #0x624, lsl #48
100007084:     	umulh	x13, x9, x12
100007088:     	sub	x14, x9, x13
10000708c:     	lsr	x14, x14, #1
100007090:     	add	x13, x13, x14
100007094:     	lsr	x13, x13, #9
100007098:     	mov	x11, x13
10000709c:     	str	x11, [sp, #0x260]
1000070a0:     	mov	x16, x11
1000070a4:     	ldr	x9, [sp, #0x260]
1000070a8:     	mov	x10, #0xffff            ; =65535
1000070ac:     	movk	x10, #0xffff, lsl #16
1000070b0:     	movk	x10, #0xffff, lsl #32
1000070b4:     	movk	x10, #0x7fff, lsl #48
1000070b8:     	cmp	x9, x10
1000070bc:     	b.ls	0x1000070ec <_silex_function_12+0x1bc>
1000070c0:     	mov	w0, #0x2                ; =2
1000070c4:     	adrp	x1, 0x100009000 <_main+0x1b80>
1000070c8:     	add	x1, x1, #0xc50
1000070cc:     	mov	x2, #0xb6               ; =182
1000070d0:     	movk	x2, #0x0, lsl #16
1000070d4:     	movk	x2, #0x0, lsl #32
1000070d8:     	movk	x2, #0x0, lsl #48
1000070dc:     	mov	w16, #0x4               ; =4
1000070e0:     	svc	#0x80
1000070e4:     	mov	w8, #0x3                ; =3
1000070e8:     	b	0x100007464 <_silex_function_12+0x534>
1000070ec:     	str	x9, [sp, #0x268]
1000070f0:     	mov	w9, #0x0                ; =0
1000070f4:     	str	x9, [sp, #0xa8]
1000070f8:     	mov	x16, x9
1000070fc:     	ldr	x9, [sp, #0x1d8]
100007100:     	ldr	x10, [sp, #0xa8]
100007104:     	cmp	x9, x10
100007108:     	mov	w11, #0x0               ; =0
10000710c:     	b.ne	0x100007114 <_silex_function_12+0x1e4>
100007110:     	mov	w11, #0x1               ; =1
100007114:     	str	x11, [sp, #0xb0]
100007118:     	mov	x17, x11
10000711c:     	ldr	x9, [sp, #0xb0]
100007120:     	cbz	w9, 0x1000071d4 <_silex_function_12+0x2a4>
100007124:     	mov	w9, #0x1                ; =1
100007128:     	str	x9, [sp, #0xb8]
10000712c:     	mov	x16, x9
100007130:     	movi	d9, #0000000000000000
100007134:     	str	s9, [sp, #0xc0]
100007138:     	ldr	x9, [sp, #0x1c0]
10000713c:     	str	x9, [sp, #0x200]
100007140:     	mov	x17, x9
100007144:     	ldr	x9, [sp, #0x1c8]
100007148:     	str	x9, [sp, #0x208]
10000714c:     	mov	x16, x9
100007150:     	ldr	x9, [sp, #0x1d0]
100007154:     	str	x9, [sp, #0x210]
100007158:     	mov	x17, x9
10000715c:     	ldr	x9, [sp, #0x268]
100007160:     	str	x9, [sp, #0xc8]
100007164:     	ldr	x9, [sp, #0x200]
100007168:     	str	x9, [sp, #0xd0]
10000716c:     	ldr	x9, [sp, #0x208]
100007170:     	str	x9, [sp, #0xd8]
100007174:     	ldr	x9, [sp, #0x210]
100007178:     	str	x9, [sp, #0xe0]
10000717c:     	ldr	x9, [sp, #0xb8]
100007180:     	str	x9, [sp, #0xe8]
100007184:     	ldr	x9, [sp, #0x1e0]
100007188:     	str	x9, [sp, #0xf0]
10000718c:     	ldr	x14, [sp, #0x30]
100007190:     	ldr	x9, [sp, #0xc8]
100007194:     	str	x9, [x14]
100007198:     	ldr	x9, [sp, #0xd0]
10000719c:     	str	x9, [x14, #0x8]
1000071a0:     	ldr	x9, [sp, #0xd8]
1000071a4:     	str	x9, [x14, #0x10]
1000071a8:     	ldr	x9, [sp, #0xe0]
1000071ac:     	str	x9, [x14, #0x18]
1000071b0:     	ldr	x9, [sp, #0xe8]
1000071b4:     	str	x9, [x14, #0x20]
1000071b8:     	ldr	x9, [sp, #0xf0]
1000071bc:     	str	x9, [x14, #0x28]
1000071c0:     	ldr	x9, [sp, #0xc0]
1000071c4:     	str	x9, [x14, #0x30]
1000071c8:     	mov	x0, #0x0                ; =0
1000071cc:     	mov	w8, #0x0                ; =0
1000071d0:     	b	0x100007464 <_silex_function_12+0x534>
1000071d4:     	ldr	x9, [sp, #0x1c0]
1000071d8:     	str	x9, [sp, #0x218]
1000071dc:     	mov	x16, x9
1000071e0:     	ldr	x9, [sp, #0x268]
1000071e4:     	ldr	x10, [sp, #0x1b8]
1000071e8:     	subs	x11, x9, x10
1000071ec:     	b.vs	0x100007470 <_silex_function_12+0x540>
1000071f0:     	str	x11, [sp, #0x270]
1000071f4:     	mov	x17, x11
1000071f8:     	ldr	x9, [sp, #0x270]
1000071fc:     	mov	x12, #0x34db            ; =13531
100007200:     	movk	x12, #0xd7b6, lsl #16
100007204:     	movk	x12, #0xde82, lsl #32
100007208:     	movk	x12, #0x431b, lsl #48
10000720c:     	smulh	x13, x9, x12
100007210:     	asr	x13, x13, #18
100007214:     	add	x13, x13, x13, lsr #63
100007218:     	mov	x11, x13
10000721c:     	str	x11, [sp, #0x280]
100007220:     	mov	x16, x11
100007224:     	ldr	x9, [sp, #0x270]
100007228:     	mov	x12, #0x34db            ; =13531
10000722c:     	movk	x12, #0xd7b6, lsl #16
100007230:     	movk	x12, #0xde82, lsl #32
100007234:     	movk	x12, #0x431b, lsl #48
100007238:     	smulh	x13, x9, x12
10000723c:     	asr	x13, x13, #18
100007240:     	add	x13, x13, x13, lsr #63
100007244:     	mov	x12, #0x4240            ; =16960
100007248:     	movk	x12, #0xf, lsl #16
10000724c:     	msub	x11, x13, x12, x9
100007250:     	str	x11, [sp, #0x290]
100007254:     	mov	x17, x11
100007258:     	ldr	x9, [sp, #0x280]
10000725c:     	scvtf	s10, x9
100007260:     	mov	x11, #0x5f000000        ; =1593835520
100007264:     	fmov	s11, w11
100007268:     	fcmp	s10, s11
10000726c:     	b.mi	0x10000729c <_silex_function_12+0x36c>
100007270:     	mov	w0, #0x2                ; =2
100007274:     	adrp	x1, 0x100009000 <_main+0x1b80>
100007278:     	add	x1, x1, #0xd10
10000727c:     	mov	x2, #0xaf               ; =175
100007280:     	movk	x2, #0x0, lsl #16
100007284:     	movk	x2, #0x0, lsl #32
100007288:     	movk	x2, #0x0, lsl #48
10000728c:     	mov	w16, #0x4               ; =4
100007290:     	svc	#0x80
100007294:     	mov	w8, #0x3                ; =3
100007298:     	b	0x100007464 <_silex_function_12+0x534>
10000729c:     	fcvtzs	x11, s10
1000072a0:     	cmp	x9, x11
1000072a4:     	b.eq	0x1000072d4 <_silex_function_12+0x3a4>
1000072a8:     	mov	w0, #0x2                ; =2
1000072ac:     	adrp	x1, 0x100009000 <_main+0x1b80>
1000072b0:     	add	x1, x1, #0xd10
1000072b4:     	mov	x2, #0xaf               ; =175
1000072b8:     	movk	x2, #0x0, lsl #16
1000072bc:     	movk	x2, #0x0, lsl #32
1000072c0:     	movk	x2, #0x0, lsl #48
1000072c4:     	mov	w16, #0x4               ; =4
1000072c8:     	svc	#0x80
1000072cc:     	mov	w8, #0x3                ; =3
1000072d0:     	b	0x100007464 <_silex_function_12+0x534>
1000072d4:     	str	s10, [sp, #0x298]
1000072d8:     	ldr	x9, [sp, #0x290]
1000072dc:     	scvtf	s10, x9
1000072e0:     	mov	x11, #0x5f000000        ; =1593835520
1000072e4:     	fmov	s11, w11
1000072e8:     	fcmp	s10, s11
1000072ec:     	b.mi	0x10000731c <_silex_function_12+0x3ec>
1000072f0:     	mov	w0, #0x2                ; =2
1000072f4:     	adrp	x1, 0x100009000 <_main+0x1b80>
1000072f8:     	add	x1, x1, #0xdc8
1000072fc:     	mov	x2, #0xaf               ; =175
100007300:     	movk	x2, #0x0, lsl #16
100007304:     	movk	x2, #0x0, lsl #32
100007308:     	movk	x2, #0x0, lsl #48
10000730c:     	mov	w16, #0x4               ; =4
100007310:     	svc	#0x80
100007314:     	mov	w8, #0x3                ; =3
100007318:     	b	0x100007464 <_silex_function_12+0x534>
10000731c:     	fcvtzs	x11, s10
100007320:     	cmp	x9, x11
100007324:     	b.eq	0x100007354 <_silex_function_12+0x424>
100007328:     	mov	w0, #0x2                ; =2
10000732c:     	adrp	x1, 0x100009000 <_main+0x1b80>
100007330:     	add	x1, x1, #0xdc8
100007334:     	mov	x2, #0xaf               ; =175
100007338:     	movk	x2, #0x0, lsl #16
10000733c:     	movk	x2, #0x0, lsl #32
100007340:     	movk	x2, #0x0, lsl #48
100007344:     	mov	w16, #0x4               ; =4
100007348:     	svc	#0x80
10000734c:     	mov	w8, #0x3                ; =3
100007350:     	b	0x100007464 <_silex_function_12+0x534>
100007354:     	str	s10, [sp, #0x2a0]
100007358:     	mov	x9, #0x2400             ; =9216
10000735c:     	movk	x9, #0x4974, lsl #16
100007360:     	fmov	s9, w9
100007364:     	str	s9, [sp, #0x2a8]
100007368:     	ldr	s9, [sp, #0x2a0]
10000736c:     	ldr	s10, [sp, #0x2a8]
100007370:     	fdiv	s11, s9, s10
100007374:     	str	s11, [sp, #0x2b0]
100007378:     	ldr	s9, [sp, #0x298]
10000737c:     	ldr	s10, [sp, #0x2b0]
100007380:     	fadd	s11, s9, s10
100007384:     	str	s11, [sp, #0x2b8]
100007388:     	ldr	x9, [sp, #0x2b8]
10000738c:     	str	x9, [sp, #0x130]
100007390:     	mov	x16, x9
100007394:     	ldr	x9, [sp, #0x1d0]
100007398:     	str	x9, [sp, #0x220]
10000739c:     	mov	x17, x9
1000073a0:     	ldr	s9, [sp, #0x130]
1000073a4:     	ldr	s10, [sp, #0x220]
1000073a8:     	ldr	s11, [sp, #0x218]
1000073ac:     	fmadd	s12, s9, s10, s11
1000073b0:     	str	s12, [sp, #0x140]
1000073b4:     	ldr	x9, [sp, #0x1c8]
1000073b8:     	str	x9, [sp, #0x228]
1000073bc:     	mov	x16, x9
1000073c0:     	ldr	s9, [sp, #0x228]
1000073c4:     	ldr	s10, [sp, #0x140]
1000073c8:     	fadd	s11, s9, s10
1000073cc:     	str	s11, [sp, #0x148]
1000073d0:     	movi	d9, #0000000000000000
1000073d4:     	str	s9, [sp, #0x230]
1000073d8:     	ldr	x9, [sp, #0x148]
1000073dc:     	str	x9, [sp, #0x238]
1000073e0:     	mov	x17, x9
1000073e4:     	ldr	x9, [sp, #0x1d0]
1000073e8:     	str	x9, [sp, #0x240]
1000073ec:     	mov	x16, x9
1000073f0:     	ldr	x9, [sp, #0x268]
1000073f4:     	str	x9, [sp, #0x150]
1000073f8:     	ldr	x9, [sp, #0x230]
1000073fc:     	str	x9, [sp, #0x158]
100007400:     	ldr	x9, [sp, #0x238]
100007404:     	str	x9, [sp, #0x160]
100007408:     	ldr	x9, [sp, #0x240]
10000740c:     	str	x9, [sp, #0x168]
100007410:     	ldr	x9, [sp, #0x1d8]
100007414:     	str	x9, [sp, #0x170]
100007418:     	ldr	x9, [sp, #0x1e0]
10000741c:     	str	x9, [sp, #0x178]
100007420:     	ldr	x14, [sp, #0x30]
100007424:     	ldr	x9, [sp, #0x150]
100007428:     	str	x9, [x14]
10000742c:     	ldr	x9, [sp, #0x158]
100007430:     	str	x9, [x14, #0x8]
100007434:     	ldr	x9, [sp, #0x160]
100007438:     	str	x9, [x14, #0x10]
10000743c:     	ldr	x9, [sp, #0x168]
100007440:     	str	x9, [x14, #0x18]
100007444:     	ldr	x9, [sp, #0x170]
100007448:     	str	x9, [x14, #0x20]
10000744c:     	ldr	x9, [sp, #0x178]
100007450:     	str	x9, [x14, #0x28]
100007454:     	ldr	x9, [sp, #0x140]
100007458:     	str	x9, [x14, #0x30]
10000745c:     	mov	x0, #0x0                ; =0
100007460:     	mov	w8, #0x0                ; =0
100007464:     	add	sp, sp, #0x2c0
100007468:     	ldp	x29, x30, [sp], #0x10
10000746c:     	ret
100007470:     	mov	w8, #0x1                ; =1
100007474:     	b	0x100007464 <_silex_function_12+0x534>
100007478:     	mov	w8, #0x2                ; =2
10000747c:     	b	0x100007464 <_silex_function_12+0x534>

0000000100007480 <_main>:
100007480:     	stp	x29, x30, [sp, #-0x10]!
100007484:     	mov	x29, sp
100007488:     	bl	0x100000b38 <_silex_function_2>
10000748c:     	cbz	w8, 0x10000749c <_main+0x1c>
100007490:     	mov	w0, #0x1                ; =1
100007494:     	ldp	x29, x30, [sp], #0x10
100007498:     	ret
10000749c:     	mov	w0, #0x0                ; =0
1000074a0:     	ldp	x29, x30, [sp], #0x10
1000074a4:     	ret
		...
100007988:     	orr	x10, x2, x3
10000798c:     	cbz	x10, 0x100007a20 <_main+0x5a0>
100007990:     	mov	x8, x1
100007994:     	mov	x9, x0
100007998:     	mov	x13, #0x0               ; =0
10000799c:     	mov	x14, #0x0               ; =0
1000079a0:     	mov	x0, #0x0                ; =0
1000079a4:     	mov	x1, #0x0                ; =0
1000079a8:     	mov	w10, #0x80              ; =128
1000079ac:     	lsl	x11, x8, #1
1000079b0:     	mov	w12, #0x1               ; =1
1000079b4:     	tst	w10, #0xff
1000079b8:     	b.eq	0x100007a28 <_main+0x5a8>
1000079bc:     	sub	w10, w10, #0x1
1000079c0:     	extr	x14, x14, x13, #0x3f
1000079c4:     	lsr	x15, x9, x10
1000079c8:     	mvn	w16, w10
1000079cc:     	lsl	x16, x11, x16
1000079d0:     	orr	x15, x16, x15
1000079d4:     	lsr	x16, x8, x10
1000079d8:     	and	x17, x10, #0xff
1000079dc:     	tst	x17, #0x40
1000079e0:     	csel	x15, x16, x15, ne
1000079e4:     	bfi	x15, x13, #1, #63
1000079e8:     	lsl	x13, x12, x10
1000079ec:     	csel	x16, x13, xzr, ne
1000079f0:     	csel	x13, xzr, x13, ne
1000079f4:     	cmp	x15, x2
1000079f8:     	sbcs	xzr, x14, x3
1000079fc:     	csel	x17, xzr, x3, lo
100007a00:     	csel	x4, xzr, x2, lo
100007a04:     	csel	x5, xzr, x13, lo
100007a08:     	csel	x16, xzr, x16, lo
100007a0c:     	subs	x13, x15, x4
100007a10:     	sbc	x14, x14, x17
100007a14:     	orr	x1, x16, x1
100007a18:     	orr	x0, x5, x0
100007a1c:     	b	0x1000079b4 <_main+0x534>
100007a20:     	mov	x0, #0x0                ; =0
100007a24:     	mov	x1, #0x0                ; =0
100007a28:     	ret
100007a2c:     	mov	x8, #0x0                ; =0
100007a30:     	cmp	x2, x8
100007a34:     	b.eq	0x100007a44 <_main+0x5c4>
100007a38:     	strb	w1, [x0, x8]
100007a3c:     	add	x8, x8, #0x1
100007a40:     	b	0x100007a30 <_main+0x5b0>
100007a44:     	ret
100007a48:     	sub	sp, sp, #0x50
100007a4c:     	stp	x20, x19, [sp, #0x30]
100007a50:     	stp	x29, x30, [sp, #0x40]
100007a54:     	mov	x19, x1
100007a58:     	cbz	x2, 0x100007a9c <_main+0x61c>
100007a5c:     	fmov	d0, x0
100007a60:     	fcmp	d0, d0
100007a64:     	b.vs	0x100007c3c <_main+0x7bc>
100007a68:     	mov	x8, #0x7ff0000000000000 ; =9218868437227405312
100007a6c:     	fmov	d1, x8
100007a70:     	fcmp	d0, d1
100007a74:     	b.eq	0x100007ab8 <_main+0x638>
100007a78:     	mov	x8, #-0x10000000000000  ; =-4503599627370496
100007a7c:     	fmov	d1, x8
100007a80:     	fcmp	d0, d1
100007a84:     	b.eq	0x100007ae0 <_main+0x660>
100007a88:     	fcmp	d0, #0.0
100007a8c:     	b.ne	0x100007b34 <_main+0x6b4>
100007a90:     	bl	0x100008b5c <_main+0x16dc>
100007a94:     	cmp	x0, #0x0
100007a98:     	b	0x100007b08 <_main+0x688>
100007a9c:     	fmov	s0, w0
100007aa0:     	fcmp	s0, s0
100007aa4:     	b.vs	0x100007c3c <_main+0x7bc>
100007aa8:     	mov	w8, #0x7f800000         ; =2139095040
100007aac:     	fmov	s1, w8
100007ab0:     	fcmp	s0, s1
100007ab4:     	b.ne	0x100007ad0 <_main+0x650>
100007ab8:     	adrp	x1, 0x100008000 <_main+0xb80>
100007abc:     	add	x1, x1, #0xef4
100007ac0:     	mov	w20, #0x3               ; =3
100007ac4:     	mov	x0, x19
100007ac8:     	mov	w2, #0x3                ; =3
100007acc:     	b	0x100007b1c <_main+0x69c>
100007ad0:     	mov	w8, #-0x800000          ; =-8388608
100007ad4:     	fmov	s1, w8
100007ad8:     	fcmp	s0, s1
100007adc:     	b.ne	0x100007af8 <_main+0x678>
100007ae0:     	adrp	x1, 0x100008000 <_main+0xb80>
100007ae4:     	add	x1, x1, #0xef8
100007ae8:     	mov	w20, #0x4               ; =4
100007aec:     	mov	x0, x19
100007af0:     	mov	w2, #0x4                ; =4
100007af4:     	b	0x100007b1c <_main+0x69c>
100007af8:     	fcmp	s0, #0.0
100007afc:     	b.ne	0x100007b64 <_main+0x6e4>
100007b00:     	bl	0x100008b5c <_main+0x16dc>
100007b04:     	cmp	w0, #0x0
100007b08:     	csel	x1, x9, x8, lt
100007b0c:     	mov	w8, #0x3                ; =3
100007b10:     	cinc	x20, x8, lt
100007b14:     	mov	x0, x19
100007b18:     	mov	x2, x20
100007b1c:     	bl	0x100008a54 <_main+0x15d4>
100007b20:     	mov	x0, x20
100007b24:     	ldp	x29, x30, [sp, #0x40]
100007b28:     	ldp	x20, x19, [sp, #0x30]
100007b2c:     	add	sp, sp, #0x50
100007b30:     	ret
100007b34:     	adrp	x8, 0x100008000 <_main+0xb80>
100007b38:     	ldrb	w20, [x8, #0xba0]
100007b3c:     	add	x8, sp, #0x8
100007b40:     	mov	w1, #0x34               ; =52
100007b44:     	mov	w2, #0xb                ; =11
100007b48:     	bl	0x1000084d4 <_main+0x1054>
100007b4c:     	adrp	x2, 0x100008000 <_main+0xb80>
100007b50:     	add	x2, x2, #0xb90
100007b54:     	tbz	w20, #0x0, 0x100007b98 <_main+0x718>
100007b58:     	bl	0x100008a94 <_main+0x1614>
100007b5c:     	bl	0x100007c48 <_main+0x7c8>
100007b60:     	b	0x100007ba0 <_main+0x720>
100007b64:     	adrp	x8, 0x100008000 <_main+0xb80>
100007b68:     	ldrb	w20, [x8, #0xba0]
100007b6c:     	mov	w0, w0
100007b70:     	add	x8, sp, #0x8
100007b74:     	mov	w1, #0x17               ; =23
100007b78:     	mov	w2, #0x8                ; =8
100007b7c:     	bl	0x1000084d4 <_main+0x1054>
100007b80:     	adrp	x2, 0x100008000 <_main+0xb80>
100007b84:     	add	x2, x2, #0xb90
100007b88:     	tbz	w20, #0x0, 0x100007bdc <_main+0x75c>
100007b8c:     	bl	0x100008a94 <_main+0x1614>
100007b90:     	bl	0x100007c48 <_main+0x7c8>
100007b94:     	b	0x100007be4 <_main+0x764>
100007b98:     	bl	0x100008a94 <_main+0x1614>
100007b9c:     	bl	0x100007e90 <_main+0xa10>
100007ba0:     	ldrh	w8, [x20, #0x10]
100007ba4:     	cbnz	w8, 0x100007bec <_main+0x76c>
100007ba8:     	bl	0x100008b10 <_main+0x1690>
100007bac:     	cmp	x20, x9
100007bb0:     	b.eq	0x100007c28 <_main+0x7a8>
100007bb4:     	ldrb	w13, [x10, x9]
100007bb8:     	sub	w13, w13, #0x2e
100007bbc:     	cmp	w13, #0x37
100007bc0:     	lsl	x13, x11, x13
100007bc4:     	and	x13, x13, x12
100007bc8:     	ccmp	x13, #0x0, #0x4, ls
100007bcc:     	b.eq	0x100007bd4 <_main+0x754>
100007bd0:     	mov	w8, #0x1                ; =1
100007bd4:     	add	x9, x9, #0x1
100007bd8:     	b	0x100007bac <_main+0x72c>
100007bdc:     	bl	0x100008a94 <_main+0x1614>
100007be0:     	bl	0x100007e90 <_main+0xa10>
100007be4:     	ldrh	w8, [x20, #0x10]
100007be8:     	cbz	w8, 0x100007bf4 <_main+0x774>
100007bec:     	mov	x20, #0x0               ; =0
100007bf0:     	b	0x100007b20 <_main+0x6a0>
100007bf4:     	bl	0x100008b10 <_main+0x1690>
100007bf8:     	cmp	x20, x9
100007bfc:     	b.eq	0x100007c28 <_main+0x7a8>
100007c00:     	ldrb	w13, [x10, x9]
100007c04:     	sub	w13, w13, #0x2e
100007c08:     	cmp	w13, #0x37
100007c0c:     	lsl	x13, x11, x13
100007c10:     	and	x13, x13, x12
100007c14:     	ccmp	x13, #0x0, #0x4, ls
100007c18:     	b.eq	0x100007c20 <_main+0x7a0>
100007c1c:     	mov	w8, #0x1                ; =1
100007c20:     	add	x9, x9, #0x1
100007c24:     	b	0x100007bf8 <_main+0x778>
100007c28:     	tbnz	w8, #0x0, 0x100007b20 <_main+0x6a0>
100007c2c:     	mov	w8, #0x302e             ; =12334
100007c30:     	strh	w8, [x19, x20]
100007c34:     	add	x20, x20, #0x2
100007c38:     	b	0x100007b20 <_main+0x6a0>
100007c3c:     	adrp	x1, 0x100008000 <_main+0xb80>
100007c40:     	add	x1, x1, #0xef0
100007c44:     	b	0x100007ac0 <_main+0x640>
100007c48:     	mov	x3, x30
100007c4c:     	bl	0x100008b70 <_main+0x16f0>
100007c50:     	mov	x30, x3
100007c54:     	stp	x29, x30, [sp, #0x90]
100007c58:     	mov	x20, x0
100007c5c:     	mov	x19, x8
100007c60:     	ldr	x0, [x1]
100007c64:     	ldr	w25, [x1, #0x8]
100007c68:     	ldrb	w23, [x1, #0xc]
100007c6c:     	mov	w8, #0x7fffffff         ; =2147483647
100007c70:     	cmp	w25, w8
100007c74:     	b.ne	0x100007cac <_main+0x82c>
100007c78:     	str	x0, [sp, #0x8]
100007c7c:     	str	w8, [sp, #0x10]
100007c80:     	strb	w23, [sp, #0x14]
100007c84:     	ldurh	w8, [x1, #0xd]
100007c88:     	sturh	w8, [sp, #0x15]
100007c8c:     	ldurb	w8, [x1, #0xf]
100007c90:     	strb	w8, [sp, #0x17]
100007c94:     	add	x1, sp, #0x8
100007c98:     	mov	x0, x20
100007c9c:     	bl	0x100008484 <_main+0x1004>
100007ca0:     	strh	wzr, [x19, #0x10]
100007ca4:     	stp	x0, x1, [x19]
100007ca8:     	b	0x100007e88 <_main+0xa08>
100007cac:     	mov	x21, x2
100007cb0:     	ldrb	w24, [x2, #0x8]
100007cb4:     	cbz	w24, 0x100007cdc <_main+0x85c>
100007cb8:     	ldr	x2, [x21]
100007cbc:     	str	x0, [sp, #0x18]
100007cc0:     	str	w25, [sp, #0x20]
100007cc4:     	bl	0x100008aa8 <_main+0x1628>
100007cc8:     	mov	w1, #0x0                ; =0
100007ccc:     	bl	0x100008354 <_main+0xed4>
100007cd0:     	ldr	x0, [sp, #0x28]
100007cd4:     	ldr	w25, [sp, #0x30]
100007cd8:     	ldrb	w23, [sp, #0x34]
100007cdc:     	str	x0, [sp, #0x38]
100007ce0:     	bl	0x1000081d4 <_main+0xd54>
100007ce4:     	mov	x22, x0
100007ce8:     	tbnz	w25, #0x1f, 0x100007d00 <_main+0x880>
100007cec:     	add	w8, w25, #0x2
100007cf0:     	add	x8, x8, w22, uxtw
100007cf4:     	cbz	w24, 0x100007d10 <_main+0x890>
100007cf8:     	ldr	x9, [x21]
100007cfc:     	b	0x100007d14 <_main+0x894>
100007d00:     	sub	w8, w22, w25
100007d04:     	cbz	w24, 0x100007d1c <_main+0x89c>
100007d08:     	ldr	x9, [x21]
100007d0c:     	b	0x100007d20 <_main+0x8a0>
100007d10:     	mov	x9, #0x0                ; =0
100007d14:     	add	x8, x8, x9
100007d18:     	b	0x100007d2c <_main+0x8ac>
100007d1c:     	mov	x9, #0x0                ; =0
100007d20:     	cmp	x8, x9
100007d24:     	csel	x8, x8, x9, hi
100007d28:     	add	x8, x8, #0x2
100007d2c:     	cmp	x8, #0x15b
100007d30:     	b.ls	0x100007d3c <_main+0x8bc>
100007d34:     	bl	0x100008ac8 <_main+0x1648>
100007d38:     	b	0x100007e88 <_main+0xa08>
100007d3c:     	tbz	w23, #0x0, 0x100007d50 <_main+0x8d0>
100007d40:     	mov	w8, #0x2d               ; =45
100007d44:     	strb	w8, [x20]
100007d48:     	mov	w26, #0x1               ; =1
100007d4c:     	b	0x100007d54 <_main+0x8d4>
100007d50:     	mov	x26, #0x0               ; =0
100007d54:     	add	w23, w22, w25
100007d58:     	cmp	w23, #0x1
100007d5c:     	b.lt	0x100007dc8 <_main+0x948>
100007d60:     	mov	w24, w22
100007d64:     	cmp	w23, w22
100007d68:     	b.hs	0x100007e34 <_main+0x9b4>
100007d6c:     	add	x27, x26, x23
100007d70:     	add	x25, x27, #0x1
100007d74:     	sub	x24, x24, x23
100007d78:     	add	x0, x20, x25
100007d7c:     	add	x1, sp, #0x38
100007d80:     	mov	x2, x24
100007d84:     	bl	0x10000814c <_main+0xccc>
100007d88:     	mov	w8, #0x2e               ; =46
100007d8c:     	strb	w8, [x20, x27]
100007d90:     	bl	0x100008ae4 <_main+0x1664>
100007d94:     	add	w8, w22, #0x1
100007d98:     	add	x8, x26, x8
100007d9c:     	ldrb	w9, [x21, #0x8]
100007da0:     	cbz	w9, 0x100007e80 <_main+0xa00>
100007da4:     	ldr	x21, [x21]
100007da8:     	subs	x2, x21, x24
100007dac:     	b.ls	0x100007db8 <_main+0x938>
100007db0:     	add	x0, x20, x8
100007db4:     	bl	0x100008b4c <_main+0x16cc>
100007db8:     	cmp	x21, #0x0
100007dbc:     	cset	w8, eq
100007dc0:     	add	x9, x21, x25
100007dc4:     	b	0x100007e2c <_main+0x9ac>
100007dc8:     	mov	w8, #0x2e30             ; =11824
100007dcc:     	strh	w8, [x20, x26]
100007dd0:     	orr	x24, x26, #0x2
100007dd4:     	neg	w23, w23
100007dd8:     	add	x0, x20, x24
100007ddc:     	mov	w1, #0x30               ; =48
100007de0:     	mov	x2, x23
100007de4:     	bl	0x100007a2c <_main+0x5ac>
100007de8:     	add	x23, x24, x23
100007dec:     	mov	w2, w22
100007df0:     	add	x0, x20, x23
100007df4:     	add	x1, sp, #0x38
100007df8:     	bl	0x10000814c <_main+0xccc>
100007dfc:     	add	x8, x23, w22, uxtw
100007e00:     	ldrb	w9, [x21, #0x8]
100007e04:     	cbz	w9, 0x100007e80 <_main+0xa00>
100007e08:     	ldr	x21, [x21]
100007e0c:     	sub	x9, x8, x24
100007e10:     	subs	x2, x21, x9
100007e14:     	b.ls	0x100007e20 <_main+0x9a0>
100007e18:     	add	x0, x20, x8
100007e1c:     	bl	0x100008b4c <_main+0x16cc>
100007e20:     	cmp	x21, #0x0
100007e24:     	cset	w8, eq
100007e28:     	add	x9, x21, x24
100007e2c:     	sub	x8, x9, x8
100007e30:     	b	0x100007e80 <_main+0xa00>
100007e34:     	add	x22, x20, x26
100007e38:     	add	x1, sp, #0x38
100007e3c:     	mov	x0, x22
100007e40:     	mov	x2, x24
100007e44:     	bl	0x10000814c <_main+0xccc>
100007e48:     	sxtw	x2, w25
100007e4c:     	add	x0, x22, x24
100007e50:     	bl	0x100008b4c <_main+0x16cc>
100007e54:     	add	x8, x26, x23
100007e58:     	ldrb	w9, [x21, #0x8]
100007e5c:     	cbz	w9, 0x100007e80 <_main+0xa00>
100007e60:     	ldr	x21, [x21]
100007e64:     	cbz	x21, 0x100007e80 <_main+0xa00>
100007e68:     	mov	w9, #0x2e               ; =46
100007e6c:     	strb	w9, [x20, x8]
100007e70:     	add	x22, x8, #0x1
100007e74:     	add	x0, x20, x22
100007e78:     	bl	0x100008b40 <_main+0x16c0>
100007e7c:     	add	x8, x21, x22
100007e80:     	strh	wzr, [x19, #0x10]
100007e84:     	stp	x20, x8, [x19]
100007e88:     	ldp	x29, x30, [sp, #0x90]
100007e8c:     	b	0x100008a78 <_main+0x15f8>
100007e90:     	mov	x3, x30
100007e94:     	bl	0x100008b70 <_main+0x16f0>
100007e98:     	mov	x30, x3
100007e9c:     	stp	x29, x30, [sp, #0x90]
100007ea0:     	mov	x20, x0
100007ea4:     	mov	x19, x8
100007ea8:     	ldr	x0, [x1]
100007eac:     	ldr	w24, [x1, #0x8]
100007eb0:     	ldrb	w23, [x1, #0xc]
100007eb4:     	mov	w8, #0x7fffffff         ; =2147483647
100007eb8:     	cmp	w24, w8
100007ebc:     	b.ne	0x100007ef4 <_main+0xa74>
100007ec0:     	str	x0, [sp, #0x8]
100007ec4:     	str	w8, [sp, #0x10]
100007ec8:     	strb	w23, [sp, #0x14]
100007ecc:     	ldurh	w8, [x1, #0xd]
100007ed0:     	sturh	w8, [sp, #0x15]
100007ed4:     	ldurb	w8, [x1, #0xf]
100007ed8:     	strb	w8, [sp, #0x17]
100007edc:     	add	x1, sp, #0x8
100007ee0:     	mov	x0, x20
100007ee4:     	bl	0x100008484 <_main+0x1004>
100007ee8:     	strh	wzr, [x19, #0x10]
100007eec:     	stp	x0, x1, [x19]
100007ef0:     	b	0x100008144 <_main+0xcc4>
100007ef4:     	mov	x21, x2
100007ef8:     	ldrb	w25, [x2, #0x8]
100007efc:     	cbz	w25, 0x100007f24 <_main+0xaa4>
100007f00:     	ldr	x2, [x21]
100007f04:     	str	x0, [sp, #0x18]
100007f08:     	str	w24, [sp, #0x20]
100007f0c:     	bl	0x100008aa8 <_main+0x1628>
100007f10:     	mov	w1, #0x1                ; =1
100007f14:     	bl	0x100008354 <_main+0xed4>
100007f18:     	ldr	x0, [sp, #0x28]
100007f1c:     	ldr	w24, [sp, #0x30]
100007f20:     	ldrb	w23, [sp, #0x34]
100007f24:     	str	x0, [sp, #0x38]
100007f28:     	bl	0x1000081d4 <_main+0xd54>
100007f2c:     	mov	x22, x0
100007f30:     	cbz	w25, 0x100007f48 <_main+0xac8>
100007f34:     	ldr	x8, [x21]
100007f38:     	cmp	x8, #0x154
100007f3c:     	b.lo	0x100007f48 <_main+0xac8>
100007f40:     	bl	0x100008ac8 <_main+0x1648>
100007f44:     	b	0x100008144 <_main+0xcc4>
100007f48:     	tbz	w23, #0x0, 0x100007f5c <_main+0xadc>
100007f4c:     	mov	w8, #0x2d               ; =45
100007f50:     	strb	w8, [x20]
100007f54:     	mov	w27, #0x1               ; =1
100007f58:     	b	0x100007f60 <_main+0xae0>
100007f5c:     	mov	x27, #0x0               ; =0
100007f60:     	orr	x26, x27, #0x2
100007f64:     	subs	w23, w22, #0x1
100007f68:     	add	x8, x26, x23
100007f6c:     	csinc	x25, x8, x27, hi
100007f70:     	bl	0x100008ae4 <_main+0x1664>
100007f74:     	add	x8, x20, x27
100007f78:     	ldr	x9, [sp, #0x38]
100007f7c:     	mov	w10, #0xa               ; =10
100007f80:     	udiv	x11, x9, x10
100007f84:     	msub	w9, w11, w10, w9
100007f88:     	orr	w9, w9, #0x30
100007f8c:     	strb	w9, [x8]
100007f90:     	mov	w9, #0x2e               ; =46
100007f94:     	strb	w9, [x8, #0x1]
100007f98:     	ldrb	w8, [x21, #0x8]
100007f9c:     	cbz	w8, 0x100007fd4 <_main+0xb54>
100007fa0:     	ldr	x8, [x21]
100007fa4:     	subs	x21, x8, x23
100007fa8:     	b.ls	0x100007fc4 <_main+0xb44>
100007fac:     	cmp	w22, #0x1
100007fb0:     	cinc	x23, x25, eq
100007fb4:     	add	x0, x20, x23
100007fb8:     	bl	0x100008b40 <_main+0x16c0>
100007fbc:     	add	x25, x21, x23
100007fc0:     	b	0x100007fd4 <_main+0xb54>
100007fc4:     	cmp	x8, #0x0
100007fc8:     	cset	w9, eq
100007fcc:     	add	x8, x8, x26
100007fd0:     	sub	x25, x8, x9
100007fd4:     	mov	w8, #0x65               ; =101
100007fd8:     	strb	w8, [x20, x25]
100007fdc:     	add	x8, x25, #0x1
100007fe0:     	add	w10, w22, w24
100007fe4:     	subs	w9, w10, #0x1
100007fe8:     	b.ge	0x100008000 <_main+0xb80>
100007fec:     	mov	w9, #0x2d               ; =45
100007ff0:     	strb	w9, [x20, x8]
100007ff4:     	add	x8, x25, #0x2
100007ff8:     	mov	w9, #0x1                ; =1
100007ffc:     	sub	w9, w9, w10
100008000:     	mov	w10, #0xa               ; =10
100008004:     	mov	w11, #0xc9ff            ; =51711
100008008:     	movk	w11, #0x3b9a, lsl #16
10000800c:     	cmp	w9, w11
100008010:     	b.ls	0x10000801c <_main+0xb9c>
100008014:     	mov	w11, #0xa               ; =10
100008018:     	b	0x1000080b8 <_main+0xc38>
10000801c:     	mov	w11, #0xe0ff            ; =57599
100008020:     	movk	w11, #0x5f5, lsl #16
100008024:     	cmp	w9, w11
100008028:     	b.ls	0x100008034 <_main+0xbb4>
10000802c:     	mov	w11, #0x9               ; =9
100008030:     	b	0x1000080b8 <_main+0xc38>
100008034:     	mov	w11, #0x967f            ; =38527
100008038:     	movk	w11, #0x98, lsl #16
10000803c:     	cmp	w9, w11
100008040:     	b.ls	0x10000804c <_main+0xbcc>
100008044:     	mov	w11, #0x8               ; =8
100008048:     	b	0x1000080b8 <_main+0xc38>
10000804c:     	mov	w11, #0x423f            ; =16959
100008050:     	movk	w11, #0xf, lsl #16
100008054:     	cmp	w9, w11
100008058:     	b.ls	0x100008064 <_main+0xbe4>
10000805c:     	mov	w11, #0x7               ; =7
100008060:     	b	0x1000080b8 <_main+0xc38>
100008064:     	lsr	w11, w9, #5
100008068:     	cmp	w11, #0xc34
10000806c:     	b.ls	0x100008078 <_main+0xbf8>
100008070:     	mov	w11, #0x6               ; =6
100008074:     	b	0x1000080b8 <_main+0xc38>
100008078:     	lsr	w11, w9, #4
10000807c:     	cmp	w11, #0x270
100008080:     	b.ls	0x10000808c <_main+0xc0c>
100008084:     	mov	w11, #0x5               ; =5
100008088:     	b	0x1000080b8 <_main+0xc38>
10000808c:     	cmp	w9, #0x3e7
100008090:     	b.ls	0x10000809c <_main+0xc1c>
100008094:     	mov	w11, #0x4               ; =4
100008098:     	b	0x1000080b8 <_main+0xc38>
10000809c:     	cmp	w9, #0x63
1000080a0:     	b.ls	0x1000080ac <_main+0xc2c>
1000080a4:     	mov	w11, #0x3               ; =3
1000080a8:     	b	0x1000080b8 <_main+0xc38>
1000080ac:     	cmp	w9, #0x9
1000080b0:     	mov	w11, #0x1               ; =1
1000080b4:     	cinc	x11, x11, hi
1000080b8:     	mov	x13, #0x0               ; =0
1000080bc:     	add	x12, x11, x8
1000080c0:     	sub	x12, x12, #0x1
1000080c4:     	mov	w14, #0x64              ; =100
1000080c8:     	add	x15, x13, #0x2
1000080cc:     	cmp	x15, x11
1000080d0:     	b.hs	0x10000810c <_main+0xc8c>
1000080d4:     	udiv	w13, w9, w14
1000080d8:     	msub	w9, w13, w14, w9
1000080dc:     	and	w16, w9, #0xff
1000080e0:     	udiv	w16, w16, w10
1000080e4:     	orr	w17, w16, #0x30
1000080e8:     	msub	w9, w16, w10, w9
1000080ec:     	orr	w9, w9, #0x30
1000080f0:     	add	x16, x20, x12
1000080f4:     	strb	w9, [x16]
1000080f8:     	sturb	w17, [x16, #-0x1]
1000080fc:     	sub	x12, x12, #0x2
100008100:     	mov	x9, x13
100008104:     	mov	x13, x15
100008108:     	b	0x1000080c8 <_main+0xc48>
10000810c:     	mov	w10, #0xa               ; =10
100008110:     	cmp	x13, x11
100008114:     	b.hs	0x100008138 <_main+0xcb8>
100008118:     	udiv	w14, w9, w10
10000811c:     	msub	w9, w14, w10, w9
100008120:     	orr	w9, w9, #0x30
100008124:     	strb	w9, [x20, x12]
100008128:     	add	x13, x13, #0x1
10000812c:     	sub	x12, x12, #0x1
100008130:     	mov	x9, x14
100008134:     	b	0x100008110 <_main+0xc90>
100008138:     	add	x8, x11, x8
10000813c:     	strh	wzr, [x19, #0x10]
100008140:     	stp	x20, x8, [x19]
100008144:     	ldp	x29, x30, [sp, #0x90]
100008148:     	b	0x100008a78 <_main+0x15f8>
10000814c:     	mov	x9, #0x0                ; =0
100008150:     	add	x8, x2, x0
100008154:     	sub	x8, x8, #0x1
100008158:     	mov	w10, #0x64              ; =100
10000815c:     	mov	w11, #0xa               ; =10
100008160:     	add	x12, x9, #0x2
100008164:     	cmp	x12, x2
100008168:     	b.hs	0x1000081a4 <_main+0xd24>
10000816c:     	ldr	x9, [x1]
100008170:     	udiv	x13, x9, x10
100008174:     	msub	w9, w13, w10, w9
100008178:     	and	w14, w9, #0xff
10000817c:     	str	x13, [x1]
100008180:     	udiv	w13, w14, w11
100008184:     	orr	w14, w13, #0x30
100008188:     	msub	w9, w13, w11, w9
10000818c:     	orr	w9, w9, #0x30
100008190:     	strb	w9, [x8]
100008194:     	sturb	w14, [x8, #-0x1]
100008198:     	sub	x8, x8, #0x2
10000819c:     	mov	x9, x12
1000081a0:     	b	0x100008160 <_main+0xce0>
1000081a4:     	mov	w10, #0xa               ; =10
1000081a8:     	cmp	x9, x2
1000081ac:     	b.hs	0x1000081d0 <_main+0xd50>
1000081b0:     	ldr	x11, [x1]
1000081b4:     	udiv	x12, x11, x10
1000081b8:     	msub	w11, w12, w10, w11
1000081bc:     	str	x12, [x1]
1000081c0:     	orr	w11, w11, #0x30
1000081c4:     	strb	w11, [x8], #-0x1
1000081c8:     	add	x9, x9, #0x1
1000081cc:     	b	0x1000081a8 <_main+0xd28>
1000081d0:     	ret
1000081d4:     	mov	x8, #0x6fc10000         ; =1874919424
1000081d8:     	movk	x8, #0x86f2, lsl #32
1000081dc:     	movk	x8, #0x23, lsl #48
1000081e0:     	cmp	x0, x8
1000081e4:     	b.lo	0x1000081f0 <_main+0xd70>
1000081e8:     	mov	w0, #0x11               ; =17
1000081ec:     	ret
1000081f0:     	mov	x8, #0x7fff             ; =32767
1000081f4:     	movk	x8, #0xa4c6, lsl #16
1000081f8:     	movk	x8, #0x8d7e, lsl #32
1000081fc:     	movk	x8, #0x3, lsl #48
100008200:     	cmp	x0, x8
100008204:     	b.ls	0x100008210 <_main+0xd90>
100008208:     	mov	w0, #0x10               ; =16
10000820c:     	ret
100008210:     	mov	x8, #0x3fff             ; =16383
100008214:     	movk	x8, #0x107a, lsl #16
100008218:     	movk	x8, #0x5af3, lsl #32
10000821c:     	cmp	x0, x8
100008220:     	b.ls	0x10000822c <_main+0xdac>
100008224:     	mov	w0, #0xf                ; =15
100008228:     	ret
10000822c:     	mov	x8, #0x9fff             ; =40959
100008230:     	movk	x8, #0x4e72, lsl #16
100008234:     	movk	x8, #0x918, lsl #32
100008238:     	cmp	x0, x8
10000823c:     	b.ls	0x100008248 <_main+0xdc8>
100008240:     	mov	w0, #0xe                ; =14
100008244:     	ret
100008248:     	mov	x8, #0xfff              ; =4095
10000824c:     	movk	x8, #0xd4a5, lsl #16
100008250:     	movk	x8, #0xe8, lsl #32
100008254:     	cmp	x0, x8
100008258:     	b.ls	0x100008264 <_main+0xde4>
10000825c:     	mov	w0, #0xd                ; =13
100008260:     	ret
100008264:     	mov	x8, #0xe7ff             ; =59391
100008268:     	movk	x8, #0x4876, lsl #16
10000826c:     	movk	x8, #0x17, lsl #32
100008270:     	cmp	x0, x8
100008274:     	b.ls	0x100008280 <_main+0xe00>
100008278:     	mov	w0, #0xc                ; =12
10000827c:     	ret
100008280:     	mov	x8, #0xe3ff             ; =58367
100008284:     	movk	x8, #0x540b, lsl #16
100008288:     	movk	x8, #0x2, lsl #32
10000828c:     	cmp	x0, x8
100008290:     	b.ls	0x10000829c <_main+0xe1c>
100008294:     	mov	w0, #0xb                ; =11
100008298:     	ret
10000829c:     	mov	w8, #0xc9ff             ; =51711
1000082a0:     	movk	w8, #0x3b9a, lsl #16
1000082a4:     	cmp	x0, x8
1000082a8:     	b.ls	0x1000082b4 <_main+0xe34>
1000082ac:     	mov	w0, #0xa                ; =10
1000082b0:     	ret
1000082b4:     	mov	w8, #0xe0ff             ; =57599
1000082b8:     	movk	w8, #0x5f5, lsl #16
1000082bc:     	cmp	x0, x8
1000082c0:     	b.ls	0x1000082cc <_main+0xe4c>
1000082c4:     	mov	w0, #0x9                ; =9
1000082c8:     	ret
1000082cc:     	mov	w8, #0x967f             ; =38527
1000082d0:     	movk	w8, #0x98, lsl #16
1000082d4:     	cmp	x0, x8
1000082d8:     	b.ls	0x1000082e4 <_main+0xe64>
1000082dc:     	mov	w0, #0x8                ; =8
1000082e0:     	ret
1000082e4:     	mov	w8, #0x423f             ; =16959
1000082e8:     	movk	w8, #0xf, lsl #16
1000082ec:     	cmp	x0, x8
1000082f0:     	b.ls	0x1000082fc <_main+0xe7c>
1000082f4:     	mov	w0, #0x7                ; =7
1000082f8:     	ret
1000082fc:     	lsr	x8, x0, #5
100008300:     	cmp	x8, #0xc34
100008304:     	b.ls	0x100008310 <_main+0xe90>
100008308:     	mov	w0, #0x6                ; =6
10000830c:     	ret
100008310:     	lsr	x8, x0, #4
100008314:     	cmp	x8, #0x270
100008318:     	b.ls	0x100008324 <_main+0xea4>
10000831c:     	mov	w0, #0x5                ; =5
100008320:     	ret
100008324:     	cmp	x0, #0x3e7
100008328:     	b.ls	0x100008334 <_main+0xeb4>
10000832c:     	mov	w0, #0x4                ; =4
100008330:     	ret
100008334:     	cmp	x0, #0x63
100008338:     	b.ls	0x100008344 <_main+0xec4>
10000833c:     	mov	w0, #0x3                ; =3
100008340:     	ret
100008344:     	cmp	x0, #0x9
100008348:     	mov	w8, #0x1                ; =1
10000834c:     	cinc	w0, w8, hi
100008350:     	ret
100008354:     	stp	x26, x25, [sp, #-0x50]!
100008358:     	stp	x24, x23, [sp, #0x10]
10000835c:     	stp	x22, x21, [sp, #0x20]
100008360:     	stp	x20, x19, [sp, #0x30]
100008364:     	stp	x29, x30, [sp, #0x40]
100008368:     	mov	x21, x2
10000836c:     	mov	x22, x1
100008370:     	mov	x19, x8
100008374:     	ldr	x20, [x0]
100008378:     	ldr	w23, [x0, #0x8]
10000837c:     	ldrb	w24, [x0, #0xc]
100008380:     	mov	x0, x20
100008384:     	bl	0x1000081d4 <_main+0xd54>
100008388:     	sub	w8, w0, #0x1
10000838c:     	add	x9, x21, x23
100008390:     	add	x8, x9, x8
100008394:     	add	x9, x21, w0, uxtw
100008398:     	neg	w10, w23
10000839c:     	subs	x9, x9, x10
1000083a0:     	csel	x9, xzr, x9, lo
1000083a4:     	cmp	w23, #0x0
1000083a8:     	csel	x8, x8, x9, gt
1000083ac:     	tst	w22, #0x1
1000083b0:     	csinc	x8, x8, x21, eq
1000083b4:     	cmp	x8, w0, uxtw
1000083b8:     	b.hs	0x10000845c <_main+0xfdc>
1000083bc:     	mov	w9, w0
1000083c0:     	mvn	x8, x8
1000083c4:     	add	x8, x8, x9
1000083c8:     	mov	w9, #0xa                ; =10
1000083cc:     	cbz	x8, 0x1000083e0 <_main+0xf60>
1000083d0:     	add	w23, w23, #0x1
1000083d4:     	sub	x8, x8, #0x1
1000083d8:     	udiv	x20, x20, x9
1000083dc:     	cbnz	x8, 0x1000083d0 <_main+0xf50>
1000083e0:     	mov	w9, #0xa                ; =10
1000083e4:     	udiv	x8, x20, x9
1000083e8:     	msub	x9, x8, x9, x20
1000083ec:     	cmp	x9, #0x5
1000083f0:     	b.lo	0x10000845c <_main+0xfdc>
1000083f4:     	mov	x21, #0x0               ; =0
1000083f8:     	add	x20, x8, #0x1
1000083fc:     	mov	w25, #0xa               ; =10
100008400:     	mov	x22, x20
100008404:     	orr	x26, x22, x21
100008408:     	mov	x0, x22
10000840c:     	mov	x1, x21
100008410:     	mov	w2, #0xa                ; =10
100008414:     	mov	x3, #0x0                ; =0
100008418:     	bl	0x100007988 <_main+0x508>
10000841c:     	umulh	x8, x0, x25
100008420:     	madd	x9, x1, x25, x8
100008424:     	add	x8, x0, x0, lsl #2
100008428:     	subs	x8, x22, x8, lsl #1
10000842c:     	sbc	x9, x21, x9
100008430:     	cbz	x26, 0x100008444 <_main+0xfc4>
100008434:     	mov	x22, x0
100008438:     	mov	x21, x1
10000843c:     	orr	x8, x8, x9
100008440:     	cbz	x8, 0x100008404 <_main+0xf84>
100008444:     	cbz	x26, 0x100008450 <_main+0xfd0>
100008448:     	add	w23, w23, #0x1
10000844c:     	b	0x10000845c <_main+0xfdc>
100008450:     	mov	w8, #0xa                ; =10
100008454:     	add	w23, w23, #0x2
100008458:     	udiv	x20, x20, x8
10000845c:     	str	x20, [x19]
100008460:     	str	w23, [x19, #0x8]
100008464:     	and	w8, w24, #0x1
100008468:     	strb	w8, [x19, #0xc]
10000846c:     	ldp	x29, x30, [sp, #0x40]
100008470:     	ldp	x20, x19, [sp, #0x30]
100008474:     	ldp	x22, x21, [sp, #0x20]
100008478:     	ldp	x24, x23, [sp, #0x10]
10000847c:     	ldp	x26, x25, [sp], #0x50
100008480:     	ret
100008484:     	ldr	x9, [x1]
100008488:     	ldrb	w8, [x1, #0xc]
10000848c:     	tbz	w8, #0x0, 0x100008498 <_main+0x1018>
100008490:     	mov	w10, #0x2d              ; =45
100008494:     	strb	w10, [x0]
100008498:     	and	x10, x8, #0x1
10000849c:     	add	x10, x0, x10
1000084a0:     	cbz	x9, 0x1000084b4 <_main+0x1034>
1000084a4:     	mov	w9, #0x6e               ; =110
1000084a8:     	strb	w9, [x10, #0x2]
1000084ac:     	mov	w9, #0x616e             ; =24942
1000084b0:     	b	0x1000084c0 <_main+0x1040>
1000084b4:     	mov	w9, #0x66               ; =102
1000084b8:     	strb	w9, [x10, #0x2]
1000084bc:     	mov	w9, #0x6e69             ; =28265
1000084c0:     	strh	w9, [x10]
1000084c4:     	tst	w8, #0x1
1000084c8:     	mov	w8, #0x3                ; =3
1000084cc:     	cinc	x1, x8, ne
1000084d0:     	ret
1000084d4:     	mov	x3, x30
1000084d8:     	bl	0x100008b70 <_main+0x16f0>
1000084dc:     	mov	x30, x3
1000084e0:     	stp	x29, x30, [sp, #0x90]
1000084e4:     	mov	x22, x2
1000084e8:     	mov	x21, x1
1000084ec:     	mov	x20, x0
1000084f0:     	mov	x19, x8
1000084f4:     	mov	w8, #0x1                ; =1
1000084f8:     	lsl	x8, x8, x1
1000084fc:     	sub	x9, x8, #0x1
100008500:     	and	x9, x9, x0
100008504:     	lsr	x10, x0, x1
100008508:     	and	x11, x2, #0x1f
10000850c:     	mov	x12, #-0x1              ; =-1
100008510:     	lsl	x11, x12, x11
100008514:     	bic	x11, x10, x11
100008518:     	orr	x10, x11, x9
10000851c:     	cbnz	x10, 0x10000852c <_main+0x10ac>
100008520:     	str	xzr, [x19]
100008524:     	str	wzr, [x19, #0x8]
100008528:     	b	0x1000089c0 <_main+0x1540>
10000852c:     	mov	w10, #-0x1              ; =-1
100008530:     	lsl	w12, w10, w22
100008534:     	eor	w12, w12, w11
100008538:     	cmn	w12, #0x1
10000853c:     	b.eq	0x1000085f0 <_main+0x1170>
100008540:     	sub	w12, w22, #0x1
100008544:     	lsl	w10, w10, w12
100008548:     	and	w12, w21, #0x3f
10000854c:     	mvn	w13, w12
100008550:     	add	w13, w10, w13
100008554:     	add	w13, w13, w11
100008558:     	orr	x8, x9, x8
10000855c:     	sub	w10, w10, w12
100008560:     	cmp	x11, #0x0
100008564:     	csel	x12, x8, x9, ne
100008568:     	csel	w10, w13, w10, ne
10000856c:     	str	x12, [sp, #0x18]
100008570:     	mov	x8, #0xcd1b             ; =52507
100008574:     	movk	x8, #0x784b, lsl #16
100008578:     	movk	x8, #0x949a, lsl #32
10000857c:     	lsl	x24, x12, #2
100008580:     	cmp	x9, #0x0
100008584:     	ccmp	x11, #0x0, #0x4, eq
100008588:     	cset	w28, eq
10000858c:     	tbnz	w10, #0x1f, 0x1000085fc <_main+0x117c>
100008590:     	mov	x9, #0xfbcf             ; =64463
100008594:     	movk	x9, #0x9a84, lsl #16
100008598:     	movk	x9, #0x9a20, lsl #32
10000859c:     	mul	x9, x10, x9
1000085a0:     	lsr	x9, x9, #49
1000085a4:     	cmp	w10, #0x3
1000085a8:     	cset	w11, hi
1000085ac:     	sub	w23, w9, w11
1000085b0:     	sub	w10, w23, w10
1000085b4:     	mul	x9, x23, x8
1000085b8:     	lsr	x9, x9, #46
1000085bc:     	add	w26, w10, w9
1000085c0:     	add	w10, w23, #0x19
1000085c4:     	and	w10, w10, #0xffff
1000085c8:     	mov	w11, #0x1a              ; =26
1000085cc:     	udiv	w12, w10, w11
1000085d0:     	mul	w10, w12, w11
1000085d4:     	adrp	x11, 0x100008000 <_main+0xb80>
1000085d8:     	add	x11, x11, #0xd30
1000085dc:     	add	x11, x11, w12, uxtw #4
1000085e0:     	subs	w12, w10, w23
1000085e4:     	b.ne	0x100008668 <_main+0x11e8>
1000085e8:     	ldp	x8, x9, [x11]
1000085ec:     	b	0x100008720 <_main+0x12a0>
1000085f0:     	str	x9, [x19]
1000085f4:     	mov	w8, #0x7fffffff         ; =2147483647
1000085f8:     	b	0x1000089bc <_main+0x153c>
1000085fc:     	str	w28, [sp, #0x14]
100008600:     	neg	w9, w10
100008604:     	mov	x11, #0x8218            ; =33304
100008608:     	movk	x11, #0xb2bd, lsl #16
10000860c:     	movk	x11, #0xb2ef, lsl #32
100008610:     	mul	x11, x9, x11
100008614:     	lsr	x11, x11, #48
100008618:     	cmn	w10, #0x1
10000861c:     	cset	w12, ne
100008620:     	sub	w28, w11, w12
100008624:     	add	w14, w28, w10
100008628:     	sub	w9, w9, w28
10000862c:     	mul	x10, x9, x8
100008630:     	lsr	x10, x10, #46
100008634:     	sub	w26, w28, w10
100008638:     	and	w11, w9, #0xffff
10000863c:     	mov	w12, #0x1a              ; =26
100008640:     	udiv	w13, w11, w12
100008644:     	mul	w11, w13, w12
100008648:     	adrp	x12, 0x100008000 <_main+0xb80>
10000864c:     	add	x12, x12, #0xe20
100008650:     	add	x12, x12, w13, uxtw #4
100008654:     	subs	w13, w9, w11
100008658:     	str	x14, [sp, #0x8]
10000865c:     	b.ne	0x10000879c <_main+0x131c>
100008660:     	ldp	x8, x9, [x12]
100008664:     	b	0x100008850 <_main+0x13d0>
100008668:     	adrp	x13, 0x100008000 <_main+0xb80>
10000866c:     	add	x13, x13, #0xbc0
100008670:     	ldr	x12, [x13, w12, uxtw #3]
100008674:     	ldp	x13, x11, [x11]
100008678:     	sub	x13, x13, #0x1
10000867c:     	umulh	x14, x13, x12
100008680:     	mul	x13, x13, x12
100008684:     	mul	x15, x11, x12
100008688:     	umulh	x11, x11, x12
10000868c:     	mul	x8, x10, x8
100008690:     	lsr	x8, x8, #46
100008694:     	sub	w8, w8, w9
100008698:     	mvn	w9, w8
10000869c:     	lsr	x10, x13, x8
1000086a0:     	lsl	x12, x14, #1
1000086a4:     	lsl	x9, x12, x9
1000086a8:     	orr	x9, x9, x10
1000086ac:     	lsr	x10, x14, x8
1000086b0:     	tst	x8, #0x40
1000086b4:     	csel	x9, x10, x9, ne
1000086b8:     	csel	x10, xzr, x10, ne
1000086bc:     	mov	w12, #0x40              ; =64
1000086c0:     	sub	w8, w12, w8
1000086c4:     	mvn	w12, w8
1000086c8:     	lsl	x11, x11, x8
1000086cc:     	lsr	x13, x15, #1
1000086d0:     	lsr	x12, x13, x12
1000086d4:     	orr	x11, x11, x12
1000086d8:     	lsl	x12, x15, x8
1000086dc:     	and	x8, x8, #0x7f
1000086e0:     	tst	x8, #0x40
1000086e4:     	csel	x8, x12, x11, ne
1000086e8:     	csel	x11, xzr, x12, ne
1000086ec:     	adrp	x12, 0x100008000 <_main+0xb80>
1000086f0:     	add	x12, x12, #0xce4
1000086f4:     	lsr	w13, w23, #4
1000086f8:     	ldr	w12, [x12, w13, uxtw #2]
1000086fc:     	ubfiz	w13, w23, #1, #4
100008700:     	lsr	w12, w12, w13
100008704:     	and	w12, w12, #0x3
100008708:     	adds	x9, x11, x9
10000870c:     	adc	x8, x8, x10
100008710:     	adds	x9, x9, x12
100008714:     	cinc	x10, x8, hs
100008718:     	adds	x8, x9, #0x1
10000871c:     	cinc	x9, x10, hs
100008720:     	stp	x8, x9, [sp, #0x20]
100008724:     	add	x1, sp, #0x20
100008728:     	add	w2, w26, #0x7d
10000872c:     	mov	x0, x24
100008730:     	bl	0x100008a14 <_main+0x1594>
100008734:     	mov	x25, x0
100008738:     	orr	x0, x24, #0x2
10000873c:     	bl	0x100008b28 <_main+0x16a8>
100008740:     	mov	x27, x0
100008744:     	cmp	w28, #0x0
100008748:     	mov	x8, #-0x2               ; =-2
10000874c:     	cinc	x28, x8, eq
100008750:     	add	x0, x28, x24
100008754:     	bl	0x100008b28 <_main+0x16a8>
100008758:     	mov	x26, x0
10000875c:     	cmp	w23, #0x16
100008760:     	b.hs	0x100008790 <_main+0x1310>
100008764:     	mov	w8, #0x5                ; =5
100008768:     	udiv	x8, x24, x8
10000876c:     	add	x8, x8, x8, lsl #2
100008770:     	cmp	x24, x8
100008774:     	ldr	x8, [sp, #0x18]
100008778:     	b.eq	0x1000088d8 <_main+0x1458>
10000877c:     	tbnz	w8, #0x0, 0x1000088f0 <_main+0x1470>
100008780:     	add	x0, x28, x24
100008784:     	bl	0x100008b54 <_main+0x16d4>
100008788:     	mov	w8, #0x0                ; =0
10000878c:     	b	0x10000890c <_main+0x148c>
100008790:     	mov	w8, #0x0                ; =0
100008794:     	mov	w0, #0x0                ; =0
100008798:     	b	0x10000890c <_main+0x148c>
10000879c:     	adrp	x14, 0x100008000 <_main+0xb80>
1000087a0:     	add	x14, x14, #0xbc0
1000087a4:     	ldr	x13, [x14, w13, uxtw #3]
1000087a8:     	ldp	x14, x12, [x12]
1000087ac:     	umulh	x15, x14, x13
1000087b0:     	mul	x14, x14, x13
1000087b4:     	mul	x16, x12, x13
1000087b8:     	umulh	x12, x12, x13
1000087bc:     	mul	x8, x11, x8
1000087c0:     	lsr	x8, x8, #46
1000087c4:     	sub	w8, w10, w8
1000087c8:     	mvn	w10, w8
1000087cc:     	lsr	x11, x14, x8
1000087d0:     	lsl	x13, x15, #1
1000087d4:     	lsl	x10, x13, x10
1000087d8:     	orr	x10, x10, x11
1000087dc:     	lsr	x11, x15, x8
1000087e0:     	tst	x8, #0x40
1000087e4:     	csel	x10, x11, x10, ne
1000087e8:     	csel	x11, xzr, x11, ne
1000087ec:     	mov	w13, #0x40              ; =64
1000087f0:     	sub	w8, w13, w8
1000087f4:     	mvn	w13, w8
1000087f8:     	lsl	x12, x12, x8
1000087fc:     	lsr	x14, x16, #1
100008800:     	lsr	x13, x14, x13
100008804:     	orr	x12, x12, x13
100008808:     	lsl	x13, x16, x8
10000880c:     	and	x8, x8, #0x7f
100008810:     	tst	x8, #0x40
100008814:     	csel	x8, x13, x12, ne
100008818:     	csel	x12, xzr, x13, ne
10000881c:     	adrp	x13, 0x100008000 <_main+0xb80>
100008820:     	add	x13, x13, #0xc90
100008824:     	lsr	w14, w9, #4
100008828:     	ldr	w13, [x13, w14, uxtw #2]
10000882c:     	ubfiz	w9, w9, #1, #4
100008830:     	lsr	w9, w13, w9
100008834:     	and	w9, w9, #0x3
100008838:     	adds	x10, x10, x12
10000883c:     	adc	x8, x11, x8
100008840:     	adds	x9, x10, x9
100008844:     	cinc	x10, x8, hs
100008848:     	adds	x8, x9, #0x1
10000884c:     	cinc	x9, x10, hs
100008850:     	stp	x8, x9, [sp, #0x30]
100008854:     	add	x1, sp, #0x30
100008858:     	add	w2, w26, #0x7c
10000885c:     	mov	x0, x24
100008860:     	bl	0x100008a14 <_main+0x1594>
100008864:     	mov	x25, x0
100008868:     	orr	x0, x24, #0x2
10000886c:     	bl	0x100008b34 <_main+0x16b4>
100008870:     	mov	x27, x0
100008874:     	ldr	w23, [sp, #0x14]
100008878:     	cmp	w23, #0x0
10000887c:     	mov	x8, #-0x2               ; =-2
100008880:     	cinc	x8, x8, eq
100008884:     	add	x0, x8, x24
100008888:     	bl	0x100008b34 <_main+0x16b4>
10000888c:     	mov	x26, x0
100008890:     	ldr	x14, [sp, #0x18]
100008894:     	ands	x8, x14, #0x1
100008898:     	cset	w9, eq
10000889c:     	and	w9, w9, w23
1000088a0:     	sub	x10, x27, x8
1000088a4:     	mov	w8, #0x1                ; =1
1000088a8:     	mov	x11, #-0x1              ; =-1
1000088ac:     	lsl	x11, x11, x28
1000088b0:     	bics	xzr, x24, x11
1000088b4:     	cset	w11, eq
1000088b8:     	cmp	w28, #0x3e
1000088bc:     	csel	w11, wzr, w11, hi
1000088c0:     	cmp	w28, #0x2
1000088c4:     	csel	w8, w8, w11, lo
1000088c8:     	csel	w0, w9, wzr, lo
1000088cc:     	csel	x27, x10, x27, lo
1000088d0:     	ldr	x23, [sp, #0x8]
1000088d4:     	b	0x100008910 <_main+0x1490>
1000088d8:     	mov	x0, x24
1000088dc:     	bl	0x100008b54 <_main+0x16d4>
1000088e0:     	ldr	x14, [sp, #0x18]
1000088e4:     	mov	x8, x0
1000088e8:     	mov	w0, #0x0                ; =0
1000088ec:     	b	0x100008910 <_main+0x1490>
1000088f0:     	orr	x0, x24, #0x2
1000088f4:     	bl	0x100008b54 <_main+0x16d4>
1000088f8:     	mov	x9, x0
1000088fc:     	mov	w8, #0x0                ; =0
100008900:     	mov	w0, #0x0                ; =0
100008904:     	and	x9, x9, #0x1
100008908:     	sub	x27, x27, x9
10000890c:     	ldr	x14, [sp, #0x18]
100008910:     	mov	w10, #0x0               ; =0
100008914:     	mov	w9, #0x0                ; =0
100008918:     	mov	w11, #0xa               ; =10
10000891c:     	udiv	x27, x27, x11
100008920:     	udiv	x12, x26, x11
100008924:     	cmp	x27, x12
100008928:     	b.ls	0x10000894c <_main+0x14cc>
10000892c:     	msub	x13, x12, x11, x26
100008930:     	cmp	x13, #0x0
100008934:     	cset	w13, eq
100008938:     	and	w0, w0, w13
10000893c:     	tst	w10, #0xff
100008940:     	cset	w10, eq
100008944:     	bl	0x100008af4 <_main+0x1674>
100008948:     	b	0x10000891c <_main+0x149c>
10000894c:     	tbz	w0, #0x0, 0x100008970 <_main+0x14f0>
100008950:     	mov	w11, #0xa               ; =10
100008954:     	udiv	x12, x26, x11
100008958:     	msub	x13, x12, x11, x26
10000895c:     	cbnz	x13, 0x100008970 <_main+0x14f0>
100008960:     	tst	w10, #0xff
100008964:     	cset	w10, eq
100008968:     	bl	0x100008af4 <_main+0x1674>
10000896c:     	b	0x100008954 <_main+0x14d4>
100008970:     	and	w11, w10, #0xff
100008974:     	cmp	w11, #0x5
100008978:     	cset	w11, eq
10000897c:     	tst	x25, #0x1
100008980:     	mov	w12, #0x4               ; =4
100008984:     	cinc	w12, w12, ne
100008988:     	tst	w8, w11
10000898c:     	csel	w8, w12, w10, ne
100008990:     	and	w8, w8, #0xff
100008994:     	cmp	x25, x26
100008998:     	cset	w10, eq
10000899c:     	eor	w11, w0, #0x1
1000089a0:     	orr	w11, w14, w11
1000089a4:     	cmp	w8, #0x4
1000089a8:     	and	w8, w10, w11
1000089ac:     	csinc	w8, w8, wzr, ls
1000089b0:     	add	x8, x25, x8
1000089b4:     	str	x8, [x19]
1000089b8:     	add	w8, w9, w23
1000089bc:     	str	w8, [x19, #0x8]
1000089c0:     	and	w8, w22, #0x1f
1000089c4:     	add	w8, w21, w8
1000089c8:     	lsr	x8, x20, x8
1000089cc:     	and	w8, w8, #0x1
1000089d0:     	strb	w8, [x19, #0xc]
1000089d4:     	ldp	x29, x30, [sp, #0x90]
1000089d8:     	b	0x100008a78 <_main+0x15f8>
1000089dc:     	mov	w8, #0x0                ; =0
1000089e0:     	mov	w9, #0x5                ; =5
1000089e4:     	cbz	x0, 0x100008a04 <_main+0x1584>
1000089e8:     	udiv	x10, x0, x9
1000089ec:     	add	x11, x10, x10, lsl #2
1000089f0:     	cmp	x0, x11
1000089f4:     	b.ne	0x100008a08 <_main+0x1588>
1000089f8:     	add	w8, w8, #0x1
1000089fc:     	mov	x0, x10
100008a00:     	cbnz	x10, 0x1000089e8 <_main+0x1568>
100008a04:     	mov	w8, #0x0                ; =0
100008a08:     	cmp	w8, w1
100008a0c:     	cset	w0, hs
100008a10:     	ret
100008a14:     	cmp	w2, #0x80
100008a18:     	b.hs	0x100008a4c <_main+0x15cc>
100008a1c:     	ldp	x9, x8, [x1]
100008a20:     	umulh	x10, x8, x0
100008a24:     	mul	x8, x8, x0
100008a28:     	umulh	x9, x9, x0
100008a2c:     	adds	x8, x9, x8
100008a30:     	cinc	x9, x10, hs
100008a34:     	lsr	x8, x8, x2
100008a38:     	lsl	x9, x9, #1
100008a3c:     	mvn	w10, w2
100008a40:     	lsl	x9, x9, x10
100008a44:     	orr	x0, x9, x8
100008a48:     	ret
100008a4c:     	mov	x0, #0x0                ; =0
100008a50:     	ret
100008a54:     	mov	x8, #0x0                ; =0
100008a58:     	cmp	x2, x8
100008a5c:     	b.eq	0x100008a70 <_main+0x15f0>
100008a60:     	ldrb	w9, [x1, x8]
100008a64:     	strb	w9, [x0, x8]
100008a68:     	add	x8, x8, #0x1
100008a6c:     	b	0x100008a58 <_main+0x15d8>
100008a70:     	mov	x0, x2
100008a74:     	ret
100008a78:     	ldp	x20, x19, [sp, #0x80]
100008a7c:     	ldp	x22, x21, [sp, #0x70]
100008a80:     	ldp	x24, x23, [sp, #0x60]
100008a84:     	ldp	x26, x25, [sp, #0x50]
100008a88:     	ldp	x28, x27, [sp, #0x40]
100008a8c:     	add	sp, sp, #0xa0
100008a90:     	ret
100008a94:     	add	x20, sp, #0x18
100008a98:     	add	x8, sp, #0x18
100008a9c:     	add	x1, sp, #0x8
100008aa0:     	mov	x0, x19
100008aa4:     	ret
100008aa8:     	strb	w23, [sp, #0x24]
100008aac:     	ldurh	w8, [x1, #0xd]
100008ab0:     	sturh	w8, [sp, #0x25]
100008ab4:     	ldurb	w8, [x1, #0xf]
100008ab8:     	strb	w8, [sp, #0x27]
100008abc:     	add	x8, sp, #0x28
100008ac0:     	add	x0, sp, #0x18
100008ac4:     	ret
100008ac8:     	adrp	x8, 0x100008000 <_main+0xb80>
100008acc:     	add	x8, x8, #0xba8
100008ad0:     	ldr	q0, [x8]
100008ad4:     	str	q0, [x19]
100008ad8:     	mov	w8, #0x66               ; =102
100008adc:     	str	x8, [x19, #0x10]
100008ae0:     	ret
100008ae4:     	add	x0, x20, x26
100008ae8:     	add	x1, sp, #0x38
100008aec:     	mov	x2, x23
100008af0:     	b	0x10000814c <_main+0xccc>
100008af4:     	and	w8, w8, w10
100008af8:     	udiv	x13, x25, x11
100008afc:     	msub	w10, w13, w11, w25
100008b00:     	add	w9, w9, #0x1
100008b04:     	mov	x26, x12
100008b08:     	mov	x25, x13
100008b0c:     	ret
100008b10:     	mov	x9, #0x0                ; =0
100008b14:     	ldp	x10, x20, [x20]
100008b18:     	mov	w11, #0x1               ; =1
100008b1c:     	mov	x12, #0x80000000800000  ; =36028797027352576
100008b20:     	movk	x12, #0x1
100008b24:     	ret
100008b28:     	add	x1, sp, #0x20
100008b2c:     	add	w2, w26, #0x7d
100008b30:     	b	0x100008a14 <_main+0x1594>
100008b34:     	add	x1, sp, #0x30
100008b38:     	add	w2, w26, #0x7c
100008b3c:     	b	0x100008a14 <_main+0x1594>
100008b40:     	mov	w1, #0x30               ; =48
100008b44:     	mov	x2, x21
100008b48:     	b	0x100007a2c <_main+0x5ac>
100008b4c:     	mov	w1, #0x30               ; =48
100008b50:     	b	0x100007a2c <_main+0x5ac>
100008b54:     	mov	x1, x23
100008b58:     	b	0x1000089dc <_main+0x155c>
100008b5c:     	adrp	x8, 0x100008000 <_main+0xb80>
100008b60:     	add	x8, x8, #0xf02
100008b64:     	adrp	x9, 0x100008000 <_main+0xb80>
100008b68:     	add	x9, x9, #0xefd
100008b6c:     	ret
100008b70:     	sub	sp, sp, #0xa0
100008b74:     	stp	x28, x27, [sp, #0x40]
100008b78:     	stp	x26, x25, [sp, #0x50]
100008b7c:     	stp	x24, x23, [sp, #0x60]
100008b80:     	stp	x22, x21, [sp, #0x70]
100008b84:     	stp	x20, x19, [sp, #0x80]
100008b88:     	ret
		...
100008ba0:     	udf	#0x1
		...
100008bb8:     	udf	#0x66
100008bbc:     	udf	#0x0
100008bc0:     	udf	#0x1
100008bc4:     	udf	#0x0
100008bc8:     	udf	#0x5
100008bcc:     	udf	#0x0
100008bd0:     	udf	#0x19
100008bd4:     	udf	#0x0
100008bd8:     	udf	#0x7d
100008bdc:     	udf	#0x0
100008be0:     	udf	#0x271
100008be4:     	udf	#0x0
100008be8:     	udf	#0xc35
100008bec:     	udf	#0x0
100008bf0:     	udf	#0x3d09
100008bf4:     	udf	#0x0
100008bf8:     	<unknown>
100008bfc:     	udf	#0x0
100008c00:     	<unknown>
100008c04:     	udf	#0x0
100008c08:     	<unknown>
100008c0c:     	udf	#0x0
100008c10:     	<unknown>
100008c14:     	udf	#0x0
100008c18:     	<unknown>
100008c1c:     	udf	#0x0
100008c20:     	<unknown>
100008c24:     	udf	#0x0
100008c28:     	ldlarh	w21, [x28]
100008c2c:     	udf	#0x0
100008c30:     	<unknown>
100008c34:     	udf	#0x1
100008c38:     	<unknown>
100008c3c:     	udf	#0x7
100008c40:     	<unknown>
100008c44:     	udf	#0x23
100008c48:     	<unknown>
100008c4c:     	udf	#0xb1
100008c50:     	stp	s25, s26, [x14, #-0x9c]!
100008c54:     	udf	#0x378
100008c58:     	<unknown>
100008c5c:     	udf	#0x1158
100008c60:     	<unknown>
100008c64:     	udf	#0x56bc
100008c68:     	<unknown>
100008c6c:     	<unknown>
100008c70:     	<unknown>
100008c74:     	<unknown>
100008c78:     	<unknown>
100008c7c:     	<unknown>
100008c80:     	<unknown>
100008c84:     	<unknown>
100008c88:     	<unknown>
100008c8c:     	<unknown>
		...
100008ca0:     	<unknown>
100008ca4:     	<unknown>
100008ca8:     	<unknown>
100008cac:     	<unknown>
100008cb0:     	<unknown>
100008cb4:     	<unknown>
100008cb8:     	smlslb	z5.h, z10.b, z21.b
100008cbc:     	smlalt	z0.h, z10.b, z16.b
100008cc0:     	ssubwt	z16.h, z10.h, z21.b
100008cc4:     	<unknown>
100008cc8:     	bl	0xf9109dc8 <dyld_stub_binder+0xf9109dc8>
100008ccc:     	<unknown>
100008cd0:     	b.pl	0x1000934d8 <dyld_private+0x834c0>
100008cd4:     	<unknown>
100008cd8:     	<unknown>
100008cdc:     	sub	w21, w10, #0x15, lsl #12 ; =0x15000
100008ce0:     	udf	#0x105
100008ce4:     	bc.mi	0x1000b158c <dyld_private+0xa1574>
100008ce8:     	mla	z5.b, p5/m, z10.b, z5.b
100008cec:     	adr	x0, 0x100010eec <dyld_private+0xed4>
100008cf0:     	<unknown>
100008cf4:     	<unknown>
100008cf8:     	<unknown>
100008cfc:     	udf	#0x454
100008d00:     	<unknown>
100008d04:     	<unknown>
100008d08:     	<unknown>
100008d0c:     	adr	x16, 0x100093596 <dyld_private+0x8357e>
100008d10:     	<unknown>
100008d14:     	sub	w20, w10, #0x955, lsl #12 ; =0x955000
100008d18:     	<unknown>
100008d1c:     	<unknown>
100008d20:     	<unknown>
100008d24:     	sub	w17, w0, #0x455, lsl #12 ; =0x455000
100008d28:     	mov	z20.h, p5/m, #0xffaa    ; =65450
100008d2c:     	udf	#0x0
100008d30:     	udf	#0x1
		...
100008d3c:     	<unknown>
100008d40:     	<unknown>
100008d44:     	mov	wzr, #0x364a0000        ; =910819328
100008d48:     	<unknown>
100008d4c:     	ldr	w4, 0xfff8d564 <dyld_stub_binder+0xfff8d564>
100008d50:     	<unknown>
100008d54:     	<unknown>
100008d58:     	<unknown>
100008d5c:     	<unknown>
100008d60:     	cbnz	w14, 0x1000b564c <dyld_private+0xa5634>
100008d64:     	bfmls	z29.h, p1/m, z3.h, z0.h
100008d68:     	ldpsw	x2, x17, [x24], #-0xc4
100008d6c:     	<unknown>
100008d70:     	<unknown>
100008d74:     	<unknown>
100008d78:     	<unknown>
100008d7c:     	b	0xfbbdfa7c <dyld_stub_binder+0xfbbdfa7c>
100008d80:     	<unknown>
100008d84:     	ldr	xzr, [sp, #0x2348]
100008d88:     	<unknown>
100008d8c:     	<unknown>
100008d90:     	<unknown>
100008d94:     	<unknown>
100008d98:     	<unknown>
100008d9c:     	<unknown>
100008da0:     	<unknown>
100008da4:     	<unknown>
100008da8:     	<unknown>
100008dac:     	b	0x104fbf730 <dyld_private+0x4faf718>
100008db0:     	sub	x14, x30, x30, sxtx
100008db4:     	ldaxrb	w19, [x11]
100008db8:     	<unknown>
100008dbc:     	adr	x21, 0x1000e9134 <dyld_private+0xd911c>
100008dc0:     	<unknown>
100008dc4:     	b	0x104caa570 <dyld_private+0x4c9a558>
100008dc8:     	cbz	x13, 0x1000a4450 <dyld_private+0x94438>
100008dcc:     	<unknown>
100008dd0:     	stnp	d22, d13, [x20, #0x78]
100008dd4:     	ldp	q24, q25, [sp, #-0x230]!
100008dd8:     	<unknown>
100008ddc:     	<unknown>
100008de0:     	<unknown>
100008de4:     	<unknown>
100008de8:     	str	q17, [x20, #0xab60]
100008dec:     	<unknown>
100008df0:     	<unknown>
100008df4:     	ldrsw	x6, 0xfff8a214 <dyld_stub_binder+0xfff8a214>
100008df8:     	<unknown>
100008dfc:     	b	0xfe40c88c <dyld_stub_binder+0xfe40c88c>
100008e00:     	subs	w14, w8, #0x25f, lsl #12 ; =0x25f000
100008e04:     	<unknown>
100008e08:     	<unknown>
100008e0c:     	and	w5, w0, #0x7e0
100008e10:     	cbz	w5, 0x1000f15c0 <dyld_private+0xe15a8>
100008e14:     	adrp	x1, 0x186279000 <dyld_private+0x86268fe8>
100008e18:     	<unknown>
100008e1c:     	ldr	s7, 0x100074ca0 <dyld_private+0x64c88>
		...
100008e2c:     	adr	x0, 0x100008e2c <_main+0x19ac>
		...
100008e38:     	orr	w25, w5, #0xe00007ff
100008e3c:     	b	0x102b86118 <dyld_private+0x2b76100>
100008e40:     	<unknown>
100008e44:     	<unknown>
100008e48:     	bl	0x105f54e7c <dyld_private+0x5f44e64>
100008e4c:     	<unknown>
100008e50:     	st1.b	{ v6 }[10], [x3], x15
100008e54:     	ldp	d6, d11, [x9, #0x68]!
100008e58:     	<unknown>
100008e5c:     	add	w2, wsp, #0x16d, lsl #12 ; =0x16d000
100008e60:     	str	q10, [x22, #0x1650]
100008e64:     	subs	x18, x12, x29, lsl #47
100008e68:     	<unknown>
100008e6c:     	b	0xf94c4ddc <dyld_stub_binder+0xf94c4ddc>
100008e70:     	<unknown>
100008e74:     	cbz	x11, 0xfff8c574 <dyld_stub_binder+0xfff8c574>
100008e78:     	<unknown>
100008e7c:     	ldr	s5, 0xfffbdabc <dyld_stub_binder+0xfffbdabc>
100008e80:     	<unknown>
100008e84:     	<unknown>
100008e88:     	<unknown>
100008e8c:     	mov	w11, #-0x2ab40001       ; =-716439553
100008e90:     	<unknown>
100008e94:     	adrp	x3, 0x15db3000 <dyld_stub_binder+0x15db3000>
100008e98:     	<unknown>
100008e9c:     	ldr	w21, 0x10003bb3c <dyld_private+0x2bb24>
100008ea0:     	<unknown>
100008ea4:     	cbz	x10, 0xfffe510c <dyld_stub_binder+0xfffe510c>
100008ea8:     	<unknown>
100008eac:     	fnmsub	s6, s12, s5, s16
100008eb0:     	adr	x3, 0xfff8da93 <dyld_stub_binder+0xfff8da93>
100008eb4:     	b	0xf92709e0 <dyld_stub_binder+0xf92709e0>
100008eb8:     	ldr	q6, 0xfff19714 <dyld_stub_binder+0xfff19714>
100008ebc:     	b	0x100843bcc <dyld_private+0x833bb4>
100008ec0:     	tbz	w16, #0x1, 0x100009b74 <_main+0x26f4>
100008ec4:     	<unknown>
100008ec8:     	b	0x1032c50dc <dyld_private+0x32b50c4>
100008ecc:     	<unknown>
100008ed0:     	ldrsh	x11, [x8, #0xcc4]
100008ed4:     	<unknown>
100008ed8:     	<unknown>
100008edc:     	adr	x21, 0xfffa8c40 <dyld_stub_binder+0xfffa8c40>
100008ee0:     	<unknown>
100008ee4:     	<unknown>
100008ee8:     	<unknown>
100008eec:     	b	0x106eb4bfc <dyld_private+0x6ea4be4>
100008ef0:     	<unknown>
100008ef4:     	<unknown>
100008ef8:     	<unknown>
100008efc:     	uqsub.8b	v0, v8, v16
100008f00:     	uaddl.8h	v16, v1, v16
100008f04:     	udf	#0x30
100008f08:     	udf	#0x1
100008f0c:     	udf	#0x0
100008f10:     	udf	#0xa
100008f14:     	udf	#0x0
100008f18:     	udf	#0x4
100008f1c:     	udf	#0x0
100008f20:     	fnmls	z20.h, p4/m, z19.h, z21.h
100008f24:     	udf	#0x0
100008f28:     	udf	#0x5
100008f2c:     	udf	#0x0
100008f30:     	<unknown>
100008f34:     	udf	#0x65
100008f38:     	udf	#0x7
100008f3c:     	udf	#0x0
100008f40:     	fcmla.8h	v5, v19, v18[1], #270
100008f44:     	<unknown>
100008f48:     	udf	#0x69
100008f4c:     	udf	#0x0
100008f50:     	<unknown>
100008f54:     	<unknown>
100008f58:     	ldr	x15, 0x10009583c <dyld_private+0x85824>
100008f5c:     	ldrh	w14, [x1, #0x1428]
100008f60:     	<unknown>
100008f64:     	raddhn2.8h	v15, v17, v5
100008f68:     	<unknown>
100008f6c:     	umlsl.4s	v18, v27, v3[7]
100008f70:     	adr	x16, 0x1000d3dbb <dyld_private+0xc3da3>
100008f74:     	<unknown>
100008f78:     	<unknown>
100008f7c:     	fnmls	z5.h, p4/m, z19.h, z14.h
100008f80:     	<unknown>
100008f84:     	adds	w19, w3, #0xe9e
100008f88:     	orr	w18, w9, #0x7ffc0
100008f8c:     	ands	w22, w17, #0x7fff
100008f90:     	ldpsw	x21, x27, [x19, #-0x60]
100008f94:     	<unknown>
100008f98:     	<unknown>
100008f9c:     	usubl2.4s	v26, v1, v9
100008fa0:     	ldpsw	x22, x24, [x11, #-0xa0]
100008fa4:     	<unknown>
100008fa8:     	ldpsw	x13, x25, [x11, #-0x70]
100008fac:     	umlal2.4s	v3, v3, v3[2]
100008fb0:     	<unknown>
100008fb4:     	<unknown>
100008fb8:     	udf	#0xa
100008fbc:     	udf	#0x0
100008fc0:     	udf	#0x69
100008fc4:     	udf	#0x0
100008fc8:     	<unknown>
100008fcc:     	<unknown>
100008fd0:     	ldr	x15, 0x1000958b4 <dyld_private+0x8589c>
100008fd4:     	ldrh	w14, [x1, #0x1428]
100008fd8:     	<unknown>
100008fdc:     	raddhn2.8h	v15, v17, v5
100008fe0:     	<unknown>
100008fe4:     	umlsl.4s	v18, v27, v3[7]
100008fe8:     	adr	x16, 0x1000d3e33 <dyld_private+0xc3e1b>
100008fec:     	<unknown>
100008ff0:     	<unknown>
100008ff4:     	fnmls	z5.h, p4/m, z19.h, z14.h
100008ff8:     	<unknown>
100008ffc:     	adds	w19, w3, #0xe9e
100009000:     	orr	w18, w17, #0x7ffc0
100009004:     	ands	w19, w17, #0x7fff
100009008:     	ldpsw	x21, x27, [x19, #-0x60]
10000900c:     	<unknown>
100009010:     	<unknown>
100009014:     	usubl2.4s	v26, v1, v9
100009018:     	ldpsw	x22, x24, [x11, #-0xa0]
10000901c:     	<unknown>
100009020:     	ldpsw	x13, x25, [x11, #-0x70]
100009024:     	umlal2.4s	v3, v3, v3[2]
100009028:     	<unknown>
10000902c:     	<unknown>
100009030:     	udf	#0xa
100009034:     	udf	#0x0
100009038:     	udf	#0x69
10000903c:     	udf	#0x0
100009040:     	<unknown>
100009044:     	<unknown>
100009048:     	ldr	x15, 0x10009592c <dyld_private+0x85914>
10000904c:     	ldrh	w14, [x1, #0x1428]
100009050:     	<unknown>
100009054:     	raddhn2.8h	v15, v17, v5
100009058:     	<unknown>
10000905c:     	umlsl.4s	v18, v27, v3[7]
100009060:     	adr	x16, 0x1000d3eab <dyld_private+0xc3e93>
100009064:     	<unknown>
100009068:     	<unknown>
10000906c:     	fnmls	z5.h, p4/m, z19.h, z14.h
100009070:     	<unknown>
100009074:     	adds	w19, w3, #0xe9e
100009078:     	<unknown>
10000907c:     	ands	w16, w17, #0x7fff
100009080:     	ldpsw	x21, x27, [x19, #-0x60]
100009084:     	<unknown>
100009088:     	<unknown>
10000908c:     	usubl2.4s	v26, v1, v9
100009090:     	ldpsw	x22, x24, [x11, #-0xa0]
100009094:     	<unknown>
100009098:     	ldpsw	x13, x25, [x11, #-0x70]
10000909c:     	umlal2.4s	v3, v3, v3[2]
1000090a0:     	<unknown>
1000090a4:     	<unknown>
1000090a8:     	udf	#0xa
1000090ac:     	udf	#0x0
1000090b0:     	udf	#0x4e
1000090b4:     	udf	#0x0
1000090b8:     	<unknown>
1000090bc:     	<unknown>
1000090c0:     	ldr	x15, 0x1000959a4 <dyld_private+0x8598c>
1000090c4:     	ldrh	w14, [x1, #0x1428]
1000090c8:     	<unknown>
1000090cc:     	raddhn2.8h	v15, v17, v5
1000090d0:     	<unknown>
1000090d4:     	umlsl.4s	v18, v27, v3[7]
1000090d8:     	adr	x16, 0x1000d3f23 <dyld_private+0xc3f0b>
1000090dc:     	<unknown>
1000090e0:     	<unknown>
1000090e4:     	fnmls	z5.h, p4/m, z19.h, z14.h
1000090e8:     	<unknown>
1000090ec:     	adds	w19, w3, #0xe9e
1000090f0:     	orr	w20, w17, #0x7ffc0
1000090f4:     	ands	w25, w17, #0x7fff
1000090f8:     	ldpsw	x21, x27, [x19, #-0x60]
1000090fc:     	<unknown>
100009100:     	<unknown>
100009104:     	udf	#0x203a
100009108:     	udf	#0x5f
10000910c:     	udf	#0x0
100009110:     	<unknown>
100009114:     	<unknown>
100009118:     	ldr	x15, 0x1000959fc <dyld_private+0x859e4>
10000911c:     	ldrh	w14, [x1, #0x1428]
100009120:     	<unknown>
100009124:     	raddhn2.8h	v15, v17, v5
100009128:     	<unknown>
10000912c:     	umlsl.4s	v18, v27, v3[7]
100009130:     	adr	x16, 0x1000d3f7b <dyld_private+0xc3f63>
100009134:     	<unknown>
100009138:     	<unknown>
10000913c:     	fnmls	z5.h, p4/m, z19.h, z14.h
100009140:     	<unknown>
100009144:     	adds	w19, w3, #0xe9e
100009148:     	adds	w20, w1, #0xe8d
10000914c:     	ands	w19, w17, #0x7fff
100009150:     	ldpsw	x21, x27, [x19, #-0x60]
100009154:     	<unknown>
100009158:     	<unknown>
10000915c:     	umlal2.4s	v26, v1, v3[2]
100009160:     	<unknown>
100009164:     	<unknown>
100009168:     	<unknown>
10000916c:     	<unknown>
100009170:     	udf	#0x1c
100009174:     	udf	#0x0
100009178:     	<unknown>
10000917c:     	<unknown>
100009180:     	<unknown>
100009184:     	<unknown>
100009188:     	umlal2.4s	v19, v3, v6[2]
10000918c:     	umlal2.4s	v18, v3, v3[2]
100009190:     	<unknown>
100009194:     	udf	#0x0
100009198:     	udf	#0x7
10000919c:     	udf	#0x0
1000091a0:     	<unknown>
1000091a4:     	<unknown>
1000091a8:     	udf	#0xc
1000091ac:     	udf	#0x0
1000091b0:     	<unknown>
1000091b4:     	ldp	s5, s24, [x27, #-0xa8]
1000091b8:     	ldnp	d6, d29, [x11, #-0x140]
1000091bc:     	udf	#0x0
1000091c0:     	udf	#0x9e
1000091c4:     	udf	#0x0
1000091c8:     	fnmla	z15.h, p5/m, z9.h, z19.h
1000091cc:     	uabdl2.8h	v18, v27, v15
1000091d0:     	<unknown>
1000091d4:     	adr	x20, 0x100067e02 <dyld_private+0x57dea>
1000091d8:     	fnmls	z18.h, p3/m, z27.h, z10.h
1000091dc:     	<unknown>
1000091e0:     	fnmls	z19.h, p2/m, z10.h, z12.h
1000091e4:     	fcmla.8h	v24, v3, v18[1], #180
1000091e8:     	<unknown>
1000091ec:     	adr	x15, 0x1000ef7b3 <dyld_private+0xdf79b>
1000091f0:     	umlsl.4s	v5, v27, v3[3]
1000091f4:     	fnmls	z19.h, p2/m, z10.h, z12.h
1000091f8:     	adr	x24, 0x1000a77a7 <dyld_private+0x9778f>
1000091fc:     	ldpsw	x20, x26, [x11, #-0x98]
100009200:     	ldpsw	x26, x24, [x11, #-0x60]
100009204:     	adr	x15, 0x100063fd2 <dyld_private+0x53fba>
100009208:     	<unknown>
10000920c:     	<unknown>
100009210:     	fnmls	z13.h, p4/m, z3.h, z12.h
100009214:     	<unknown>
100009218:     	<unknown>
10000921c:     	fnmls	z11.h, p5/m, z3.h, z18.h
100009220:     	<unknown>
100009224:     	<unknown>
100009228:     	<unknown>
10000922c:     	<unknown>
100009230:     	ldnp	d15, d25, [x3, #-0xb0]
100009234:     	ld3.b	{ v5, v6, v7 }[11], [x27]
100009238:     	ldnp	d15, d25, [x3, #-0xb0]
10000923c:     	<unknown>
100009240:     	adds	w26, w9, #0xe8c
100009244:     	<unknown>
100009248:     	ldp	d14, d29, [x3, #-0x170]
10000924c:     	<unknown>
100009250:     	<unknown>
100009254:     	ldnp	d0, d24, [x25, #-0x110]
100009258:     	<unknown>
10000925c:     	<unknown>
100009260:     	fnmls	z9.h, p3/m, z19.h, z4.h
100009264:     	udf	#0x2078
100009268:     	udf	#0x5f
10000926c:     	udf	#0x0
100009270:     	<unknown>
100009274:     	<unknown>
100009278:     	ldr	x15, 0x100095b5c <dyld_private+0x85b44>
10000927c:     	ldrh	w14, [x1, #0x1428]
100009280:     	<unknown>
100009284:     	raddhn2.8h	v15, v17, v5
100009288:     	<unknown>
10000928c:     	umlsl.4s	v18, v27, v3[7]
100009290:     	adr	x16, 0x1000d40db <dyld_private+0xc40c3>
100009294:     	<unknown>
100009298:     	<unknown>
10000929c:     	fnmls	z5.h, p4/m, z19.h, z14.h
1000092a0:     	<unknown>
1000092a4:     	adds	w19, w3, #0xe9e
1000092a8:     	<unknown>
1000092ac:     	ands	w20, w17, #0x7fff
1000092b0:     	ldpsw	x21, x27, [x19, #-0x60]
1000092b4:     	<unknown>
1000092b8:     	<unknown>
1000092bc:     	umlal2.4s	v26, v1, v3[2]
1000092c0:     	<unknown>
1000092c4:     	<unknown>
1000092c8:     	<unknown>
1000092cc:     	<unknown>
1000092d0:     	udf	#0x5f
1000092d4:     	udf	#0x0
1000092d8:     	<unknown>
1000092dc:     	<unknown>
1000092e0:     	ldr	x15, 0x100095bc4 <dyld_private+0x85bac>
1000092e4:     	ldrh	w14, [x1, #0x1428]
1000092e8:     	<unknown>
1000092ec:     	raddhn2.8h	v15, v17, v5
1000092f0:     	<unknown>
1000092f4:     	umlsl.4s	v18, v27, v3[7]
1000092f8:     	adr	x16, 0x1000d4143 <dyld_private+0xc412b>
1000092fc:     	<unknown>
100009300:     	<unknown>
100009304:     	fnmls	z5.h, p4/m, z19.h, z14.h
100009308:     	<unknown>
10000930c:     	adds	w19, w3, #0xe9e
100009310:     	<unknown>
100009314:     	ands	w17, w17, #0x7fff
100009318:     	ldpsw	x21, x27, [x19, #-0x60]
10000931c:     	<unknown>
100009320:     	<unknown>
100009324:     	umlal2.4s	v26, v1, v3[2]
100009328:     	<unknown>
10000932c:     	<unknown>
100009330:     	<unknown>
100009334:     	<unknown>
100009338:     	udf	#0x5f
10000933c:     	udf	#0x0
100009340:     	<unknown>
100009344:     	<unknown>
100009348:     	ldr	x15, 0x100095c2c <dyld_private+0x85c14>
10000934c:     	ldrh	w14, [x1, #0x1428]
100009350:     	<unknown>
100009354:     	raddhn2.8h	v15, v17, v5
100009358:     	<unknown>
10000935c:     	umlsl.4s	v18, v27, v3[7]
100009360:     	adr	x16, 0x1000d41ab <dyld_private+0xc4193>
100009364:     	<unknown>
100009368:     	<unknown>
10000936c:     	fnmls	z5.h, p4/m, z19.h, z14.h
100009370:     	<unknown>
100009374:     	adds	w19, w3, #0xe9e
100009378:     	orr	w23, w25, #0x7ffc0
10000937c:     	ands	w20, w17, #0x7fff
100009380:     	ldpsw	x21, x27, [x19, #-0x60]
100009384:     	<unknown>
100009388:     	<unknown>
10000938c:     	umlal2.4s	v26, v1, v3[2]
100009390:     	<unknown>
100009394:     	<unknown>
100009398:     	<unknown>
10000939c:     	<unknown>
1000093a0:     	udf	#0x5f
1000093a4:     	udf	#0x0
1000093a8:     	<unknown>
1000093ac:     	<unknown>
1000093b0:     	ldr	x15, 0x100095c94 <dyld_private+0x85c7c>
1000093b4:     	ldrh	w14, [x1, #0x1428]
1000093b8:     	<unknown>
1000093bc:     	raddhn2.8h	v15, v17, v5
1000093c0:     	<unknown>
1000093c4:     	umlsl.4s	v18, v27, v3[7]
1000093c8:     	adr	x16, 0x1000d4213 <dyld_private+0xc41fb>
1000093cc:     	<unknown>
1000093d0:     	<unknown>
1000093d4:     	fnmls	z5.h, p4/m, z19.h, z14.h
1000093d8:     	<unknown>
1000093dc:     	adds	w19, w3, #0xe9e
1000093e0:     	cbz	w23, 0x10007da44 <dyld_private+0x6da2c>
1000093e4:     	ands	w24, w17, #0x7fff
1000093e8:     	ldpsw	x21, x27, [x19, #-0x60]
1000093ec:     	<unknown>
1000093f0:     	<unknown>
1000093f4:     	umlal2.4s	v26, v1, v3[2]
1000093f8:     	<unknown>
1000093fc:     	<unknown>
100009400:     	<unknown>
100009404:     	<unknown>
100009408:     	udf	#0x5f
10000940c:     	udf	#0x0
100009410:     	<unknown>
100009414:     	<unknown>
100009418:     	ldr	x15, 0x100095cfc <dyld_private+0x85ce4>
10000941c:     	ldrh	w14, [x1, #0x1428]
100009420:     	<unknown>
100009424:     	raddhn2.8h	v15, v17, v5
100009428:     	<unknown>
10000942c:     	umlsl.4s	v18, v27, v3[7]
100009430:     	adr	x16, 0x1000d427b <dyld_private+0xc4263>
100009434:     	<unknown>
100009438:     	<unknown>
10000943c:     	fnmls	z5.h, p4/m, z19.h, z14.h
100009440:     	<unknown>
100009444:     	adds	w19, w3, #0xe9e
100009448:     	cbz	w23, 0x10007db4c <dyld_private+0x6db34>
10000944c:     	ands	w17, w17, #0x7fff
100009450:     	ldpsw	x21, x27, [x19, #-0x60]
100009454:     	<unknown>
100009458:     	<unknown>
10000945c:     	umlal2.4s	v26, v1, v3[2]
100009460:     	<unknown>
100009464:     	<unknown>
100009468:     	<unknown>
10000946c:     	<unknown>
100009470:     	udf	#0x6
100009474:     	udf	#0x0
100009478:     	bc.lo	0x10008bf00 <dyld_private+0x7bee8>
10000947c:     	udf	#0x2045
100009480:     	udf	#0x1
100009484:     	udf	#0x0
100009488:     	udf	#0x20
10000948c:     	udf	#0x0
100009490:     	udf	#0x69
100009494:     	udf	#0x0
100009498:     	<unknown>
10000949c:     	<unknown>
1000094a0:     	ldr	x15, 0x100095d84 <dyld_private+0x85d6c>
1000094a4:     	ldrh	w14, [x1, #0x1428]
1000094a8:     	<unknown>
1000094ac:     	raddhn2.8h	v15, v17, v5
1000094b0:     	<unknown>
1000094b4:     	umlsl.4s	v18, v27, v3[7]
1000094b8:     	adr	x16, 0x1000d4303 <dyld_private+0xc42eb>
1000094bc:     	<unknown>
1000094c0:     	<unknown>
1000094c4:     	fnmls	z5.h, p4/m, z19.h, z14.h
1000094c8:     	<unknown>
1000094cc:     	orr	w19, w3, #0xffffffdf
1000094d0:     	cbz	w19, 0x10007db34 <dyld_private+0x6db1c>
1000094d4:     	ands	w17, w17, #0x7fff
1000094d8:     	ldpsw	x21, x27, [x19, #-0x60]
1000094dc:     	<unknown>
1000094e0:     	<unknown>
1000094e4:     	usubl2.4s	v26, v1, v9
1000094e8:     	ldpsw	x22, x24, [x11, #-0xa0]
1000094ec:     	<unknown>
1000094f0:     	ldpsw	x13, x25, [x11, #-0x70]
1000094f4:     	umlal2.4s	v3, v3, v3[2]
1000094f8:     	<unknown>
1000094fc:     	<unknown>
100009500:     	udf	#0xa
100009504:     	udf	#0x0
100009508:     	udf	#0x20
10000950c:     	udf	#0x0
100009510:     	<unknown>
100009514:     	adr	x5, 0x100049e9f <dyld_private+0x39e87>
100009518:     	<unknown>
10000951c:     	ldpsw	x18, x24, [x11, #-0x60]
100009520:     	<unknown>
100009524:     	<unknown>
100009528:     	fcmla.8h	v0, v25, v12[1], #270
10000952c:     	<unknown>
		...
100009538:     	udf	#0x11
10000953c:     	udf	#0x0
100009540:     	<unknown>
100009544:     	uabdl.4s	v5, v27, v19
100009548:     	<unknown>
10000954c:     	<unknown>
100009550:     	udf	#0x73
100009554:     	udf	#0x0
100009558:     	udf	#0x1c
10000955c:     	udf	#0x0
100009560:     	<unknown>
100009564:     	<unknown>
100009568:     	ldp	d18, d25, [x27, #-0xb0]
10000956c:     	<unknown>
100009570:     	<unknown>
100009574:     	<unknown>
100009578:     	<unknown>
10000957c:     	udf	#0x0
100009580:     	udf	#0xb9
100009584:     	udf	#0x0
100009588:     	fnmla	z15.h, p5/m, z9.h, z19.h
10000958c:     	uabdl2.8h	v18, v27, v15
100009590:     	<unknown>
100009594:     	adr	x20, 0x1000681c2 <dyld_private+0x581aa>
100009598:     	fnmls	z18.h, p3/m, z27.h, z10.h
10000959c:     	<unknown>
1000095a0:     	fnmls	z19.h, p2/m, z10.h, z12.h
1000095a4:     	fcmla.8h	v24, v3, v18[1], #180
1000095a8:     	<unknown>
1000095ac:     	adr	x15, 0x1000efb73 <dyld_private+0xdfb5b>
1000095b0:     	umlsl.4s	v5, v27, v3[3]
1000095b4:     	fnmls	z19.h, p2/m, z10.h, z12.h
1000095b8:     	adr	x24, 0x1000a7b67 <dyld_private+0x97b4f>
1000095bc:     	ldpsw	x20, x26, [x11, #-0x98]
1000095c0:     	ldpsw	x26, x24, [x11, #-0x60]
1000095c4:     	adr	x15, 0x100064392 <dyld_private+0x5437a>
1000095c8:     	<unknown>
1000095cc:     	<unknown>
1000095d0:     	fnmls	z13.h, p4/m, z3.h, z12.h
1000095d4:     	<unknown>
1000095d8:     	<unknown>
1000095dc:     	fnmls	z11.h, p5/m, z3.h, z18.h
1000095e0:     	<unknown>
1000095e4:     	<unknown>
1000095e8:     	<unknown>
1000095ec:     	adr	x20, 0x100067e76 <dyld_private+0x57e5e>
1000095f0:     	<unknown>
1000095f4:     	fcmla.4h	v15, v19, v13[1], #270
1000095f8:     	smlsl2.4s	v13, v10, v3[2]
1000095fc:     	<unknown>
100009600:     	fnmls	z4.h, p5/m, z11.h, z12.h
100009604:     	fcmla.8h	v15, v1, v18[1], #180
100009608:     	<unknown>
10000960c:     	<unknown>
100009610:     	adds	w18, w1, #0xe8c
100009614:     	ands	w25, w17, #0x7fff
100009618:     	ldpsw	x21, x27, [x19, #-0x60]
10000961c:     	<unknown>
100009620:     	<unknown>
100009624:     	usubl2.4s	v26, v1, v9
100009628:     	ldpsw	x22, x24, [x11, #-0xa0]
10000962c:     	<unknown>
100009630:     	ldpsw	x13, x25, [x11, #-0x70]
100009634:     	umlal2.4s	v3, v3, v3[2]
100009638:     	<unknown>
10000963c:     	<unknown>
100009640:     	udf	#0xa
100009644:     	udf	#0x0
100009648:     	udf	#0xb9
10000964c:     	udf	#0x0
100009650:     	fnmla	z15.h, p5/m, z9.h, z19.h
100009654:     	uabdl2.8h	v18, v27, v15
100009658:     	<unknown>
10000965c:     	adr	x20, 0x10006828a <dyld_private+0x58272>
100009660:     	fnmls	z18.h, p3/m, z27.h, z10.h
100009664:     	<unknown>
100009668:     	fnmls	z19.h, p2/m, z10.h, z12.h
10000966c:     	fcmla.8h	v24, v3, v18[1], #180
100009670:     	<unknown>
100009674:     	adr	x15, 0x1000efc3b <dyld_private+0xdfc23>
100009678:     	umlsl.4s	v5, v27, v3[3]
10000967c:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009680:     	adr	x24, 0x1000a7c2f <dyld_private+0x97c17>
100009684:     	ldpsw	x20, x26, [x11, #-0x98]
100009688:     	ldpsw	x26, x24, [x11, #-0x60]
10000968c:     	adr	x15, 0x10006445a <dyld_private+0x54442>
100009690:     	<unknown>
100009694:     	<unknown>
100009698:     	fnmls	z13.h, p4/m, z3.h, z12.h
10000969c:     	<unknown>
1000096a0:     	<unknown>
1000096a4:     	fnmls	z11.h, p5/m, z3.h, z18.h
1000096a8:     	<unknown>
1000096ac:     	<unknown>
1000096b0:     	<unknown>
1000096b4:     	adr	x20, 0x100067f3e <dyld_private+0x57f26>
1000096b8:     	<unknown>
1000096bc:     	fcmla.4h	v15, v19, v13[1], #270
1000096c0:     	smlsl2.4s	v13, v10, v3[2]
1000096c4:     	<unknown>
1000096c8:     	fnmls	z4.h, p5/m, z11.h, z12.h
1000096cc:     	fcmla.8h	v15, v1, v18[1], #180
1000096d0:     	<unknown>
1000096d4:     	<unknown>
1000096d8:     	cbnz	w18, 0x10007dcfc <dyld_private+0x6dce4>
1000096dc:     	ands	w21, w17, #0x7fff
1000096e0:     	ldpsw	x21, x27, [x19, #-0x60]
1000096e4:     	<unknown>
1000096e8:     	<unknown>
1000096ec:     	usubl2.4s	v26, v1, v9
1000096f0:     	ldpsw	x22, x24, [x11, #-0xa0]
1000096f4:     	<unknown>
1000096f8:     	ldpsw	x13, x25, [x11, #-0x70]
1000096fc:     	umlal2.4s	v3, v3, v3[2]
100009700:     	<unknown>
100009704:     	<unknown>
100009708:     	udf	#0xa
10000970c:     	udf	#0x0
100009710:     	udf	#0xaf
100009714:     	udf	#0x0
100009718:     	fnmla	z15.h, p5/m, z9.h, z19.h
10000971c:     	uabdl2.8h	v18, v27, v15
100009720:     	<unknown>
100009724:     	adr	x20, 0x100068352 <dyld_private+0x5833a>
100009728:     	fnmls	z18.h, p3/m, z27.h, z10.h
10000972c:     	<unknown>
100009730:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009734:     	fcmla.8h	v24, v3, v18[1], #180
100009738:     	<unknown>
10000973c:     	adr	x15, 0x1000efd03 <dyld_private+0xdfceb>
100009740:     	umlsl.4s	v5, v27, v3[3]
100009744:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009748:     	adr	x24, 0x1000a7cf7 <dyld_private+0x97cdf>
10000974c:     	ldpsw	x20, x26, [x11, #-0x98]
100009750:     	ldpsw	x26, x24, [x11, #-0x60]
100009754:     	adr	x15, 0x100064522 <dyld_private+0x5450a>
100009758:     	<unknown>
10000975c:     	<unknown>
100009760:     	fnmls	z13.h, p4/m, z3.h, z12.h
100009764:     	<unknown>
100009768:     	<unknown>
10000976c:     	fnmls	z11.h, p5/m, z3.h, z18.h
100009770:     	<unknown>
100009774:     	<unknown>
100009778:     	<unknown>
10000977c:     	adr	x20, 0x100068006 <dyld_private+0x57fee>
100009780:     	<unknown>
100009784:     	fcmla.4h	v15, v19, v13[1], #270
100009788:     	smlsl2.4s	v13, v10, v3[2]
10000978c:     	<unknown>
100009790:     	fnmls	z4.h, p5/m, z11.h, z12.h
100009794:     	fcmla.8h	v15, v1, v18[1], #180
100009798:     	<unknown>
10000979c:     	<unknown>
1000097a0:     	adds	w18, w25, #0xe8c
1000097a4:     	ands	w22, w17, #0x7fff
1000097a8:     	ldpsw	x21, x27, [x19, #-0x60]
1000097ac:     	<unknown>
1000097b0:     	<unknown>
1000097b4:     	umlal2.4s	v26, v1, v3[2]
1000097b8:     	<unknown>
1000097bc:     	<unknown>
1000097c0:     	<unknown>
1000097c4:     	<unknown>
1000097c8:     	udf	#0x26
1000097cc:     	udf	#0x0
1000097d0:     	<unknown>
1000097d4:     	adr	x5, 0x10004a583 <dyld_private+0x3a56b>
1000097d8:     	fnmls	z18.h, p3/m, z27.h, z3.h
1000097dc:     	<unknown>
1000097e0:     	<unknown>
1000097e4:     	fnmls	z5.h, p6/m, z3.h, z3.h
1000097e8:     	<unknown>
1000097ec:     	tbz	w20, #0x7, 0x10000bdf0 <dyld_stub_binder+0x10000bdf0>
1000097f0:     	<unknown>
1000097f4:     	udf	#0x7365
1000097f8:     	udf	#0x9d
1000097fc:     	udf	#0x0
100009800:     	fnmla	z15.h, p5/m, z9.h, z19.h
100009804:     	uabdl2.8h	v18, v27, v15
100009808:     	<unknown>
10000980c:     	adr	x20, 0x10006843a <dyld_private+0x58422>
100009810:     	fnmls	z18.h, p3/m, z27.h, z10.h
100009814:     	<unknown>
100009818:     	fnmls	z19.h, p2/m, z10.h, z12.h
10000981c:     	fcmla.8h	v24, v3, v18[1], #180
100009820:     	<unknown>
100009824:     	adr	x15, 0x1000efdeb <dyld_private+0xdfdd3>
100009828:     	umlsl.4s	v5, v27, v3[3]
10000982c:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009830:     	adr	x24, 0x1000a7ddf <dyld_private+0x97dc7>
100009834:     	ldpsw	x20, x26, [x11, #-0x98]
100009838:     	ldpsw	x26, x24, [x11, #-0x60]
10000983c:     	adr	x15, 0x10006460a <dyld_private+0x545f2>
100009840:     	<unknown>
100009844:     	<unknown>
100009848:     	fnmls	z13.h, p4/m, z3.h, z12.h
10000984c:     	<unknown>
100009850:     	<unknown>
100009854:     	fnmls	z11.h, p5/m, z3.h, z18.h
100009858:     	<unknown>
10000985c:     	<unknown>
100009860:     	<unknown>
100009864:     	adr	x20, 0x1000680ee <dyld_private+0x580d6>
100009868:     	<unknown>
10000986c:     	fcmla.4h	v15, v19, v13[1], #270
100009870:     	smlsl2.4s	v13, v10, v3[2]
100009874:     	<unknown>
100009878:     	fnmls	z4.h, p5/m, z11.h, z12.h
10000987c:     	fcmla.8h	v15, v1, v18[1], #180
100009880:     	<unknown>
100009884:     	<unknown>
100009888:     	cbnz	w22, 0x10007decc <dyld_private+0x6deb4>
10000988c:     	<unknown>
100009890:     	ldp	d14, d29, [x3, #-0x170]
100009894:     	<unknown>
100009898:     	<unknown>
10000989c:     	udf	#0x20
1000098a0:     	udf	#0x2a
1000098a4:     	udf	#0x0
1000098a8:     	<unknown>
1000098ac:     	adr	x5, 0x10004a65b <dyld_private+0x3a643>
1000098b0:     	fnmls	z18.h, p3/m, z27.h, z3.h
1000098b4:     	<unknown>
1000098b8:     	<unknown>
1000098bc:     	<unknown>
1000098c0:     	<unknown>
1000098c4:     	<unknown>
1000098c8:     	<unknown>
1000098cc:     	<unknown>
1000098d0:     	udf	#0x382d
1000098d4:     	udf	#0x0
1000098d8:     	udf	#0x9e
1000098dc:     	udf	#0x0
1000098e0:     	fnmla	z15.h, p5/m, z9.h, z19.h
1000098e4:     	uabdl2.8h	v18, v27, v15
1000098e8:     	<unknown>
1000098ec:     	adr	x20, 0x10006851a <dyld_private+0x58502>
1000098f0:     	fnmls	z18.h, p3/m, z27.h, z10.h
1000098f4:     	<unknown>
1000098f8:     	fnmls	z19.h, p2/m, z10.h, z12.h
1000098fc:     	fcmla.8h	v24, v3, v18[1], #180
100009900:     	<unknown>
100009904:     	adr	x15, 0x1000efecb <dyld_private+0xdfeb3>
100009908:     	umlsl.4s	v5, v27, v3[3]
10000990c:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009910:     	adr	x24, 0x1000a7ebf <dyld_private+0x97ea7>
100009914:     	ldpsw	x20, x26, [x11, #-0x98]
100009918:     	ldpsw	x26, x24, [x11, #-0x60]
10000991c:     	adr	x15, 0x1000646ea <dyld_private+0x546d2>
100009920:     	<unknown>
100009924:     	<unknown>
100009928:     	fnmls	z13.h, p4/m, z3.h, z12.h
10000992c:     	<unknown>
100009930:     	<unknown>
100009934:     	fnmls	z11.h, p5/m, z3.h, z18.h
100009938:     	<unknown>
10000993c:     	<unknown>
100009940:     	<unknown>
100009944:     	adr	x20, 0x1000681ce <dyld_private+0x581b6>
100009948:     	<unknown>
10000994c:     	fcmla.4h	v15, v19, v13[1], #270
100009950:     	smlsl2.4s	v13, v10, v3[2]
100009954:     	<unknown>
100009958:     	fnmls	z4.h, p5/m, z11.h, z12.h
10000995c:     	fcmla.8h	v15, v1, v18[1], #180
100009960:     	<unknown>
100009964:     	<unknown>
100009968:     	<unknown>
10000996c:     	ands	w23, w17, #0x7fff
100009970:     	ldpsw	x21, x27, [x19, #-0x60]
100009974:     	<unknown>
100009978:     	<unknown>
10000997c:     	udf	#0x203a
100009980:     	udf	#0xaf
100009984:     	udf	#0x0
100009988:     	fnmla	z15.h, p5/m, z9.h, z19.h
10000998c:     	uabdl2.8h	v18, v27, v15
100009990:     	<unknown>
100009994:     	adr	x20, 0x1000685c2 <dyld_private+0x585aa>
100009998:     	fnmls	z18.h, p3/m, z27.h, z10.h
10000999c:     	<unknown>
1000099a0:     	fnmls	z19.h, p2/m, z10.h, z12.h
1000099a4:     	fcmla.8h	v24, v3, v18[1], #180
1000099a8:     	<unknown>
1000099ac:     	adr	x15, 0x1000eff73 <dyld_private+0xdff5b>
1000099b0:     	umlsl.4s	v5, v27, v3[3]
1000099b4:     	fnmls	z19.h, p2/m, z10.h, z12.h
1000099b8:     	adr	x24, 0x1000a7f67 <dyld_private+0x97f4f>
1000099bc:     	ldpsw	x20, x26, [x11, #-0x98]
1000099c0:     	ldpsw	x26, x24, [x11, #-0x60]
1000099c4:     	adr	x15, 0x100064792 <dyld_private+0x5477a>
1000099c8:     	<unknown>
1000099cc:     	<unknown>
1000099d0:     	fnmls	z13.h, p4/m, z3.h, z12.h
1000099d4:     	<unknown>
1000099d8:     	<unknown>
1000099dc:     	fnmls	z11.h, p5/m, z3.h, z18.h
1000099e0:     	<unknown>
1000099e4:     	<unknown>
1000099e8:     	<unknown>
1000099ec:     	adr	x20, 0x100068276 <dyld_private+0x5825e>
1000099f0:     	<unknown>
1000099f4:     	fcmla.4h	v15, v19, v13[1], #270
1000099f8:     	smlsl2.4s	v13, v10, v3[2]
1000099fc:     	<unknown>
100009a00:     	fnmls	z4.h, p5/m, z11.h, z12.h
100009a04:     	fcmla.8h	v15, v1, v18[1], #180
100009a08:     	<unknown>
100009a0c:     	<unknown>
100009a10:     	adds	w21, w9, #0xe8e
100009a14:     	ands	w21, w17, #0x7fff
100009a18:     	ldpsw	x21, x27, [x19, #-0x60]
100009a1c:     	<unknown>
100009a20:     	<unknown>
100009a24:     	umlal2.4s	v26, v1, v3[2]
100009a28:     	<unknown>
100009a2c:     	<unknown>
100009a30:     	<unknown>
100009a34:     	<unknown>
100009a38:     	udf	#0xa2
100009a3c:     	udf	#0x0
100009a40:     	fnmla	z15.h, p5/m, z9.h, z19.h
100009a44:     	uabdl2.8h	v18, v27, v15
100009a48:     	<unknown>
100009a4c:     	adr	x20, 0x10006867a <dyld_private+0x58662>
100009a50:     	fnmls	z18.h, p3/m, z27.h, z10.h
100009a54:     	<unknown>
100009a58:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009a5c:     	fcmla.8h	v24, v3, v18[1], #180
100009a60:     	<unknown>
100009a64:     	adr	x15, 0x1000f002b <dyld_private+0xe0013>
100009a68:     	umlsl.4s	v5, v27, v3[3]
100009a6c:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009a70:     	adr	x24, 0x1000a801f <dyld_private+0x98007>
100009a74:     	ldpsw	x20, x26, [x11, #-0x98]
100009a78:     	ldpsw	x26, x24, [x11, #-0x60]
100009a7c:     	adr	x15, 0x10006484a <dyld_private+0x54832>
100009a80:     	<unknown>
100009a84:     	<unknown>
100009a88:     	fnmls	z13.h, p4/m, z3.h, z12.h
100009a8c:     	<unknown>
100009a90:     	<unknown>
100009a94:     	fnmls	z11.h, p5/m, z3.h, z18.h
100009a98:     	<unknown>
100009a9c:     	<unknown>
100009aa0:     	<unknown>
100009aa4:     	<unknown>
100009aa8:     	ldnp	d15, d25, [x3, #-0xb0]
100009aac:     	<unknown>
100009ab0:     	<unknown>
100009ab4:     	ushl.8b	v20, v18, v24
100009ab8:     	cbz	w19, 0x10007e9c4 <dyld_private+0x6e9ac>
100009abc:     	<unknown>
100009ac0:     	<unknown>
100009ac4:     	ldp	d14, d29, [x3, #-0x170]
100009ac8:     	<unknown>
100009acc:     	<unknown>
100009ad0:     	ldnp	d0, d24, [x25, #-0x110]
100009ad4:     	<unknown>
100009ad8:     	<unknown>
100009adc:     	fnmls	z9.h, p3/m, z19.h, z4.h
100009ae0:     	udf	#0x2078
100009ae4:     	udf	#0x0
100009ae8:     	udf	#0xa2
100009aec:     	udf	#0x0
100009af0:     	fnmla	z15.h, p5/m, z9.h, z19.h
100009af4:     	uabdl2.8h	v18, v27, v15
100009af8:     	<unknown>
100009afc:     	adr	x20, 0x10006872a <dyld_private+0x58712>
100009b00:     	fnmls	z18.h, p3/m, z27.h, z10.h
100009b04:     	<unknown>
100009b08:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009b0c:     	fcmla.8h	v24, v3, v18[1], #180
100009b10:     	<unknown>
100009b14:     	adr	x15, 0x1000f00db <dyld_private+0xe00c3>
100009b18:     	umlsl.4s	v5, v27, v3[3]
100009b1c:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009b20:     	adr	x24, 0x1000a80cf <dyld_private+0x980b7>
100009b24:     	ldpsw	x20, x26, [x11, #-0x98]
100009b28:     	ldpsw	x26, x24, [x11, #-0x60]
100009b2c:     	adr	x15, 0x1000648fa <dyld_private+0x548e2>
100009b30:     	<unknown>
100009b34:     	<unknown>
100009b38:     	fnmls	z13.h, p4/m, z3.h, z12.h
100009b3c:     	<unknown>
100009b40:     	<unknown>
100009b44:     	fnmls	z11.h, p5/m, z3.h, z18.h
100009b48:     	<unknown>
100009b4c:     	<unknown>
100009b50:     	<unknown>
100009b54:     	<unknown>
100009b58:     	ldnp	d15, d25, [x3, #-0xb0]
100009b5c:     	<unknown>
100009b60:     	<unknown>
100009b64:     	ushl.8b	v20, v18, v24
100009b68:     	tbz	w19, #0x7, 0x10000ea74 <dyld_stub_binder+0x10000ea74>
100009b6c:     	cbz	w23, 0x1000722b0 <dyld_private+0x62298>
100009b70:     	<unknown>
100009b74:     	ldp	d14, d29, [x3, #-0x170]
100009b78:     	<unknown>
100009b7c:     	<unknown>
100009b80:     	ldnp	d0, d24, [x25, #-0x110]
100009b84:     	<unknown>
100009b88:     	<unknown>
100009b8c:     	fnmls	z9.h, p3/m, z19.h, z4.h
100009b90:     	udf	#0x2078
100009b94:     	udf	#0x0
100009b98:     	udf	#0xa2
100009b9c:     	udf	#0x0
100009ba0:     	fnmla	z15.h, p5/m, z9.h, z19.h
100009ba4:     	uabdl2.8h	v18, v27, v15
100009ba8:     	<unknown>
100009bac:     	adr	x20, 0x1000687da <dyld_private+0x587c2>
100009bb0:     	fnmls	z18.h, p3/m, z27.h, z10.h
100009bb4:     	<unknown>
100009bb8:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009bbc:     	fcmla.8h	v24, v3, v18[1], #180
100009bc0:     	<unknown>
100009bc4:     	adr	x15, 0x1000f018b <dyld_private+0xe0173>
100009bc8:     	umlsl.4s	v5, v27, v3[3]
100009bcc:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009bd0:     	adr	x24, 0x1000a817f <dyld_private+0x98167>
100009bd4:     	ldpsw	x20, x26, [x11, #-0x98]
100009bd8:     	ldpsw	x26, x24, [x11, #-0x60]
100009bdc:     	adr	x15, 0x1000649aa <dyld_private+0x54992>
100009be0:     	<unknown>
100009be4:     	<unknown>
100009be8:     	fnmls	z13.h, p4/m, z3.h, z12.h
100009bec:     	<unknown>
100009bf0:     	<unknown>
100009bf4:     	fnmls	z11.h, p5/m, z3.h, z18.h
100009bf8:     	<unknown>
100009bfc:     	<unknown>
100009c00:     	<unknown>
100009c04:     	<unknown>
100009c08:     	ldnp	d15, d25, [x3, #-0xb0]
100009c0c:     	<unknown>
100009c10:     	<unknown>
100009c14:     	ushl.8b	v20, v18, v24
100009c18:     	tbnz	w19, #0x7, 0x10000eb24 <dyld_stub_binder+0x10000eb24>
100009c1c:     	cbz	w22, 0x100070360 <dyld_private+0x60348>
100009c20:     	<unknown>
100009c24:     	ldp	d14, d29, [x3, #-0x170]
100009c28:     	<unknown>
100009c2c:     	<unknown>
100009c30:     	ldnp	d0, d24, [x25, #-0x110]
100009c34:     	<unknown>
100009c38:     	<unknown>
100009c3c:     	fnmls	z9.h, p3/m, z19.h, z4.h
100009c40:     	udf	#0x2078
100009c44:     	udf	#0x0
100009c48:     	udf	#0xb6
100009c4c:     	udf	#0x0
100009c50:     	fnmla	z15.h, p5/m, z9.h, z19.h
100009c54:     	uabdl2.8h	v18, v27, v15
100009c58:     	<unknown>
100009c5c:     	adr	x20, 0x10006888a <dyld_private+0x58872>
100009c60:     	fnmls	z18.h, p3/m, z27.h, z10.h
100009c64:     	<unknown>
100009c68:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009c6c:     	fcmla.8h	v24, v3, v18[1], #180
100009c70:     	<unknown>
100009c74:     	adr	x15, 0x1000f023b <dyld_private+0xe0223>
100009c78:     	umlsl.4s	v5, v27, v3[3]
100009c7c:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009c80:     	adr	x24, 0x1000a822f <dyld_private+0x98217>
100009c84:     	ldpsw	x20, x26, [x11, #-0x98]
100009c88:     	ldpsw	x26, x24, [x11, #-0x60]
100009c8c:     	adr	x15, 0x100064a5a <dyld_private+0x54a42>
100009c90:     	<unknown>
100009c94:     	<unknown>
100009c98:     	fnmls	z13.h, p4/m, z3.h, z12.h
100009c9c:     	<unknown>
100009ca0:     	<unknown>
100009ca4:     	fnmls	z11.h, p5/m, z3.h, z18.h
100009ca8:     	<unknown>
100009cac:     	<unknown>
100009cb0:     	<unknown>
100009cb4:     	adr	x20, 0x10006853e <dyld_private+0x58526>
100009cb8:     	<unknown>
100009cbc:     	fcmla.4h	v15, v19, v13[1], #270
100009cc0:     	smlsl2.4s	v13, v10, v3[2]
100009cc4:     	<unknown>
100009cc8:     	fnmls	z4.h, p5/m, z11.h, z12.h
100009ccc:     	ldp	d15, d21, [x1, #-0x170]
100009cd0:     	<unknown>
100009cd4:     	<unknown>
100009cd8:     	<unknown>
100009cdc:     	<unknown>
100009ce0:     	<unknown>
100009ce4:     	fcmla.8h	v5, v19, v18[1], #270
100009ce8:     	stgp	x18, x14, [x19, #-0x400]
100009cec:     	ldnp	d14, d29, [x19, #-0x1f0]
100009cf0:     	umax.16b	v9, v3, v0
100009cf4:     	<unknown>
100009cf8:     	<unknown>
100009cfc:     	fnmls	z15.h, p3/m, z19.h, z22.h
100009d00:     	fcmla.8h	v18, v27, v9[1], #270
100009d04:     	udf	#0xa6e
100009d08:     	udf	#0xaf
100009d0c:     	udf	#0x0
100009d10:     	fnmla	z15.h, p5/m, z9.h, z19.h
100009d14:     	uabdl2.8h	v18, v27, v15
100009d18:     	<unknown>
100009d1c:     	adr	x20, 0x10006894a <dyld_private+0x58932>
100009d20:     	fnmls	z18.h, p3/m, z27.h, z10.h
100009d24:     	<unknown>
100009d28:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009d2c:     	fcmla.8h	v24, v3, v18[1], #180
100009d30:     	<unknown>
100009d34:     	adr	x15, 0x1000f02fb <dyld_private+0xe02e3>
100009d38:     	umlsl.4s	v5, v27, v3[3]
100009d3c:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009d40:     	adr	x24, 0x1000a82ef <dyld_private+0x982d7>
100009d44:     	ldpsw	x20, x26, [x11, #-0x98]
100009d48:     	ldpsw	x26, x24, [x11, #-0x60]
100009d4c:     	adr	x15, 0x100064b1a <dyld_private+0x54b02>
100009d50:     	<unknown>
100009d54:     	<unknown>
100009d58:     	fnmls	z13.h, p4/m, z3.h, z12.h
100009d5c:     	<unknown>
100009d60:     	<unknown>
100009d64:     	fnmls	z11.h, p5/m, z3.h, z18.h
100009d68:     	<unknown>
100009d6c:     	<unknown>
100009d70:     	<unknown>
100009d74:     	<unknown>
100009d78:     	ldnp	d15, d25, [x3, #-0xb0]
100009d7c:     	ldpsw	x5, x11, [x27, #0xa0]
100009d80:     	<unknown>
100009d84:     	<unknown>
100009d88:     	<unknown>
100009d8c:     	tbz	w24, #0x6, 0x10000e4d8 <dyld_stub_binder+0x10000e4d8>
100009d90:     	<unknown>
100009d94:     	uabdl2.4s	v0, v17, v21
100009d98:     	fnmls	z20.h, p2/m, z11.h, z13.h
100009d9c:     	<unknown>
100009da0:     	<unknown>
100009da4:     	<unknown>
100009da8:     	<unknown>
100009dac:     	fnmls	z14.h, p5/m, z11.h, z13.h
100009db0:     	<unknown>
100009db4:     	<unknown>
100009db8:     	ldpsw	x5, x28, [x19, #-0x68]
100009dbc:     	<unknown>
100009dc0:     	udf	#0xaf
100009dc4:     	udf	#0x0
100009dc8:     	fnmla	z15.h, p5/m, z9.h, z19.h
100009dcc:     	uabdl2.8h	v18, v27, v15
100009dd0:     	<unknown>
100009dd4:     	adr	x20, 0x100068a02 <dyld_private+0x589ea>
100009dd8:     	fnmls	z18.h, p3/m, z27.h, z10.h
100009ddc:     	<unknown>
100009de0:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009de4:     	fcmla.8h	v24, v3, v18[1], #180
100009de8:     	<unknown>
100009dec:     	adr	x15, 0x1000f03b3 <dyld_private+0xe039b>
100009df0:     	umlsl.4s	v5, v27, v3[3]
100009df4:     	fnmls	z19.h, p2/m, z10.h, z12.h
100009df8:     	adr	x24, 0x1000a83a7 <dyld_private+0x9838f>
100009dfc:     	ldpsw	x20, x26, [x11, #-0x98]
100009e00:     	ldpsw	x26, x24, [x11, #-0x60]
100009e04:     	adr	x15, 0x100064bd2 <dyld_private+0x54bba>
100009e08:     	<unknown>
100009e0c:     	<unknown>
100009e10:     	fnmls	z13.h, p4/m, z3.h, z12.h
100009e14:     	<unknown>
100009e18:     	<unknown>
100009e1c:     	fnmls	z11.h, p5/m, z3.h, z18.h
100009e20:     	<unknown>
100009e24:     	<unknown>
100009e28:     	<unknown>
100009e2c:     	<unknown>
100009e30:     	ldnp	d15, d25, [x3, #-0xb0]
100009e34:     	ldpsw	x5, x11, [x27, #0xa0]
100009e38:     	<unknown>
100009e3c:     	<unknown>
100009e40:     	<unknown>
100009e44:     	tbz	w24, #0x6, 0x10000e590 <dyld_stub_binder+0x10000e590>
100009e48:     	<unknown>
100009e4c:     	uabdl2.4s	v0, v17, v21
100009e50:     	fnmls	z20.h, p2/m, z11.h, z13.h
100009e54:     	<unknown>
100009e58:     	<unknown>
100009e5c:     	<unknown>
100009e60:     	<unknown>
100009e64:     	fnmls	z14.h, p5/m, z11.h, z13.h
100009e68:     	<unknown>
100009e6c:     	<unknown>
100009e70:     	ldpsw	x5, x28, [x19, #-0x68]
100009e74:     	<unknown>
100009e78:     	udf	#0x22
		...
100009e88:     	udf	#0x18
100009e8c:     	udf	#0x0
100009e90:     	udf	#0x89
100009e94:     	udf	#0x0
100009e98:     	udf	#0x18
		...
100009ea8:     	udf	#0x1a
100009eac:     	udf	#0x0
100009eb0:     	udf	#0xa1
100009eb4:     	udf	#0x0
100009eb8:     	udf	#0x1a
100009ebc:     	udf	#0x0
100009ec0:     	udf	#0x3
100009ec4:     	udf	#0x0
100009ec8:     	udf	#0x1
100009ecc:     	udf	#0x0
100009ed0:     	udf	#0xbb
100009ed4:     	udf	#0x0
100009ed8:     	udf	#0x1
		...
100009ee8:     	udf	#0x2
100009eec:     	udf	#0x0
100009ef0:     	udf	#0xbc
		...
100009f00:     	udf	#0x3
100009f04:     	udf	#0x0
100009f08:     	udf	#0x1
100009f0c:     	udf	#0x0
100009f10:     	udf	#0xbc
100009f14:     	udf	#0x0
100009f18:     	udf	#0x1
		...
100009f28:     	udf	#0x2
100009f2c:     	udf	#0x0
100009f30:     	udf	#0xbd
		...
100009f48:     	udf	#0x5
100009f4c:     	udf	#0x0
100009f50:     	udf	#0xbd
100009f54:     	udf	#0x0
100009f58:     	udf	#0x4
		...
100009f68:     	udf	#0x5
100009f6c:     	udf	#0x0
100009f70:     	udf	#0xc1
100009f74:     	udf	#0x0
100009f78:     	udf	#0x5
100009f7c:     	udf	#0x0
100009f80:     	udf	#0x3
100009f84:     	udf	#0x0
100009f88:     	udf	#0x1
100009f8c:     	udf	#0x0
100009f90:     	udf	#0xc6
100009f94:     	udf	#0x0
100009f98:     	udf	#0x1
		...
100009fa8:     	udf	#0x2
100009fac:     	udf	#0x0
100009fb0:     	udf	#0xc7
		...
100009fc0:     	udf	#0x3
100009fc4:     	udf	#0x0
100009fc8:     	udf	#0x1
100009fcc:     	udf	#0x0
100009fd0:     	udf	#0xc7
100009fd4:     	udf	#0x0
100009fd8:     	udf	#0x1
		...
100009fe8:     	udf	#0x2
100009fec:     	udf	#0x0
100009ff0:     	udf	#0xc8
		...
10000a000:     	udf	#0x4
10000a004:     	udf	#0x0
10000a008:     	udf	#0x200
10000a00c:     	udf	#0x0
10000a010:     	udf	#0xc8
10000a014:     	udf	#0x0
10000a018:     	udf	#0x2
		...
10000a028:     	udf	#0x2
10000a02c:     	udf	#0x0
10000a030:     	udf	#0xca
		...
10000a048:     	udf	#0x2
10000a04c:     	udf	#0x0
10000a050:     	udf	#0xca
10000a054:     	udf	#0x0
10000a058:     	udf	#0x2
		...
10000a068:     	udf	#0x2
10000a06c:     	udf	#0x0
10000a070:     	udf	#0xcc
10000a074:     	udf	#0x0
10000a078:     	udf	#0x2
10000a07c:     	udf	#0x0
10000a080:     	udf	#0x3
10000a084:     	udf	#0x0
10000a088:     	udf	#0x1
10000a08c:     	udf	#0x0
10000a090:     	udf	#0xce
10000a094:     	udf	#0x0
10000a098:     	udf	#0x1
		...
10000a0a8:     	udf	#0x2
10000a0ac:     	udf	#0x0
10000a0b0:     	udf	#0xcf
		...
10000a0c8:     	udf	#0x4
10000a0cc:     	udf	#0x0
10000a0d0:     	udf	#0xcf
10000a0d4:     	udf	#0x0
10000a0d8:     	udf	#0x4
10000a0dc:     	udf	#0x0
10000a0e0:     	udf	#0x4
10000a0e4:     	udf	#0x0
10000a0e8:     	udf	#0x4
10000a0ec:     	udf	#0x0
10000a0f0:     	udf	#0xd3
10000a0f4:     	udf	#0x0
10000a0f8:     	udf	#0x2
10000a0fc:     	udf	#0x0
10000a100:     	udf	#0x4
10000a104:     	udf	#0x0
10000a108:     	udf	#0x7
10000a10c:     	udf	#0x0
10000a110:     	udf	#0xd5
10000a114:     	udf	#0x0
10000a118:     	udf	#0x2
		...
10000a128:     	udf	#0x2
10000a12c:     	udf	#0x0
10000a130:     	udf	#0xd7
		...
10000a148:     	udf	#0x6
10000a14c:     	udf	#0x0
10000a150:     	udf	#0xd7
10000a154:     	udf	#0x0
10000a158:     	udf	#0x6
10000a15c:     	udf	#0x0
10000a160:     	udf	#0x5
10000a164:     	udf	#0x0
10000a168:     	udf	#0x1
10000a16c:     	udf	#0x0
10000a170:     	udf	#0xdd
10000a174:     	udf	#0x0
10000a178:     	udf	#0x20
10000a17c:     	udf	#0x0
10000a180:     	udf	#0x5
10000a184:     	udf	#0x0
10000a188:     	udf	#0x1
10000a18c:     	udf	#0x0
10000a190:     	udf	#0xfd
10000a194:     	udf	#0x0
10000a198:     	udf	#0x7
10000a19c:     	udf	#0x0
10000a1a0:     	udf	#0x5
10000a1a4:     	udf	#0x0
10000a1a8:     	udf	#0x1
10000a1ac:     	udf	#0x0
10000a1b0:     	udf	#0x104
10000a1b4:     	udf	#0x0
10000a1b8:     	udf	#0x3
10000a1bc:     	udf	#0x0
10000a1c0:     	udf	#0x5
10000a1c4:     	udf	#0x0
10000a1c8:     	udf	#0x6
10000a1cc:     	udf	#0x0
10000a1d0:     	udf	#0x107
10000a1d4:     	udf	#0x0
10000a1d8:     	udf	#0x4
10000a1dc:     	udf	#0x0
10000a1e0:     	udf	#0x5
10000a1e4:     	udf	#0x0
10000a1e8:     	udf	#0x6
10000a1ec:     	udf	#0x0
10000a1f0:     	udf	#0x10b
10000a1f4:     	udf	#0x0
10000a1f8:     	udf	#0x5
10000a1fc:     	udf	#0x0
10000a200:     	udf	#0x5
10000a204:     	udf	#0x0
10000a208:     	udf	#0x6
10000a20c:     	udf	#0x0
10000a210:     	udf	#0x110
10000a214:     	udf	#0x0
10000a218:     	udf	#0x5
10000a21c:     	udf	#0x0
10000a220:     	udf	#0x5
10000a224:     	udf	#0x0
10000a228:     	udf	#0x6
10000a22c:     	udf	#0x0
10000a230:     	udf	#0x115
10000a234:     	udf	#0x0
10000a238:     	udf	#0x5
10000a23c:     	udf	#0x0
10000a240:     	udf	#0x5
10000a244:     	udf	#0x0
10000a248:     	udf	#0x6
10000a24c:     	udf	#0x0
10000a250:     	udf	#0x11a
10000a254:     	udf	#0x0
10000a258:     	udf	#0x5
10000a25c:     	udf	#0x0
10000a260:     	udf	#0x5
10000a264:     	udf	#0x0
10000a268:     	udf	#0x3
10000a26c:     	udf	#0x0
10000a270:     	udf	#0x11f
10000a274:     	udf	#0x0
10000a278:     	udf	#0x5
10000a27c:     	udf	#0x0
10000a280:     	udf	#0x5
10000a284:     	udf	#0x0
10000a288:     	udf	#0x3
10000a28c:     	udf	#0x0
10000a290:     	udf	#0x124
10000a294:     	udf	#0x0
10000a298:     	udf	#0x5
		...
10000a2a8:     	udf	#0x7
10000a2ac:     	udf	#0x0
10000a2b0:     	udf	#0x129
10000a2b4:     	udf	#0x0
10000a2b8:     	udf	#0x2
10000a2bc:     	udf	#0x0
10000a2c0:     	udf	#0xa
10000a2c4:     	udf	#0x0
10000a2c8:     	udf	#0xa
10000a2cc:     	udf	#0x0
10000a2d0:     	udf	#0xa
10000a2d4:     	udf	#0x0
10000a2d8:     	udf	#0xa
10000a2dc:     	udf	#0x0
10000a2e0:     	udf	#0xa
10000a2e4:     	udf	#0x0
10000a2e8:     	udf	#0xa
10000a2ec:     	udf	#0x0
10000a2f0:     	udf	#0xa
10000a2f4:     	udf	#0x0
10000a2f8:     	udf	#0xa
10000a2fc:     	udf	#0x0
10000a300:     	udf	#0xa
10000a304:     	udf	#0x0
10000a308:     	udf	#0xa
10000a30c:     	udf	#0x0
10000a310:     	udf	#0xa
10000a314:     	udf	#0x0
10000a318:     	udf	#0xa
10000a31c:     	udf	#0x0
10000a320:     	udf	#0xa
10000a324:     	udf	#0x0
10000a328:     	udf	#0xa
10000a32c:     	udf	#0x0
10000a330:     	udf	#0xa
10000a334:     	udf	#0x0
10000a338:     	udf	#0xa
10000a33c:     	udf	#0x0
10000a340:     	udf	#0xa
10000a344:     	udf	#0x0
10000a348:     	udf	#0xa
10000a34c:     	udf	#0x0
10000a350:     	udf	#0xa
10000a354:     	udf	#0x0
10000a358:     	udf	#0xa
10000a35c:     	udf	#0x0
10000a360:     	udf	#0xa
10000a364:     	udf	#0x0
10000a368:     	udf	#0xa
10000a36c:     	udf	#0x0
10000a370:     	udf	#0xa
10000a374:     	udf	#0x0
10000a378:     	udf	#0xa
10000a37c:     	udf	#0x0
10000a380:     	udf	#0xa
10000a384:     	udf	#0x0
10000a388:     	udf	#0xa
10000a38c:     	udf	#0x0
10000a390:     	udf	#0xa
10000a394:     	udf	#0x0
10000a398:     	udf	#0xa
10000a39c:     	udf	#0x0
10000a3a0:     	udf	#0xa
10000a3a4:     	udf	#0x0
10000a3a8:     	udf	#0xa
10000a3ac:     	udf	#0x0
10000a3b0:     	udf	#0xa
10000a3b4:     	udf	#0x0
10000a3b8:     	udf	#0xa
10000a3bc:     	udf	#0x0
10000a3c0:     	udf	#0xa
10000a3c4:     	udf	#0x0
10000a3c8:     	udf	#0xa
10000a3cc:     	udf	#0x0
10000a3d0:     	udf	#0xa
10000a3d4:     	udf	#0x0
10000a3d8:     	udf	#0xa
10000a3dc:     	udf	#0x0
10000a3e0:     	udf	#0xa
10000a3e4:     	udf	#0x0
10000a3e8:     	udf	#0xa
10000a3ec:     	udf	#0x0
10000a3f0:     	udf	#0xa
10000a3f4:     	udf	#0x0
10000a3f8:     	udf	#0xa
10000a3fc:     	udf	#0x0
10000a400:     	udf	#0xa
10000a404:     	udf	#0x0
10000a408:     	udf	#0xa
10000a40c:     	udf	#0x0
10000a410:     	udf	#0xa
10000a414:     	udf	#0x0
10000a418:     	udf	#0xa
10000a41c:     	udf	#0x0
10000a420:     	udf	#0xa
10000a424:     	udf	#0x0
10000a428:     	udf	#0xa
10000a42c:     	udf	#0x0
10000a430:     	udf	#0xa
10000a434:     	udf	#0x0
10000a438:     	udf	#0xa
10000a43c:     	udf	#0x0
10000a440:     	udf	#0xa
10000a444:     	udf	#0x0
10000a448:     	udf	#0xa
10000a44c:     	udf	#0x0
10000a450:     	udf	#0x100
10000a454:     	udf	#0x0
10000a458:     	udf	#0x101
10000a45c:     	udf	#0x0
10000a460:     	udf	#0x117
10000a464:     	udf	#0x0
10000a468:     	udf	#0xc
10000a46c:     	udf	#0x0
10000a470:     	<unknown>
10000a474:     	udf	#0x0
10000a478:     	udf	#0xc
10000a47c:     	udf	#0x0
10000a480:     	udf	#0x9
10000a484:     	udf	#0x0
10000a488:     	udf	#0x9
10000a48c:     	udf	#0x0
10000a490:     	udf	#0xc
10000a494:     	udf	#0x0
10000a498:     	udf	#0x108
10000a49c:     	udf	#0x0
10000a4a0:     	udf	#0xc
10000a4a4:     	udf	#0x0
10000a4a8:     	udf	#0xc
10000a4ac:     	udf	#0x0
10000a4b0:     	udf	#0x5
10000a4b4:     	udf	#0x0
10000a4b8:     	udf	#0x4
10000a4bc:     	udf	#0x0
10000a4c0:     	udf	#0x200
10000a4c4:     	udf	#0x0
10000a4c8:     	udf	#0x118
10000a4cc:     	udf	#0x0
10000a4d0:     	udf	#0x4
10000a4d4:     	udf	#0x0
10000a4d8:     	udf	#0x119
10000a4dc:     	udf	#0x0
10000a4e0:     	udf	#0x4
10000a4e4:     	udf	#0x0
10000a4e8:     	udf	#0x7
10000a4ec:     	udf	#0x0
10000a4f0:     	udf	#0x4
10000a4f4:     	udf	#0x0
10000a4f8:     	udf	#0x4
10000a4fc:     	udf	#0x0
10000a500:     	udf	#0x4
10000a504:     	udf	#0x0
10000a508:     	udf	#0x4
10000a50c:     	udf	#0x0
10000a510:     	udf	#0x4
10000a514:     	udf	#0x0
10000a518:     	udf	#0x4
10000a51c:     	udf	#0x0
10000a520:     	udf	#0x8
10000a524:     	udf	#0x0
10000a528:     	udf	#0x7
10000a52c:     	udf	#0x0
10000a530:     	udf	#0x4
10000a534:     	udf	#0x0
10000a538:     	udf	#0xa
10000a53c:     	udf	#0x0
10000a540:     	udf	#0xa
10000a544:     	udf	#0x0
10000a548:     	udf	#0xa
10000a54c:     	udf	#0x0
10000a550:     	udf	#0x9
10000a554:     	udf	#0x0
10000a558:     	udf	#0x9
10000a55c:     	udf	#0x0
10000a560:     	udf	#0x1f
		...
10000a660:     	udf	#0x6
		...
10000a698:     	udf	#0x2
		...
10000a6b0:     	udf	#0x2
		...
10000a6c0:     	udf	#0x1
10000a6c4:     	udf	#0x0
10000a6c8:     	udf	#0x106
10000a6cc:     	udf	#0x0
10000a6d0:     	udf	#0x2
10000a6d4:     	udf	#0x0
10000a6d8:     	udf	#0x1
10000a6dc:     	udf	#0x0
10000a6e0:     	udf	#0xc
10000a6e4:     	udf	#0x0
10000a6e8:     	udf	#0x1
10000a6ec:     	udf	#0x0
10000a6f0:     	udf	#0x106
10000a6f4:     	udf	#0x0
10000a6f8:     	udf	#0x2
10000a6fc:     	udf	#0x0
10000a700:     	udf	#0x1
10000a704:     	udf	#0x0
10000a708:     	<unknown>
10000a70c:     	udf	#0x0
10000a710:     	udf	#0x1
10000a714:     	udf	#0x0
10000a718:     	udf	#0x106
10000a71c:     	udf	#0x0
10000a720:     	udf	#0x2
10000a724:     	udf	#0x0
10000a728:     	udf	#0x1
10000a72c:     	udf	#0x0
10000a730:     	udf	#0x9
10000a734:     	udf	#0x0
10000a738:     	udf	#0x1
10000a73c:     	udf	#0x0
10000a740:     	udf	#0x106
10000a744:     	udf	#0x0
10000a748:     	udf	#0x2
10000a74c:     	udf	#0x0
10000a750:     	udf	#0x1
10000a754:     	udf	#0x0
10000a758:     	udf	#0x108
10000a75c:     	udf	#0x0
10000a760:     	udf	#0x1
10000a764:     	udf	#0x0
10000a768:     	udf	#0x106
10000a76c:     	udf	#0x0
10000a770:     	udf	#0x2
10000a774:     	udf	#0x0
10000a778:     	udf	#0x1
10000a77c:     	udf	#0x0
10000a780:     	udf	#0xc
10000a784:     	udf	#0x0
10000a788:     	udf	#0x1
10000a78c:     	udf	#0x0
10000a790:     	udf	#0x10e
10000a794:     	udf	#0x0
10000a798:     	udf	#0x2
10000a79c:     	udf	#0x0
10000a7a0:     	udf	#0x1
10000a7a4:     	udf	#0x0
10000a7a8:     	udf	#0xc
10000a7ac:     	udf	#0x0
10000a7b0:     	udf	#0x1
10000a7b4:     	udf	#0x0
10000a7b8:     	udf	#0x10f
10000a7bc:     	udf	#0x0
10000a7c0:     	udf	#0x116
10000a7c4:     	udf	#0x0
10000a7c8:     	udf	#0xa
10000a7cc:     	udf	#0x0

000000010000a7d0 <__NSGetArgc__thunk>:
10000a7d0:     	adrp	x16, 0x10000a000 <_main+0x2b80>
10000a7d4:     	add	x16, x16, #0x7f4
10000a7d8:     	br	x16

000000010000a7dc <__NSGetArgv__thunk>:
10000a7dc:     	adrp	x16, 0x10000a000 <_main+0x2b80>
10000a7e0:     	add	x16, x16, #0x800
10000a7e4:     	br	x16

000000010000a7e8 <_clock_gettime_nsec_np__thunk>:
10000a7e8:     	adrp	x16, 0x10000a000 <_main+0x2b80>
10000a7ec:     	add	x16, x16, #0x80c
10000a7f0:     	br	x16

Disassembly of section __TEXT,__stubs:

000000010000a7f4 <__stubs>:
10000a7f4:     	adrp	x16, 0x100010000 <dyld_stub_binder+0x100010000>
10000a7f8:     	ldr	x16, [x16]
10000a7fc:     	br	x16
10000a800:     	adrp	x16, 0x100010000 <dyld_stub_binder+0x100010000>
10000a804:     	ldr	x16, [x16, #0x8]
10000a808:     	br	x16
10000a80c:     	adrp	x16, 0x100010000 <dyld_stub_binder+0x100010000>
10000a810:     	ldr	x16, [x16, #0x10]
10000a814:     	br	x16

Disassembly of section __TEXT,__stub_helper:

000000010000a818 <__stub_helper>:
10000a818:     	adrp	x17, 0x100010000 <dyld_stub_binder+0x100010000>
10000a81c:     	add	x17, x17, #0x18
10000a820:     	stp	x16, x17, [sp, #-0x10]!
10000a824:     	adrp	x16, 0x10000c000 <dyld_stub_binder+0x10000c000>
10000a828:     	ldr	x16, [x16]
10000a82c:     	br	x16
10000a830:     	ldr	w16, 0x10000a838 <__stub_helper+0x20>
10000a834:     	b	0x10000a818 <__stub_helper>
10000a838:     	udf	#0x0
10000a83c:     	ldr	w16, 0x10000a844 <__stub_helper+0x2c>
10000a840:     	b	0x10000a818 <__stub_helper>
10000a844:     	udf	#0x0
10000a848:     	ldr	w16, 0x10000a850 <__stub_helper+0x38>
10000a84c:     	b	0x10000a818 <__stub_helper>
10000a850:     	udf	#0x0
