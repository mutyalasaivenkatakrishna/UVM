class i2c_slave_driver extends uvm_component;

  `uvm_component_utils(i2c_slave_driver)

  virtual i2c_if vif;

  //------------------------------------------
  // MEMORY (per slave, 256 bytes)
  //------------------------------------------
  bit [7:0] mem [bit[6:0]][256];
  int ptr [bit[6:0]];

  //------------------------------------------
  // Supported slave addresses
  //------------------------------------------
  bit [6:0] slave_addrs[$];

  //------------------------------------------
  function new(string name, uvm_component parent);
    super.new(name, parent);
  endfunction

  //------------------------------------------
  function void build_phase(uvm_phase phase);
    if(!uvm_config_db#(virtual i2c_if)::get(this,"","vif",vif))
      `uvm_fatal("SLAVE","No vif")

    // Example addresses
    slave_addrs = '{7'h10, 7'h20, 7'h30, 7'h60};
  endfunction

  //------------------------------------------
  // Utility: address match
  //------------------------------------------
  function bit addr_match(bit [6:0] a);
    foreach(slave_addrs[i])
      if(a == slave_addrs[i]) return 1;
    return 0;
  endfunction

  //------------------------------------------
  // START detection
  //------------------------------------------
  task wait_for_start();
    bit prev = vif.sda;
    forever begin
      @(vif.sda or vif.scl);
      if(vif.scl == 1 && prev == 1 && vif.sda == 0)
        break;
      prev = vif.sda;
    end
  endtask

  //------------------------------------------
  // STOP detection
  //------------------------------------------
  function bit stop_detected();
    return (vif.scl == 1 && vif.sda == 1);
  endfunction

  //------------------------------------------
  // REPEATED START detection
  //------------------------------------------
  function bit repeated_start_detected();
    return (vif.scl == 1 && vif.sda == 0);
  endfunction

  //------------------------------------------
  // RECEIVE BYTE (MSB first)
  //------------------------------------------
  task recv_byte(output bit [7:0] data);
    for(int i=7;i>=0;i--) begin
      @(posedge vif.scl);
      data[i] = vif.sda;
    end
  endtask

  //------------------------------------------
  // SEND ACK
  //------------------------------------------
  task send_ack(bit ack);
    @(negedge vif.scl);

    if(ack) begin
      vif.sda_out <= 0;
      vif.sda_oe  <= 1;
    end else begin
      vif.sda_oe  <= 0;
    end

    @(posedge vif.scl);
    @(negedge vif.scl);
    vif.sda_oe <= 0;
  endtask

  //------------------------------------------
  // SEND BYTE (FIXED FIRST BIT ALIGNMENT)
  //------------------------------------------
  task send_byte(input bit [7:0] data);

    // FIRST BIT (MSB)
    @(negedge vif.scl);
    if(data[7] == 0) begin
      vif.sda_out <= 0;
      vif.sda_oe  <= 1;
    end else begin
      vif.sda_oe <= 0;
    end
    @(posedge vif.scl);

    // Remaining bits
    for(int i=6;i>=0;i--) begin
      @(negedge vif.scl);
      if(data[i] == 0) begin
        vif.sda_out <= 0;
        vif.sda_oe  <= 1;
      end else begin
        vif.sda_oe <= 0;
      end
      @(posedge vif.scl);
    end

    // Release SDA
    @(negedge vif.scl);
    vif.sda_oe <= 0;
  endtask

  //------------------------------------------
  // WAIT MASTER ACK
  //------------------------------------------
  task wait_master_ack(output bit ack);
    @(posedge vif.scl);
    ack = (vif.sda == 0);
  endtask

  //------------------------------------------
  // MAIN RUN
  //------------------------------------------
  task run_phase(uvm_phase phase);

    vif.sda_oe = 0;

    forever begin

      //----------------------------------
      // START
      //----------------------------------
      wait_for_start();

      //----------------------------------
      // ADDRESS
      //----------------------------------
      bit [7:0] addr_byte;
      recv_byte(addr_byte);

      bit [6:0] addr = addr_byte[7:1];
      bit rw         = addr_byte[0];

      if(!addr_match(addr)) begin
        send_ack(0);
        continue;
      end

      send_ack(1);

      //----------------------------------
      // WRITE (multi-byte)
      //----------------------------------
      if(rw == 0) begin

        // First byte = pointer
        bit [7:0] reg_ptr;
        recv_byte(reg_ptr);
        ptr[addr] = reg_ptr;
        send_ack(1);

        forever begin
          if(stop_detected()) break;
          if(repeated_start_detected()) break;

          bit [7:0] data;
          recv_byte(data);

          mem[addr][ptr[addr]] = data;
          ptr[addr]++;

          `uvm_info("SLAVE",
            $sformatf("WRITE addr=%0h ptr=%0h data=%0h",
                      addr, ptr[addr]-1, data),
            UVM_LOW)

          send_ack(1);
        end
      end

      //----------------------------------
      // READ (multi-byte)
      //----------------------------------
      else begin

        forever begin
          if(stop_detected()) break;

          bit [7:0] data = mem[addr][ptr[addr]];
          ptr[addr]++;

          send_byte(data);

          `uvm_info("SLAVE",
            $sformatf("READ addr=%0h data=%0h",
                      addr, data),
            UVM_LOW)

          bit ack;
          wait_master_ack(ack);

          if(!ack) break;
          if(repeated_start_detected()) break;
        end
      end

    end
  endtask

endclass
