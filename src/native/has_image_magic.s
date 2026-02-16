.section __TEXT,__text,regular,pure_instructions
.globl _has_image_magic
.p2align 2

_has_image_magic:
	pacia	x30, sp
	stp	x29, x30, [sp, #-32]!
	mov	x29, sp
	stp	x19, x20, [sp, #16]

	// Open
	mov	x1, #0			// O_RDONLY
	movk	x1, #0x100, lsl #16	// O_CLOEXEC
	bl	_open
	cmp	x0, #0
	b.lt	.L_error

	mov	w19, w0

	// Read file
	// fd already in w0
	add	x1, sp, #8		// buffer
	mov	x2, #8			// bytes count
	bl	_read

	mov	x20, x0

	// Close file
	mov	w0, w19			// grab the fd
	bl	_close

	// Check if 8 bytes
	cmp	x20, #8
	b.ne	.L_error

	// PNG Magic: 0x0A1A0A0D474E5089
	movz	x1, #0x5089		// Load low 16 bits
	movk	x1, #0x474E, lsl #16	// Shift and "keep"
	movk	x1, #0x0A0D, lsl #32
	movk	x1, #0x0A1A, lsl #48

	cmp	x0, x1
	cset	w0, eq
	b	.L_done

.L_error:
	mov	w0, #0

.L_done:
	ldp	x19, x20, [sp, #16]
	ldp	x29, x30, [sp], #32
	retaa
