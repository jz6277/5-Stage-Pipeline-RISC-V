// RISC-V Load-Store Unit (LSU)
// Handles byte/halfword/word alignment and formatting
// Supports all RV32I load/store operations

module load_store_unit (
    // CPU interface
    input  logic [31:0] address,        // Byte address from ALU
    input  logic [31:0] store_data,     // Data to store (from register)
    input  logic [2:0]  funct3,         // Load/store type (from instruction)
    input  logic        mem_read,       // Memory read enable
    input  logic        mem_write,      // Memory write enable
    output logic [31:0] load_data,      // Formatted load data (to register)
    
    // Memory interface
    output logic [31:0] mem_address,    // Word-aligned address to memory
    output logic [31:0] mem_write_data, // Formatted write data to memory
    output logic [3:0]  mem_byte_enable,// Byte enables for memory
    output logic        mem_enable,     // Memory enable
    output logic        mem_we,         // Memory write enable
    input  logic [31:0] mem_read_data   // Raw word from memory
);

    // Extract byte offset from address
    logic [1:0] byte_offset;
    assign byte_offset = address[1:0];
    
    // Word-aligned address (clear lower 2 bits)
    assign mem_address = {address[31:2], 2'b00};
    
    // Memory control signals
    assign mem_enable = mem_read | mem_write;
    assign mem_we = mem_write;

    // ========================================
    // STORE PATH: Format data and generate byte enables
    // ========================================
    always_comb begin
        // Default values
        mem_write_data = 32'h0;
        mem_byte_enable = 4'b0000;
        
        if (mem_write) begin
            case (funct3)
                // SB - Store Byte
                3'b000: begin
                    case (byte_offset)
                        2'b00: begin
                            mem_write_data = {24'h0, store_data[7:0]};
                            mem_byte_enable = 4'b0001;
                        end
                        2'b01: begin
                            mem_write_data = {16'h0, store_data[7:0], 8'h0};
                            mem_byte_enable = 4'b0010;
                        end
                        2'b10: begin
                            mem_write_data = {8'h0, store_data[7:0], 16'h0};
                            mem_byte_enable = 4'b0100;
                        end
                        2'b11: begin
                            mem_write_data = {store_data[7:0], 24'h0};
                            mem_byte_enable = 4'b1000;
                        end
                    endcase
                end
                
                // SH - Store Halfword
                3'b001: begin
                    case (byte_offset[1])
                        1'b0: begin
                            mem_write_data = {16'h0, store_data[15:0]};
                            mem_byte_enable = 4'b0011;
                        end
                        1'b1: begin
                            mem_write_data = {store_data[15:0], 16'h0};
                            mem_byte_enable = 4'b1100;
                        end
                    endcase
                end
                
                // SW - Store Word
                3'b010: begin
                    mem_write_data = store_data;
                    mem_byte_enable = 4'b1111;
                end
                
                default: begin
                    mem_write_data = 32'h0;
                    mem_byte_enable = 4'b0000;
                end
            endcase
        end
    end

    // ========================================
    // LOAD PATH: Extract and sign/zero-extend
    // ========================================
    always_comb begin
        if (mem_read) begin
            case (funct3)
                // LB - Load Byte (signed)
                3'b000: begin
                    case (byte_offset)
                        2'b00: load_data = {{24{mem_read_data[7]}},  mem_read_data[7:0]};
                        2'b01: load_data = {{24{mem_read_data[15]}}, mem_read_data[15:8]};
                        2'b10: load_data = {{24{mem_read_data[23]}}, mem_read_data[23:16]};
                        2'b11: load_data = {{24{mem_read_data[31]}}, mem_read_data[31:24]};
                    endcase
                end
                
                // LH - Load Halfword (signed)
                3'b001: begin
                    case (byte_offset[1])
                        1'b0: load_data = {{16{mem_read_data[15]}}, mem_read_data[15:0]};
                        1'b1: load_data = {{16{mem_read_data[31]}}, mem_read_data[31:16]};
                    endcase
                end
                
                // LW - Load Word
                3'b010: begin
                    load_data = mem_read_data;
                end
                
                // LBU - Load Byte Unsigned
                3'b100: begin
                    case (byte_offset)
                        2'b00: load_data = {24'h0, mem_read_data[7:0]};
                        2'b01: load_data = {24'h0, mem_read_data[15:8]};
                        2'b10: load_data = {24'h0, mem_read_data[23:16]};
                        2'b11: load_data = {24'h0, mem_read_data[31:24]};
                    endcase
                end
                
                // LHU - Load Halfword Unsigned
                3'b101: begin
                    case (byte_offset[1])
                        1'b0: load_data = {16'h0, mem_read_data[15:0]};
                        1'b1: load_data = {16'h0, mem_read_data[31:16]};
                    endcase
                end
                
                default: load_data = 32'h0;
            endcase
        end else begin
            load_data = 32'h0;
        end
    end

endmodule
