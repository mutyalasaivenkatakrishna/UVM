class apb_monitor extends uvm_monitor;
    
    uvm_analysis_port #(apb_tx) ap_port;
    
    virtual apb_i2c_intf vif;

    apb_tx tx_1;

    `uvm_component_utils(apb_monitor)
    
    function new(string name, uvm_component parent);
        super.new(name, parent);
        ap_port = new("ap_port",this);
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
            @(vif.mon_cb);            
           begin
            tx_1=new();

            tx_1.psel = vif.mon_cb.psel;
            tx_1.penable = vif.mon_cb.penable;
            tx_1.paddr = vif.mon_cb.paddr;
            tx_1.pwdata = vif.mon_cb.pwdata;
            tx_1.pwrite = vif.mon_cb.pwrite;
            tx_1.pready = vif.mon_cb.pready;
            tx_1.prdata = vif.mon_cb.prdata;
            tx_1.pslverr = vif.mon_cb.pslverr;
                       
         if(vif.mon_cb.psel && vif.mon_cb.penable && vif.mon_cb.pready && vif.rst==1'b1 && !vif.pslverr)   ap_port.write(tx_1);
         end
        end
    endtask

endclass
