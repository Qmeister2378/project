module cpu_top (
    input        CLOCK_50,
    input  [3:0] KEY,
    input  [9:0] SW,
    output [9:0] LEDR,
    output [6:0] HEX0,
    output [6:0] HEX1
);

    wire rst = ~KEY[3];

    wire mem_select = SW[7];

    wire [4:0] selected_reg;
    assign selected_reg = SW[4:0];

    reg [25:0] counter;

always @(posedge CLOCK_50 or posedge rst) begin
    if (rst)
        counter <= 26'd0;
    else
        counter <= counter + 26'd1;
end


    wire slow_clk = counter[23];

    wire [31:0] pc;
    wire [31:0] debug_data;
    wire all_passed;

    cpu CPU (
        .clk(slow_clk),
        .reset(rst),
        .mem_select(mem_select),

        .debug_reg(selected_reg),
        .debug_data(debug_data),

        .pc_debug(pc),
        .all_passed(all_passed)
    );

    wire [31:0] display_value;

    assign display_value = (SW[8] == 1'b1) ? pc : debug_data;

    assign LEDR[8:0] = display_value[8:0];
    assign LEDR[9] = all_passed;

    seg7 S0 (
        .value(display_value[3:0]),
        .o(HEX0)
    );

    seg7 S1 (
        .value(display_value[7:4]),
        .o(HEX1)
    );

endmodule
