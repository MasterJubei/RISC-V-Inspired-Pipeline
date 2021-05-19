### RISC-V Based Pipelined CPU
##### This is primarily for learning

- This code should hopefully be straight forward for someone to understand how a simple pipelined CPU can function

- This code was made primarily in two quarters for two classes taught by Professor Jim Lewis at Santa Clara University

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
|add  |0100   |0100   |0010   |0011   |add x3, x4, x2   |
|sub   |0101   |0100   |0110   |0101   |sub x5, x4, x6   |
|addi   |1000   |0001   |0100   |0010   |addi x2, x1, 4   |
|halt   |xxxx   |xxxx   |xxxx   |xxxx   |halt   |

