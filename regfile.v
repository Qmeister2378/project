module regfile (
    input clk,
    input [4:0] rs1,
    input [4:0] rs2,
    input [4:0] rd,
    input [31:0] wd,
    input we,

    output [31:0] rd1,
    output [31:0] rd2,

    output [31:0] reg1_out,
    output [31:0] reg2_out,
    output [31:0] reg3_out,
    output [31:0] reg6_out
);

    reg [31:0] regs [0:31];

    assign rd1 = (rs1 == 0) ? 0 : regs[rs1];
    assign rd2 = (rs2 == 0) ? 0 : regs[rs2];

    assign reg1_out = regs[1];
    assign reg2_out = regs[2];
    assign reg3_out = regs[3];
    assign reg6_out = regs[6];

    always @(posedge clk) begin
        if (we && rd != 0)
            regs[rd] <= wd;
    end

endmodule