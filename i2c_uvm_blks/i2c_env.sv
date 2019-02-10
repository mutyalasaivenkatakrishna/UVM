class i2c_env extends uvm_component;
`uvm_component_utils(i2c_env)

i2c_agent agth;
i2c_slave_agent s_agth;
i2c_scoreboard scrb_h;

function new(string name = "i2c_env",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);
agth = i2c_agent::type_id::create("agth",this);
s_agth = i2c_slave_agent::type_id::create("s_agth",this);
scrb_h = i2c_scoreboard::type_id::create("scrb_h",this);
`uvm_info(get_type_name(),$sformatf($time,"build_phase = %t -i2c_env"),UVM_LOW)
endfunction

function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
agth.monh.mn_port.connect(scrb_h.master_imp);
s_agth.slave_agth.ap.connect(scrb_h.slave_imp);
//s_agth.slave_agth.ap.connect(scrb_h.master_imp);
//s_agth.sla_mon.mn_slave.connect(scrb_h.slave_imp);

endfunction 

endclass
