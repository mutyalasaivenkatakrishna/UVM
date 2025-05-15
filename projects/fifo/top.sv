`include "uvm_pkg.sv"
import uvm_pkg::*;

`include "uvm_macros.svh"
`include "async_fifo.v"
`include "fifo_common.sv"
`include "fifo_tx.sv"
`include "fifo_seq_lib.sv"
`include "fifo_drv.sv"
`include "fifo_sqr.sv"
`include "fifo_mon.sv"
`include "fifo_cov.sv"
`include "fifo_agent.sv"
`include "fifo_sbd.sv"
`include "fifo_env.sv"
`include "fifo_intf.sv"
`include "fifo_test_lib.sv"
module top;
reg w_clk_i,r_clk_i,rst_i;
initial begin 
	w_clk_i=0;
	forever begin 
		#5 w_clk_i=~w_clk_i;
	end
end
initial begin 
	r_clk_i=0;
	forever begin 
		#7 r_clk_i=~r_clk_i;
	end
end

initial begin
reset=1;	
repeat (2) @(posedge clk);
	reset=0;
end

fifo_intf pif (w_clk_i,r_clk_i,rst_i);
fifo dut(pif.w_clk_i,pif.r_clk_i,pif.rst_i,pif.wr_enable_i,pif.rd_enable_i,pif.wr_data_i,pif.rd_data_o,pif.empty_o,pif.full_o,pif.error_o);
initial begin
	uvm_config_db#(virtual fifo_intf)::set("GLOBAL","FIFO_VIF",pif,null);
end
initial begin
	run_test("base_test");
end
endmodule

