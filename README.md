# AXI Interconnect

## Overview

This repository contains the current implementation of a parameterized AXI interconnect and its supporting RTL modules. The project includes a Python-based wrapper generator, AXI interconnect RTL, arbitration logic, priority encoding logic, and a generated 3×14 AXI interconnect wrapper.

## Project Contents

The current repository contains:

- Python-based AXI interconnect wrapper generator
- AXI interconnect RTL
- Arbiter RTL
- Priority encoder RTL
- Generated 3×14 AXI interconnect wrapper
- SystemVerilog testbench
- Simulation and verification files

## Repository Structure

```text
proj-dir/
│
├── doc/
│
├── lib/
│
├── reg/
│
├── scripts/
│   └── axi_interconnect_wrap.py
│
├── rtl/
│   └── interconnect/
│       ├── axi_interconnect.v
│       ├── axi_interconnect_wrap_3x14.v
│       ├── arbiter.v
│       └── priority_encoder.v
│
└── run/
    └── Simulation / VCS generated files
