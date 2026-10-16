# Spectrum Analyzer SoC — Firmware Verification Plan & Test Strategy

**Project**: Design and RTL Implementation of a RISC-V Based Spectrum Analyzer SoC with Hardware DSP Acceleration  
**Root Path**: `/home/student/Documents/CBP-Spectrum_Analyzer`  
**Document**: `firmware/verification_plan.md`  
**Status**: Authoritative Bare-Metal Verification Plan  

---

## 1. Overview & Verification Objectives

This document establishes the structured verification methodology for the bare-metal C firmware developed for the Spectrum Analyzer SoC. The primary verification goal is to ensure that the firmware exercises the actual hardware capabilities of the VeeR EL2 processor, the 3x18 AXI4 interconnect fabric, all memory-mapped peripherals (UART, GPIO, Timer), and the dedicated hardware DSP acceleration pipeline (ADC Controller, FIR Filter, and 1024-point complex FFT Accelerator) without making assumptions unsupported by the RTL baseline.

### Key Verification Principles
1. **Real Hardware Interfacing**: The firmware performs authentic read/write MMIO operations against documented register offsets.
2. **Zero Falsification**: Diagnostic outputs and `PASS` notifications are emitted only after evaluating the corresponding hardware response or status bit.
3. **Bounded Latency & Anti-Deadlock**: Every polling loop enforcing bus or peripheral synchronization is bounded by a strict iteration limit to prevent infinite hangs.
4. **Architectural Boundary Fidelity**: The plan acknowledges physical and bus boundaries (e.g., AXI-Stream for FIR samples, external stimulus for ADC pins) and distinguishes between hardware-executed tests and environment-limited conditions.
5. **Reusability for RTL Regressions**: Test cases are structured with clear stimulus, observable outputs, and expected results so that the same functional scenarios can be replicated in cycle-accurate SystemVerilog/VCS regression environments.

---

## 2. Multi-Tier Verification Methodology

The verification strategy is organized into five complementary tiers:

```text
+-----------------------------------------------------------------------------------+
| TIER 1: Static Code Review & Register Audit                                       |
| - Validate register addresses, offsets, bitfield definitions against RTL          |
| - Verify finite loop bounds, pointer correctness, and volatile qualifiers         |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
| TIER 2: Linker Architecture & Memory Layout Validation                            |
| - Check section allocation (IMEM 64K, DMEM 64K), stack alignment, no overlaps     |
| - Verify reset vector (0x00000000) and data relocation mechanisms                 |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
| TIER 3: Toolchain Compilation & ELF Analysis (College PC)                         |
| - Build with riscv64-unknown-elf-gcc (-march=rv32imc -mabi=ilp32)                 |
| - Inspect symbols, disassembly (objdump), memory footprint (size)                 |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
| TIER 4: Target Simulation & Bus-Level Monitoring                                  |
| - Monitor VeeR EL2 instruction fetch (IFU) and data transaction (LSU) on AXI      |
| - Verify read/write handshakes, dummy DECERR responses, and IRQ line assertion    |
+-----------------------------------------------------------------------------------+
                                          |
                                          v
+-----------------------------------------------------------------------------------+
| TIER 5: DSP Acceleration & Spectrum Analysis Application                          |
| - Validate ADC acquisition scheduler and FIFO status handling                     |
| - Verify FIR coefficient latching and active bank activation                      |
| - Inject deterministic test vectors (DC, Nyquist, Tones, Impulse) to FFT window   |
| - Trigger FFT, poll completion, retrieve complex bins, compute magnitude spectrum |
+-----------------------------------------------------------------------------------+
```

---

## 3. Comprehensive 22-Case Verification Matrix

The test matrix implements and extends all 22 test cases specified in the project's authoritative ODS spreadsheet (`excel sheet (address, test cases, register set, data and cntrol path).ods`):

| Test ID | Category | Target Hardware | Stimulus / Procedure | Observable Register / Signal | Pass Criteria | Known Constraints / Notes |
|---|---|---|---|---|---|---|
| **TC-01** | Reset & CPU | VeeR EL2 Core | Execute ALU addition, subtraction, bitwise logic, and branching out of reset | Register updates, sequential PC execution | Result matches exact expected value; no CPU trap | Verifies CPU instruction decode and execution out of reset at `0x0` |
| **TC-02** | Interconnect | IMEM & DMEM | Write known words (`0xA5A55A5A`, `0x55AA33CC`) to DMEM (`0x0001_8000`), read back | `s01_axi_wdata`, `s01_axi_rdata` | Readback identically matches written patterns | Verifies LSU-to-AXI width adaptation and DMEM SRAM retention |
| **TC-03** | Address Decode | All Peripherals | Perform 32-bit read accesses to base addresses of UART, GPIO, Timer, FIR, ADC, FFT | `m00` to `m08` AXI chip selects | Valid `OKAY` (`2'b00`) responses received; no bus hang | Verifies interconnect address routing across all active IP slots |
| **TC-04** | Error Handling | Dummy Slaves | Read from reserved / unmapped dummy slots (Watchdog `0x4000_6000`, SPI, etc.) | Interconnect `RRESP` | Returns AXI `DECERR` (`2'b11`); system recovers cleanly | Verifies dummy slave DECERR generation without CPU lockup |
| **TC-05** | Bus Stress | Interconnect Fabric| Issue 8 consecutive writes followed by 8 consecutive reads in DMEM | AXI burst/beat handshakes | All 8 data words match without pipeline corruption | Verifies interconnect buffering and arbiter throughput under burst load |
| **TC-06** | Register Config| Timer / GPIO / FIR| Write distinct bit patterns to prescaler, GPIO output, and FIR coefficient 3 | Peripheral register readback | Registers retain exact programmed values | Verifies register file read/write decoders and clocking |
| **TC-07** | ADC Capture | ADC Controller | Enable ADC scheduler, issue single-shot sample trigger, poll with timeout | `ADC_REG_STATUS`, `SAMPLE_DATA`, `FIFO_DATA` | Enable confirmed; sample retrieved if valid, or timeout handled cleanly | In simulation, external sample stimulus requires top-level pin injection |
| **TC-08** | FIR Filter | FIR Engine | Program 32-tap low-pass filter coefficients, pulse load strobe, enable engine | `FIR_REG_COEFF[0..31]`, `FIR_REG_CTRL`, `STATUS` | Coefficients retained; load strobe latches active bank; enable=1 | Streaming datapath is AXI4-Stream; software configures control interface |
| **TC-09** | FFT Data Buffer| FFT Memory Window | Write complex words to Word 0 and Word 1023 in FFT BRAM (`0x4000_A000`, `0x4000_AFFC`) | `S_AXI_WDATA`, `S_AXI_RDATA` | Complex words read back identically with correct Q1.15 packing | Verifies BRAM read/write access when accelerator is idle (`fft_busy=0`) |
| **TC-10** | FFT Control | FFT Accelerator | Preload DC vector, write start pulse to `FFT_REG_CTRL`, poll status | `FFT_REG_STATUS` (`busy`, `done_sticky`) | `fft_busy` asserts during run, deasserts upon completion; `done_sticky`=1 | Requires twiddle ROM file (`twiddle1024.mem`) in working directory |
| **TC-11** | FFT Boundary | FFT Memory Window | Write and read test pattern at extreme upper memory window bound (`0x4000_AFFC`) | Address `0x4000_AFFC` | Data matches; no address wrap-around or bus error | Verifies full 4 KiB capacity ($1024 \times 32\text{-bit}$ words) |
| **TC-12** | UART Protocol | UART Interface | Read Line Control (LCR) and Line Status (LSR); transmit diagnostic characters | `UART_REG_LSR[5]` (`THRE`), `UART_REG_THR` | LCR confirms 8N1 (`0x03`); LSR confirms THRE empty; bytes transmitted | Verifies baud divisor calculation (27 for 115200) and serial transmission |
| **TC-13** | GPIO Functions | GPIO Subsystem | Set pin direction (`DIR`), output data (`DATA_O`), atomic SET, CLR, and TGL | `GPIO_REG_DATA_O` | Register accurately reflects bit manipulation operations | Verifies atomic bitfield logic and output register drivers |
| **TC-14** | Timer Engine | Timer Subsystem | Load down-counter with 1000, enable timer, delay, read current counter | `TIMER_REG_VAL` | Counter value decreases from 1000; timer stops upon disable | Verifies clock prescaling, down-counter logic, and control enables |
| **TC-15** | Complete DSP | ADC->FIR->FFT | Execute end-to-end processing pipeline; run impulse response through FFT | Spectral bin energy distribution | Completed FFT produces non-zero spectral energy across all frequency bins | Demonstrates integrated application flow across acceleration blocks |
| **TC-16** | CPU Integration| VeeR EL2 & Interconnect | Read CPU Program Counter using `auipc` instruction; monitor fetch continuity | CPU PC register, `s00_axi_araddr` | PC resides strictly within IMEM boundary (`0x0000_0000` - `0x0000_FFFF`) | Verifies instruction fetch path through 64-to-32 adapter |
| **TC-17** | Result Retrieval| FFT & UART | Preload alternating Nyquist vector ($+A, -A \dots$); execute FFT; read bins | `FFT_BIN_ADDR(512)` vs other bins | Dominant peak identified strictly at Bin 512 ($N/2$); magnitude > 0 | Mathematically proves frequency-bin localization for known Nyquist input |
| **TC-18** | State Isolation| FFT Accelerator | Process two consecutive frames (Frame 1: DC offset; Frame 2: Square wave) | Peak bin for Frame 1 vs Frame 2 | Frame 1 peaks at Bin 0; Frame 2 peaks at Bin 16; zero stale cross-leakage | Proves hardware accelerator resets stage registers between runs |
| **TC-19** | Reset Recovery | UART & Timer | Reinitialize peripheral registers after active operations (soft reset) | Peripheral registers post-init | Peripherals return to clean idle states without lingering locks | Verifies warm reconfiguration without requiring cold chip power cycle |
| **TC-20** | Coexistence | Timer, GPIO, FFT | Run Timer down-count and GPIO toggling concurrently while FFT computes | Timer counter, GPIO data, FFT status | All peripherals complete operations without bus collision or arbitration stall | Proves multi-slave concurrency and non-interference on AXI fabric |
| **TC-21** | Interrupts | Timer & PIC Routing | Enable Timer expiry IRQ; program tiny load value; poll sticky interrupt status | `TIMER_REG_INT_STS[0]`, `extintsrc_req[3]` | Sticky interrupt flag asserts upon zero expiry; clears on W1C | Verifies interrupt generation, latching, and CPU PIC connectivity |
| **TC-22** | Bus Stress | AXI Byte Strobes | Perform 8-bit narrow writes to consecutive bytes of 32-bit DMEM word | `s01_axi_wstrb[3:0]`, 32-bit readback | Combined 32-bit word reflects all 4 byte updates (`0x44332211`) | Verifies byte-lane enable decoding across 64-to-32 bus adapter |

---

## 4. Test Pattern Definitions for FFT Verification

To verify the mathematical and operational correctness of the FFT accelerator without relying on a bulky floating-point math library in bare-metal C, six deterministic test vectors are defined:

1. **Zero Vector (Pattern 0)**:
   - $x[n] = 0 + j0$ for all $n \in [0, 1023]$.
   - Expected Output: All output bins $X[k] = 0 + j0$.
   - Purpose: Verifies zero-state convergence and noise-free baseline.
2. **DC Offset Vector (Pattern 1)**:
   - $x[n] = 16384 + j0$ ($+0.5$ in Q1.15) for all $n$.
   - Expected Output: Peak energy concentrated exclusively at Bin 0 ($X[0] \neq 0$); all AC bins $X[k > 0] \approx 0$.
   - Purpose: Verifies DC accumulation and stage-wise scaling.
3. **Nyquist Alternating Vector (Pattern 2)**:
   - $x[n] = (-1)^n \times 16384 + j0$ ($+16384, -16384, +16384 \dots$).
   - Expected Output: Peak energy concentrated exclusively at the Nyquist frequency bin $k = N/2 = 512$.
   - Purpose: Verifies highest-frequency butterfly computation and symmetry.
4. **Impulse Vector (Pattern 3)**:
   - $x[0] = 32767 + j0$; $x[n > 0] = 0$.
   - Expected Output: Flat spectrum across all 1024 bins with approximately uniform magnitude ($X[k] \approx \text{const}$).
   - Purpose: Verifies broadband excitation and impulse response.
5. **Periodic Square Wave (Pattern 4)**:
   - Period $P = 64$ samples ($f_0 = N/P = 1024/64 = 16$).
   - Expected Output: Fundamental peak at Bin 16, with odd harmonics at Bins 48, 80, 112, etc.
   - Purpose: Exercises multi-harmonic frequency resolution and harmonic detection.

---

## 5. Result Classification Criteria

Every test case executed by firmware or evaluated during review is assigned one of four definitive states:

- **PASS**: Executed by the target or checked against valid observable criteria, with actual behavior matching expected specification.
- **FAIL**: Executed and produced a detectable divergence, timeout, or incorrect numerical result.
- **BLOCKED**: Cannot be exercised in the current setup due to an unavailable external physical stimulus or missing tool dependency.
- **UNVERIFIED**: Insufficient evidence exists in the static baseline to confirm functional compliance without dynamic simulation.

---

## 6. Execution and Reporting Procedure

1. **Static Validation**: Code review of `spectrum_analyzer_firmware.c`, `spectrum_analyzer.ld`, and `start.S`.
2. **Compilation**: Execute `make` using `riscv64-unknown-elf-gcc` on the target development machine.
3. **Simulation Execution**: Load generated firmware image into IMEM and simulate in Synopsys VCS.
4. **UART Telemetry Capture**: Monitor serial output pin `uart_tx_o` to observe live execution logs and regression summary.
5. **Final Documentation**: Consolidate findings into the formal project verification report in `doc/`.
