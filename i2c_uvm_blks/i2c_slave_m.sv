class i2c_slave_model extends uvm_component;

  `uvm_component_utils(i2c_slave_model)

  virtual i2c_master_if vif;

    txn txnh1;
    txn tx;
    i2c_cfg cfg;
  // ---------------- MEMORY ----------------
  bit [7:0] memo[int];

  // ---------------- ANALYSIS PORT ----------------
  uvm_analysis_port #(txn) ap;

  // ---------------- SLAVE ADDRESSES ----------------
/*  bit [6:0] slave_addrs[$] = '{
      7'h10, 7'h20, 7'h30, 7'h40, 7'h50,
      7'h60, 7'h70, 7'h15, 7'h25, 7'h35,
      7'h00, 7'h7F
  }; */

  
  function new(string name = "i2c_slave_model", uvm_component parent);
    super.new(name,parent);
  endfunction

    // BUILD
  

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    ap = new("ap",this);
    tx = txn::type_id::create("tx");

    if(!(uvm_config_db#(virtual i2c_master_if)::get(this,"","vif",vif)))
      `uvm_fatal("i2c_slave_model","vif is not set")

 if (!uvm_config_db#(i2c_cfg)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal("NO_CFG", "slave config not found in slave response")
    end
      
  endfunction

    // START DETECT
  
  task wait_for_start();
    bit prev;
    prev = vif.sda_in;
    forever begin
      @(vif.sda_in or vif.scl);
      if(vif.scl == 1 && prev == 1 && vif.sda_in == 0) begin
        break;
      end
      prev = vif.sda_in;
    end
  endtask

    // STOP DETECT
  
  task wait_for_stop();
    bit prev;
    prev = vif.sda_in;
    forever begin
      @(vif.sda_in or vif.scl);
      if(vif.scl == 1 && prev == 0 && vif.sda_in == 1)
        break;
      prev = vif.sda_in;
    end
  endtask

  
  // ADDRESS MATCH
  

  function bit addr_match(bit [6:0] addr);
    foreach(cfg.addr[i]) begin
      if(addr == cfg.addr[i])
        return 1;
    end
    return 0;
  endfunction

  
  // RECEIVE BYTE
  
  task recv_byte(output bit [7:0] din);
    for(int i=7;i>=0;i--) begin
      @(posedge vif.scl);
      din[i] = vif.sda_in;
    end
  //  $display($time," RECEIVE BYTE = %0h",din);
  endtask

   // SEND ACK/NACK
 
  task send_ack(bit ack);
    @(negedge vif.scl);
    if(ack) begin
      vif.sda_out <= 0;
      vif.sda_oe  <= 1;
    end
    else begin
      vif.sda_oe <= 0;
    end
    @(posedge vif.scl);
    @(negedge vif.scl);
    
    vif.sda_oe <= 0;
  endtask

    // SEND BYTE
  
  task send_byte(input bit [7:0] dout);
    // MSB first
    if(dout[7] == 0) begin
      vif.sda_out <= 0;
      vif.sda_oe  <= 1;
    end
    else begin
      vif.sda_oe <= 0;
    end

    for(int i=6;i>=0;i--) begin
      @(negedge vif.scl);
      if(dout[i] == 0) begin
        vif.sda_out <= 0;
        vif.sda_oe  <= 1;
      end
      else begin
        vif.sda_oe <= 0;
      end
      @(posedge vif.scl);
    end
    @(negedge vif.scl);
    vif.sda_oe <= 0;
  endtask

  
  // MASTER ACK
  
  task wait_master_ack(output bit ack);
    @(posedge vif.scl);
    ack = (vif.sda_in == 1);
  endtask

   // MAIN RUN
  
  task run();
    bit [7:0] addr_byte;
    bit [6:0] addr;
    bit rw;

    
    vif.sda_oe  = 0;
    vif.sda_out = 0;

    forever begin

     
      // WAIT FOR START
     
      wait_for_start();

      // ADDRESS PHASE
      
      recv_byte(addr_byte);

      addr = addr_byte[7:1];
      rw   = addr_byte[0];

   /*   $display($time,
               " ADDR=%0h RW=%0b",
               addr,
               rw);  */

      if(addr_match(addr))
        send_ack(1);

      else begin
        send_ack(0);
        continue;
      end

      // ========================================================
      // WRITE OPERATION
      // ========================================================

      if(rw == 0) begin
       // forever begin

          bit [7:0] din;

          recv_byte(din);
          // store data
          memo[addr] = din;
       /*   $display($time,
                   " WRITE MEM[%0h] = %0h",
                   addr,
                   din);  */
          
          // SEND EXPECTED TXN TO SCOREBOARD
          //tx = txn::type_id::create("tx");
          tx.addr = addr;
          tx.op   = 0;
          tx.din = din;

          ap.write(tx);
          if(memo[addr]== 8'h40)
              send_ack(0);
              else
                send_ack(1);

          // WAIT STOP
          wait_for_stop();

         // break;

       // end

      end


            // READ OPERATION
      
      else begin

        bit ack;
        bit [7:0] dout;

        // fetch data
        dout = memo[addr];

       /* $display($time,
                 " READ MEM[%0h] = %0h",
                 addr,
                 dout); */

        // SEND EXPECTED TXN TO SCOREBOARD
       

       // tx = txn::type_id::create("tx");

        tx.addr = addr;
        tx.op   = 1;
        tx.dout = dout;

        ap.write(tx);
        $display($time,"data from slave = %0h addr = %0h",tx.dout,tx.addr);
        // send data
        send_byte(dout);

        // master ack/nack
        wait_master_ack(ack);

        // stop condition
        if(ack)
          wait_for_stop();

      end

    end

  endtask


   // RUN PHASE
    task run_phase(uvm_phase phase);

    super.run_phase(phase);

    run();

forever
        begin
        @(vif.cb_s_mon)
      // @(posedge vif.clk)
        txnh1.addr = tx.addr;
        txnh1.op = tx.op;
        txnh1.din = tx.din;
        txnh1.dout = tx.dout;
        
      if(vif.cb_s_mon.done==1'b1)  ap.write(txnh1);
        end
$display("data from slave(exp data) = %0h",tx.dout);

  endtask


endclass



/*
class i2c_slave_model extends uvm_component;
`uvm_component_utils(i2c_slave_model)
virtual i2c_master_if vif;

   //  bit [7:0] mem [128][64];
     bit [7:0] memo [int];
   // int mem_ptr [128];

    bit [6:0] slave_addrs[$] = '{
    7'h10, 7'h20, 7'h30, 7'h40, 7'h50,
    7'h60, 7'h70, 7'h15, 7'h25, 7'h35, 7'h00, 7'h7F
    };


    function new(string name = "i2c_slave_model",uvm_component parent);
    super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if(!(uvm_config_db#(virtual i2c_master_if)::get(this,"","vif",vif)))
    `uvm_fatal("i2c_slave_model","ifi is not set")
    endfunction

       // ---------------- START ----------------
  task wait_for_start();
    bit prev;

    prev = vif.sda_in;

    forever begin
         @(vif.sda_in or vif.scl);

        if (vif.scl == 1 && prev == 1 && vif.sda_in == 0) begin
            break; // START detected
        end

        prev = vif.sda_in;
    end
endtask 

    // ---------------- STOP ----------------
   task wait_for_stop();
        bit prev = vif.sda_in;
        forever begin
            @(negedge vif.scl);  ///////
            if (prev == 0 && vif.sda_in == 1)
                break;
            prev = vif.sda_in;
            end
    endtask  

    
    function bit addr_match(bit [6:0] addr);
    foreach (slave_addrs[i]) begin
        if (addr == slave_addrs[i])
            return 1;
    end
    return 0;
    endfunction

    // ---------------- RECEIVE BYTE ----------------
    task recv_byte(output bit [7:0] data);
        for (int i=7; i>=0; i--) begin
            @(posedge vif.scl);
            data[i] = vif.sda_in;
        end
        $display($time," task receive byte=%b",data);
    endtask

    // ---------------- ACK ----------------
    task send_ack(bit ack);
        @(negedge vif.scl);

        if (ack) begin
            vif.sda_out <= 0;
            vif.sda_oe  <= 1;
        end else begin
            vif.sda_oe  <= 0;
        end

        @(posedge vif.scl);

        @(negedge vif.scl);
        vif.sda_oe <= 0;
    endtask



    // ---------------- SEND BYTE ----------------
    task send_byte(input bit [7:0] data);
   
            if (data[7] == 0) begin
                vif.sda_out <= 0;
                vif.sda_oe  <= 1;
            end else begin
                vif.sda_oe  <= 0;
                //vif.sda_out <= 1;
            end

        for (int i=6; i>=0; i--) begin
            @(negedge vif.scl);

            if (data[i] == 0) begin
                vif.sda_out <= 0;
                vif.sda_oe  <= 1;
            end else begin
                vif.sda_oe  <= 0;
                //vif.sda_out <= 1;
            end
        
            @(posedge vif.scl);
        end
    $display("data_out = %b",data);
        @(negedge vif.scl);  
        vif.sda_oe <= 0;

    endtask   


    // ---------------- MASTER ACK ----------------
    task wait_master_ack(output bit ack);
        @(posedge vif.scl);
        ack = (vif.sda_in == 1);
    endtask

    // ---------------- MAIN LOOP ----------------
    task run();

        bit [7:0] addr_byte;
        bit [6:0] addr;
        bit rw;
        
        vif.sda_oe = 0;
        vif.sda_out = 0;

        forever begin
                         
            wait_for_start();

            // Address phase
            recv_byte(addr_byte);
            
            $display($time," receive byte in main=%b",addr_byte);
            addr = addr_byte[7:1];
            rw   = addr_byte[0];
            
            if (addr_match(addr))
                send_ack(1);
            else begin
                send_ack(0);
                continue;
            end

            // WRITE
            if (rw == 0) begin
                forever begin
                    bit [7:0] data;
                    recv_byte(data);

                    //mem[mem_ptr++] = data;
                  //  mem[addr][mem_ptr[addr]++] = data;
                    memo[addr] = data;
                    $display("write mem=%p",memo);
                    send_ack(1);
                    wait_for_stop();
                 //   if (vif.scl && vif.sda_in)
                        break;
                end
            end

            // READ
            else begin
               // forever begin
                    bit ack;
                    //bit [7:0] data = mem[mem_ptr++];
                    bit [7:0] data;
                  //  data = mem[addr][mem_ptr[addr]++];

                    $display("read mem=%p",memo);
                    data = memo[addr];
                    send_byte(data);
                    $display("mem = %p",memo);
                   wait_master_ack(ack);
                     if (ack) 
                     wait_for_stop();
            end
            //end
        end
    endtask

endclass   
*/



/*
class i2c_slave_model extends uvm_component;

  `uvm_component_utils(i2c_slave_model)

  virtual i2c_master_if vif;

  bit [7:0] mem [0:127];

  bit [7:0] shift_reg;
  bit [6:0] addr;
  bit [7:0] data_to_send;
  int i;
  bit rw;

  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

   function void build_phase(uvm_phase phase);
    super.build_phase(phase);

    if (!uvm_config_db#(virtual i2c_master_if)::get(this, "", "vif", vif)) begin
      `uvm_fatal("SLAVE", "No vif found")
    end
  endfunction

    function void start_of_simulation_phase(uvm_phase phase);
    foreach (mem[i])
      mem[i] = $urandom;
  endfunction

    task wait_for_start();
     forever begin
     @(posedge vif.scl);
      if (vif.sda_in == 1) begin
          @(negedge vif.sda_in);
      if (vif.scl == 1) begin
        `uvm_info("SLAVE", "START detected", UVM_LOW)
        break;
         end
        end
        end
    endtask

  function bit stop_detected();
    return (vif.scl == 1 && vif.sda_in == 1);
  endfunction

    task run_phase(uvm_phase phase);
     vif.sda_oe = 0; // release by default
    vif.sda_out = 0;
    slave_fsm();
  endtask

   task slave_fsm();

    forever begin
          @(posedge vif.scl);
      shift_reg = 0;

        repeat (8) begin
        @(posedge vif.scl);
        shift_reg = {shift_reg[6:0], vif.sda_in};
      end

      rw   = shift_reg[0];
      addr = shift_reg[7:1];

      `uvm_info("SLAVE",
        $sformatf("ADDR=%0h RW=%0d", addr, rw), UVM_LOW)

      @(negedge vif.scl);
      vif.sda_oe  = 1;
      vif.sda_out = 0;
      `uvm_info("DEBUG", "REACHED ACK BLOCK", UVM_LOW)
      
      @(posedge vif.scl);  
      @(negedge vif.scl);
      vif.sda_oe = 0;

            if (rw == 0) begin

        shift_reg = 0;

        repeat (8) begin
          @(posedge vif.scl);
          shift_reg = {shift_reg[6:0], vif.sda_in};
        end

        // Store data 
        mem[addr] = shift_reg;

        `uvm_info("SLAVE",
          $sformatf("WRITE mem[%0h] = %0h", addr, shift_reg), UVM_MEDIUM)

                
                
        // Ack data
        @(negedge vif.scl);
        vif.sda_oe  = 1;
        vif.sda_out = 0;

      // @(posedge vif.scl);
       @(negedge vif.scl);
        //wait(vif.scl == 0);
        vif.sda_oe = 0;
 
      
           end

           else begin
       // @(posedge vif.scl);
        data_to_send = mem[addr];

        `uvm_info("SLAVE",
          $sformatf("READ mem[%0h] = %0h", addr, data_to_send), UVM_MEDIUM)

       
        for (i = 7; i >= 0; i = i - 1) begin
          @(negedge vif.scl);
          vif.sda_oe  = 1;
          vif.sda_out = data_to_send[i];

          @(posedge vif.scl);
        end

        // release for master Ack
        @(negedge vif.scl);
        vif.sda_oe = 0;

        @(posedge vif.scl); // master Ack phase

      end
            wait (stop_detected());
      `uvm_info("SLAVE", "STOP detected", UVM_LOW)

    end

  endtask

endclass
*/
