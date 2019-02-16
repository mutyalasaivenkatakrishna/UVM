class apb_base_seq extends uvm_sequence #(apb_tx);
    
    `uvm_object_utils(apb_base_seq)
    
   
    function new(string name= "apb_base_seq");
        super.new(name);
    endfunction
       
    task pre_body();
        if(starting_phase!=null) begin
            starting_phase.raise_objection(this);
            starting_phase.phase_done.set_drain_time(this,100);
        end
    endtask

    task post_body();
        if(starting_phase!=null) begin
            starting_phase.drop_objection(this);    
        end
    endtask

endclass


class random_basic_seq extends apb_base_seq;

    `uvm_object_utils(random_basic_seq)

    function new(string name = "random_basic_seq");
        super.new(name);
    endfunction
    
    task reg_wr(input bit[ADDR_WIDTH-1:0] paddr_i,input bit[DATA_WIDTH-1:0]pwdata_i );

        apb_tx req,rsp;

        req = apb_tx::type_id::create("req");
        rsp = apb_tx::type_id::create("rsp");

        start_item(req);

        if (!req.randomize() with {
                                    pwrite==1;
                                    paddr==paddr_i;
                                    //if(paddr_i[7:0]==8'h00)  pwdata[2:0] == pwdata_i[2:0];
                                     pwdata==pwdata_i;
                                  })
        begin
                `uvm_error("SEQ", "Randomization failed")
        end

        finish_item(req);
        get_response(rsp);

    endtask

    task reg_rd (output bit[DATA_WIDTH-1:0]prdata_o,input bit[ADDR_WIDTH-1:0] paddr_i);
        
        apb_tx req,rsp;

        req = apb_tx::type_id::create("req");
        rsp = apb_tx::type_id::create("rsp");

        start_item(req);
        if (!req.randomize() with {
                                    pwrite==0;
                                    paddr==paddr_i;
                                    psel==1'b1;
                                    penable==1'b1;
                                    pwdata=='h0;
                                  })
        begin
                `uvm_error("SEQ", "Randomization failed")
        end

        finish_item(req);   

        get_response(rsp);
        prdata_o = rsp.prdata;
        
    endtask

    task i2c_write(input bit[ADDR_WIDTH-1:0]slv_addr,input bit[ADDR_WIDTH-1:0]reg_addr,input bit mode,bit[DATA_WIDTH-1:0]data_in);
        
        logic [DATA_WIDTH-1:0] prdata_t;

        reg_wr(8'h04,slv_addr);         // pwaddr pwdata
        reg_wr(8'h08,reg_addr);         // pwaddr pwdata
        reg_wr(8'h0c,data_in);
        reg_wr(8'h00,{mode,2'b01});
        reg_rd(prdata_t,'h14);      // prdata pwaddr

        while(prdata_t[0]) reg_rd(prdata_t,'h14);
       
    endtask

    task i2c_read(input bit[ADDR_WIDTH-1:0]slv_addr,input bit[ADDR_WIDTH-1:0]reg_addr,input bit mode,output logic [DATA_WIDTH-1:0] prdata_t);
        
        //logic [DATA_WIDTH-1:0] prdata_t;

        reg_wr(8'h04,slv_addr);         // pwaddr pwdata
        reg_wr(8'h08,reg_addr);         // pwaddr pwdata
        reg_wr(8'h00,{mode,2'b11});
        reg_rd(prdata_t,'h14);                          // prdata pwaddr pwdata
        while(prdata_t[0]) reg_rd(prdata_t,'h14);
        reg_rd(prdata_t,'h10);
       
    endtask

    task body();

            logic [DATA_WIDTH-1:0] prdata_o;
            
            //write
            //parameters -slv_addr,reg_addr,mode(0)-1byte (1)-4byte,data_in
          //  i2c_write('h00,'h00,0,'h12345678);
            i2c_write('h06,'h06,1,'h87654321);

         //   i2c_write('h04,'hfb,'hffffffff);
            
            //read
        //    i2c_read('h11,'h00,0,prdata_o);
        //    `uvm_info(get_type_name(),$sformatf("prdata_o=%h",prdata_o),UVM_MEDIUM)
            i2c_read('h06,'h06,1,prdata_o);
            `uvm_info(get_type_name(),$sformatf("prdata_o=%h",prdata_o),UVM_MEDIUM)
            
     endtask

endclass


class random_full_seq extends apb_base_seq;

    `uvm_object_utils(random_full_seq)

    bit[7:0] slvaddr_q[$]; 
    bit[7:0] regaddr_q[$]; 

    function new(string name = "random_basic_seq");
        super.new(name);
    endfunction


     task reg_wr_r(input bit[ADDR_WIDTH-1:0] paddr_i,input bit[DATA_WIDTH-1:0]pwdata_i );

        apb_tx req,rsp;

        req = apb_tx::type_id::create("req");
        rsp = apb_tx::type_id::create("rsp");

        start_item(req);

        if (!req.randomize() with {
                                    pwrite==1;
                                    paddr==paddr_i;
                                    if(paddr=='h00)  pwdata[1:0] == pwdata_i;
                                    else pwdata==pwdata_i;
                                  })
        begin
                `uvm_error("SEQ", "Randomization failed")
        end

        finish_item(req);
        get_response(rsp);

    endtask

    

    task reg_wr(input bit[ADDR_WIDTH-1:0] paddr_i,input bit[DATA_WIDTH-1:0]pwdata_i='h0 );

        apb_tx req,rsp;

        req = apb_tx::type_id::create("req");
        rsp = apb_tx::type_id::create("rsp");

        start_item(req);

        if (!req.randomize() with {
                                    pwrite==1;
                                    paddr==paddr_i;
                                    if(paddr=='h00)  pwdata[1:0] == pwdata_i;
                                  // pwdata == pwdata_i;
                                  })
        begin
                `uvm_error("SEQ", "Randomization failed")
        end

        if(req.paddr==8'h04) slvaddr_q.push_back(req.pwdata); 
        if(req.paddr==8'h08) regaddr_q.push_back(req.pwdata); 
        finish_item(req);
        get_response(rsp);

    endtask
    
    task i2c_write();
        
        logic [DATA_WIDTH-1:0] prdata_t;

        reg_wr(8'h04);         // pwaddr pwdata
        reg_wr(8'h08);         // pwaddr pwdata
        reg_wr(8'h0c);
        reg_wr(8'h00,'b01);
        reg_rd(prdata_t,'h14);      // prdata pwaddr

        while(prdata_t[0]!=1'b0) reg_rd(prdata_t,'h14);
       
    endtask

    task reg_rd (output bit[DATA_WIDTH-1:0]prdata_o,input bit[ADDR_WIDTH-1:0] paddr_i);
        
                
        apb_tx req,rsp;

        req = apb_tx::type_id::create("req");
        rsp = apb_tx::type_id::create("rsp");

        start_item(req);
        if (!req.randomize() with {
                                    pwrite==0;
                                    paddr==paddr_i;
                                    psel==1'b1;
                                    penable==1'b1;
                                    pwdata=='h0;
                                  })
        begin
                `uvm_error("SEQ", "Randomization failed")
        end

        finish_item(req);   

        get_response(rsp);
        prdata_o = rsp.prdata;
        
    endtask

    

    task i2c_read(output logic [DATA_WIDTH-1:0] prdata_t);
        
        //logic [DATA_WIDTH-1:0] prdata_t;
        bit[7:0] slvt_addr;
        bit[7:0] regt_addr;
        
        slvt_addr=slvaddr_q.pop_front(); 
        regt_addr=regaddr_q.pop_front(); 

        reg_wr_r(8'h04,slvt_addr);         // pwaddr pwdata
        reg_wr_r(8'h08,regt_addr);         // pwaddr pwdata
        reg_wr_r(8'h00,'b11);
        reg_rd(prdata_t,'h14);                          // prdata pwaddr pwdata
        while(prdata_t[0]!=1'b0) reg_rd(prdata_t,'h14);
        reg_rd(prdata_t,'h10);
       
    endtask

     task pslver_check();
        
        
        //write attempted to status-> genrates error
        apb_tx req,rsp;

        req = apb_tx::type_id::create("req");
        rsp = apb_tx::type_id::create("rsp");

        start_item(req);
        if (!req.randomize() with {
                                    pwrite==1;
                                    paddr=='h14;
                                    psel==1'b1;
                                    penable==1'b1;
                                    pwdata=='h0;
                                  })
        begin
                `uvm_error("SEQ", "Randomization failed")
        end

        finish_item(req);   

        get_response(rsp);
       

    endtask



    task body();
            
            logic [DATA_WIDTH-1:0] prdata_o;
             
            //consecutive write read.
            repeat(15) begin
                i2c_write();
                i2c_read(prdata_o);
                `uvm_info(get_type_name(),$sformatf("prdata=%h",prdata_o),UVM_MEDIUM)
            end
            
            //back to back write -read
            repeat(15) begin
                i2c_write();
            end            
            repeat(15) begin
                i2c_read(prdata_o);
                `uvm_info(get_type_name(),$sformatf("prdata=%h",prdata_o),UVM_MEDIUM)
            end
            
            //slave error 
            reg_wr(8'h11,8); // write to invalid address,pslvrr should be asserted.
            reg_wr(8'h13,8); // write to invalid address,pslvrr should be asserted.
            pslver_check();

    endtask

endclass


