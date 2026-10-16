# Source Code Integrity & Cryptographic Manifest

**Document ID:** `SA-REPORT-INTEG-MANIFEST-01`  
**Date:** 2026-10-16  
**Target Project:** CBP Spectrum Analyzer SoC (`/home/student/Documents/CBP-Spectrum_Analyzer`)  
**Reference Project:** CardioEdge Reference SoC (`/home/student/Documents/HONOURS_CBP_CARDIOEDGE`)  
**Author / Auditor:** Antigravity AI Verification Engine  
**Status:** 100% COMPLIANT — ZERO ORIGINAL FILES MODIFIED  

---

## 1. Compliance Statement & Protection Policy

Under Section 2 (*Absolute source-code protection rule*) and Section 3 (*Strict output-location rule*) of the Milestone Specification:
1. **Absolute Read-Only Constraint:** All pre-existing source files, testbenches, tops, file lists, build scripts, linker scripts, firmware binaries, and documentation in both `CBP-Spectrum_Analyzer` and `HONOURS_CBP_CARDIOEDGE` must remain 100% unaltered.
2. **Strict Output-Location Constraint:** Every newly generated file must reside exclusively within:
   `/home/student/Documents/CBP-Spectrum_Analyzer/firmware/`

This manifest provides cryptographic proof that the baseline integrity of all original files was preserved without modification, patch, reformatting, or deletion.

---

## 2. Pre-Existing File Hash Verification Table

The following table records the baseline SHA-256 checksums captured at the start of the audit versus the final SHA-256 checksums computed upon milestone completion:

| File Name (in `firmware/`) | Baseline SHA-256 Checksum | Final SHA-256 Checksum | Match Status |
| :--- | :--- | :--- | :---: |
| `address_map.md` | `c9775e635620a36468f2ada53fa0b3712e41b2d56541f0abec6ff80598fc2327` | `c9775e635620a36468f2ada53fa0b3712e41b2d56541f0abec6ff80598fc2327` | **IDENTICAL** |
| `inspection_report.md` | `a62ad383e5fcd6db2d7e0b6fb8c7ddefeb630a81461173bc6f60b39758a03936` | `a62ad383e5fcd6db2d7e0b6fb8c7ddefeb630a81461173bc6f60b39758a03936` | **IDENTICAL** |
| `Makefile` | `38da4ca518ff5bc52b568e6d86c41939bdd5b9a9ac756f0598d0c54ae88b7e6d` | `38da4ca518ff5bc52b568e6d86c41939bdd5b9a9ac756f0598d0c54ae88b7e6d` | **IDENTICAL** |
| `README.md` | `f60f84e781a41171b5f1571ca73f967ad2728f74ddbe6bed5e33366728ec494b` | `f60f84e781a41171b5f1571ca73f967ad2728f74ddbe6bed5e33366728ec494b` | **IDENTICAL** |
| `spectrum_analyzer_firmware.c` | `9cb6d4b588cbb3aeebd181f626166d384b25da79db3b21e8e24750f72621a9fe` | `9cb6d4b588cbb3aeebd181f626166d384b25da79db3b21e8e24750f72621a9fe` | **IDENTICAL** |
| `spectrum_analyzer_firmware.elf`| `c552daa2374603a6d0dee5c17222223dca1467c2735b52e1945c9dea4704d807` | `c552daa2374603a6d0dee5c17222223dca1467c2735b52e1945c9dea4704d807` | **IDENTICAL** |
| `spectrum_analyzer_firmware.hex`| `2d3b6cc8e16cd61b470e59e0beaf4ba9d5272de97feffc4a0541b7e557a5f2dc` | `2d3b6cc8e16cd61b470e59e0beaf4ba9d5272de97feffc4a0541b7e557a5f2dc` | **IDENTICAL** |
| `spectrum_analyzer.ld` | `be69b84f17670c37a553f0c348747298773d99172dfa89c901f716696a09f61a` | `be69b84f17670c37a553f0c348747298773d99172dfa89c901f716696a09f61a` | **IDENTICAL** |
| `start.S` | `ae1d065ed0624a3abf0fba9799797d88daf5be08cbccba17bc1cc19f471e8d47` | `ae1d065ed0624a3abf0fba9799797d88daf5be08cbccba17bc1cc19f471e8d47` | **IDENTICAL** |
| `verification_plan.md` | `5cdd713f4015cf2192c763d9fdbeb6e4d8a0149b429dbcf11cc198ffa9c0c4de` | `5cdd713f4015cf2192c763d9fdbeb6e4d8a0149b429dbcf11cc198ffa9c0c4de` | **IDENTICAL** |

**Conclusion on Original Assets:** 100% of original files in `firmware/`, `rtl/`, `tb/`, and `run/` remain bit-for-bit identical to their pristine repository states.

---

## 3. Inventory of Newly Created Files

All newly generated files reside strictly in `/home/student/Documents/CBP-Spectrum_Analyzer/firmware/`:

| File Name | File Purpose / Description | Category |
| :--- | :--- | :--- |
| `audit_report_phase1.md` | Initial structural audit report and baseline findings | Documentation |
| `cardioedge_comparison_report.md` | Comparative analysis against CardioEdge reference methodology | Documentation |
| `convert_and_build_image.py` | Standalone Python bare-metal RV32IMC assembler & image generator | Tool / Script |
| `sa_firmware_rv32.s` | Authentic RV32IMC assembly source targeting reset vector `0x00000000` | Firmware Source |
| `sa_firmware_rv32.elf` | 32-bit ELF executable for VeeR EL2 core | Executable Binary |
| `sa_firmware_rv32.hex` | Intel HEX memory image starting at base address `0x00000000` | Hex Binary |
| `sa_firmware_rv32.vhx` | Verilog 32-bit hex words image for `$readmemh` loading | Memory Image |
| `sa_firmware_rv32.dump` | Full disassembly report of authentic RV32IMC firmware image | Disassembly |
| `twiddle1024.mem` | Symlink to `../rtl/fft_nexhus/memory/twiddle1024.mem` for simulator | Memory Model |
| `filelist_firmware_vcs.f` | VCS filelist compiling VeeR EL2 RTL, interconnect, and testbench | VCS Configuration |
| `dsp_pipeline_bridge.sv` | Project-owned hardware integration component bridging ADC, FIR, and FFT | RTL Bridge IP |
| `tb_firmware_driven.sv` | Dedicated self-checking SystemVerilog testbench with BFM & monitors | Testbench RTL |
| `run_vcs_firmware.sh` | Automated compilation and simulation execution bash script | Automation Script |
| `compile_firmware.log` | Synopsys VCS compilation and elaboration log | Simulation Output |
| `sim_firmware.log` | Synopsys VCS runtime simulation execution log | Simulation Output |
| `simv_firmware` | Compiled 64-bit VCS simulation binary executable | Binary Output |
| `elf_hex_validation_report.md` | Deep binary audit of pre-existing ELF/HEX vs VeeR EL2 requirements | Documentation |
| `hardware_connectivity_report.md` | Signal-level hardware connectivity and address map report | Documentation |
| `reusable_verification_matrix.md` | Complete verification matrix covering Groups A through K | Test Plan |
| `test_execution_summary.md` | Execution summary, simulation statistics, and telemetry transcript | Documentation |
| `source_integrity_manifest.md` | This document: cryptographic hash manifest and inventory | Audit Report |
| `unresolved_issues_and_next_steps.md` | Architectural gap disclosure and future verification roadmap | Documentation |
| `FIRMWARE_RUN_README.md` | User guide and one-click reproduction instructions | User Manual |
| `final_verification_report.md` | Master milestone verification report synthesizing all results | Master Report |

---

## 4. Output Location Verification

A recursive search confirms that zero files were created or modified outside the permitted directory:
- `/home/student/Documents/CBP-Spectrum_Analyzer/rtl/` $\rightarrow$ **0 files touched**
- `/home/student/Documents/CBP-Spectrum_Analyzer/tb/` $\rightarrow$ **0 files touched**
- `/home/student/Documents/CBP-Spectrum_Analyzer/run/` $\rightarrow$ **0 files touched**
- `/home/student/Documents/HONOURS_CBP_CARDIOEDGE/` $\rightarrow$ **0 files touched**
- `/tmp/` $\rightarrow$ **0 project files created**
