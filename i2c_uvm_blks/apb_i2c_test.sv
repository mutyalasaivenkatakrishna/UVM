class apb_i2c_test extends uvm_test;
`uvm_component_utils(apb_i2c_test)
    apb_i2c_env envh;
    random_basic_seq apb_seq;   
    
    //i2c_sequence seqh;
    i2c_cfg cfg;

    function new(string name = "apb_i2c_test",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);

     cfg = i2c_cfg::type_id::create("cfg");

    // Add multiple slave addresses here
    for(int i=0;i<128;i++) 
        cfg.addr.push_back(i);
/*
    cfg.addr.push_back(7'h55);
    cfg.addr.push_back(7'h68);
    cfg.addr.push_back(7'h20); 
    cfg.addr.push_back(7'h25);
    cfg.addr.push_back(7'h30);
    cfg.addr.push_back(7'h40);
    cfg.addr.push_back(7'h50);
    cfg.addr.push_back(7'h7F);
    cfg.addr.push_back(7'h00);
*/
    uvm_config_db#(i2c_cfg)::set(this,"*","cfg",cfg);
    
    envh = apb_i2c_env::type_id::create("envh",this);
    endfunction
    
    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    //seqh = i2c_sequence::type_id::create("seqh");
    apb_seq = random_basic_seq::type_id::create("apb_seq");
    apb_seq.start(envh.apb_agt.sqr);
    phase.phase_done.set_drain_time(this,20);
    phase.drop_objection(this);
    endtask  
    
    function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
    endfunction

endclass

class write_tc_n extends apb_i2c_test;
    `uvm_component_utils(write_tc_n)
    random_basic_seq seq1;

    function new(string name = "write_tc_n",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this,100ns);
    seq1 = random_basic_seq::type_id::create("seq1");

    seq1.start(envh.apb_agt.sqr);
   
    phase.drop_objection(this);
    endtask

endclass

class wr_rand_tc extends apb_i2c_test;
    `uvm_component_utils(wr_rand_tc)
    random_full_seq seq1;

    function new(string name = "wr_rand_tc",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this,100ns);
    seq1 = random_full_seq::type_id::create("seq1");

    seq1.start(envh.apb_agt.sqr);
   
    phase.drop_objection(this);
    endtask

endclass


