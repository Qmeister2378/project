Your FPGA processor project is built from several Verilog files that work together like a small CPU.

The cpu_top.v file is the top-level design that connects the FPGA board inputs and outputs to the CPU. It uses the board clock, reset button, switches, and LEDs. The switches decide what value is displayed on the LEDs, such as the program counter, register values, or the final pass signal.

The imem.v file is the instruction memory. It loads machine-code instructions from program.mem using $readmemh. The CPU sends the current program counter address to instruction memory, and instruction memory returns the instruction at that address. Since each instruction is 32 bits, the CPU moves through the program by increasing the PC by 4.

The program.mem file contains the actual machine-code instructions that the CPU executes. These instructions are the micro-benchmarks. They test instructions such as ADDI, ADD, SUB, SLT, ANDI, LW, SW, and BEQ. The program is designed to exercise arithmetic, memory access, and branch paths.

The regfile.v file is the register file. It stores the CPU’s register values. The CPU can read two registers at the same time and write one result back into a register. It also outputs certain registers, such as x1, x2, x3, and x6, so they can be displayed on the LEDs for debugging.

The alu.v file performs the processor’s arithmetic and logic operations. It handles operations like addition, subtraction, bitwise AND, OR, and set-less-than. The CPU chooses which ALU operation to use based on the instruction’s opcode, funct3, and funct7.

The cpu.v file is the main processor. It fetches instructions from instruction memory, decodes the instruction fields, selects the correct ALU operation, reads values from the register file, writes results back to registers, handles load/store data memory, and updates the program counter. It also has a finite state machine with fetch, decode, and execute stages.

Inside cpu.v, data memory is used for LW and SW. A store instruction writes a register value into memory, and a load instruction reads that memory value back into a register. This proves that the processor can move data between registers and memory.

The CPU also includes instruction coverage flags. Each time an instruction type runs successfully, such as ADDI, ADD, SUB, SLT, ANDI, LW, SW, or a taken/not-taken BEQ, a flag is set. When all flags are set, the all_passed signal turns on. This shows that the processor exercised all major instruction paths required for the micro-benchmarks.

Overall, the project demonstrates how a basic processor is built on an FPGA by combining instruction memory, a register file, an ALU, data memory, and control logic. The LEDs allow you to observe the processor’s progress and verify that the micro-benchmarks are running correctly.
