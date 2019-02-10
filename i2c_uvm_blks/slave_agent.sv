class i2c_slave_agent extends uvm_agent;
`uvm_component_utils(i2c_slave_agent)

i2c_slave_model slave_agth;
//i2c_slave_mon sla_mon;

function new(string name = "i2c_slave_agent",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);
slave_agth = i2c_slave_model::type_id::create("slave_agth",this);
//sla_mon = i2c_slave_mon::type_id::create("sla_mon",this);
`uvm_info(get_type_name(),$sformatf($time,"build_phase = %t -i2c_agent"),UVM_LOW)
endfunction

/*function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
slave_agth.ap.connect(sla_mon.mn_slave);
endfunction  */


endclass
/*

`uvm_info("SB",
            $sformatf("READ PASS addr=%0h exp_data=%0h act_data=%0h",
                      ref_d.addr, ref_d.dout, act_d.dout),
            UVM_LOW)
*/
