#!/usr/bin/env bash
# ==============================================================================
# run_vcs_firmware.sh — VCS Compilation and Simulation Execution Script
# Project: CBP-Spectrum_Analyzer
# Target: tb_firmware_driven
# Location: /home/student/Documents/CBP-Spectrum_Analyzer/firmware/run_vcs_firmware.sh
# Execute from: /home/student/Documents/CBP-Spectrum_Analyzer/firmware
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "${SCRIPT_DIR}"

echo "=================================================================="
echo "    SPECTRUM ANALYZER SoC — FIRMWARE-DRIVEN VCS REGRESSION"
echo "=================================================================="

# 1. Environment & License Setup
export VCS_HOME=/home/student/snps_tools_target/vcs/U-2023.03
export PATH="${VCS_HOME}/bin:${PATH}"
export SNPSLMD_LICENSE_FILE=27021@14.139.1.126

# 2. Check for required tool
if ! command -v vcs &> /dev/null; then
    echo "[-] ERROR: Synopsys VCS not found at ${VCS_HOME}/bin/vcs"
    exit 1
fi

echo "[+] VCS toolchain detected: $(vcs -full64 -ID | grep 'Compiler version' || true)"

# 3. Check / build verified firmware images
if [ ! -f "sa_firmware_rv32.vhx" ] || [ ! -f "sa_firmware_rv32.hex" ]; then
    echo "[*] Building authentic RV32IMC firmware images..."
    python3 convert_and_build_image.py
fi

# 4. Check twiddle factors memory file
if [ ! -f "twiddle1024.mem" ]; then
    echo "[*] Creating twiddle1024.mem symlink in firmware directory..."
    ln -sf ../rtl/fft_nexhus/memory/twiddle1024.mem twiddle1024.mem
fi

# 5. VCS RTL Compilation
echo "------------------------------------------------------------------"
echo "[*] Compiling RTL and testbench with VCS..."
echo "    Command: vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb \\"
echo "                 -f filelist_firmware_vcs.f -l compile_firmware.log -o simv_firmware"
echo "------------------------------------------------------------------"

vcs -full64 -sverilog -timescale=1ns/1ps -debug_access+all -kdb \
    -f filelist_firmware_vcs.f \
    -l compile_firmware.log \
    -o simv_firmware

if [ ! -f "simv_firmware" ]; then
    echo "[-] ERROR: VCS compilation failed! Inspect compile_firmware.log"
    exit 1
fi
echo "[+] Compilation successful: simv_firmware created."

# 6. VCS Simulation Run
echo "------------------------------------------------------------------"
echo "[*] Running simulation: ./simv_firmware +VHX=sa_firmware_rv32.vhx -l sim_firmware.log"
echo "------------------------------------------------------------------"

./simv_firmware +VHX=sa_firmware_rv32.vhx -l sim_firmware.log

# 7. Check simulation completion & report status
echo "------------------------------------------------------------------"
if grep -q ">> OVERALL VERIFICATION STATUS: ALL EXECUTED TESTS PASSED <<" sim_firmware.log; then
    echo "[+] SUCCESS: All firmware-driven simulation tests passed!"
    exit 0
else
    echo "[-] FAILURE: Simulation encountered errors. Inspect sim_firmware.log"
    exit 2
fi
