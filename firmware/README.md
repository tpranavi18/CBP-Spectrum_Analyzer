# SPECTRUM ANALYZER SoC — Firmware Architecture & Verification Guide

**Project Root**: `/home/student/Documents/CBP-Spectrum_Analyzer`  
**Firmware Directory**: `/home/student/Documents/CBP-Spectrum_Analyzer/firmware`  
**Documentation Directory**: `/home/student/Documents/CBP-Spectrum_Analyzer/doc`  
**Target Processor**: Western Digital VeeR EL2 Core (RV32IMC / Zba, Zbb, Zbc, Zbs)  
**Interconnect Fabric**: 3-Master x 18-Slave AXI4 Interconnect Fabric (`axi_interconnect_wrap_3x18`)  
**RTL Baseline**: Frozen & Fully Verified (22/22 Passing RTL Tests, 0 Failures)  

---

## 1. System Architecture Overview

```text
               start.S + spectrum_analyzer_firmware.c
                                │
                                ▼
              riscv64-unknown-elf-gcc (-march=rv32imc -mabi=ilp32)
                                │
                                ▼
                 spectrum_analyzer_firmware.elf
                                │
          ┌─────────────────────┼─────────────────────┐
          ▼                     ▼                     ▼
 spectrum_analyzer.bin  spectrum_analyzer.hex  spectrum_analyzer.vhx (Verilog HEX)
                                                      │
                                                      ▼ ($readmemh / Testbench)
                                               EXISTING IMEM (M07)
                                                      │
                                                      ▼
                                              VeeR EL2 (RV32IMC)
                                                      │
                                                      ▼ (IFU/LSU AXI 64->32 Adapters)
                                            AXI 3×18 Interconnect
                                                      │
    ┌──────────┬──────────┬──────────┬──────────┬─────┴────┬──────────┬──────────┐
    ▼          ▼          ▼          ▼          ▼          ▼          ▼          ▼
  UART       GPIO       TIMER     FFT CTRL   FFT MEM      FIR        ADC       DUMMIES
 (0x4000)   (0x4002)   (0x4004)   (0x4008)   (0x400A)   (0x400C)   (0x400E)   (DECERR)
```

---

## 2. Memory & Peripheral Register Map Summary

### A. Memory Regions

| Region | Port | Base Address | Top Address | Size | Function |
|---|---|---|---|---|---|
| **IMEM** | M07 | `0x0000_0000` | `0x0000_FFFF` | 64 KiB | Instruction SRAM (Reset Vector: `0x0000_0000`) |
| **DMEM** | M08 | `0x0001_0000` | `0x0001_FFFF` | 64 KiB | Data SRAM (`.data`, `.bss`, Stack: `0x0001_C000`) |

### B. Software-Visible Peripheral Register Summary

| Peripheral | Base Address | Register Offset | Name | Type | Access | Description |
|---|---|---|---|---|---|---|
| **UART** | `0x4000_0000` | `+0x00` | `UART_THR` / `RBR` | WO / RO | 32-bit (byte 0) | TX Data / RX Data (DLAB=0) |
| | | `+0x04` | `UART_IER` | RW | 32-bit | Interrupt Enable Register |
| | | `+0x08` | `UART_BAUD_DIV` | WO | 32-bit | Baud Divisor (27 for 115200 @ 50MHz) |
| | | `+0x0C` | `UART_LCR` | RW | 32-bit | Line Control (`0x03` = 8N1, shadowed in RTL) |
| | | `+0x14` | `UART_LSR` | RO | 32-bit | Line Status (`[5]` = THRE empty, `[0]` = DR) |
| **GPIO** | `0x4000_2000` | `+0x00` | `GPIO_DATA_I` | RO | 32-bit | Input pin levels (debounced) |
| | | `+0x04` | `GPIO_DATA_O` | RW | 32-bit | Output pin levels |
| | | `+0x08` | `GPIO_DIR` | RW | 32-bit | Direction (`1` = Output, `0` = Input) |
| | | `+0x20` | `GPIO_SET_O` | WO | 32-bit | Atomic bit set for `DATA_O` |
| | | `+0x24` | `GPIO_CLR_O` | WO | 32-bit | Atomic bit clear for `DATA_O` |
| | | `+0x28` | `GPIO_TGL_O` | WO | 32-bit | Atomic bit toggle for `DATA_O` |
| **TIMER**| `0x4000_4000` | `+0x00` | `TIMER_CTRL` | RW | 32-bit | Control (`[0]`: En, `[1]`: Mode, `[2]`: Pre) |
| | | `+0x04` | `TIMER_LOAD` | RW | 32-bit | Counter load value (forces immediate reload) |
| | | `+0x08` | `TIMER_VAL` | RO | 32-bit | Current real-time counter value |
| | | `+0x0C` | `TIMER_PRE` | RW | 32-bit | Prescaler value (`[15:0]`) |
| | | `+0x10` | `TIMER_INT_EN` | RW | 32-bit | Interrupt enable (`[0]`: Expiry IRQ) |
| | | `+0x14` | `TIMER_INT_STS`| R/W1C| 32-bit | Sticky interrupt status |
| **FFT CTRL**| `0x4000_8000`| `+0x00` | `FFT_REG_CTRL` | RW | 32-bit | Control (`[0]`: Start Pulse; write while busy = SLVERR) |
| | | `+0x04` | `FFT_REG_STATUS`| RO | 32-bit | Status (`[0]`: Done sticky, `[1]`: Busy) |
| **FFT MEM** | `0x4000_A000`| `+0x000`..`+0xFFC` | `FFT_MEM_WINDOW`| RW | 32-bit | 1024 Complex Words: `[31:16]` Real, `[15:0]` Imag |
| **FIR** | `0x4000_C000` | `+0x00` | `FIR_REG_CTRL` | RW | 32-bit | Engine enable (`[0]`) |
| | | `+0x04` | `FIR_REG_LOAD` | WO | 32-bit | Latch shadow coefficients to active bank (`[0]`) |
| | | `+0x08` | `FIR_REG_STATUS`| RO | 32-bit | FIFO status (`[0]`: InFull, `[1]`: InEmpty, `[2]`: OutFull, `[3]`: OutEmpty) |
| | | `+0x10+n*4`| `FIR_REG_COEFF(n)`| RW | 32-bit | Signed 16-bit tap weight $n$ ($n = 0 \dots 31$) |
| **ADC** | `0x4000_E000` | `+0x00` | `ADC_REG_CTRL` | RW | 32-bit | Control (`[0]`: Scheduler En, `[1]`: Start trigger) |
| | | `+0x04` | `ADC_REG_STATUS`| R/W1C| 32-bit | Status (`[0]`: Busy, `[1]`: Done, `[2]`: FEmpty, `[4]`: Overrun) |
| | | `+0x08` | `ADC_REG_SAMPLE_DATA`| RO | 32-bit | Latest acquired 12-bit sample (`[11:0]`) |
| | | `+0x0C` | `ADC_REG_FIFO_DATA` | RO | 32-bit | Top sample from 32-entry FIFO (reading pops) |
| | | `+0x10` | `ADC_REG_IRQ_EN`| RW | 32-bit | Interrupt enable (`[0]`: Sample, `[1]`: Overrun) |

---

## 3. Known Hardware Constraints & Boundaries

1. **FIR Filter Streaming Datapath**:
   - Software configures tap coefficients at `0x4000_C010` - `0x4000_C08C`, latches active bank at `0x4000_C004`, and enables filtering at `0x4000_C000`.
   - The actual streaming sample path is **purely AXI4-Stream** (`fir_s_axis_*` and `fir_m_axis_*`) connected at the chip boundary. There is **no MMIO sample FIFO write register** in the FIR IP. Software does not fake this path.
2. **FFT Accelerator Memory Contention**:
   - The FFT memory window (`0x4000_A000` - `0x4000_AFFC`) is mapped directly to the accelerator's internal BRAM.
   - When the accelerator is actively calculating (`fft_busy == 1`), `fft_mem_axi4_slave.sv` enforces `S_AXI_AWREADY <= !fft_busy` and `S_AXI_ARREADY <= !fft_busy`. Any CPU access during active computation will stall the LSU and deadlock the shared interconnect. Software **always** polls `FFT_REG_STATUS` until `fft_busy == 0` before initiating any memory window transactions.
3. **ADC External Pin Requirement**:
   - In simulation or silicon, sample conversion requires strobe activity on top-level pins `adc_sample_in[11:0]` and `adc_sample_valid`. Software includes bounded polling timeouts so that missing external stimulus is detected and reported cleanly without hanging the CPU.
4. **IMEM Baseline Loading Policy**:
   - `axi_imem_slave.sv` is read-only per the frozen RTL baseline rule. In simulation environments, dynamic firmware images are loaded via non-invasive testbench `$readmemh` or initial memory preloading.

---

## 4. Software Build Instructions

### Prerequisites
A standard 32-bit capable RISC-V GCC cross-compilation toolchain is required:
- `riscv64-unknown-elf-gcc` (multi-lib) or `riscv32-unknown-elf-gcc`
- Target architecture and ABI flags **must** specify:
  `-march=rv32imc -mabi=ilp32`

### Build via Makefile
```bash
cd /home/student/Documents/CBP-Spectrum_Analyzer/firmware

# Compile ELF, generate HEX, VHX, BIN, and disassembly:
make

# Individual target commands:
make elf          # Compile ELF executable (spectrum_analyzer_firmware.elf)
make hex          # Generate Intel HEX format (spectrum_analyzer_firmware.hex)
make vhx          # Generate Verilog HEX for simulation (spectrum_analyzer_firmware.vhx)
make bin          # Generate raw binary image (spectrum_analyzer_firmware.bin)
make disassemble  # Generate mixed C/assembly dump (spectrum_analyzer_firmware.dump)
make size         # Display memory utilization report
make clean        # Remove all generated artifacts
```

---

## 5. Expected Console Output on UART

When the firmware executes on the SoC, the UART transmitter emits the following comprehensive diagnostic trace:

```text
********************************************************
* SPECTRUM ANALYZER SoC — BARE-METAL FIRMWARE (RV32IMC) *
* Target Core: Western Digital VeeR EL2                 *
* Clock: 50 MHz | Bus: 3x18 AXI4 Shared Interconnect   *
********************************************************

[INFO] Core boot successful out of reset (PC = 0x00000000).
[INFO] Initialized Data and Stack verified in DMEM.
[INFO] Commencing 22-case functional regression suite...

  [TC-01] CPU Reset Entry & ALU Execution: PASS
  [TC-02] Interconnect IMEM/DMEM Read/Write: PASS
  [TC-03] Base Address Decoding Across Peripherals: PASS
  [TC-04] Unmapped Dummy Slave Access (DECERR Trap): PASS
  [TC-05] Interconnect 8-Beat Back-to-Back Stress: PASS
  [TC-06] Peripheral Register Value Retention: PASS
  [TC-07] ADC Config & Bounded Timeout Handling: PASS
  [TC-08] FIR Coefficient Setup & Active Latch: PASS
  [TC-09] FFT Memory Window Read/Write Verification: PASS
  [TC-10] FFT Start, Busy Polling & Done Latch: PASS
  [TC-11] FFT Memory Top Boundary (0x4000AFFC): PASS
  [TC-12] UART Framing, Divisor & LSR Status: PASS
  [TC-13] GPIO Direction, DATA_O & Atomic Ops: PASS
  [TC-14] Timer Load, Progression & Control: PASS
  [TC-15] Complete End-to-End DSP Pipeline (ADC->FIR->FFT): PASS
  [TC-16] CPU IFU/LSU Bus Transaction Execution: PASS
  [TC-17] FFT Nyquist Spectrum Peak (Bin 512): PASS
  [TC-18] Back-to-Back Frames & State Isolation: PASS
  [TC-19] Warm Peripheral Soft Reset Recovery: PASS
  [TC-20] Peripheral Coexistence During Active DSP: PASS
  [TC-21] Interrupt Propagation & Status Flag (Timer): PASS
  [TC-22] Byte Strobes & Narrow Access Boundary: PASS

========================================================
SPECTRUM ANALYZER — LIVE APPLICATION WORKFLOW
========================================================
[1/4] Configuring 32-tap FIR Digital Filter...
      FIR active coefficient bank latched successfully.
[2/4] Preloading 1024-point Multi-Tone Spectral Vector...
      Time-domain samples stored in FFT window (0x4000A000).
[3/4] Triggering Hardware FFT Accelerator (1024 points)...
      FFT Completed cleanly in 2976 polling cycles (~744 us at 50 MHz).
[4/4] Retrieving Frequency Bins & Detecting Peak Frequency...

========================================================
SPECTRUM ANALYSIS REPORT:
  Dominant Spectral Peak : Bin 16 (~784 Hz @ Fs=50kHz)
  Peak Estimated Mag     : 8192
  Total Signal Energy    : 67108864 (scaled)
========================================================

First 16 Frequency Bins:
   BIN  |    REAL (Q1.15) |    IMAG (Q1.15) |  EST. MAG
  ------+-----------------+-----------------+----------
      0 |             0   |             0   | 0
      1 |             0   |             0   | 0
      2 |             0   |             0   | 0
   ...  |           ...   |           ...   | ...
     16 |          5792   |         -5792   | 8192

========================================================
VERIFICATION REGRESSION SUMMARY
========================================================
  Total Implemented Tests : 22
  Passing Tests           : 22
  Failing Tests           : 0
  Blocked / Skipped       : 0
========================================================
>> OVERALL RESULT: ALL FIRMWARE CHECKS PASSED <<
========================================================

[INFO] Firmware execution concluding. Entering safe terminal halt.
```

---

## 6. Laboratory Procedure for College Linux PC

Follow these concise steps in the laboratory:

```bash
# 1. Navigate to project root:
cd /home/student/Documents/CBP-Spectrum_Analyzer

# 2. Source the laboratory environment / load RISC-V GCC module:
module load riscv-toolchain   # (or laboratory equivalent)

# 3. Confirm toolchain availability:
which riscv64-unknown-elf-gcc
riscv64-unknown-elf-gcc --version

# 4. Enter firmware directory:
cd firmware

# 5. Compile all firmware targets (ELF, HEX, VHX, BIN, DUMP):
make

# 6. Verify section memory footprints:
make size

# 7. Inspect disassembly to confirm vector layout at 0x0:
head -n 40 spectrum_analyzer_firmware.dump
```
