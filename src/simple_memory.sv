// Simple Word-Based Memory
// Pure storage with byte-enable support
// Word-addressable (32-bit aligned access)

module simple_memory #(
    parameter ADDR_WIDTH = 12,          // Address width in bytes (4KB default)
    parameter DATA_WIDTH = 32,         // Data width (32-bit)
    parameter CLEAR_ON_RESET = 1       // 0 = don't clear (for ROM/instruction mem)
) (
    input  logic                    clock,          // System clock
    input  logic                    reset,          // Synchronous reset (active high)
    
    // Memory interface
    input  logic                    enable,         // Memory enable
    input  logic                    write_enable,   // Write enable
    input  logic [3:0]              byte_enable,    // Byte enable (4 bits for 4 bytes)
    input  logic [ADDR_WIDTH-1:0]   address,        // Byte address (word-aligned)
    input  logic [DATA_WIDTH-1:0]   write_data,     // Data to write
    output logic [DATA_WIDTH-1:0]   read_data       // Data read from memory
);

    // Memory array (word-addressable, byte-accessible)
    localparam MEM_WORDS = 2**(ADDR_WIDTH-2);  // Number of 32-bit words
    logic [7:0] memory [MEM_WORDS*4-1:0];      // Byte array

    // Word-aligned address
    logic [ADDR_WIDTH-3:0] word_addr;
    assign word_addr = address[ADDR_WIDTH-1:2];

    // Asynchronous read (full word)
    always_comb begin
        if (enable && !write_enable) begin
            read_data[7:0]   = memory[word_addr * 4 + 0];
            read_data[15:8]  = memory[word_addr * 4 + 1];
            read_data[23:16] = memory[word_addr * 4 + 2];
            read_data[31:24] = memory[word_addr * 4 + 3];
        end else begin
            read_data = 32'h0;
        end
    end

    // Synchronous write with byte enables
    always_ff @(posedge clock) begin
        if (reset && CLEAR_ON_RESET) begin
            for (int i = 0; i < MEM_WORDS*4; i = i + 1) begin
                memory[i] <= 8'h0;
            end
        end else if (enable && write_enable) begin
            // Write individual bytes based on byte enables
            if (byte_enable[0]) memory[word_addr * 4 + 0] <= write_data[7:0];
            if (byte_enable[1]) memory[word_addr * 4 + 1] <= write_data[15:8];
            if (byte_enable[2]) memory[word_addr * 4 + 2] <= write_data[23:16];
            if (byte_enable[3]) memory[word_addr * 4 + 3] <= write_data[31:24];
        end
    end

endmodule
