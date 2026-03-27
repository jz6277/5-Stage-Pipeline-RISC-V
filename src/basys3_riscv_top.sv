// Basys3 board wrapper: 100 MHz input, divided CPU clock, synchronized reset, LED heartbeat

module basys3_riscv_top #(
    parameter int unsigned CLK_DIV_HALF = 2  // CPU f = 100MHz/(2*CLK_DIV_HALF); use >= 2 (default 25 MHz)
) (
    input  logic        CLK100MHZ,
    input  logic        btnC,
    output logic [15:0] led
);

    // Synchronize active-high reset (matches CPU / testbench)
    logic rst_r, rst_rr;
    always_ff @(posedge CLK100MHZ) begin
        rst_r  <= btnC;
        rst_rr <= rst_r;
    end

    logic cpu_reset;
    assign cpu_reset = rst_rr;

    localparam int unsigned HALF = (CLK_DIV_HALF < 2) ? 2 : CLK_DIV_HALF;
    localparam int CW = $clog2(HALF);
    logic [CW-1:0] hcnt;
    logic cpu_clk;

    always_ff @(posedge CLK100MHZ) begin
        if (cpu_reset) begin
            hcnt    <= '0;
            cpu_clk <= 1'b0;
        end else if (hcnt == HALF - 1) begin
            hcnt    <= '0;
            cpu_clk <= ~cpu_clk;
        end else begin
            hcnt <= hcnt + 1'b1;
        end
    end

    riscv_cpu_top cpu (
        .clock(cpu_clk),
        .reset(cpu_reset)
    );

    defparam cpu.imem.INIT_FILE = "imem_program.hex";

    logic [23:0] hb_ctr;
    always_ff @(posedge cpu_clk) begin
        if (cpu_reset)
            hb_ctr <= '0;
        else
            hb_ctr <= hb_ctr + 24'd1;
    end

    assign led = {hb_ctr[23:16], hb_ctr[15:8]};

endmodule
