// Compares a branch that can use WB->EX forwarding against one that must rely
// on the register file value read in ID during the producer's WB cycle.

module tb_branch_wb_id_hazard;
    logic clock;
    logic reset = 1;

    logic [11:0] addr_one_nop;
    logic [31:0] data_one_nop;
    logic [11:0] addr_two_nop;
    logic [31:0] data_two_nop;

    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    riscv_cpu_top cpu_one_nop (
        .clock(clock),
        .reset(reset),
        .instruction_data(data_one_nop),
        .instruction_address(addr_one_nop),
        .debug_done(),
        .debug_regs_flat()
    );

    simple_memory #(
        .ADDR_WIDTH(12),
        .CLEAR_ON_RESET(0)
    ) imem_one_nop (
        .clock(clock),
        .reset(reset),
        .enable(1'b1),
        .write_enable(1'b0),
        .byte_enable(4'b1111),
        .address(addr_one_nop),
        .write_data(32'h0),
        .read_data(data_one_nop)
    );

    riscv_cpu_top cpu_two_nop (
        .clock(clock),
        .reset(reset),
        .instruction_data(data_two_nop),
        .instruction_address(addr_two_nop),
        .debug_done(),
        .debug_regs_flat()
    );

    simple_memory #(
        .ADDR_WIDTH(12),
        .CLEAR_ON_RESET(0)
    ) imem_two_nop (
        .clock(clock),
        .reset(reset),
        .enable(1'b1),
        .write_enable(1'b0),
        .byte_enable(4'b1111),
        .address(addr_two_nop),
        .write_data(32'h0),
        .read_data(data_two_nop)
    );

    initial begin
        int pass_count, fail_count;

        // One-NOP case:
        // addi x1, x0, 1
        // addi x1, x1, -1
        // nop
        // beq x1, x0, target
        // addi x2, x0, 99   ; should be skipped
        // jal  x0, done
        // target: addi x3, x0, 42
        imem_one_nop.memory[0]  = 8'h93; imem_one_nop.memory[1]  = 8'h00; imem_one_nop.memory[2]  = 8'h10; imem_one_nop.memory[3]  = 8'h00;
        imem_one_nop.memory[4]  = 8'h93; imem_one_nop.memory[5]  = 8'h80; imem_one_nop.memory[6]  = 8'hF0; imem_one_nop.memory[7]  = 8'hFF;
        imem_one_nop.memory[8]  = 8'h13; imem_one_nop.memory[9]  = 8'h00; imem_one_nop.memory[10] = 8'h00; imem_one_nop.memory[11] = 8'h00;
        imem_one_nop.memory[12] = 8'h63; imem_one_nop.memory[13] = 8'h86; imem_one_nop.memory[14] = 8'h00; imem_one_nop.memory[15] = 8'h00;
        imem_one_nop.memory[16] = 8'h13; imem_one_nop.memory[17] = 8'h01; imem_one_nop.memory[18] = 8'h30; imem_one_nop.memory[19] = 8'h06;
        imem_one_nop.memory[20] = 8'h6F; imem_one_nop.memory[21] = 8'h00; imem_one_nop.memory[22] = 8'h80; imem_one_nop.memory[23] = 8'h00;
        imem_one_nop.memory[24] = 8'h93; imem_one_nop.memory[25] = 8'h01; imem_one_nop.memory[26] = 8'hA0; imem_one_nop.memory[27] = 8'h02;

        // Two-NOP case: same program, but with one extra nop before the branch.
        imem_two_nop.memory[0]  = 8'h93; imem_two_nop.memory[1]  = 8'h00; imem_two_nop.memory[2]  = 8'h10; imem_two_nop.memory[3]  = 8'h00;
        imem_two_nop.memory[4]  = 8'h93; imem_two_nop.memory[5]  = 8'h80; imem_two_nop.memory[6]  = 8'hF0; imem_two_nop.memory[7]  = 8'hFF;
        imem_two_nop.memory[8]  = 8'h13; imem_two_nop.memory[9]  = 8'h00; imem_two_nop.memory[10] = 8'h00; imem_two_nop.memory[11] = 8'h00;
        imem_two_nop.memory[12] = 8'h13; imem_two_nop.memory[13] = 8'h00; imem_two_nop.memory[14] = 8'h00; imem_two_nop.memory[15] = 8'h00;
        imem_two_nop.memory[16] = 8'h63; imem_two_nop.memory[17] = 8'h86; imem_two_nop.memory[18] = 8'h00; imem_two_nop.memory[19] = 8'h00;
        imem_two_nop.memory[20] = 8'h13; imem_two_nop.memory[21] = 8'h01; imem_two_nop.memory[22] = 8'h30; imem_two_nop.memory[23] = 8'h06;
        imem_two_nop.memory[24] = 8'h6F; imem_two_nop.memory[25] = 8'h00; imem_two_nop.memory[26] = 8'h80; imem_two_nop.memory[27] = 8'h00;
        imem_two_nop.memory[28] = 8'h93; imem_two_nop.memory[29] = 8'h01; imem_two_nop.memory[30] = 8'hA0; imem_two_nop.memory[31] = 8'h02;

        $display("========================================");
        $display("Branch WB->ID Hazard Test");
        $display("========================================");

        reset = 1;
        repeat(5) @(posedge clock);
        reset = 0;

        repeat(25) @(posedge clock);

        pass_count = 0;
        fail_count = 0;

        if ((cpu_one_nop.regfile.registers[2] == 32'd0) &&
            (cpu_one_nop.regfile.registers[3] == 32'd42)) begin
            pass_count++;
            $display("[PASS] one-nop case branches correctly");
        end else begin
            fail_count++;
            $display("[FAIL] one-nop case unexpected state: x2=%0d x3=%0d",
                     cpu_one_nop.regfile.registers[2], cpu_one_nop.regfile.registers[3]);
        end

        if ((cpu_two_nop.regfile.registers[2] == 32'd0) &&
            (cpu_two_nop.regfile.registers[3] == 32'd42)) begin
            pass_count++;
            $display("[PASS] two-nop case now branches correctly");
        end else begin
            fail_count++;
            $display("[FAIL] two-nop case unexpected state after fix: x1=%0d x2=%0d x3=%0d",
                     cpu_two_nop.regfile.registers[1], cpu_two_nop.regfile.registers[2],
                     cpu_two_nop.regfile.registers[3]);
        end

        $display("\n========================================");
        $display("Test Results: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("========================================");

        if (fail_count == 0)
            $display("TEST PASSED - WB-to-ID branch hazard is fixed.");
        else
            $fatal(1, "TEST FAILED - %0d checks failed", fail_count);

        $finish(0);
    end

    initial begin
        #50000;
        $fatal(1, "Timeout");
    end
endmodule
