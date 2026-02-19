// Comprehensive Testbench for RISC-V Register File
// Tests all 32 registers, x0 protection, dual-port reads, and write enable

module tb_register_file;

    // Testbench signals
    logic        clock;
    logic        reset;
    logic [4:0]  read_addr1;
    logic [31:0] read_data1;
    logic [4:0]  read_addr2;
    logic [31:0] read_data2;
    logic        write_enable;
    logic [4:0]  write_addr;
    logic [31:0] write_data;

    // Test tracking
    int error_count = 0;
    int test_count = 0;

    // Clock generation
    initial begin
        clock = 0;
        forever #5 clock = ~clock;  // 10ns period (100MHz)
    end

    // Instantiate DUT
    register_file dut (
        .clock(clock),
        .reset(reset),
        .read_addr1(read_addr1),
        .read_data1(read_data1),
        .read_addr2(read_addr2),
        .read_data2(read_data2),
        .write_enable(write_enable),
        .write_addr(write_addr),
        .write_data(write_data)
    );

    // Check read data against expected value
    task automatic check_read(
        input string test_name,
        input logic [4:0] addr,
        input logic [31:0] expected,
        input logic [31:0] actual
    );
        test_count++;
        if (actual !== expected) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_register_file : dut.read_data : expected_value: 0x%08h actual_value: 0x%08h", 
                     $time, expected, actual);
            $display("  Test: %s, addr=x%0d", test_name, addr);
        end
    endtask

    // Write to register and wait for clock edge
    task automatic write_register(
        input logic [4:0] addr,
        input logic [31:0] data
    );
        write_enable = 1;
        write_addr = addr;
        write_data = data;
        @(posedge clock);
        #1;
    endtask

    // Read register and check value
    task automatic read_and_check(
        input string test_name,
        input logic [4:0] addr,
        input logic [31:0] expected
    );
        read_addr1 = addr;
        #1; // Wait for combinational read
        check_read(test_name, addr, expected, read_data1);
    endtask

    // Main test sequence
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("Register File Comprehensive Test");
        $display("========================================");

        // Initialize signals
        reset = 1;
        read_addr1 = 5'd0;
        read_addr2 = 5'd0;
        write_enable = 0;
        write_addr = 5'd0;
        write_data = 32'd0;

        // Wait for reset
        @(posedge clock);
        @(posedge clock);
        #1;

        // ==========================================
        // Test 1: Reset Behavior
        // ==========================================
        $display("\n[INFO] Test 1: Reset Behavior");
        
        reset = 1;
        @(posedge clock);
        #1;
        
        // Check all registers are zero after reset
        for (int i = 0; i < 32; i++) begin
            read_and_check($sformatf("Reset: x%0d should be 0", i), i[4:0], 32'd0);
        end
        
        reset = 0;
        @(posedge clock);

        // ==========================================
        // Test 2: Write and Read All Registers (except x0)
        // ==========================================
        $display("\n[INFO] Test 2: Write and Read All Registers");
        
        // Write unique values to all registers
        for (int i = 1; i < 32; i++) begin
            write_register(i[4:0], 32'hA0000000 | i);
        end
        
        write_enable = 0;
        #1;
        
        // Read back and verify
        for (int i = 1; i < 32; i++) begin
            read_and_check($sformatf("Read x%0d", i), i[4:0], 32'hA0000000 | i);
        end

        // ==========================================
        // Test 3: x0 Always Reads Zero
        // ==========================================
        $display("\n[INFO] Test 3: x0 Hardwired to Zero");
        
        // Try to write to x0
        write_register(5'd0, 32'hDEADBEEF);
        write_enable = 0;
        
        // x0 should still read 0
        read_and_check("x0 after write attempt", 5'd0, 32'd0);
        
        // Multiple write attempts
        write_register(5'd0, 32'hFFFFFFFF);
        write_register(5'd0, 32'h12345678);
        write_enable = 0;
        
        read_and_check("x0 after multiple writes", 5'd0, 32'd0);

        // ==========================================
        // Test 4: Dual-Port Reading
        // ==========================================
        $display("\n[INFO] Test 4: Dual-Port Reading");
        
        // Write test values
        write_register(5'd5, 32'h11111111);
        write_register(5'd10, 32'h22222222);
        write_enable = 0;
        #1;
        
        // Read both ports simultaneously
        read_addr1 = 5'd5;
        read_addr2 = 5'd10;
        #1;
        check_read("Dual read port 1", 5'd5, 32'h11111111, read_data1);
        check_read("Dual read port 2", 5'd10, 32'h22222222, read_data2);
        
        // Swap addresses
        read_addr1 = 5'd10;
        read_addr2 = 5'd5;
        #1;
        check_read("Dual read swapped port 1", 5'd10, 32'h22222222, read_data1);
        check_read("Dual read swapped port 2", 5'd5, 32'h11111111, read_data2);
        
        // Read same register on both ports
        read_addr1 = 5'd5;
        read_addr2 = 5'd5;
        #1;
        check_read("Same reg port 1", 5'd5, 32'h11111111, read_data1);
        check_read("Same reg port 2", 5'd5, 32'h11111111, read_data2);

        // ==========================================
        // Test 5: Write Enable Control
        // ==========================================
        $display("\n[INFO] Test 5: Write Enable Control");
        
        // Write initial value
        write_register(5'd15, 32'hAABBCCDD);
        write_enable = 0;
        #1;
        
        // Try to write with enable=0
        write_enable = 0;
        write_addr = 5'd15;
        write_data = 32'h99999999;
        @(posedge clock);
        #1;
        
        // Should still have old value
        read_and_check("Write disabled", 5'd15, 32'hAABBCCDD);
        
        // Enable write
        write_enable = 1;
        write_addr = 5'd15;
        write_data = 32'h88888888;
        @(posedge clock);
        #1;  // Wait for write to complete
        write_enable = 0;
        #1;
        
        // Should have new value
        read_and_check("Write enabled", 5'd15, 32'h88888888);

        // ==========================================
        // Test 6: Overwrite Registers
        // ==========================================
        $display("\n[INFO] Test 6: Overwrite Registers");
        
        // Write initial values
        write_register(5'd20, 32'h00000001);
        write_register(5'd21, 32'h00000002);
        write_enable = 0;
        #1;
        
        read_and_check("Before overwrite x20", 5'd20, 32'h00000001);
        read_and_check("Before overwrite x21", 5'd21, 32'h00000002);
        
        // Overwrite
        write_register(5'd20, 32'hFFFFFFFF);
        write_register(5'd21, 32'hEEEEEEEE);
        write_enable = 0;
        #1;
        
        read_and_check("After overwrite x20", 5'd20, 32'hFFFFFFFF);
        read_and_check("After overwrite x21", 5'd21, 32'hEEEEEEEE);

        // ==========================================
        // Test 7: Read-After-Write (Same Cycle Check)
        // ==========================================
        $display("\n[INFO] Test 7: Read During Write");
        
        write_register(5'd25, 32'h12345678);
        write_enable = 0;  // Disable write after initial write
        #1;
        
        // Read the register being written
        read_addr1 = 5'd25;
        write_enable = 1;
        write_addr = 5'd25;
        write_data = 32'h87654321;
        
        // Before clock edge, should still see old value
        #1;
        check_read("Read during write (before edge)", 5'd25, 32'h12345678, read_data1);
        
        @(posedge clock);
        #1;  // Wait for write to complete
        write_enable = 0;
        #1;
        
        // After clock edge, should see new value
        read_and_check("Read after write", 5'd25, 32'h87654321);

        // ==========================================
        // Test 8: Boundary Registers
        // ==========================================
        $display("\n[INFO] Test 8: Boundary Registers");
        
        // Test x0 (already tested but verify again)
        read_and_check("Boundary: x0", 5'd0, 32'd0);
        
        // Test x31 (last register)
        write_register(5'd31, 32'hFEDCBA98);
        write_enable = 0;
        #1;
        read_and_check("Boundary: x31", 5'd31, 32'hFEDCBA98);

        // ==========================================
        // Test 9: All Registers with Different Patterns
        // ==========================================
        $display("\n[INFO] Test 9: Pattern Testing");
        
        // Write alternating patterns
        for (int i = 1; i < 32; i++) begin
            if (i % 2 == 0) begin
                write_register(i[4:0], 32'hAAAAAAAA);
            end else begin
                write_register(i[4:0], 32'h55555555);
            end
        end
        
        write_enable = 0;
        #1;
        
        // Verify patterns
        for (int i = 1; i < 32; i++) begin
            if (i % 2 == 0) begin
                read_and_check($sformatf("Pattern x%0d", i), i[4:0], 32'hAAAAAAAA);
            end else begin
                read_and_check($sformatf("Pattern x%0d", i), i[4:0], 32'h55555555);
            end
        end

        // ==========================================
        // Test 10: Reset During Operation
        // ==========================================
        $display("\n[INFO] Test 10: Reset During Operation");
        
        // Write some values
        write_register(5'd7, 32'hCAFEBABE);
        write_register(5'd14, 32'hDEADBEEF);
        write_enable = 0;  // Disable write before reset
        #1;
        
        // Reset
        reset = 1;
        @(posedge clock);
        #1;  // Wait for reset to complete
        reset = 0;
        @(posedge clock);
        #1;
        
        // All registers should be zero
        read_and_check("After reset x7", 5'd7, 32'd0);
        read_and_check("After reset x14", 5'd14, 32'd0);
        read_and_check("After reset x31", 5'd31, 32'd0);

        // ==========================================
        // Test 11: Rapid Write/Read Sequences
        // ==========================================
        $display("\n[INFO] Test 11: Rapid Sequences");
        
        for (int i = 1; i <= 10; i++) begin
            write_register(5'd3, i);
        end
        
        write_enable = 0;
        #1;
        
        // Should have last written value
        read_and_check("Rapid writes x3", 5'd3, 32'd10);

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
