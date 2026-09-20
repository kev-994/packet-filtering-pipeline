module rule_classifier #(
    parameter int RULE_DEPTH = 1024
)(
    input  logic clk,
    input  logic rst_n,

    // Upstream data
    input  logic [31:0] parsed_src_ip,
    input  logic [31:0] parsed_dst_ip,
    input  logic [15:0] parsed_src_port,
    input  logic [15:0] parsed_dst_port,

    // Upstream handshaking
    input  logic parsed_valid, 
    output logic parsed_ready, 

    // Downstream outputs
    output logic action_drop,  
    output logic classify_valid 
);
    localparam INDEX_BITS = $clog2(RULE_DEPTH);

    // Hardware Memory Array
    logic [32:0] rule_table [RULE_DEPTH]; // {1'b Valid, 32'b IP_Tag}

    // Pre-load rules for simulation (Synthesis tools will convert this to BRAM init)
    initial begin
        // Wipe memory
        for (int i = 0; i < RULE_DEPTH; i++) begin
            rule_table[i] = 33'h0; 
        end

        // Lower 10 bits as hash index
        
        // Rule 1: 192.168.1.100 (C0 A8 01 64) -> Lower 10 bits: 10'h164
        rule_table[10'h164] = {1'b1, 32'hC0A80164};
        
        // Rule 2: 10.0.0.5 (0A 00 00 05) -> Lower 10 bits: 10'h005
        rule_table[10'h005] = {1'b1, 32'h0A000005};
        
        // Rule 3: 255.255.255.255 (FF FF FF FF) -> Lower 10 bits: 10'h3FF
        rule_table[10'h3FF] = {1'b1, 32'hFFFFFFFF};
    end

    /*
    Enterprise hardware firewalls never scan memory sequentially.
    To maintain multi-gigabit line rates, they use hardware-specific architectures,
    TCAM, Hash tables in BRAM/SRAM, Pipelined Binary Search, Bloom Filters
    */

    // FSM States
    typedef enum logic {
        IDLE = 1'b0,
        CHECK = 1'b1
    } state_t;

    state_t state_reg, state_next;
    
    // Internal registers to hold state during SCAN
    logic [15:0] index_reg, index_next;
    logic [31:0] latched_ip_reg, latched_ip_next;

    logic [32:0] read_data_reg; // Holds BRAM output
    
    // Registers for downstream outputs
    logic drop_reg, drop_next;
    logic valid_reg, valid_next;

    // Sequential update & Synchronous BRAM Read
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_reg      <= IDLE;
            latched_ip_reg <= '0;
            drop_reg       <= 1'b0;
            valid_reg      <= 1'b0;
            read_data_reg  <= '0;
        end else begin
            state_reg      <= state_next;
            latched_ip_reg <= latched_ip_next;
            drop_reg       <= drop_next;
            valid_reg      <= valid_next;
            
            // Infer synchronous BRAM read when valid data arrives
            if (state_reg == IDLE && parsed_valid) begin
                read_data_reg <= rule_table[parsed_src_ip[INDEX_BITS-1:0]];
            end
        end
    end

    // Combinational logic for FSM
    always_comb begin
        // Default assignments
        state_next      = state_reg;
        index_next      = index_reg;
        latched_ip_next = latched_ip_reg;
        drop_next       = 1'b0; // Default to no drop
        valid_next      = 1'b0; // Default to not valid
        
        parsed_ready    = (state_reg == IDLE); 

        case (state_reg)
            IDLE: begin
                if (parsed_valid) begin
                    latched_ip_next = parsed_src_ip;
                    index_next = 16'b0;
                    state_next = CHECK;
                end
            end

            CHECK: begin
                // Verify both the Valid bit and the full IP Tag
                if (read_data_reg[32] == 1'b1 && read_data_reg[31:0] == latched_ip_reg) begin
                    drop_next = 1'b1;
                end
                
                valid_next = 1'b1;
                state_next = IDLE;
            end
            
            default: state_next = IDLE;
        endcase
    end

    // Output routing
    assign action_drop    = drop_reg;
    assign classify_valid = valid_reg;

endmodule