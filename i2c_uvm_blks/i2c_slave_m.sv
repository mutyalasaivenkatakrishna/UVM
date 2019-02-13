class i2c_slave_model extends uvm_component;

  `uvm_component_utils(i2c_slave_model)

  virtual apb_i2c_intf vif;

    apb_tx txnh1;
    apb_tx tx;
    i2c_cfg cfg;
  
  bit [7:0] memo[int];

  uvm_analysis_port #(apb_tx) i2c_slv;

  logic [3:0][7:0] mem_data[int];
  
  function new(string name = "i2c_slave_model", uvm_component parent);
    super.new(name,parent);
  endfunction

  function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    i2c_slv = new("i2c_slv",this);
    tx = apb_tx::type_id::create("tx");

    if(!(uvm_config_db#(virtual apb_i2c_intf)::get(this,"","vif",vif)))
      `uvm_fatal("i2c_slave_model","vif is not set")

 if (!uvm_config_db#(i2c_cfg)::get(this, "", "cfg", cfg)) begin
      `uvm_fatal("NO_CFG", "slave config not found in slave response")
    end
      
  endfunction

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

  

  function bit addr_match(bit [6:0] addr);
    foreach(cfg.addr[i]) begin
      if(addr == cfg.addr[i])
        return 1;
    end
    return 0;
  endfunction

  
  task recv_byte(output bit [7:0] din);
    for(int i=7;i>=0;i--) begin
      @(posedge vif.scl);
      din[i] = vif.sda_in;
    end
  endtask

 
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
  
  task send_byte(input bit [7:0] dout);
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

  
  task wait_master_ack(output bit ack);
    @(posedge vif.scl);
    ack = (vif.sda_in == 1);
  endtask

  task run();
    bit [7:0] addr_byte;
    bit [6:0] addr;
    bit rw;

    vif.sda_oe  = 0;
    vif.sda_out = 0;

    forever begin
     
      wait_for_start();

      recv_byte(addr_byte);

      addr = addr_byte[7:1];
      rw   = addr_byte[0];

      if(addr_match(addr))
        send_ack(1);

      else begin
        send_ack(0);
        continue;
      end

      if(rw == 0) begin
        forever begin

          bit [7:0] din;
        for(int i=4;i>0;i--) begin
          recv_byte(din);
          mem_data[addr][i] = din;
          //check start from 0 or 7
          send_ack(1);
        end
          wait_for_stop();

          break;

        end

      end

      else begin

        bit ack;
        bit [7:0] dout;

      for(int i=4;i>0;i--) begin

        dout = mem_data[addr][i];

        send_byte(dout);

        wait_master_ack(ack);
        if(ack==1) break;
        // check to start from 0 or 1
      end

        if(ack)
          wait_for_stop();

      end

    end

  endtask

    task run_phase(uvm_phase phase);

        super.run_phase(phase);

        run();

    endtask

endclass




