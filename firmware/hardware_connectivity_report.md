# Spectrum Analyzer SoC — Architectural Connectivity & Memory Map Report

**Document ID:** `SA-REPORT-HW-CONN-01`  
**Date:** 2026-10-16  
**Target Project:** CBP Spectrum Analyzer SoC (`/home/student/Documents/CBP-Spectrum_Analyzer`)  
**Directory:** `/home/student/Documents/CBP-Spectrum_Analyzer/firmware/`  
**Status:** COMPLETE & VERIFIED AGAINST RTL  

---

## 1. Architectural Overview & Datapath Realities

The Spectrum Analyzer SoC integrates a Western Digital VeeR EL2 RISC-V processor core with a 3-Master by 18-Slave AXI4 Interconnect and several dedicated peripheral and DSP IP blocks.

The theoretical high-level functional path intended for a digital spectrum analyzer is:
$$\text{Analog Input} \longrightarrow \text{ADC Controller} \longrightarrow \text{FIR Low-Pass Filter} \longrightarrow \text{FFT Accelerator} \longrightarrow \text{CPU Interpretation / UART Telemetry}$$

An exhaustive, signal-by-signal trace of the actual top-level RTL (`veerall_top.sv`), peripheral subsystem (`periph_subsys.v`), and individual IP source files was conducted. The physical reality of the RTL implementation is documented below.

```
                           +-------------------------------------------------------+
                           |                     veerall_top.sv                    |
                           |                                                       |
[External ADC Pins] ------>| adc_sample_in[11:0]                                   |
                           | adc_sample_valid ---> [ ADC Controller ]              |
                           |                              | (FIFO)                 |
                           |                              v                        |
                           |                     AXI-Lite MMIO (0x4000_E000)       |
                           |                              |                        |
                           |      +-----------------------+                        |
                           |      | (Requires SW copy / Missing HW Stream Bridge)  |
                           |      v                                                |
[External FIR Pins] ------>| fir_s_axis_tdata[15:0]                                |
                           | fir_s_axis_tvalid ---> [ FIR Filter IP ]              |
                           | fir_s_axis_tready <--- (32-Tap Direct MAC)            |
                           |                              |                        |
                           |                              v                        |
[External FIR Out]  <------| fir_m_axis_tdata[39:0] <-----+                        |
                           | fir_m_axis_tvalid <----------+                        |
                           | fir_m_axis_tready ---------->+                        |
                           |                                                       |
                           |      +------------------------------------------------+
                           |      | (Missing HW Stream-to-BRAM DMA / SW copy)      |
                           |      v                                                |
                           | [ Dual-Port BRAM ] <---> [ FFT NexHus 1024-pt Engine ]|
                           |   (0x4000_A000)                   |                   |
                           |         ^                         | (DONE, BUSY)      |
                           |         |                         v                   |
                           |         +================== [ FFT CTRL ]              |
                           |                               (0x4000_8000)           |
                           |                                                       |
                           |   [ 3x18 AXI Interconnect ] <==================+      |
                           |        ^               ^                       |      |
                           |        |               |                       |      |
                           |   [IFU Port]      [LSU Port]              [UART / MMIO|
                           |        |               |                  Peripherals]|
                           |   +-------------------------+                         |
                           |   |   VeeR EL2 RV32IMC Core |                         |
                           |   +-------------------------+                         |
                           +-------------------------------------------------------+
```

---

## 2. Signal-by-Signal Datapath Stage Analysis

### Stage 1: ADC Controller Subsystem
- **Source File:** `rtl/adc_controller/adc_controller.sv`
- **External Pins:**
  - `adc_sample_in[11:0]`: 12-bit unsigned/offset-binary raw sample input.
  - `adc_sample_valid`: Push strobe indicating valid external sample.
  - `adc_clk_out`, `adc_cs_n`: Clock and chip-select telemetry signals.
- **Internal Storage:** Samples are pushed into an internal synchronous FIFO (`adc_fifo`).
- **Interconnect Interface:** AXI4-Lite Slave mapped to `0x4000_E000 - 0x4000_EFFF` (Slave 4).
  - Register `0x4000_E000` (`ADC_CTRL`): Bit 0 = Enable, Bit 1 = Single-shot start trigger.
  - Register `0x4000_E004` (`ADC_STATUS`): Bit 0 = Busy, Bit 1 = FIFO Data Ready, Bit 2 = FIFO Overflow.
  - Register `0x4000_E008` (`ADC_SAMPLE_DATA`): 12-bit popped sample readback (`[11:0]`).
- **Disconnection Finding:** The ADC controller does **not** feature an AXI-Stream master or hardware streaming link to the FIR filter. Samples captured in the ADC FIFO can only be extracted by CPU load instructions over the AXI bus.

---

### Stage 2: FIR Filter Accelerator
- **Source File:** `rtl/fir_filter/fir_top.v`
- **Architecture:** 32-tap transpose/direct form symmetric FIR filter with programmable 16-bit coefficients.
- **Top-Level Port Routing in `veerall_top.sv`:**
  ```verilog
  // Directly tied to chip-level ports:
  input  wire [15:0] fir_s_axis_tdata,
  input  wire        fir_s_axis_tvalid,
  output wire        fir_s_axis_tready,
  output wire [39:0] fir_m_axis_tdata,
  output wire        fir_m_axis_tvalid,
  input  wire        fir_m_axis_tready,
  ```
- **Control Interface:** AXI4-Lite Slave mapped to `0x4000_C000 - 0x4000_CFFF` (Slave 3).
  - Register `0x4000_C000` (`FIR_CTRL`): Bit 0 = Filter Core Enable, Bit 1 = Bypass Mode.
  - Register `0x4000_C004` (`FIR_LOAD`): Bit 0 = Strobe to latch shadow coefficient registers.
  - Register `0x4000_C008` (`FIR_STATUS`): Bit 0 = Ready, Bit 1 = Reload Active.
  - Registers `0x4000_C010 - 0x4000_C08C`: 32 x 16-bit programmable coefficient shadow registers (`coeff_0` through `coeff_31`).
- **Disconnection Finding:**
  1. The FIR filter streaming input (`fir_s_axis_*`) is connected directly to external top-level package pins of `veerall_top.sv`. It is **not** connected internally to the ADC controller.
  2. The FIR filtered stream output (`fir_m_axis_*`) is connected directly to external top-level package pins. It is **not** connected internally to the FFT accelerator.
  3. There is no memory-mapped sample write register for software injection into the FIR filter core.

---

### Stage 3: FFT Accelerator Subsystem
- **Source File:** `rtl/fft_nexhus/fft_accel_top.sv`
- **Architecture:** 1024-point complex FFT engine implementing Radix-2/4 Decimation-in-Frequency (DIF) pipeline using pre-calculated twiddle factors from `twiddle1024.mem`.
- **Memory Interface (Slave 6):** Dual-port Block RAM mapped to `0x4000_A000 - 0x4000_AFFF` (4096 bytes = 1024 x 32-bit words).
  - Port A is coupled to the AXI Interconnect for host CPU / DMA read and write access.
  - Port B is coupled directly to the internal FFT butterfly execution pipeline.
  - Data Format: 32-bit complex words where bits `[31:16]` represent Signed Q1.15 Real part, and bits `[15:0]` represent Signed Q1.15 Imaginary part.
- **Control Interface (Slave 5):** AXI4-Lite registers mapped to `0x4000_8000 - 0x4000_8FFF`.
  - Register `0x4000_8000` (`FFT_CTRL`): Bit 0 = `start` trigger pulse.
  - Register `0x4000_8004` (`FFT_STATUS`): Bit 0 = `done` sticky status flag, Bit 1 = `busy` processing flag.
- **Result Output:** In-place calculation within the dual-port BRAM (`0x4000_A000 - 0x4000_AFFF`). After `done` asserts, Bin 0 resides at `0x4000_A000`, Bin 1 at `0x4000_A004`, through Bin 1023 at `0x4000_AFFC`.

---

## 3. SoC Memory Map & Interconnect Topology

The AXI Interconnect (`axi_interconnect_3x18.sv`) arbitrates across 3 AXI Masters and routes transactions to 18 Slave apertures using high-order address decoding:

| Slave ID | Base Address | End Address | Range | Target Module | Bus Protocol | Description |
| :---: | :---: | :---: | :---: | :--- | :--- | :--- |
| **0** | `0x4000_0000` | `0x4000_0FFF` | 4 KB | `u_uart` (`uart_axi.v`) | AXI4-Lite | 16550-compatible UART Controller |
| **1** | `0x4000_2000` | `0x4000_2FFF` | 4 KB | `u_gpio` (`gpio_axi.v`) | AXI4-Lite | 32-bit Bidirectional GPIO Port |
| **2** | `0x4000_4000` | `0x4000_4FFF` | 4 KB | `u_timer` (`timer_axi.v`) | AXI4-Lite | 32-bit Down-Counter Timer |
| **3** | `0x4000_C000` | `0x4000_CFFF` | 4 KB | `u_fir` (`fir_top.v`) | AXI4-Lite | FIR Control & 32 Coefficient Registers |
| **4** | `0x4000_E000` | `0x4000_EFFF` | 4 KB | `u_adc` (`adc_controller.sv`) | AXI4-Lite | ADC Control, Status & Sample FIFO |
| **5** | `0x4000_8000` | `0x4000_8FFF` | 4 KB | `u_fft_accel` (`fft_accel_top.sv`) | AXI4-Lite | FFT Start Control & Status Registers |
| **6** | `0x4000_A000` | `0x4000_AFFF` | 4 KB | `u_fft_accel.u_mem` | AXI4 Full | FFT 1024-Word Dual-Port Sample RAM |
| **7** | `0x0000_0000` | `0x0000_FFFF` | 64 KB | `u_imem` (`dpram_axi.v`) | AXI4 Full | Instruction Memory (Boot Reset Vector) |
| **8** | `0x0001_0000` | `0x0001_FFFF` | 64 KB | `u_dmem` (`dpram_axi.v`) | AXI4 Full | Data Memory (Stack, BSS, Heap) |
| **9** | `0x4000_6000` | `0x4000_6FFF` | 4 KB | Dummy Slave / Watchdog | AXI4 Full | Unmapped Aperture (Returns `DECERR`) |
| **10-17** | `0x4001_0000` | `0x4001_EFFF` | 8x4KB | Reserved Dummy Slaves | AXI4 Full | Reserved Expansion Apertures |

---

## 4. Bus Deadlock and Concurrency Analysis

1. **CPU Fetch (IFU) vs Data (LSU):**
   - VeeR EL2 IFU is mapped to Master Port 0 (`s00_axi`).
   - VeeR EL2 LSU is mapped to Master Port 1 (`s01_axi`) through a 64-to-32 bit adapter (`axi_64to32_adapter.sv`).
   - IFU fetches strictly from `0x0000_0000` (Slave 7), while LSU accesses DMEM (Slave 8) or MMIO peripherals (`0x4000_xxxx`).
   - The crossbar handles concurrent transactions smoothly without protocol violations or deadlocks.
2. **DSP Acceleration Concurrency:**
   - When the FFT accelerator is triggered via MMIO write to `0x4000_8000`, the calculation takes approximately $1024 \times \log_2(1024) / 4 \approx 2560$ clock cycles.
   - During this period, the internal butterfly engine accesses the dual-port memory via Port B.
   - The CPU can safely poll `0x4000_8004` (FFT Status) over AXI Master 1 without stalling the bus.
   - Bus transactions to other peripherals (UART, GPIO, Timer) proceed concurrently with zero interference.

---

## 5. Architectural Defect Disclosure & Recommended Next Steps

### Defect 1: Missing ADC-to-FIR Stream Bridge
- **Status:** **BLOCKED IN RTL**
- **Root Cause:** ADC output resides in an internal FIFO accessible exclusively through AXI MMIO register `0x4000_E008`. The FIR filter input is an AXI-Stream interface exposed on the chip boundary.
- **Remediation Plan:** For the next SoC revision, instantiate an internal AXI-Stream bridge or DMA channel connecting `adc_fifo` output directly to `fir_s_axis_*`.

### Defect 2: Missing FIR-to-FFT Stream Bridge
- **Status:** **BLOCKED IN RTL**
- **Root Cause:** The FIR filter filtered stream output `fir_m_axis_*` is exposed on the chip boundary. The FFT input requires sample preloading into dual-port memory at `0x4000_A000`.
- **Remediation Plan:** Implement an AXI Stream-to-Memory Scatter/Gather DMA controller that writes FIR filtered samples directly into `0x4000_A000`.
