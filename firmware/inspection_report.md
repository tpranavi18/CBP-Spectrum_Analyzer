# Spectrum Analyzer SoC — Architectural Inspection & Hardware Baseline Report

**Project**: Design and RTL Implementation of a RISC-V Based Spectrum Analyzer SoC with Hardware DSP Acceleration  
**Root Path**: `/home/student/Documents/CBP-Spectrum_Analyzer`  
**Date**: October 15, 2026  
**Status**: Frozen RTL Baseline — New Firmware & Documentation Only  

---

## 1. Executive Architectural Summary

The Spectrum Analyzer System-on-Chip (SoC) integrates a Western Digital VeeR EL2 32-bit RISC-V processor core with a dedicated hardware DSP acceleration pipeline and standard embedded peripherals over an AXI4 interconnect fabric. The SoC is engineered to acquire digitized analog samples, optionally apply digital finite impulse response (FIR) filtering, execute a 1024-point radix-2 Decimation-in-Time (DIT) Fast Fourier Transform (FFT), and communicate spectral analysis diagnostics to a host platform via an AXI UART interface.

```
+----------------------------------------------------------------------------------------------------+
|                                    SPECTRUM ANALYZER SOC TOP                                       |
|                                                                                                    |
|  +---------------------+                                                                           |
|  | Western Digital     |                                                                           |
|  | VeeR EL2 Core       |                                                                           |
|  | (RV32IMC / Zba,bb,  |                                                                           |
|  |  bc,bs)             |                                                                           |
|  | Reset: 0x00000000   |                                                                           |
|  +----+-----------+----+                                                                           |
|       | IFU (64b) | LSU (64b)                                                                      |
|       v           v                                                                                |
|  +----+-----------+----+                                                                           |
|  | 2x axi_64to32_      |                                                                           |
|  | adapter (Width Conv)|                                                                           |
|  +----+-----------+----+                                                                           |
|       | S00 (32b) | S01 (32b)        S02: Verification Master BFM (32b)                            |
|       v           v                  v                                                             |
|  +----+-----------+------------------+----------------------------------------------------------+  |
|  |            AXI4 Interconnect Fabric (3-Master x 18-Slave: axi_interconnect_wrap_3x18)        |  |
|  +----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+-----+  |
|       |     |     |     |     |     |     |     |     |     |     |     |     |     |     |        |
|       v     v     v     v     v     v     v     v     v     v     v     v     v     v     v        |
|      M07   M08   M00   M01   M02   M03   M04   M05   M06   M09   M10   M11   M12   M13-M17     |
|     IMEM  DMEM  UART  GPIO  TIMER  FIR   ADC   FFT   FFT   WDT   SPI   QRS   AES   RESERVED    |
|      64K   64K  4KB   4KB   4KB    4KB   4KB   CTRL  MEM   DECERR------------------------>     |
|                                                  4KB   4KB                                         |
+-------+-----+-----+-----+-----+-----+-----+-----+-----+-----+--------------------------------------+
        |                                   ^     ^     ^
        |   ADC Sample Pins [11:0] -------->+     |     |
        |   FIR AXI-Stream In/Out ----------------+     |
        |   FFT BRAM Direct Window (1024 words) --------+
```

---

## 2. Core Processor Configuration & Boot Sequence

### 2.1 Processor Architecture & ISA
- **Core Type**: Western Digital VeeR EL2 (instantiated as `el2_veer_wrapper` inside `rtl/veer_wrapper.sv`).
- **XLEN**: 32-bit (`RV_XLEN = 32`).
- **Base ISA**: RV32I.
- **Extensions**:
  - `M`: Hardware integer multiplication and division (`RV_DIV_NEW = 1`, `RV_DIV_BIT = 4`).
  - `C`: Standard 16-bit compressed instructions.
  - Bitmanipulation Extensions enabled in snapshot: `Zba` (address generation), `Zbb` (basic bitmanip), `Zbc` (carry-less multiplication), `Zbs` (single-bit instructions).
- **Toolchain Target**: `-march=rv32imc -mabi=ilp32`.
- **Registers**: 32 standard integer architectural registers (`x0` - `x31`).

### 2.2 Memory Subsystem Configuration (Snapshot Defines)
As verified directly in `rtl/Cores-VeeR-EL2/snapshots/spectrum_analyzer/common_defines.vh`:
```verilog
// cmd: veer -target=default -set=iccm_enable=0 -set=dccm_enable=0 -set=icache_enable=0
//           -set=reset_vec=0x00000000 -set=pic_total_int=8 -snapshot=spectrum_analyzer
`define RV_RESET_VEC          'h00000000
`define RV_NO_ICCM_NO_ICACHE  1
`define RV_XLEN               32
`define RV_BUILD_AXI4         1
`define RV_BUILD_AXI_NATIVE   1
`define RV_EXT_ADDRWIDTH      32
`define RV_EXT_DATAWIDTH      64
```
- **ICCM / DCCM**: Disabled (`iccm_enable=0`, `dccm_enable=0`).
- **Instruction Cache**: Disabled (`icache_enable=0`).
- **Instruction Fetching**: The core fetches instructions natively via the 64-bit IFU AXI master (`ifu_axi_*`), translated by `axi_64to32_adapter` to 32-bit AXI slot S00 of the interconnect.
- **Data Load/Store**: The core accesses data natively via the 64-bit LSU AXI master (`lsu_axi_*`), translated by `axi_64to32_adapter` to 32-bit AXI slot S01 of the interconnect.
- **Reset Vector**: Explicitly configured to `0x0000_0000`. Upon deassertion of `rst_n`, the CPU begins fetching from byte address `0x0000_0000` in IMEM.

---

## 3. Bus Fabric & Memory Map Verification

### 3.1 AXI Interconnect Architecture
- **Interconnect Module**: `axi_interconnect_wrap_3x18` (3 Masters, 18 Slaves).
- **Master Ports**:
  - `S00`: CPU IFU Master (Instruction fetch via 64-to-32 adapter).
  - `S01`: CPU LSU Master (Load/store data via 64-to-32 adapter).
  - `S02`: Verification Master BFM (Direct 32-bit AXI master driven by testbench).
- **Arbitration**: Round-robin priority with backpressure management.
- **Data Width**: 32-bit internal data fabric.
- **Address Width**: 32-bit byte addressing.

### 3.2 Confirmed Address Map (Cross-Checked Against RTL & ODS Spreadsheet)

| Interconnect Slot | Peripheral / Region | Base Address | End Address | Window Size | Implementation / Status |
|---|---|---|---|---|---|
| **M07** | **IMEM (Instruction Memory)** | `0x0000_0000` | `0x0000_FFFF` | 64 KiB | Real SRAM (`axi_imem_slave.sv`), Reset Vector |
| **M08** | **DMEM (Data Memory)** | `0x0001_0000` | `0x0001_FFFF` | 64 KiB | Real SRAM (`axi_dmem_slave.sv`), Stack/Data |
| **M00** | **UART** | `0x4000_0000` | `0x4000_0FFF` | 4 KiB | Real IP (`axi_uart_top.v`), 115200 baud, 8N1 |
| **M01** | **GPIO** | `0x4000_2000` | `0x4000_2FFF` | 4 KiB | Real IP (`gpio_axi.sv`), 32 bidirectional pins |
| **M02** | **Timer** | `0x4000_4000` | `0x4000_4FFF` | 4 KiB | Real IP (`timer_axi.sv`), 32-bit down counter |
| **M09** | **Watchdog (Reserved)** | `0x4000_6000` | `0x4000_6FFF` | 4 KiB | Dummy Responder (`DECERR` `2'b11`) |
| **M05** | **FFT Control / Status** | `0x4000_8000` | `0x4000_8FFF` | 4 KiB | Real IP (`fft_ctrl_axil.sv`), Start / Done / Busy |
| **M06** | **FFT Memory Window** | `0x4000_A000` | `0x4000_AFFF` | 4 KiB | Real IP (`fft_mem_axi4_slave.sv`), 1024 complex words |
| **M03** | **FIR Filter** | `0x4000_C000` | `0x4000_CFFF` | 4 KiB | Real IP (`fir_top.v`), 32 taps, AXI-Stream datapath |
| **M04** | **ADC Interface** | `0x4000_E000` | `0x4000_EFFF` | 4 KiB | Real IP (`adc_controller.sv`), 12-bit, FIFO |
| **M10** | **SPI (Reserved)** | `0x4001_0000` | `0x4001_0FFF` | 4 KiB | Dummy Responder (`DECERR` `2'b11`) |
| **M11** | **QRS (Reserved)** | `0x4001_2000` | `0x4001_2FFF` | 4 KiB | Dummy Responder (`DECERR` `2'b11`) |
| **M12** | **AES-128 (Reserved)** | `0x4001_4000` | `0x4001_4FFF` | 4 KiB | Dummy Responder (`DECERR` `2'b11`) |
| **M13** | **Interrupt Aggregator** | `0x4001_6000` | `0x4001_6FFF` | 4 KiB | Dummy Responder (`DECERR` `2'b11`) |
| **M14** | **PWM (Reserved)** | `0x4001_8000` | `0x4001_8FFF` | 4 KiB | Dummy Responder (`DECERR` `2'b11`) |
| **M15** | **I2C (Reserved)** | `0x4001_A000` | `0x4001_AFFF` | 4 KiB | Dummy Responder (`DECERR` `2'b11`) |
| **M16** | **DMA (Reserved)** | `0x4001_C000` | `0x4001_CFFF` | 4 KiB | Dummy Responder (`DECERR` `2'b11`) |
| **M17** | **Reserved / Future** | `0x4001_E000` | `0x4001_EFFF` | 4 KiB | Dummy Responder (`DECERR` `2'b11`) |

*Note on Unmapped Addresses*: 4 KiB buffer regions between peripheral apertures (`0x4000_1000`, `0x4000_3000`, etc.) and unmapped space above `0x4002_0000` are decoded by the interconnect default responder, returning `DECERR` (`2'b11`).

---

## 4. Hardware DSP Acceleration Pipeline

### 4.1 FFT Accelerator (`fft_accel_top`)
- **Core Architecture**: Radix-2 Decimation-In-Time (DIT) Butterfly Processor with internal twiddle factor ROM (`twiddle1024.mem`).
- **Transform Size ($N$)**: 1024 complex points ($1024 \times 32\text{-bit}$ words = 4096 bytes).
- **Execution Latency**: 10 stages ($2^{10} = 1024$), taking 5,120 butterfly operations (~2,976 status polling cycles / ~717 µs at 50 MHz).
- **Data Packing**:
  - Bit `[31:16]`: Signed 16-bit Real component ($Q1.15$ format, range $[-1.0, +0.9999]$).
  - Bit `[15:0]`: Signed 16-bit Imaginary component ($Q1.15$ format).
- **Control Registers**:
  - `0x4000_8000` (`FFT_REG_CTRL`): Write bit 0 = 1 issues a 1-cycle `start_pulse` to the stage controller. If written while `fft_busy == 1`, returns `SLVERR`. Read returns 0.
  - `0x4000_8004` (`FFT_REG_STATUS`): Read-only. Bit 0 is `done_sticky` (asserted upon stage 10 completion), Bit 1 is `fft_busy` (active during computation).
- **Memory Window (`0x4000_A000` - `0x4000_AFFC`)**:
  - Address translation: In `veerall_axi_ips_top.sv`, `fft_mem_awaddr = m06_axi_awaddr[15:0] - 16'h9000;`. Offset `0x000` maps to internal BRAM base `0x1000`. Offset `0xFFC` maps to BRAM top `0x1FFC`.
  - **Critical Hardware Contention Rule**: When `fft_busy == 1`, `fft_mem_axi4_slave.sv` enforces `S_AXI_AWREADY <= !fft_busy` and `S_AXI_ARREADY <= !fft_busy`. Any CPU load or store to the memory window while the FFT engine is actively computing will stall the LSU and deadlock the shared interconnect. Software must poll `FFT_REG_STATUS` until `fft_busy == 0` before initiating any result readback or next-frame vector preload!

### 4.2 FIR Filter IP (`fir_top`)
- **Structure**: 32-tap transpose/direct-form FIR filter engine.
- **Precision**: 16-bit signed coefficients, 16-bit signed input data, 40-bit internal accumulator.
- **Software Interface**:
  - `0x4000_C000` (`FIR_REG_CTRL`): Bit 0 = Engine enable.
  - `0x4000_C004` (`FIR_REG_LOAD`): Write bit 0 = 1 pulses load strobe to transfer shadow coefficient registers (`coeff_reg[0..31]`) into active pipeline registers (`active_coeff_reg[0..31]`).
  - `0x4000_C008` (`FIR_REG_STATUS`): Read-only status flags (Bit 0: Input FIFO Full, Bit 1: Input FIFO Empty, Bit 2: Output FIFO Full, Bit 3: Output FIFO Empty).
  - `0x4000_C010` - `0x4000_C08C`: `FIR_REG_COEFF[0..31]` (32 registers, 16-bit signed tap weights).
- **Hardware/Software Boundary Limitation**: The FIR filter's sample input path is **strictly AXI4-Stream** (`fir_s_axis_tvalid`, `fir_s_axis_tdata`, `fir_s_axis_tready`) exposed at the top level of the chip. There is **no memory-mapped sample write register** in the FIR register block. Software can configure coefficients, issue the load strobe, verify enable status, and monitor FIFO flags, but cannot directly write raw streaming samples to the FIR engine via MMIO.

### 4.3 ADC Interface (`adc_controller`)
- **Structure**: 12-bit ADC capture controller with 32-entry sample FIFO and periodic sampling scheduler.
- **Base Address**: `0x4000_E000`.
- **Registers**:
  - `0x4000_E000` (`ADC_REG_CTRL`): Bit 0 = Scheduler enable (`ENABLE`), Bit 1 = Single-shot sample trigger (`START`).
  - `0x4000_E004` (`ADC_REG_STATUS`): Bit 0 = Busy, Bit 1 = Done, Bit 2 = FIFO Empty, Bit 3 = FIFO Full, Bit 4 = Overrun, Bit 5 = Request Error. (Bits 1, 4, 5 are R/W1C).
  - `0x4000_E008` (`ADC_REG_SAMPLE_DATA`): Read latest 12-bit captured sample.
  - `0x4000_E00C` (`ADC_REG_FIFO_DATA`): Read 12-bit sample from FIFO; read strobe automatically pops the FIFO entry.
  - `0x4000_E010` (`ADC_REG_IRQ_EN`): Bit 0 = Sample IRQ enable, Bit 1 = Overrun IRQ enable.
- **Hardware/Software Boundary Limitation**: In real operation, ADC samples are generated by external analog circuitry or top-level testbench pins (`adc_sample_in[11:0]`, `adc_sample_valid`). If external sample strobes are not applied, the ADC state machine remains in `ACQ_WAIT`. Firmware must enforce bounded timeouts on all ADC acquisition loops to detect missing samples gracefully.

---

## 5. Standard Embedded Peripherals

### 5.1 UART Interface (`axi_uart_top`)
- **Base Address**: `0x4000_0000`.
- **Clock**: 50 MHz system clock.
- **Baud Rate Calculation**: Divisor $= \frac{F_{\text{clk}}}{16 \times \text{Baud}} = \frac{50\,000\,000}{16 \times 115\,200} \approx 27 = \text{0x001B}$.
- **Line Control (LCR)**: 8 data bits, 1 stop bit, no parity (8N1) $\rightarrow$ write `0x03` to `0x4000_000C`.
- **RTL Integration Enhancement**: In `veerall_axi_ips_top.sv`, a dedicated shadow register intercepts LCR writes (`0x4000_000C`) and supplies fallback readback, preventing bus hang observed in unextended UART cores.
- **Line Status (LSR)**: `0x4000_0014`. Bit 5 (`THRE`) indicates Transmitter Holding Register Empty. Bit 0 (`DR`) indicates Data Ready.

### 5.2 GPIO Interface (`gpio_axi`)
- **Base Address**: `0x4000_2000`.
- **Width**: 32 bidirectional I/O pins (`gpio_io[31:0]`).
- **Registers**:
  - `+0x00` (`GPIO_REG_DATA_I`): Read pin status (debounced).
  - `+0x04` (`GPIO_REG_DATA_O`): Read/write output register.
  - `+0x08` (`GPIO_REG_DIR`): Direction (1 = Output, 0 = Input).
  - `+0x0C` (`GPIO_REG_INT_EN`): Per-pin interrupt enable.
  - `+0x1C` (`GPIO_REG_INT_STS`): Interrupt status (R/W1C).
  - `+0x20` (`GPIO_REG_SET_O`): Atomic bit set for `DATA_O`.
  - `+0x24` (`GPIO_REG_CLR_O`): Atomic bit clear for `DATA_O`.
  - `+0x28` (`GPIO_REG_TGL_O`): Atomic bit toggle for `DATA_O`.

### 5.3 Timer Subsystem (`timer_axi`)
- **Base Address**: `0x4000_4000`.
- **Registers**:
  - `+0x00` (`TIMER_REG_CTRL`): Bit 0 = Enable, Bit 1 = Mode (0 = One-shot, 1 = Periodic), Bit 2 = Prescaler Enable, Bit 3 = Direction (0 = Down, 1 = Up).
  - `+0x04` (`TIMER_REG_LOAD`): Write immediately loads the down-counter.
  - `+0x08` (`TIMER_REG_VAL`): Current counter value.
  - `+0x0C` (`TIMER_REG_PRE`): 16-bit prescaler divide value.
  - `+0x10` (`TIMER_REG_INT_EN`): Bit 0 = Expiry interrupt enable.
  - `+0x14` (`TIMER_REG_INT_STS`): Sticky interrupt status (R/W1C).

---

## 6. Interrupt Architecture & PIC Routing

The SoC peripheral interrupt lines are aggregated in `veerall_top.sv` and routed into the VeeR core Programmable Interrupt Controller (PIC) lines `extintsrc_req[8:1]`:

| Interrupt Source | Peripheral Module | Top-Level Signal | VeeR Core Input |
|---|---|---|---|
| **UART RX IRQ** | `axi_uart_top` (`read_interrupt_o`) | `output wire uart_irq` | `extintsrc_req[1]` |
| **GPIO IRQ** | `gpio_axi` (`intr`) | `output wire gpio_irq` | `extintsrc_req[2]` |
| **Timer Expiry IRQ** | `timer_axi` (`irq`) | `output wire timer_irq` | `extintsrc_req[3]` |
| **ADC Sample Ready** | `adc_controller` (`irq_sample`) | `output wire adc_irq_sample` | `extintsrc_req[4]` |
| **ADC Overrun** | `adc_controller` (`irq_overrun`) | `output wire adc_irq_overrun`| `extintsrc_req[5]` |
| **Reserved / Tied** | Unused | Tied to 0 | `extintsrc_req[8:6]` |

---

## 7. Categorization of Hardware Functions

To satisfy Phase A requirements, all SoC functionality is categorized into four distinct operational classes:

### Category 1: Functions Controlled by C through MMIO
1. **UART Configuration & Transmission**: Setting baud rate divisor, configuring 8N1 line format, polling transmitter holding empty flag (`LSR[5]`), and writing diagnostic characters to `THR`.
2. **GPIO Pin Management**: Setting pin direction (`DIR`), writing output pins (`DATA_O`), atomic set/clear/toggle, and reading pin states (`DATA_I`).
3. **Timer Operations**: Loading down-counter values, setting prescaler, enabling one-shot or periodic modes, and checking down-counter progression.
4. **FIR Configuration**: Writing 32 signed 16-bit filter coefficients, pulsing the coefficient load strobe, enabling the filtering engine, and reading FIFO status.
5. **ADC Controller Configuration**: Setting sampling enable, initiating manual acquisition triggers, configuring sample/overrun interrupt masks, reading status flags, and popping samples from the FIFO.
6. **FFT Accelerator Execution**: Polling busy/idle status, writing start pulse to `FFT_REG_CTRL`, monitoring `done_sticky` flag, and retrieving 1024 complex frequency bins from the memory window.

### Category 2: Functions Performed by the Hardware DSP Datapath
1. **Pipelined Complex Butterfly Operations**: 10-stage Radix-2 DIT FFT engine performing fixed-point butterfly arithmetic with internal twiddle factor multiplication and dynamic scaling.
2. **FIR Streaming MAC Engine**: 32-stage multiply-accumulate datapath calculating $\sum_{k=0}^{31} h[k] \cdot x[n-k]$ at full clock rate over AXI4-Stream.
3. **ADC Sampling Scheduler & FIFO**: Hardware FSM managing sample acquisition timing, input latching, and 32-entry circular FIFO management.

### Category 3: Functions Observed & Verified through Existing Interfaces
1. **Register Readback**: Verification of written configuration values across UART, GPIO, Timer, FIR, ADC, and FFT.
2. **Status Flag Transitions**: Observation of busy assertion, completion deassertion, FIFO empty/full transitions, and error flags.
3. **FFT Numerical Convergence**: Reading computed frequency-domain real and imaginary values from the memory window and locating peak spectral energy bins.
4. **DECERR Bus Trap Responses**: Detecting illegal or reserved peripheral access responses.

### Category 4: Functions Blocked by Missing Interfaces or Frozen Baseline Constraints
1. **Direct MMIO Sample Delivery to FIR**: There is no memory-mapped FIFO write register for the FIR filter; streaming data must be injected via `fir_s_axis_*` top-level pins.
2. **Autonomous Physical Analog Signal Generation**: The chip cannot fabricate continuous analog voltage waveforms; digital samples must arrive via `adc_sample_in[11:0]`.
3. **In-place Dynamic IMEM Loading Without Testbench Backdoor**: `axi_imem_slave.sv` does not contain dynamic `$readmemh` or external flash interface; software testing in simulation relies on testbench memory preloading or initial memory arrays.

---

## 8. Conclusion & Readiness for Firmware Development

The architectural inspection confirms that all necessary peripheral registers, memory windows, and accelerator controls are fully accessible via the 32-bit AXI interconnect. Bare-metal firmware targeting `-march=rv32imc -mabi=ilp32` with entry point at `0x0000_0000` can fully orchestrate the spectrum analysis application, manage peripheral operations, handle timeouts, and report diagnostic telemetry over UART.
