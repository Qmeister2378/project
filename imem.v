module imem (
    input [31:0] addr,
    input mem_select,
    output [31:0] data
);

    reg [31:0] memory0 [0:255];
    reg [31:0] memory1 [0:255];

    initial begin
        $readmemh("program.mem", memory0);
        $readmemh("program.mem", memory1);
    end

    assign data = (mem_select == 1'b0) ? memory0[addr[9:2]] :
                                           memory1[addr[9:2]];

endmodule
