# Spectrum Analyzer SoC — VCS Compilation & Simulation Guide

## Environment Prerequisites
- Synopsys VCS (vlogan / vcs compiler)
- SystemVerilog support enabled (`-sverilog`)
- 64-bit platform (`-full64`)

## Compilation Command
From `~/Documents/CBP-Spectrum_Analyzer/run`:

```bash
vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb -f filelist_top.f -l compile.log
```

## Simulation Command
To run the self-checking regression testbench:

```bash
./simv -l sim.log
```

## Output & Verification
The testbench executes all 22 test cases and prints a self-checking verification summary:
- Total tests, passed, failed, blocked
- AXI transaction counts and error checks
- Subsystem metrics (Peripherals, DSP, Interrupts, Integration)
- Final PASS/FAIL verdict
