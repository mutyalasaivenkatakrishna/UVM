class mem_tx extends uvm_sequence_item;

rand bit write_read_enable;
rand bit [`SZ-1:0]address;
rand bit [`WIDTH-1:0]wr_data;
 bit [`WIDTH-1:0]rdata;
//factory registration of mem_tx
//anytime we create a component we have to register the component in factory
`uvm_object_utils_begin(mem_tx)
//registering address field also to the factory
//advantage: it can be used anywhere in the testbench.
	`uvm_field_int(address,UVM_ALL_ON|UVM_NOPACK)
	`uvm_field_int(wr_data,UVM_ALL_ON|UVM_NOPACK)
	`uvm_field_int(write_read_enable,UVM_ALL_ON|UVM_NOPACK)
	`uvm_object_utils_end
	`NEW_OBJ

	//These Variables can be accessed by using uvm_config_db and can be used to update the component behaviour.
	//uvm_default->uvm_all_on(all capitals) 
endclass
