    .section __TEXT,__text,regular,pure_instructions
    .globl _has_image_signature
    .p2align 2

_has_image_signature:
    .cfi_startproc
    pacia   x30, sp

    ldp     x9, x10, [x0]

    // PNG: 89 50 4E 47 0D 0A 1A 0A
    movz    x11, #0x5089
    movk    x11, #0x474E, lsl #16
    movk    x11, #0x0A0D, lsl #32
    movk    x11, #0x0A1A, lsl #48
    cmp     x9, x11

    // JPEG: FF D8 FF
    ubfx    w11, w9, #0, #24
    movz    w12, #0xD8FF
    movk    w12, #0x00FF, lsl #16
    ccmp    w11, w12, #4, ne

    // TIFF: 'II' (49 49 2A 00) or 'MM'(4D 4D 00 2A)
    ubfx    w11, w9, #0, #32
    movz    w12, #0x4949                // 'II'
    movk    w12, #0x002A, lsl #16
    ccmp    w11, w12, #4, ne

    movz    w12, #0x4D4D                // 'MM'
    movk    w12, #0x2A00, lsl #16
    ccmp    w11, w12, #4, ne

    // HEIF: 'ftypmif1' or 'ftypheic' at offset 4
    extr    x11, x10, x9, #32
    movz    x12, #0x7466                // 'ft'
    movk    x12, #0x7079, lsl #16       // 'yp'
    movk    x12, #0x696D, lsl #32       // 'mi'
    movk    x12, #0x3166, lsl #48       // 'f1'
    ccmp    x11, x12, #4, ne

    movk    x12, #0x6568, lsl #32       // 'he'
    movk    x12, #0x6369, lsl #48       // 'ic'
    ccmp    x11, x12, #4, ne

    b.eq    L_true

    mov     w0, wzr
    retaa

L_true:
    mov     w0, #1
    retaa

    .cfi_endproc
    .subsections_via_symbols
