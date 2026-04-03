// Basys3 board wrapper: 100 MHz input, UART program loader, divided CPU clock,
// state LEDs, and UART register dump once the program reaches a sentinel.

module basys3_riscv_top #(
    parameter int unsigned CLK_DIV_HALF = 2,     // CPU f = 100MHz/(2*CLK_DIV_HALF); use >= 2
    parameter int unsigned UART_BAUD    = 115200,
    parameter int unsigned DUMP_LAST_REG = 14,
    parameter string IMEM_INIT_FILE = "imem_program.hex"
) (
    input  logic        CLK100MHZ,
    input  logic        btnC,
    input  logic        RsRx,
    output logic [15:0] led,
    output logic        RsTx
);

    localparam int unsigned HALF = (CLK_DIV_HALF < 2) ? 2 : CLK_DIV_HALF;
    localparam int unsigned UART_CLKS_PER_BIT = 100_000_000 / UART_BAUD;
    localparam int unsigned LAST_REG = (DUMP_LAST_REG > 31) ? 31 : DUMP_LAST_REG;
    localparam logic [4:0] LAST_REG_IDX = LAST_REG;
    localparam int unsigned IMEM_ADDR_WIDTH = 12;
    localparam int unsigned IMEM_WORDS = 2**(IMEM_ADDR_WIDTH-2);

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

    function automatic logic [3:0] reg_idx_digits(input logic [4:0] reg_idx);
        reg_idx_digits = (reg_idx >= 5'd10) ? 4'd2 : 4'd1;
    endfunction

    function automatic logic [3:0] hex_digit_count(input logic [31:0] reg_value);
        // Always print the full 32-bit register value as 8 hex digits.
        hex_digit_count = 4'd8;
    endfunction

    function automatic logic [7:0] reg_idx_char(
        input logic [4:0] reg_idx,
        input logic [3:0] digit_idx
    );
        if (reg_idx >= 5'd10) begin
            if (digit_idx == 4'd0)
                reg_idx_char = 8'h30 + (reg_idx / 5'd10);
            else
                reg_idx_char = 8'h30 + (reg_idx % 5'd10);
        end else begin
            reg_idx_char = 8'h30 + reg_idx;
        end
    endfunction

    function automatic logic [3:0] hex_digit_at(
        input logic [31:0] reg_value,
        input logic [3:0]  digit_idx,
        input logic [3:0]  digit_count
    );
        int unsigned shift_amount;
        begin
            shift_amount = (digit_count - digit_idx - 4'd1) * 4;
            hex_digit_at = reg_value[shift_amount +: 4];
        end
    endfunction

    function automatic logic [4:0] dump_last_char_idx(
        input logic [4:0]  reg_idx,
        input logic [31:0] reg_value
    );
        dump_last_char_idx = 5'd7 + reg_idx_digits(reg_idx) + hex_digit_count(reg_value);
    endfunction

    function automatic logic [7:0] dump_char(
        input logic [4:0]  reg_idx,
        input logic [4:0]  char_idx,
        input logic [31:0] reg_value
    );
        logic [3:0] reg_digit_count;
        logic [3:0] value_digit_count;
        begin
            reg_digit_count = reg_idx_digits(reg_idx);
            value_digit_count = hex_digit_count(reg_value);

            if (char_idx == 5'd0)
                dump_char = "x";
            else if (char_idx <= reg_digit_count)
                dump_char = reg_idx_char(reg_idx, char_idx - 5'd1);
            else if (char_idx == (5'd1 + reg_digit_count))
                dump_char = " ";
            else if (char_idx == (5'd2 + reg_digit_count))
                dump_char = "=";
            else if (char_idx == (5'd3 + reg_digit_count))
                dump_char = " ";
            else if (char_idx == (5'd4 + reg_digit_count))
                dump_char = "0";
            else if (char_idx == (5'd5 + reg_digit_count))
                dump_char = "x";
            else if (char_idx < (5'd6 + reg_digit_count + value_digit_count))
                dump_char = hex_ascii(hex_digit_at(reg_value, char_idx - (5'd6 + reg_digit_count), value_digit_count));
            else if (char_idx == (5'd6 + reg_digit_count + value_digit_count))
                dump_char = 8'h0D;
            else
                dump_char = 8'h0A;
        end
    endfunction

    // Synchronize active-high reset (matches CPU / testbench)
    logic rst_r, rst_rr;
    always_ff @(posedge CLK100MHZ) begin
        rst_r  <= btnC;
        rst_rr <= rst_r;
    end

    logic sys_reset;
    logic cpu_reset;
    assign sys_reset = rst_rr;

    localparam int CW = $clog2(HALF);
    logic [CW-1:0] hcnt;
    logic cpu_clk;
    logic cpu_halt;
    logic cpu_debug_done;
    logic cpu_debug_done_meta, cpu_debug_done_sync;
    logic [32*32-1:0] cpu_debug_regs_flat;
    logic [11:0] cpu_instruction_addr;
    logic [31:0] cpu_instruction_data;
    logic [32*32-1:0] dump_regs_flat_snapshot;
    logic dump_snapshot_pending, dump_snapshot_valid;
    logic [7:0] rx_data;
    logic       rx_valid;
    logic       loader_done;
    logic       loader_receiving_count;
    logic [1:0] loader_count_byte_idx;
    logic [1:0] loader_word_byte_idx;
    logic [31:0] loader_count_shift;
    logic [31:0] loader_word_shift;
    logic [31:0] loader_total_words;
    logic [31:0] loader_words_received;
    logic        loader_write_pending;
    logic [IMEM_ADDR_WIDTH-1:0] loader_write_address;
    logic [31:0] loader_write_data;
    logic [IMEM_ADDR_WIDTH-1:0] imem_address;
    logic        imem_write_enable;
    logic [31:0] imem_write_data;

    assign cpu_reset = sys_reset || !loader_done;
    assign imem_address = loader_write_pending ? loader_write_address : cpu_instruction_addr;
    assign imem_write_enable = loader_write_pending;
    assign imem_write_data = loader_write_data;

    // Host loader protocol: send a 32-bit little-endian word count, then that
    // many 32-bit little-endian instruction words. A zero count starts the CPU
    // with the preinitialized image.
    always_ff @(posedge CLK100MHZ) begin
        if (sys_reset) begin
            loader_done            <= 1'b0;
            loader_receiving_count <= 1'b1;
            loader_count_byte_idx  <= 2'd0;
            loader_word_byte_idx   <= 2'd0;
            loader_count_shift     <= 32'h0;
            loader_word_shift      <= 32'h0;
            loader_total_words     <= 32'h0;
            loader_words_received  <= 32'h0;
            loader_write_pending   <= 1'b0;
            loader_write_address   <= '0;
            loader_write_data      <= 32'h0;
        end else begin
            loader_write_pending <= 1'b0;

            if (!loader_done && rx_valid) begin
                if (loader_receiving_count) begin
                    if (loader_count_byte_idx == 2'd3) begin
                        if ({rx_data, loader_count_shift[31:8]} == 32'd0) begin
                            loader_done <= 1'b1;
                        end else begin
                            loader_total_words <= ({rx_data, loader_count_shift[31:8]} > IMEM_WORDS)
                                ? IMEM_WORDS
                                : {rx_data, loader_count_shift[31:8]};
                            loader_receiving_count <= 1'b0;
                        end
                        loader_count_byte_idx <= 2'd0;
                        loader_count_shift    <= 32'h0;
                    end else begin
                        loader_count_byte_idx <= loader_count_byte_idx + 2'd1;
                        loader_count_shift    <= {rx_data, loader_count_shift[31:8]};
                    end
                end else if (loader_word_byte_idx == 2'd3) begin
                    loader_write_pending <= 1'b1;
                    loader_write_address <= {loader_words_received[IMEM_ADDR_WIDTH-3:0], 2'b00};
                    loader_write_data    <= {rx_data, loader_word_shift[31:8]};
                    loader_words_received <= loader_words_received + 32'd1;
                    loader_word_byte_idx <= 2'd0;
                    loader_word_shift    <= 32'h0;

                    if ((loader_words_received + 32'd1) >= loader_total_words)
                        loader_done <= 1'b1;
                end else begin
                    loader_word_byte_idx <= loader_word_byte_idx + 2'd1;
                    loader_word_shift    <= {rx_data, loader_word_shift[31:8]};
                end
            end
        end
    end

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
        else if (cpu_debug_done_sync)
            cpu_halt <= 1'b1;
    end

    always_ff @(posedge CLK100MHZ) begin
        if (cpu_reset) begin
            cpu_debug_done_meta <= 1'b0;
            cpu_debug_done_sync <= 1'b0;
        end else begin
            cpu_debug_done_meta <= cpu_debug_done;
            cpu_debug_done_sync <= cpu_debug_done_meta;
        end
    end

    always_ff @(posedge CLK100MHZ) begin
        if (cpu_reset) begin
            dump_regs_flat_snapshot <= '0;
            dump_snapshot_pending   <= 1'b0;
            dump_snapshot_valid     <= 1'b0;
        end else begin
            if (cpu_debug_done_sync && !cpu_halt && !dump_snapshot_valid)
                dump_snapshot_pending <= 1'b1;

            if (dump_snapshot_pending) begin
                dump_regs_flat_snapshot <= cpu_debug_regs_flat;
                dump_snapshot_pending   <= 1'b0;
                dump_snapshot_valid     <= 1'b1;
            end
        end
    end

    simple_memory #(
        .ADDR_WIDTH(IMEM_ADDR_WIDTH),
        .CLEAR_ON_RESET(0),
        .INIT_FILE(IMEM_INIT_FILE)
    ) imem (
        .clock(CLK100MHZ),
        .reset(sys_reset),
        .enable(1'b1),
        .write_enable(imem_write_enable),
        .byte_enable(4'b1111),
        .address(imem_address),
        .write_data(imem_write_data),
        .read_data(cpu_instruction_data)
    );

    riscv_cpu_top cpu (
        .clock(cpu_clk),
        .reset(cpu_reset),
        .instruction_data(cpu_instruction_data),
        .instruction_address(cpu_instruction_addr),
        .debug_done(cpu_debug_done),
        .debug_regs_flat(cpu_debug_regs_flat)
    );

    logic [7:0] tx_data;
    logic       tx_valid, tx_busy;
    logic       dump_active, dump_finished;
    logic       led_execute, led_output;
    logic [4:0] dump_reg_idx;
    logic [4:0] dump_char_idx;
    logic [31:0] dump_reg_value;
    logic       tx_byte_ready;

    assign dump_reg_value = get_debug_reg(dump_regs_flat_snapshot, dump_reg_idx);

    always_ff @(posedge CLK100MHZ) begin
        if (cpu_reset) begin
            tx_data       <= 8'h00;
            tx_valid      <= 1'b0;
            tx_byte_ready <= 1'b0;
            dump_active   <= 1'b0;
            dump_finished <= 1'b0;
            dump_reg_idx  <= 5'd0;
            dump_char_idx <= 5'd0;
        end else begin
            tx_valid <= 1'b0;

            if (!dump_active && !dump_finished && dump_snapshot_valid) begin
                tx_byte_ready <= 1'b0;
                dump_active   <= 1'b1;
                dump_reg_idx  <= 5'd0;
                dump_char_idx <= 5'd0;
            end else if (dump_active && !tx_busy) begin
                if (tx_byte_ready) begin
                    tx_valid      <= 1'b1;
                    tx_byte_ready <= 1'b0;
                end else if (dump_reg_value == 32'd0) begin
                    dump_char_idx <= 5'd0;
                    if (dump_reg_idx == LAST_REG_IDX) begin
                        dump_active   <= 1'b0;
                        dump_finished <= 1'b1;
                    end else begin
                        dump_reg_idx <= dump_reg_idx + 5'd1;
                    end
                end else begin
                    tx_data       <= dump_char(dump_reg_idx, dump_char_idx, dump_reg_value);
                    tx_byte_ready <= 1'b1;

                    if (dump_char_idx == dump_last_char_idx(dump_reg_idx, dump_reg_value)) begin
                        dump_char_idx <= 5'd0;
                        if (dump_reg_idx == LAST_REG_IDX) begin
                            dump_active   <= 1'b0;
                            dump_finished <= 1'b1;
                        end else begin
                            dump_reg_idx <= dump_reg_idx + 5'd1;
                        end
                    end else begin
                        dump_char_idx <= dump_char_idx + 5'd1;
                    end
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

    uart_rx #(
        .CLKS_PER_BIT(UART_CLKS_PER_BIT)
    ) prog_uart_rx (
        .clock(CLK100MHZ),
        .reset(sys_reset),
        .rx(RsRx),
        .rx_data(rx_data),
        .rx_valid(rx_valid)
    );

    assign led_execute = !cpu_reset && !cpu_halt;
    assign led_output  = dump_active;
    assign led = {14'd0, led_output, led_execute};

endmodule
