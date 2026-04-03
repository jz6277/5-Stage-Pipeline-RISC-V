module tb_basys3_uart_loader;
    localparam int unsigned TB_UART_BAUD = 1_000_000;
    localparam int unsigned CLKS_PER_BIT = 100_000_000 / TB_UART_BAUD;

    logic CLK100MHZ = 1'b0;
    logic btnC = 1'b1;
    logic RsRx = 1'b1;
    logic [15:0] led;
    logic RsTx;
    logic tx_seen;

    basys3_riscv_top #(
        .UART_BAUD(TB_UART_BAUD),
        .IMEM_INIT_FILE("")
    ) dut (
        .CLK100MHZ(CLK100MHZ),
        .btnC(btnC),
        .RsRx(RsRx),
        .led(led),
        .RsTx(RsTx)
    );

    always #5 CLK100MHZ = ~CLK100MHZ;

    always_ff @(posedge CLK100MHZ) begin
        if (btnC)
            tx_seen <= 1'b0;
        else if (dut.tx_valid)
            tx_seen <= 1'b1;
    end

    task automatic uart_send_byte(input logic [7:0] data);
        begin
            RsRx <= 1'b0;
            repeat (CLKS_PER_BIT) @(posedge CLK100MHZ);

            for (int i = 0; i < 8; i++) begin
                RsRx <= data[i];
                repeat (CLKS_PER_BIT) @(posedge CLK100MHZ);
            end

            RsRx <= 1'b1;
            repeat (CLKS_PER_BIT) @(posedge CLK100MHZ);
        end
    endtask

    initial begin
        repeat (8) @(posedge CLK100MHZ);
        btnC <= 1'b0;
        repeat (8) @(posedge CLK100MHZ);

        // Send word count = 2, then:
        //   0x00100093  addi x1, x0, 1
        //   0xFFFFFFFF  debug sentinel
        uart_send_byte(8'h02);
        uart_send_byte(8'h00);
        uart_send_byte(8'h00);
        uart_send_byte(8'h00);

        uart_send_byte(8'h93);
        uart_send_byte(8'h00);
        uart_send_byte(8'h10);
        uart_send_byte(8'h00);

        uart_send_byte(8'hFF);
        uart_send_byte(8'hFF);
        uart_send_byte(8'hFF);
        uart_send_byte(8'hFF);

        wait (dut.loader_done);
        repeat (4) @(posedge CLK100MHZ);

        if (dut.imem.memory[0] !== 8'h93 || dut.imem.memory[1] !== 8'h00 ||
            dut.imem.memory[2] !== 8'h10 || dut.imem.memory[3] !== 8'h00) begin
            $fatal(1, "Loader failed to write first instruction");
        end

        if (dut.imem.memory[4] !== 8'hFF || dut.imem.memory[5] !== 8'hFF ||
            dut.imem.memory[6] !== 8'hFF || dut.imem.memory[7] !== 8'hFF) begin
            $fatal(1, "Loader failed to write sentinel instruction");
        end

        wait (dut.cpu_halt);
        repeat (50) @(posedge CLK100MHZ);

        if (dut.cpu.regfile.registers[1] !== 32'd1)
            $fatal(1, "Loaded program did not execute correctly");

        if (!tx_seen)
            $fatal(1, "UART TX debug dump never started after execution");

        $display("UART loader test passed");
        $finish(0);
    end

    initial begin
        #5000000;
        $fatal(1, "Timeout");
    end
endmodule
