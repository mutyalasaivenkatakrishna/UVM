
`uvm_analysis_imp_decl(_apb)
`uvm_analysis_imp_decl(_i2c)

class apb_i2c_sbd extends uvm_scoreboard;
    
    uvm_analysis_imp_apb #(apb_tx,apb_i2c_sbd) apb;
    uvm_analysis_imp_i2c #(i2c_slv_tx,apb_i2c_sbd) i2c;
    
    `uvm_component_utils(apb_i2c_sbd)

    apb_tx apb_q[$];
    //i2c_slv_tx i2c_q[$];
  
  /* 
    //i2c i/o signals
     bit newd;
     bit [6:0]addr;
     bit op;
     bit [7:0]din;
     bit done;
     bit sda;
     bit scl;
     bit busy;
     bit ack_err;
     bit [7:0]dout;
*/

  //  bit[31:0] mem_as[bit[7:0]][7:0];
    //   Two-dimensional flat byte-addressable memory
    // First  key = slave address  [6:0]
    // Second key = register address [7:0]
    // Each value = one data byte  [7:0]
    
    bit [7:0] mem_data[bit [6:0]][bit [7:0]];
    
    logic [2:0] control_reg;
    logic [6:0] slv_addr;
    logic [7:0] reg_addr;
    logic [31:0] data_in;
    logic [31:0] data_out;
    logic [1:0] status_reg;
//check slvaddr and reg addr
   
    function new(string name,uvm_component parent);
        super.new(name,parent);
        apb=new("apb",this);
        i2c=new("i2c",this);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
    endfunction

    function void write_apb(apb_tx tx1);
        apb_q.push_back(tx1);
        ref_model_apb( tx1);
    endfunction

    function void write_i2c(i2c_slv_tx tx2);
        ref_model_i2c(tx2);
    endfunction

    function void ref_model_apb(apb_tx tx1);
        case(tx1.paddr)

            //slave_address register
            8'h04: begin
                    if(tx1.pwrite==1'b1) slv_addr = tx1.pwdata[6:0];
                   end
            8'h08: begin
                    if(tx1.pwrite==1'b1) reg_addr = tx1.pwdata[7:0];
                   end
            
            8'h0c: begin
                    if(tx1.pwrite==1'b1)data_in = tx1.pwdata;
                   end

            8'h00: begin
                    control_reg = tx1.pwdata[2:0];
                    if(control_reg[1]==1'b0 && tx1.pwrite==1'b1) begin
                        //single byte
                        if(control_reg[2]==0)mem_data[slv_addr][reg_addr][31:24] = data_in[31:24];
                        //multibyte
                        if(control_reg[2]==1)mem_data[slv_addr][reg_addr] = data_in;
                    end
                   end

            8'h10: begin
                    if(control_reg[1]==1'b0 && tx1.pwrite==1'b0) begin
                        if(control_reg[2]==0)data_out={23'h0,mem_data[slv_addr][reg_addr][31:24]};
                        if(control_reg[2]==1)data_out=mem_data[slv_addr][reg_addr];
                        if(data_out==tx1.prdata) `uvm_info(get_type_name(),$sformatf("Test Passed address = %h, read_data = %h",reg_addr,data_out),UVM_LOW)
                        else `uvm_error("Scoreboard","Test Failed")
                    end
                   end
        endcase
    endfunction


    function void ref_model_i2c(i2c_slv_tx i2c_tx);
        
    endfunction
    
endclass
