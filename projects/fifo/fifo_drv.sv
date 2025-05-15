class fifo_drv extends uvm_driver#(fifo_tx);

`uvm_component_utils(fifo_drv)
function new(string name,uvm_component parent);
	super.new(name,parent);
endfunction
endclass
