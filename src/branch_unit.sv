// RISC-V Branch Unit
// Evaluates branch conditions for all RV32I branch instructions
// Pure combinational logic

module branch_unit (
    input  logic [31:0] operand_a,      // First operand (rs1)
    input  logic [31:0] operand_b,      // Second operand (rs2)
    input  logic [2:0]  funct3,         // Branch type selector
    input  logic        branch,         // Branch instruction signal from control
    output logic        branch_taken    // Branch taken output
);

    // Branch comparison results
    logic equal;
    logic less_than_signed;
    logic less_than_unsigned;

    // Perform comparisons
    assign equal = (operand_a == operand_b);
    assign less_than_signed = ($signed(operand_a) < $signed(operand_b));
    assign less_than_unsigned = (operand_a < operand_b);

    // Evaluate branch condition based on funct3
    always_comb begin
        if (branch) begin
            case (funct3)
                3'b000: branch_taken = equal;                   // BEQ: Branch if Equal
                3'b001: branch_taken = !equal;                  // BNE: Branch if Not Equal
                3'b100: branch_taken = less_than_signed;        // BLT: Branch if Less Than (signed)
                3'b101: branch_taken = !less_than_signed;       // BGE: Branch if Greater or Equal (signed)
                3'b110: branch_taken = less_than_unsigned;      // BLTU: Branch if Less Than Unsigned
                3'b111: branch_taken = !less_than_unsigned;     // BGEU: Branch if Greater or Equal Unsigned
                default: branch_taken = 1'b0;
            endcase
        end else begin
            branch_taken = 1'b0;
        end
    end

endmodule