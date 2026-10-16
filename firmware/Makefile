# ==============================================================================
# SPECTRUM ANALYZER SoC — BARE-METAL FIRMWARE MAKEFILE
# Target: Western Digital VeeR EL2 Core (RV32IMC / Zba, Zbb, Zbc, Zbs)
# ==============================================================================

# Toolchain configuration (default to 64-bit multi-lib or 32-bit cross compiler)
CROSS_COMPILE ?= riscv64-unknown-elf-
ifeq ($(shell which $(CROSS_COMPILE)gcc 2>/dev/null),)
CROSS_COMPILE := riscv32-unknown-elf-
endif

CC            := $(CROSS_COMPILE)gcc
OBJCOPY       := $(CROSS_COMPILE)objcopy
OBJDUMP       := $(CROSS_COMPILE)objdump
SIZE          := $(CROSS_COMPILE)size

# Target Architecture & Application Binary Interface (ABI)
# VeeR EL2 is RV32IMC. The toolchain MUST target 32-bit integer, multiply, compressed.
ARCH_FLAGS    := -march=rv32imc -mabi=ilp32

# Compilation and Linker Flags
CFLAGS        := $(ARCH_FLAGS) -O2 -g -ffreestanding -nostdlib -Wall -Wextra
LDFLAGS       := -T spectrum_analyzer.ld -nostdlib -Wl,--gc-sections

# Target Binary Outputs
TARGET        := spectrum_analyzer_firmware
ELF           := $(TARGET).elf
BIN           := $(TARGET).bin
HEX           := $(TARGET).hex
VHX           := $(TARGET).vhx
DUMP          := $(TARGET).dump

# Source Files
SRCS_S        := start.S
SRCS_C        := spectrum_analyzer_firmware.c
LDSCRIPT      := spectrum_analyzer.ld

.PHONY: all clean elf bin hex vhx disassemble size help

# Default target
all: $(ELF) hex vhx bin disassemble size
	@echo "========================================================"
	@echo "Spectrum Analyzer Firmware Build Successful:"
	@echo "  ELF Executable : $(ELF)"
	@echo "  Raw Binary     : $(BIN)"
	@echo "  Intel HEX      : $(HEX)"
	@echo "  Verilog HEX    : $(VHX) (for \$$readmemh simulation)"
	@echo "  Disassembly    : $(DUMP)"
	@echo "========================================================"

elf: $(ELF)

$(ELF): $(SRCS_S) $(SRCS_C) $(LDSCRIPT)
	@if [ -z "$$(which $(CC) 2>/dev/null)" ]; then \
		echo "[-] ERROR: RISC-V GCC cross-compiler ($(CC)) not found in PATH."; \
		echo "    Please run on the college PC or load the toolchain module:"; \
		echo "    e.g., 'module load riscv-toolchain' or export PATH=/opt/riscv/bin:\$$PATH"; \
		exit 1; \
	fi
	$(CC) $(CFLAGS) $(LDFLAGS) -o $@ $(SRCS_S) $(SRCS_C)

hex: $(HEX)
$(HEX): $(ELF)
	$(OBJCOPY) -O ihex $< $@

vhx: $(VHX)
$(VHX): $(ELF)
	$(OBJCOPY) -O verilog $< $@

bin: $(BIN)
$(BIN): $(ELF)
	$(OBJCOPY) -O binary $< $@

disassemble: $(DUMP)
$(DUMP): $(ELF)
	$(OBJDUMP) -d -S $< > $@

size: $(ELF)
	@echo "=== Firmware Section Memory Utilization ==="
	$(SIZE) $<

clean:
	rm -f $(ELF) $(BIN) $(HEX) $(VHX) $(DUMP)
	rm -rf build output

help:
	@echo "Spectrum Analyzer Firmware Build Targets:"
	@echo "  make              - Build all targets (ELF, HEX, VHX, BIN, DUMP)"
	@echo "  make elf          - Compile ELF executable ($(ELF))"
	@echo "  make hex          - Generate Intel HEX format ($(HEX))"
	@echo "  make vhx          - Generate Verilog HEX format ($(VHX) for \$$readmemh)"
	@echo "  make bin          - Generate flat binary image ($(BIN))"
	@echo "  make disassemble  - Generate assembly dump with C interleave ($(DUMP))"
	@echo "  make size         - Report memory footprint with $(SIZE)"
	@echo "  make clean        - Remove all compiled artifacts"
