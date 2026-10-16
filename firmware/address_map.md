# Spectrum Analyzer SoC — Complete Peripheral Address Map & Register Specification

**Project**: Design and RTL Implementation of a RISC-V Based Spectrum Analyzer SoC with Hardware DSP Acceleration  
**Root Path**: `/home/student/Documents/CBP-Spectrum_Analyzer`  
**Document**: `firmware/address_map.md`  
**Reference Sources**:
1. `rtl/veerall_axi_ips_top.sv` (Peripheral interconnect integration & address decoding)
2. `rtl/interconnect/axi_interconnect_wrap_3x18.v` (Interconnect address aperture decode)
3. `doc/excel sheet (address, test cases, register set, data and cntrol path).ods` (ODS Specification)
4. `rtl/Cores-VeeR-EL2/snapshots/spectrum_analyzer/common_defines.vh` (VeeR EL2 memory configuration)
5. `rtl/uart/axi_uart_top.v`, `rtl/gpio/gpio_regs.sv`, `rtl/timer/timer_regs.sv`
6. `rtl/fir/fir_axi_lite.v`, `rtl/adc/adc_registers.sv`, `rtl/fft_nexhus/fft_ctrl_axil.sv`, `rtl/fft_nexhus/fft_mem_axi4_slave.sv`

---

## 1. System Memory Map Overview

| Region / Port | Base Address | End Address | Size | AXI Type | Backing Hardware / Implementation | Source File |
|---|---|---|---|---|---|---|
| **IMEM (M07)** | `0x0000_0000` | `0x0000_FFFF` | 64 KiB | AXI4 Full | `axi_imem_slave` (Instruction SRAM, Reset Vector `0x0`) | `rtl/axi_imem_slave.sv` |
| **DMEM (M08)** | `0x0001_0000` | `0x0001_FFFF` | 64 KiB | AXI4 Full | `axi_dmem_slave` (Data SRAM, Stack & Data) | `rtl/axi_dmem_slave.sv` |
| **UART (M00)** | `0x4000_0000` | `0x4000_0FFF` | 4 KiB | AXI4-Lite | `axi_uart_top` (16550-compatible serial UART) | `rtl/uart/axi_uart_top.v` |
| **GPIO (M01)** | `0x4000_2000` | `0x4000_2FFF` | 4 KiB | AXI4-Lite | `gpio_axi` (32-bit bidirectional GPIO) | `rtl/gpio/gpio_axi.sv` |
| **Timer (M02)**| `0x4000_4000` | `0x4000_4FFF` | 4 KiB | AXI4-Lite | `timer_axi` (32-bit prescaled down-counter) | `rtl/timer/timer_axi.sv` |
| **Watchdog (M09)**| `0x4000_6000` | `0x4000_6FFF` | 4 KiB | AXI4-Lite | `axi_dummy_slave` (Returns `DECERR` `2'b11`) | `rtl/common/axi_dummy_slave.sv` |
| **FFT Control (M05)**| `0x4000_8000` | `0x4000_8FFF` | 4 KiB | AXI4-Lite | `fft_ctrl_axil` (Start, Busy, Done status) | `rtl/fft_nexhus/fft_ctrl_axil.sv` |
| **FFT Memory (M06)** | `0x4000_A000` | `0x4000_AFFF` | 4 KiB | AXI4 Full | `fft_mem_axi4_slave` (1024 complex sample BRAM) | `rtl/fft_nexhus/fft_mem_axi4_slave.sv` |
| **FIR Filter (M03)** | `0x4000_C000` | `0x4000_CFFF` | 4 KiB | AXI4-Lite | `fir_top` (32-tap coefficients, load, status) | `rtl/fir/fir_axi_lite.v` |
| **ADC Interface (M04)**| `0x4000_E000` | `0x4000_EFFF` | 4 KiB | AXI4-Lite | `adc_controller` (12-bit ADC capture, FIFO) | `rtl/adc/adc_registers.sv` |
| **SPI (M10)** | `0x4001_0000` | `0x4001_0FFF` | 4 KiB | AXI4-Lite | `axi_dummy_slave` (Returns `DECERR` `2'b11`) | `rtl/common/axi_dummy_slave.sv` |
| **QRS (M11)** | `0x4001_2000` | `0x4001_2FFF` | 4 KiB | AXI4-Lite | `axi_dummy_slave` (Returns `DECERR` `2'b11`) | `rtl/common/axi_dummy_slave.sv` |
| **AES-128 (M12)**| `0x4001_4000` | `0x4001_4FFF` | 4 KiB | AXI4-Lite | `axi_dummy_slave` (Returns `DECERR` `2'b11`) | `rtl/common/axi_dummy_slave.sv` |
| **Int Aggr (M13)**| `0x4001_6000` | `0x4001_6FFF` | 4 KiB | AXI4-Lite | `axi_dummy_slave` (Returns `DECERR` `2'b11`) | `rtl/common/axi_dummy_slave.sv` |
| **PWM (M14)** | `0x4001_8000` | `0x4001_8FFF` | 4 KiB | AXI4-Lite | `axi_dummy_slave` (Returns `DECERR` `2'b11`) | `rtl/common/axi_dummy_slave.sv` |
| **I2C (M15)** | `0x4001_A000` | `0x4001_AFFF` | 4 KiB | AXI4-Lite | `axi_dummy_slave` (Returns `DECERR` `2'b11`) | `rtl/common/axi_dummy_slave.sv` |
| **DMA (M16)** | `0x4001_C000` | `0x4001_CFFF` | 4 KiB | AXI4-Lite | `axi_dummy_slave` (Returns `DECERR` `2'b11`) | `rtl/common/axi_dummy_slave.sv` |
| **Reserved (M17)**| `0x4001_E000` | `0x4001_EFFF` | 4 KiB | AXI4-Lite | `axi_dummy_slave` (Returns `DECERR` `2'b11`) | `rtl/common/axi_dummy_slave.sv` |

---

## 2. Detailed Software-Visible Register Maps

### 2.1 UART Interface (`0x4000_0000`)
**Source**: `rtl/uart/axi_uart_top.v`, shadowed in `rtl/veerall_axi_ips_top.sv`

| Offset | Register Name | Access | Reset | Description / Bitfields |
|---|---|---|---|---|
| `+0x00` | `UART_RBR` | RO | `0x00` | Receive Buffer Register: Bits `[7:0]` receive character (when DLAB=0). |
| `+0x00` | `UART_THR` | WO | `0x00` | Transmitter Holding Register: Bits `[7:0]` byte to transmit (when DLAB=0). |
| `+0x04` | `UART_IER` | RW | `0x00` | Interrupt Enable Register: Bit `[0]` = RX Data Ready IRQ, Bit `[1]` = TX Empty IRQ. |
| `+0x08` | `UART_BAUD_DIV` | WO | `0x00` | Baud Rate Divisor: 32-bit divisor ($50\text{ MHz} / (16 \times \text{Baud})$). For 115200: write `27` (`0x1B`). |
| `+0x0C` | `UART_LCR` | RW | `0x00` | Line Control Register: Bits `[1:0]` = Word length (`2'b11` = 8 bits). Bit `[2]` = Stop bits (`0` = 1 bit). Bits `[5:3]` = Parity (`0` = none). Standard 8N1 = `0x03`. Write shadowed in `veerall_axi_ips_top.sv`. |
| `+0x14` | `UART_LSR` | RO | `0x60` | Line Status Register: Bit `[0]` (`DR`): Data Ready in RX FIFO. Bit `[5]` (`THRE`): Transmitter Holding Register Empty (ready for next character). Bit `[6]` (`TEMT`): Transmitter completely empty. |

---

### 2.2 GPIO Interface (`0x4000_2000`)
**Source**: `rtl/gpio/gpio_regs.sv`, `rtl/gpio/gpio_axi.sv`

| Offset | Register Name | Access | Reset | Description / Bitfields |
|---|---|---|---|---|
| `+0x00` | `GPIO_DATA_I` | RO | External | Input Pin State: Bits `[31:0]` debounced external logic levels on `gpio_io`. |
| `+0x04` | `GPIO_DATA_O` | RW | `0x00` | Output Pin State: Bits `[31:0]` output levels driven when pin direction is output. |
| `+0x08` | `GPIO_DIR` | RW | `0x00` | Pin Direction: Bits `[31:0]` (`1` = Output, `0` = Input). Default reset: all inputs (`0x00000000`). |
| `+0x0C` | `GPIO_INT_EN` | RW | `0x00` | Interrupt Enable: Bits `[31:0]` per-pin interrupt generation mask. |
| `+0x10` | `GPIO_INT_TYP` | RW | `0x00` | Interrupt Type: Bits `[31:0]` (`1` = Edge-sensitive, `0` = Level-sensitive). |
| `+0x14` | `GPIO_INT_POL` | RW | `0x00` | Interrupt Polarity: Bits `[31:0]` (`1` = Rising edge / High level, `0` = Falling edge / Low level). |
| `+0x18` | `GPIO_INT_ANY` | RW | `0x00` | Any Edge Enable: Bits `[31:0]` (`1` = Interrupt on both edges). |
| `+0x1C` | `GPIO_INT_STS` | R/W1C | `0x00` | Interrupt Status: Bits `[31:0]` sticky active interrupt flags; write 1 to clear. |
| `+0x20` | `GPIO_SET_O` | WO | N/A | Atomic Bit Set: Writing bit $n=1$ sets bit $n$ in `GPIO_DATA_O` without read-modify-write. |
| `+0x24` | `GPIO_CLR_O` | WO | N/A | Atomic Bit Clear: Writing bit $n=1$ clears bit $n$ in `GPIO_DATA_O`. |
| `+0x28` | `GPIO_TGL_O` | WO | N/A | Atomic Bit Toggle: Writing bit $n=1$ inverts bit $n$ in `GPIO_DATA_O`. |
| `+0x2C` | `GPIO_DEB_TH` | RW | `0x00` | Debounce Threshold: 32-bit clock cycle debounce filter count. |
| `+0x30` | `GPIO_DEB_EN` | RW | `0x00` | Debounce Enable: Bits `[31:0]` per-pin debounce filter enable. |

---

### 2.3 General Purpose Timer Interface (`0x4000_4000`)
**Source**: `rtl/timer/timer_regs.sv`, `rtl/timer/timer_axi.sv`

| Offset | Register Name | Access | Reset | Description / Bitfields |
|---|---|---|---|---|
| `+0x00` | `TIMER_CTRL` | RW | `0x00` | Control Register: Bit `[0]` (`EN`): Timer enable. Bit `[1]` (`MODE`): `0` = One-shot, `1` = Periodic/auto-reload. Bit `[2]` (`PRE_EN`): Prescaler enable. Bit `[3]` (`DIR`): `0` = Down-count, `1` = Up-count. Bit `[4]` (`PWM_EN`): PWM output enable. Bit `[5]` (`EXT_EN`): External measurement enable. Bit `[6]` (`CAP_EN`): Input capture enable. |
| `+0x04` | `TIMER_LOAD` | RW | `0x00` | Timer Load Value: 32-bit load value. Writing immediately loads the counter. |
| `+0x08` | `TIMER_VAL` | RO | `0x00` | Current Counter Value: 32-bit real-time running counter. |
| `+0x0C` | `TIMER_PRE` | RW | `0x00` | Prescaler Value: Bits `[15:0]` 16-bit clock prescaler divide value. |
| `+0x10` | `TIMER_INT_EN` | RW | `0x00` | Interrupt Enable: Bit `[0]` = Timer expiry IRQ enable. Bit `[1]` = Capture event IRQ enable. |
| `+0x14` | `TIMER_INT_STS` | R/W1C | `0x00` | Interrupt Status: Bit `[0]` = Sticky timer expiry flag. Write 1 to clear. |
| `+0x18` | `TIMER_CMP` | RW | `0x00` | PWM Compare Value: 32-bit threshold for PWM duty cycle match. |
| `+0x1C` | `TIMER_CAP` | RO | `0x00` | Capture Value: 32-bit captured counter value on external event. |

---

### 2.4 FFT Accelerator Control & Status (`0x4000_8000`)
**Source**: `rtl/fft_nexhus/fft_ctrl_axil.sv`

| Offset | Register Name | Access | Reset | Description / Bitfields |
|---|---|---|---|---|
| `+0x00` | `FFT_REG_CTRL` | RW | `0x00` | Control Register: Writing Bit `[0]` = 1 generates a 1-cycle `start_pulse` to initiate 1024-point FFT. Software must verify `fft_busy == 0` before writing; writing while busy returns `SLVERR`. Read returns `0x00000000`. |
| `+0x04` | `FFT_REG_STATUS`| RO | `0x00` | Status Register: Bit `[0]` (`done_sticky`): Latches high when 10th FFT stage completes. Cleared when new start command is issued. Bit `[1]` (`fft_busy`): Asserted during active butterfly computation (~2,976 cycles). Bits `[31:2]` reserved (read as 0). |
| Other | Unmapped | RW | N/A | Any access to offsets other than `0x00` or `0x04` returns `SLVERR` (`0xDEADBEEF` on read). |

---

### 2.5 FFT Accelerator Memory Window (`0x4000_A000` - `0x4000_AFFF`)
**Source**: `rtl/fft_nexhus/fft_mem_axi4_slave.sv`, `rtl/fft_nexhus/bram_memeory.sv`

- **Aperture Size**: 4 KiB ($1024 \times 32\text{-bit}$ words).
- **Address Bounds**: `0x4000_A000` (Word 0 / Bin 0) to `0x4000_AFFC` (Word 1023 / Bin 1023).
- **Data Packing**:
  - `[31:16]`: Signed 16-bit **Real** part ($Q1.15$ format, two's complement).
  - `[15:0]`: Signed 16-bit **Imaginary** part ($Q1.15$ format, two's complement).
- **Dual-Purpose Pre/Post Processing**:
  - Before Start: Firmware writes 1024 complex time-domain input samples into this window.
  - After Done: Firmware reads 1024 complex frequency-domain bins from this window.
- **Safety Restriction**: Hardware enforces `S_AXI_AWREADY <= !fft_busy` and `S_AXI_ARREADY <= !fft_busy`. **Never access this window while `fft_busy == 1`** as it will stall the AXI bus!

---

### 2.6 FIR Filter Subsystem (`0x4000_C000`)
**Source**: `rtl/fir/fir_axi_lite.v`, `rtl/fir/fir_top.v`

| Offset | Register Name | Access | Reset | Description / Bitfields |
|---|---|---|---|---|
| `+0x00` | `FIR_REG_CTRL` | RW | `0x00` | Filter Control: Bit `[0]` (`ENABLE`): 1 = Enable FIR processing engine; 0 = Disabled. |
| `+0x04` | `FIR_REG_LOAD` | WO | `0x00` | Coefficient Load Strobe: Writing Bit `[0]` = 1 latches shadow `coeff_reg[0..31]` into the active processing bank `active_coeff_reg[0..31]`. Read returns 0. |
| `+0x08` | `FIR_REG_STATUS` | RO | `0x0A` | FIFO Status: Bit `[0]`: Input FIFO Full. Bit `[1]`: Input FIFO Empty (Reset = 1). Bit `[2]`: Output FIFO Full. Bit `[3]`: Output FIFO Empty (Reset = 1). |
| `+0x10 + 4*n`| `FIR_REG_COEFF(n)`| RW | `0x00` | Tap Coefficient $n$ ($n = 0 \dots 31$): Bits `[15:0]` signed 16-bit filter weight in $Q1.15$ format. Offset range: `0x4000_C010` to `0x4000_C08C`. |

---

### 2.7 ADC Capture Interface (`0x4000_E000`)
**Source**: `rtl/adc/adc_registers.sv`, `rtl/adc/adc_pkg.sv`, `rtl/adc/adc_controller.sv`

| Offset | Register Name | Access | Reset | Description / Bitfields |
|---|---|---|---|---|
| `+0x00` | `ADC_REG_CTRL` | RW | `0x00` | Control Register: Bit `[0]` (`ENABLE`): Scheduler and acquisition enable. Bit `[1]` (`START`): Software acquisition trigger pulse. |
| `+0x04` | `ADC_REG_STATUS`| R/W1C | `0x04` | Status Register: Bit `[0]` (`BUSY`): Acquisition active. Bit `[1]` (`DONE`): Sample captured (R/W1C). Bit `[2]` (`FIFO_EMPTY`): FIFO empty flag (Reset = 1). Bit `[3]` (`FIFO_FULL`): FIFO full flag. Bit `[4]` (`OVERRUN`): FIFO overrun flag (R/W1C). Bit `[5]` (`REQERR`): Request error flag (R/W1C). |
| `+0x08` | `ADC_REG_SAMPLE_DATA`| RO | `0x00` | Sample Data: Bits `[11:0]` latest captured 12-bit ADC conversion result. |
| `+0x0C` | `ADC_REG_FIFO_DATA` | RO | `0x00` | FIFO Data: Bits `[11:0]` top sample from the 32-entry FIFO. Reading pops FIFO. |
| `+0x10` | `ADC_REG_IRQ_EN`| RW | `0x00` | Interrupt Enable: Bit `[0]`: Sample ready IRQ enable. Bit `[1]`: Overrun IRQ enable. |

---

## 3. Dummy / Reserved Slaves (`DECERR` Verification)

The following addresses route to instances of `axi_dummy_slave.sv`, which respond with `DECERR` (`2'b11`):
- `0x4000_6000`: Watchdog Timer aperture
- `0x4001_0000`: SPI aperture
- `0x4001_2000`: QRS Detector aperture
- `0x4001_4000`: AES-128 aperture
- `0x4001_6000`: Interrupt Aggregator aperture
- `0x4001_8000`: PWM aperture
- `0x4001_A000`: I2C aperture
- `0x4001_C000`: DMA aperture
- `0x4001_E000`: Reserved / Future expansion aperture

Firmware verifies that reading or writing any of these regions generates an intentional decode error without causing a system lockup.
