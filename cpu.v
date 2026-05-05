module cpu (
    input clk,
    input reset,
    input mem_select,

    input [4:0] debug_reg,
    output [31:0] debug_data,

    output [31:0] pc_debug,
    output reg all_passed
);

    reg [31:0] PC;
    assign pc_debug = PC;

    wire [31:0] instruction;
    reg  [31:0] instr_reg;

    imem IMEM (
    .addr(PC),
    .mem_select(mem_select),
    .data(instruction)
);

    wire [6:0] opcode = instr_reg[6:0];
    wire [4:0] rd     = instr_reg[11:7];
    wire [2:0] funct3 = instr_reg[14:12];
    wire [4:0] rs1    = instr_reg[19:15];
    wire [4:0] rs2    = instr_reg[24:20];
    wire [6:0] funct7 = instr_reg[31:25];

    wire [31:0] imm_i = {{20{instr_reg[31]}}, instr_reg[31:20]};
    wire [31:0] imm_s = {{20{instr_reg[31]}}, instr_reg[31:25], instr_reg[11:7]};
    wire [31:0] imm_b = {{19{instr_reg[31]}}, instr_reg[31],
                         instr_reg[7], instr_reg[30:25],
                         instr_reg[11:8], 1'b0};

    wire [31:0] rd1, rd2;
    wire [31:0] write_data;

    reg reg_write;

    regfile RF (
    .clk(clk),
    .reset(reset),
    .rs1(rs1),
    .rs2(rs2),
    .rd(rd),
    .wd(write_data),
    .we(reg_write),

    .debug_reg(debug_reg),
    .debug_data(debug_data),

    .rd1(rd1),
    .rd2(rd2)
);

   

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
            else if (funct3 == 3'b010 && funct7 == 7'b0000000)
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

    reg [31:0] dmem [0:255];

    wire [31:0] mem_read_data;
    assign mem_read_data = dmem[alu_result[9:2]];

    assign write_data = (opcode == 7'b0000011) ? mem_read_data : alu_result;

    reg [2:0] state;

    parameter FETCH     = 3'b000;
    parameter DECODE    = 3'b001;
    parameter EXECUTE   = 3'b010;
    parameter WRITEBACK = 3'b011;

    reg addi_pass, add_pass, sub_pass, slt_pass;
    reg andi_pass, lw_pass, sw_pass;
    reg beq_taken_pass, beq_not_taken_pass;

    wire is_rtype = opcode == 7'b0110011;
    wire is_itype = opcode == 7'b0010011;
    wire is_lw    = opcode == 7'b0000011;
    wire is_sw    = opcode == 7'b0100011;
    wire is_beq   = opcode == 7'b1100011;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            PC <= 0;
            instr_reg <= 0;
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

                FETCH: begin
                    reg_write <= 0;
                    instr_reg <= instruction;
                    state <= DECODE;
                end

                DECODE: begin
                    state <= EXECUTE;
                end

                EXECUTE: begin
                    reg_write <= 0;

                    if (is_rtype) begin
                        PC <= PC + 4;

                        if (funct3 == 3'b000 && funct7 == 7'b0000000)
                            add_pass <= 1;
                        else if (funct3 == 3'b000 && funct7 == 7'b0100000)
                            sub_pass <= 1;
                        else if (funct3 == 3'b010 && funct7 == 7'b0000000)
                            slt_pass <= 1;

                        state <= WRITEBACK;
                    end

                    else if (is_itype) begin
                        PC <= PC + 4;

                        if (funct3 == 3'b000)
                            addi_pass <= 1;
                        else if (funct3 == 3'b111)
                            andi_pass <= 1;

                        state <= WRITEBACK;
                    end

                    else if (is_lw) begin
                        PC <= PC + 4;
                        lw_pass <= 1;
                        state <= WRITEBACK;
                    end

                    else if (is_sw) begin
                        dmem[alu_result[9:2]] <= rd2;
                        PC <= PC + 4;
                        sw_pass <= 1;
                        state <= FETCH;
                    end

                    else if (is_beq) begin
                        if (funct3 == 3'b000 && rd1 == rd2) begin
                            PC <= PC + imm_b;
                            beq_taken_pass <= 1;
                        end
                        else begin
                            PC <= PC + 4;
                            beq_not_taken_pass <= 1;
                        end

                        state <= FETCH;
                    end

                    else begin
                        PC <= PC + 4;
                        state <= FETCH;
                    end
                end

                WRITEBACK: begin
                    reg_write <= 1;
                    state <= FETCH;
                end

                default: begin
                    state <= FETCH;
                end

            endcase

            if (addi_pass && add_pass && sub_pass && slt_pass &&
                andi_pass && lw_pass && sw_pass &&
                beq_taken_pass && beq_not_taken_pass) begin
                all_passed <= 1;
            end
        end
    end

endmodule
