// Testbench: Fibonacci program loaded from imem_program.hex
// Expected: x5=89 (F11), x6=144 (F12) after 11 loop iterations

module tb_fibonacci;
    logic clock;
    logic reset = 1;
    logic [11:0] instruction_address;
    logic [31:0] instruction_data;

    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    riscv_cpu_top cpu (
        .clock(clock),
        .reset(reset),
        .instruction_data(instruction_data),
        .instruction_address(instruction_address),
        .debug_done(debug_done),
        .debug_regs_flat()
    );
    logic debug_done;

    simple_memory #(
        .ADDR_WIDTH(12),
        .CLEAR_ON_RESET(0)
    ) imem (
        .clock(clock),
        .reset(reset),
        .enable(1'b1),
        .write_enable(1'b0),
        .byte_enable(4'b1111),
        .address(instruction_address),
        .write_data(32'h0),
        .read_data(instruction_data)
    );

    initial begin
        // Load Fibonacci program (imem_program.hex decoded to bytes)
        // PC=0:  addi x5, x0, 0     (0x00000293)
        imem.memory[0]=8'h93; imem.memory[1]=8'h02; imem.memory[2]=8'h00; imem.memory[3]=8'h00;
        // PC=4:  addi x6, x0, 1     (0x00100313)
        imem.memory[4]=8'h13; imem.memory[5]=8'h03; imem.memory[6]=8'h10; imem.memory[7]=8'h00;
        // PC=8:  addi x7, x0, 10    (0x00A00393)
        imem.memory[8]=8'h93; imem.memory[9]=8'h03; imem.memory[10]=8'hA0; imem.memory[11]=8'h00;
        // PC=12: blt x7, x0, +24    (0x00038C63)
        imem.memory[12]=8'h63; imem.memory[13]=8'h8C; imem.memory[14]=8'h03; imem.memory[15]=8'h00;
        // PC=16: addi x7, x7, -1    (0xFFF38393)
        imem.memory[16]=8'h93; imem.memory[17]=8'h83; imem.memory[18]=8'hF3; imem.memory[19]=8'hFF;
        // PC=20: add x2, x5, x6     (0x00628133)
        imem.memory[20]=8'h33; imem.memory[21]=8'h81; imem.memory[22]=8'h62; imem.memory[23]=8'h00;
        // PC=24: addi x5, x6, 0     (0x00030293)
        imem.memory[24]=8'h93; imem.memory[25]=8'h02; imem.memory[26]=8'h03; imem.memory[27]=8'h00;
        // PC=28: addi x6, x2, 0     (0x00010313)
        imem.memory[28]=8'h13; imem.memory[29]=8'h03; imem.memory[30]=8'h01; imem.memory[31]=8'h00;
        // PC=32: jal x0, -20        (0xFEDFF06F)
        imem.memory[32]=8'h6F; imem.memory[33]=8'hF0; imem.memory[34]=8'hDF; imem.memory[35]=8'hFE;
        // PC=36: sentinel           (0xFFFFFFFF)
        imem.memory[36]=8'hFF; imem.memory[37]=8'hFF; imem.memory[38]=8'hFF; imem.memory[39]=8'hFF;

        $display("========================================");
        $display("Fibonacci Program Test");
        $display("========================================");
        reset = 1;
        repeat(5) @(posedge clock);
        reset = 0;
        $display("Reset released, running Fibonacci loop...\n");

        // Wait for debug_done (sentinel reached and pipeline drained)
        @(posedge debug_done);
        @(posedge clock);  // one more cycle so WB completes

        $display("========================================");
        $display("Results (expected 11 iterations: counter 10 -> -1):");
        $display("========================================");

        if (cpu.regfile.registers[5] == 32'd89)
            $display("[PASS] x5 (a) = %0d (expected 89 = F(11))", cpu.regfile.registers[5]);
        else
            $display("[FAIL] x5 (a) = %0d (expected 89)", cpu.regfile.registers[5]);

        if (cpu.regfile.registers[6] == 32'd144)
            $display("[PASS] x6 (b) = %0d (expected 144 = F(12))", cpu.regfile.registers[6]);
        else
            $display("[FAIL] x6 (b) = %0d (expected 144)", cpu.regfile.registers[6]);

        if (cpu.regfile.registers[7] == 32'hFFFFFFFF)
            $display("[PASS] x7 (counter) = 0x%08h (expected -1)", cpu.regfile.registers[7]);
        else
            $display("[FAIL] x7 (counter) = 0x%08h (expected 0xFFFFFFFF)", cpu.regfile.registers[7]);

        if (cpu.regfile.registers[2] == 32'd144)
            $display("[PASS] x2 (tmp) = %0d (expected 144)", cpu.regfile.registers[2]);
        else
            $display("[FAIL] x2 (tmp) = %0d (expected 144)", cpu.regfile.registers[2]);

        $display("\n========================================");
        $display("Register Dump:");
        $display("========================================");
        for (int i = 0; i <= 7; i++)
            $display("x%-2d = 0x%08h (%0d)", i, cpu.regfile.registers[i], $signed(cpu.regfile.registers[i]));

        $finish(0);
    end

    initial begin
        #50000;
        $fatal(1, "Timeout: debug_done never asserted");
    end

    initial begin
        $dumpfile("fib_dump.fst");
        $dumpvars(0);
    end

endmodule
