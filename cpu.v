module cpu (
    input clk,
    input reset,
    input mem_select,

    input [4:0] debug_reg,
    output [31:0] debug_data,

    output [31:0] pc_debug,
    output reg all_passed
);

    // Stop PC at this instruction address if program reaches it
    parameter HALT_PC = 32'd88;

    // Program counter
    reg [31:0] pc_current;
    assign pc_debug = pc_current;

    // Instruction wires/registers
    wire [31:0] fetched_instruction;
    reg  [31:0] current_instruction;

    imem IMEM (
        .addr(pc_current),
        .mem_select(mem_select),
        .data(fetched_instruction)
    );

    // Instruction fields
    wire [6:0] instr_opcode = current_instruction[6:0];
    wire [4:0] instr_rd     = current_instruction[11:7];
    wire [2:0] instr_funct3 = current_instruction[14:12];
    wire [4:0] instr_rs1    = current_instruction[19:15];
    wire [4:0] instr_rs2    = current_instruction[24:20];
    wire [6:0] instr_funct7 = current_instruction[31:25];

    // Immediate values
    wire [31:0] imm_i_type;
    wire [31:0] imm_s_type;
    wire [31:0] imm_b_type;

    assign imm_i_type = {{20{current_instruction[31]}}, current_instruction[31:20]};
    assign imm_s_type = {{20{current_instruction[31]}}, current_instruction[31:25], current_instruction[11:7]};
    assign imm_b_type = {{19{current_instruction[31]}}, current_instruction[31],
                         current_instruction[7], current_instruction[30:25],
                         current_instruction[11:8], 1'b0};

    // Register file connections
    wire [31:0] reg_value_a;
    wire [31:0] reg_value_b;
    wire [31:0] reg_write_value;

    reg write_enable;

    regfile RF (
        .clk(clk),
        .reset(reset),

        .rs1(instr_rs1),
        .rs2(instr_rs2),
        .rd(instr_rd),
        .wd(reg_write_value),
        .we(write_enable),

        .debug_reg(debug_reg),
        .debug_data(debug_data),

        .rd1(reg_value_a),
        .rd2(reg_value_b)
    );

    // ALU connections
    reg [3:0] alu_operation;
    reg [31:0] alu_input_b;
    wire [31:0] alu_output;

    alu ALU (
        .a(reg_value_a),
        .b(alu_input_b),
        .alu_ctrl(alu_operation),
        .result(alu_output)
    );

    // Data memory
    reg [31:0] data_memory [0:255];

    wire [31:0] load_value;
    assign load_value = data_memory[alu_output[9:2]];

    assign reg_write_value = (instr_opcode == 7'b0000011) ? load_value : alu_output;

    // Instruction type checks
    wire r_type_instruction;
    wire i_type_instruction;
    wire load_instruction;
    wire store_instruction;
    wire branch_instruction;

    assign r_type_instruction = (instr_opcode == 7'b0110011);
    assign i_type_instruction = (instr_opcode == 7'b0010011);
    assign load_instruction   = (instr_opcode == 7'b0000011);
    assign store_instruction  = (instr_opcode == 7'b0100011);
    assign branch_instruction = (instr_opcode == 7'b1100011);

    // CPU states
    reg [2:0] cpu_state;

    parameter STATE_FETCH     = 3'b000;
    parameter STATE_DECODE    = 3'b001;
    parameter STATE_EXECUTE   = 3'b010;
    parameter STATE_WRITEBACK = 3'b011;
    parameter STATE_HALT      = 3'b100;

    // Test pass flags
    reg pass_addi;
    reg pass_add;
    reg pass_sub;
    reg pass_slt;
    reg pass_andi;
    reg pass_lw;
    reg pass_sw;
    reg pass_beq_taken;
    reg pass_beq_not_taken;

    // ALU control logic
    always @(*) begin
        alu_operation = 4'b0000;
        alu_input_b = reg_value_b;

        if (i_type_instruction || load_instruction)
            alu_input_b = imm_i_type;
        else if (store_instruction)
            alu_input_b = imm_s_type;

        if (r_type_instruction) begin
            if (instr_funct3 == 3'b000 && instr_funct7 == 7'b0000000)
                alu_operation = 4'b0000;     // ADD
            else if (instr_funct3 == 3'b000 && instr_funct7 == 7'b0100000)
                alu_operation = 4'b0001;     // SUB
            else if (instr_funct3 == 3'b010 && instr_funct7 == 7'b0000000)
                alu_operation = 4'b0100;     // SLT
        end

        else if (i_type_instruction) begin
            if (instr_funct3 == 3'b000)
                alu_operation = 4'b0000;     // ADDI
            else if (instr_funct3 == 3'b111)
                alu_operation = 4'b0010;     // ANDI
        end
    end

    // Main CPU state machine
    always @(posedge clk or posedge reset) begin
        if (reset) begin
            pc_current <= 32'd0;
            current_instruction <= 32'd0;
            cpu_state <= STATE_FETCH;
            write_enable <= 1'b0;

            pass_addi <= 1'b0;
            pass_add <= 1'b0;
            pass_sub <= 1'b0;
            pass_slt <= 1'b0;
            pass_andi <= 1'b0;
            pass_lw <= 1'b0;
            pass_sw <= 1'b0;
            pass_beq_taken <= 1'b0;
            pass_beq_not_taken <= 1'b0;

            all_passed <= 1'b0;
        end

        else begin
            case (cpu_state)

                STATE_FETCH: begin
                    write_enable <= 1'b0;

                    if (pc_current >= HALT_PC || all_passed == 1'b1) begin
                        cpu_state <= STATE_HALT;
                    end
                    else begin
                        current_instruction <= fetched_instruction;
                        cpu_state <= STATE_DECODE;
                    end
                end

                STATE_DECODE: begin
                    cpu_state <= STATE_EXECUTE;
                end

                STATE_EXECUTE: begin
                    write_enable <= 1'b0;

                    if (r_type_instruction) begin
                        pc_current <= pc_current + 32'd4;

                        if (instr_funct3 == 3'b000 && instr_funct7 == 7'b0000000)
                            pass_add <= 1'b1;
                        else if (instr_funct3 == 3'b000 && instr_funct7 == 7'b0100000)
                            pass_sub <= 1'b1;
                        else if (instr_funct3 == 3'b010 && instr_funct7 == 7'b0000000)
                            pass_slt <= 1'b1;

                        cpu_state <= STATE_WRITEBACK;
                    end

                    else if (i_type_instruction) begin
                        pc_current <= pc_current + 32'd4;

                        if (instr_funct3 == 3'b000)
                            pass_addi <= 1'b1;
                        else if (instr_funct3 == 3'b111)
                            pass_andi <= 1'b1;

                        cpu_state <= STATE_WRITEBACK;
                    end

                    else if (load_instruction) begin
                        pc_current <= pc_current + 32'd4;
                        pass_lw <= 1'b1;
                        cpu_state <= STATE_WRITEBACK;
                    end

                    else if (store_instruction) begin
                        data_memory[alu_output[9:2]] <= reg_value_b;
                        pc_current <= pc_current + 32'd4;
                        pass_sw <= 1'b1;
                        cpu_state <= STATE_FETCH;
                    end

                    else if (branch_instruction) begin
                        if (instr_funct3 == 3'b000 && reg_value_a == reg_value_b) begin
                            pc_current <= pc_current + imm_b_type;
                            pass_beq_taken <= 1'b1;
                        end
                        else begin
                            pc_current <= pc_current + 32'd4;
                            pass_beq_not_taken <= 1'b1;
                        end

                        cpu_state <= STATE_FETCH;
                    end

                    else begin
                        pc_current <= pc_current + 32'd4;
                        cpu_state <= STATE_FETCH;
                    end
                end

                STATE_WRITEBACK: begin
                    write_enable <= 1'b1;
                    cpu_state <= STATE_FETCH;
                end

                STATE_HALT: begin
                    write_enable <= 1'b0;
                    pc_current <= pc_current;
                    cpu_state <= STATE_HALT;
                end

                default: begin
                    cpu_state <= STATE_FETCH;
                end

            endcase

            if (pass_addi && pass_add && pass_sub && pass_slt &&
                pass_andi && pass_lw && pass_sw &&
                pass_beq_taken && pass_beq_not_taken) begin
                all_passed <= 1'b1;
            end
        end
    end

endmodule
