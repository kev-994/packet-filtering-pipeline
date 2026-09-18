module packet_parser (
    input  logic       clk,
    input  logic       rst_n, // active low

    // AXI4-Stream Ingress (Input from network)
    input  logic [7:0] s_axis_tdata,
    input  logic       s_axis_tvalid,
    input  logic       s_axis_tlast,
    output logic       s_axis_tready
);

    // FSM States
    typedef enum logic [2:0] {
        IDLE       = 3'b000,
        PARSE_ETH  = 3'b001,
        PARSE_IPV4 = 3'b010,
        PARSE_UDP  = 3'b011,
        WAIT_EOF   = 3'b100
    } state_t;

    state_t state_reg, state_next;
    
    logic [15:0] byte_cnt_reg, byte_cnt_next;


    // Sequential logic
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_reg <= IDLE;
            byte_cnt_reg <= 16'b0;
        end
        else begin
            state_reg <= state_next;
            byte_cnt_reg <= byte_cnt_next;
        end
    end

    // Combinational logic
    always_comb begin
    state_next = state_reg;
    byte_cnt_next = byte_cnt_reg;

    s_axis_tready = 1'b1;

    if (s_axis_tvalid) begin
        case (state_reg) 
            IDLE: begin 
                state_next = PARSE_ETH;
                byte_cnt_next = 16'd1;
            end
            
            PARSE_ETH: begin // Only care abouto the EtherType bytes
                byte_cnt_next = byte_cnt_reg + 16'd1;
                
                if (s_axis_tlast) // If the network sends a tiny, broken packet that ends prematurely, abort
                    state_next = IDLE;

                else if (byte_cnt_reg == 12 && s_axis_tdata != 8'h08) // Not an IPv4 packet
                    state_next = WAIT_EOF;
                
                else if (byte_cnt_reg == 13 && s_axis_tdata == 8'h00)  // Valid IPv4 packet
                    state_next = PARSE_IPV4;
                
                else if (byte_cnt_reg == 13 && s_axis_tdata != 8'h00)
                    state_next = WAIT_EOF;
            end
            
            PARSE_IPV4: begin
                byte_cnt_next = byte_cnt_reg + 16'd1;

                if (s_axis_tlast) // If the network sends a tiny, broken packet that ends prematurely, abort
                    state_next = IDLE;

                else if (byte_cnt_reg == 23 && s_axis_tdata != 8'h11) // TCP or ICMP packet
                    state_next = WAIT_EOF;

                else if (byte_cnt_reg == 33) // Standard IPv4 header ends at byte 33
                    state_next = PARSE_UDP;
            end
            
            PARSE_UDP: begin
                byte_cnt_next = byte_cnt_reg + 16'd1;

                if (s_axis_tlast) // If the network sends a tiny, broken packet that ends prematurely, abort
                    state_next = IDLE;

                else if (byte_cnt_reg == 41) // Done parsing
                    state_next = WAIT_EOF;
            end
            
            WAIT_EOF: begin
                if (s_axis_tlast) // Packet is over
                    state_next = IDLE; 
            end
        endcase
    end
    end

endmodule