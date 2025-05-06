# RISC-V 5-Stage Pipelined Processor (UCSB ECE 154B)

This project implements a 5-stage pipelined RISC-V processor in Verilog, developed for the UCSB ECE 154B computer architecture course. The processor supports core RISC-V instructions with full hazard detection, data forwarding, and control flow handling.

## 🔧 Features

- 5 pipeline stages: IF, ID, EX, MEM, WB
- Data hazard detection and stall logic
  - Forwarding unit (EX/MEM/WB to EX)
-  Branch and jump support (`beq`, `jal`)
- Control hazard handling via flushing
-  Support for I-type, R-type, S-type, B-type, U-type, J-type instructions
-  Modular design with `datapath.v` and `controller.v`
-  Designed for simulation in ModelSim
