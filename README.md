# Hardware-Accelerated Packet Filtering Pipeline

A SystemVerilog pipeline that parses Ethernet/IPv4/UDP headers at line rate from an AXI4-Stream interface and filters traffic against a configurable rule table — verified via Verilator co-simulation against real PCAP traffic and closed timing at 250 MHz on Xilinx Vivado.

This is a hardware packet classification pipeline in the same class of problem solved by SmartNICs, hardware firewalls, and line-rate classifiers — not a security product. The engineering focus is on streaming header parsing, AXI4-Stream backpressure, and hardware/software partitioning.

## Architecture

```
AXI4-Stream Ingress ──▶ Byte-serial FSM Parser ──▶ Rule Classifier ──▶ Forward / Drop
   (s_axis_t*)         (Ethernet/IPv4/UDP)      (O(1) tagged BRAM       + performance
                        extracts src/dst IP,      lookup, blocklist)      counters
                        src/dst port
```

| Stage | Module | What it does |
|---|---|---|
| Ingress | `packet_parser.sv` | AXI4-Stream slave interface; 1 byte/cycle |
| Parse | `packet_parser.sv` | FSM extracts EtherType, Protocol, src/dst IP, src/dst UDP port |
| Classify | `rule_classifier.sv` | Direct-mapped, tagged BRAM lookup against a 1024-entry rule table |
| Integrate | `pipeline_top.sv` | Wires parser → classifier; hosts cycle/packet counters |

## Results

| Metric | V1 (sequential scan) | V2 (tagged direct-mapped BRAM) |
|---|---|---|
| Avg. latency | 1013.9 cycles/packet | 90.9 cycles/packet |
| Sustained throughput | 0.15 Gbps | 1.65 Gbps |

Synthesized on an Artix-7 (`xc7a200tfbg676-2`) at a 250 MHz clock constraint:

- **Timing:** WNS +0.447 ns, 0 failing endpoints
- **Utilization:** 77 LUTs, 196 FFs

The V1→V2 change replaced an O(n) linear rule-table scan with an O(1) lookup: the low bits of the source IP address a BRAM directly, and the full 32-bit IP is stored and compared as a tag to prevent aliasing between IPs that share the same low-order bits.

## Repository structure

```
constraints/   pipeline.xdc          — 250 MHz clock constraint for Vivado synthesis
generate/      generate_pcap.py      — synthetic PCAP traffic generator (Scapy)
               generate_hex.py       — converts PCAP → $readmemh-compatible hex for Vivado sim
rtl/           packet_parser.sv      — AXI4-Stream ingress + header extraction FSM
               rule_classifier.sv    — tagged direct-mapped BRAM rule lookup
               pipeline_top.sv       — top-level integration + performance counters
sim/           tb_pipeline.cpp       — Verilator C++ testbench (PCAP replay, self-checking)
               tb_pipeline.sv        — Vivado behavioral SV testbench (hex-driven)
```

## Running the simulation

**Verilator (C++ co-simulation against real PCAP traffic):**
```bash
python3 generate/generate_pcap.py          # produces sim/test_traffic.pcap
verilator --cc rtl/packet_parser.sv rtl/rule_classifier.sv rtl/pipeline_top.sv \
          --top-module pipeline_top --exe sim/tb_pipeline.cpp --build --trace
./obj_dir/Vpipeline_top
```
Outputs pass/drop decisions checked automatically against a software reference model, plus hardware-measured latency and throughput. Waveforms are written to `sim/waveform.vcd` (view with GTKWave).

**Vivado (behavioral simulation, synthesizable flow):**
1. Add `rtl/*.sv` and `sim/tb_pipeline.sv` as sources (mark `tb_pipeline.sv` as a simulation source, type SystemVerilog).
2. Run `python3 generate/generate_hex.py` to produce `packets.hex` and copy it alongside the simulation working directory.
3. Add `constraints/pipeline.xdc`, run synthesis, then run behavioral simulation.

## Verification approach

Two independent testbenches, each matched to its simulator's semantics:

- **Verilator** — cycle-based; drives the DUT directly from C++, replays real PCAP-captured traffic byte-by-byte, and self-checks every classification decision against a software reference model via `assert()`.
- **Vivado XSim** — event-driven; a SystemVerilog testbench loads packets from a `$readmemh` hex file and drives stimulus with non-blocking assignments to avoid same-edge race conditions between testbench and DUT.

## Known limitations

- Assumes a fixed 20-byte IPv4 header (does not parse the IHL field for options).
- Rule table is loaded once at elaboration time; no runtime write interface from a host CPU yet.
- Direct-mapped classifier rejects false-positive aliasing via a tag check, but does not handle genuine index collisions between two distinct wanted rules.
- Single processing lane; no packet modification or multi-lane arbitration.