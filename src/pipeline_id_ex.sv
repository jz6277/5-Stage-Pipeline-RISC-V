// ID/EX Pipeline Register
module pipeline_id_ex (
    input  logic        clock,
    input  logic        reset,
    input  logic        flush,
    input  logic [31:0] pc_in,
    input  logic [31:0] pc_plus4_in,
    input  logic [31:0] read_data1_in,
    input  logic [31:0] read_data2_in,
    input  logic [31:0] immediate_in,
    input  logic [4:0]  rs1_in,
    input  logic [4:0]  rs2_in,
    input  logic [4:0]  rd_in,
    input  logic [2:0]  funct3_in,
    input  logic        reg_write_in,
    input  logic        mem_read_in,
    input  logic        mem_write_in,
    input  logic        branch_in,
    input  logic        jump_in,
    input  logic [3:0]  alu_op_in,
    input  logic [1:0]  alu_src_a_in,
    input  logic [1:0]  alu_src_b_in,
    input  logic [1:0]  result_src_in,
    output logic [31:0] pc_out,
    output logic [31:0] pc_plus4_out,
    output logic [31:0] read_data1_out,
    output logic [31:0] read_data2_out,
    output logic [31:0] immediate_out,
    output logic [4:0]  rs1_out,
    output logic [4:0]  rs2_out,
    output logic [4:0]  rd_out,
    output logic [2:0]  funct3_out,
    output logic        reg_write_out,
    output logic        mem_read_out,
    output logic        mem_write_out,
    output logic        branch_out,
    output logic        jump_out,
    output logic [3:0]  alu_op_out,
    output logic [1:0]  alu_src_a_out,
    output logic [1:0]  alu_src_b_out,
    output logic [1:0]  result_src_out
);
    always_ff @(posedge clock) begin
        if (reset || flush) begin
            pc_out <= 32'h0; pc_plus4_out <= 32'h0; read_data1_out <= 32'h0; read_data2_out <= 32'h0;
            immediate_out <= 32'h0; rs1_out <= 5'h0; rs2_out <= 5'h0; rd_out <= 5'h0; funct3_out <= 3'h0;
            reg_write_out <= 1'b0; mem_read_out <= 1'b0; mem_write_out <= 1'b0; branch_out <= 1'b0;
            jump_out <= 1'b0; alu_op_out <= 4'h0; alu_src_a_out <= 2'b00; alu_src_b_out <= 2'b00; result_src_out <= 2'b00;
        end else begin
            pc_out <= pc_in; pc_plus4_out <= pc_plus4_in; read_data1_out <= read_data1_in; read_data2_out <= read_data2_in;
            immediate_out <= immediate_in; rs1_out <= rs1_in; rs2_out <= rs2_in; rd_out <= rd_in; funct3_out <= funct3_in;
            reg_write_out <= reg_write_in; mem_read_out <= mem_read_in; mem_write_out <= mem_write_in; branch_out <= branch_in;
            jump_out <= jump_in; alu_op_out <= alu_op_in; alu_src_a_out <= alu_src_a_in; alu_src_b_out <= alu_src_b_in; result_src_out <= result_src_in;
        end
    end
endmodule
