class i2c_sequencer extends uvm_sequencer #(txn);
`uvm_component_utils(i2c_sequencer)

i2c_cfg cfg;

function new(string name = "i2c_sequencer",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);

if (!uvm_config_db#(i2c_cfg)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal("NO_CFG", "s_cfg not found in master sequencer")
    end


endfunction

endclass
