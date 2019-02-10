/*class i2c_slave_mon extends uvm_monitor;
`uvm_component_utils(i2c_slave_mon)
 uvm_analysis_port #(txn) mn_slave;

    virtual i2c_master_if vif;

    txn txnh1;

function new (string name = "i2c_slave_mon",uvm_component parent);
super.new(name,parent);
mn_slave = new("mn_slave",this);
endfunction

function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(),$sformatf($time,"build_phase = %t -i2c_slave_monitor"),UVM_LOW)

    if(!(uvm_config_db#(virtual i2c_master_if)::get(this,"","vif",vif)))
    `uvm_fatal("slave_Monitor","ifi does not getting")
    endfunction
 
    
task run_phase(uvm_phase phase);
super.run_phase(phase);
// `uvm_info("SLV_MON", "SLAVE MON RUN STARTED", UVM_LOW)
txnh1 = txn::type_id::create("txnh1");
forever
        begin
       // @(vif.cb_s_mon)
        txnh1.addr = mn_slave.addr;
        txnh1.op = mn_slave.op;
        txnh1.din = mn_slave.din;
        txnh1.dout = mn_slave.dout;
        
        mn_slave.write(txnh1);
        end
endtask 
/*
task run_phase(uvm_phase phase);

    bit [6:0] addr;
    bit       op;
    bit [7:0] data;

    super.run_phase(phase);

    `uvm_info("SLV_MON", "SLAVE MON RUN STARTED", UVM_LOW)

    forever begin

      @(vif.cb_s_mon);

      // temporary values
      // Later replace these with decoded SDA/SCL values
     // addr = 7'h10;
     // op   = 1'b0;
     // data = 8'h55;

      txnh1 = txn::type_id::create("txnh1");

      txnh1.addr = addr;
      txnh1.op   = op;

      if (op == 1'b0) begin
        txnh1.din  = data;
        txnh1.dout = '0;
      end
      else begin
        txnh1.din  = '0;
        txnh1.dout = data;
      end

      mn_slave.write(txnh1);

    end

  endtask


endclass

*/
