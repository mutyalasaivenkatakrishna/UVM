class i2c_slv_monitor extends uvm_monitor;
    
    uvm_analysis_port #(i2c_slv_tx) i2c_slv_mon_port;
    
    virtual apb_i2c_intf vif;

    i2c_slv_tx tx_1;

    `uvm_component_utils(i2c_slv_monitor)
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        i2c_slv_mon_port = new("i2c_slv_mon_port",this);
    endfunction
    
     function void build_phase(uvm_phase phase);
        super.build_phase(phase);
       if(! uvm_resource_db#(virtual apb_i2c_intf)::read_by_name("GLOBAL","vif",vif,this))
           `uvm_info(get_type_name(),$sformatf("failed get using resource db"),UVM_NONE)
       else
           `uvm_info(get_type_name(),$sformatf("successfully get using resource db"),UVM_NONE)
    endfunction

    task run_phase(uvm_phase phase);
        forever begin
            @(vif.cb_s_mon);
            tx_1=new();
            tx_1.sda_si = vif.cb_s_mon.sda_si;
            tx_1.sda_so = vif.cb_s_mon.sda_so;
            tx_1.scl = vif.cb_s_mon.scl;
            i2c_slv_mon_port.write(tx_1);
        end
        
    endtask

endclass
