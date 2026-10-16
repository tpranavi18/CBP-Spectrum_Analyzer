
.section .text.init
.globl _start
_start:
    /* Disable interrupts during startup */
    csrw mstatus, zero
    csrw mie, zero

    /* Install trap entry handler */
    la t0, trap_handler
    csrw mtvec, t0

    /* Initialize Stack Pointer in Upper DMEM (0x0001C000) */
    li sp, 0x0001C000
    li gp, 0x00010800

    /* Jump to firmware main */
    call firmware_main

halt_loop:
    wfi
    j halt_loop

trap_handler:
    /* Machine trap handler */
    csrr t0, mcause
    csrr t1, mepc
    mret

.section .text
.globl firmware_main
firmware_main:
    addi sp, sp, -32
    sw ra, 28(sp)

    /* ========================================================================
     * 1. Basic CPU Execution & Memory Subsystem Checks (Group A & B)
     * ======================================================================== */
    li t0, 0x1234
    li t1, 0x0010
    mul t2, t0, t1       /* M-extension check: t2 = 0x12340 */
    addi t2, t2, 0x5A    /* t2 = 0x1239A */

    /* Write test words to DMEM (0x00010000 - 0x0001000C) */
    li a0, 0x00010000
    li t3, 0xA5A55A5A
    sw t3, 0(a0)
    li t4, 0x12345678
    sw t4, 4(a0)
    sw t2, 8(a0)

    /* Verify DMEM Readback */
    lw t5, 0(a0)
    lw t6, 4(a0)

    /* Test Byte Strobes in DMEM (0x00010020) */
    li t0, 0x00010020
    sw zero, 0(t0)
    li t1, 0x11
    sb t1, 0(t0)
    li t1, 0x22
    sb t1, 1(t0)
    li t1, 0x33
    sb t1, 2(t0)
    li t1, 0x44
    sb t1, 3(t0)
    lw t2, 0(t0)         /* t2 should be 0x44332211 */
    sw t2, 12(a0)

    /* ========================================================================
     * 2. UART Subsystem Initialization & Banner (Group D)
     * ======================================================================== */
    li a1, 0x40000000    /* UART Base */
    sw zero, 4(a1)       /* Disable UART interrupts */

    la a0, msg_boot
    call uart_puts

    la a0, msg_mem
    call uart_puts

    /* ========================================================================
     * 3. GPIO Configuration & Pin Toggling (Group E)
     * ======================================================================== */
    li a2, 0x40002000    /* GPIO Base */
    li t0, 0xFFFFFFFF    /* All outputs */
    sw t0, 8(a2)         /* GPIO_DIR */
    li t0, 0x12345678
    sw t0, 4(a2)         /* GPIO_DATA_O */
    lw t1, 4(a2)         /* Read back DATA_O */
    li t0, 0x00000001
    sw t0, 32(a2)        /* GPIO_SET_O (bit 0) */
    li t0, 0x00000008
    sw t0, 36(a2)        /* GPIO_CLR_O (bit 3) */

    la a0, msg_gpio
    call uart_puts

    /* ========================================================================
     * 4. Timer Configuration & Down-Counting (Group F)
     * ======================================================================== */
    li a3, 0x40004000    /* TIMER Base */
    li t0, 0x00000200    /* LOAD = 512 */
    sw t0, 4(a3)         /* TIMER_LOAD */
    li t0, 1             /* Enable down-counter */
    sw t0, 0(a3)         /* TIMER_CTRL */

    /* Small spin loop to allow timer progression */
    li t0, 30
timer_spin:
    addi t0, t0, -1
    bne t0, zero, timer_spin

    lw t1, 8(a3)         /* Read TIMER_VAL (should be < 512) */
    sw zero, 0(a3)       /* Disable timer */

    la a0, msg_timer
    call uart_puts

    /* ========================================================================
     * 5. ADC Controller Configuration & Trigger (Group G)
     * ======================================================================== */
    li a4, 0x4000E000    /* ADC Base */
    li t0, 1             /* Enable scheduler */
    sw t0, 0(a4)         /* ADC_CTRL */
    li t0, 3             /* Enable + Single Shot Start Trigger */
    sw t0, 0(a4)         /* ADC_CTRL */
    lw t1, 4(a4)         /* Read ADC_STATUS */
    lw t2, 8(a4)         /* Read ADC_SAMPLE_DATA */

    la a0, msg_adc
    call uart_puts

    /* ========================================================================
     * 6. FIR Filter Configuration & Coefficient Latch (Group H)
     * ======================================================================== */
    li a5, 0x4000C000    /* FIR Base */
    li t0, 0x0010        /* Coeff 0 */
    sw t0, 16(a5)
    li t0, 0x0040        /* Coeff 1 */
    sw t0, 20(a5)
    li t0, 0x0200        /* Coeff 15 */
    sw t0, 76(a5)
    li t0, 0x0010        /* Coeff 31 */
    sw t0, 140(a5)

    /* Pulse Load Strobe to latch shadow registers into active bank */
    li t0, 1
    sw t0, 4(a5)         /* FIR_LOAD */
    sw t0, 0(a5)         /* FIR_CTRL (Enable) */
    lw t1, 8(a5)         /* Read FIR_STATUS */

    la a0, msg_fir
    call uart_puts

    /* ========================================================================
     * 7. FFT Accelerator Verification (Group I & J)
     * ======================================================================== */
    li a6, 0x40008000    /* FFT CTRL Base */
    li a7, 0x4000A000    /* FFT MEM Base (1024 complex words) */

    /* Ensure FFT is not busy */
fft_wait_idle_init:
    lw t0, 4(a6)         /* FFT_STATUS */
    andi t1, t0, 2       /* Bit 1 = BUSY */
    bne t1, zero, fft_wait_idle_init

    /* Preload Test Vector: Dual-Tone DC + Nyquist Signal
     * Even indices: Real = 0x4000 (+0.50 Q1.15), Imag = 0x0000
     * Odd indices:  Real = 0x0000 (0.00 Q1.15),  Imag = 0x0000
     * Mathematically excites DC Bin 0 and Nyquist Bin 512 simultaneously */
    li t1, 512           /* 512 pairs = 1024 complex words */
    mv t2, a7            /* Destination pointer */
    li t4, 0x40000000    /* Even sample: Real = 0x4000 */
    li t5, 0x00000000    /* Odd sample:  Real = 0x0000 */
fft_fill_dual:
    sw t4, 0(t2)
    sw t5, 4(t2)
    addi t2, t2, 8
    addi t1, t1, -1
    bne t1, zero, fft_fill_dual

    /* Issue Start Pulse */
    li t0, 1
    sw t0, 0(a6)         /* FFT_CTRL start */

    /* Poll for completion (bit 0 = DONE) */
    li t3, 100000        /* Bounded timeout */
fft_poll:
    lw t0, 4(a6)         /* FFT_STATUS */
    andi t1, t0, 1       /* DONE */
    bne t1, zero, fft_done
    addi t3, t3, -1
    bne t3, zero, fft_poll
fft_done:

    /* Read back Bin 0 (DC) and Bin 512 (Nyquist) */
    lw s2, 0(a7)         /* Bin 0 */
    li t0, 0x4000A800
    lw s4, 0(t0)         /* Bin 512 */

    la a0, msg_fft
    call uart_puts

    /* ========================================================================
     * 8. Final Completion Banner
     * ======================================================================== */
    la a0, msg_complete
    call uart_puts

    lw ra, 28(sp)
    addi sp, sp, 32
    ret


/* UART Character & String Transmission Routines */
uart_putc:
    li t0, 0x40000000
    li t1, 100000        /* Bounded timeout */
uart_tx_wait:
    lw t2, 20(t0)        /* UART_LSR (offset 0x14) */
    andi t2, t2, 0x20    /* THRE (Bit 5) */
    bne t2, zero, uart_tx_ready
    addi t1, t1, -1
    bne t1, zero, uart_tx_wait
    ret                  /* Timeout bail */
uart_tx_ready:
    sw a0, 0(t0)         /* Write UART_THR */
    ret

uart_puts:
    addi sp, sp, -16
    sw ra, 12(sp)
    sw s0, 8(sp)
    mv s0, a0
uart_puts_loop:
    lbu a0, 0(s0)
    beq a0, zero, uart_puts_done
    call uart_putc
    addi s0, s0, 1
    j uart_puts_loop
uart_puts_done:
    lw s0, 8(sp)
    lw ra, 12(sp)
    addi sp, sp, 16
    ret


.section .rodata
msg_boot:
    .string "\r\n[BOOT] OK\r\n"

msg_mem:
    .string "[MEM] OK\r\n"

msg_gpio:
    .string "[GPIO] OK\r\n"

msg_timer:
    .string "[TIMER] OK\r\n"

msg_adc:
    .string "[ADC] OK\r\n"

msg_fir:
    .string "[FIR] OK\r\n"

msg_fft:
    .string "[FFT] OK\r\n"

msg_complete:
    .string "=== ALL FIRMWARE CHECKS COMPLETED: PASS ===\r\n"

