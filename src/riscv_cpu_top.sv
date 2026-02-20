// RISC-V 5-Stage Pipeline CPU Top Module
// Integrates: IF, ID, EX, MEM, WB stages with all components

module riscv_cpu_top (
    input  logic clock,
    input  logic reset
);

    // ========== Instruction Fetch (IF) Stage ==========
    logic [31:0] pc_if, pc_plus4_if, instruction_if;
    logic        pc_enable, pc_branch_sel;
    logic [31:0] pc_branch_target;
    
    // PC logic
    assign pc_plus4_if = pc_if + 32'd4;
    assign pc_enable = 1'b1;  // Always enabled (simplified, no stalls yet)
    
    program_counter pc_unit (
        .clock(clock),
        .reset(reset),
        .enable(pc_enable),
        .pc_src(pc_branch_sel),
        .pc_target(pc_branch_target),
        .pc_current(pc_if),
        .pc_next(pc_plus4_if)
    );
    
    // Instruction Memory
    simple_memory #(.ADDR_WIDTH(12)) imem (
        .clock(clock),
        .reset(reset),
        .enable(1'b1),
        .write_enable(1'b0),
        .byte_enable(4'b1111),
        .address(pc_if[11:0]),
        .write_data(32'h0),
        .read_data(instruction_if)
    );

    // ========== IF/ID Pipeline Register ==========
    logic [31:0] instruction_id, pc_id, pc_plus4_id;
    logic        if_id_stall, if_id_flush;
    
    assign if_id_stall = 1'b0;  // Simplified
    assign if_id_flush = pc_branch_sel;
    
    pipeline_if_id if_id_reg (
        .clock(clock),
        .reset(reset),
        .stall(if_id_stall),
        .flush(if_id_flush),
        .instruction_in(instruction_if),
        .pc_in(pc_if),
        .pc_plus4_in(pc_plus4_if),
        .instruction_out(instruction_id),
        .pc_out(pc_id),
        .pc_plus4_out(pc_plus4_id)
    );

    // ========== Instruction Decode (ID) Stage ==========
    logic [4:0]  rs1_id, rs2_id, rd_id;
    logic [31:0] read_data1_id, read_data2_id, immediate_id;
    logic [2:0]  funct3_id, imm_src_id;
    logic        reg_write_id, mem_read_id, mem_write_id, branch_id, jump_id;
    logic [3:0]  alu_op_id;
    logic [1:0]  alu_src_a_id, alu_src_b_id, result_src_id;
    
    assign rs1_id = instruction_id[19:15];
    assign rs2_id = instruction_id[24:20];
    assign rd_id = instruction_id[11:7];
    assign funct3_id = instruction_id[14:12];
    
    // Control Unit
    control_unit ctrl (
        .instruction(instruction_id),
        .reg_write(reg_write_id),
        .mem_read(mem_read_id),
        .mem_write(mem_write_id),
        .branch(branch_id),
        .jump(jump_id),
        .alu_op(alu_op_id),
        .alu_src_a(alu_src_a_id),
        .alu_src_b(alu_src_b_id),
        .imm_src(imm_src_id),
        .result_src(result_src_id)
    );
    
    // Register File
    logic [31:0] write_data_wb;
    logic [4:0]  rd_wb;
    logic        reg_write_wb;
    
    register_file regfile (
        .clock(clock),
        .reset(reset),
        .read_addr1(rs1_id),
        .read_data1(read_data1_id),
        .read_addr2(rs2_id),
        .read_data2(read_data2_id),
        .write_enable(reg_write_wb),
        .write_addr(rd_wb),
        .write_data(write_data_wb)
    );
    
    // Immediate Generator
    immediate_generator immgen (
        .instruction(instruction_id),
        .imm_src(imm_src_id),
        .immediate(immediate_id)
    );

    // ========== ID/EX Pipeline Register ==========
    logic [31:0] pc_ex, pc_plus4_ex, read_data1_ex, read_data2_ex, immediate_ex;
    logic [4:0]  rs1_ex, rs2_ex, rd_ex;
    logic [2:0]  funct3_ex;
    logic        reg_write_ex, mem_read_ex, mem_write_ex, branch_ex, jump_ex;
    logic [3:0]  alu_op_ex;
    logic [1:0]  alu_src_a_ex, alu_src_b_ex, result_src_ex;
    logic        id_ex_flush;
    
    assign id_ex_flush = pc_branch_sel;
    
    pipeline_id_ex id_ex_reg (
        .clock(clock),
        .reset(reset),
        .flush(id_ex_flush),
        .pc_in(pc_id),
        .pc_plus4_in(pc_plus4_id),
        .read_data1_in(read_data1_id),
        .read_data2_in(read_data2_id),
        .immediate_in(immediate_id),
        .rs1_in(rs1_id),
        .rs2_in(rs2_id),
        .rd_in(rd_id),
        .funct3_in(funct3_id),
        .reg_write_in(reg_write_id),
        .mem_read_in(mem_read_id),
        .mem_write_in(mem_write_id),
        .branch_in(branch_id),
        .jump_in(jump_id),
        .alu_op_in(alu_op_id),
        .alu_src_a_in(alu_src_a_id),
        .alu_src_b_in(alu_src_b_id),
        .result_src_in(result_src_id),
        .pc_out(pc_ex),
        .pc_plus4_out(pc_plus4_ex),
        .read_data1_out(read_data1_ex),
        .read_data2_out(read_data2_ex),
        .immediate_out(immediate_ex),
        .rs1_out(rs1_ex),
        .rs2_out(rs2_ex),
        .rd_out(rd_ex),
        .funct3_out(funct3_ex),
        .reg_write_out(reg_write_ex),
        .mem_read_out(mem_read_ex),
        .mem_write_out(mem_write_ex),
        .branch_out(branch_ex),
        .jump_out(jump_ex),
        .alu_op_out(alu_op_ex),
        .alu_src_a_out(alu_src_a_ex),
        .alu_src_b_out(alu_src_b_ex),
        .result_src_out(result_src_ex)
    );

    // ========== Execute (EX) Stage ==========
    // Forward declarations for forwarding unit
    logic [31:0] alu_result_mem;
    logic [4:0]  rd_mem;
    logic        reg_write_mem;
    
    logic [31:0] alu_operand_a, alu_operand_b, alu_result_ex;
    logic        alu_zero, branch_taken_ex;
    logic [31:0] pc_target_ex;
    logic [1:0]  forward_a, forward_b;
    logic [31:0] forwarded_a, forwarded_b;
    
    // Forwarding Unit
    forwarding_unit fwd (
        .rs1_ex(rs1_ex),
        .rs2_ex(rs2_ex),
        .rd_mem(rd_mem),
        .reg_write_mem(reg_write_mem),
        .rd_wb(rd_wb),
        .reg_write_wb(reg_write_wb),
        .forward_a(forward_a),
        .forward_b(forward_b)
    );
    
    // Forwarding muxes for ALU operands
    always_comb begin
        case (forward_a)
            2'b00: forwarded_a = read_data1_ex;    // No forwarding
            2'b01: forwarded_a = write_data_wb;    // Forward from WB
            2'b10: forwarded_a = alu_result_mem;   // Forward from MEM
            default: forwarded_a = read_data1_ex;
        endcase
        
        case (forward_b)
            2'b00: forwarded_b = read_data2_ex;    // No forwarding
            2'b01: forwarded_b = write_data_wb;    // Forward from WB
            2'b10: forwarded_b = alu_result_mem;   // Forward from MEM
            default: forwarded_b = read_data2_ex;
        endcase
    end
    
    // ALU source muxes (now use forwarded values)
    always_comb begin
        case (alu_src_a_ex)
            2'b00: alu_operand_a = forwarded_a;
            2'b01: alu_operand_a = pc_ex;
            2'b10: alu_operand_a = 32'h0;
            default: alu_operand_a = forwarded_a;
        endcase
        
        case (alu_src_b_ex)
            2'b00: alu_operand_b = forwarded_b;
            2'b01: alu_operand_b = immediate_ex;
            2'b10: alu_operand_b = 32'd4;
            default: alu_operand_b = forwarded_b;
        endcase
    end
    
    // ALU
    riscv_alu alu (
        .operand_a(alu_operand_a),
        .operand_b(alu_operand_b),
        .alu_op(alu_op_ex),
        .result(alu_result_ex),
        .zero(alu_zero)
    );
    
    // Branch Unit (also uses forwarded values)
    branch_unit branch_eval (
        .operand_a(forwarded_a),
        .operand_b(forwarded_b),
        .funct3(funct3_ex),
        .branch(branch_ex),
        .branch_taken(branch_taken_ex)
    );
    
    // Branch/Jump target
    assign pc_target_ex = pc_ex + immediate_ex;
    assign pc_branch_sel = (branch_taken_ex && branch_ex) || jump_ex;
    assign pc_branch_target = pc_target_ex;

    // ========== EX/MEM Pipeline Register ==========
    // (alu_result_mem, rd_mem, reg_write_mem declared earlier for forwarding)
    logic [31:0] write_data_mem, pc_target_mem, pc_plus4_mem;
    logic [2:0]  funct3_mem;
    logic        branch_taken_mem, mem_read_mem, mem_write_mem;
    logic [1:0]  result_src_mem;
    logic        ex_mem_flush;
    
    assign ex_mem_flush = 1'b0;
    
    pipeline_ex_mem ex_mem_reg (
        .clock(clock),
        .reset(reset),
        .flush(ex_mem_flush),
        .alu_result_in(alu_result_ex),
        .write_data_in(forwarded_b),
        .pc_target_in(pc_target_ex),
        .pc_plus4_in(pc_plus4_ex),
        .rd_in(rd_ex),
        .funct3_in(funct3_ex),
        .branch_taken_in(branch_taken_ex),
        .reg_write_in(reg_write_ex),
        .mem_read_in(mem_read_ex),
        .mem_write_in(mem_write_ex),
        .result_src_in(result_src_ex),
        .alu_result_out(alu_result_mem),
        .write_data_out(write_data_mem),
        .pc_target_out(pc_target_mem),
        .pc_plus4_out(pc_plus4_mem),
        .rd_out(rd_mem),
        .funct3_out(funct3_mem),
        .branch_taken_out(branch_taken_mem),
        .reg_write_out(reg_write_mem),
        .mem_read_out(mem_read_mem),
        .mem_write_out(mem_write_mem),
        .result_src_out(result_src_mem)
    );

    // ========== Memory (MEM) Stage ==========
    logic [31:0] lsu_load_data, mem_read_data_mem;
    logic [31:0] lsu_mem_addr, lsu_mem_write_data;
    logic [3:0]  lsu_mem_byte_enable;
    logic        lsu_mem_enable, lsu_mem_we;
    
    // Load-Store Unit
    load_store_unit lsu (
        .address(alu_result_mem),
        .store_data(write_data_mem),
        .funct3(funct3_mem),
        .mem_read(mem_read_mem),
        .mem_write(mem_write_mem),
        .load_data(lsu_load_data),
        .mem_address(lsu_mem_addr),
        .mem_write_data(lsu_mem_write_data),
        .mem_byte_enable(lsu_mem_byte_enable),
        .mem_enable(lsu_mem_enable),
        .mem_we(lsu_mem_we),
        .mem_read_data(mem_read_data_mem)
    );
    
    // Data Memory
    simple_memory #(.ADDR_WIDTH(12)) dmem (
        .clock(clock),
        .reset(reset),
        .enable(lsu_mem_enable),
        .write_enable(lsu_mem_we),
        .byte_enable(lsu_mem_byte_enable),
        .address(lsu_mem_addr[11:0]),
        .write_data(lsu_mem_write_data),
        .read_data(mem_read_data_mem)
    );

    // ========== MEM/WB Pipeline Register ==========
    logic [31:0] alu_result_wb, mem_read_data_wb, pc_plus4_wb;
    logic [1:0]  result_src_wb;
    
    pipeline_mem_wb mem_wb_reg (
        .clock(clock),
        .reset(reset),
        .alu_result_in(alu_result_mem),
        .mem_read_data_in(lsu_load_data),
        .pc_plus4_in(pc_plus4_mem),
        .rd_in(rd_mem),
        .reg_write_in(reg_write_mem),
        .result_src_in(result_src_mem),
        .alu_result_out(alu_result_wb),
        .mem_read_data_out(mem_read_data_wb),
        .pc_plus4_out(pc_plus4_wb),
        .rd_out(rd_wb),
        .reg_write_out(reg_write_wb),
        .result_src_out(result_src_wb)
    );

    // ========== Writeback (WB) Stage ==========
    // Result mux
    always_comb begin
        case (result_src_wb)
            2'b00: write_data_wb = alu_result_wb;      // ALU result
            2'b01: write_data_wb = mem_read_data_wb;   // Memory data
            2'b10: write_data_wb = pc_plus4_wb;        // PC+4 (for JAL/JALR)
            default: write_data_wb = alu_result_wb;
        endcase
    end

endmodule
