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

	// PNG Magic: 0x0A1A0A0D474E5089
	ldr	x0, [sp, #1088]	// Load the 12 bytes
	movz	x1, #0x5089		// Load low 16 bits
	movk	x1, #0x474E, lsl #16	// Shift and "keep"
	movk	x1, #0x0A0D, lsl #32
	movk	x1, #0x0A1A, lsl #48

	cmp	x0, x1
	cset	w0, eq
	b	.L_done

.L_false:
	mov	w0, #0

.L_done:
	ldp	x19, x20, [sp, #16]
	ldp	x29, x30, [sp]
	add	sp, sp, #2112
	retaa
