module rule_classifier #(
    parameter int RULE_DEPTH = 4
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

    // Hardware Memory Array
    logic [31:0] rule_table [RULE_DEPTH];

    // Pre-load rules for simulation (Synthesis tools will convert this to BRAM init)
    initial begin
        rule_table[0] = 32'h00000000;
        rule_table[1] = 32'hFFFFFFFF;
        rule_table[2] = 32'hC0A80164; // 192.168.1.100 (Malicious)
        rule_table[3] = 32'h0A000005; 
    end

    // FSM States
    typedef enum logic [1:0] {
        IDLE = 2'b00,
        SCAN = 2'b01
    } state_t;

    state_t state_reg, state_next;
    
    // Internal registers to hold state during SCAN
    logic [15:0] index_reg, index_next;
    logic [31:0] latched_ip_reg, latched_ip_next;
    
    // Registers for downstream outputs
    logic drop_reg, drop_next;
    logic valid_reg, valid_next;

    // Sequential update
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_reg      <= IDLE;
            index_reg      <= '0;
            latched_ip_reg <= '0;
            drop_reg       <= 1'b0;
            valid_reg      <= 1'b0;
        end else begin
            state_reg      <= state_next;
            index_reg      <= index_next;
            latched_ip_reg <= latched_ip_next;
            drop_reg       <= drop_next;
            valid_reg      <= valid_next;
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
                    state_next = SCAN;
                end
            end

            SCAN: begin
                if (latched_ip_reg == rule_table[index_reg[$clog2(RULE_DEPTH)-1:0]]) begin
                    drop_next  = 1;
                    valid_next = 1;
                    state_next = IDLE;
                end
                else begin
                    index_next = index_reg + 1'b1;
                    
                    if (index_reg == 16'(RULE_DEPTH - 1)) begin
                        valid_next = 1'b1;
                        state_next = IDLE;
                    end
                end
            end
            
            default: state_next = IDLE;
        endcase
    end

    // Output routing
    assign action_drop    = drop_reg;
    assign classify_valid = valid_reg;

endmodule