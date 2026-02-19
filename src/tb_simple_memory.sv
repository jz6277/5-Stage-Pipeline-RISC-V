// Comprehensive Testbench for Simple Memory
// Tests word storage with byte enable support

module tb_simple_memory;

    // Testbench signals
    logic        clock;
    logic        reset;
    logic        enable;
    logic        write_enable;
    logic [3:0]  byte_enable;
    logic [11:0] address;
    logic [31:0] write_data;
    logic [31:0] read_data;

    // Test tracking
    int error_count = 0;
    int test_count = 0;

    // Clock generation
    initial begin
        clock = 0;
        forever #5 clock = ~clock;  // 10ns period (100MHz)
    end

    // Instantiate DUT
    simple_memory dut (
        .clock(clock),
        .reset(reset),
        .enable(enable),
        .write_enable(write_enable),
        .byte_enable(byte_enable),
        .address(address),
        .write_data(write_data),
        .read_data(read_data)
    );

    // Check read data
    task automatic check_read(input string test_name, input logic [31:0] expected);
        test_count++;
        #1;
        if (read_data !== expected) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_simple_memory : dut.read_data : expected_value: 0x%08h actual_value: 0x%08h",
                     $time, expected, read_data);
            $display("  Test: %s", test_name);
        end
    endtask

    // Write to memory
    task automatic write_word(input logic [11:0] addr, input logic [31:0] data, input logic [3:0] be);
        enable = 1;
        write_enable = 1;
        address = addr;
        write_data = data;
        byte_enable = be;
        @(posedge clock);
        #1;
    endtask

    // Read from memory
    task automatic read_word(input string test_name, input logic [11:0] addr, input logic [31:0] expected);
        enable = 1;
        write_enable = 0;
        address = addr;
        #1;
        check_read(test_name, expected);
    endtask

    // Main test sequence
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("Simple Memory Comprehensive Test");
        $display("========================================");

        // Initialize
        reset = 1;
        enable = 0;
        write_enable = 0;
        byte_enable = 4'b0000;
        address = 12'h000;
        write_data = 32'h0;

        @(posedge clock);
        @(posedge clock);
        reset = 0;
        @(posedge clock);
        #1;

        // ==========================================
        // Test 1: Word Write and Read
        // ==========================================
        $display("\n[INFO] Test 1: Word Write and Read");
        
        write_word(12'h000, 32'hDEADBEEF, 4'b1111);
        write_enable = 0;
        read_word("Read word at 0x000", 12'h000, 32'hDEADBEEF);
        
        write_word(12'h004, 32'h12345678, 4'b1111);
        write_enable = 0;
        read_word("Read word at 0x004", 12'h004, 32'h12345678);
        
        write_word(12'h100, 32'hCAFEBABE, 4'b1111);
        write_enable = 0;
        read_word("Read word at 0x100", 12'h100, 32'hCAFEBABE);

        // ==========================================
        // Test 2: Byte Enable - Write Individual Bytes
        // ==========================================
        $display("\n[INFO] Test 2: Byte Enable Testing");
        
        // Write full word first
        write_word(12'h200, 32'h00000000, 4'b1111);
        write_enable = 0;
        
        // Write byte 0
        write_word(12'h200, 32'h000000AA, 4'b0001);
        write_enable = 0;
        read_word("Byte 0 written", 12'h200, 32'h000000AA);
        
        // Write byte 1
        write_word(12'h200, 32'h0000BB00, 4'b0010);
        write_enable = 0;
        read_word("Byte 1 written", 12'h200, 32'h0000BBAA);
        
        // Write byte 2
        write_word(12'h200, 32'h00CC0000, 4'b0100);
        write_enable = 0;
        read_word("Byte 2 written", 12'h200, 32'h00CCBBAA);
        
        // Write byte 3
        write_word(12'h200, 32'hDD000000, 4'b1000);
        write_enable = 0;
        read_word("Byte 3 written", 12'h200, 32'hDDCCBBAA);

        // ==========================================
        // Test 3: Halfword Write with Byte Enables
        // ==========================================
        $display("\n[INFO] Test 3: Halfword Write");
        
        write_word(12'h300, 32'h00000000, 4'b1111);
        write_enable = 0;
        
        // Write lower halfword
        write_word(12'h300, 32'h0000FFEE, 4'b0011);
        write_enable = 0;
        read_word("Lower halfword", 12'h300, 32'h0000FFEE);
        
        // Write upper halfword
        write_word(12'h300, 32'hAABB0000, 4'b1100);
        write_enable = 0;
        read_word("Upper halfword", 12'h300, 32'hAABBFFEE);

        // ==========================================
        // Test 4: Multiple Addresses
        // ==========================================
        $display("\n[INFO] Test 4: Multiple Addresses");
        
        for (int i = 0; i < 16; i++) begin
            write_word(12'h400 + i*4, 32'hA0000000 | i, 4'b1111);
        end
        write_enable = 0;
        
        for (int i = 0; i < 16; i++) begin
            read_word($sformatf("Address 0x%03X", 12'h400 + i*4), 
                     12'h400 + i*4, 32'hA0000000 | i);
        end

        // ==========================================
        // Test 5: Overwrite Test
        // ==========================================
        $display("\n[INFO] Test 5: Overwrite Test");
        
        write_word(12'h500, 32'h11111111, 4'b1111);
        write_enable = 0;
        read_word("Initial value", 12'h500, 32'h11111111);
        
        write_word(12'h500, 32'h22222222, 4'b1111);
        write_enable = 0;
        read_word("Overwritten value", 12'h500, 32'h22222222);

        // ==========================================
        // Test 6: Enable Signal Test
        // ==========================================
        $display("\n[INFO] Test 6: Enable Signal");
        
        write_word(12'h600, 32'hAAAAAAAA, 4'b1111);
        write_enable = 0;
        
        // Try to write with enable=0
        enable = 0;
        write_enable = 1;
        address = 12'h600;
        write_data = 32'hBBBBBBBB;
        byte_enable = 4'b1111;
        @(posedge clock);
        #1;
        
        // Should still be old value
        enable = 1;
        write_enable = 0;
        read_word("Enable=0, no write", 12'h600, 32'hAAAAAAAA);

        // ==========================================
        // Test 7: Reset Test
        // ==========================================
        $display("\n[INFO] Test 7: Reset Test");
        
        write_word(12'h700, 32'hDEADBEEF, 4'b1111);
        write_enable = 0;
        #1;
        
        // Assert reset and wait for it to take effect
        reset = 1;
        enable = 0;  // Disable during reset
        @(posedge clock);
        #1;  // Wait for reset to complete
        
        // Deassert reset and wait
        reset = 0;
        @(posedge clock);
        #1;
        
        read_word("After reset", 12'h700, 32'h00000000);

        // ==========================================
        // Test 8: Word Alignment
        // ==========================================
        $display("\n[INFO] Test 8: Word-Aligned Addresses");
        
        write_word(12'h000, 32'h00000001, 4'b1111);
        write_word(12'h004, 32'h00000002, 4'b1111);
        write_word(12'h008, 32'h00000003, 4'b1111);
        write_word(12'h00C, 32'h00000004, 4'b1111);
        write_enable = 0;
        
        read_word("Aligned 0x000", 12'h000, 32'h00000001);
        read_word("Aligned 0x004", 12'h004, 32'h00000002);
        read_word("Aligned 0x008", 12'h008, 32'h00000003);
        read_word("Aligned 0x00C", 12'h00C, 32'h00000004);

        // Wait a bit
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
        #100000;
        $display("\nERROR: Test timeout!");
        $fatal(1, "TEST FAILED - Timeout");
    end

    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
