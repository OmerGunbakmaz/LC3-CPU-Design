`timescale 1ns/1ps

module tb_top;

    logic clk = 0;
    always #5 clk = ~clk;

    lc3_if dut_if(.clk(clk));

    lc3_cpu dut(
        .clk      (clk),
        .reset    (dut_if.reset),
        .mem_addr (dut_if.mem_addr),
        .mem_wdata(dut_if.mem_wdata),
        .mem_rdata(dut_if.mem_rdata),
        .mem_we   (dut_if.mem_we),
        .mem_re   (dut_if.mem_re),
        .pc_out   (dut_if.pc_out),
        .nzp_out  (dut_if.nzp_out),
        .halted   (dut_if.halted)
    );

    int pass_cnt = 0, fail_cnt = 0;

    task automatic reset_cpu();
        dut_if.reset = 1;
        repeat(4) @(posedge clk);
        dut_if.reset = 0;
    endtask

    task automatic wait_halt(int timeout = 500);
        int cnt = 0;
        while (!dut_if.halted && cnt < timeout) begin
            @(posedge clk);
            cnt++;
        end
        if (cnt >= timeout)
            $fatal(1, "TIMEOUT: CPU did not halt in %0d cycles", timeout);
    endtask

    task automatic chk(string name, logic cond);
        if (cond) begin $display("PASS: %s", name); pass_cnt++; end
        else      begin $display("FAIL: %s", name); fail_cnt++; end
    endtask

    initial begin
        $dumpfile("lc3_waves.vcd");
        $dumpvars(0, tb_top);

        // Test 1: ALU
        // ADD R0,R0,#5  ADD R1,R1,#3  AND R2,R0,R1  NOT R3,R2  ADD R4,R0,R1  TRAP x25
        dut_if.load_prog(16'h3000, '{16'h1025, 16'h1263, 16'h5401, 16'h96BF, 16'h1801, 16'hF025});
        reset_cpu();
        wait_halt();
        chk("ALU: halted",  dut_if.halted);
        chk("ALU: PC=3006", dut_if.pc_out === 16'h3006);

        // Test 2: Branch (BRp)
        // ADD R0,R0,#5  BRp #1  TRAP x25  ADD R1,R1,#2  TRAP x25
        dut_if.load_prog(16'h3000, '{16'h1025, 16'h0201, 16'hF025, 16'h1262, 16'hF025});
        reset_cpu();
        wait_halt();
        chk("BR: halted",  dut_if.halted);
        chk("BR: PC=3005", dut_if.pc_out === 16'h3005);

        // Test 3: Store (ST)
        // ADD R0,R0,#7  ST R0,#3  TRAP x25  -> mem[0x3005] = 7
        dut_if.load_prog(16'h3000, '{16'h1027, 16'h3003, 16'hF025});
        reset_cpu();
        wait_halt();
        chk("ST: halted",      dut_if.halted);
        chk("ST: PC=3003",     dut_if.pc_out === 16'h3003);
        chk("ST: mem[3005]=7", dut_if.sim_mem[16'h3005] === 16'h0007);

        $display("=== PASS: %0d  FAIL: %0d ===", pass_cnt, fail_cnt);
        $finish;
    end

endmodule
