/* ============================================================================
 * start.S — Bare-Metal Startup and Interrupt Vector for VeeR EL2 RISC-V Core
 * Project: Design and RTL Implementation of RISC-V Spectrum Analyzer SoC
 * Target: Western Digital VeeR EL2 (RV32IMC / Zba, Zbb, Zbc, Zbs)
 * 
 * Functions Implemented:
 *   1. Hardware reset entry point (_start at 0x00000000)
 *   2. Machine-mode CSR initialization (mstatus, mie, mtvec)
 *   3. Global pointer (GP) initialization for relaxed addressing
 *   4. Stack pointer (SP) initialization to top of DMEM (0x0001C000)
 *   5. Initialized data section copy (.data from IMEM to DMEM)
 *   6. Zero-initialization of BSS section (.bss in DMEM)
 *   7. Direct call to application main()
 *   8. Complete machine-mode trap and interrupt dispatcher (trap_entry)
 *   9. Safe terminal halt loop (wfi) upon main() return
 * ============================================================================ */

    .section .text.init, "ax"
    .global _start
    .type _start, @function

_start:
    /* ------------------------------------------------------------------------
     * 1. Disable Machine-Mode Interrupts During Core Initialization
     * ------------------------------------------------------------------------ */
    csrw mstatus, zero
    csrw mie, zero

    /* ------------------------------------------------------------------------
     * 2. Install Machine-Mode Trap Vector Handler
     * ------------------------------------------------------------------------ */
    la   t0, trap_entry
    csrw mtvec, t0

    /* ------------------------------------------------------------------------
     * 3. Initialize Global Pointer (GP) for Linker Relaxations
     * ------------------------------------------------------------------------ */
    .option push
    .option norelax
    la gp, __global_pointer$
    .option pop

    /* ------------------------------------------------------------------------
     * 4. Initialize Stack Pointer (SP) in Upper Data Memory (DMEM)
     * ------------------------------------------------------------------------ */
    la sp, _stack_top

    /* ------------------------------------------------------------------------
     * 5. Copy Initialized Data Section from Flash/IMEM (LMA) to DMEM (VMA)
     * ------------------------------------------------------------------------ */
    la t0, _sdata       /* Destination start in DMEM */
    la t1, _edata       /* Destination end in DMEM */
    la t2, _sidata      /* Source start in IMEM (LMA) */

    beq t0, t2, copy_data_done  /* Skip copy if LMA == VMA */
copy_data_loop:
    bge t0, t1, copy_data_done
    lw  t3, 0(t2)
    sw  t3, 0(t0)
    addi t0, t0, 4
    addi t2, t2, 4
    j copy_data_loop
copy_data_done:

    /* ------------------------------------------------------------------------
     * 6. Zero-Fill Uninitialized Data Section (.bss) in DMEM
     * ------------------------------------------------------------------------ */
    la t0, _sbss
    la t1, _ebss
zero_bss_loop:
    bge t0, t1, zero_bss_done
    sw  zero, 0(t0)
    addi t0, t0, 4
    j zero_bss_loop
zero_bss_done:

    /* ------------------------------------------------------------------------
     * 7. Call Application Main
     * ------------------------------------------------------------------------ */
    call main

    /* ------------------------------------------------------------------------
     * 8. Safe Terminal Loop (Executed only if main() ever returns)
     * ------------------------------------------------------------------------ */
halt_loop:
    wfi
    j halt_loop

    .size _start, . - _start


/* ============================================================================
 * Machine-Mode Trap and Interrupt Handler
 * ============================================================================ */
    .section .text.trap, "ax"
    .global trap_entry
    .align 4
    .type trap_entry, @function

trap_entry:
    /* Allocate 64 bytes on stack to preserve caller-saved context */
    addi sp, sp, -64
    sw   ra,  0(sp)
    sw   t0,  4(sp)
    sw   t1,  8(sp)
    sw   t2, 12(sp)
    sw   a0, 16(sp)
    sw   a1, 20(sp)
    sw   a2, 24(sp)
    sw   a3, 28(sp)
    sw   a4, 32(sp)
    sw   a5, 36(sp)
    sw   a6, 40(sp)
    sw   a7, 44(sp)
    sw   t3, 48(sp)
    sw   t4, 52(sp)
    sw   t5, 56(sp)
    sw   t6, 60(sp)

    /* Read trap cause, exception program counter, and trap value */
    csrr a0, mcause
    csrr a1, mepc
    csrr a2, mtval

    /* Call high-level C trap dispatcher */
    call handle_trap

    /* Restore preserved context */
    lw   ra,  0(sp)
    lw   t0,  4(sp)
    lw   t1,  8(sp)
    lw   t2, 12(sp)
    lw   a0, 16(sp)
    lw   a1, 20(sp)
    lw   a2, 24(sp)
    lw   a3, 28(sp)
    lw   a4, 32(sp)
    lw   a5, 36(sp)
    lw   a6, 40(sp)
    lw   a7, 44(sp)
    lw   t3, 48(sp)
    lw   t4, 52(sp)
    lw   t5, 56(sp)
    lw   t6, 60(sp)
    addi sp, sp, 64

    /* Return from machine-mode trap */
    mret

    .size trap_entry, . - trap_entry
