// Data Forwarding Unit for RISC-V Pipeline
// Detects hazards and generates forwarding control signals

module forwarding_unit (
    // From EX stage
    input  logic [4:0]  rs1_ex,
    input  logic [4:0]  rs2_ex,
    
    // From MEM stage
    input  logic [4:0]  rd_mem,
    input  logic        reg_write_mem,
    
    // From WB stage
    input  logic [4:0]  rd_wb,
    input  logic        reg_write_wb,
    
    // Forwarding control outputs
    output logic [1:0]  forward_a,  // For ALU operand A
    output logic [1:0]  forward_b   // For ALU operand B
);

    // Forward operand A
    always_comb begin
        if (reg_write_mem && (rd_mem != 5'b0) && (rd_mem == rs1_ex)) begin
            forward_a = 2'b10;  // Forward from MEM stage
        end else if (reg_write_wb && (rd_wb != 5'b0) && (rd_wb == rs1_ex)) begin
            forward_a = 2'b01;  // Forward from WB stage
        end else begin
            forward_a = 2'b00;  // No forwarding
        end
    end

    // Forward operand B
    always_comb begin
        if (reg_write_mem && (rd_mem != 5'b0) && (rd_mem == rs2_ex)) begin
            forward_b = 2'b10;  // Forward from MEM stage
        end else if (reg_write_wb && (rd_wb != 5'b0) && (rd_wb == rs2_ex)) begin
            forward_b = 2'b01;  // Forward from WB stage
        end else begin
            forward_b = 2'b00;  // No forwarding
        end
    end

endmodule
