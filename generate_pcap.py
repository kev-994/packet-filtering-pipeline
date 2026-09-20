from scapy.all import Ether, IP, UDP, wrpcap

# 1. Benign Packet (Should pass through)
pkt1 = Ether(src="aa:aa:aa:aa:aa:aa", dst="bb:bb:bb:bb:bb:bb") / \
       IP(src="192.168.1.50", dst="10.0.0.1") / \
       UDP(sport=1234, dport=80) / \
       b"Hello Hardware!"

# 2. Malicious Packet (Matches rule_table[2] target)
pkt2 = Ether(src="aa:aa:aa:aa:aa:aa", dst="bb:bb:bb:bb:bb:bb") / \
       IP(src="192.168.1.100", dst="10.0.0.1") / \
       UDP(sport=1234, dport=80) / \
       b"Drop me!"

# 3. Write to file
wrpcap("sim/test_traffic.pcap", [pkt1, pkt2])
print("Successfully generated sim/test_traffic.pcap")