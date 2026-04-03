module uart_tx #(
    parameter int unsigned CLKS_PER_BIT = 868
) (
    input  logic       clock,
    input  logic       reset,
    input  logic [7:0] tx_data,
    input  logic       tx_valid,
    output logic       tx_busy,
    output logic       tx
);

    localparam int unsigned COUNTER_WIDTH = (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);

    logic [COUNTER_WIDTH-1:0] clk_count;
    logic [3:0] bit_index;
    logic [9:0] shift_reg;

    always_ff @(posedge clock) begin
        if (reset) begin
            clk_count <= '0;
            bit_index <= '0;
            shift_reg <= 10'h3FF;
            tx_busy   <= 1'b0;
            tx        <= 1'b1;
        end else if (!tx_busy) begin
            clk_count <= '0;
            bit_index <= '0;
            tx        <= 1'b1;

            if (tx_valid) begin
                shift_reg <= {1'b1, tx_data, 1'b0};
                tx_busy   <= 1'b1;
                tx        <= 1'b0;
            end
        end else if (clk_count == CLKS_PER_BIT - 1) begin
            clk_count <= '0;

            if (bit_index == 4'd9) begin
                tx_busy <= 1'b0;
                tx      <= 1'b1;
            end else begin
                bit_index <= bit_index + 4'd1;
                shift_reg <= {1'b1, shift_reg[9:1]};
                tx        <= shift_reg[1];
            end
        end else begin
            clk_count <= clk_count + 1'b1;
        end
    end

endmodule
