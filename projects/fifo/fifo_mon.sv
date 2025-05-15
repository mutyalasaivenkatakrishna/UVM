class fifo_mon extends uvm_monitor;

`uvm_component_utils(fifo_mon)
function new(string name,uvm_component parent);
	super.new(name,parent);
endfunction
endclass
