// RISC-V Immediate Generator
// Extracts and formats immediate values from instructions
// Supports all RV32I immediate formats: I, S, B, U, J

module immediate_generator (
    input  logic [31:0] instruction,    // 32-bit instruction
    input  logic [2:0]  imm_src,        // Immediate format selector
    output logic [31:0] immediate       // Formatted 32-bit immediate value
);

    // Immediate format types (matches control_unit.sv)
    localparam logic [2:0] IMM_I = 3'b000;  // I-type
    localparam logic [2:0] IMM_S = 3'b001;  // S-type
    localparam logic [2:0] IMM_B = 3'b010;  // B-type
    localparam logic [2:0] IMM_U = 3'b011;  // U-type
    localparam logic [2:0] IMM_J = 3'b100;  // J-type

    // Extract immediate value based on format
    always_comb begin
        case (imm_src)
            // I-type: 12-bit sign-extended
            // Format: inst[31:20]
            // Used by: ADDI, SLTI, XORI, ORI, ANDI, loads, JALR
            IMM_I: begin
                immediate = {{20{instruction[31]}}, instruction[31:20]};
            end

            // S-type: 12-bit sign-extended, split format
            // Format: {inst[31:25], inst[11:7]}
            // Used by: SB, SH, SW (stores)
            IMM_S: begin
                immediate = {{20{instruction[31]}}, instruction[31:25], instruction[11:7]};
            end

            // B-type: 13-bit sign-extended, split format
            // Format: {inst[31], inst[7], inst[30:25], inst[11:8], 1'b0}
            // Bit 0 is implicitly 0 (halfword aligned)
            // Used by: BEQ, BNE, BLT, BGE, BLTU, BGEU
            IMM_B: begin
                immediate = {{19{instruction[31]}}, instruction[31], instruction[7], 
                            instruction[30:25], instruction[11:8], 1'b0};
            end

            // U-type: 20-bit in upper bits
            // Format: {inst[31:12], 12'b0}
            // Used by: LUI, AUIPC
            IMM_U: begin
                immediate = {instruction[31:12], 12'b0};
            end

            // J-type: 21-bit sign-extended, split format
            // Format: {inst[31], inst[19:12], inst[20], inst[30:21], 1'b0}
            // Bit 0 is implicitly 0 (halfword aligned)
            // Used by: JAL
            IMM_J: begin
                immediate = {{11{instruction[31]}}, instruction[31], instruction[19:12],
                            instruction[20], instruction[30:21], 1'b0};
            end

            // Default: I-type format
            default: begin
                immediate = {{20{instruction[31]}}, instruction[31:20]};
            end
        endcase
    end

endmodule
