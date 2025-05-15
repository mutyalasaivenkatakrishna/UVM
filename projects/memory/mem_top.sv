`include "uvm_pkg.sv"
import uvm_pkg::*;
`include "uvm_macros.svh"
`include "memory.v"
`include "mem_common.sv"
`include "mem_tx.sv"
`include "mem_seq_lib.sv"
`include "mem_drv.sv"
`include "mem_sqr.sv"
`include "mem_mon.sv"
`include "mem_cov.sv"
`include "mem_agent.sv"
`include "mem_sbd.sv"
`include "mem_env.sv"
`include "mem_intf.sv"
`include "mem_test.sv"
module top;
reg clk;
reg reset;

initial begin
	clk=0;
	forever #5 clk=~clk;
	
end

initial begin
reset=1;	
repeat (2) @(posedge clk);
	reset=0;
end

mem_intf pif(.clk(clk),.rst(reset)); 
memory dut(.clk_i(pif.clk),
	.rst_i(pif.rst),
	.addr_i(pif.address),
	.valid_i(pif.valid),
	.wdata_i(pif.wr_data),
	.wr_rd_en_i(pif.write_read_enable),
	.rdata_o(pif.rdata),
	.ready_o(pif.ready));

initial begin 
	uvm_resource_db#(virtual mem_intf)::set("GLOBAL","APB_VIF",pif,null);
	uvm_resource_db#(int)::set("GLOBAL","COUNT",mem_common::total_tx_count,null);
end

initial begin
	#650 $finish;
end

initial begin
	run_test("mem_base_test");//run the testcase -mem_test
end
endmodule
