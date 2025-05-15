class fifo_cov extends uvm_subscriber#(fifo_tx);

`uvm_component_utils(fifo_cov)
function new(string name,uvm_component parent);
	super.new(name,parent);
endfunction

function void write(fifo_tx t);
endfunction
endclass
