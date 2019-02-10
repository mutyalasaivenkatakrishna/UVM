class i2c_cfg extends uvm_object;
`uvm_object_utils(i2c_cfg)

 bit [6:0] addr[$];
 

function new(string name = "i2c_env_cfg");
super.new(name);
endfunction

endclass
