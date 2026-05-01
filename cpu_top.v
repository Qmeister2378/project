module cpu_top (
    input        CLOCK_50,
    input  [3:0] KEY,
    input  [9:0] SW,
    output [9:0] LEDR
);

    wire rst = ~KEY[3];

    reg [25:0] counter;

    always @(posedge CLOCK_50) begin
        counter <= counter + 1;
    end

    wire slow_clk = counter[25];

    wire [31:0] pc;
    wire [31:0] r1, r2, r3, r6;

    cpu CPU (
        .clk(slow_clk),
        .reset(rst),
        .pc_debug(pc),
        .reg1_debug(r1),
        .reg2_debug(r2),
        .reg3_debug(r3),
        .reg6_debug(r6)
    );

    assign LEDR =
        (SW[1:0] == 2'b00) ? pc[9:0] :
        (SW[1:0] == 2'b01) ? r1[9:0] :
        (SW[1:0] == 2'b10) ? r3[9:0] :
                             r6[9:0];

endmodule