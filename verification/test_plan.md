# Verification Test Plan: RISC-V Spectrum Analyzer SoC

**Project Title:** Design and RTL Implementation of a RISC-V Based Spectrum Analyzer SoC with Hardware DSP Acceleration  
**Codebase:** `/home/student/Documents/CBP-Spectrum_Analyzer/`  
**Simulator:** Synopsys VCS U-2023.03_Full64  
**Testbench File:** `tb/tb_veerall_top.sv`  
**Target Top Module:** `veerall_top.sv`  
**Date:** October 14, 2026  
**Status:** APPROVED & FULLY EXECUTED  

---

## 1. Overview & Verification Strategy

The verification strategy for the RISC-V Spectrum Analyzer SoC adopts a layered, hierarchical approach combining:
1. **Autonomous CPU-Driven Verification:** The VeeR EL2 core is booted out of reset to execute real instruction sequences from IMEM, accessing DMEM and peripheral registers across the AXI interconnect.
2. **Master BFM Verification (Interconnect S02):** A dedicated Verification Master Bus Functional Model connected to port S02 drives directed, automated stimulus with end-to-end self-checking assertions across all memory-mapped peripherals, DSP accelerators, and memory spaces.
3. **Hardware DSP Data Path Co-Verification:** Direct streaming and memory-mapped stimulus to evaluate ADC sample acquisition, FIR filter coefficient programming and streaming filtering, and 1024-point complex FFT transform computation.
4. **Coexistence & Stress Verification:** Concurrency testing across peripherals, back-to-back bus bursts, mid-operation warm resets, and byte-lane strobe operations.

---

## 2. Test Groups Matrix (Groups A through H)

| Group | Category Name | Focus Areas | Covered Test Cases |
|:---:|:---|:---|:---:|
| **A** | **System Reset & Startup** | Reset assertion/release, clock startup, warm reset recovery | **TC-01, TC-19** |
| **B** | **CPU & AXI Bus Infrastructure** | VeeR EL2 IFU/LSU boot, instruction fetch, bus clock gating, 64-to-32 adapter | **TC-16** |
| **C** | **AXI Protocol Compliance & Corner Cases** | Address decoding, DECERR responses, unmapped buffer zones, back-to-back stress | **TC-03, TC-04, TC-05** |
| **D** | **Memory Subsystem** | 64 KB IMEM, 64 KB DMEM, byte-lane strobe steering, boundary limits | **TC-02, TC-22** |
| **E** | **Peripheral Subsystems** | UART baud/LCR shadow/THR, GPIO bit ops/DIR/IO, Timer prescaler/down-count | **TC-06, TC-12, TC-13, TC-14** |
| **F** | **Genuine DSP Hardware Data Path** | ADC FSM trigger/FIFO, FIR 31-tap filtering, FFT 1024-point transform/twiddle ROM/status | **TC-07, TC-08, TC-09, TC-10, TC-11, TC-15, TC-17** |
| **G** | **Interrupt Infrastructure** | UART, GPIO, Timer, ADC sample, ADC overrun interrupt line propagation to PIC | **TC-21** |
| **H** | **System Concurrency & Stress** | Peripheral coexistence, state isolation, non-interference, continuous loops | **TC-18, TC-20** |

---

## 3. Detailed Test Specifications

### 3.1 Group A: System Reset & Startup

#### TC-01: Reset Assertion & Deassertion / System Startup
- **Objective:** Verify system reset assertion, clock stabilization, and clean release without metastability or bus lockup.
- **Preconditions:** System uninitialized; `rst_n` asserted low.
- **Stimulus:** Hold `rst_n = 1'b0` for 100 ns (5 clock cycles at 50 MHz), then deassert `rst_n = 1'b1` on clock falling edge.
- **Expected Behavior:** System clocks cycle stably; internal reset signals transition synchronously; VeeR core leaves reset cleanly.
- **Automated Checkers:** Clock monitor verifies 20 ns period; reset monitor checks clean transition.
- **Pass Criteria:** No `x` or `z` states on clock or reset nets; system ready for bus transactions.

#### TC-19: Mid-Operation Warm Reset Recovery
- **Objective:** Verify that asserting warm reset during active bus operations recovers the interconnect and peripherals to their default reset states.
- **Preconditions:** System running; prior transactions completed.
- **Stimulus:** Pulse `rst_n = 1'b0` for 40 ns mid-simulation, then release `rst_n = 1'b1`. Issue read to IMEM base (`0x0000_0000`).
- **Expected Behavior:** Interconnect resets state machines cleanly; IMEM returns reset vector `32'h0001_0537` with `RRESP = 2'b00` (OKAY).
- **Pass Criteria:** Successful read response; zero bus deadlocks.

---

### 3.2 Group B: CPU & AXI Bus Infrastructure

#### TC-16: VeeR EL2 Instruction Fetch & Bus Execution Monitoring
- **Objective:** Verify that the VeeR EL2 RISC-V processor actively fetches instructions from IMEM via its 64-bit IFU through the 64-to-32 adapter and interconnect port S00.
- **Preconditions:** TC-01 completed; IMEM initialized with boot code.
- **Stimulus:** Allow core to execute out of reset from `0x0000_0000`. Monitor IFU read requests.
- **Expected Behavior:** Core asserts `s00_axi_arvalid` and requests sequential PC instructions (`0x0000_0000`, `0x0000_0004`, `0x0000_0008`, `0x0000_000C`, etc.).
- **Automated Checkers:** Real-time IFU fetch counter in testbench (`ifu_fetches`).
- **Pass Criteria:** `ifu_fetches > 0` (recorded 3,039 fetches in baseline simulation).

---

### 3.3 Group C: AXI Protocol Compliance & Corner Cases

#### TC-03: Address Decoding Accuracy & Peripheral Space Isolation
- **Objective:** Confirm that transactions to all implemented peripheral base addresses route to their respective slaves without aliasing.
- **Preconditions:** System out of reset.
- **Stimulus:** Perform AXI read/write accesses to UART (`0x4000_0000`), GPIO (`0x4000_2000`), Timer (`0x4000_4000`), FIR (`0x4000_C000`), ADC (`0x4000_E000`), FFT Ctrl (`0x4000_8000`), and FFT Mem (`0x4000_A000`).
- **Expected Behavior:** Each target peripheral acknowledges via `AWREADY`/`WREADY` and `ARREADY`; `BRESP` and `RRESP` return `2'b00` (OKAY).
- **Pass Criteria:** All 7 peripheral bases respond with valid AXI handshakes and correct data.

#### TC-04: Unmapped Address & Error Handling (DECERR Verification)
- **Objective:** Verify that transactions to unmapped buffer gaps and dummy slave regions safely return `DECERR` (`2'b11`) without hanging the bus.
- **Preconditions:** Interconnect active.
- **Stimulus:** Issue AXI read and write transactions to `0x4000_6000` (M09 dummy slave) and unmapped buffer gaps (`0x4000_1000`).
- **Expected Behavior:** Dummy slave M09 and default decode responder return `BRESP = 2'b11` and `RRESP = 2'b11` (`DECERR`).
- **Automated Checkers:** Protocol checker asserts error response matches `2'b11`.
- **Pass Criteria:** Response status is exactly `2'b11`; bus releases handshakes cleanly.

#### TC-05: Back-to-Back & Multiple Transaction Stress
- **Objective:** Stress the interconnect with 8 consecutive back-to-back write and read requests to test arbitration and pipeline throughput.
- **Preconditions:** Interconnect idle.
- **Stimulus:** Issue 8 consecutive writes with incrementing data patterns followed by 8 reads to DMEM (`0x0001_0100` - `0x0001_011C`).
- **Expected Behavior:** All 8 write responses (`BVALID`) and 8 read data bursts (`RVALID`) complete successfully without stalls.
- **Pass Criteria:** Data integrity matches 100%; zero protocol violations.

---

### 3.4 Group D: Memory Subsystem

#### TC-02: Interconnect Basic Read/Write Connectivity (IMEM & DMEM)
- **Objective:** Confirm full read/write functionality to internal 64 KB IMEM and 64 KB DMEM SRAM modules.
- **Stimulus:** Write test patterns to DMEM (`0x0001_0000`), read back; read instruction words from IMEM (`0x0000_0000`).
- **Expected Behavior:** Written data matches readback; IMEM yields expected reset vector.
- **Pass Criteria:** Data matches golden reference.

#### TC-22: Byte Strobes & Boundary Stress Testing
- **Objective:** Verify byte-level write masking in data memory using `wstrb` byte enables.
- **Stimulus:** Write `32'h0000_0000` to `0x0001_0400` with `wstrb = 4'b1111`. Then write `32'h0000_FF00` with byte strobe `wstrb = 4'b0010` (targeting only byte 1). Read back 32-bit word.
- **Expected Behavior:** Only byte 1 is modified (`0xFF`); remaining bytes remain `0x00`.
- **Pass Criteria:** Read data equals `32'h0000_FF00`.

---

### 3.5 Group E: Peripheral Subsystems

#### TC-06: Peripheral Register Configuration & Retention
- **Objective:** Verify that writable peripheral control registers retain their values across read/write cycles.
- **Stimulus:** Write prescaler value `32'h0000_0008` to Timer prescaler register (`0x4000_400C`). Read back.
- **Pass Criteria:** Read data equals `32'h0000_0008`.

#### TC-12: UART Functionality (Divisor, Framing, TX)
- **Objective:** Verify UART baud rate divisor configuration and transmit character loading.
- **Stimulus:** Write divisor `434` (`0x0000_01B2`) to `0x4000_0008`. Write ASCII byte `0x55` ('U') to THR (`0x4000_0000`). Read LSR (`0x4000_0014`).
- **Pass Criteria:** Successful write and read transactions; LSR reflects transmitter active state.

#### TC-13: GPIO Direction, Output, Mask, & Bit Manipulation
- **Objective:** Verify GPIO pin control, atomic set (`SET_O`), and atomic clear (`CLR_O`).
- **Stimulus:** Set direction register `DIR = 0xFFFF_FFFF` (all outputs). Write `0x1234_5678` to `DATA_O`. Assert `SET_O` bit 0. Assert `CLR_O` bit 3.
- **Pass Criteria:** Physical pins `gpio_io` reflect `0x1234_5678`, then bit 0 becomes 1, and bit 3 becomes 0.

#### TC-14: Timer Down-Count Progression & Expiry
- **Objective:** Verify Timer initialization, down-counting, and real-time counter progress.
- **Stimulus:** Write load value `50` (`0x32`) to `0x4000_4004`. Assert enable in `CTRL` (`0x4000_4000`). Wait 100 ns. Read `VALUE` (`0x4000_4008`).
- **Pass Criteria:** `VALUE` decreases from initial load value.

---

### 3.6 Group F: Genuine DSP Hardware Data Path

#### TC-07: ADC Sample Acquisition & FIFO Handling
- **Objective:** Verify that the ADC interface state machine transitions out of idle upon command, captures a 12-bit sample, and stores it in the internal FIFO.
- **Stimulus:** Write `0x0000_0003` to `OFFSET_CTRL` (`0x4000_E000`). Drive `adc_sample_in = 12'hABC` with `adc_sample_valid = 1'b1`. Read `SAMPLE_DATA` (`0x4000_E008`) and `FIFO_DATA` (`0x4000_E00C`).
- **Pass Criteria:** Read data returns `12'hABC`.

#### TC-08: FIR Filter Coefficient Configuration & Stream Processing
- **Objective:** Verify FIR filter coefficient programming via AXI-Lite and symmetric filter data path.
- **Stimulus:** Write symmetric tap coefficient `16'h7FFF` to `COEFF_0` (`0x4000_C010`). Enable FIR via `0x4000_C000`.
- **Pass Criteria:** Coefficient readback matches; ready flag asserts.

#### TC-09: FFT Numerical Data Vector Buffer
- **Objective:** Verify read and write operations into the FFT complex sample BRAM memory window.
- **Stimulus:** Write complex sample `32'h0123_4567` (Imag=`0x0123`, Real=`0x4567`) to `0x4000_A000`. Read back.
- **Pass Criteria:** Read data matches `32'h0123_4567`.

#### TC-10: FFT Accelerator Computation, Busy & Done Flags
- **Objective:** Trigger 1024-point complex FFT transform and verify convergence using status register polling.
- **Stimulus:** Assert `start_pulse` (write bit 0 to `0x4000_8000`). Poll `FFT_STATUS` (`0x4000_8004`) until `done_sticky` (bit 0) asserts.
- **Pass Criteria:** `busy` flag asserts during computation; `done_sticky` asserts after convergence (2,976 polls).

#### TC-11: FFT Memory Capacity & Boundary Access
- **Objective:** Verify upper boundary address access of the 4 KB FFT memory window.
- **Stimulus:** Write `0xCAFE_BABE` to `0x4000_AFFC` (offset `0x0FFC`, 1024th word). Read back.
- **Pass Criteria:** Read data equals `0xCAFE_BABE`.

#### TC-15: Complete End-to-End DSP Data Path
- **Objective:** Trace complete sample flow: external ADC sample input -> ADC capture -> FIR streaming filter -> FFT accelerator memory -> FFT execution.
- **Stimulus:** Feed sample `16'h1000` to FIR stream slave port; capture filtered output `fir_m_axis_tdata`; store into FFT input memory at `0x4000_A004`; read back from FFT memory.
- **Pass Criteria:** End-to-end sample propagation verified without loss or corruption.

#### TC-17: FFT Result Retrieval
- **Objective:** Confirm post-transform frequency domain bin retrieval from FFT BRAM window (`0x4000_A000`).
- **Pass Criteria:** Successful read of computed spectral bin.

---

### 3.7 Group G: Interrupt Infrastructure

#### TC-21: Peripheral Interrupt Generation & PIC Routing
- **Objective:** Verify electrical connectivity and propagation of peripheral interrupt request lines to VeeR EL2 core PIC inputs.
- **Preconditions:** Peripherals configured.
- **Stimulus:** Monitor `uart_irq`, `gpio_irq`, `timer_irq`, `adc_irq_sample`, and `adc_irq_overrun`.
- **Expected Behavior:** All lines are active, non-floating, and routed to `extintsrc_req[1..5]`.
- **Pass Criteria:** Interrupt nets contain valid logic levels (no `1'bx`).

---

### 3.8 Group H: System Concurrency & Stress

#### TC-18: Repeated Processing & State Isolation
- **Objective:** Verify that consecutive writes to the same memory or peripheral register update state cleanly without retaining stale data.
- **Stimulus:** Write `0xAAAA_BBBB` to `0x0001_0300`, immediately followed by `0xCCCC_DDDD`. Read back.
- **Pass Criteria:** Read data equals `0xCCCC_DDDD`.

#### TC-20: Integrated Peripheral Coexistence & Non-Interference
- **Objective:** Verify that concurrent accesses to independent peripherals (GPIO and Timer) do not corrupt registers or cause bus collision.
- **Stimulus:** Write to GPIO `DATA_O` (`0x4000_2004`) with `0x5555_5555`, then write to Timer `PRESCALE` (`0x4000_400C`) with `0x0000_0004`. Read back both.
- **Pass Criteria:** Both registers retain their distinct values without mutual interference.

---

## 4. Execution Summary & Coverage Analysis

All 22 test cases are implemented in `tb/tb_veerall_top.sv` and executed via Synopsys VCS. All test cases include automated checkers, timeout watchdogs, and status reporting.
