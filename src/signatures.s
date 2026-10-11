.section __TEXT,__text,regular,pure_instructions
.globl _has_image_signature
.p2align 4

// PNG: 89 50 4E 47 0D 0A 1A 0A
.equiv	PNG_LO16 #0x5089
.equiv	PNG_HI16 #0x474E
.equiv	PNG_LO32 #0x0A0D
.equiv	PNG_HI32 #0x0A1A

// JPEG: FF D8 FF
.equiv	JPEG_LO16 #0xD8FF
.equiv	JPEG_HI16 #0x00FF

// TIFF - 'II': 49 49 2A 00
.equiv	TIFF_II_LO16 #0x4949
.equiv	TIFF_II_HI16 #0x002A

// TIFF - 'MM': 4D 4D 00 2A
.equiv	TIFF_MM_LO16 #0x4D4D
.equiv	TIFF_MM_HI16 #0x2A00

// HEIF: 'ftypheic' or 'ftypmif1' at offset 4
.equiv	HEIF_FT #'f' | ('t' << 8)
.equiv	HEIF_YP #'y' | ('p' << 8)

.equiv	HEIF_HE #'h' | ('e' << 8)
.equiv	HEIF_IC #'i' | ('c' << 8)

.equiv	HEIF_MI #'m' | ('i' << 8)
.equiv	HEIF_F1 #'f' | ('1' << 8)

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

	movz	x3, #PNG_LO16
	movk	x3, #PNG_HI16, lsl #16
	movk	x3, #PNG_LO32, lsl #32
	movk	x3, #PNG_HI32, lsl #48

	ubfx	w4, w1, #0, #24
	movz	w5, #JPEG_LO16
	movk	w5, #JPEG_HI16, lsl #16

	movz	w6, #TIFF_II_LO16
	movk	w6, #TIFF_II_HI16, lsl #16

	movz	w7, #TIFF_MM_LO16
	movk	w7, #TIFF_MM_HI16, lsl #16

	extr	x8, x2, x1, #32
	movz	x9, #HEIC_FT
	movk	x9, #HEIC_YP, lsl #16
	movk	x9, #HEIC_HE, lsl #32
	movk	x9, #HEIC_IC, lsl #48

	movz	x10, #HEIC_FT
	movk	x10, #HEIC_YP, lsl #16
	movk	x10, #HEIC_MI, lsl #32
	movk	x10, #HEIC_F1, lsl #48

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
