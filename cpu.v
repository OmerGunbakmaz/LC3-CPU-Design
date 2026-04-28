module lc3_cpu (
    input  wire        clk,
    input  wire        reset,
    output wire [15:0] mem_addr,
    output wire [15:0] mem_wdata,
    input  wire [15:0] mem_rdata,
    output wire        mem_we,
    output wire        mem_re,
    output wire [15:0] pc_out,
    output wire [2:0]  nzp_out,
    output wire        halted
);

    reg [3:0] state, next_state;
    localparam S_FETCH      = 4'd0;
    localparam S_DECODE     = 4'd1;
    localparam S_EXEC_ALU   = 4'd2;
    localparam S_EXEC_MEM1  = 4'd3;
    localparam S_EXEC_MEM2  = 4'd4;
    localparam S_EXEC_MEM3  = 4'd5;
    localparam S_EXEC_BR    = 4'd6;
    localparam S_EXEC_JSR   = 4'd7;
    localparam S_EXEC_TRAP  = 4'd8;
    localparam S_HALTED     = 4'd9;
    localparam S_STORE1     = 4'd10;
    localparam S_STORE2     = 4'd11;
    localparam S_STORE3     = 4'd12;
    localparam S_STORE4     = 4'd13;

    reg [15:0] PC;
    reg [15:0] IR;
    reg [15:0] REG_FILE [0:7];
    reg        N, Z, P;
    reg        halt_flag;

    reg [15:0] mar;
    reg [15:0] mdr;

    wire [3:0]  opcode    = IR[15:12];
    wire [2:0]  dr        = IR[11:9];
    wire [2:0]  sr1       = IR[8:6];
    wire [2:0]  sr2       = IR[2:0];
    wire        imm_flag  = IR[5];
    wire [4:0]  imm5      = IR[4:0];
    wire [5:0]  offset6   = IR[5:0];
    wire [8:0]  offset9   = IR[8:0];
    wire [10:0] offset11  = IR[10:0];
    wire [7:0]  trapvect8 = IR[7:0];
    wire [2:0]  nzp_bits  = IR[11:9];
    wire        jsr_flag  = IR[11];

    wire [3:0]  decode_opcode = mem_rdata[15:12];

    wire [15:0] sext_imm5    = {{11{imm5[4]}}, imm5};
    wire [15:0] sext_offset6 = {{10{offset6[5]}}, offset6};
    wire [15:0] sext_offset9 = {{7{offset9[8]}}, offset9};
    wire [15:0] sext_offset11= {{5{offset11[10]}}, offset11};
    wire [15:0] zext_trapvect= {8'b0, trapvect8};

    localparam OP_BR   = 4'b0000;
    localparam OP_ADD  = 4'b0001;
    localparam OP_LD   = 4'b0010;
    localparam OP_ST   = 4'b0011;
    localparam OP_JSR  = 4'b0100;
    localparam OP_AND  = 4'b0101;
    localparam OP_LDR  = 4'b0110;
    localparam OP_STR  = 4'b0111;
    localparam OP_RTI  = 4'b1000;
    localparam OP_NOT  = 4'b1001;
    localparam OP_LDI  = 4'b1010;
    localparam OP_STI  = 4'b1011;
    localparam OP_JMP  = 4'b1100;
    localparam OP_RES  = 4'b1101;
    localparam OP_LEA  = 4'b1110;
    localparam OP_TRAP = 4'b1111;

    reg        mem_we_reg, mem_re_reg;
    reg [15:0] mem_addr_reg;
    reg [15:0] mem_wdata_reg;

    assign mem_addr  = mem_addr_reg;
    assign mem_wdata = mem_wdata_reg;
    assign mem_we    = mem_we_reg;
    assign mem_re    = mem_re_reg;

    assign pc_out  = PC;
    assign nzp_out = {N, Z, P};
    assign halted  = halt_flag;

    task update_nzp;
        input [15:0] value;
        begin
            N <= value[15];
            Z <= (value == 16'b0);
            P <= (~value[15]) & (value != 16'b0);
        end
    endtask

    always @(posedge clk or posedge reset) begin
        if (reset)
            state <= S_FETCH;
        else
            state <= next_state;
    end

    always @(*) begin
        next_state = state;
        case (state)
            S_FETCH: next_state = halt_flag ? S_HALTED : S_DECODE;
            S_DECODE: begin
                case (decode_opcode)
                    OP_ADD, OP_AND, OP_NOT: next_state = S_EXEC_ALU;
                    OP_BR:                  next_state = S_EXEC_BR;
                    OP_JMP:                 next_state = S_EXEC_BR;
                    OP_JSR:                 next_state = S_EXEC_JSR;
                    OP_LD, OP_LDR, OP_LDI: next_state = S_EXEC_MEM1;
                    OP_LEA:                 next_state = S_EXEC_ALU;
                    OP_ST, OP_STR, OP_STI: next_state = S_STORE1;
                    OP_TRAP:                next_state = S_EXEC_TRAP;
                    default:                next_state = S_FETCH;
                endcase
            end
            S_EXEC_ALU:  next_state = S_FETCH;
            S_EXEC_BR:   next_state = S_FETCH;
            S_EXEC_JSR:  next_state = S_FETCH;
            S_EXEC_MEM1: next_state = (opcode == OP_LDI) ? S_EXEC_MEM2 : S_EXEC_MEM3;
            S_EXEC_MEM2: next_state = S_EXEC_MEM3;
            S_EXEC_MEM3: next_state = S_FETCH;
            S_EXEC_TRAP: next_state = (trapvect8 == 8'h25) ? S_HALTED : S_FETCH;
            S_STORE1:    next_state = (opcode == OP_STI) ? S_STORE3 : S_STORE2;
            S_STORE2:    next_state = S_FETCH;
            S_STORE3:    next_state = S_STORE4;
            S_STORE4:    next_state = S_FETCH;
            S_HALTED:    next_state = S_HALTED;
            default:     next_state = S_FETCH;
        endcase
    end

    integer i;

    always @(posedge clk or posedge reset) begin
        if (reset) begin
            PC            <= 16'h3000;
            IR            <= 16'b0;
            N             <= 0;
            Z             <= 1;
            P             <= 0;
            halt_flag     <= 0;
            mar           <= 16'b0;
            mdr           <= 16'b0;
            mem_we_reg    <= 0;
            mem_re_reg    <= 0;
            mem_addr_reg  <= 16'b0;
            mem_wdata_reg <= 16'b0;
            for (i = 0; i < 8; i = i + 1)
                REG_FILE[i] <= 16'b0;
        end else begin
            mem_we_reg <= 0;
            mem_re_reg <= 0;

            case (state)
                S_FETCH: begin
                    if (!halt_flag) begin
                        mem_addr_reg <= PC;
                        mem_re_reg   <= 1;
                        PC           <= PC + 16'd1;
                    end
                end

                S_DECODE: begin
                    IR <= mem_rdata;
                end

                S_EXEC_ALU: begin
                    case (opcode)
                        OP_ADD: begin
                            if (imm_flag) begin
                                REG_FILE[dr] <= REG_FILE[sr1] + sext_imm5;
                                update_nzp(REG_FILE[sr1] + sext_imm5);
                            end else begin
                                REG_FILE[dr] <= REG_FILE[sr1] + REG_FILE[sr2];
                                update_nzp(REG_FILE[sr1] + REG_FILE[sr2]);
                            end
                        end
                        OP_AND: begin
                            if (imm_flag) begin
                                REG_FILE[dr] <= REG_FILE[sr1] & sext_imm5;
                                update_nzp(REG_FILE[sr1] & sext_imm5);
                            end else begin
                                REG_FILE[dr] <= REG_FILE[sr1] & REG_FILE[sr2];
                                update_nzp(REG_FILE[sr1] & REG_FILE[sr2]);
                            end
                        end
                        OP_NOT: begin
                            REG_FILE[dr] <= ~REG_FILE[sr1];
                            update_nzp(~REG_FILE[sr1]);
                        end
                        OP_LEA: begin
                            REG_FILE[dr] <= PC + sext_offset9;
                            update_nzp(PC + sext_offset9);
                        end
                    endcase
                end

                S_EXEC_BR: begin
                    case (opcode)
                        OP_BR: begin
                            if ((nzp_bits[2] & N) | (nzp_bits[1] & Z) | (nzp_bits[0] & P))
                                PC <= PC + sext_offset9;
                        end
                        OP_JMP: PC <= REG_FILE[sr1];
                    endcase
                end

                S_EXEC_JSR: begin
                    REG_FILE[7] <= PC;
                    if (jsr_flag)
                        PC <= PC + sext_offset11;
                    else
                        PC <= REG_FILE[sr1];
                end

                S_EXEC_MEM1: begin
                    case (opcode)
                        OP_LD, OP_LDI: begin
                            mar          <= PC + sext_offset9;
                            mem_addr_reg <= PC + sext_offset9;
                            mem_re_reg   <= 1;
                        end
                        OP_LDR: begin
                            mar          <= REG_FILE[sr1] + sext_offset6;
                            mem_addr_reg <= REG_FILE[sr1] + sext_offset6;
                            mem_re_reg   <= 1;
                        end
                    endcase
                end

                S_EXEC_MEM2: begin
                    mar          <= mem_rdata;
                    mem_addr_reg <= mem_rdata;
                    mem_re_reg   <= 1;
                end

                S_EXEC_MEM3: begin
                    REG_FILE[dr] <= mem_rdata;
                    update_nzp(mem_rdata);
                end

                S_STORE1: begin
                    case (opcode)
                        OP_ST: begin
                            mar          <= PC + sext_offset9;
                            mem_addr_reg <= PC + sext_offset9;
                        end
                        OP_STR: begin
                            mar          <= REG_FILE[sr1] + sext_offset6;
                            mem_addr_reg <= REG_FILE[sr1] + sext_offset6;
                        end
                        OP_STI: begin
                            mar          <= PC + sext_offset9;
                            mem_addr_reg <= PC + sext_offset9;
                            mem_re_reg   <= 1;
                        end
                    endcase
                end

                S_STORE2: begin
                    mem_addr_reg  <= mar;
                    mem_wdata_reg <= REG_FILE[dr];
                    mem_we_reg    <= 1;
                end

                S_STORE3: begin
                    mar          <= mem_rdata;
                    mem_addr_reg <= mem_rdata;
                end

                S_STORE4: begin
                    mem_addr_reg  <= mar;
                    mem_wdata_reg <= REG_FILE[dr];
                    mem_we_reg    <= 1;
                end

                S_EXEC_TRAP: begin
                    REG_FILE[7] <= PC;
                    if (trapvect8 == 8'h25) begin
                        halt_flag <= 1;
                    end else begin
                        mem_addr_reg <= zext_trapvect;
                        mem_re_reg   <= 1;
                        PC           <= zext_trapvect;
                    end
                end

                S_HALTED: halt_flag <= 1;
            endcase
        end
    end

endmodule
