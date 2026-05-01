module cpu (
    input clk,
    input reset,

    output [31:0] pc_debug,
    output [31:0] reg1_debug,
    output [31:0] reg2_debug,
    output [31:0] reg3_debug,
    output [31:0] reg6_debug,

    output reg all_passed
);

    // =============================
    // PC
    // =============================
    reg [31:0] PC;
    assign pc_debug = PC;

    // =============================
    // Instruction Memory
    // =============================
    wire [31:0] instruction;

    imem IMEM (
        .addr(PC),
        .data(instruction)
    );

    // =============================
    // Decode
    // =============================
    wire [6:0] opcode = instruction[6:0];
    wire [4:0] rd     = instruction[11:7];
    wire [2:0] funct3 = instruction[14:12];
    wire [4:0] rs1    = instruction[19:15];
    wire [4:0] rs2    = instruction[24:20];
    wire [6:0] funct7 = instruction[31:25];

    // =============================
    // Immediates
    // =============================
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

    // =============================
    // Register File
    // =============================
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

    // =============================
    // ALU
    // =============================
    reg [3:0] alu_ctrl;
    reg [31:0] alu_b;
    wire [31:0] alu_result;

    always @(*) begin
        alu_ctrl = 4'b0000;
        alu_b = rd2;

        if (opcode == 7'b0010011 || opcode == 7'b0000011)
            alu_b = imm_i;
        else if (opcode == 7'b0100011)
            alu_b = imm_s;

        if (opcode == 7'b0110011) begin
            if (funct3 == 3'b000 && funct7 == 7'b0000000)
                alu_ctrl = 4'b0000; // ADD
            else if (funct3 == 3'b000 && funct7 == 7'b0100000)
                alu_ctrl = 4'b0001; // SUB
            else if (funct3 == 3'b010)
                alu_ctrl = 4'b0100; // SLT
        end
        else if (opcode == 7'b0010011) begin
            if (funct3 == 3'b000)
                alu_ctrl = 4'b0000; // ADDI
            else if (funct3 == 3'b111)
                alu_ctrl = 4'b0010; // ANDI
        end
    end

    alu ALU (
        .a(rd1),
        .b(alu_b),
        .alu_ctrl(alu_ctrl),
        .result(alu_result)
    );

    // =============================
    // Data Memory (inside CPU)
    // =============================
    reg [31:0] dmem [0:255];

    wire [31:0] mem_read_data;
    assign mem_read_data = dmem[alu_result[9:2]];

    assign write_data = (opcode == 7'b0000011) ? mem_read_data : alu_result;

    // =============================
    // FSM
    // =============================
    reg [1:0] state;
    parameter FETCH = 0, DECODE = 1, EXECUTE = 2;

    // =============================
    // Instruction coverage flags
    // =============================
    reg addi_pass, add_pass, sub_pass, slt_pass;
    reg andi_pass, lw_pass, sw_pass;
    reg beq_taken_pass, beq_not_taken_pass;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            PC <= 0;
            state <= FETCH;
            reg_write <= 0;

            addi_pass <= 0;
            add_pass <= 0;
            sub_pass <= 0;
            slt_pass <= 0;
            andi_pass <= 0;
            lw_pass <= 0;
            sw_pass <= 0;
            beq_taken_pass <= 0;
            beq_not_taken_pass <= 0;
            all_passed <= 0;
        end
        else begin
            case (state)

                FETCH: state <= DECODE;

                DECODE: state <= EXECUTE;

                EXECUTE: begin
                    reg_write <= 0;

                    // ADD / SUB / SLT
                    if (opcode == 7'b0110011) begin
                        reg_write <= 1;
                        PC <= PC + 4;

                        if (funct3 == 3'b000 && funct7 == 7'b0000000)
                            add_pass <= 1;

                        if (funct3 == 3'b000 && funct7 == 7'b0100000)
                            sub_pass <= 1;

                        if (funct3 == 3'b010)
                            slt_pass <= 1;
                    end

                    // ADDI / ANDI
                    else if (opcode == 7'b0010011) begin
                        reg_write <= 1;
                        PC <= PC + 4;

                        if (funct3 == 3'b000)
                            addi_pass <= 1;

                        if (funct3 == 3'b111)
                            andi_pass <= 1;
                    end

                    // LW
                    else if (opcode == 7'b0000011) begin
                        reg_write <= 1;
                        PC <= PC + 4;
                        lw_pass <= 1;
                    end

                    // SW
                    else if (opcode == 7'b0100011) begin
                        dmem[alu_result[9:2]] <= rd2;
                        PC <= PC + 4;
                        sw_pass <= 1;
                    end

                    // BEQ
                    else if (opcode == 7'b1100011) begin
                        if (rd1 == rd2) begin
                            PC <= PC + imm_b;
                            beq_taken_pass <= 1;
                        end else begin
                            PC <= PC + 4;
                            beq_not_taken_pass <= 1;
                        end
                    end

                    else begin
                        PC <= PC + 4;
                    end

                    // FINAL CHECK
                    if (addi_pass && add_pass && sub_pass && slt_pass &&
                        andi_pass && lw_pass && sw_pass &&
                        beq_taken_pass && beq_not_taken_pass) begin
                        all_passed <= 1;
                    end

                    state <= FETCH;
                end

            endcase
        end
    end

endmodule
