# LC-3 CPU

A Verilog/SystemVerilog implementation of the LC-3 (Little Computer 3) architecture.

## Features

- 16-bit data bus and address space
- 8 general-purpose registers (R0–R7)
- Condition codes: N (Negative), Z (Zero), P (Positive)
- Supported instructions: ADD, AND, NOT, BR, JMP, JSR, JSRR, LD, LDI, LDR, LEA, ST, STI, STR, TRAP, RTI

## Files

| File | Description |
|---|---|
| `cpu.v` | LC-3 CPU top module |
| `lc3_memory.v` | Memory module |
| `lc3_if.sv` | SystemVerilog interface |
| `lc3_tb_pkg.sv` | Testbench package |
| `tb_top.sv` | Top-level testbench |

## Simulation

```bash
# ModelSim / QuestaSim
vlog cpu.v lc3_memory.v lc3_if.sv lc3_tb_pkg.sv tb_top.sv
vsim tb_top
run -all
```
