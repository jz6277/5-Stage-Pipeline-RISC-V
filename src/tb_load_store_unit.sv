// Comprehensive Testbench for Load-Store Unit
// Tests all RV32I load/store operations with memory integration

module tb_load_store_unit;

    // Testbench signals - CPU side
    logic [31:0] address;
    logic [31:0] store_data;
    logic [2:0]  funct3;
    logic        mem_read;
    logic        mem_write;
    logic [31:0] load_data;
    
    // LSU to Memory interface
    logic [31:0] mem_address;
    logic [31:0] mem_write_data;
    logic [3:0]  mem_byte_enable;
    logic        mem_enable;
    logic        mem_we;
    logic [31:0] mem_read_data;
    
    // Memory signals
    logic        clock;
    logic        reset;

    // Test tracking
    int error_count = 0;
    int test_count = 0;

    // Clock generation
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end

    // Instantiate LSU
    load_store_unit dut (
        .address(address),
        .store_data(store_data),
        .funct3(funct3),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .load_data(load_data),
        .mem_address(mem_address),
        .mem_write_data(mem_write_data),
        .mem_byte_enable(mem_byte_enable),
        .mem_enable(mem_enable),
        .mem_we(mem_we),
        .mem_read_data(mem_read_data)
    );

    // Instantiate simple memory for integration testing
    simple_memory #(.ADDR_WIDTH(12)) mem (
        .clock(clock),
        .reset(reset),
        .enable(mem_enable),
        .write_enable(mem_we),
        .byte_enable(mem_byte_enable),
        .address(mem_address[11:0]),
        .write_data(mem_write_data),
        .read_data(mem_read_data)
    );

    // Check load data
    task automatic check_load(input string test_name, input logic [31:0] expected);
        test_count++;
        #1;
        if (load_data !== expected) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_load_store_unit : dut.load_data : expected_value: 0x%08h actual_value: 0x%08h",
                     $time, expected, load_data);
            $display("  Test: %s, address=0x%08h, funct3=0x%01h", test_name, address, funct3);
        end
    endtask

    // Store operation
    task automatic do_store(input logic [31:0] addr, input logic [31:0] data, input logic [2:0] fn3);
        address = addr;
        store_data = data;
        funct3 = fn3;
        mem_read = 0;
        mem_write = 1;
        @(posedge clock);
        #1;
        mem_write = 0;
    endtask

    // Load operation
    task automatic do_load(input string test_name, input logic [31:0] addr, input logic [2:0] fn3, input logic [31:0] expected);
        address = addr;
        funct3 = fn3;
        mem_read = 1;
        mem_write = 0;
        #1;
        check_load(test_name, expected);
    endtask

    // Main test sequence
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("Load-Store Unit Comprehensive Test");
        $display("========================================");

        // Initialize
        reset = 1;
        address = 32'h0;
        store_data = 32'h0;
        funct3 = 3'b0;
        mem_read = 0;
        mem_write = 0;

        @(posedge clock);
        @(posedge clock);
        reset = 0;
        @(posedge clock);
        #1;

        // ==========================================
        // Test 1: Store Word (SW)
        // ==========================================
        $display("\n[INFO] Test 1: Store Word");
        
        do_store(32'h00000000, 32'hDEADBEEF, 3'b010);  // SW
        do_load("SW: Load word at 0x000", 32'h00000000, 3'b010, 32'hDEADBEEF);
        
        do_store(32'h00000004, 32'h12345678, 3'b010);  // SW
        do_load("SW: Load word at 0x004", 32'h00000004, 3'b010, 32'h12345678);

        // ==========================================
        // Test 2: Store Byte (SB) - All Offsets
        // ==========================================
        $display("\n[INFO] Test 2: Store Byte");
        
        // Clear memory location
        do_store(32'h00000100, 32'h00000000, 3'b010);
        
        // Store bytes at different offsets
        do_store(32'h00000100, 32'h000000AA, 3'b000);  // SB offset 0
        do_store(32'h00000101, 32'h000000BB, 3'b000);  // SB offset 1
        do_store(32'h00000102, 32'h000000CC, 3'b000);  // SB offset 2
        do_store(32'h00000103, 32'h000000DD, 3'b000);  // SB offset 3
        
        // Read back as word
        do_load("SB: All bytes stored", 32'h00000100, 3'b010, 32'hDDCCBBAA);

        // ==========================================
        // Test 3: Store Halfword (SH) - Both Offsets
        // ==========================================
        $display("\n[INFO] Test 3: Store Halfword");
        
        // Clear memory
        do_store(32'h00000200, 32'h00000000, 3'b010);
        
        // Store halfwords
        do_store(32'h00000200, 32'h00001234, 3'b001);  // SH offset 0
        do_store(32'h00000202, 32'h00005678, 3'b001);  // SH offset 2
        
        // Read back as word
        do_load("SH: Both halfwords stored", 32'h00000200, 3'b010, 32'h56781234);

        // ==========================================
        // Test 4: Load Byte Signed (LB)
        // ==========================================
        $display("\n[INFO] Test 4: Load Byte (Signed)");
        
        // Store test pattern
        do_store(32'h00000300, 32'h8899AABB, 3'b010);
        
        // Load bytes with sign extension
        do_load("LB: offset 0 (0xBB)", 32'h00000300, 3'b000, 32'hFFFFFFBB);  // Sign-extended
        do_load("LB: offset 1 (0xAA)", 32'h00000301, 3'b000, 32'hFFFFFFAA);  // Sign-extended
        do_load("LB: offset 2 (0x99)", 32'h00000302, 3'b000, 32'hFFFFFF99);  // Sign-extended
        do_load("LB: offset 3 (0x88)", 32'h00000303, 3'b000, 32'hFFFFFF88);  // Sign-extended
        
        // Positive byte (no sign extension effect)
        do_store(32'h00000304, 32'h01020304, 3'b010);
        do_load("LB: positive byte", 32'h00000304, 3'b000, 32'h00000004);

        // ==========================================
        // Test 5: Load Byte Unsigned (LBU)
        // ==========================================
        $display("\n[INFO] Test 5: Load Byte (Unsigned)");
        
        // Store test pattern
        do_store(32'h00000400, 32'hFFEEDDCC, 3'b010);
        
        // Load bytes with zero extension
        do_load("LBU: offset 0 (0xCC)", 32'h00000400, 3'b100, 32'h000000CC);
        do_load("LBU: offset 1 (0xDD)", 32'h00000401, 3'b100, 32'h000000DD);
        do_load("LBU: offset 2 (0xEE)", 32'h00000402, 3'b100, 32'h000000EE);
        do_load("LBU: offset 3 (0xFF)", 32'h00000403, 3'b100, 32'h000000FF);

        // ==========================================
        // Test 6: Load Halfword Signed (LH)
        // ==========================================
        $display("\n[INFO] Test 6: Load Halfword (Signed)");
        
        // Store test pattern
        do_store(32'h00000500, 32'h8899AABB, 3'b010);
        
        // Load halfwords with sign extension
        do_load("LH: offset 0 (0xAABB)", 32'h00000500, 3'b001, 32'hFFFFAABB);  // Sign-extended
        do_load("LH: offset 2 (0x8899)", 32'h00000502, 3'b001, 32'hFFFF8899);  // Sign-extended
        
        // Positive halfword
        do_store(32'h00000504, 32'h01020304, 3'b010);
        do_load("LH: positive halfword", 32'h00000504, 3'b001, 32'h00000304);

        // ==========================================
        // Test 7: Load Halfword Unsigned (LHU)
        // ==========================================
        $display("\n[INFO] Test 7: Load Halfword (Unsigned)");
        
        // Store test pattern
        do_store(32'h00000600, 32'hFFEEDDCC, 3'b010);
        
        // Load halfwords with zero extension
        do_load("LHU: offset 0 (0xDDCC)", 32'h00000600, 3'b101, 32'h0000DDCC);
        do_load("LHU: offset 2 (0xFFEE)", 32'h00000602, 3'b101, 32'h0000FFEE);

        // ==========================================
        // Test 8: Load Word (LW)
        // ==========================================
        $display("\n[INFO] Test 8: Load Word");
        
        do_store(32'h00000700, 32'hCAFEBABE, 3'b010);
        do_load("LW: Full word", 32'h00000700, 3'b010, 32'hCAFEBABE);
        
        do_store(32'h00000704, 32'hDEADC0DE, 3'b010);
        do_load("LW: Full word", 32'h00000704, 3'b010, 32'hDEADC0DE);

        // ==========================================
        // Test 9: Mixed Load/Store Operations
        // ==========================================
        $display("\n[INFO] Test 9: Mixed Operations");
        
        // Build a word byte by byte
        do_store(32'h00000800, 32'h00000000, 3'b010);
        do_store(32'h00000800, 32'h00000011, 3'b000);
        do_store(32'h00000801, 32'h00000022, 3'b000);
        do_store(32'h00000802, 32'h00000033, 3'b000);
        do_store(32'h00000803, 32'h00000044, 3'b000);
        do_load("Mixed: Word from bytes", 32'h00000800, 3'b010, 32'h44332211);
        
        // Read individual bytes back
        do_load("Mixed: Byte 0", 32'h00000800, 3'b100, 32'h00000011);
        do_load("Mixed: Byte 1", 32'h00000801, 3'b100, 32'h00000022);
        do_load("Mixed: Byte 2", 32'h00000802, 3'b100, 32'h00000033);
        do_load("Mixed: Byte 3", 32'h00000803, 3'b100, 32'h00000044);

        // ==========================================
        // Test 10: Address Alignment
        // ==========================================
        $display("\n[INFO] Test 10: Address Alignment");
        
        // Verify word-aligned addresses sent to memory
        address = 32'h00000901;
        mem_write = 0;
        mem_read = 1;
        #1;
        if (mem_address !== 32'h00000900) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_load_store_unit : mem_address alignment : expected_value: 0x%08h actual_value: 0x%08h",
                     $time, 32'h00000900, mem_address);
        end
        
        address = 32'h00000A03;
        #1;
        if (mem_address !== 32'h00000A00) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_load_store_unit : mem_address alignment : expected_value: 0x%08h actual_value: 0x%08h",
                     $time, 32'h00000A00, mem_address);
        end

        // Wait a bit
        mem_read = 0;
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
        #200000;
        $display("\nERROR: Test timeout!");
        $fatal(1, "TEST FAILED - Timeout");
    end

    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
