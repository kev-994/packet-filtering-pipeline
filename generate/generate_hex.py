from scapy.all import rdpcap, raw

packets = rdpcap("sim/test_traffic.pcap")

with open("sim/packets.hex", "w") as f:
    for pkt in packets:
        # Extract the raw bytes of the actual Ethernet frame
        raw_bytes = bytearray(raw(pkt))
        
        # Pad to exactly 64 bytes (standard minimum Ethernet frame)
        if len(raw_bytes) < 64:
            raw_bytes.extend(b'\x00' * (64 - len(raw_bytes)))
            
        # Truncate anything longer than 64 bytes for simple simulation
        raw_bytes = raw_bytes[:64]
        
        # Write out as a 128-character hex string (512 bits)
        f.write(raw_bytes.hex() + "\n")