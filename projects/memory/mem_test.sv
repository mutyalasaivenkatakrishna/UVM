class mem_base_test extends uvm_test;
mem_env env;
//register the user defined class with the factory
`uvm_component_utils(mem_base_test)

`NEW_COMP
//function new(string name,uvm_component parent);
//	super.new(name,parent);
//endfunction

//function void build_phase(uvm_phase phase);
//	env=new("env",this);
//endfunction

function void build_phase(uvm_phase phase);
	super.build_phase(phase);
//mem_env::type_id->factory definition of mem_env
env=mem_env::type_id::create("env",this);
endfunction

function void end_of_elaboration_phase(uvm_phase phase);
	uvm_top.print_topology();
	//print the testbench topology
endfunction
///*
function void report_phase(uvm_phase phase);
if(mem_common::num_matches==mem_common::total_tx_count && mem_common::num_mismatches==0) begin
	`uvm_info("STATUS","Test passed",UVM_NONE);
end
else begin
	`uvm_error("STATUS","Test failed");
end
endfunction
//*/
endclass
class mem_wr_rd_test extends mem_base_test;
`uvm_component_utils(mem_wr_rd_test);
`NEW_COMP
mem_wr_rd_seq wr_rd_seq;
function void build_phase(uvm_phase phase);
super.build_phase(phase);
wr_rd_seq=mem_wr_rd_seq::type_id::create("wr_rd_seq");
//mem_env::type_id->factory definition of mem_env
//env=mem_env::type_id::create("env",this);
endfunction

task run_phase(uvm_phase phase);
phase.raise_objection(this);
phase.phase_done.set_drain_time(this,100);
wr_rd_seq.start(env.agent.sqr);
#100;
phase.drop_objection(this);

endtask
endclass
class mem_wr_rd_build_phase_test extends mem_base_test;
`uvm_component_utils(mem_wr_rd_build_phase_test);
`NEW_COMP
mem_wr_rd_seq wr_rd_seq;
function void build_phase(uvm_phase phase);
	super.build_phase(phase);
	uvm_config_db#(uvm_object_wrapper)::set(this,"env.agent.sqr.run_phase","default_sequence",mem_wr_rd_seq::get_type());
endfunction
endclass
