module imem (
    input [31:0] addr,
    output [31:0] data
);

    reg [31:0] memory [0:255];

    initial begin
        $readmemh("program.mem", memory);
    end

    assign data = memory[addr[9:2]];

endmodule