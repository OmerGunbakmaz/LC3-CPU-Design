interface lc3_if (input logic clk);

    logic        reset;
    logic [15:0] mem_addr;
    logic [15:0] mem_wdata;
    logic        mem_we;
    logic        mem_re;
    logic [15:0] mem_rdata;
    logic [15:0] pc_out;
    logic [2:0]  nzp_out;
    logic        halted;

    logic [15:0] sim_mem [0:65535];

    assign mem_rdata = sim_mem[mem_addr];

    always @(posedge clk)
        if (mem_we) sim_mem[mem_addr] <= mem_wdata;

    task automatic load_prog(input logic [15:0] base,
                             input logic [15:0] prog []);
        foreach (prog[i]) sim_mem[base + i] = prog[i];
    endtask

endinterface
