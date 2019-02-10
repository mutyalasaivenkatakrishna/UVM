class i2c_slv_tx extends uvm_sequence_item;

    logic sda_so,sda_si,scl;
     
    `uvm_object_utils_begin(i2c_slv_tx)
        `uvm_field_int (sda_si,UVM_ALL_ON)
        `uvm_field_int (sda_so,UVM_ALL_ON)
        `uvm_field_int (scl,UVM_ALL_ON)
    `uvm_object_utils_end
    
    function new(string name ="i2c_slv_tx");
        super.new(name);
    endfunction

endclass
