# Design and RTL Implementation of a RISC-V-Based Spectrum Analyzer SoC with Hardware DSP Acceleration

## 1. Project Overview

This project focuses on the design and RTL implementation of a **RISC-V-based Spectrum Analyzer System-on-Chip (SoC) with hardware Digital Signal Processing (DSP) acceleration**.

The system combines a RISC-V processor, an AXI-based system interconnect, dedicated DSP accelerator IPs, memory interfaces, and peripheral controllers to develop a hardware platform for spectrum analysis.

The processor provides the programmable control and configuration interface, while dedicated hardware blocks perform signal acquisition and digital signal processing. This hardware/software partitioning is intended to reduce the computational burden on the processor for operations such as digital filtering and frequency-domain analysis.

The project is being developed using Verilog/SystemVerilog RTL, simulation-based verification, and Synopsys VCS. The CHIPS Alliance VeeR EL2 RISC-V core is included as a Git submodule for processor integration.

### Project Details

| Attribute                | Description                  |
| ------------------------ | ---------------------------- |
| Project Type             | Honours Project / SoC Design |
| Application              | Digital Spectrum Analysis    |
| Processor Architecture   | RISC-V                       |
| Processor IP             | CHIPS Alliance VeeR EL2      |
| System Interconnect      | AXI4-based                   |
| RTL Languages            | Verilog and SystemVerilog    |
| Verification Environment | SystemVerilog testbenches    |
| Simulator                | Synopsys VCS                 |
| Version Control          | Git and GitHub               |

## 2. Motivation

Spectrum analysis is used to study the frequency components present in a sampled signal. A conventional software-only implementation may require the processor to perform multiple computationally intensive operations for every block of samples.

This project explores a hardware-accelerated approach in which dedicated RTL modules handle signal acquisition, digital filtering, and Fast Fourier Transform (FFT) processing, while the RISC-V processor manages configuration, control, and result retrieval.

The primary objectives are:

* Integrate a RISC-V processor into a modular SoC architecture.
* Develop an AXI4-based communication infrastructure for connecting processing and peripheral IPs.
* Integrate dedicated ADC interface, FIR filter, and FFT accelerator modules.
* Provide software-accessible control and status registers for peripheral configuration.
* Support data storage and retrieval through memory-mapped interfaces.
* Integrate UART, GPIO, and timer peripherals.
* Develop simulation testbenches to verify individual interfaces and progressively validate the integrated design.

## 3. Proposed System Architecture

The intended system contains the following major components:

1. **VeeR EL2 RISC-V Processor** – provides programmable control and system-level execution.
2. **AXI4 Interconnect** – routes memory and peripheral transactions between connected master and slave interfaces.
3. **ADC Interface** – receives digitized samples from an external ADC and provides sample acquisition and control logic.
4. **FIR Filter Accelerator** – performs finite impulse response filtering on the acquired samples.
5. **FFT Accelerator** – transforms time-domain sample data into frequency-domain results.
6. **Instruction Memory** – stores the program instructions executed by the processor.
7. **Data Memory** – stores input samples, intermediate data, and processed results.
8. **UART** – provides serial communication for control, debugging, and result transfer to a host computer.
9. **GPIO** – provides general-purpose digital input/output.
10. **Timer** – provides timer-related control and status functionality.

### High-Level Signal Processing Flow

```text
        External Analog Signal
                  |
                  v
          External ADC Device
                  |
                  v
           ADC Interface IP
                  |
                  v
            FIR Filter IP
                  |
                  v
             FFT Accelerator
                  |
                  v
              Data Memory
                  ^
                  |
          RISC-V Processor
                  |
          AXI4 System Fabric
                  |
       +----------+----------+
       |          |          |
       v          v          v
     UART        GPIO       Timer
       |
       v
     Host PC
```

**Important architectural distinction:** The signal-processing path represents the intended functional flow. The processor, memories, interconnect, and individual IPs must be connected and verified through their actual RTL interfaces. The diagram is a conceptual system overview, not evidence that every connection has already been validated.

## 4. Hardware Architecture

### 4.1 VeeR EL2 RISC-V Processor

The project uses the VeeR EL2 processor from the CHIPS Alliance repository.

The processor is intended to execute control software, configure the accelerator registers, manage memory accesses, and retrieve processed results. Processor integration requires the appropriate VeeR configuration, generated include files, RTL source list, reset and clock connections, and compatible AXI interfaces.

The upstream processor implementation is maintained separately and included in this repository as a Git submodule.

Repository: https://github.com/chipsalliance/Cores-VeeR-EL2

### 4.2 AXI4 Interconnect

The AXI4 interconnect provides the communication infrastructure for connecting processor-side masters and memory-mapped peripheral targets.

The project RTL includes an interconnect wrapper and associated arbitration logic. The interconnect is intended to support address-based transaction routing between the connected IPs.

The integration involves:

* AXI read-address and read-data channels.
* AXI write-address, write-data, and write-response channels.
* Address decoding and target selection.
* Arbitration between requesting masters.
* Transaction handshaking and response handling.
* Integration of peripheral interfaces and memory-access paths.

The current interconnect RTL uses a 32-bit data path. The VeeR EL2 AXI interfaces use 64-bit data paths in the inspected configuration. Consequently, processor integration requires explicit interface-width compatibility analysis and, where necessary, appropriate width adaptation or bridging. A direct connection must not be assumed to be valid solely because both interfaces use AXI.

### 4.3 ADC Interface

The ADC interface forms the input stage of the spectrum analyzer.

Its RTL includes sample acquisition, scheduling, FIFO, register, and controller logic. The external ADC is responsible for converting the analog input into digital samples; the ADC interface receives those samples and manages their acquisition and availability to downstream processing logic.

The ADC-related RTL includes:

* ADC package and definitions.
* Sample acquisition logic.
* Sampling scheduler.
* FIFO storage.
* Register interface.
* ADC controller.
* AXI-Lite slave interface.

The exact sampling rate, ADC resolution, and external ADC timing requirements depend on the selected ADC hardware and system configuration.

### 4.4 FIR Filter Accelerator

The FIR filter performs digital filtering on the acquired samples before frequency analysis.

The project includes FIR processing logic and memory-mapped control interfaces. The filter is intended to suppress unwanted signal components and condition the input data before it reaches the FFT stage.

The FIR subsystem contains:

* FIR DSP processing logic.
* FIFO support.
* AXI-Lite register/control interface.
* Top-level integration logic.

Filter coefficients, input sample format, arithmetic precision, filter length, and throughput depend on the implemented FIR configuration.

### 4.5 FFT Accelerator

The FFT accelerator performs frequency-domain transformation of the filtered sample data.

The project contains RTL for the FFT processing stages, control logic, arithmetic operations, memory interfaces, and twiddle-factor storage.

The FFT-related modules include:

* FFT top-level logic.
* FFT stage processing core.
* FFT stage controller.
* FFT control and AXI-Lite interface.
* FFT load/store wrapper.
* FFT memory-mapped AXI4 slave.
* Complex multiplication and arithmetic support.
* Twiddle-factor ROM.
* Memory and simulation support models.

The accelerator is intended to make frequency analysis available through a hardware processing path rather than requiring the processor to execute every FFT operation in software.

FFT length, numerical representation, scaling behavior, and performance must be taken from the implemented RTL and its verification results.

### 4.6 UART

The UART provides serial communication between the SoC and a host computer.

The UART subsystem includes the transmitter, receiver, controller, parity logic, FIFO support, and AXI-facing top-level interface.

Its memory-mapped register interface supports configuration, data transmission/reception, and status access. The intended use includes debugging, processor interaction, and transferring spectrum-analysis results to a host application.

### 4.7 GPIO

The GPIO subsystem provides general-purpose digital input/output through memory-mapped registers.

It includes GPIO bit-level logic, register logic, wrapper logic, and an AXI-facing interface.

The peripheral can be used for basic digital control and status signaling, depending on the configured implementation.

### 4.8 Timer

The timer subsystem provides timer-related functionality through a memory-mapped interface.

Its RTL includes timer core logic, timer registers, and an AXI interface. The processor can use the timer for control operations and time-related software tasks, subject to the implemented register behavior.

## 5. Memory Map and Address Allocation

The following address allocation is specified for the project.

| Component          |  Base Address | Address Range / Allocation |
| ------------------ | ------------: | -------------------------- |
| Instruction Memory | `0x0000_0000` | `0x0000_0000–0x0000_FFFF`  |
| Data Memory        | `0x1000_0000` | `0x1000_0000–0x1000_FFFF`  |
| UART               | `0x4000_0000` | Peripheral address space   |
| Timer              | `0x4000_1000` | Peripheral address space   |
| GPIO               | `0x4000_2000` | Peripheral address space   |
| ADC Interface      | `0x4000_3000` | Peripheral address space   |
| FIR Filter         | `0x4000_4000` | Peripheral address space   |
| FFT Accelerator    | `0x4000_5000` | Peripheral address space   |

The general peripheral region is specified as `0x4000_0000–0x4FFF_FFFF`.

### Data Memory Allocation

The following subregions are designated for signal-processing data:

| Purpose              | Address Range             |
| -------------------- | ------------------------- |
| Working / Input Data | `0x1000_0000–0x1000_0FFF` |
| FFT Output Data      | `0x1000_1000–0x1000_17FF` |

These addresses describe the project-level allocation. The final address decoder, memory implementation, access widths, and peripheral register offsets must be consistent with the integrated RTL.

## 6. RTL Repository Structure

The repository is organized into subsystem-specific RTL directories, documentation, and simulation files.

```text
CBP-Spectrum_Analyzer/
|
+-- doc/
|   +-- Project specifications
|   +-- AES register-set documentation
|   +-- Interface and IP documentation
|   +-- Supporting diagrams and reference material
|
+-- rtl/
|   +-- Cores-VeeR-EL2/       # VeeR EL2 Git submodule
|   +-- adc/                  # ADC interface and acquisition logic
|   +-- aes_axi_slave/        # AXI-compatible AES IP interface
|   +-- common/               # Common AXI adapters and bridges
|   +-- fft_nexhus/           # FFT accelerator RTL
|   +-- fir/                  # FIR filter RTL
|   +-- gpio/                 # GPIO peripheral RTL
|   +-- interconnect/         # AXI interconnect and arbitration
|   +-- timer/                # Timer peripheral RTL
|   +-- uart/                 # UART RTL and support files
|   +-- soc_uart_fft_top.v
|   +-- soc_uart_fft_adc_top.v
|   +-- soc_uart_fft_top_fir_integrated.v
|   +-- soc_uart_fft_fir_adc_gpio_timer_top.sv
|
+-- run/
|   +-- filelist.f           

|
+-- tb/
|   +-- Testbench sources
|
+-- .gitmodules
+-- README.md
```

The exact files present in each directory may evolve as the design is integrated. The file list used for a particular simulation determines which modules and testbench are compiled for that run.

## 7. Development Environment

The project has been developed in a Linux-based EDA environment.

| Tool / Technology       | Purpose                                    |
| ----------------------- | ------------------------------------------ |
| Linux                   | RTL development and simulation environment |
| Verilog                 | RTL design                                 |
| SystemVerilog           | RTL design and testbenches                 |
| Synopsys VCS            | RTL compilation and simulation             |
| Verdi                   | Waveform/debug support, where available    |
| Git                     | Source version control                     |
| GitHub                  | Remote repository and collaboration        |
| CHIPS Alliance VeeR EL2 | RISC-V processor IP                        |

The exact simulator version, VeeR configuration, and EDA tool setup are environment-dependent.


## 8. Documentation

The `doc/` directory contains project specifications and supporting documentation associated with the development of the SoC and its IP interfaces.

Refer to the relevant specification documents and RTL source files for implementation-specific details, including register definitions, interface widths, timing assumptions, and module behavior.

## 9. Repository and References

**Project repository:**
https://github.com/tpranavi18/CBP-Spectrum_Analyzer

**VeeR EL2 processor repository:**
https://github.com/chipsalliance/Cores-VeeR-EL2

The project uses third-party RTL and supporting code where applicable. Refer to the corresponding upstream repositories and license files for their licensing and attribution requirements.

## 10. Conclusion

This project explores the design of a modular RISC-V-based spectrum analyzer SoC with hardware DSP acceleration. By combining a programmable processor, AXI-based communication, dedicated FIR and FFT processing blocks, sample-acquisition logic, memory, and peripheral interfaces, the design aims to provide a flexible platform for embedded signal processing.

The development approach emphasizes modular RTL design, reusable IP integration, explicit memory mapping, and incremental simulation-based verification. The final system-level objective is to connect processor control with hardware-accelerated signal processing and make the resulting frequency-domain data accessible to a host computer.
