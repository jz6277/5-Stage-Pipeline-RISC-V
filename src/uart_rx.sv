module uart_rx #(
    parameter int unsigned CLKS_PER_BIT = 868
) (
    input  logic       clock,
    input  logic       reset,
    input  logic       rx,
    output logic [7:0] rx_data,
    output logic       rx_valid
);

    localparam int unsigned COUNTER_WIDTH = (CLKS_PER_BIT <= 1) ? 1 : $clog2(CLKS_PER_BIT);

    typedef enum logic [1:0] {
        RX_IDLE,
        RX_START,
        RX_DATA,
        RX_STOP
    } rx_state_t;

    rx_state_t state;
    logic rx_meta, rx_sync;
    logic [COUNTER_WIDTH-1:0] clk_count;
    logic [2:0] bit_index;
    logic [7:0] shift_reg;

    always_ff @(posedge clock) begin
        if (reset) begin
            rx_meta <= 1'b1;
            rx_sync <= 1'b1;
        end else begin
            rx_meta <= rx;
            rx_sync <= rx_meta;
        end
    end

    always_ff @(posedge clock) begin
        if (reset) begin
            state     <= RX_IDLE;
            rx_data   <= 8'h00;
            rx_valid  <= 1'b0;
            clk_count <= '0;
            bit_index <= 3'd0;
            shift_reg <= 8'h00;
        end else begin
            rx_valid <= 1'b0;

            case (state)
                RX_IDLE: begin
                    clk_count <= '0;
                    bit_index <= 3'd0;
                    if (!rx_sync)
                        state <= RX_START;
                end

                RX_START: begin
                    if (clk_count == ((CLKS_PER_BIT - 1) / 2)) begin
                        if (!rx_sync) begin
                            state     <= RX_DATA;
                            clk_count <= '0;
                        end else begin
                            state <= RX_IDLE;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                RX_DATA: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        clk_count <= '0;
                        shift_reg[bit_index] <= rx_sync;

                        if (bit_index == 3'd7)
                            state <= RX_STOP;
                        else
                            bit_index <= bit_index + 3'd1;
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                RX_STOP: begin
                    if (clk_count == CLKS_PER_BIT - 1) begin
                        state     <= RX_IDLE;
                        clk_count <= '0;

                        if (rx_sync) begin
                            rx_data  <= shift_reg;
                            rx_valid <= 1'b1;
                        end
                    end else begin
                        clk_count <= clk_count + 1'b1;
                    end
                end

                default: begin
                    state <= RX_IDLE;
                end
            endcase
        end
    end

endmodule
