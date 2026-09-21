from scapy.all import Ether, IP, UDP, wrpcap
import random

packets = []
malicious_ip = "192.168.1.100"
benign_ips = [f"10.0.1.{i}" for i in range(1, 20)]

print("Generating 1000 packets. Please wait...")

for i in range(1000):
    # 10% chance to inject a malicious packet
    if random.random() < 0.10:
        src_ip = malicious_ip
        payload = b"Malicious drop payload!"
    else:
        src_ip = random.choice(benign_ips)
        payload = b"Standard background web traffic..."
        
    pkt = Ether(src="aa:aa:aa:aa:aa:aa", dst="bb:bb:bb:bb:bb:bb") / \
          IP(src=src_ip, dst="192.168.1.1") / \
          UDP(sport=random.randint(1024, 65535), dport=80) / \
          payload
          
    packets.append(pkt)

wrpcap("sim/test_traffic.pcap", packets)
print(f"Successfully generated sim/test_traffic.pcap with {len(packets)} packets.")