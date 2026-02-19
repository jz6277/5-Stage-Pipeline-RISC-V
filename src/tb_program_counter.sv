// Comprehensive Testbench for RISC-V Program Counter
// Tests reset, sequential execution, branches, jumps, and stalls

module tb_program_counter;

    // Testbench signals
    logic        clock;
    logic        reset;
    logic        enable;
    logic        pc_src;
    logic [31:0] pc_target;
    logic [31:0] pc_current;
    logic [31:0] pc_next;

    // Test tracking
    int error_count = 0;
    int test_count = 0;

    // Clock generation
    initial begin
        clock = 0;
        forever #5 clock = ~clock;  // 10ns period (100MHz)
    end

    // Instantiate DUT with default reset address
    program_counter dut (
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .pc_src(pc_src),
        .pc_target(pc_target),
        .pc_current(pc_current),
        .pc_next(pc_next)
    );

    // Golden reference model
    logic [31:0] expected_pc_current;
    logic [31:0] expected_pc_next;

    // Check result against expected values
    task automatic check_pc(input string test_name);
        test_count++;
        #1; // Small delay for signal stability
        
        if (pc_current !== expected_pc_current) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_program_counter : dut.pc_current : expected_value: 0x%08h actual_value: 0x%08h", 
                     $time, expected_pc_current, pc_current);
            $display("  Test: %s", test_name);
        end
        
        if (pc_next !== expected_pc_next) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_program_counter : dut.pc_next : expected_value: 0x%08h actual_value: 0x%08h", 
                     $time, expected_pc_next, pc_next);
            $display("  Test: %s", test_name);
        end
    endtask

    // Apply inputs and wait for clock edge
    task automatic apply_and_check(
        input string test_name,
        input logic rst,
        input logic en,
        input logic src,
        input logic [31:0] target
    );
        // Apply inputs
        reset = rst;
        enable = en;
        pc_src = src;
        pc_target = target;
        
        // Wait for clock edge
        @(posedge clock);
        #1; // Small delay after clock edge
        
        // Update expected values based on inputs
        if (rst) begin
            expected_pc_current = 32'h00000000;
        end else if (en) begin
            if (src) begin
                expected_pc_current = target;
            end else begin
                expected_pc_current = expected_pc_current + 32'd4;
            end
        end
        // If !en, expected_pc_current stays the same
        
        expected_pc_next = expected_pc_current + 32'd4;
        
        // Check outputs
        check_pc(test_name);
    endtask

    // Main test sequence
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("Program Counter Comprehensive Test");
        $display("========================================");

        // Initialize signals
        reset = 1;
        enable = 0;
        pc_src = 0;
        pc_target = 32'h00000000;
        expected_pc_current = 32'h00000000;
        expected_pc_next = 32'h00000004;

        // Wait for initial clock edge
        @(posedge clock);
        #1;

        // ==========================================
        // Test 1: Reset Behavior
        // ==========================================
        $display("\n[INFO] Test 1: Reset Behavior");
        
        reset = 1;
        enable = 1;
        pc_src = 0;
        @(posedge clock);
        #1;
        expected_pc_current = 32'h00000000;
        expected_pc_next = 32'h00000004;
        check_pc("Reset: PC should be 0x00000000");

        // ==========================================
        // Test 2: Sequential Execution (PC+4)
        // ==========================================
        $display("\n[INFO] Test 2: Sequential Execution");
        
        apply_and_check("Sequential: Release reset", 0, 1, 0, 32'h00000000);
        apply_and_check("Sequential: PC+4 (0->4)", 0, 1, 0, 32'h00000000);
        apply_and_check("Sequential: PC+4 (4->8)", 0, 1, 0, 32'h00000000);
        apply_and_check("Sequential: PC+4 (8->C)", 0, 1, 0, 32'h00000000);
        apply_and_check("Sequential: PC+4 (C->10)", 0, 1, 0, 32'h00000000);
        apply_and_check("Sequential: PC+4 (10->14)", 0, 1, 0, 32'h00000000);

        // ==========================================
        // Test 3: Branch/Jump Target
        // ==========================================
        $display("\n[INFO] Test 3: Branch/Jump Target");
        
        apply_and_check("Branch: Jump to 0x1000", 0, 1, 1, 32'h00001000);
        apply_and_check("Sequential after branch", 0, 1, 0, 32'h00000000);
        
        apply_and_check("Branch: Jump to 0x2000", 0, 1, 1, 32'h00002000);
        apply_and_check("Sequential after branch", 0, 1, 0, 32'h00000000);
        
        apply_and_check("Branch: Jump to 0xFFFFFF00", 0, 1, 1, 32'hFFFFFF00);
        apply_and_check("Sequential after branch", 0, 1, 0, 32'h00000000);

        // ==========================================
        // Test 4: Pipeline Stall (Enable = 0)
        // ==========================================
        $display("\n[INFO] Test 4: Pipeline Stall");
        
        // Set PC to known value
        apply_and_check("Setup: Jump to 0x100", 0, 1, 1, 32'h00000100);
        
        // Stall (enable = 0)
        apply_and_check("Stall: Hold PC", 0, 0, 0, 32'h00000000);
        apply_and_check("Stall: Hold PC", 0, 0, 0, 32'h00000000);
        apply_and_check("Stall: Hold PC", 0, 0, 0, 32'h00000000);
        
        // Resume
        apply_and_check("Resume: PC+4", 0, 1, 0, 32'h00000000);
        apply_and_check("Sequential: PC+4", 0, 1, 0, 32'h00000000);

        // ==========================================
        // Test 5: Stall during branch attempt
        // ==========================================
        $display("\n[INFO] Test 5: Stall During Branch");
        
        apply_and_check("Setup: Sequential", 0, 1, 0, 32'h00000000);
        // Try to branch but stalled - PC should hold
        apply_and_check("Stalled branch ignored", 0, 0, 1, 32'h00005000);
        // Resume sequential
        apply_and_check("Resume: PC+4", 0, 1, 0, 32'h00000000);

        // ==========================================
        // Test 6: Reset during operation
        // ==========================================
        $display("\n[INFO] Test 6: Reset During Operation");
        
        apply_and_check("Setup: Jump to 0xABCD", 0, 1, 1, 32'h0000ABCD);
        apply_and_check("Sequential", 0, 1, 0, 32'h00000000);
        apply_and_check("Reset during operation", 1, 1, 0, 32'h00000000);
        apply_and_check("Resume after reset", 0, 1, 0, 32'h00000000);

        // ==========================================
        // Test 7: Consecutive Branches
        // ==========================================
        $display("\n[INFO] Test 7: Consecutive Branches");
        
        apply_and_check("Branch 1: to 0x1000", 0, 1, 1, 32'h00001000);
        apply_and_check("Branch 2: to 0x2000", 0, 1, 1, 32'h00002000);
        apply_and_check("Branch 3: to 0x3000", 0, 1, 1, 32'h00003000);
        apply_and_check("Sequential after branches", 0, 1, 0, 32'h00000000);

        // ==========================================
        // Test 8: PC Wraparound (edge case)
        // ==========================================
        $display("\n[INFO] Test 8: PC Wraparound");
        
        apply_and_check("Setup: Near max address", 0, 1, 1, 32'hFFFFFFF8);
        apply_and_check("Increment near wraparound", 0, 1, 0, 32'h00000000);
        apply_and_check("Wraparound", 0, 1, 0, 32'h00000000);

        // ==========================================
        // Test 9: Mixed Operations
        // ==========================================
        $display("\n[INFO] Test 9: Mixed Operations");
        
        apply_and_check("Branch to 0x400", 0, 1, 1, 32'h00000400);
        apply_and_check("Sequential", 0, 1, 0, 32'h00000000);
        apply_and_check("Stall", 0, 0, 0, 32'h00000000);
        apply_and_check("Sequential", 0, 1, 0, 32'h00000000);
        apply_and_check("Branch to 0x800", 0, 1, 1, 32'h00000800);
        apply_and_check("Stall", 0, 0, 0, 32'h00000000);
        apply_and_check("Stall", 0, 0, 0, 32'h00000000);
        apply_and_check("Sequential", 0, 1, 0, 32'h00000000);

        // ==========================================
        // Test 10: pc_next output verification
        // ==========================================
        $display("\n[INFO] Test 10: PC_next Output");
        
        apply_and_check("Verify pc_next = pc_current + 4", 0, 1, 1, 32'h00000200);
        apply_and_check("Verify pc_next = pc_current + 4", 0, 1, 0, 32'h00000000);
        apply_and_check("Verify pc_next = pc_current + 4", 0, 1, 0, 32'h00000000);

        // Wait a few more cycles
        repeat(3) @(posedge clock);

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

    // Timeout watchdog
    initial begin
        #100000; // 100us timeout
        $display("\nERROR: Test timeout!");
        $fatal(1, "TEST FAILED - Timeout");
    end

    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
