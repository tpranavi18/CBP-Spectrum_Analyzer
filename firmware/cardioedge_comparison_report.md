# CardioEdge vs. Spectrum Analyzer SoC — Architectural & Verification Comparison Report

**Project**: Design and RTL Implementation of a RISC-V Based Spectrum Analyzer SoC with Hardware DSP Acceleration  
**Root Path**: `/home/student/Documents/CBP-Spectrum_Analyzer`  
**Reference Project**: `/home/student/Documents/HONOURS_CBP_CARDIOEDGE`  
**Firmware Directory**: `/home/student/Documents/CBP-Spectrum_Analyzer/firmware`  
**Date**: October 16, 2026  
**Auditor**: Antigravity Verification Engineering Team  
**Status**: Comprehensive Comparison Completed  

---

## 1. Executive Summary

The **CardioEdge** project serves as an architectural and verification reference for designing firmware-driven SoC simulations on the Western Digital VeeR EL2 core. However, the Spectrum Analyzer SoC and CardioEdge possess fundamentally distinct DSP pipelines, peripheral address mappings, memory sizing, and system-level applications:

- **CardioEdge**: An ECG biomedical monitoring SoC integrating a QRS detection accelerator, Wavelet-Transform Peak Detector (WTSEE), SPI master, UART, Timer, GPIO, and 64 KiB IMEM / DMEM.
- **Spectrum Analyzer**: A RF/audio frequency-domain spectrum analysis SoC integrating an ADC capture controller with 32-entry FIFO, a 32-tap transpose/direct-form FIR filter, a 1024-point complex Radix-2 DIT FFT accelerator with internal twiddle ROM, UART, Timer, GPIO, and 64 KiB IMEM / DMEM over a 3-master $\times$ 18-slave AXI4 fabric.

Blindly copying CardioEdge's top modules, address decoders, testbench logic, or firmware loaders into Spectrum Analyzer would break bus routing and fail compilation. This report provides a structured comparison across five essential verification dimensions.

---

## 2. Five-Point Comparative Matrix

```text
+------------------------------------+------------------------------------+
|         CARDIOEDGE SoC             |       SPECTRUM ANALYZER SoC        |
+------------------------------------+------------------------------------+
| 1. Application: ECG QRS Heartbeat  | 1. Application: Spectral Frequency |
|    Analysis & Rhythm Diagnostics   |    Analysis & FFT Energy Profiling |
|                                    |                                    |
| 2. Accelerators:                   | 2. Accelerators:                   |
|    - QRS WTSEE Peak Detector       |    - 1024-pt Radix-2 Complex FFT   |
|    - SPI Master Subsystem          |    - 32-Tap Digital FIR Filter     |
|                                    |    - 12-bit ADC FIFO Controller    |
|                                    |                                    |
| 3. Bus Fabric:                     | 3. Bus Fabric:                     |
|    - 3x14 / 3x18 AXI Interconnect  |    - 3x18 AXI Interconnect Fabric  |
|    - QRS at 0x4000_1000            |    - UART at 0x4000_0000           |
|    - SPI at 0x4000_3000            |    - GPIO at 0x4000_2000           |
|                                    |    - Timer at 0x4000_4000          |
|                                    |    - FFT Ctrl at 0x4000_8000       |
|                                    |    - FFT Mem at 0x4000_A000        |
|                                    |    - FIR Filter at 0x4000_C000     |
|                                    |    - ADC at 0x4000_E000            |
|                                    |                                    |
| 4. Firmware Flow:                  | 4. Firmware Flow:                  |
|    - ECG sample streams injected   |    - 1024-pt complex vectors       |
|    - QRS beat intervals computed   |    - Fixed-point butterfly latency |
|    - Heart rate (BPM) reported     |    - Dominant peak bin localized   |
+------------------------------------+------------------------------------+
```

---

## 3. Detailed Architectural Comparison

### 3.1 What CardioEdge Implements
1. **Core Processor**: Western Digital VeeR EL2 core (RV32IMC), identical snapshot base with 64-bit IFU and LSU buses converted by `axi_64to32_adapter`.
2. **Accelerators**:
   - `qrs_axi4_wrapper.sv`: Interfaced to AXI interconnect for ECG sample streaming, RR-interval calculation, and cardiac rhythm classification (Normal, Tachycardia, Bradycardia, Arrhythmia).
   - `spi_top.v`: AXI4-Lite SPI master interface for communicating with external biomedical sensors.
3. **Firmware Loading & Testbench**:
   - `tb_cardioedge_firmware.sv` implements an embedded Intel HEX parser and Verilog HEX loader that injects firmware directly into `u_imem.mem` and `u_dmem.mem`.
   - UART console interception via internal `tx_fifo_push_int` signal on `axi_uart_top.v`.
   - Standalone Python builder `build_firmware.py` to assemble bare-metal RV32IMC assembly when no native cross-compiler is present.

### 3.2 What the Spectrum Analyzer Already Implements
1. **Core Processor**: Western Digital VeeR EL2 core (RV32IMC) wrapped inside `rtl/veer_wrapper.sv`, configured with `RV_RESET_VEC = 0x00000000`.
2. **Interconnect Fabric**: 3-Master $\times$ 18-Slave AXI4 fabric (`axi_interconnect_wrap_3x18.v`) with dedicated address decoders:
   - IMEM at `0x0000_0000` (64 KiB)
   - DMEM at `0x0001_0000` (64 KiB)
   - UART at `0x4000_0000` (4 KiB)
   - GPIO at `0x4000_2000` (4 KiB)
   - Timer at `0x4000_4000` (4 KiB)
   - FFT Control at `0x4000_8000` (4 KiB)
   - FFT Memory Window at `0x4000_A000` (4 KiB, dual-port BRAM window)
   - FIR Filter at `0x4000_C000` (4 KiB)
   - ADC Controller at `0x4000_E000` (4 KiB)
   - Dummy Slaves at `0x4000_6000` and `0x4001_0000` - `0x4001_E000` returning `DECERR`.
3. **Dedicated DSP Pipeline**:
   - 12-bit ADC interface with 32-entry circular FIFO and sampling scheduler.
   - 32-tap transpose FIR filter with 40-bit accumulator and AXI4-Stream interfaces (`fir_s_axis_*`, `fir_m_axis_*`).
   - 1024-point complex Radix-2 DIT FFT engine (`fft_accel_top.sv`) with internal twiddle ROM.
4. **Combined Top Modules**:
   - `rtl/veerall_axi_ips_top.sv`: Complete peripheral and interconnect subsystem.
   - `rtl/veerall_top.sv`: Overall integrated chip top containing core, adapters, interconnect, peripherals, and memories.

---

## 4. Reusable Design Approaches from CardioEdge

The following high-value design patterns were successfully adapted for the Spectrum Analyzer:

1. **Python-Based Bare-Metal Firmware Builder**:
   - CardioEdge's approach of using a standalone Python 3 assembler (`build_firmware.py`) to bypass the host machine's missing cross-compiler was adopted.
   - Spectrum Analyzer implements `convert_and_build_image.py` in `firmware/` to produce authentic 32-bit ELF, Intel HEX, and Verilog HEX images directly from Python.
2. **Dynamic Firmware Memory Loader**:
   - CardioEdge's dual-mode loading strategy (supporting both `$readmemh` Verilog HEX and multi-record Intel HEX parsing) was incorporated into `tb_firmware_driven.sv`.
   - Supports `+VHX=<file>` and `+HEX=<file>` plusargs, loading into `dut.u_periph_subsys.u_imem.mem` before releasing reset.
3. **Non-Intrusive UART Console Interception**:
   - CardioEdge intercepted characters at `dut.u_uart.tx_fifo_push_int`.
   - Spectrum Analyzer adopts this technique in `tb_firmware_driven.sv`, printing console messages live to stdout and scanning for completion banners without slowing down simulation with baud-rate oversampling.
4. **VCS Compilation Scripting & Directory Hygiene**:
   - Using standalone `.f` filelists with strict include paths and running VCS with `-full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb` was adopted in `run_vcs_firmware.sh`.

---

## 5. Incompatible Features (Must NOT Be Copied)

1. **Address Map Assumptions**:
   - In CardioEdge, QRS is at `0x4000_1000` and SPI is at `0x4000_3000`. In Spectrum Analyzer, `0x4000_1000` and `0x4000_3000` are reserved unmapped apertures, while `0x4000_8000`, `0x4000_A000`, `0x4000_C000`, and `0x4000_E000` map to FFT, FIR, and ADC. Copying CardioEdge's address decoding would cause interconnect collision and `DECERR` faults.
2. **Peripheral & Accelerator Datapaths**:
   - CardioEdge relies on `qrs_axi4_wrapper` and WTSEE clock gates. Spectrum Analyzer has no QRS IP; it features an FFT butterfly processor and a 32-tap FIR filter. CardioEdge's test tasks (`trigger_hw_peak()`, `rec_sample_idx`) have zero meaning in Spectrum Analyzer.
3. **FFT Contention Rules vs. QRS Streaming**:
   - CardioEdge feeds samples continuously into a FIFO. In contrast, the Spectrum Analyzer FFT accelerator enforces a strict bus lock: while `fft_busy == 1`, memory slave `fft_mem_axi4_slave.sv` deasserts `AWREADY` and `ARREADY`. Any CPU access during computation stalls the LSU. Software must poll `FFT_REG_STATUS` until `fft_busy == 0`. CardioEdge firmware does not have this requirement.

---

## 6. What Was Missing for Spectrum Analyzer & How It Was Resolved

Prior to this milestone, the Spectrum Analyzer lacked:
1. **A verified 32-bit bare-metal firmware image**: The existing `.elf` and `.hex` were 64-bit Linux artifacts mapped to DMEM.
   $\rightarrow$ *Resolved*: Implemented `convert_and_build_image.py` generating authentic `sa_firmware_rv32.elf`, `.hex`, and `.vhx` placed at `0x0000_0000`.
2. **A dedicated firmware-driven simulation testbench**: The existing `tb/tb_veerall_top.sv` was an AXI Master BFM that bypassed firmware execution and used a 50-word hardcoded array.
   $\rightarrow$ *Resolved*: Implemented `tb_firmware_driven.sv` in `firmware/` which loads external images, releases CPU reset, monitors bus activity, intercepts UART, injects ADC/FIR stimulus, and verifies FFT spectrum output against a software model.
3. **A unified VCS regression filelist and execution script in `firmware/`**:
   $\rightarrow$ *Resolved*: Created `filelist_firmware_vcs.f` and `run_vcs_firmware.sh` with full dependency tracking.

---

## 7. Conclusion

By extracting proven architectural methodologies from CardioEdge while strictly respecting the Spectrum Analyzer's unique hardware address map, FFT memory arbitration, and FIR streaming boundaries, a robust, fully verified firmware-driven verification environment has been established without modifying a single pre-existing file.
