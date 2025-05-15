class base_seq extends uvm_sequence#(fifo_tx);
`uvm_object_utils(base_seq);
function new(string name ="");
	super.new(name);
endfunction
endclass
