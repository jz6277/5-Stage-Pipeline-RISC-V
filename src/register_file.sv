// RISC-V Register File
// 32 x 32-bit general-purpose registers for RV32I
// Dual-read, single-write port configuration

module register_file (
    input  logic        clock,          // System clock
    input  logic        reset,          // Synchronous reset (active high)
    
    // Read Port 1 (rs1)
    input  logic [4:0]  read_addr1,     // Read address 1 (rs1)
    output logic [31:0] read_data1,     // Read data 1
    
    // Read Port 2 (rs2)
    input  logic [4:0]  read_addr2,     // Read address 2 (rs2)
    output logic [31:0] read_data2,     // Read data 2
    
    // Write Port (rd)
    input  logic        write_enable,   // Write enable
    input  logic [4:0]  write_addr,     // Write address (rd)
    input  logic [31:0] write_data      // Write data
);

    // Register array: 32 registers of 32 bits each
    // x0 to x31
    logic [31:0] registers [31:0];

    // Asynchronous Read Port 1
    // x0 always returns 0, regardless of stored value
    assign read_data1 = (read_addr1 == 5'd0) ? 32'd0 : registers[read_addr1];

    // Asynchronous Read Port 2
    // x0 always returns 0, regardless of stored value
    assign read_data2 = (read_addr2 == 5'd0) ? 32'd0 : registers[read_addr2];

    // Synchronous Write Port
    // Writes on positive clock edge when write_enable is high
    // Writing to x0 is ignored (x0 is hardwired to zero)
    always_ff @(posedge clock) begin
        if (reset) begin
            // Reset all registers to 0
            for (int i = 0; i < 32; i = i + 1) begin
                registers[i] <= 32'd0;
            end
        end else if (write_enable && (write_addr != 5'd0)) begin
            // Write to register (except x0)
            registers[write_addr] <= write_data;
        end
    end

endmodule
