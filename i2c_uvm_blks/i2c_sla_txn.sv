class i2c_sla_txn extends uvm_sequence_item;




`uvm_object_utils_begin(i2c_sla_txn)
`uvm_field_int(newd,UVM_ALL_ON)
`uvm_field_int(addr,UVM_ALL_ON)
`uvm_field_int(op,UVM_ALL_ON)
`uvm_field_int(din,UVM_ALL_ON)
`uvm_field_int(done,UVM_ALL_ON)
`uvm_field_int(sda,UVM_ALL_ON)
`uvm_field_int(scl,UVM_ALL_ON)
`uvm_field_int(dout,UVM_ALL_ON)
`uvm_field_int(ack_err,UVM_ALL_ON)
`uvm_field_int(busy,UVM_ALL_ON)
`uvm_object_utils_end


function new (string name = "i2c_sla_txn");
super.new(name);
endfunction



endclass
