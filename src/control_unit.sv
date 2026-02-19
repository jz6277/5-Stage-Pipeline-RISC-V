// RISC-V Control Unit
// Decodes RV32I instructions and generates control signals
// Supports all base integer instruction formats

module control_unit (
    input  logic [31:0] instruction,    // 32-bit instruction from IF stage
    
    // Main control signals
    output logic        reg_write,      // Register file write enable
    output logic        mem_read,       // Memory read enable
    output logic        mem_write,      // Memory write enable
    output logic        branch,         // Branch instruction
    output logic        jump,           // Jump instruction (JAL/JALR)
    output logic [3:0]  alu_op,         // ALU operation select
    output logic [1:0]  alu_src_a,      // ALU source A: 00=rs1, 01=PC, 10=0
    output logic [1:0]  alu_src_b,      // ALU source B: 00=rs2, 01=imm, 10=4
    output logic [2:0]  imm_src,        // Immediate format: I/S/B/U/J
    output logic [1:0]  result_src      // Result source: 00=ALU, 01=Mem, 10=PC+4
);

    // Instruction fields
    logic [6:0] opcode;
    logic [2:0] funct3;
    logic [6:0] funct7;
    
    assign opcode = instruction[6:0];
    assign funct3 = instruction[14:12];
    assign funct7 = instruction[31:25];

    // Opcode definitions (RISC-V RV32I)
    localparam logic [6:0] OP_LUI    = 7'b0110111;  // Load Upper Immediate
    localparam logic [6:0] OP_AUIPC  = 7'b0010111;  // Add Upper Immediate to PC
    localparam logic [6:0] OP_JAL    = 7'b1101111;  // Jump and Link
    localparam logic [6:0] OP_JALR   = 7'b1100111;  // Jump and Link Register
    localparam logic [6:0] OP_BRANCH = 7'b1100011;  // Branch operations
    localparam logic [6:0] OP_LOAD   = 7'b0000011;  // Load operations
    localparam logic [6:0] OP_STORE  = 7'b0100011;  // Store operations
    localparam logic [6:0] OP_IMM    = 7'b0010011;  // Immediate ALU operations
    localparam logic [6:0] OP_REG    = 7'b0110011;  // Register ALU operations

    // ALU operation codes (matches riscv_alu.sv)
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
    localparam logic [2:0] IMM_I = 3'b000;  // I-type
    localparam logic [2:0] IMM_S = 3'b001;  // S-type
    localparam logic [2:0] IMM_B = 3'b010;  // B-type
    localparam logic [2:0] IMM_U = 3'b011;  // U-type
    localparam logic [2:0] IMM_J = 3'b100;  // J-type

    // Main control decoder
    always_comb begin
        // Default values (NOP-like behavior)
        reg_write   = 1'b0;
        mem_read    = 1'b0;
        mem_write   = 1'b0;
        branch      = 1'b0;
        jump        = 1'b0;
        alu_op      = ALU_ADD;
        alu_src_a   = 2'b00;  // rs1
        alu_src_b   = 2'b00;  // rs2
        imm_src     = IMM_I;
        result_src  = 2'b00;  // ALU result

        case (opcode)
            // LUI: Load Upper Immediate
            // rd = imm << 12
            OP_LUI: begin
                reg_write   = 1'b1;
                alu_op      = ALU_ADD;
                alu_src_a   = 2'b10;  // 0
                alu_src_b   = 2'b01;  // immediate
                imm_src     = IMM_U;
                result_src  = 2'b00;  // ALU
            end

            // AUIPC: Add Upper Immediate to PC
            // rd = PC + (imm << 12)
            OP_AUIPC: begin
                reg_write   = 1'b1;
                alu_op      = ALU_ADD;
                alu_src_a   = 2'b01;  // PC
                alu_src_b   = 2'b01;  // immediate
                imm_src     = IMM_U;
                result_src  = 2'b00;  // ALU
            end

            // JAL: Jump and Link
            // rd = PC + 4; PC = PC + imm
            OP_JAL: begin
                reg_write   = 1'b1;
                jump        = 1'b1;
                alu_op      = ALU_ADD;
                alu_src_a   = 2'b01;  // PC
                alu_src_b   = 2'b01;  // immediate
                imm_src     = IMM_J;
                result_src  = 2'b10;  // PC+4
            end

            // JALR: Jump and Link Register
            // rd = PC + 4; PC = (rs1 + imm) & ~1
            OP_JALR: begin
                reg_write   = 1'b1;
                jump        = 1'b1;
                alu_op      = ALU_ADD;
                alu_src_a   = 2'b00;  // rs1
                alu_src_b   = 2'b01;  // immediate
                imm_src     = IMM_I;
                result_src  = 2'b10;  // PC+4
            end

            // BRANCH: BEQ, BNE, BLT, BGE, BLTU, BGEU
            // if (condition) PC = PC + imm
            OP_BRANCH: begin
                branch      = 1'b1;
                alu_op      = ALU_SUB;  // Use ALU for comparison
                alu_src_a   = 2'b00;  // rs1
                alu_src_b   = 2'b00;  // rs2
                imm_src     = IMM_B;
            end

            // LOAD: LB, LH, LW, LBU, LHU
            // rd = mem[rs1 + imm]
            OP_LOAD: begin
                reg_write   = 1'b1;
                mem_read    = 1'b1;
                alu_op      = ALU_ADD;
                alu_src_a   = 2'b00;  // rs1
                alu_src_b   = 2'b01;  // immediate
                imm_src     = IMM_I;
                result_src  = 2'b01;  // Memory
            end

            // STORE: SB, SH, SW
            // mem[rs1 + imm] = rs2
            OP_STORE: begin
                mem_write   = 1'b1;
                alu_op      = ALU_ADD;
                alu_src_a   = 2'b00;  // rs1
                alu_src_b   = 2'b01;  // immediate
                imm_src     = IMM_S;
            end

            // Immediate ALU operations
            OP_IMM: begin
                reg_write   = 1'b1;
                alu_src_a   = 2'b00;  // rs1
                alu_src_b   = 2'b01;  // immediate
                imm_src     = IMM_I;
                result_src  = 2'b00;  // ALU

                case (funct3)
                    3'b000: alu_op = ALU_ADD;   // ADDI
                    3'b010: alu_op = ALU_SLT;   // SLTI
                    3'b011: alu_op = ALU_SLTU;  // SLTIU
                    3'b100: alu_op = ALU_XOR;   // XORI
                    3'b110: alu_op = ALU_OR;    // ORI
                    3'b111: alu_op = ALU_AND;   // ANDI
                    3'b001: alu_op = ALU_SLL;   // SLLI
                    3'b101: begin
                        if (funct7[5]) alu_op = ALU_SRA;  // SRAI
                        else           alu_op = ALU_SRL;  // SRLI
                    end
                    default: alu_op = ALU_ADD;
                endcase
            end

            // Register ALU operations
            OP_REG: begin
                reg_write   = 1'b1;
                alu_src_a   = 2'b00;  // rs1
                alu_src_b   = 2'b00;  // rs2
                result_src  = 2'b00;  // ALU

                case (funct3)
                    3'b000: begin
                        if (funct7[5]) alu_op = ALU_SUB;  // SUB
                        else           alu_op = ALU_ADD;  // ADD
                    end
                    3'b001: alu_op = ALU_SLL;   // SLL
                    3'b010: alu_op = ALU_SLT;   // SLT
                    3'b011: alu_op = ALU_SLTU;  // SLTU
                    3'b100: alu_op = ALU_XOR;   // XOR
                    3'b101: begin
                        if (funct7[5]) alu_op = ALU_SRA;  // SRA
                        else           alu_op = ALU_SRL;  // SRL
                    end
                    3'b110: alu_op = ALU_OR;    // OR
                    3'b111: alu_op = ALU_AND;   // AND
                    default: alu_op = ALU_ADD;
                endcase
            end

            default: begin
                // Invalid opcode - all control signals remain at default (NOP)
            end
        endcase
    end

endmodule
