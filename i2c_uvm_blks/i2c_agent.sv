class i2c_agent extends uvm_agent;
`uvm_component_utils(i2c_agent)

i2c_sequencer seqrh;
i2c_driver drvh;
i2c_monitor monh;

function new(string name = "i2c_agent",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);
seqrh = i2c_sequencer::type_id::create("seqrh",this);
drvh = i2c_driver::type_id::create("drvh",this);
monh = i2c_monitor::type_id::create("monh",this);

`uvm_info(get_type_name(),$sformatf($time,"build_phase = %t -i2c_agent"),UVM_LOW)
endfunction

function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
drvh.seq_item_port.connect(seqrh.seq_item_export);

endfunction



endclass
