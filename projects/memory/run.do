vlog mem_top.sv \
+incdir+C:/Users/SAI\ VENKATA\ KRISHNA/Downloads/uvm-1.2_RC8/uvm-1.2/src

vsim top -novopt \
-suppress 12110 \
+UVM_TESTNAME=mem_wr_rd_build_phase_test \
-sv_lib C:/questasim64_10.7c/uvm-1.2/win64/uvm_dpi \
+UVM_OBJECTION_TRACE
add wave -position insertpoint sim:/top/dut/*
run -all

