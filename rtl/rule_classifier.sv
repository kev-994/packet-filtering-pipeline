module rule_classifier (
    input  logic clk,
    input  logic rst_n,

    // Upstream data
    input  logic [31:0] parsed_src_ip,
    input  logic [31:0] parsed_dst_ip,
    input  logic [15:0] parsed_src_port,
    input  logic [15:0] parsed_dst_port,

    // Upstream handshaking
    input  logic parsed_valid, // Parser has data
    output logic parsed_ready, // Ready to accept the data

    // Downstream ouputs
    output logic action_drop, // Packet matches malicious rule table
    output logic classify_valid // Classification result is ready
);

    always_comb begin
        parsed_ready = 1'b1;

        // Block any packet coming from the Source IP 192.168.1.100
        action_drop = parsed_valid && (parsed_src_ip == 32'hC0A80164);

        classify_valid = parsed_valid; // Pass valid signal down chain
    end

endmodule