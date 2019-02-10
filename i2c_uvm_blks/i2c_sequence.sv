class i2c_sequence extends uvm_sequence #(txn);
`uvm_object_utils(i2c_sequence)

 `uvm_declare_p_sequencer(i2c_sequencer)

    int intQ [$];
    int tmp;

    function new(string name = "i2c_sequence");
    super.new(name);
    endfunction

endclass


//normal working write testcase

class i2c_write_n extends i2c_sequence;
`uvm_object_utils(i2c_write_n)
    function new(string name = "i2c_write_n");
    super.new(name);
    endfunction
    
    task pre_body();
    if(starting_phase != null) begin
        `uvm_info("seq","raising objection",UVM_MEDIUM)
        starting_phase.raise_objection(this);
        end
    endtask

    task body();
    bit[6:0] addr[$];
    bit [6:0] temp;
    addr = p_sequencer.cfg.addr;
    addr.shuffle();
    temp = addr.pop_front();

        req = txn::type_id::create("req");
         `uvm_do_with(req,{newd==1;op ==0;addr ==temp;})
         
          endtask

    task post_body();
    if(starting_phase != null)begin
        `uvm_info("seq","dropping objection",UVM_MEDIUM)
        starting_phase.drop_objection(this);
        end
    endtask

endclass


class i2c_write_b extends i2c_sequence;
`uvm_object_utils(i2c_write_b)
    function new(string name = "i2c_write_b");
    super.new(name);
    endfunction
    
    task pre_body();
    if(starting_phase != null) begin
        `uvm_info("seq","raising objection",UVM_MEDIUM)
        starting_phase.raise_objection(this);
        starting_phase.phase_done.set_drain_time(this,83000);
        end
    endtask

    task body();
     bit[6:0] addr[$];
    bit [6:0] temp;
    addr = p_sequencer.cfg.addr;
   // addr.shuffle();
   // temp = addr.pop_front();

    
    req = txn::type_id::create("req");
        
        repeat(10) begin
        addr.shuffle();
       temp = addr.pop_front();

         `uvm_do_with(req,{newd==1;op ==0;addr == temp;})
        end
        
       // `uvm_do_with(req,{newd ==1; op == 1;})
        
       endtask

    task post_body();
    if(starting_phase != null)begin
        `uvm_info("seq","dropping objection",UVM_MEDIUM)
        starting_phase.drop_objection(this);
        end
    endtask

endclass



/*
class i2c_write_0 extends i2c_sequence;
`uvm_object_utils(i2c_write_0)
    function new(string name = "i2c_write_0");
    super.new(name);
    endfunction
    
    task pre_body();
    if(starting_phase != null) begin
        `uvm_info("seq","raising objection",UVM_MEDIUM)
        starting_phase.raise_objection(this);
        end
    endtask

    task body();
    bit[6:0] addr[$];
    bit [6:0] temp;
    addr = p_sequencer.cfg.addr;
    addr.shuffle();
    temp = addr.pop_front();

        req = txn::type_id::create("req");
         `uvm_do_with(req,{newd ==1;op ==0;addr == temp;din == 8'h00;})
           
          endtask

    task post_body();
    if(starting_phase != null)begin
        `uvm_info("seq","dropping objection",UVM_MEDIUM)
        starting_phase.drop_objection(this);
        end
    endtask

endclass

///write addr has 7'hFF

class i2c_write_1 extends i2c_sequence;
`uvm_object_utils(i2c_write_1)
    function new(string name = "i2c_write_1");
    super.new(name);
    endfunction
    
    task pre_body();
    if(starting_phase != null) begin
        `uvm_info("seq","raising objection",UVM_MEDIUM)
        starting_phase.raise_objection(this);
        end
    endtask

    task body();
    bit [6:0] addr[$];
    bit [6:0] temp;
    addr = p_sequencer.cfg.addr;
    addr.shuffle();
    temp = addr.pop_front();
        req = txn::type_id::create("req");
         //`uvm_do_with(req,{newd ==1;op ==0; addr == 7'h50;})
            `uvm_do_with(req,{newd == 1;op ==0;addr == temp;din == 8'hFF;})

          endtask

    task post_body();
    if(starting_phase != null)begin
        `uvm_info("seq","dropping objection",UVM_MEDIUM)
        starting_phase.drop_objection(this);
        end
    endtask

endclass


class i2c_read_n extends i2c_sequence;
`uvm_object_utils(i2c_read_n)
    function new(string name = "i2c_read_n");
    super.new(name);
    endfunction
    
    task pre_body();
    if(starting_phase != null) begin
        `uvm_info("seq","raising objection",UVM_MEDIUM)
        starting_phase.raise_objection(this);
        end
    endtask

    task body();
     bit[6:0] addr[$];
    bit [6:0] temp;
    addr = p_sequencer.cfg.addr;
    addr.shuffle();
    temp = addr.pop_front();
        req = txn::type_id::create("req");
       // repeat(10)
        begin
         `uvm_do_with(req,{newd == 1;op ==1;addr ==temp;})
        end
          endtask

    task post_body();
    if(starting_phase != null)begin
        `uvm_info("seq","dropping objection",UVM_MEDIUM)
        starting_phase.drop_objection(this);
        end
    endtask

endclass */

/*
class i2c_addr_0 extends i2c_sequence;
`uvm_object_utils(i2c_addr_0)
    function new(string name = "i2c_addr_0");
    super.new(name);
    endfunction
    
    task pre_body();
    if(starting_phase != null) begin
        `uvm_info("seq","raising objection",UVM_MEDIUM)
        starting_phase.raise_objection(this);
        end
    endtask

    task body();
        req = txn::type_id::create("req");
         `uvm_do_with(req,{newd ==1;op ==0;addr == 7'h00;})

          endtask

    task post_body();
    if(starting_phase != null)begin
        `uvm_info("seq","dropping objection",UVM_MEDIUM)
        starting_phase.drop_objection(this);
        end
    endtask

endclass */

/*
class i2c_addr_1 extends i2c_sequence;
`uvm_object_utils(i2c_addr_1)
    function new(string name = "i2c_addr_1");
    super.new(name);
    endfunction
    
    task pre_body();
    if(starting_phase != null) begin
        `uvm_info("seq","raising objection",UVM_MEDIUM)
        starting_phase.raise_objection(this);
        end
    endtask

    task body();
        req = txn::type_id::create("req");
         `uvm_do_with(req,{newd ==1;op ==0;addr == 7'h7F;})

          endtask

    task post_body();
    if(starting_phase != null)begin
        `uvm_info("seq","dropping objection",UVM_MEDIUM)
        starting_phase.drop_objection(this);
        end
    endtask

endclass */


class i2c_rand_in extends i2c_sequence;
`uvm_object_utils(i2c_rand_in)
    function new(string name = "i2c_rand_in");
    super.new(name);
    endfunction
    
    task pre_body();
    if(starting_phase != null) begin
        `uvm_info("seq","raising objection",UVM_MEDIUM)
        starting_phase.raise_objection(this);
        end
    endtask

    task body();
     bit[6:0] addr[$];
    bit [6:0] temp;
    addr = p_sequencer.cfg.addr;
    addr.shuffle();
    temp = addr.pop_front();
    req = txn::type_id::create("req");

    repeat(100)
    begin
                 `uvm_do_with(req,{newd == 1;addr ==temp;})
    end
          endtask

    task post_body();
    if(starting_phase != null)begin
        `uvm_info("seq","dropping objection",UVM_MEDIUM)
        starting_phase.drop_objection(this);
        end
    endtask

endclass


class i2c_rand_wr extends i2c_sequence;
`uvm_object_utils(i2c_rand_wr)
    function new(string name = "i2c_rand_wr");
    super.new(name);
    endfunction
    
    task pre_body();
    if(starting_phase != null) begin
        `uvm_info("seq","raising objection",UVM_MEDIUM)
        starting_phase.raise_objection(this);
        starting_phase.phase_done.set_drain_time(this,200ns);
        end
    endtask

    task body();
     bit[6:0] addr[$];
    bit [6:0] temp;
    addr = p_sequencer.cfg.addr;
    addr.shuffle();
    temp = addr.pop_front();
        
       repeat(100) begin
         `uvm_do_with(req,{newd == 1;op ==0;addr == temp;})
           tmp=req.addr;
        // `uvm_do_with(req,{newd == 0;din == 8'h00;})   

         `uvm_do_with(req,{newd == 1;op ==1;addr==temp;})
        
      
      
      end
             endtask

    task post_body();
    if(starting_phase != null)begin
        `uvm_info("seq","dropping objection",UVM_MEDIUM)
        starting_phase.drop_objection(this);
        end
    endtask

endclass

class i2c_ack_err extends i2c_sequence;
`uvm_object_utils(i2c_ack_err)
    function new(string name = "i2c_ack_err");
    super.new(name);
    endfunction
    
    task pre_body();
    if(starting_phase != null) begin
        `uvm_info("seq","raising objection",UVM_MEDIUM)
        starting_phase.raise_objection(this);
        starting_phase.phase_done.set_drain_time(this,200ns);
        end
    endtask

    task body();
   /*  bit[6:0] addr[$];
    bit [6:0] temp;
    addr = p_sequencer.cfg.addr;
    addr.shuffle();
    temp = addr.pop_front(); */
        
       repeat(10) begin
         `uvm_do_with(req,{newd == 1;op ==0;})
              end
             endtask

    task post_body();
    if(starting_phase != null)begin
        `uvm_info("seq","dropping objection",UVM_MEDIUM)
        starting_phase.drop_objection(this);
        end
    endtask

endclass


class i2c_d_err extends i2c_sequence;
`uvm_object_utils(i2c_d_err)
    function new(string name = "i2c_d_err");
    super.new(name);
    endfunction
    
    task pre_body();
    if(starting_phase != null) begin
        `uvm_info("seq","raising objection",UVM_MEDIUM)
        starting_phase.raise_objection(this);
        starting_phase.phase_done.set_drain_time(this,200ns);
        end
    endtask

    task body();
    bit[6:0] addr[$];
    bit [6:0] temp;
    addr = p_sequencer.cfg.addr;
            
       repeat(10) begin
       addr.shuffle();
         temp = addr.pop_front(); 

         `uvm_do_with(req,{newd == 1;op ==0;addr == temp;din == 8'h40;})
              end
             endtask

    task post_body();
    if(starting_phase != null)begin
        `uvm_info("seq","dropping objection",UVM_MEDIUM)
        starting_phase.drop_objection(this);
        end
    endtask

endclass




