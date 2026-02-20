// RISC-V 32-bit ALU for RV32I Base Integer Instruction Set
// Gate-Level Implementation
// Supports: ADD, SUB, AND, OR, XOR, SLT, SLTU, SLL, SRL, SRA

module riscv_alu (
    input  logic [31:0] operand_a,    // First operand
    input  logic [31:0] operand_b,    // Second operand
    input  logic [3:0]  alu_op,       // ALU operation select
    output logic [31:0] result,       // ALU result
    output logic        zero          // Zero flag (result == 0)
);

    // ALU Operation Codes
    localparam logic [3:0] ALU_ADD  = 4'b0000;  // Addition
    localparam logic [3:0] ALU_SUB  = 4'b0001;  // Subtraction
    localparam logic [3:0] ALU_AND  = 4'b0010;  // Bitwise AND
    localparam logic [3:0] ALU_OR   = 4'b0011;  // Bitwise OR
    localparam logic [3:0] ALU_XOR  = 4'b0100;  // Bitwise XOR
    localparam logic [3:0] ALU_SLT  = 4'b0101;  // Set Less Than (signed)
    localparam logic [3:0] ALU_SLTU = 4'b0110;  // Set Less Than Unsigned
    localparam logic [3:0] ALU_SLL  = 4'b0111;  // Shift Left Logical
    localparam logic [3:0] ALU_SRL  = 4'b1000;  // Shift Right Logical
    localparam logic [3:0] ALU_SRA  = 4'b1001;  // Shift Right Arithmetic

    // Internal wires for different operations
    logic [31:0] and_result, or_result, xor_result;
    logic [31:0] add_sub_result;
    logic [31:0] sll_result, srl_result, sra_result;
    logic [31:0] b_inverted;
    logic [31:0] b_input;
    logic        add_sub_carry_out;
    logic        less_than_signed, less_than_unsigned;
    logic        is_sub;

    // Decode operation type
    assign is_sub = (alu_op == ALU_SUB) | (alu_op == ALU_SLT) | (alu_op == ALU_SLTU);

    // =====================================================
    // Logic Operations (Bitwise gate-level)
    // =====================================================
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : logic_ops
            and (and_result[i], operand_a[i], operand_b[i]);
            or  (or_result[i],  operand_a[i], operand_b[i]);
            xor (xor_result[i], operand_a[i], operand_b[i]);
        end
    endgenerate

    // =====================================================
    // Adder/Subtractor (32-bit ripple-carry using full adders)
    // =====================================================
    // For subtraction, invert A and set carry_in = 1 (computing B - A instead of A - B)
    generate
        for (i = 0; i < 32; i = i + 1) begin : invert_b
            xor (b_inverted[i], operand_a[i], is_sub);
        end
    endgenerate

    assign b_input = b_inverted;

    // Instantiate 32 full adders
    logic [32:0] carry;
    assign carry[0] = is_sub;  // Carry in = 1 for subtraction (2's complement)

    generate
        for (i = 0; i < 32; i = i + 1) begin : full_adders
            full_adder fa (
                .a(operand_b[i]),
                .b(b_input[i]),
                .cin(carry[i]),
                .sum(add_sub_result[i]),
                .cout(carry[i+1])
            );
        end
    endgenerate

    assign add_sub_carry_out = carry[32];

    // =====================================================
    // Comparisons (using adder result)
    // =====================================================
    // For signed comparison: check overflow and sign
    logic overflow, sign_result;
    xor (overflow, carry[31], carry[32]);  // Overflow = carry into MSB XOR carry out of MSB
    assign sign_result = add_sub_result[31];

    // Signed less than: (A < B) if sign differs from overflow
    xor (less_than_signed, sign_result, overflow);

    // Unsigned less than: (A < B) if no carry out (borrow occurred)
    not (less_than_unsigned, add_sub_carry_out);

    // =====================================================
    // Barrel Shifter for SLL, SRL, SRA
    // =====================================================
    barrel_shifter_left bsl (
        .data_in(operand_b),
        .shift_amt(operand_a[4:0]),
        .data_out(sll_result)
    );

    barrel_shifter_right bsr_logical (
        .data_in(operand_b),
        .shift_amt(operand_a[4:0]),
        .arithmetic(1'b0),
        .data_out(srl_result)
    );

    barrel_shifter_right bsr_arithmetic (
        .data_in(operand_b),
        .shift_amt(operand_a[4:0]),
        .arithmetic(1'b1),
        .data_out(sra_result)
    );

    // =====================================================
    // Result Multiplexer (10-input mux using gate logic)
    // =====================================================
    logic [31:0] mux_out;
    
    generate
        for (i = 0; i < 32; i = i + 1) begin : result_mux
            mux_10to1 result_mux_inst (
                .in0(add_sub_result[i]),        // ADD
                .in1(add_sub_result[i]),        // SUB
                .in2(and_result[i]),            // AND
                .in3(or_result[i]),             // OR
                .in4(xor_result[i]),            // XOR
                .in5((i == 0) ? less_than_signed : 1'b0),     // SLT
                .in6((i == 0) ? less_than_unsigned : 1'b0),   // SLTU
                .in7(sll_result[i]),            // SLL
                .in8(srl_result[i]),            // SRL
                .in9(sra_result[i]),            // SRA
                .sel(alu_op),
                .out(mux_out[i])
            );
        end
    endgenerate

    assign result = mux_out;

    // =====================================================
    // Zero Flag (NOR of all result bits)
    // =====================================================
    logic [31:0] or_tree;
    assign or_tree[0] = result[0];
    
    generate
        for (i = 1; i < 32; i = i + 1) begin : zero_detect
            or (or_tree[i], or_tree[i-1], result[i]);
        end
    endgenerate
    
    not (zero, or_tree[31]);

endmodule

// =====================================================
// Full Adder Module
// =====================================================
module full_adder (
    input  logic a,
    input  logic b,
    input  logic cin,
    output logic sum,
    output logic cout
);
    logic ab_xor, ab_and, cin_and;
    
    xor (ab_xor, a, b);
    xor (sum, ab_xor, cin);
    
    and (ab_and, a, b);
    and (cin_and, ab_xor, cin);
    or  (cout, ab_and, cin_and);

endmodule

// =====================================================
// Barrel Shifter Left
// =====================================================
module barrel_shifter_left (
    input  logic [31:0] data_in,
    input  logic [4:0]  shift_amt,
    output logic [31:0] data_out
);
    logic [31:0] stage0, stage1, stage2, stage3, stage4;

    // Stage 0: shift by 0 or 1
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : stage0_gen
            mux_2to1 mux_s0 (
                .in0(data_in[i]),
                .in1((i >= 1) ? data_in[i-1] : 1'b0),
                .sel(shift_amt[0]),
                .out(stage0[i])
            );
        end
    endgenerate

    // Stage 1: shift by 0 or 2
    generate
        for (i = 0; i < 32; i = i + 1) begin : stage1_gen
            mux_2to1 mux_s1 (
                .in0(stage0[i]),
                .in1((i >= 2) ? stage0[i-2] : 1'b0),
                .sel(shift_amt[1]),
                .out(stage1[i])
            );
        end
    endgenerate

    // Stage 2: shift by 0 or 4
    generate
        for (i = 0; i < 32; i = i + 1) begin : stage2_gen
            mux_2to1 mux_s2 (
                .in0(stage1[i]),
                .in1((i >= 4) ? stage1[i-4] : 1'b0),
                .sel(shift_amt[2]),
                .out(stage2[i])
            );
        end
    endgenerate

    // Stage 3: shift by 0 or 8
    generate
        for (i = 0; i < 32; i = i + 1) begin : stage3_gen
            mux_2to1 mux_s3 (
                .in0(stage2[i]),
                .in1((i >= 8) ? stage2[i-8] : 1'b0),
                .sel(shift_amt[3]),
                .out(stage3[i])
            );
        end
    endgenerate

    // Stage 4: shift by 0 or 16
    generate
        for (i = 0; i < 32; i = i + 1) begin : stage4_gen
            mux_2to1 mux_s4 (
                .in0(stage3[i]),
                .in1((i >= 16) ? stage3[i-16] : 1'b0),
                .sel(shift_amt[4]),
                .out(stage4[i])
            );
        end
    endgenerate

    assign data_out = stage4;

endmodule

// =====================================================
// Barrel Shifter Right
// =====================================================
module barrel_shifter_right (
    input  logic [31:0] data_in,
    input  logic [4:0]  shift_amt,
    input  logic        arithmetic,  // 1 for arithmetic, 0 for logical
    output logic [31:0] data_out
);
    logic [31:0] stage0, stage1, stage2, stage3, stage4;
    logic fill_bit;

    // Fill bit: sign bit for arithmetic shift, 0 for logical shift
    and (fill_bit, arithmetic, data_in[31]);

    // Stage 0: shift by 0 or 1
    genvar i;
    generate
        for (i = 0; i < 32; i = i + 1) begin : stage0_gen
            mux_2to1 mux_s0 (
                .in0(data_in[i]),
                .in1((i <= 30) ? data_in[i+1] : fill_bit),
                .sel(shift_amt[0]),
                .out(stage0[i])
            );
        end
    endgenerate

    // Stage 1: shift by 0 or 2
    generate
        for (i = 0; i < 32; i = i + 1) begin : stage1_gen
            mux_2to1 mux_s1 (
                .in0(stage0[i]),
                .in1((i <= 29) ? stage0[i+2] : fill_bit),
                .sel(shift_amt[1]),
                .out(stage1[i])
            );
        end
    endgenerate

    // Stage 2: shift by 0 or 4
    generate
        for (i = 0; i < 32; i = i + 1) begin : stage2_gen
            mux_2to1 mux_s2 (
                .in0(stage1[i]),
                .in1((i <= 27) ? stage1[i+4] : fill_bit),
                .sel(shift_amt[2]),
                .out(stage2[i])
            );
        end
    endgenerate

    // Stage 3: shift by 0 or 8
    generate
        for (i = 0; i < 32; i = i + 1) begin : stage3_gen
            mux_2to1 mux_s3 (
                .in0(stage2[i]),
                .in1((i <= 23) ? stage2[i+8] : fill_bit),
                .sel(shift_amt[3]),
                .out(stage3[i])
            );
        end
    endgenerate

    // Stage 4: shift by 0 or 16
    generate
        for (i = 0; i < 32; i = i + 1) begin : stage4_gen
            mux_2to1 mux_s4 (
                .in0(stage3[i]),
                .in1((i <= 15) ? stage3[i+16] : fill_bit),
                .sel(shift_amt[4]),
                .out(stage4[i])
            );
        end
    endgenerate

    assign data_out = stage4;

endmodule

// =====================================================
// 2-to-1 Multiplexer
// =====================================================
module mux_2to1 (
    input  logic in0,
    input  logic in1,
    input  logic sel,
    output logic out
);
    logic sel_n, and0, and1;
    
    not (sel_n, sel);
    and (and0, in0, sel_n);
    and (and1, in1, sel);
    or  (out, and0, and1);

endmodule

// =====================================================
// 10-to-1 Multiplexer (for ALU operation select)
// =====================================================
module mux_10to1 (
    input  logic in0, in1, in2, in3, in4,
    input  logic in5, in6, in7, in8, in9,
    input  logic [3:0] sel,
    output logic out
);
    logic [9:0] and_results;
    logic [9:0] sel_decode;

    // Decode selector to 10 outputs
    assign sel_decode[0] = (sel == 4'd0);
    assign sel_decode[1] = (sel == 4'd1);
    assign sel_decode[2] = (sel == 4'd2);
    assign sel_decode[3] = (sel == 4'd3);
    assign sel_decode[4] = (sel == 4'd4);
    assign sel_decode[5] = (sel == 4'd5);
    assign sel_decode[6] = (sel == 4'd6);
    assign sel_decode[7] = (sel == 4'd7);
    assign sel_decode[8] = (sel == 4'd8);
    assign sel_decode[9] = (sel == 4'd9);

    // AND each input with its select
    and (and_results[0], in0, sel_decode[0]);
    and (and_results[1], in1, sel_decode[1]);
    and (and_results[2], in2, sel_decode[2]);
    and (and_results[3], in3, sel_decode[3]);
    and (and_results[4], in4, sel_decode[4]);
    and (and_results[5], in5, sel_decode[5]);
    and (and_results[6], in6, sel_decode[6]);
    and (and_results[7], in7, sel_decode[7]);
    and (and_results[8], in8, sel_decode[8]);
    and (and_results[9], in9, sel_decode[9]);

    // OR all results together
    logic or0, or1, or2, or3, or4, or5, or6, or7;
    or (or0, and_results[0], and_results[1]);
    or (or1, and_results[2], and_results[3]);
    or (or2, and_results[4], and_results[5]);
    or (or3, and_results[6], and_results[7]);
    or (or4, and_results[8], and_results[9]);
    or (or5, or0, or1);
    or (or6, or2, or3);
    or (or7, or5, or6);
    or (out, or7, or4);

endmodule
