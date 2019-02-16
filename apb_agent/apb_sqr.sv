//typedef uvm_sequencer #(apb_tx) apb_sqr;

class apb_sqr extends uvm_sequencer #(apb_tx);
`uvm_component_utils(apb_sqr)

i2c_cfg cfg;

function new(string name = "apb_sqr",uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);

if (!uvm_config_db#(i2c_cfg)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal("NO_CFG", "s_cfg not found in master sequencer")
    end


endfunction

endclass
