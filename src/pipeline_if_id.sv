// IF/ID Pipeline Register
module pipeline_if_id (
    input  logic        clock,
    input  logic        reset,
    input  logic        stall,
    input  logic        flush,
    input  logic [31:0] instruction_in,
    input  logic [31:0] pc_in,
    input  logic [31:0] pc_plus4_in,
    output logic [31:0] instruction_out,
    output logic [31:0] pc_out,
    output logic [31:0] pc_plus4_out
);
    always_ff @(posedge clock) begin
        if (reset || flush) begin
            instruction_out <= 32'h00000013;
            pc_out <= 32'h0;
            pc_plus4_out <= 32'h0;
        end else if (!stall) begin
            instruction_out <= instruction_in;
            pc_out <= pc_in;
            pc_plus4_out <= pc_plus4_in;
        end
    end
endmodule
