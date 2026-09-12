subsd %xmm15, %xmm6
movaps %xmm6, %xmm0
subsd %xmm15, %xmm0
movaps %xmm0, %xmm15
divss %xmm6, %xmm15
ucomisd %xmm15, %xmm14
ucomiss %xmm6, %xmm15
