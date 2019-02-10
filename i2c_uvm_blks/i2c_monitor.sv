class i2c_monitor extends uvm_monitor;
`uvm_component_utils(i2c_monitor)
    uvm_analysis_port #(txn) mn_port;

    virtual i2c_master_if vif;
    
    txn txnh;

    function new(string name = "i2c_monitor",uvm_component parent);
    super.new(name,parent);
    mn_port = new("mn_port",this);
    endfunction

    function void build_phase(uvm_phase phase);
    super.build_phase(phase);
    `uvm_info(get_type_name(),$sformatf($time,"build_phase = %t -i2c_monitor"),UVM_LOW)

    if(!(uvm_config_db#(virtual i2c_master_if)::get(this,"","vif",vif)))
    `uvm_fatal("Monitor","ifi does not getting")
    endfunction

    task run_phase(uvm_phase phase);
    super.run_phase(phase);
     `uvm_info("MST_MON", "MASTER MON RUN STARTED", UVM_LOW)
    txnh = txn::type_id::create("txnh");
    forever
        begin
        @(vif.cb_mon)
     // @(posedge vif.clk)
        txnh.newd = vif.cb_mon.newd;
        txnh.addr = vif.cb_mon.addr;
        txnh.op = vif.op;
        txnh.din = vif.cb_mon.din;
        txnh.done = vif.cb_mon.done;
        txnh.sda = vif.cb_mon.sda;
        txnh.scl = vif.cb_mon.scl;
        txnh.busy = vif.cb_mon.busy;
        txnh.ack_err = vif.cb_mon.ack_err;
        txnh.dout = vif.cb_mon.dout;
       if(vif.cb_mon.done==1'b1) mn_port.write(txnh);
     end
      $display("data to dut = %0h",vif.cb_mon.dout); 

    endtask
endclass
