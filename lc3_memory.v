
module lc3_memory (
    input  wire        clk,
    input  wire [15:0] addr,
    input  wire [15:0] wdata,
    output wire [15:0] rdata,
    input  wire        we,
    input  wire        re
);

    reg [15:0] mem [0:65535];

    assign rdata = mem[addr];

    always @(posedge clk) begin
        if (we) begin
            mem[addr] <= wdata;
        end
    end

endmodule
