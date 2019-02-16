class apb_tx extends uvm_sequence_item;

    parameter ADDR_WIDTH=8;	      //address width
	parameter DATA_WIDTH=32;	      //data width
	parameter SLV_REG_DEPTH=16;	      //slave register memory depth
	localparam BYTES_PER_WORD= DATA_WIDTH/8;
	localparam TOTAL_BYTES=SLV_REG_DEPTH * BYTES_PER_WORD;

    
    
    //rand logic pclk;						  //pclk input
	//rand logic presetn;					  //presetn is a synchronous active low reset
	rand logic psel;						  //psel input which helps to select the particular slave
	rand logic pwrite;
	rand logic penable;					  //input enable enables the access phase.
	rand logic [ADDR_WIDTH-1:0]paddr;	  //address input
	rand logic [DATA_WIDTH-1:0]pwdata;	  //write data input
	
	logic pslverr;				  //pslverr is 1 when address is out off range for the slave
	logic pready;				  //handshaking single 
	logic [DATA_WIDTH-1:0]prdata;//read data output
    
    
    `uvm_object_utils_begin(apb_tx)
        `uvm_field_int (psel,UVM_ALL_ON)
        `uvm_field_int (pwrite,UVM_ALL_ON)
        `uvm_field_int (penable,UVM_ALL_ON)
        `uvm_field_int (paddr,UVM_ALL_ON)
        `uvm_field_int (pwdata,UVM_ALL_ON)
        `uvm_field_int (pslverr,UVM_ALL_ON)
        `uvm_field_int (pready,UVM_ALL_ON)
        `uvm_field_int (prdata,UVM_ALL_ON)
    `uvm_object_utils_end

    function new(string name ="apb_tx");
        super.new(name);
    endfunction
    
    constraint cons_addr {
                           soft paddr[1:0]==2'b00;
                           //pwdata[7:0] inside  {[8'h00:'d124]};
                          }
       
    //constraint cons_addr { paddr inside {[0:(1 << ADDR_WIDTH) - 1]};}

   


endclass
