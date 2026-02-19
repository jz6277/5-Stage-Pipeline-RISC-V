// Comprehensive Testbench for Immediate Generator
// Tests all RV32I immediate formats: I, S, B, U, J

module tb_immediate_generator;

    // Testbench signals
    logic [31:0] instruction;
    logic [2:0]  imm_src;
    logic [31:0] immediate;

    // Test tracking
    int error_count = 0;
    int test_count = 0;

    // Instantiate DUT
    immediate_generator dut (
        .instruction(instruction),
        .imm_src(imm_src),
        .immediate(immediate)
    );

    // Immediate format types
    localparam logic [2:0] IMM_I = 3'b000;
    localparam logic [2:0] IMM_S = 3'b001;
    localparam logic [2:0] IMM_B = 3'b010;
    localparam logic [2:0] IMM_U = 3'b011;
    localparam logic [2:0] IMM_J = 3'b100;

    // Check immediate value
    task automatic check_immediate(input string test_name, input logic [31:0] expected);
        test_count++;
        #1;
        if (immediate !== expected) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_immediate_generator : dut.immediate : expected_value: 0x%08h actual_value: 0x%08h",
                     $time, expected, immediate);
            $display("  Test: %s", test_name);
        end
    endtask

    // Test immediate extraction
    task automatic test_imm(input string test_name, input logic [31:0] inst, 
                            input logic [2:0] src, input logic [31:0] expected);
        instruction = inst;
        imm_src = src;
        check_immediate(test_name, expected);
    endtask

    // Main test sequence
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("Immediate Generator Comprehensive Test");
        $display("========================================");

        // Initialize
        instruction = 32'h0;
        imm_src = IMM_I;
        #10;

        // ==========================================
        // Test 1: I-type Immediate (12-bit sign-extended)
        // ==========================================
        $display("\n[INFO] Test 1: I-type Immediate");
        
        // Positive immediate: ADDI x1, x0, 100
        test_imm("I-type: +100", 32'h06400093, IMM_I, 32'h00000064);
        
        // Negative immediate: ADDI x1, x0, -1
        test_imm("I-type: -1", 32'hFFF00093, IMM_I, 32'hFFFFFFFF);
        
        // Negative immediate: ADDI x1, x0, -100
        test_imm("I-type: -100", 32'hF9C00093, IMM_I, 32'hFFFFFF9C);
        
        // Max positive (2047)
        test_imm("I-type: +2047", 32'h7FF00093, IMM_I, 32'h000007FF);
        
        // Max negative (-2048)
        test_imm("I-type: -2048", 32'h80000093, IMM_I, 32'hFFFFF800);
        
        // Zero immediate
        test_imm("I-type: 0", 32'h00000093, IMM_I, 32'h00000000);

        // ==========================================
        // Test 2: S-type Immediate (12-bit sign-extended, split)
        // ==========================================
        $display("\n[INFO] Test 2: S-type Immediate");
        
        // SW x1, 100(x2): Store with offset 100
        // imm[11:5]=0x03, imm[4:0]=0x04, total=100
        test_imm("S-type: +100", 32'h06112223, IMM_S, 32'h00000064);
        
        // SW x1, -4(x2): Store with offset -4
        // imm[11:5]=0x7F, imm[4:0]=0x1C
        test_imm("S-type: -4", 32'hFE112E23, IMM_S, 32'hFFFFFFFC);
        
        // SW x1, 0(x2): Store with offset 0
        test_imm("S-type: 0", 32'h00112023, IMM_S, 32'h00000000);
        
        // Max positive (2047)
        test_imm("S-type: +2047", 32'h7E112FA3, IMM_S, 32'h000007FF);
        
        // Max negative (-2048)
        test_imm("S-type: -2048", 32'h80112023, IMM_S, 32'hFFFFF800);

        // ==========================================
        // Test 3: B-type Immediate (13-bit sign-extended, split)
        // ==========================================
        $display("\n[INFO] Test 3: B-type Immediate");
        
        // BEQ x1, x2, 8: Branch with offset 8
        test_imm("B-type: +8", 32'h00208463, IMM_B, 32'h00000008);
        
        // BEQ x1, x2, -4: Branch with offset -4
        test_imm("B-type: -4", 32'hFE208EE3, IMM_B, 32'hFFFFFFFC);
        
        // BEQ x1, x2, 100: Branch with offset 100
        test_imm("B-type: +100", 32'h06208263, IMM_B, 32'h00000064);
        
        // BEQ x1, x2, -100: Branch with offset -100
        // -100 = 0xFFFFFF9C, imm[12:0]=1_1111_1001_1100
        // B-type: imm[12]→[31]=1, imm[11]→[7]=1, imm[10:5]→[30:25]=111100, imm[4:1]→[11:8]=1110
        test_imm("B-type: -100", 32'hF8208EF3, IMM_B, 32'hFFFFFF9C);
        
        // Max positive (4094)
        test_imm("B-type: +4094", 32'h7E20FFE3, IMM_B, 32'h00000FFE);
        
        // Max negative (-4096)
        test_imm("B-type: -4096", 32'h80208063, IMM_B, 32'hFFFFF000);

        // ==========================================
        // Test 4: U-type Immediate (20-bit in upper)
        // ==========================================
        $display("\n[INFO] Test 4: U-type Immediate");
        
        // LUI x1, 0x12345: Load upper immediate
        test_imm("U-type: 0x12345000", 32'h123450B7, IMM_U, 32'h12345000);
        
        // LUI x1, 0xDEADB: Load upper immediate
        test_imm("U-type: 0xDEADB000", 32'hDEADB0B7, IMM_U, 32'hDEADB000);
        
        // LUI x1, 0x00000: Zero
        test_imm("U-type: 0x00000000", 32'h000000B7, IMM_U, 32'h00000000);
        
        // LUI x1, 0xFFFFF: All ones in upper
        test_imm("U-type: 0xFFFFF000", 32'hFFFFF0B7, IMM_U, 32'hFFFFF000);
        
        // LUI x1, 0x80000: Test sign bit
        test_imm("U-type: 0x80000000", 32'h800000B7, IMM_U, 32'h80000000);

        // ==========================================
        // Test 5: J-type Immediate (21-bit sign-extended, split)
        // ==========================================
        $display("\n[INFO] Test 5: J-type Immediate");
        
        // JAL x1, 8: Jump with offset 8
        test_imm("J-type: +8", 32'h008000EF, IMM_J, 32'h00000008);
        
        // JAL x1, -4: Jump with offset -4
        test_imm("J-type: -4", 32'hFFDFF0EF, IMM_J, 32'hFFFFFFFC);
        
        // JAL x1, 100: Jump with offset 100
        test_imm("J-type: +100", 32'h064000EF, IMM_J, 32'h00000064);
        
        // JAL x1, -52: Jump with offset -52 (simpler test)
        test_imm("J-type: -52", 32'hFCDFF0EF, IMM_J, 32'hFFFFFFCC);
        
        // JAL x1, 1024: Larger positive offset
        test_imm("J-type: +1024", 32'h400000EF, IMM_J, 32'h00000400);
        
        // Max positive (~1MB)
        test_imm("J-type: +1048574", 32'h7FFFF0EF, IMM_J, 32'h000FFFFE);
        
        // Max negative (~-1MB)
        test_imm("J-type: -1048576", 32'h800000EF, IMM_J, 32'hFFF00000);

        // ==========================================
        // Test 6: Edge Cases and Special Values
        // ==========================================
        $display("\n[INFO] Test 6: Edge Cases");
        
        // All zeros instruction
        test_imm("Edge: All zeros I-type", 32'h00000000, IMM_I, 32'h00000000);
        test_imm("Edge: All zeros S-type", 32'h00000000, IMM_S, 32'h00000000);
        test_imm("Edge: All zeros B-type", 32'h00000000, IMM_B, 32'h00000000);
        test_imm("Edge: All zeros U-type", 32'h00000000, IMM_U, 32'h00000000);
        test_imm("Edge: All zeros J-type", 32'h00000000, IMM_J, 32'h00000000);
        
        // All ones instruction
        test_imm("Edge: All ones I-type", 32'hFFFFFFFF, IMM_I, 32'hFFFFFFFF);
        test_imm("Edge: All ones S-type", 32'hFFFFFFFF, IMM_S, 32'hFFFFFFFF);
        test_imm("Edge: All ones B-type", 32'hFFFFFFFF, IMM_B, 32'hFFFFFFFE);
        test_imm("Edge: All ones U-type", 32'hFFFFFFFF, IMM_U, 32'hFFFFF000);
        test_imm("Edge: All ones J-type", 32'hFFFFFFFF, IMM_J, 32'hFFFFFFFE);

        // ==========================================
        // Test 7: Sign Extension Verification
        // ==========================================
        $display("\n[INFO] Test 7: Sign Extension");
        
        // I-type: bit 31=1, should sign extend
        test_imm("Sign: I-type negative", 32'h80000013, IMM_I, 32'hFFFFF800);
        
        // I-type: bit 31=0, should zero extend
        test_imm("Sign: I-type positive", 32'h7FF00013, IMM_I, 32'h000007FF);
        
        // B-type: bit 31=1, should sign extend
        test_imm("Sign: B-type negative", 32'h80000063, IMM_B, 32'hFFFFF000);
        
        // J-type: bit 31=1, should sign extend
        test_imm("Sign: J-type negative", 32'h800000EF, IMM_J, 32'hFFF00000);

        // Wait a bit
        #100;

        // ==========================================
        // Final Report
        // ==========================================
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Errors:      %0d", error_count);
        
        if (error_count == 0) begin
            $display("\nTEST PASSED");
        end else begin
            $display("\nERROR");
            $fatal(1, "TEST FAILED with %0d errors", error_count);
        end
        
        $finish(0);
    end

    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
