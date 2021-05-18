### RISC-V Based Pipelined CPU
##### This is primarily for learning

------------
- 5 Stages (IF, ID, EX, MEM, WB)

- Forwarding is supported

- Stalling is being tuned (So avoid using lw followed by consuming the result)

- Registers: 16, 16-bit registers

- Cache is WIP, currently direct mapped

- This is heavily based on The Morgan Kaufmann Series in Computer Architecture and design, RISC V Edition 2017

- cpu-9.sv contains the entire CPU, cache.sv is not connected 

| Instruction  |OP  |RS1   |RS2/IMM   |RD   |Example   |
| ------------ | ------------ | ------------ | ------------ | ------------ | ------------ |
|load   |0000   |0010   |0000 |0011  |lw x3, (0)x2   |
|sw   |0001   |0010   |0000   |0100   |sw x4, (0)(x2)   |
|add  |0100   |0011   |0010   |0100   |add x3, x4, x2   |
|sub   |0101   |0011   |0110   |0101   |add x3, x4, x2   |
|addi   |1000   |0001   |0100   |0010   |addi x2, x1, 4   |
|halt   |xxxx   |xxxx   |xxxx   |xxxx   |halt   |

