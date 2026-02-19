// Comprehensive Testbench for RISC-V ALU
// Tests all 10 RV32I ALU operations with directed and random tests

module tb_riscv_alu;

    // Testbench signals
    logic [31:0] operand_a;
    logic [31:0] operand_b;
    logic [3:0]  alu_op;
    logic [31:0] result;
    logic        zero;

    // ALU Operation Codes (matching DUT)
    localparam logic [3:0] ALU_ADD  = 4'b0000;
    localparam logic [3:0] ALU_SUB  = 4'b0001;
    localparam logic [3:0] ALU_AND  = 4'b0010;
    localparam logic [3:0] ALU_OR   = 4'b0011;
    localparam logic [3:0] ALU_XOR  = 4'b0100;
    localparam logic [3:0] ALU_SLT  = 4'b0101;
    localparam logic [3:0] ALU_SLTU = 4'b0110;
    localparam logic [3:0] ALU_SLL  = 4'b0111;
    localparam logic [3:0] ALU_SRL  = 4'b1000;
    localparam logic [3:0] ALU_SRA  = 4'b1001;

    // Golden reference signals
    logic [31:0] expected_result;
    logic        expected_zero;
    logic signed [31:0] operand_a_signed;
    logic signed [31:0] operand_b_signed;

    // Test tracking
    int error_count = 0;
    int test_count = 0;

    // Instantiate DUT
    riscv_alu dut (
        .operand_a(operand_a),
        .operand_b(operand_b),
        .alu_op(alu_op),
        .result(result),
        .zero(zero)
    );

    // Golden Reference Model
    task automatic compute_golden_result();
        operand_a_signed = operand_a;
        operand_b_signed = operand_b;
        
        case (alu_op)
            ALU_ADD:  expected_result = operand_a + operand_b;
            ALU_SUB:  expected_result = operand_a - operand_b;
            ALU_AND:  expected_result = operand_a & operand_b;
            ALU_OR:   expected_result = operand_a | operand_b;
            ALU_XOR:  expected_result = operand_a ^ operand_b;
            ALU_SLT:  expected_result = (operand_a_signed < operand_b_signed) ? 32'd1 : 32'd0;
            ALU_SLTU: expected_result = (operand_a < operand_b) ? 32'd1 : 32'd0;
            ALU_SLL:  expected_result = operand_a << operand_b[4:0];
            ALU_SRL:  expected_result = operand_a >> operand_b[4:0];
            ALU_SRA:  expected_result = operand_a_signed >>> operand_b[4:0];
            default:  expected_result = 32'd0;
        endcase
        
        expected_zero = (expected_result == 32'd0);
    endtask

    // Check result against golden model
    task automatic check_result(input string test_name);
        test_count++;
        #1; // Small delay for signals to settle
        
        if (result !== expected_result) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_riscv_alu : dut.result : expected_value: 0x%08h actual_value: 0x%08h", 
                     $time, expected_result, result);
            $display("  Test: %s, op=%0d, A=0x%08h, B=0x%08h", test_name, alu_op, operand_a, operand_b);
        end
        
        if (zero !== expected_zero) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_riscv_alu : dut.zero : expected_value: %0b actual_value: %0b", 
                     $time, expected_zero, zero);
            $display("  Test: %s, result=0x%08h", test_name, result);
        end
    endtask

    // Test operation with specific operands
    task automatic test_operation(input string test_name, 
                                   input logic [3:0] op,
                                   input logic [31:0] a,
                                   input logic [31:0] b);
        operand_a = a;
        operand_b = b;
        alu_op = op;
        compute_golden_result();
        #10;
        check_result(test_name);
    endtask

    // Main test sequence
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("RISC-V ALU Comprehensive Test");
        $display("========================================");

        // Initialize signals
        operand_a = 32'd0;
        operand_b = 32'd0;
        alu_op = 4'd0;
        #10;

        // ==========================================
        // Test ADD Operation
        // ==========================================
        $display("\n[INFO] Testing ADD operation...");
        test_operation("ADD: 5 + 3", ALU_ADD, 32'd5, 32'd3);
        test_operation("ADD: 0 + 0", ALU_ADD, 32'd0, 32'd0);
        test_operation("ADD: max + 1", ALU_ADD, 32'hFFFFFFFF, 32'd1);
        test_operation("ADD: large nums", ALU_ADD, 32'h12345678, 32'h87654321);
        test_operation("ADD: negative overflow", ALU_ADD, 32'h80000000, 32'h80000000);

        // ==========================================
        // Test SUB Operation
        // ==========================================
        $display("\n[INFO] Testing SUB operation...");
        test_operation("SUB: 10 - 3", ALU_SUB, 32'd10, 32'd3);
        test_operation("SUB: 0 - 0", ALU_SUB, 32'd0, 32'd0);
        test_operation("SUB: 5 - 10", ALU_SUB, 32'd5, 32'd10);
        test_operation("SUB: underflow", ALU_SUB, 32'h00000000, 32'h00000001);
        test_operation("SUB: equal values", ALU_SUB, 32'hAAAAAAAA, 32'hAAAAAAAA);

        // ==========================================
        // Test AND Operation
        // ==========================================
        $display("\n[INFO] Testing AND operation...");
        test_operation("AND: 0xFF & 0x0F", ALU_AND, 32'h000000FF, 32'h0000000F);
        test_operation("AND: all ones", ALU_AND, 32'hFFFFFFFF, 32'hFFFFFFFF);
        test_operation("AND: with zero", ALU_AND, 32'hAAAAAAAA, 32'h00000000);
        test_operation("AND: alternating", ALU_AND, 32'hAAAAAAAA, 32'h55555555);
        test_operation("AND: pattern", ALU_AND, 32'hF0F0F0F0, 32'h0F0F0F0F);

        // ==========================================
        // Test OR Operation
        // ==========================================
        $display("\n[INFO] Testing OR operation...");
        test_operation("OR: 0xF0 | 0x0F", ALU_OR, 32'h000000F0, 32'h0000000F);
        test_operation("OR: with zero", ALU_OR, 32'h12345678, 32'h00000000);
        test_operation("OR: all ones", ALU_OR, 32'hFFFFFFFF, 32'hFFFFFFFF);
        test_operation("OR: alternating", ALU_OR, 32'hAAAAAAAA, 32'h55555555);
        test_operation("OR: zero | zero", ALU_OR, 32'h00000000, 32'h00000000);

        // ==========================================
        // Test XOR Operation
        // ==========================================
        $display("\n[INFO] Testing XOR operation...");
        test_operation("XOR: same values", ALU_XOR, 32'hAAAAAAAA, 32'hAAAAAAAA);
        test_operation("XOR: alternating", ALU_XOR, 32'hAAAAAAAA, 32'h55555555);
        test_operation("XOR: with zero", ALU_XOR, 32'h12345678, 32'h00000000);
        test_operation("XOR: all ones", ALU_XOR, 32'hFFFFFFFF, 32'hFFFFFFFF);
        test_operation("XOR: pattern", ALU_XOR, 32'hF0F0F0F0, 32'h0F0F0F0F);

        // ==========================================
        // Test SLT (Set Less Than - Signed)
        // ==========================================
        $display("\n[INFO] Testing SLT operation...");
        test_operation("SLT: 5 < 10", ALU_SLT, 32'd5, 32'd10);
        test_operation("SLT: 10 < 5", ALU_SLT, 32'd10, 32'd5);
        test_operation("SLT: equal", ALU_SLT, 32'd100, 32'd100);
        test_operation("SLT: negative < positive", ALU_SLT, 32'hFFFFFFFF, 32'd1);
        test_operation("SLT: -1 < -2", ALU_SLT, 32'hFFFFFFFF, 32'hFFFFFFFE);
        test_operation("SLT: min < 0", ALU_SLT, 32'h80000000, 32'd0);
        test_operation("SLT: 0 < min", ALU_SLT, 32'd0, 32'h80000000);

        // ==========================================
        // Test SLTU (Set Less Than Unsigned)
        // ==========================================
        $display("\n[INFO] Testing SLTU operation...");
        test_operation("SLTU: 5 < 10", ALU_SLTU, 32'd5, 32'd10);
        test_operation("SLTU: 10 < 5", ALU_SLTU, 32'd10, 32'd5);
        test_operation("SLTU: equal", ALU_SLTU, 32'd100, 32'd100);
        test_operation("SLTU: 0xFF < 0x01", ALU_SLTU, 32'hFFFFFFFF, 32'd1);
        test_operation("SLTU: 1 < max", ALU_SLTU, 32'd1, 32'hFFFFFFFF);
        test_operation("SLTU: 0 < 1", ALU_SLTU, 32'd0, 32'd1);

        // ==========================================
        // Test SLL (Shift Left Logical)
        // ==========================================
        $display("\n[INFO] Testing SLL operation...");
        test_operation("SLL: shift by 0", ALU_SLL, 32'h12345678, 32'd0);
        test_operation("SLL: shift by 1", ALU_SLL, 32'h12345678, 32'd1);
        test_operation("SLL: shift by 4", ALU_SLL, 32'h0000000F, 32'd4);
        test_operation("SLL: shift by 8", ALU_SLL, 32'h000000FF, 32'd8);
        test_operation("SLL: shift by 16", ALU_SLL, 32'h0000FFFF, 32'd16);
        test_operation("SLL: shift by 31", ALU_SLL, 32'd1, 32'd31);
        test_operation("SLL: shift > 31", ALU_SLL, 32'h12345678, 32'd37); // Should use only lower 5 bits (5)
        test_operation("SLL: zero shift", ALU_SLL, 32'hAAAAAAAA, 32'd0);

        // ==========================================
        // Test SRL (Shift Right Logical)
        // ==========================================
        $display("\n[INFO] Testing SRL operation...");
        test_operation("SRL: shift by 0", ALU_SRL, 32'h12345678, 32'd0);
        test_operation("SRL: shift by 1", ALU_SRL, 32'h12345678, 32'd1);
        test_operation("SRL: shift by 4", ALU_SRL, 32'hF0000000, 32'd4);
        test_operation("SRL: shift by 8", ALU_SRL, 32'hFF000000, 32'd8);
        test_operation("SRL: shift by 16", ALU_SRL, 32'hFFFF0000, 32'd16);
        test_operation("SRL: shift by 31", ALU_SRL, 32'h80000000, 32'd31);
        test_operation("SRL: shift all bits out", ALU_SRL, 32'hFFFFFFFF, 32'd32); // Uses lower 5 bits = 0
        test_operation("SRL: negative num", ALU_SRL, 32'hFFFFFFFF, 32'd1);

        // ==========================================
        // Test SRA (Shift Right Arithmetic)
        // ==========================================
        $display("\n[INFO] Testing SRA operation...");
        test_operation("SRA: positive by 0", ALU_SRA, 32'h12345678, 32'd0);
        test_operation("SRA: positive by 1", ALU_SRA, 32'h12345678, 32'd1);
        test_operation("SRA: positive by 4", ALU_SRA, 32'h70000000, 32'd4);
        test_operation("SRA: negative by 1", ALU_SRA, 32'hFFFFFFFF, 32'd1);
        test_operation("SRA: negative by 4", ALU_SRA, 32'hF0000000, 32'd4);
        test_operation("SRA: negative by 8", ALU_SRA, 32'hFF000000, 32'd8);
        test_operation("SRA: negative by 16", ALU_SRA, 32'hFFFF0000, 32'd16);
        test_operation("SRA: negative by 31", ALU_SRA, 32'h80000000, 32'd31);
        test_operation("SRA: -1 >> 16", ALU_SRA, 32'hFFFFFFFF, 32'd16);

        // ==========================================
        // Test Zero Flag Specifically
        // ==========================================
        $display("\n[INFO] Testing Zero Flag...");
        test_operation("ZERO: ADD to zero", ALU_ADD, 32'd0, 32'd0);
        test_operation("ZERO: SUB to zero", ALU_SUB, 32'd100, 32'd100);
        test_operation("ZERO: AND to zero", ALU_AND, 32'hAAAAAAAA, 32'h55555555);
        test_operation("ZERO: XOR to zero", ALU_XOR, 32'hFFFFFFFF, 32'hFFFFFFFF);
        test_operation("ZERO: SLL to zero", ALU_SLL, 32'd0, 32'd5);
        test_operation("ZERO: non-zero result", ALU_ADD, 32'd1, 32'd1);

        // ==========================================
        // Random Tests
        // ==========================================
        $display("\n[INFO] Running random tests...");
        for (int i = 0; i < 50; i++) begin
            logic [31:0] rand_a, rand_b;
            logic [3:0] rand_op;
            
            rand_a = $urandom();
            rand_b = $urandom();
            rand_op = $urandom_range(0, 9); // Only valid operations
            
            test_operation($sformatf("RANDOM test %0d", i), rand_op, rand_a, rand_b);
        end

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
