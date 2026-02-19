// MEM/WB Pipeline Register
module pipeline_mem_wb (
    input  logic        clock,
    input  logic        reset,
    input  logic [31:0] alu_result_in,
    input  logic [31:0] mem_read_data_in,
    input  logic [31:0] pc_plus4_in,
    input  logic [4:0]  rd_in,
    input  logic        reg_write_in,
    input  logic [1:0]  result_src_in,
    output logic [31:0] alu_result_out,
    output logic [31:0] mem_read_data_out,
    output logic [31:0] pc_plus4_out,
    output logic [4:0]  rd_out,
    output logic        reg_write_out,
    output logic [1:0]  result_src_out
);
    always_ff @(posedge clock) begin
        if (reset) begin
            alu_result_out <= 32'h0;
            mem_read_data_out <= 32'h0;
            pc_plus4_out <= 32'h0;
            rd_out <= 5'h0;
            reg_write_out <= 1'b0;
            result_src_out <= 2'b00;
        end else begin
            alu_result_out <= alu_result_in;
            mem_read_data_out <= mem_read_data_in;
            pc_plus4_out <= pc_plus4_in;
            rd_out <= rd_in;
            reg_write_out <= reg_write_in;
            result_src_out <= result_src_in;
        end
    end
endmodule
