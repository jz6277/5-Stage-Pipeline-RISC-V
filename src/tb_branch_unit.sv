// Comprehensive Testbench for Branch Unit
// Tests all 6 RV32I branch instructions

module tb_branch_unit;

    // Testbench signals
    logic [31:0] operand_a;
    logic [31:0] operand_b;
    logic [2:0]  funct3;
    logic        branch;
    logic        branch_taken;

    // Test tracking
    int error_count = 0;
    int test_count = 0;

    // Instantiate DUT
    branch_unit dut (
        .operand_a(operand_a),
        .operand_b(operand_b),
        .funct3(funct3),
        .branch(branch),
        .branch_taken(branch_taken)
    );

    // Check branch_taken output
    task automatic check_branch(input string test_name, input logic expected);
        test_count++;
        #1;
        if (branch_taken !== expected) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_branch_unit : dut.branch_taken : expected_value: %0b actual_value: %0b",
                     $time, expected, branch_taken);
            $display("  Test: %s", test_name);
        end
    endtask

    // Test branch condition
    task automatic test_branch(input string test_name, input logic [31:0] a, input logic [31:0] b,
                               input logic [2:0] fn3, input logic expected);
        operand_a = a;
        operand_b = b;
        funct3 = fn3;
        branch = 1;
        check_branch(test_name, expected);
    endtask

    // Main test sequence
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("Branch Unit Comprehensive Test");
        $display("========================================");

        // Initialize
        operand_a = 32'h0;
        operand_b = 32'h0;
        funct3 = 3'b0;
        branch = 0;
        #10;

        // Test 1: BEQ
        $display("\n[INFO] Test 1: BEQ");
        test_branch("BEQ: 0 == 0", 32'd0, 32'd0, 3'b000, 1'b1);
        test_branch("BEQ: 5 == 5", 32'd5, 32'd5, 3'b000, 1'b1);
        test_branch("BEQ: 5 != 10", 32'd5, 32'd10, 3'b000, 1'b0);

        // Test 2: BNE
        $display("\n[INFO] Test 2: BNE");
        test_branch("BNE: 5 != 10", 32'd5, 32'd10, 3'b001, 1'b1);
        test_branch("BNE: 5 == 5", 32'd5, 32'd5, 3'b001, 1'b0);

        // Test 3: BLT
        $display("\n[INFO] Test 3: BLT");
        test_branch("BLT: 5 < 10", 32'd5, 32'd10, 3'b100, 1'b1);
        test_branch("BLT: -10 < -5", 32'hFFFFFFF6, 32'hFFFFFFFB, 3'b100, 1'b1);
        test_branch("BLT: 10 < 5", 32'd10, 32'd5, 3'b100, 1'b0);

        // Test 4: BGE  
        $display("\n[INFO] Test 4: BGE");
        test_branch("BGE: 10 >= 5", 32'd10, 32'd5, 3'b101, 1'b1);
        test_branch("BGE: 5 >= 5", 32'd5, 32'd5, 3'b101, 1'b1);
        test_branch("BGE: 5 >= 10", 32'd5, 32'd10, 3'b101, 1'b0);

        // Test 5: BLTU
        $display("\n[INFO] Test 5: BLTU");
        test_branch("BLTU: 5 < 10", 32'd5, 32'd10, 3'b110, 1'b1);
        test_branch("BLTU: 10 < 0xFFFFFFFF", 32'd10, 32'hFFFFFFFF, 3'b110, 1'b1);
        test_branch("BLTU: 10 < 5", 32'd10, 32'd5, 3'b110, 1'b0);

        // Test 6: BGEU
        $display("\n[INFO] Test 6: BGEU");
        test_branch("BGEU: 10 >= 5", 32'd10, 32'd5, 3'b111, 1'b1);
        test_branch("BGEU: 0xFFFFFFFF >= 10", 32'hFFFFFFFF, 32'd10, 3'b111, 1'b1);
        test_branch("BGEU: 5 >= 10", 32'd5, 32'd10, 3'b111, 1'b0);

        // Test 7: Branch disabled
        $display("\n[INFO] Test 7: Branch Disabled");
        branch = 0;
        operand_a = 32'd5;
        operand_b = 32'd5;
        funct3 = 3'b000;
        check_branch("branch=0", 1'b0);

        #100;

        // Final Report
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