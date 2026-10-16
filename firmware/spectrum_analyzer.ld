/* ============================================================================
 * spectrum_analyzer.ld — Authoritative Linker Script for Spectrum Analyzer SoC
 * Target: Western Digital VeeR EL2 Core (RV32IMC / Zba, Zbb, Zbc, Zbs)
 * 
 * Verified Physical Memory Layout:
 *   IMEM (Instruction SRAM): Base 0x00000000, Size 64 KiB (0x00000000 - 0x0000FFFF)
 *   DMEM (Data SRAM)       : Base 0x00010000, Size 64 KiB (0x00010000 - 0x0001FFFF)
 * 
 * Reset Vector: 0x00000000 (Placed at start of IMEM)
 * Stack Top   : 0x0001C000 (Allocates 48 KiB for BSS/Data/Heap, 16 KiB for Stack)
 * ============================================================================ */

OUTPUT_ARCH("riscv")
ENTRY(_start)

MEMORY
{
    IMEM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
    DMEM (rwx) : ORIGIN = 0x00010000, LENGTH = 64K
}

SECTIONS
{
    /* ------------------------------------------------------------------------
     * Code and Read-Only Data in IMEM
     * ------------------------------------------------------------------------ */
    .text : {
        . = ALIGN(4);
        KEEP(*(.text.init))          /* Boot and reset vector code placed at 0x0 */
        *(.text.trap)                /* Machine-mode trap and interrupt handlers */
        *(.text .text.*)             /* Application code */
        *(.rodata .rodata.*)         /* Constants, strings, lookup tables */
        *(.srodata .srodata.*)
        . = ALIGN(4);
        _etext = .;
    } > IMEM

    /* ------------------------------------------------------------------------
     * Initialized Data (VMA in DMEM, LMA in IMEM)
     * Copied from IMEM to DMEM by start.S during reset initialization
     * ------------------------------------------------------------------------ */
    .data : {
        . = ALIGN(4);
        _sdata = .;
        __global_pointer$ = . + 0x800; /* Relaxed addressing pointer (+2048 bytes) */
        *(.data .data.*)
        *(.sdata .sdata.*)
        . = ALIGN(4);
        _edata = .;
    } > DMEM AT > IMEM
    
    _sidata = LOADADDR(.data);

    /* ------------------------------------------------------------------------
     * Uninitialized Data (.bss, zero-initialized by start.S)
     * ------------------------------------------------------------------------ */
    .bss (NOLOAD) : {
        . = ALIGN(4);
        _sbss = .;
        *(.sbss .sbss.*)
        *(.bss .bss.*)
        *(COMMON)
        . = ALIGN(4);
        _ebss = .;
    } > DMEM

    /* ------------------------------------------------------------------------
     * Stack Allocation in Upper DMEM (Stack grows downwards)
     * ------------------------------------------------------------------------ */
    .stack (NOLOAD) : {
        . = ALIGN(16);
        _stack_bottom = .;
        . = ORIGIN(DMEM) + 0xC000;   /* Allocate up to 0x0001C000 */
        _stack_top = .;
    } > DMEM

    _end = .;

    /* ------------------------------------------------------------------------
     * Discard debugging and C++ runtime unwinding artifacts
     * ------------------------------------------------------------------------ */
    /DISCARD/ : {
        *(.eh_frame)
        *(.comment)
    }
}
