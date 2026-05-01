module cpu (
    input clk,
    input reset,

    output [31:0] pc_debug,
    output [31:0] reg1_debug,
    output [31:0] reg2_debug,
    output [31:0] reg3_debug,
    output [31:0] reg6_debug,

    output reg benchmark1_done,
    output reg benchmark2_done,
    output reg all_passed
);

    reg [31:0] PC;
    assign pc_debug = PC;

    // Instruction Memory
    wire [31:0] instruction;

    imem IMEM (
        .addr(PC),
        .data(instruction)
    );

    // Decode
    wire [6:0] opcode = instruction[6:0];
    wire [4:0] rd     = instruction[11:7];
    wire [2:0] funct3 = instruction[14:12];
    wire [4:0] rs1    = instruction[19:15];
    wire [4:0] rs2    = instruction[24:20];
    wire [6:0] funct7 = instruction[31:25];

    // Immediates
    wire [31:0] imm_i = {{20{instruction[31]}}, instruction[31:20]};

    wire [31:0] imm_s = {{20{instruction[31]}},
                         instruction[31:25],
                         instruction[11:7]};

    wire [31:0] imm_b = {{19{instruction[31]}},
                         instruction[31],
                         instruction[7],
                         instruction[30:25],
                         instruction[11:8],
                         1'b0};

    // Register File
    wire [31:0] rd1, rd2;
    wire [31:0] write_data;
    reg reg_write;

    wire [31:0] r1_out, r2_out, r3_out, r6_out;

    regfile RF (
        .clk(clk),
        .rs1(rs1),
        .rs2(rs2),
        .rd(rd),
        .wd(write_data),
        .we(reg_write),
        .rd1(rd1),
        .rd2(rd2),

        .reg1_out(r1_out),
        .reg2_out(r2_out),
        .reg3_out(r3_out),
        .reg6_out(r6_out)
    );

    assign reg1_debug = r1_out;
    assign reg2_debug = r2_out;
    assign reg3_debug = r3_out;
    assign reg6_debug = r6_out;

    // ALU control/input
    reg [3:0] alu_ctrl;
    reg [31:0] alu_b;
    wire [31:0] alu_result;

    always @(*) begin
        alu_ctrl = 4'b0000;
        alu_b = rd2;

        // Choose ALU second input
        if (opcode == 7'b0010011) begin
            alu_b = imm_i;       // ADDI, ANDI
        end
        else if (opcode == 7'b0000011) begin
            alu_b = imm_i;       // LW address
        end
        else if (opcode == 7'b0100011) begin
            alu_b = imm_s;       // SW address
        end

        // Choose ALU operation
        if (opcode == 7'b0110011) begin
            // R-type: ADD, SUB, SLT
            if (funct3 == 3'b000 && funct7 == 7'b0000000)
                alu_ctrl = 4'b0000; // ADD
            else if (funct3 == 3'b000 && funct7 == 7'b0100000)
                alu_ctrl = 4'b0001; // SUB
            else if (funct3 == 3'b010 && funct7 == 7'b0000000)
                alu_ctrl = 4'b0100; // SLT
        end
        else if (opcode == 7'b0010011) begin
            // I-type: ADDI, ANDI
            if (funct3 == 3'b000)
                alu_ctrl = 4'b0000; // ADDI
            else if (funct3 == 3'b111)
                alu_ctrl = 4'b0010; // ANDI
        end
        else if (opcode == 7'b0000011 || opcode == 7'b0100011) begin
            alu_ctrl = 4'b0000;     // LW/SW address = base + offset
        end
    end

    alu ALU (
        .a(rd1),
        .b(alu_b),
        .alu_ctrl(alu_ctrl),
        .result(alu_result)
    );

    // Data Memory inside CPU
    reg [31:0] dmem [0:255];

    wire [31:0] mem_read_data;
    assign mem_read_data = dmem[alu_result[9:2]];

    assign write_data = (opcode == 7'b0000011) ? mem_read_data : alu_result;

    // FSM
    reg [1:0] state;

    parameter FETCH   = 2'b00;
    parameter DECODE  = 2'b01;
    parameter EXECUTE = 2'b10;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            PC <= 0;
            state <= FETCH;
            reg_write <= 0;

            benchmark1_done <= 0;
            benchmark2_done <= 0;
            all_passed <= 0;
        end
        else begin
            case (state)

                FETCH: begin
                    reg_write <= 0;
                    state <= DECODE;
                end

                DECODE: begin
                    state <= EXECUTE;
                end

                EXECUTE: begin
                    reg_write <= 0;

                    // R-type: ADD, SUB, SLT
                    if (opcode == 7'b0110011) begin
                        reg_write <= 1;
                        PC <= PC + 4;
                    end

                    // I-type: ADDI, ANDI
                    else if (opcode == 7'b0010011) begin
                        reg_write <= 1;
                        PC <= PC + 4;
                    end

                    // LW
                    else if (opcode == 7'b0000011) begin
                        reg_write <= 1;
                        PC <= PC + 4;
                    end

                    // SW
                    else if (opcode == 7'b0100011) begin
                        dmem[alu_result[9:2]] <= rd2;
                        reg_write <= 0;
                        PC <= PC + 4;
                    end

                    // BEQ
                    else if (opcode == 7'b1100011) begin
                        reg_write <= 0;

                        if (funct3 == 3'b000 && rd1 == rd2)
                            PC <= PC + imm_b;
                        else
                            PC <= PC + 4;
                    end

                    // Unknown instruction
                    else begin
                        reg_write <= 0;
                        PC <= PC + 4;
                    end

                    // Benchmark checker
                    if (r1_out == 32'hFFFFFFF7) begin
                        benchmark1_done <= 1;
                    end

                    if (r6_out == 32'hFFFFFFFD) begin
                        benchmark2_done <= 1;
                    end

                    if (benchmark1_done && benchmark2_done) begin
                        all_passed <= 1;
                    end

                    state <= FETCH;
                end

                default: begin
                    state <= FETCH;
                end

            endcase
        end
    end

endmodule