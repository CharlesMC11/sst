.section __TEXT,__text,regular,pure_instructions
.globl _is_image
.p2align 2

.extern _g_input_absolute_path
.extern _open
.extern _read
.extern _close

_is_image:
	pacia	x30, sp
	sub	sp, sp, #2112			// 16 + 16 + 1024 + buf + 1024
	stp	x29, x30, [sp]
	mov	x29, sp
	stp	x19, x20, [sp, #16]

	// Check if regular file
	mov	x19, x0				// const struct dirent* entry
	ldrb	w0, [x19, #20]			// d_type
	cmp	w0, #8				// DT_REG
	b.ne	.L_false

	// Construct absolute path
	add	x20, x19, #21			// entry->d_name

	add	x0, sp, #32			// target buffer
	adrp	x1, _g_input_absolute_path@GOTPAGE
	ldr	x1, [x1, _g_input_absolute_path@GOTPAGEOFF]

.L_copy_dirname:				// Manual strcpy
	ldrb	w2, [x1], #1
	cbz	w2, .L_add_separator
	strb	w2, [x0], #1
	b	.L_copy_dirname

.L_add_separator:
	mov	w2, #47				// ASCII '/'
	strb	w2, [x0], #1

.L_copy_filename:
	ldrb	w2, [x20], #1
	strb	w2, [x0], #1
	cbnz	w2, .L_copy_filename

	// Open file
	add	x0, sp, #32
	mov	x1, #0				// O_RDONLY
	movk	x1, #0x100, lsl #16		// O_CLOEXEC
	bl	_open
	cmp	x0, #0
	b.lt	.L_false
	mov	w19, w0

	// Read file
	add	x1, sp, #1088		// buffer
	mov	x2, #12			// bytes count
	bl	_read
	mov	x20, x0

	// Close file
	mov	w0, w19
	bl	_close

	// Check if 12 bytes
	cmp	x20, #12
	b.ne	.L_false

	ldr	q0, [sp, #1088]	// Load the 12 bytes

	// PNG: 89 50 4E 47 0D 0A 1A 0A
	movz	x1, #0x5089
	movk	x1, #0x474E, lsl #16
	movk	x1, #0x0A0D, lsl #32
	movk	x1, #0x0A1A, lsl #48
	fmov	d1, x1
	cmeq	v1.2d, v0.2d, v1.2d
	fmov	x1, d1
	cbnz	x1, .L_true

	// JPEG: FF D8 FF
	fmov	w1, s0
	and	w1, w1, #0xFFFFFF
	mov	w2, #0xD8FF
	movk	w2, #0x00FF, lsl #16
	cmp	w1, w2
	b.eq	.L_true

	// TIFF: 'II' (49 49 2A 00) or 'MM'(4D 4D 00 2A)
	fmov	w1, s0
	mov	w2, #0x4949		// 'II'
	movk	w2, #0x002A, lsl #16
	cmp	w1, w2
	b.eq	.L_true

	mov	w2, #0x4D4D		// 'MM'
	movk	w2, #0x2A00, lsl #16
	cmp	w1, w2
	b.eq	.L_true

	// HEIF: 'ftypheic' or 'ftypmif1' at offset 4
	ext	v1.16b, v0.16b, v0.16b, #4
	movz	x1, #0x7466		// 'ft'
	movk	x1, #0x7079, lsl #16	// 'yp'
	movk	x1, #0x6568, lsl #32	// 'he'
	movk	x1, #0x6369, lsl #48	// 'ic'
	fmov	d2, x1
	cmeq	v2.2d, v1.2d, v2.2d
	fmov	x1, d2
	cbnz	x1, .L_true

.L_false:
	mov	w0, #0
	b	.L_done

.L_true:
	mov	w0, #1

.L_done:
	ldp	x19, x20, [sp, #16]
	ldp	x29, x30, [sp]
	add	sp, sp, #2112
	retaa
