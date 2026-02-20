// Comprehensive Testbench for RISC-V CPU - All RV32I Instruction Types
// Tests: R-type, I-type, S-type, B-type, U-type, J-type

module tb_riscv_cpu_top;
    logic clock;
    logic reset = 1;  // Initialize to avoid X; ensures clean negedge for memory load

    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    riscv_cpu_top cpu (.clock(clock), .reset(reset));

    // Load program into memory and run - all in one block for deterministic ordering
    // Imem has CLEAR_ON_RESET=0 so we load before reset and it persists
    initial begin
        int pass_count, fail_count;

        // Load memory first (imem has CLEAR_ON_RESET=0)
        // 0x00: addi x1, x0, 10 (0x00A00093)
        cpu.imem.memory[0]=8'h93; cpu.imem.memory[1]=8'h00; cpu.imem.memory[2]=8'hA0; cpu.imem.memory[3]=8'h00;
        // 0x04: addi x2, x0, 5 (0x00500113)
        cpu.imem.memory[4]=8'h13; cpu.imem.memory[5]=8'h01; cpu.imem.memory[6]=8'h50; cpu.imem.memory[7]=8'h00;
        // 0x08: add x3, x1, x2 (0x002081B3) R-type
        cpu.imem.memory[8]=8'hB3; cpu.imem.memory[9]=8'h81; cpu.imem.memory[10]=8'h20; cpu.imem.memory[11]=8'h00;
        // 0x0C: sub x4, x1, x2 (0x40208233) R-type
        cpu.imem.memory[12]=8'h33; cpu.imem.memory[13]=8'h82; cpu.imem.memory[14]=8'h20; cpu.imem.memory[15]=8'h40;
        // 0x10: and x5, x1, x2 (0x0020F2B3) R-type
        cpu.imem.memory[16]=8'hB3; cpu.imem.memory[17]=8'hF2; cpu.imem.memory[18]=8'h20; cpu.imem.memory[19]=8'h00;
        // 0x14: or x6, x1, x2 (0x0020E333) R-type
        cpu.imem.memory[20]=8'h33; cpu.imem.memory[21]=8'hE3; cpu.imem.memory[22]=8'h20; cpu.imem.memory[23]=8'h00;
        // 0x18: xor x7, x1, x2 (0x0020C3B3) R-type
        cpu.imem.memory[24]=8'hB3; cpu.imem.memory[25]=8'hC3; cpu.imem.memory[26]=8'h20; cpu.imem.memory[27]=8'h00;
        // 0x1C: lui x8, 0x12345 (0x12345437) U-type
        cpu.imem.memory[28]=8'h37; cpu.imem.memory[29]=8'h54; cpu.imem.memory[30]=8'h34; cpu.imem.memory[31]=8'h12;
        // 0x20: jal x9, 0x08 (offset=8) (0x008004EF) J-type
        cpu.imem.memory[32]=8'hEF; cpu.imem.memory[33]=8'h04; cpu.imem.memory[34]=8'h80; cpu.imem.memory[35]=8'h00;
        // 0x24: addi x10, x0, 99 (should be skipped!)
        cpu.imem.memory[36]=8'h13; cpu.imem.memory[37]=8'h05; cpu.imem.memory[38]=8'h30; cpu.imem.memory[39]=8'h06;
        // 0x28: addi x11, x0, 20 (JAL target) (0x01400593)
        cpu.imem.memory[40]=8'h93; cpu.imem.memory[41]=8'h05; cpu.imem.memory[42]=8'h40; cpu.imem.memory[43]=8'h01;
        // 0x2C: sw x1, 0(sp) (0x00112023) S-type
        cpu.imem.memory[44]=8'h23; cpu.imem.memory[45]=8'h20; cpu.imem.memory[46]=8'h11; cpu.imem.memory[47]=8'h00;
        // 0x30: lw x12, 0(sp) (0x00012603) I-type load
        cpu.imem.memory[48]=8'h03; cpu.imem.memory[49]=8'h26; cpu.imem.memory[50]=8'h01; cpu.imem.memory[51]=8'h00;
        // 0x34: beq x1, x1, 8 (offset=8) (0x00108463) B-type
        cpu.imem.memory[52]=8'h63; cpu.imem.memory[53]=8'h84; cpu.imem.memory[54]=8'h10; cpu.imem.memory[55]=8'h00;
        // 0x38: addi x13, x0, 99 (should be skipped!)
        cpu.imem.memory[56]=8'h93; cpu.imem.memory[57]=8'h06; cpu.imem.memory[58]=8'h30; cpu.imem.memory[59]=8'h06;
        // 0x3C: addi x14, x0, 30 (BEQ target) (0x01E00713)
        cpu.imem.memory[60]=8'h13; cpu.imem.memory[61]=8'h07; cpu.imem.memory[62]=8'hE0; cpu.imem.memory[63]=8'h01;

        $display("========================================");
        $display("RISC-V CPU Comprehensive ISA Test");
        $display("========================================");
        reset = 1;
        repeat(5) @(posedge clock);
        reset = 0;
        cpu.regfile.registers[2] = 32'h00001000;  // sp (after reset clears regfile)

        $display("Comprehensive RV32I Test Program Loaded:");
        $display("  R-type: ADD, SUB, AND, OR, XOR");
        $display("  I-type: ADDI, LW");
        $display("  S-type: SW");
        $display("  B-type: BEQ");
        $display("  U-type: LUI");
        $display("  J-type: JAL");
        $display("Reset released, executing program...\n");

        repeat(40) @(posedge clock);
        
        $display("\n========================================");
        $display("Checking Results:");
        $display("========================================");
        
        // Check I-type
        if (cpu.regfile.registers[1] == 32'd10)
            $display("[PASS] x1 (I-type ADDI) = %0d (expected 10)", cpu.regfile.registers[1]);
        else
            $display("[FAIL] x1 = %0d (expected 10)", cpu.regfile.registers[1]);
            
        if (cpu.regfile.registers[2] == 32'd5)
            $display("[PASS] x2 (I-type ADDI) = %0d (expected 5)", cpu.regfile.registers[2]);
        else
            $display("[FAIL] x2 = %0d (expected 5)", cpu.regfile.registers[2]);
        
        // Check R-type
        if (cpu.regfile.registers[3] == 32'd15)
            $display("[PASS] x3 (R-type ADD) = %0d (expected 15)", cpu.regfile.registers[3]);
        else
            $display("[FAIL] x3 = %0d (expected 15)", cpu.regfile.registers[3]);
            
        if (cpu.regfile.registers[4] == 32'd5)
            $display("[PASS] x4 (R-type SUB) = %0d (expected 5)", cpu.regfile.registers[4]);
        else
            $display("[FAIL] x4 = %0d (expected 5)", cpu.regfile.registers[4]);
            
        if (cpu.regfile.registers[5] == 32'd0)
            $display("[PASS] x5 (R-type AND) = %0d (expected 0)", cpu.regfile.registers[5]);
        else
            $display("[FAIL] x5 = %0d (expected 0)", cpu.regfile.registers[5]);
            
        if (cpu.regfile.registers[6] == 32'd15)
            $display("[PASS] x6 (R-type OR) = %0d (expected 15)", cpu.regfile.registers[6]);
        else
            $display("[FAIL] x6 = %0d (expected 15)", cpu.regfile.registers[6]);
            
        if (cpu.regfile.registers[7] == 32'd15)
            $display("[PASS] x7 (R-type XOR) = %0d (expected 15)", cpu.regfile.registers[7]);
        else
            $display("[FAIL] x7 = %0d (expected 15)", cpu.regfile.registers[7]);
        
        // Check U-type
        if (cpu.regfile.registers[8] == 32'h12345000)
            $display("[PASS] x8 (U-type LUI) = 0x%08h (expected 0x12345000)", cpu.regfile.registers[8]);
        else
            $display("[FAIL] x8 = 0x%08h (expected 0x12345000)", cpu.regfile.registers[8]);
        
        // Check J-type
        if (cpu.regfile.registers[9] == 32'h00000024)
            $display("[PASS] x9 (J-type JAL) = 0x%08h (expected 0x24)", cpu.regfile.registers[9]);
        else
            $display("[FAIL] x9 = 0x%08h (expected 0x24)", cpu.regfile.registers[9]);
            
        if (cpu.regfile.registers[10] == 32'd0)
            $display("[PASS] x10 (skipped by JAL) = %0d (expected 0)", cpu.regfile.registers[10]);
        else
            $display("[FAIL] x10 = %0d (should be 0, was skipped)", cpu.regfile.registers[10]);
            
        if (cpu.regfile.registers[11] == 32'd20)
            $display("[PASS] x11 (after JAL) = %0d (expected 20)", cpu.regfile.registers[11]);
        else
            $display("[FAIL] x11 = %0d (expected 20)", cpu.regfile.registers[11]);
        
        // Check S-type and I-type load
        if (cpu.regfile.registers[12] == 32'd10)
            $display("[PASS] x12 (I-type LW after S-type SW) = %0d (expected 10)", cpu.regfile.registers[12]);
        else
            $display("[FAIL] x12 = %0d (expected 10)", cpu.regfile.registers[12]);
        
        // Check B-type
        if (cpu.regfile.registers[13] == 32'd0)
            $display("[PASS] x13 (skipped by BEQ) = %0d (expected 0)", cpu.regfile.registers[13]);
        else
            $display("[FAIL] x13 = %0d (should be 0, was skipped)", cpu.regfile.registers[13]);
            
        if (cpu.regfile.registers[14] == 32'd30)
            $display("[PASS] x14 (after BEQ) = %0d (expected 30)", cpu.regfile.registers[14]);
        else
            $display("[FAIL] x14 = %0d (expected 30)", cpu.regfile.registers[14]);
        
        $display("\n========================================");
        $display("Register File Summary:");
        $display("========================================");
        for (int i = 0; i <= 14; i++) begin
            $display("x%-2d = 0x%08h (%0d)", i, cpu.regfile.registers[i], cpu.regfile.registers[i]);
        end
        
        // Final verdict
        pass_count = 0;
        fail_count = 0;
        
        if (cpu.regfile.registers[1] == 32'd10) pass_count++; else fail_count++;
        if (cpu.regfile.registers[2] == 32'd5) pass_count++; else fail_count++;
        if (cpu.regfile.registers[3] == 32'd15) pass_count++; else fail_count++;
        if (cpu.regfile.registers[4] == 32'd5) pass_count++; else fail_count++;
        if (cpu.regfile.registers[5] == 32'd0) pass_count++; else fail_count++;
        if (cpu.regfile.registers[6] == 32'd15) pass_count++; else fail_count++;
        if (cpu.regfile.registers[7] == 32'd15) pass_count++; else fail_count++;
        if (cpu.regfile.registers[8] == 32'h12345000) pass_count++; else fail_count++;
        if (cpu.regfile.registers[9] == 32'h24) pass_count++; else fail_count++;
        if (cpu.regfile.registers[10] == 32'd0) pass_count++; else fail_count++;
        if (cpu.regfile.registers[11] == 32'd20) pass_count++; else fail_count++;
        if (cpu.regfile.registers[12] == 32'd10) pass_count++; else fail_count++;
        if (cpu.regfile.registers[13] == 32'd0) pass_count++; else fail_count++;
        if (cpu.regfile.registers[14] == 32'd30) pass_count++; else fail_count++;
        
        $display("\n========================================");
        $display("Test Results: %0d PASS, %0d FAIL", pass_count, fail_count);
        $display("========================================");
        
        if (fail_count == 0)
            $display("TEST PASSED - All RV32I instruction types work!");
        else
            $display("TEST FAILED - %0d checks failed", fail_count);
            
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
