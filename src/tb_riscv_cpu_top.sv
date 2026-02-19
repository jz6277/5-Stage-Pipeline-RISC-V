// Debug Testbench - Shows what's happening each cycle
module tb_riscv_cpu_top;
    logic clock;
    logic reset;
    
    initial begin
        clock = 0;
        forever #5 clock = ~clock;
    end
    
    riscv_cpu_top cpu (.clock(clock), .reset(reset));
    
    // Load program immediately after reset, before clock
    initial begin
        @(negedge reset);  // Wait for reset to fall
        // Load IMMEDIATELY - no clock wait!
        cpu.imem.memory[0] = 8'h13;  
        cpu.imem.memory[1] = 8'h05;
        cpu.imem.memory[2] = 8'hA0;
        cpu.imem.memory[3] = 8'h00;
        cpu.regfile.registers[2] = 32'h1000;  // sp
        $display("Loaded: addi a0, x0, 10 at address 0");
    end
    
    // Monitor execution
    always @(posedge clock) begin
        if (!reset) begin
            $display("Cycle %0d: PC=0x%h, Instr=0x%h, a0=0x%h", 
                $time/10, cpu.pc_if, cpu.instruction_if, cpu.regfile.registers[10]);
        end
    end
    
    initial begin
        $display("=== RISC-V CPU Debug Test ===");
        reset = 1;
        repeat(5) @(posedge clock);
        reset = 0;
        $display("Reset released");
        
        repeat(15) @(posedge clock);
        
        $display("\nFinal a0 value: 0x%h (expected 0x0000000A)", cpu.regfile.registers[10]);
        
        if (cpu.regfile.registers[10] == 32'h0A)
            $display("TEST PASSED");
        else
            $display("TEST FAILED - a0 not updated");
            
        $finish(0);
    end
    
    initial begin
        #50000;
        $fatal(1, "Timeout");
    end
    
    initial begin
        $dumpfile("dumpfile.fst");
        $dumpvars(0);
    end

endmodule
