// Basys3 board wrapper: 100 MHz input, divided CPU clock, synchronized reset,
// LED heartbeat, and UART register dump once the program reaches a sentinel.

module basys3_riscv_top #(
    parameter int unsigned CLK_DIV_HALF = 2,     // CPU f = 100MHz/(2*CLK_DIV_HALF); use >= 2
    parameter int unsigned UART_BAUD    = 115200,
    parameter int unsigned DUMP_LAST_REG = 14
) (
    input  logic        CLK100MHZ,
    input  logic        btnC,
    output logic [15:0] led,
    output logic        RsTx
);

    localparam int unsigned HALF = (CLK_DIV_HALF < 2) ? 2 : CLK_DIV_HALF;
    localparam int unsigned UART_CLKS_PER_BIT = 100_000_000 / UART_BAUD;
    localparam int unsigned LAST_REG = (DUMP_LAST_REG > 31) ? 31 : DUMP_LAST_REG;
    localparam logic [4:0] LAST_REG_IDX = LAST_REG;

    function automatic logic [31:0] get_debug_reg(
        input logic [32*32-1:0] regs_flat,
        input logic [4:0]       reg_idx
    );
        get_debug_reg = regs_flat[reg_idx*32 +: 32];
    endfunction

    function automatic logic [7:0] hex_ascii(input logic [3:0] nibble);
        if (nibble < 4'd10)
            hex_ascii = 8'h30 + nibble;
        else
            hex_ascii = 8'h41 + (nibble - 4'd10);
    endfunction

    function automatic logic [7:0] dump_char(
        input logic [4:0]  reg_idx,
        input logic [3:0]  char_idx,
        input logic [31:0] reg_value
    );
        begin
            case (char_idx)
                4'd0:  dump_char = "x";
                4'd1:  dump_char = 8'h30 + (reg_idx / 5'd10);
                4'd2:  dump_char = 8'h30 + (reg_idx % 5'd10);
                4'd3:  dump_char = "=";
                4'd4:  dump_char = hex_ascii(reg_value[31:28]);
                4'd5:  dump_char = hex_ascii(reg_value[27:24]);
                4'd6:  dump_char = hex_ascii(reg_value[23:20]);
                4'd7:  dump_char = hex_ascii(reg_value[19:16]);
                4'd8:  dump_char = hex_ascii(reg_value[15:12]);
                4'd9:  dump_char = hex_ascii(reg_value[11:8]);
                4'd10: dump_char = hex_ascii(reg_value[7:4]);
                4'd11: dump_char = hex_ascii(reg_value[3:0]);
                4'd12: dump_char = 8'h0D;
                default: dump_char = 8'h0A;
            endcase
        end
    endfunction

    // Synchronize active-high reset (matches CPU / testbench)
    logic rst_r, rst_rr;
    always_ff @(posedge CLK100MHZ) begin
        rst_r  <= btnC;
        rst_rr <= rst_r;
    end

    logic cpu_reset;
    assign cpu_reset = rst_rr;

    localparam int CW = $clog2(HALF);
    logic [CW-1:0] hcnt;
    logic cpu_clk;
    logic cpu_halt;
    logic cpu_debug_done;
    logic [32*32-1:0] cpu_debug_regs_flat;

    always_ff @(posedge CLK100MHZ) begin
        if (cpu_reset) begin
            hcnt    <= '0;
            cpu_clk <= 1'b0;
        end else if (cpu_halt) begin
            hcnt    <= hcnt;
            cpu_clk <= cpu_clk;
        end else if (hcnt == HALF - 1) begin
            hcnt    <= '0;
            cpu_clk <= ~cpu_clk;
        end else begin
            hcnt <= hcnt + 1'b1;
        end
    end

    always_ff @(posedge CLK100MHZ) begin
        if (cpu_reset)
            cpu_halt <= 1'b0;
        else if (cpu_debug_done)
            cpu_halt <= 1'b1;
    end

    riscv_cpu_top cpu (
        .clock(cpu_clk),
        .reset(cpu_reset),
        .debug_done(cpu_debug_done),
        .debug_regs_flat(cpu_debug_regs_flat)
    );

    defparam cpu.imem.INIT_FILE = "imem_program.hex";

    logic [23:0] hb_ctr;
    always_ff @(posedge cpu_clk) begin
        if (cpu_reset)
            hb_ctr <= '0;
        else
            hb_ctr <= hb_ctr + 24'd1;
    end

    logic [7:0] tx_data;
    logic       tx_valid, tx_busy;
    logic       dump_active, dump_finished;
    logic [4:0] dump_reg_idx;
    logic [3:0] dump_char_idx;
    logic [31:0] dump_reg_value;

    assign dump_reg_value = get_debug_reg(cpu_debug_regs_flat, dump_reg_idx);

    always_ff @(posedge CLK100MHZ) begin
        if (cpu_reset) begin
            tx_data       <= 8'h00;
            tx_valid      <= 1'b0;
            dump_active   <= 1'b0;
            dump_finished <= 1'b0;
            dump_reg_idx  <= 5'd0;
            dump_char_idx <= 4'd0;
        end else begin
            tx_valid <= 1'b0;

            if (!dump_active && !dump_finished && cpu_halt) begin
                dump_active   <= 1'b1;
                dump_reg_idx  <= 5'd0;
                dump_char_idx <= 4'd0;
            end else if (dump_active && !tx_busy) begin
                tx_data  <= dump_char(dump_reg_idx, dump_char_idx, dump_reg_value);
                tx_valid <= 1'b1;

                if (dump_char_idx == 4'd13) begin
                    dump_char_idx <= 4'd0;
                    if (dump_reg_idx == LAST_REG_IDX) begin
                        dump_active   <= 1'b0;
                        dump_finished <= 1'b1;
                    end else begin
                        dump_reg_idx <= dump_reg_idx + 5'd1;
                    end
                end else begin
                    dump_char_idx <= dump_char_idx + 4'd1;
                end
            end
        end
    end

    uart_tx #(
        .CLKS_PER_BIT(UART_CLKS_PER_BIT)
    ) dbg_uart_tx (
        .clock(CLK100MHZ),
        .reset(cpu_reset),
        .tx_data(tx_data),
        .tx_valid(tx_valid),
        .tx_busy(tx_busy),
        .tx(RsTx)
    );

    assign led = cpu_halt
        ? {13'd0, dump_finished, dump_active, tx_busy}
        : {hb_ctr[23:16], hb_ctr[15:8]};

endmodule
