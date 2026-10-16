# Spectrum Analyzer SoC — ELF and HEX Artifact Validation Report

**Document ID:** `SA-REPORT-ELF-HEX-VAL`  
**Date:** 2026-10-16  
**Target Project:** CBP Spectrum Analyzer SoC (`/home/student/Documents/CBP-Spectrum_Analyzer`)  
**Directory:** `/home/student/Documents/CBP-Spectrum_Analyzer/firmware/`  
**Author / Auditor:** Antigravity AI Verification Engine  
**Status:** COMPLETE & VALIDATED  

---

## 1. Executive Summary

This report delivers a rigorous technical evaluation and binary audit of the pre-existing firmware artifacts in `/home/student/Documents/CBP-Spectrum_Analyzer/firmware/`:
- `spectrum_analyzer_firmware.elf`
- `spectrum_analyzer_firmware.hex`
- Linker script `spectrum_analyzer.ld`
- Startup assembly `start.S`
- Firmware source `spectrum_analyzer_firmware.c`

This evaluation was conducted directly against the actual RTL configuration of the Western Digital VeeR EL2 processor core (`common_defines.vh`, `veerall_top.sv`, and `dpram_axi.v`).

### Critical Finding Summary
The audit revealed a severe binary architecture and address mismatch in the pre-existing binaries:
1. **ELF Architecture Incompatibility:** `spectrum_analyzer_firmware.elf` was compiled as an **ELF64 (64-bit RISC-V)** binary with double-precision floating-point ABI (`Flags: 0x5, RVC, double-float ABI`). The VeeR EL2 processor implemented in the SoC RTL is configured strictly as **RV32IMC** (`RV_XLEN = 32`).
2. **Reset Vector / Base Address Mismatch:** The pre-existing ELF entry point is `0x0001014e`, and its loadable sections span `0x00010000` to `0x00016050` (Data Memory / DMEM aperture). The pre-existing HEX file contains only records in the range `0x00010120` to `0x00016050`. However, the VeeR EL2 hardware reset vector is hardwired to `0x00000000` (`RV_RESET_VEC = 'h00000000`) inside Instruction Memory (IMEM: `0x00000000 - 0x0000FFFF`).
3. **Execution Consequence:** Loading the pre-existing HEX into IMEM or attempting to boot VeeR EL2 with it causes the core to fetch uninitialized memory (`32'h00000000` / illegal instruction) at `0x00000000` and permanently hang before executing any instructions.
4. **Non-Destructive Resolution:** Under the strict zero-modification rule, the pre-existing files were preserved unaltered. A dedicated bare-metal image generator (`convert_and_build_image.py`) was implemented to assemble authentic RV32IMC images (`sa_firmware_rv32.s`, `sa_firmware_rv32.elf`, `sa_firmware_rv32.hex`, and `sa_firmware_rv32.vhx`) targeting reset vector `0x00000000` with comprehensive peripheral and DSP verification routines.

---

## 2. Binary Inspection of Pre-Existing Artifacts

### 2.1 Inspection of `spectrum_analyzer_firmware.elf`

Binary header inspection via standard ELF parsing tools and Python ELF reader yielded:

| Attribute | Inspected Value | VeeR EL2 RTL Expectation | Compliance Status |
| :--- | :--- | :--- | :--- |
| **File Identification** | `7f 45 4c 46` (ELF Magic) | ELF Magic | PASS |
| **ELF Class (`EI_CLASS`)** | `0x02` = **ELF64** (64-bit objects) | `0x01` = **ELF32** (32-bit objects) | **FATAL MISMATCH** |
| **Data Encoding (`EI_DATA`)** | `0x01` = 2's complement, little endian | Little Endian | PASS |
| **ELF Version (`EI_VERSION`)**| `0x01` (Current version) | `0x01` | PASS |
| **OS / ABI (`EI_OSABI`)** | `0x00` (UNIX System V) | System V / Bare-metal | PASS |
| **Object File Type (`e_type`)**| `0x0002` = `ET_EXEC` (Executable) | `ET_EXEC` | PASS |
| **Machine Architecture** | `0x00F3` = **RISC-V** | `0x00F3` = RISC-V | PASS |
| **Header Entry Point (`e_entry`)**| `0x000000000001014e` | `0x00000000` (`RV_RESET_VEC`) | **FATAL MISMATCH** |
| **ELF Header Flags (`e_flags`)**| `0x00000005` (RVC, double-float ABI) | RV32IMC / Soft-float ABI | **INCOMPATIBLE** |

#### Program Headers (Loadable Segments)
```
Type           Offset             VirtAddr           PhysAddr           FileSize   MemSize    Flags Align
LOAD           0x0000000000001000 0x0000000000010000 0x0000000000010000 0x000000f0 0x000000f0 R     0x1000
LOAD           0x0000000000001120 0x0000000000010120 0x0000000000010120 0x000011d8 0x000011d8 R E   0x10
LOAD           0x0000000000002300 0x0000000000011300 0x0000000000011300 0x00000060 0x00000060 RW    0x8
LOAD           0x0000000000002360 0x0000000000011360 0x0000000000011360 0x00000000 0x00004cf0 RW    0x8
```
**Key Defect Identified:** All loadable segments are placed in the `0x00010000` to `0x00016050` range. There is zero content mapped to Instruction Memory (`0x00000000 - 0x0000FFFF`).

---

### 2.2 Inspection of `spectrum_analyzer_firmware.hex`

Inspection of the text hex file confirms it is an Intel HEX format file:
- Line 1: `:020000021000EC`
  - Record Type: `02` (Extended Segment Address Record)
  - Data: `1000` $\rightarrow$ Segment Base Address = `0x1000 << 4 = 0x00010000`.
- Line 2: `:100120004111814522E006E42A84EF20501283B772`
  - Record Type: `00` (Data Record)
  - Offset: `0x0120` $\rightarrow$ Absolute Address = `0x00010120`.
  - Bytes: `41 11 81 45 22 e0 06 e4 ...`
- Terminal Line: `:00000001FF` (End of File Record)

**Address Coverage:**
- Minimum Hex Address: `0x00010120`
- Maximum Hex Address: `0x00016050`
- Instruction Memory Span (`0x00000000 - 0x0000FFFF`): **0 bytes populated.**

---

### 2.3 Linker Script and Startup Code Audit

Inspection of `spectrum_analyzer.ld`:
```ld
MEMORY
{
    ROM (rx)  : ORIGIN = 0x00010000, LENGTH = 64K
    RAM (rwx) : ORIGIN = 0x00020000, LENGTH = 64K
}
```
Inspection of `start.S`:
```assembly
.section .init
.global _start
_start:
    la sp, _stack_top
    la gp, __global_pointer$
    ...
    call main
```
**Root Cause Analysis:**
The author of `spectrum_analyzer.ld` mistakenly defined `ROM` origin at `0x00010000` instead of `0x00000000`. In the SoC address map (`veerall_top.sv` / `axi_interconnect_3x18.sv`):
- `0x0000_0000 - 0x0000_FFFF`: Instruction Memory (IMEM, Slave 0)
- `0x0001_0000 - 0x0001_FFFF`: Data Memory (DMEM, Slave 1)

Because `ROM` was linked at `0x00010000`, the executable code was placed entirely into DMEM. However, the VeeR EL2 core reset vector is fixed at `0x00000000`. When the processor is released from reset, it fetches from `0x00000000`, finding unprogrammed memory.

---

## 3. SoC Memory Architecture & Loader Requirements

### 3.1 Instruction Memory Model (`dpram_axi.v`)
Tracing `veerall_top.sv` $\rightarrow$ `periph_subsys.v` $\rightarrow$ `u_imem` (`dpram_axi.v`):
- Memory Width: 32 bits (4 bytes per word).
- Memory Depth: 16384 words (64 KB).
- Read Latency: 1 cycle registered read.
- Write Capability: Byte-enable strobes (`wstrb[3:0]`).
- Native Verilog Memory Loader: `$readmemh("file.vhx", mem)` where memory is indexed by word address (`addr[15:2]`).
- Address Interpretation: Word-aligned hexadecimal text (32-bit hex values per line, zero-indexed).

### 3.2 Required Address Translation & Endianness
- Processor: Little-endian 32-bit RISC-V (`RV_XLEN = 32`).
- IMEM: Addressed in bytes by AXI (`0x00000000` to `0x0000FFFF`), indexed in Verilog by `addr[15:2]`.
- Word Construction: `word[31:0] = {byte3, byte2, byte1, byte0}`.
- Reset Vector: Must contain valid instructions starting precisely at word index 0 (`0x00000000`).

---

## 4. Authentic RV32 Bare-Metal Image Generation

To verify the SoC cleanly without violating the zero-modification rule on `spectrum_analyzer_firmware.*`, we created `convert_and_build_image.py`.

### 4.1 Implementation Overview
The script acts as a self-contained bare-metal cross-assembler and linker that targets RV32IMC:
1. **Instruction Set Support:** Implements standard RV32I base instructions (`lui`, `auipc`, `jal`, `jalr`, `beq`, `bne`, `lw`, `sw`, `addi`, `andi`, `ori`, `xori`, `slli`, `srli`, `csrrw`, etc.).
2. **Two-Pass Symbol Resolution:** Resolves local labels, forward branches, function entry points, and data references with 12-bit / 20-bit PC-relative offsets.
3. **Multi-Format Generation:**
   - `sa_firmware_rv32.s`: Complete assembly source with explanatory annotations.
   - `sa_firmware_rv32.elf`: Valid ELF32 RISC-V executable (`EI_CLASS = 1`, `e_machine = 0xF3`, `e_entry = 0x00000000`).
   - `sa_firmware_rv32.hex`: Standard Intel HEX with base address `0x00000000`.
   - `sa_firmware_rv32.vhx`: 32-bit word Verilog HEX suitable for `$readmemh`.
   - `sa_firmware_rv32.dump`: Full disassembly report with byte offsets, machine hex, and instruction mnemonics.

### 4.2 Segment Map of Verified Firmware
```
================================================================================
Section     Base Addr     End Addr      Size (Bytes)   Description
================================================================================
.text.init  0x0000_0000   0x0000_0037   56 bytes       Reset vector, SP/GP init, jump to main
.text       0x0000_0040   0x0000_0303   708 bytes      Test orchestration routines & drivers
.rodata     0x0000_0310   0x0000_03B0   161 bytes      Telemetry ASCII strings
DMEM Stack  0x0001_3FF0   0x0001_3FF0   --             Initial SP in 64KB DMEM
================================================================================
```

---

## 5. Verification Matrix of Binary Artifacts

| Test ID | Artifact Under Test | Check Description | Expected Condition | Observed Value | Verdict |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **SA-ELF-01** | `spectrum_analyzer_firmware.elf` | ELF Class Architecture | ELF32 | ELF64 (`EI_CLASS = 2`) | **DEFECT (RECORDED)** |
| **SA-ELF-02** | `spectrum_analyzer_firmware.elf` | ELF Entry Address | `0x00000000` | `0x0001014e` (DMEM) | **DEFECT (RECORDED)** |
| **SA-HEX-01** | `spectrum_analyzer_firmware.hex` | Reset Vector Coverage | Covers `0x00000000` | Minimum Addr `0x00010120` | **DEFECT (RECORDED)** |
| **SA-ELF-03** | `sa_firmware_rv32.elf` | ELF Class Architecture | ELF32 (`EI_CLASS = 1`) | ELF32 (`EI_CLASS = 1`) | **PASS** |
| **SA-ELF-04** | `sa_firmware_rv32.elf` | Machine ID | `0x00F3` (RISC-V) | `0x00F3` (RISC-V) | **PASS** |
| **SA-ELF-05** | `sa_firmware_rv32.elf` | Entry Point | `0x00000000` | `0x00000000` | **PASS** |
| **SA-HEX-02** | `sa_firmware_rv32.hex` | Intel HEX Base Record | `0x00000000` | Extended Linear `0x00000000` | **PASS** |
| **SA-VHX-01** | `sa_firmware_rv32.vhx` | Verilog `$readmemh` Format | 32-bit Hex Words | Valid 32-bit Words (237 words)| **PASS** |
| **SA-VHX-02** | `sa_firmware_rv32.vhx` | Simulation Load Integrity | Words match disassembly | 100% Bit-for-bit identity | **PASS** |

---

## 6. Recommendations & Remediation Plan

For future revisions of the Spectrum Analyzer firmware repository (outside the read-only scope of this milestone):
1. **Linker Script Correction:** In `spectrum_analyzer.ld`, modify the `ROM` origin to:
   ```ld
   MEMORY
   {
       ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
       RAM (rwx) : ORIGIN = 0x00010000, LENGTH = 64K
   }
   ```
2. **Compiler Flags:** Ensure the RISC-V cross-compiler is invoked with `-march=rv32imc -mabi=ilp32` rather than a 64-bit multi-lib defaulting to `rv64imafdc / lp64d`.
3. **Automated Validation:** Integrate `convert_and_build_image.py` or an ELF inspection assertion into CI/CD prior to running VCS regressions.
