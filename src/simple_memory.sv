// Simple Word-Based Memory
// Pure storage with byte-enable support
// Word-addressable (32-bit aligned access)

module simple_memory #(
    parameter ADDR_WIDTH = 12,          // Address width in bytes (4KB default)
    parameter DATA_WIDTH = 32,         // Data width (32-bit)
    parameter CLEAR_ON_RESET = 1,      // 0 = don't clear (for ROM/instruction mem)
    parameter string INIT_FILE = ""    // If non-empty, load byte array via $readmemh (FPGA/synth)
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

`ifdef SYNTHESIS
    // Use a word-oriented RAM for synthesis so Vivado can map this into LUTRAM
    // instead of building a large byte-array mux/reset structure in slice logic.
    (* ram_style = "distributed" *) logic [DATA_WIDTH-1:0] memory [0:MEM_WORDS-1];
    logic [7:0] init_bytes [0:MEM_WORDS*4-1];
    logic [ADDR_WIDTH-3:0] word_addr;
    logic [DATA_WIDTH-1:0] current_word;
    logic [DATA_WIDTH-1:0] merged_write_data;
    integer i;

    assign word_addr = address[ADDR_WIDTH-1:2];
    assign current_word = memory[word_addr];
    assign merged_write_data = {
        byte_enable[3] ? write_data[31:24] : current_word[31:24],
        byte_enable[2] ? write_data[23:16] : current_word[23:16],
        byte_enable[1] ? write_data[15:8]  : current_word[15:8],
        byte_enable[0] ? write_data[7:0]   : current_word[7:0]
    };

    initial begin
        for (i = 0; i < MEM_WORDS; i = i + 1) begin
            memory[i] = '0;
        end

        if (INIT_FILE != "") begin
            $readmemh(INIT_FILE, init_bytes);
            for (i = 0; i < MEM_WORDS; i = i + 1) begin
                memory[i] = {
                    init_bytes[i*4 + 3],
                    init_bytes[i*4 + 2],
                    init_bytes[i*4 + 1],
                    init_bytes[i*4 + 0]
                };
            end
        end
    end

    // Keep the CPU-visible interface asynchronous; the new storage style is what
    // makes the synthesis result FPGA-friendly.
    always_comb begin
        if (enable && !write_enable)
            read_data = memory[word_addr];
        else
            read_data = '0;
    end

    always_ff @(posedge clock) begin
        if (enable && write_enable)
            memory[word_addr] <= merged_write_data;
    end
`else
    logic [7:0] memory [MEM_WORDS*4-1:0];      // Byte array

    initial begin
        if (INIT_FILE != "")
            $readmemh(INIT_FILE, memory);
    end

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

    // Preserve the original simulation reset semantics for the existing testbenches.
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
`endif

endmodule
