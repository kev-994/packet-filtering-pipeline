module packet_parser (
    input  logic       clk,
    input  logic       rst_n, // active low

    // AXI4-Stream Ingress (Input from network)
    input  logic [7:0] s_axis_tdata,
    input  logic       s_axis_tvalid,
    input  logic       s_axis_tlast,
    output logic       s_axis_tready,

    // Classification
    output logic [31:0] parsed_src_ip,
    output logic [31:0] parsed_dst_ip,
    output logic [15:0] parsed_src_port,
    output logic [15:0] parsed_dst_port,
    
    input  logic        parsed_ready,
    output logic        parsed_valid
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
    
    logic [15:0] byte_cnt_reg, byte_cnt_next, src_port_reg, src_port_next, dst_port_reg, dst_port_next;
    logic [31:0] src_ip_reg, src_ip_next, dst_ip_reg, dst_ip_next;


    // Sequential logic
    always_ff @(posedge clk) begin
        if (!rst_n) begin
            state_reg <= IDLE;
            byte_cnt_reg <= 16'b0;

            src_ip_reg <= 32'b0;
            dst_ip_reg <= 32'b0;

            src_port_reg <= 16'b0;
            dst_port_reg <= 16'b0;
        end
        
        else begin
            state_reg <= state_next;
            byte_cnt_reg <= byte_cnt_next;

            src_ip_reg <= src_ip_next;
            dst_ip_reg <= dst_ip_next;

            src_port_reg <= src_port_next;
            dst_port_reg <= dst_port_next;
        end
    end

    // FSM control loop, IP address extracting
    always_comb begin
    state_next = state_reg;
    byte_cnt_next = byte_cnt_reg;

    src_ip_next = src_ip_reg;
    dst_ip_next = dst_ip_reg;

    src_port_next = src_port_reg;
    dst_port_next = dst_port_reg;

    s_axis_tready = parsed_ready; // is downstream ready to take on more data?

    parsed_valid = 1'b0;

    if (s_axis_tvalid && s_axis_tready) begin // valid/ready handshake
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
                
                case (byte_cnt_reg)
                    // Source IP
                    16'd26: src_ip_next = {src_ip_reg[23:0], s_axis_tdata};
                    16'd27: src_ip_next = {src_ip_reg[23:0], s_axis_tdata};
                    16'd28: src_ip_next = {src_ip_reg[23:0], s_axis_tdata};
                    16'd29: src_ip_next = {src_ip_reg[23:0], s_axis_tdata};

                    // Destination IP
                    16'd30: dst_ip_next = {dst_ip_reg[23:0], s_axis_tdata};
                    16'd31: dst_ip_next = {dst_ip_reg[23:0], s_axis_tdata};
                    16'd32: dst_ip_next = {dst_ip_reg[23:0], s_axis_tdata};
                    16'd33: dst_ip_next = {dst_ip_reg[23:0], s_axis_tdata};

                    default:;
                endcase
            end
            
            PARSE_UDP: begin
                byte_cnt_next = byte_cnt_reg + 16'd1;

                if (s_axis_tlast) // If the network sends a tiny, broken packet that ends prematurely, abort
                    state_next = IDLE;

                else if (byte_cnt_reg == 41) begin // Done parsing
                    state_next = WAIT_EOF;
                    parsed_valid = 1'b1;
                end

                case (byte_cnt_reg)
                    // Source Port
                    16'd34: src_port_next = {src_port_reg[7:0], s_axis_tdata};
                    16'd35: src_port_next = {src_port_reg[7:0], s_axis_tdata};

                    // Destination Port
                    16'd36: dst_port_next = {dst_port_reg[7:0], s_axis_tdata};
                    16'd37: dst_port_next = {dst_port_reg[7:0], s_axis_tdata};

                    default:;
                endcase

            end
            
            WAIT_EOF: begin
                if (s_axis_tlast) // Packet is over
                    state_next = IDLE; 
            end

            default:;
        endcase
    end
    end

    // Outputs
    assign parsed_src_ip = src_ip_reg;
    assign parsed_dst_ip = dst_ip_reg;

    assign parsed_src_port = src_port_reg;
    assign parsed_dst_port = dst_port_reg;
endmodule