class apb_i2c_cov extends uvm_subscriber#(apb_tx);

`uvm_component_utils(apb_i2c_cov)

 apb_tx tx_1;

covergroup cp1 ();

  option.per_instance = 1;

  // REGISTER ADDRESS ACCESS

  cp_addr : coverpoint tx_1.paddr
  iff(tx_1.psel && tx_1.penable)
  {
    bins control  = {8'h00};
    bins addr     = {8'h04};
    bins data_in  = {8'h08};
    bins status   = {8'h0C};
    bins data_out = {8'h10};

    bins invalid_addr = default;
  }

  // APB OPERATION TYPE

  cp_rw : coverpoint tx_1.pwrite
  iff(tx_1.psel && tx_1.penable)
  {
    bins read  = {0};
    bins write = {1};
  }

  // ERROR RESPONSE

  cp_pslverr : coverpoint tx_1.pslverr
  iff(tx_1.psel && tx_1.penable)
  {
    bins no_error = {0};
    bins err    = {1};
  }

  // WRITE DATA

  cp_pwdata : coverpoint tx_1.pwdata
  iff(tx_1.psel && tx_1.penable && tx_1.pwrite)
  {
    bins zero      = {32'h0};
    bins all_ones  = {32'hFFFF_FFFF};

    bins low_range  = {[1:255]};
    bins mid_range  = {[256:65535]};
    bins high_range = default;
  }

  // READ DATA

  cp_prdata : coverpoint tx_1.prdata
  iff(tx_1.psel && tx_1.penable && !tx_1.pwrite)
  {
    bins zero      = {32'h0};
    bins all_ones  = {32'hFFFF_FFFF};

    bins low_range  = {[1:255]};
    bins mid_range  = {[256:65535]};
    bins high_range = default;
  }

  // CROSS COVERAGE

  // Every register read/write
  cross_addr_rw :
      cross cp_addr, cp_rw;

  // Error generated on which address
  cross_addr_err :
      cross cp_addr, cp_pslverr;

  // Read/Write causing error
  cross_rw_err :
      cross cp_rw, cp_pslverr;

endgroup


function new(string name, uvm_component parent);
    super.new(name,parent);
    cp1=new();
endfunction

function void write(apb_tx t);
    this.tx_1=t;
    cp1.sample();
endfunction

endclass

