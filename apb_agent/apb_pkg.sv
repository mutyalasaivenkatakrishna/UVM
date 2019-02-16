package apb_pkg;
    

	parameter ADDR_WIDTH=32;	      //address width
	parameter DATA_WIDTH=32;	      //data width
	parameter SLV_REG_DEPTH=16;	      //slave register memory depth
	localparam BYTES_PER_WORD= DATA_WIDTH/8;
	localparam TOTAL_BYTES=SLV_REG_DEPTH * BYTES_PER_WORD;

    import uvm_pkg::*;

    `include "uvm_macros.svh"
    `include "apb_common.sv"
    `include "apb_tx.sv"
    `include "apb_sequence.sv"    
    `include "apb_sqr.sv"
    `include "apb_driver.sv"
    `include "apb_monitor.sv"
    `include "apb_agent.sv"
   
endpackage
