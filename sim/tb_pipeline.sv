// Used in Vivado
`timescale 1ns / 1ps

module tb_pipeline;

    // Simulation signals
    logic clk;
    logic rst_n;
    logic [7:0] s_axis_tdata;
    logic       s_axis_tvalid;
    logic       s_axis_tlast;
    
    logic        s_axis_tready;
    logic        action_drop;
    logic        classify_valid;
    logic [63:0] cycle_count;
    logic [31:0] packet_count;

    // Update memory array for 64 bytes (512 bits)
    logic [511:0] packet_mem [0:999]; 
    logic [511:0] current_packet;

    // Instantiate the pipeline
    pipeline_top uut (
        .clk(clk),
        .rst_n(rst_n),
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tready(s_axis_tready),
        .action_drop(action_drop),
        .classify_valid(classify_valid),
        .cycle_count(cycle_count),
        .packet_count(packet_count)
    );

    // Clock generation (250 MHz -> 4.0 ns period)
    initial begin
        clk = 0;
        forever #2.0 clk = ~clk; 
    end

    // Stimulus process
    initial begin
        // Initialize Inputs
        rst_n = 0;
        s_axis_tdata = 0;
        s_axis_tvalid = 0;
        s_axis_tlast = 0;

        // Load the parsed PCAP hex data
        $readmemh("sim/packets.hex", packet_mem);

        // Hold reset
        #100;
        rst_n = 1;
        #20;

        // Stream the packets into the AXI interface
        for (int i = 0; i < 1000; i++) begin
            if (packet_mem[i] !== 512'hx) begin
                
                current_packet = packet_mem[i];
                
                // Shift out the 64 bytes MSB-first
                for (int byte_idx = 63; byte_idx >= 0; byte_idx--) begin
                    
                    wait(s_axis_tready); 
                    
                    @(posedge clk);
                    s_axis_tvalid <= 1;
                    s_axis_tdata  <= current_packet[511:504]; // Take the top byte
                    current_packet = current_packet << 8;     // Shift next byte up
                    
                    // Assert tlast on the final byte (byte_idx == 0)
                    s_axis_tlast  <= (byte_idx == 0) ? 1'b1 : 1'b0;
                end
                
                // Pull signals low between packets
                @(posedge clk);
                s_axis_tvalid <= 0;
                s_axis_tlast  <= 0;
                
                #40;
            end
        end

        // Wait for final processing, then end simulation
        #200;
        $display("Simulation complete. Processed %0d packets.", packet_count);
        $finish;
    end

endmodule