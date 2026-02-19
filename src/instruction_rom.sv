// Simple Instruction ROM - doesn't clear on reset
module instruction_rom #(
    parameter ADDR_WIDTH = 12
) (
    input  logic [ADDR_WIDTH-1:0] address,
    output logic [31:0] read_data
);
    logic [7:0] memory [(2**ADDR_WIDTH)-1:0];
    
    // Asynchronous read - always reads, never clears
    assign read_data = {memory[address[ADDR_WIDTH-1:2]*4 + 3],
                       memory[address[ADDR_WIDTH-1:2]*4 + 2],
                       memory[address[ADDR_WIDTH-1:2]*4 + 1],
                       memory[address[ADDR_WIDTH-1:2]*4 + 0]};
endmodule
