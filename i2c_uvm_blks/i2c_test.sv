class i2c_test extends uvm_test;
`uvm_component_utils(i2c_test)
    i2c_env envh;
    i2c_sequence seqh;
    i2c_cfg cfg;

    function new(string name = "i2c_test",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);

     cfg = i2c_cfg::type_id::create("cfg");

    // Add multiple slave addresses here
    cfg.addr.push_back(7'h60);
    cfg.addr.push_back(7'h55);
    cfg.addr.push_back(7'h68);
    cfg.addr.push_back(7'h20); 
    cfg.addr.push_back(7'h25);
    cfg.addr.push_back(7'h30);
    cfg.addr.push_back(7'h40);
    cfg.addr.push_back(7'h50);
    cfg.addr.push_back(7'h7F);
    cfg.addr.push_back(7'h00);

    uvm_config_db#(i2c_cfg)::set(
      this,
      "*",
      "cfg",
      cfg
    );
    
    envh = i2c_env::type_id::create("envh",this);
    endfunction
    
    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seqh = i2c_sequence::type_id::create("seqh");
    seqh.start(envh.agth.seqrh);
    phase.phase_done.set_drain_time(this,20);
    phase.drop_objection(this);
    endtask  
    

    function void end_of_elaboration_phase(uvm_phase phase);
    super.end_of_elaboration_phase(phase);
    uvm_top.print_topology();
    endfunction

endclass
/*
class write_tc_n extends i2c_test;
`uvm_component_utils(write_tc_n)
i2c_write_n seq1;

    function new(string name = "write_tc_n",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this,83000ns);
    seq1 = i2c_write_n::type_id::create("seq1");

    seq1.start(envh.agth.seqrh);
   
        phase.drop_objection(this);
    endtask

endclass */


class write_tc_b extends i2c_test;
`uvm_component_utils(write_tc_b)
i2c_write_b seq1;

    function new(string name = "write_tc_b",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this,83000ns);
    seq1 = i2c_write_b::type_id::create("seq1");

    seq1.start(envh.agth.seqrh);
   
        phase.drop_objection(this);
    endtask

endclass


/*
class write_tc_0 extends i2c_test;
`uvm_component_utils(write_tc_0)
i2c_write_0 seq1;

    function new(string name = "write_tc_o",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
     phase.phase_done.set_drain_time(this,83000ns);
    seq1 = i2c_write_0::type_id::create("seq1");
    
    seq1.start(envh.agth.seqrh);
   
       phase.drop_objection(this);
    endtask

endclass


class write_tc_1 extends i2c_test;
`uvm_component_utils(write_tc_1)
i2c_write_1 seq1;

    function new(string name = "write_tc_1",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this,83000ns);
    seq1 = i2c_write_1::type_id::create("seq1");
    
    seq1.start(envh.agth.seqrh);
   
        phase.drop_objection(this);
    endtask

endclass


class read_tc_n extends i2c_test;
`uvm_component_utils(read_tc_n)
i2c_read_n seq2;
    function new(string name = "read_tc_n",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq2 = i2c_read_n::type_id::create("seq2");
     phase.phase_done.set_drain_time(this,83000ns);

    seq2.start(envh.agth.seqrh);
       phase.drop_objection(this);
    endtask

endclass */

/*
class addr_tc_0 extends i2c_test;
`uvm_component_utils(addr_tc_0)
i2c_addr_0 seq1;
    function new(string name = "addr_tc_0",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq1 = i2c_addr_0::type_id::create("seq1");
    phase.phase_done.set_drain_time(this,83000ns);
    seq1.start(envh.agth.seqrh);
    
    phase.drop_objection(this);
    endtask

endclass


class addr_tc_1 extends i2c_test;
`uvm_component_utils(addr_tc_1)
i2c_addr_1 seq1;
    function new(string name = "addr_tc_1",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    seq1 = i2c_addr_1::type_id::create("seq1");
    phase.phase_done.set_drain_time(this,83000ns);
    seq1.start(envh.agth.seqrh);
    
    phase.drop_objection(this);
    endtask

endclass   */


class rand_tc extends i2c_test;
`uvm_component_utils(rand_tc)
i2c_rand_in seq1;
    function new(string name = "rand_tc",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    phase.phase_done.set_drain_time(this,83000ns);
    seq1 = i2c_rand_in::type_id::create("seq1");
    seq1.start(envh.agth.seqrh);
    
    phase.drop_objection(this);
    endtask

endclass


class rand_tc_wr extends i2c_test;
`uvm_component_utils(rand_tc_wr)
i2c_rand_wr seqw;
//i2c_rand_r seqr;
    function new(string name = "rand_tc_wr",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    
    phase.phase_done.set_drain_time(this,83000ns);
    seqw = i2c_rand_wr::type_id::create("seqw");
       seqw.start(envh.agth.seqrh);

   // seqr = i2c_rand_r::type_id::create("seqr");
   // seqr.start(envh.agth.seqrh);

    phase.drop_objection(this);
    endtask

endclass


class tc_ack_err extends i2c_test;
`uvm_component_utils(tc_ack_err)
i2c_ack_err seqw;
//i2c_rand_r seqr;
    function new(string name = "tc_ack_err",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    
    phase.phase_done.set_drain_time(this,83000ns);
    seqw = i2c_ack_err::type_id::create("seqw");
       seqw.start(envh.agth.seqrh);

   // seqr = i2c_rand_r::type_id::create("seqr");
   // seqr.start(envh.agth.seqrh);

    phase.drop_objection(this);
    endtask

endclass


class tc_d_err extends i2c_test;
`uvm_component_utils(tc_d_err)
i2c_d_err seqw;

    function new(string name = "tc_d_err",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    endfunction

    task run_phase(uvm_phase phase);
    phase.raise_objection(this);
    
    phase.phase_done.set_drain_time(this,83000ns);
    seqw = i2c_d_err::type_id::create("seqw");
       seqw.start(envh.agth.seqrh);

   // seqr = i2c_rand_r::type_id::create("seqr");
   // seqr.start(envh.agth.seqrh);

    phase.drop_objection(this);
    endtask

endclass

