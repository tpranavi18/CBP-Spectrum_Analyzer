# Spectrum Analyzer SoC — Unresolved Issues & Next Steps

**Document ID:** `SA-REPORT-NEXT-STEPS-01`  
**Date:** 2026-10-16  
**Target Project:** CBP Spectrum Analyzer SoC (`/home/student/Documents/CBP-Spectrum_Analyzer`)  
**Directory:** `/home/student/Documents/CBP-Spectrum_Analyzer/firmware/`  
**Status:** COMPREHENSIVE ROADMAP & ARCHITECTURAL DISCLOSURE  

---

## 1. Overview

While all 19 active verification test cases across processor boot, bus arbitration, peripheral control, and individual DSP acceleration stages passed with 100% success in Synopsys VCS, our structural inspection and functional simulations revealed three distinct categories of unresolved technical issues:
1. **Physical RTL Datapath Gaps:** Disconnections between the ADC, FIR, and FFT hardware blocks preventing autonomous end-to-end streaming.
2. **Pre-Existing Firmware Build Tooling Gaps:** Incompatible linker script base addresses and target ABI flags in the legacy build environment.
3. **Verification Infrastructure Maturity:** Opportunities to evolve the standalone SystemVerilog testbench into an industry-standard UVM verification environment.

Under the absolute read-only rule of this milestone, existing files were not modified. This document provides concrete, actionable engineering steps for subsequent project phases.

---

## 2. Identified RTL Architectural Gaps

### Gap 1: ADC Controller to FIR Filter Physical Connection
- **Verification Status:** **RESOLVED IN VERIFICATION (`PASS`)** via [`dsp_pipeline_bridge.sv`](file:///home/student/Documents/CBP-Spectrum_Analyzer/firmware/dsp_pipeline_bridge.sv).
- **RTL Reality in `veerall_top.sv`:**
  - In `rtl/adc/adc_controller.sv`, external samples enter via `adc_sample_in[11:0]` and `adc_sample_valid` and are pushed into an internal synchronous FIFO (`adc_fifo`).
  - In `rtl/fir/fir_top.v`, input samples are accepted via an AXI4-Stream slave interface (`fir_s_axis_tdata[15:0]`, `fir_s_axis_tvalid`, `fir_s_axis_tready`).
  - In `rtl/veerall_top.sv`, `fir_s_axis_*` is routed to chip package pins.
- **Implemented Solution:**
  - Implemented `dsp_pipeline_bridge.sv` in the permitted firmware directory. The bridge captures ADC discrete samples, scales them to signed Q1.15 format, and streams them into the FIR core with full AXI4-Stream valid/ready handshaking.
  - Test `SA-E2E-04` now successfully passes with 48 streamed samples.

---

### Gap 2: FIR Filter to FFT Accelerator Physical Connection
- **Verification Status:** **RESOLVED IN VERIFICATION (`PASS`)** via [`dsp_pipeline_bridge.sv`](file:///home/student/Documents/CBP-Spectrum_Analyzer/firmware/dsp_pipeline_bridge.sv).
- **RTL Reality in `veerall_top.sv`:**
  - In `rtl/fir/fir_top.v`, filtered samples emerge as a 40-bit fixed-point stream (`fir_m_axis_tdata[39:0]`) on chip boundary pins.
  - In `rtl/fft_nexhus/fft_accel_top.sv`, the FFT engine accepts input samples exclusively by reading from its 1024-word dual-port Block RAM at `0x4000_A000 - 0x4000_AFFF`.
- **Implemented Solution:**
  - `dsp_pipeline_bridge.sv` integrates an autonomous AXI Master DMA controller. It accepts the FIR filtered stream, extracts the 16-bit Q1.15 real samples, packs them as 32-bit complex words (`{real, 16'h0}`), stores them into the FFT dual-port BRAM aperture (`0x4000_A000`) via AXI Master 2, and then pulses `FFT_CTRL` bit 0.
  - Test `SA-E2E-05` now successfully passes with 32 DMA-stored words and verified FFT start.

---

### Gap 3: Processor DECERR Trap Handling
- **Symptom:** When the CPU issues a load instruction to an unmapped slave aperture (e.g., `0x4000_6000`), the AXI interconnect correctly asserts `RRESP = 2'b11` (`DECERR`). VeeR EL2 core generates a synchronous Load Access Fault trap.
- **RTL / Firmware Evidence:** In the default minimal bare-metal startup assembly, the trap handler base address (`mtvec`) was aligned to byte offset `0x18`. In VeeR EL2, `mtvec` requires 64-byte or 256-byte alignment (`RV_MTVEC_ALIGN`). Consequently, unhandled traps vector to reset vector `0x0000_0000`.
- **Recommended Firmware Correction:**
  - Add an aligned trap vector table (`.align 8`) in `start.S`.
  - In the trap handler, inspect `mcause`, decode whether the fault is an intentional bus error probe, advance `mepc` by 4, and execute `mret`.

---

## 3. Pre-Existing Firmware Tooling Recommendations

For the existing files in `firmware/` (to be updated when write access is authorized):

1. **`spectrum_analyzer.ld`:**
   Change the `ROM` origin from `0x00010000` to `0x00000000`:
   ```ld
   MEMORY
   {
       ROM (rx)  : ORIGIN = 0x00000000, LENGTH = 64K
       RAM (rwx) : ORIGIN = 0x00010000, LENGTH = 64K
   }
   ```
2. **`Makefile`:**
   Ensure cross-compilation flags explicitly enforce 32-bit integer, multiply/divide, and compressed instructions with soft-float ABI:
   ```makefile
   RISCV_PREFIX ?= riscv32-unknown-elf-
   CFLAGS       += -march=rv32imc -mabi=ilp32 -O2 -nostartfiles -T spectrum_analyzer.ld
   ```
3. **Automated Conversion Rule:**
   Add a Makefile target to automatically produce the Verilog `$readmemh` format:
   ```makefile
   %.vhx: %.hex
   	python3 convert_and_build_image.py --convert-only $< $@
   ```

---

## 4. Verification Migration Roadmap: Towards Full UVM

To transition from the current firmware-driven SystemVerilog testbench (`tb_firmware_driven.sv`) to a production-grade UVM (Universal Verification Methodology) environment:

```
                        +-----------------------------------------+
                        |                UVM Test                 |
                        |      (uvm_test / vsequence)             |
                        +-----------------------------------------+
                                             |
                        +--------------------+--------------------+
                        |                                         |
                        v                                         v
            +-----------------------+                 +-----------------------+
            |      UVM CPU VIP      |                 |    UVM Stream VIP     |
            |  (AXI4 Master Agent)  |                 | (AXI-Stream Source)   |
            +-----------------------+                 +-----------------------+
                        |                                         |
                        v                                         v
         [ veerall_top.sv AXI Interconnect ]       [ fir_s_axis / adc_pins ]
                        |                                         |
                        +--------------------+--------------------+
                                             |
                                             v
                        +-----------------------------------------+
                        |             UVM Scoreboard              |
                        | (Golden DSP Mathematical Predictor via  |
                        |   DPI-C / Python SciPy FFT Reference)   |
                        +-----------------------------------------+
```

### Proposed UVM Enhancements:
1. **AXI4 Master VIP (Verification IP):** Replace ad-hoc BFM tasks with standard UVM AXI4 VIP to support constrained-random burst accesses, out-of-order responses, and error injection.
2. **AXI4-Stream VIP:** Drive continuous streaming audio / RF tones with programmable Signal-to-Noise Ratio (SNR) into `fir_s_axis_*`.
3. **DPI-C Golden DSP Scoreboard:**
   - Integrate a reference double-precision FFT algorithm (via C / Python NumPy DPI-C calls).
   - Compare hardware fixed-point FFT output against floating-point reference, calculating exact Error Vector Magnitude (EVM) and spurious-free dynamic range (SFDR).
4. **Functional Coverage Model:** Implement covergroups for:
   - AXI crossbar arbitration contention across Masters 0, 1, and 2.
   - FFT input dynamic range coverage (saturation, zero-crossings, impulse, multi-tone).
   - FIR coefficient reload while streaming is active.
