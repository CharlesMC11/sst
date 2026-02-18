/*!
 * Read the first 12-16 bytes of a file to determine if it belongs to a
 * supported photographic format
 * @environment AArch64 (Apple Silicon), macOS ABI
 * @param x0 (int fd): File descriptor to read from
 * @return w0 (bool): 1 if file matches PNG, HEIC, JPEG, or TIFF; 0 otherwise
 */

.section __TEXT,__text,regular,pure_instructions
.globl _is_image
.p2align 2

.extern _read

_is_image:
    pacia   x30, sp
    stp     x29, x30, [sp, #-32]!       // reserve a 16-byte buffer
    mov     x29, sp

    // Read file
    add     x1, sp, #16                 // load the 16-byte buffer
    mov     x2, #16                     // read 16 bytes from the file
    bl      _read

    cmp     x0, #12                     // Check if at least 12 bytes were read
    b.lt   .L_false

    ldr     x9, [sp, #16]
    ldr     w10, [sp, #24]

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    movz    x11, #0x5089
    movk    x11, #0x474E, lsl #16
    movk    x11, #0x0A0D, lsl #32
    movk    x11, #0x0A1A, lsl #48
    cmp     x9, x11
    b.eq    .L_true

    // JPEG: FF D8 FF
    ubfx    w11, w9, #0, #24
    movz    w12, #0xD8FF
    movk    w12, #0x00FF, lsl #16
    cmp     w11, w12
    b.eq    .L_true

    // TIFF: 'II' (49 49 2A 00) or 'MM'(4D 4D 00 2A)
    ubfx    w11, w9, #0, #32
    movz    w12, #0x4949                // 'II'
    movk    w12, #0x002A, lsl #16
    cmp     w11, w12
    b.eq    .L_true

    movz    w12, #0x4D4D                // 'MM'
    movk    w12, #0x2A00, lsl #16
    cmp     w11, w12
    b.eq    .L_true

    // HEIF: 'ftypmif1' or 'ftypheic' at offset 4
    extr    x11, x10, x9, #32
    movz    x12, #0x7466                // 'ft'
    movk    x12, #0x7079, lsl #16       // 'yp'
    movk    x12, #0x696D, lsl #32       // 'mi'
    movk    x12, #0x3166, lsl #48       // 'f1'
    cmp     x11, x12
    b.eq    .L_true

    movk    x12, #0x6568, lsl #32       // 'he'
    movk    x12, #0x6369, lsl #48       // 'ic'
    cmp     x11, x12
    b.eq    .L_true

.L_false:
    mov     w0, #0
    b       .L_done

.L_true:
    mov     w0, #1

.L_done:
    ldp     x29, x30, [sp], #32
    retaa
