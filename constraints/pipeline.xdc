# Define a 250 MHz clock (4.0 ns period) with a 50% duty cycle
create_clock -period 4.000 -name clk -waveform {0.000 2.000} [get_ports clk]