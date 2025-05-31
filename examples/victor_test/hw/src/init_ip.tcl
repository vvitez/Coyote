# Initialize vFPGA ILA with the correct configuration
# Important parameters that need to be set:
#   1. The number of probes 
#   2. Width of each probe, if different than 1
create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_perf_host
set_property -dict [list CONFIG.C_NUM_OF_PROBES {8} CONFIG.C_PROBE7_WIDTH {512} CONFIG.C_PROBE3_WIDTH {512} CONFIG.C_EN_STRG_QUAL {1} CONFIG.ALL_PROBE_SAME_MU_CNT {2}] [get_ips ila_perf_host]


create_ip -name ila -vendor xilinx.com -library ip -version 6.2 -module_name ila_metadata
set_property -dict [list CONFIG.C_NUM_OF_PROBES {8} CONFIG.C_PROBE2_WIDTH {31} CONFIG.C_PROBE3_WIDTH {32} CONFIG.C_PROBE4_WIDTH {32} CONFIG.C_PROBE5_WIDTH {16} CONFIG.C_EN_STRG_QUAL {1} CONFIG.ALL_PROBE_SAME_MU_CNT {2}] [get_ips ila_metadata]

#fifo for data, 128 bits wide
#16 is smallest value for fifo depth, and it will be imlemented in lutram but shouldn't be too much
create_ip -name axis_data_fifo -vendor xilinx.com -library ip -version 2.0 -module_name axs_data_fifo_dandelion
set_property -dict [list CONFIG.TDATA_NUM_BYTES {16} CONFIG.TID_WIDTH {0} CONFIG.FIFO_DEPTH {16} CONFIG.HAS_TKEEP {1} CONFIG.HAS_TLAST {1} CONFIG.Component_Name {axs_data_fifo_dandelion}] [get_ips axs_data_fifo_dandelion]
