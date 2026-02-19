// EX/MEM Pipeline Register
module pipeline_ex_mem (
    input  logic        clock,
    input  logic        reset,
    input  logic        flush,
    input  logic [31:0] alu_result_in,
    input  logic [31:0] write_data_in,
    input  logic [31:0] pc_target_in,
    input  logic [31:0] pc_plus4_in,
    input  logic [4:0]  rd_in,
    input  logic [2:0]  funct3_in,
    input  logic        branch_taken_in,
    input  logic        reg_write_in,
    input  logic        mem_read_in,
    input  logic        mem_write_in,
    input  logic [1:0]  result_src_in,
    output logic [31:0] alu_result_out,
    output logic [31:0] write_data_out,
    output logic [31:0] pc_target_out,
    output logic [31:0] pc_plus4_out,
    output logic [4:0]  rd_out,
    output logic [2:0]  funct3_out,
    output logic        branch_taken_out,
    output logic        reg_write_out,
    output logic        mem_read_out,
    output logic        mem_write_out,
    output logic [1:0]  result_src_out
);
    always_ff @(posedge clock) begin
        if (reset || flush) begin
            alu_result_out <= 32'h0; write_data_out <= 32'h0; pc_target_out <= 32'h0; pc_plus4_out <= 32'h0;
            rd_out <= 5'h0; funct3_out <= 3'h0; branch_taken_out <= 1'b0;
            reg_write_out <= 1'b0; mem_read_out <= 1'b0; mem_write_out <= 1'b0; result_src_out <= 2'b00;
        end else begin
            alu_result_out <= alu_result_in; write_data_out <= write_data_in; pc_target_out <= pc_target_in; pc_plus4_out <= pc_plus4_in;
            rd_out <= rd_in; funct3_out <= funct3_in; branch_taken_out <= branch_taken_in;
            reg_write_out <= reg_write_in; mem_read_out <= mem_read_in; mem_write_out <= mem_write_in; result_src_out <= result_src_in;
        end
    end
endmodule
