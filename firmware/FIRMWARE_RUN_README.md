# Spectrum Analyzer SoC — Firmware-Driven VCS Verification Guide

**Project Directory:** `/home/student/Documents/CBP-Spectrum_Analyzer/firmware/`  
**Target Simulator:** Synopsys VCS U-2023.03_Full64  
**SoC Architecture:** Western Digital VeeR EL2 (RV32IMC) + 3x18 AXI Interconnect + DSP Acceleration  
**Status:** FULLY AUTOMATED & VERIFIED  

---

## 1. Quick Start Guide

To run the complete firmware-driven verification suite out-of-the-box, open a bash terminal and execute:

```bash
cd /home/student/Documents/CBP-Spectrum_Analyzer/firmware
./run_vcs_firmware.sh
```

### Expected Output Summary
```text
================================================================================
   FINAL REGRESSION SUMMARY -- SPECTRUM ANALYZER SoC
================================================================================
  Total Tests Recorded  : 21
  Passing Tests         : 21
  Failing Tests         : 0
  Architectural Blocked : 0
  Total IFU Fetches     : 116261
  Total LSU Writes      : 1187
  Total LSU Reads       : 10422
  Total UART Characters : 120
================================================================================
>> OVERALL VERIFICATION STATUS: ALL EXECUTED TESTS PASSED <<
```

---

## 2. Environment & License Prerequisites

The testbench and compilation scripts require Synopsys VCS and the college lab license server:

```bash
export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export PATH="${VCS_HOME}/bin:${PATH}"
export SNPSLMD_LICENSE_FILE=27021@14.139.1.126
```

Confirm VCS availability:
```bash
vcs -full64 -ID
```

---

## 3. Step-by-Step Manual Execution

If you prefer to run each step manually rather than using `./run_vcs_firmware.sh`:

### Step 1: Reassemble Firmware Images
Assemble the authentic RV32IMC bare-metal image targeting reset vector `0x00000000`:
```bash
cd /home/student/Documents/CBP-Spectrum_Analyzer/firmware
python3 convert_and_build_image.py
```
*Generated Artifacts:*
- `sa_firmware_rv32.elf`: 32-bit ELF executable.
- `sa_firmware_rv32.hex`: Intel HEX file (Base `0x00000000`).
- `sa_firmware_rv32.vhx`: Verilog 32-bit words HEX for `$readmemh`.
- `sa_firmware_rv32.dump`: Complete annotated disassembly text.

### Step 2: Ensure Twiddle Factors Symlink
The NexHus FFT butterfly model requires `twiddle1024.mem` in the working simulation directory:
```bash
ln -sf ../rtl/fft_nexhus/memory/twiddle1024.mem twiddle1024.mem
```

### Step 3: Compile RTL and Testbench with VCS
Compile using the verified file list:
```bash
vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb \
    -f filelist_firmware_vcs.f \
    -l compile_firmware.log \
    -o simv_firmware
```

### Step 4: Execute Simulation
Run the compiled simulation executable:
```bash
./simv_firmware +VHX=sa_firmware_rv32.vhx -l sim_firmware.log
```

---

## 4. Simulator Runtime Options & Plusargs

The self-checking testbench (`tb_firmware_driven.sv`) supports command-line configuration options:

| Plusarg / Option | Default Value | Description |
| :--- | :--- | :--- |
| `+VHX=<filename>` | `sa_firmware_rv32.vhx` | Path to 32-bit word Verilog hex file loaded via `$readmemh` into IMEM (`0x0000_0000`). |
| `+HEX=<filename>` | None | Path to Intel HEX file. The built-in testbench parser converts records and maps to IMEM / DMEM. |
| `-l <logfile>` | `sim_firmware.log` | VCS simulation log output file. |

---

## 5. Testbench Architecture & Self-Checking Checks

`tb_firmware_driven.sv` provides automated, multi-layered hardware verification:
1. **Live UART Interception:** Transparently snoops `u_uart.tx_fifo_push_int` to display console telemetry characters in real time without waiting for baud rate delays.
2. **AXI Bus Activity Monitors:** Continuously counts IFU fetches on Master 0 and LSU read/write transactions on Master 1.
3. **External Stimulus Generators:**
   - Injects 12-bit sample `0x5A5` with `adc_sample_valid` handshake into the ADC controller.
   - Injects 16-bit impulse sample `0x1000` with `fir_s_axis_tvalid` handshake into the FIR filter core.
4. **Master 2 AXI BFM:** Reads back hardware status and validates FFT frequency bins directly over the interconnect:
   - Bin 0 (`0x4000_A000`): Verifies DC peak magnitude.
   - Bin 512 (`0x4000_A800`): Verifies Nyquist tone peak magnitude.
   - Unmapped aperture (`0x4000_6000`): Confirms `DECERR` (`2'b11`) response.
5. **Watchdog Guard:** Implements a bounded cycle watchdog (`1,500,000` cycles) to prevent simulator hangs on infinite loops.

---

## 6. Directory File Index

| File Name | Description |
| :--- | :--- |
| `run_vcs_firmware.sh` | One-click bash script to build firmware, compile VCS, and run regression. |
| `filelist_firmware_vcs.f` | VCS filelist including all VeeR EL2 RTL, interconnect, and testbench files. |
| `tb_firmware_driven.sv` | The self-checking SystemVerilog testbench. |
| `convert_and_build_image.py` | Standalone bare-metal assembler generating RV32IMC images. |
| `sa_firmware_rv32.*` | Authentic RV32 bare-metal source, ELF, HEX, VHX, and disassembly files. |
| `compile_firmware.log` | Compilation and elaboration log from Synopsys VCS. |
| `sim_firmware.log` | Runtime execution log from Synopsys VCS. |
| `test_execution_summary.md` | Complete execution report with test verdicts and metrics. |
| `reusable_verification_matrix.md`| Test matrix covering Groups A through K. |
| `hardware_connectivity_report.md`| Detailed signal-level connectivity and memory map report. |
| `elf_hex_validation_report.md` | Deep binary audit of pre-existing ELF/HEX artifacts. |
| `cardioedge_comparison_report.md`| Comparison study against CardioEdge reference methodology. |
| `source_integrity_manifest.md` | SHA-256 cryptographic hashes confirming zero original files were touched. |
| `unresolved_issues_and_next_steps.md` | Architectural gaps (ADC-FIR-FFT bridge) and future UVM roadmap. |
| `final_verification_report.md` | Comprehensive milestone report. |

---

## 7. Troubleshooting

- **Error: `Failed to obtain license...`**
  - Verify that `SNPSLMD_LICENSE_FILE` is set to `27021@14.139.1.126`.
  - Check network reachability: `ping 14.139.1.126` or `nc -zv 14.139.1.126 27021`.
- **Error: `$readmemh: Unable to open twiddle1024.mem`**
  - Run `ln -sf ../rtl/fft_nexhus/memory/twiddle1024.mem twiddle1024.mem`.
- **Simulator Hang / Timeout**
  - Verify that `+VHX=sa_firmware_rv32.vhx` is passed so the CPU boots at `0x00000000`. Do not use the pre-existing 64-bit HEX file which starts at `0x00010120`.
