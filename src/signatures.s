	.section __TEXT,__text,regular,pure_instructions
	.globl _has_image_signature
	.p2align 2

/**
 * Check if a given array of bytes matches an image’s magic pattern
 *
 * x0: Pointer to an array of bytes
 *
 * x1: Array index 0–7
 * x2: Array index 8–15
 *
 * x3: PNG magic bytes
 *
 * w4: Extracted bytes for JPEG
 * w5: JPEG magic bytes
 *
 * w6: TIFF 'II' magic bytes
 * w7: TIFF 'MM' magic bytes
 *
 * x8: Extracted bytes for HEIC
 * x9: 'ftypheic' magic bytes
 * x10: 'ftypmif1' magic bytes
 *
 * w3: PNG cmp
 * w5: JPEG cmp
 * w6: 'II' cmp
 * w7: 'MM' cmp
 * w9: 'ftypheic' cmp
 * w10: 'ftypmif1' cmp
 *
 * w0: 1 if a match is found; 0 otherwise
 */
_has_image_signature:
	.cfi_startproc
	ldp 	x1, x2, [x0]

	// PNG: 89 50 4E 47 0D 0A 1A 0A
	movz	x3, #0x5089
	movk	x3, #0x474E, lsl #16
	movk	x3, #0x0A0D, lsl #32
	movk	x3, #0x0A1A, lsl #48

	// JPEG: FF D8 FF
	ubfx	w4, w1, #0, #24
	movz	w5, #0xD8FF
	movk	w5, #0x00FF, lsl #16

	// TIFF: 'II' (49 49 2A 00) or 'MM'(4D 4D 00 2A)
	movz	w6, #0x4949         	// 'II'
	movk	w6, #0x002A, lsl #16

	movz	w7, #0x4D4D         	// 'MM'
	movk	w7, #0x2A00, lsl #16

	// HEIF: 'ftypheic' or 'ftypmif1' at offset 4
	extr	x8, x2, x1, #32
	movz	x9, #0x7466         	// 'ft'
	movk	x9, #0x7079, lsl #16	// 'yp'
	movk	x9, #0x6568, lsl #32	// 'he'
	movk	x9, #0x6369, lsl #48	// 'ic'

	movz	x10, #0x7466         	// 'ft'
	movk	x10, #0x7079, lsl #16	// 'yp'
	movk	x10, #0x696D, lsl #32	// 'mi'
	movk	x10, #0x3166, lsl #48	// 'f1'

	// PNG
	cmp 	x3, x1
	cset	w3, eq
	// JPEG
	cmp 	w5, w4
	cset	w5, eq
	// 'II'
	cmp 	w6, w1
	cset	w6, eq
	// 'MM'
	cmp 	w7, w1
	cset	w7, eq
	// 'ftypheic'
	cmp 	x9, x8
	cset	w9, eq
	// 'ftypmif1'
	cmp 	x10, x8
	cset	w10, eq

	// PNG v JPEG
	orr 	w0, w3, w5
	// 'II' v 'MM'
	orr 	w1, w6, w7
	// 'ftypheic' v 'ftypmif1'
	orr 	w2, w9, w10

	orr 	w0, w0, w1
	orr 	w0, w0, w2
	ret

	.cfi_endproc
	.subsections_via_symbols
