module pipeline_top (
    // System
    input  logic clk,
    input  logic rst_n,

    // AXI4-Stream Ingress
    input  logic [7:0] s_axis_tdata,
    input  logic       s_axis_tvalid,
    input  logic       s_axis_tlast,
    output logic       s_axis_tready,

    // Classification Egress
    output logic action_drop,
    output logic classify_valid,

    // Performance counters
    output logic [63:0] cycle_count,
    output logic [31:0] packet_count

);

    // Internal wires
    logic [31:0] parsed_src_ip, parsed_dst_ip;
    logic [15:0] parsed_src_port, parsed_dst_port;
    logic parsed_ready, parsed_valid;

    // Instantiate modules
    packet_parser pp (
        .clk(clk),
        .rst_n(rst_n),
        
        .s_axis_tdata(s_axis_tdata),
        .s_axis_tvalid(s_axis_tvalid),
        .s_axis_tlast(s_axis_tlast),
        .s_axis_tready(s_axis_tready),
        
        .parsed_src_ip(parsed_src_ip),
        .parsed_dst_ip(parsed_dst_ip),
        .parsed_src_port(parsed_src_port),
        .parsed_dst_port(parsed_dst_port),

        .parsed_ready(parsed_ready),
        .parsed_valid(parsed_valid)
    );

    rule_classifier rc (
        .clk(clk),
        .rst_n(rst_n),

        .parsed_src_ip(parsed_src_ip),
        .parsed_dst_ip(parsed_dst_ip),
        .parsed_src_port(parsed_src_port),
        .parsed_dst_port(parsed_dst_port),

        .parsed_ready(parsed_ready),
        .parsed_valid(parsed_valid),

        .action_drop(action_drop),
        .classify_valid(classify_valid)
    );

    always_ff @(posedge clk) begin
        if (!rst_n) begin
            cycle_count  <= 64'b0;
            packet_count <= 32'b0;
        end else begin
            cycle_count <= cycle_count + 64'd1;
            
            if (classify_valid) begin
                packet_count <= packet_count + 32'd1;
            end
        end
    end
    

endmodule