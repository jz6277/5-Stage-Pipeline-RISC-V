// Comprehensive Testbench for RISC-V Control Unit
// Tests all RV32I instruction decoding and control signal generation

module tb_control_unit;

    // Testbench signals
    logic [31:0] instruction;
    logic        reg_write;
    logic        mem_read;
    logic        mem_write;
    logic        branch;
    logic        jump;
    logic [3:0]  alu_op;
    logic [1:0]  alu_src_a;
    logic [1:0]  alu_src_b;
    logic [2:0]  imm_src;
    logic [1:0]  result_src;

    // Test tracking
    int error_count = 0;
    int test_count = 0;

    // Expected values for verification
    logic        exp_reg_write;
    logic        exp_mem_read;
    logic        exp_mem_write;
    logic        exp_branch;
    logic        exp_jump;
    logic [3:0]  exp_alu_op;
    logic [1:0]  exp_alu_src_a;
    logic [1:0]  exp_alu_src_b;
    logic [2:0]  exp_imm_src;
    logic [1:0]  exp_result_src;

    // Instantiate DUT
    control_unit dut (
        .instruction(instruction),
        .reg_write(reg_write),
        .mem_read(mem_read),
        .mem_write(mem_write),
        .branch(branch),
        .jump(jump),
        .alu_op(alu_op),
        .alu_src_a(alu_src_a),
        .alu_src_b(alu_src_b),
        .imm_src(imm_src),
        .result_src(result_src)
    );

    // ALU operation codes (matching control_unit.sv)
    localparam logic [3:0] ALU_ADD  = 4'b0000;
    localparam logic [3:0] ALU_SUB  = 4'b0001;
    localparam logic [3:0] ALU_AND  = 4'b0010;
    localparam logic [3:0] ALU_OR   = 4'b0011;
    localparam logic [3:0] ALU_XOR  = 4'b0100;
    localparam logic [3:0] ALU_SLT  = 4'b0101;
    localparam logic [3:0] ALU_SLTU = 4'b0110;
    localparam logic [3:0] ALU_SLL  = 4'b0111;
    localparam logic [3:0] ALU_SRL  = 4'b1000;
    localparam logic [3:0] ALU_SRA  = 4'b1001;

    // Immediate format types
    localparam logic [2:0] IMM_I = 3'b000;
    localparam logic [2:0] IMM_S = 3'b001;
    localparam logic [2:0] IMM_B = 3'b010;
    localparam logic [2:0] IMM_U = 3'b011;
    localparam logic [2:0] IMM_J = 3'b100;

    // Helper function to create R-type instruction
    function logic [31:0] r_type(input logic [6:0] funct7, input logic [4:0] rs2, 
                                   input logic [4:0] rs1, input logic [2:0] funct3,
                                   input logic [4:0] rd, input logic [6:0] opcode);
        return {funct7, rs2, rs1, funct3, rd, opcode};
    endfunction

    // Helper function to create I-type instruction
    function logic [31:0] i_type(input logic [11:0] imm, input logic [4:0] rs1,
                                   input logic [2:0] funct3, input logic [4:0] rd,
                                   input logic [6:0] opcode);
        return {imm, rs1, funct3, rd, opcode};
    endfunction

    // Helper function to create S-type instruction
    function logic [31:0] s_type(input logic [11:0] imm, input logic [4:0] rs2,
                                   input logic [4:0] rs1, input logic [2:0] funct3,
                                   input logic [6:0] opcode);
        return {imm[11:5], rs2, rs1, funct3, imm[4:0], opcode};
    endfunction

    // Helper function to create B-type instruction
    function logic [31:0] b_type(input logic [12:0] imm, input logic [4:0] rs2,
                                   input logic [4:0] rs1, input logic [2:0] funct3,
                                   input logic [6:0] opcode);
        return {imm[12], imm[10:5], rs2, rs1, funct3, imm[4:1], imm[11], opcode};
    endfunction

    // Helper function to create U-type instruction
    function logic [31:0] u_type(input logic [31:0] imm, input logic [4:0] rd,
                                   input logic [6:0] opcode);
        return {imm[31:12], rd, opcode};
    endfunction

    // Helper function to create J-type instruction
    function logic [31:0] j_type(input logic [20:0] imm, input logic [4:0] rd,
                                   input logic [6:0] opcode);
        return {imm[20], imm[10:1], imm[11], imm[19:12], rd, opcode};
    endfunction

    // Check all control signals
    task automatic check_signals(input string test_name);
        test_count++;
        #1; // Small delay for combinational logic
        
        if (reg_write !== exp_reg_write) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_control_unit : dut.reg_write : expected_value: %0b actual_value: %0b",
                     $time, exp_reg_write, reg_write);
            $display("  Test: %s", test_name);
        end
        
        if (mem_read !== exp_mem_read) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_control_unit : dut.mem_read : expected_value: %0b actual_value: %0b",
                     $time, exp_mem_read, mem_read);
            $display("  Test: %s", test_name);
        end
        
        if (mem_write !== exp_mem_write) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_control_unit : dut.mem_write : expected_value: %0b actual_value: %0b",
                     $time, exp_mem_write, mem_write);
            $display("  Test: %s", test_name);
        end
        
        if (branch !== exp_branch) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_control_unit : dut.branch : expected_value: %0b actual_value: %0b",
                     $time, exp_branch, branch);
            $display("  Test: %s", test_name);
        end
        
        if (jump !== exp_jump) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_control_unit : dut.jump : expected_value: %0b actual_value: %0b",
                     $time, exp_jump, jump);
            $display("  Test: %s", test_name);
        end
        
        if (alu_op !== exp_alu_op) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_control_unit : dut.alu_op : expected_value: 0x%01h actual_value: 0x%01h",
                     $time, exp_alu_op, alu_op);
            $display("  Test: %s", test_name);
        end
        
        if (alu_src_a !== exp_alu_src_a) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_control_unit : dut.alu_src_a : expected_value: 0x%01h actual_value: 0x%01h",
                     $time, exp_alu_src_a, alu_src_a);
            $display("  Test: %s", test_name);
        end
        
        if (alu_src_b !== exp_alu_src_b) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_control_unit : dut.alu_src_b : expected_value: 0x%01h actual_value: 0x%01h",
                     $time, exp_alu_src_b, alu_src_b);
            $display("  Test: %s", test_name);
        end
        
        if (imm_src !== exp_imm_src) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_control_unit : dut.imm_src : expected_value: 0x%01h actual_value: 0x%01h",
                     $time, exp_imm_src, imm_src);
            $display("  Test: %s", test_name);
        end
        
        if (result_src !== exp_result_src) begin
            error_count++;
            $display("LOG: %0t : ERROR : tb_control_unit : dut.result_src : expected_value: 0x%01h actual_value: 0x%01h",
                     $time, exp_result_src, result_src);
            $display("  Test: %s", test_name);
        end
    endtask

    // Main test sequence
    initial begin
        $display("TEST START");
        $display("========================================");
        $display("Control Unit Comprehensive Test");
        $display("========================================");

        // Initialize
        instruction = 32'h00000013;  // NOP (ADDI x0, x0, 0)
        #10;

        // ==========================================
        // Test 1: LUI (Load Upper Immediate)
        // ==========================================
        $display("\n[INFO] Test 1: LUI Instructions");
        
        instruction = u_type(32'h12345000, 5'd1, 7'b0110111);  // LUI x1, 0x12345
        exp_reg_write = 1; exp_mem_read = 0; exp_mem_write = 0;
        exp_branch = 0; exp_jump = 0; exp_alu_op = ALU_ADD;
        exp_alu_src_a = 2'b10; exp_alu_src_b = 2'b01;
        exp_imm_src = IMM_U; exp_result_src = 2'b00;
        check_signals("LUI x1, 0x12345");

        // ==========================================
        // Test 2: AUIPC (Add Upper Immediate to PC)
        // ==========================================
        $display("\n[INFO] Test 2: AUIPC Instructions");
        
        instruction = u_type(32'hABCDE000, 5'd2, 7'b0010111);  // AUIPC x2, 0xABCDE
        exp_reg_write = 1; exp_mem_read = 0; exp_mem_write = 0;
        exp_branch = 0; exp_jump = 0; exp_alu_op = ALU_ADD;
        exp_alu_src_a = 2'b01; exp_alu_src_b = 2'b01;
        exp_imm_src = IMM_U; exp_result_src = 2'b00;
        check_signals("AUIPC x2, 0xABCDE");

        // ==========================================
        // Test 3: JAL (Jump and Link)
        // ==========================================
        $display("\n[INFO] Test 3: JAL Instructions");
        
        instruction = j_type(21'h100, 5'd3, 7'b1101111);  // JAL x3, offset
        exp_reg_write = 1; exp_mem_read = 0; exp_mem_write = 0;
        exp_branch = 0; exp_jump = 1; exp_alu_op = ALU_ADD;
        exp_alu_src_a = 2'b01; exp_alu_src_b = 2'b01;
        exp_imm_src = IMM_J; exp_result_src = 2'b10;
        check_signals("JAL x3, offset");

        // ==========================================
        // Test 4: JALR (Jump and Link Register)
        // ==========================================
        $display("\n[INFO] Test 4: JALR Instructions");
        
        instruction = i_type(12'h100, 5'd4, 3'b000, 5'd5, 7'b1100111);  // JALR x5, x4, 0x100
        exp_reg_write = 1; exp_mem_read = 0; exp_mem_write = 0;
        exp_branch = 0; exp_jump = 1; exp_alu_op = ALU_ADD;
        exp_alu_src_a = 2'b00; exp_alu_src_b = 2'b01;
        exp_imm_src = IMM_I; exp_result_src = 2'b10;
        check_signals("JALR x5, x4, 0x100");

        // ==========================================
        // Test 5: Branch Instructions
        // ==========================================
        $display("\n[INFO] Test 5: Branch Instructions");
        
        // BEQ
        instruction = b_type(13'h100, 5'd6, 5'd7, 3'b000, 7'b1100011);  // BEQ x7, x6, offset
        exp_reg_write = 0; exp_mem_read = 0; exp_mem_write = 0;
        exp_branch = 1; exp_jump = 0; exp_alu_op = ALU_SUB;
        exp_alu_src_a = 2'b00; exp_alu_src_b = 2'b00;
        exp_imm_src = IMM_B; exp_result_src = 2'b00;
        check_signals("BEQ x7, x6, offset");
        
        // BNE
        instruction = b_type(13'h200, 5'd8, 5'd9, 3'b001, 7'b1100011);  // BNE x9, x8, offset
        check_signals("BNE x9, x8, offset");

        // ==========================================
        // Test 6: Load Instructions
        // ==========================================
        $display("\n[INFO] Test 6: Load Instructions");
        
        // LW
        instruction = i_type(12'h100, 5'd10, 3'b010, 5'd11, 7'b0000011);  // LW x11, 0x100(x10)
        exp_reg_write = 1; exp_mem_read = 1; exp_mem_write = 0;
        exp_branch = 0; exp_jump = 0; exp_alu_op = ALU_ADD;
        exp_alu_src_a = 2'b00; exp_alu_src_b = 2'b01;
        exp_imm_src = IMM_I; exp_result_src = 2'b01;
        check_signals("LW x11, 0x100(x10)");
        
        // LH
        instruction = i_type(12'h050, 5'd12, 3'b001, 5'd13, 7'b0000011);  // LH x13, 0x50(x12)
        check_signals("LH x13, 0x50(x12)");

        // ==========================================
        // Test 7: Store Instructions
        // ==========================================
        $display("\n[INFO] Test 7: Store Instructions");
        
        // SW
        instruction = s_type(12'h100, 5'd14, 5'd15, 3'b010, 7'b0100011);  // SW x14, 0x100(x15)
        exp_reg_write = 0; exp_mem_read = 0; exp_mem_write = 1;
        exp_branch = 0; exp_jump = 0; exp_alu_op = ALU_ADD;
        exp_alu_src_a = 2'b00; exp_alu_src_b = 2'b01;
        exp_imm_src = IMM_S; exp_result_src = 2'b00;
        check_signals("SW x14, 0x100(x15)");
        
        // SH
        instruction = s_type(12'h020, 5'd16, 5'd17, 3'b001, 7'b0100011);  // SH x16, 0x20(x17)
        check_signals("SH x16, 0x20(x17)");

        // ==========================================
        // Test 8: Immediate ALU Instructions
        // ==========================================
        $display("\n[INFO] Test 8: Immediate ALU Instructions");
        
        exp_reg_write = 1; exp_mem_read = 0; exp_mem_write = 0;
        exp_branch = 0; exp_jump = 0;
        exp_alu_src_a = 2'b00; exp_alu_src_b = 2'b01;
        exp_imm_src = IMM_I; exp_result_src = 2'b00;
        
        // ADDI
        instruction = i_type(12'h100, 5'd1, 3'b000, 5'd2, 7'b0010011);
        exp_alu_op = ALU_ADD;
        check_signals("ADDI x2, x1, 0x100");
        
        // SLTI
        instruction = i_type(12'h050, 5'd3, 3'b010, 5'd4, 7'b0010011);
        exp_alu_op = ALU_SLT;
        check_signals("SLTI x4, x3, 0x50");
        
        // SLTIU
        instruction = i_type(12'h020, 5'd5, 3'b011, 5'd6, 7'b0010011);
        exp_alu_op = ALU_SLTU;
        check_signals("SLTIU x6, x5, 0x20");
        
        // XORI
        instruction = i_type(12'hFFF, 5'd7, 3'b100, 5'd8, 7'b0010011);
        exp_alu_op = ALU_XOR;
        check_signals("XORI x8, x7, 0xFFF");
        
        // ORI
        instruction = i_type(12'h0FF, 5'd9, 3'b110, 5'd10, 7'b0010011);
        exp_alu_op = ALU_OR;
        check_signals("ORI x10, x9, 0xFF");
        
        // ANDI
        instruction = i_type(12'h0F0, 5'd11, 3'b111, 5'd12, 7'b0010011);
        exp_alu_op = ALU_AND;
        check_signals("ANDI x12, x11, 0xF0");
        
        // SLLI
        instruction = i_type(12'h005, 5'd13, 3'b001, 5'd14, 7'b0010011);
        exp_alu_op = ALU_SLL;
        check_signals("SLLI x14, x13, 5");
        
        // SRLI
        instruction = i_type(12'h008, 5'd15, 3'b101, 5'd16, 7'b0010011);
        exp_alu_op = ALU_SRL;
        check_signals("SRLI x16, x15, 8");
        
        // SRAI
        instruction = i_type(12'h40A, 5'd17, 3'b101, 5'd18, 7'b0010011);
        exp_alu_op = ALU_SRA;
        check_signals("SRAI x18, x17, 10");

        // ==========================================
        // Test 9: Register ALU Instructions
        // ==========================================
        $display("\n[INFO] Test 9: Register ALU Instructions");
        
        exp_reg_write = 1; exp_mem_read = 0; exp_mem_write = 0;
        exp_branch = 0; exp_jump = 0;
        exp_alu_src_a = 2'b00; exp_alu_src_b = 2'b00;
        exp_imm_src = IMM_I; exp_result_src = 2'b00;
        
        // ADD
        instruction = r_type(7'b0000000, 5'd2, 5'd1, 3'b000, 5'd3, 7'b0110011);
        exp_alu_op = ALU_ADD;
        check_signals("ADD x3, x1, x2");
        
        // SUB
        instruction = r_type(7'b0100000, 5'd4, 5'd3, 3'b000, 5'd5, 7'b0110011);
        exp_alu_op = ALU_SUB;
        check_signals("SUB x5, x3, x4");
        
        // SLL
        instruction = r_type(7'b0000000, 5'd6, 5'd5, 3'b001, 5'd7, 7'b0110011);
        exp_alu_op = ALU_SLL;
        check_signals("SLL x7, x5, x6");
        
        // SLT
        instruction = r_type(7'b0000000, 5'd8, 5'd7, 3'b010, 5'd9, 7'b0110011);
        exp_alu_op = ALU_SLT;
        check_signals("SLT x9, x7, x8");
        
        // SLTU
        instruction = r_type(7'b0000000, 5'd10, 5'd9, 3'b011, 5'd11, 7'b0110011);
        exp_alu_op = ALU_SLTU;
        check_signals("SLTU x11, x9, x10");
        
        // XOR
        instruction = r_type(7'b0000000, 5'd12, 5'd11, 3'b100, 5'd13, 7'b0110011);
        exp_alu_op = ALU_XOR;
        check_signals("XOR x13, x11, x12");
        
        // SRL
        instruction = r_type(7'b0000000, 5'd14, 5'd13, 3'b101, 5'd15, 7'b0110011);
        exp_alu_op = ALU_SRL;
        check_signals("SRL x15, x13, x14");
        
        // SRA
        instruction = r_type(7'b0100000, 5'd16, 5'd15, 3'b101, 5'd17, 7'b0110011);
        exp_alu_op = ALU_SRA;
        check_signals("SRA x17, x15, x16");
        
        // OR
        instruction = r_type(7'b0000000, 5'd18, 5'd17, 3'b110, 5'd19, 7'b0110011);
        exp_alu_op = ALU_OR;
        check_signals("OR x19, x17, x18");
        
        // AND
        instruction = r_type(7'b0000000, 5'd20, 5'd19, 3'b111, 5'd21, 7'b0110011);
        exp_alu_op = ALU_AND;
        check_signals("AND x21, x19, x20");

        // ==========================================
        // Test 10: Invalid Opcode (should behave as NOP)
        // ==========================================
        $display("\n[INFO] Test 10: Invalid Opcode");
        
        instruction = 32'hFFFFFFFF;  // Invalid instruction
        exp_reg_write = 0; exp_mem_read = 0; exp_mem_write = 0;
        exp_branch = 0; exp_jump = 0; exp_alu_op = ALU_ADD;
        exp_alu_src_a = 2'b00; exp_alu_src_b = 2'b00;
        exp_imm_src = IMM_I; exp_result_src = 2'b00;
        check_signals("Invalid opcode");

        // Wait a bit
        #100;

        // ==========================================
        // Final Report
        // ==========================================
        $display("\n========================================");
        $display("Test Summary");
        $display("========================================");
        $display("Total Tests: %0d", test_count);
        $display("Errors:      %0d", error_count);
        
        if (error_count == 0) begin
            $display("\nTEST PASSED");
        end else begin
            $display("\nERROR");
            $fatal(1, "TEST FAILED with %0d errors", error_count);
        end
        
        $finish(0);
    end

    // Waveform dump
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
