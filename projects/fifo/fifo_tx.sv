

class fifo_tx extends uvm_sequence_item;

rand bit [`WIDTH-1:0]wr_data_i;
rand bit rd_enable_i;
rand bit wr_enable_i;

`uvm_object_utils_begin(fifo_tx)
	`uvm_field_int(wr_data_i,UVM_ALL_ON);
	`uvm_field_int(rd_enable_i,UVM_ALL_ON);
	`uvm_field_int(wr_enable_i,UVM_ALL_ON);
`uvm_object_utils_end

function  new(string  name="");
	super.new(name);
endfunction

endclass
