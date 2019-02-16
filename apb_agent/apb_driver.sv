class apb_driver extends uvm_driver #(apb_tx);
    
    `uvm_component_utils(apb_driver)

    virtual apb_i2c_intf vif;

    function new(string name,uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        if(! uvm_resource_db#(virtual apb_i2c_intf)::read_by_name("GLOBAL","vif",vif,this))
            `uvm_info(get_type_name(),$sformatf("failed get using resource db"),UVM_NONE)
        else
            `uvm_info(get_type_name(),$sformatf("successfully get using resource db"),UVM_NONE)
    endfunction

    task run_phase(uvm_phase phase);        
        
        apb_tx req, rsp;
        rsp = apb_tx::type_id::create("rsp");
        req = apb_tx::type_id::create("req");

        forever begin 
            wait(vif.rst==1'b1);
            seq_item_port.get_next_item(req);
            drive_tx(req);
           
            rsp.copy(req);                  
            if(vif.penable==1'b1)rsp.prdata = vif.prdata;        

            rsp.set_id_info(req);           
            seq_item_port.item_done(rsp);
            @(vif.clk);
        end
    endtask

    task drive_tx(apb_tx tx1);
       // if(tx1.paddr!='h14)tx1.print();
        @(vif.drv_cb);
        //later at last modify, if psel==1, then penable =1,
        vif.drv_cb.psel<= 1;
        vif.drv_cb.paddr <=tx1.paddr;
        vif.drv_cb.pwdata <= tx1.pwdata;
        vif.drv_cb.pwrite <= tx1.pwrite;
      //  vif.drv_cb.penable <= tx1.penable;
        vif.drv_cb.penable <= 0;
        @(vif.drv_cb);
        vif.drv_cb.penable <= 1;
        wait(vif.drv_cb.pready==1'b1);
       // @(vif.drv_cb);
        vif.drv_cb.psel<= 0;
        vif.drv_cb.penable <= 0;  
        //later at lst check with out clearing the psel=0.
    endtask

endclass
