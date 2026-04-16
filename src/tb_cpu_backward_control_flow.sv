// Focused CPU-level testbench for backward control-flow targets.
// Runs independent infinite loops so backward BEQ and backward JAL can be
// verified without needing a loop-exit branch.

module tb_cpu_backward_control_flow;
    logic clock;
    logic reset = 1;

    logic [11:0] beq_instruction_address;
    logic [31:0] beq_instruction_data;
    logic [11:0] jal_instruction_address;
    logic [31:0] jal_instruction_data;

    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    riscv_cpu_top cpu_beq (
        .clock(clock),
        .reset(reset),
        .instruction_data(beq_instruction_data),
        .instruction_address(beq_instruction_address),
        .debug_done(),
        .debug_regs_flat()
    );

    simple_memory #(
        .ADDR_WIDTH(12),
        .CLEAR_ON_RESET(0)
    ) imem_beq (
        .clock(clock),
        .reset(reset),
        .enable(1'b1),
        .write_enable(1'b0),
        .byte_enable(4'b1111),
        .address(beq_instruction_address),
        .write_data(32'h0),
        .read_data(beq_instruction_data)
    );

    riscv_cpu_top cpu_jal (
        .clock(clock),
        .reset(reset),
        .instruction_data(jal_instruction_data),
        .instruction_address(jal_instruction_address),
        .debug_done(),
        .debug_regs_flat()
    );

    simple_memory #(
        .ADDR_WIDTH(12),
        .CLEAR_ON_RESET(0)
    ) imem_jal (
        .clock(clock),
        .reset(reset),
        .enable(1'b1),
        .write_enable(1'b0),
        .byte_enable(4'b1111),
        .address(jal_instruction_address),
        .write_data(32'h0),
        .read_data(jal_instruction_data)
    );

    initial begin
        int pass_count, fail_count;

        // Backward BEQ program:
        //   0x00: addi x2, x2, 1
        //   0x04: beq  x0, x0, -4
        imem_beq.memory[0] = 8'h13; imem_beq.memory[1] = 8'h01; imem_beq.memory[2] = 8'h11; imem_beq.memory[3] = 8'h00;
        imem_beq.memory[4] = 8'hE3; imem_beq.memory[5] = 8'h0E; imem_beq.memory[6] = 8'h00; imem_beq.memory[7] = 8'hFE;

        // Backward JAL program:
        //   0x00: addi x2, x2, 1
        //   0x04: jal  x5, -4
        imem_jal.memory[0] = 8'h13; imem_jal.memory[1] = 8'h01; imem_jal.memory[2] = 8'h11; imem_jal.memory[3] = 8'h00;
        imem_jal.memory[4] = 8'hEF; imem_jal.memory[5] = 8'hF2; imem_jal.memory[6] = 8'hDF; imem_jal.memory[7] = 8'hFF;

        $display("========================================");
        $display("CPU Backward Control-Flow Test");
        $display("========================================");

        reset = 1;
        repeat(5) @(posedge clock);
        reset = 0;

        $display("Running backward BEQ and backward JAL loops...\n");
        repeat(30) @(posedge clock);

        $display("\n========================================");
        $display("Checking Results:");
        $display("========================================");

        pass_count = 0;
        fail_count = 0;

        if (cpu_beq.regfile.registers[2] > 32'd1) begin
            pass_count++;
            $display("[PASS] backward BEQ re-entered loop body, x2 = %0d", cpu_beq.regfile.registers[2]);
        end else begin
            fail_count++;
            $display("[FAIL] backward BEQ did not re-enter loop body, x2 = %0d", cpu_beq.regfile.registers[2]);
        end

        if (cpu_jal.regfile.registers[2] > 32'd1) begin
            pass_count++;
            $display("[PASS] backward JAL re-entered loop body, x2 = %0d", cpu_jal.regfile.registers[2]);
        end else begin
            fail_count++;
            $display("[FAIL] backward JAL did not re-enter loop body, x2 = %0d", cpu_jal.regfile.registers[2]);
        end

        if (cpu_jal.regfile.registers[5] == 32'h00000008) begin
            pass_count++;
            $display("[PASS] backward JAL wrote link register x5 = 0x%08h", cpu_jal.regfile.registers[5]);
        end else begin
            fail_count++;
            $display("[FAIL] backward JAL link register x5 = 0x%08h (expected 0x00000008)",
                     cpu_jal.regfile.registers[5]);
        end

        $display("\n========================================");
        $display("Test Results: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("========================================");

        if (fail_count == 0)
            $display("TEST PASSED - Backward BEQ and backward JAL work in the full CPU pipeline!");
        else
            $fatal(1, "TEST FAILED - %0d checks failed", fail_count);

        $finish(0);
    end

    initial begin
        #50000;
        $fatal(1, "Timeout");
    end

    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
