// RISC-V Program Counter (PC) Module
// For 5-stage pipeline implementation
// Handles sequential execution, branches, and jumps

module program_counter #(
    parameter RESET_ADDR = 32'h00000000  // Initial PC value on reset
) (
    input  logic        clock,           // System clock
    input  logic        reset,           // Synchronous reset (active high)
    input  logic        enable,          // Enable PC update (0 = stall)
    input  logic        pc_src,          // PC source select: 0=PC+4, 1=branch/jump target
    input  logic [31:0] pc_target,       // Branch/jump target address
    output logic [31:0] pc_current,      // Current PC value
    output logic [31:0] pc_next          // Next PC value (PC+4)
);

    // Internal signals
    logic [31:0] pc_reg;                 // PC register
    logic [31:0] pc_increment;           // PC + 4
    logic [31:0] pc_new;                 // Next PC value (muxed)

    // Calculate PC + 4 for sequential execution
    assign pc_increment = pc_reg + 32'd4;

    // Multiplexer: select between PC+4 and branch/jump target
    assign pc_new = pc_src ? pc_target : pc_increment;

    // Output assignments
    assign pc_current = pc_reg;
    assign pc_next = pc_increment;

    // PC Register - synchronous update
    always_ff @(posedge clock) begin
        if (reset) begin
            // Reset PC to initial address
            pc_reg <= RESET_ADDR;
        end else if (enable) begin
            // Update PC when enabled
            pc_reg <= pc_new;
        end
        // If enable=0, PC holds its value (pipeline stall)
    end

endmodule
