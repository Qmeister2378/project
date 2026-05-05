module regfile (
    input clk,
    input reset,
    input [4:0] rs1,
    input [4:0] rs2,
    input [4:0] rd,
    input [31:0] wd,
    input we,

    input [4:0] debug_reg,
    output [31:0] debug_data,

    output [31:0] rd1,
    output [31:0] rd2
);

    reg [31:0] regs [0:31];
    integer i;

    assign rd1 = (rs1 == 0) ? 0 : regs[rs1];
    assign rd2 = (rs2 == 0) ? 0 : regs[rs2];

    assign debug_data = (debug_reg == 0) ? 0 : regs[debug_reg];

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            for (i = 0; i < 32; i = i + 1)
                regs[i] <= 0;
        end
        else begin
            if (we && rd != 0)
                regs[rd] <= wd;
        end
    end

endmodule
