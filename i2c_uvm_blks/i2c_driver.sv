class i2c_driver extends uvm_driver #(txn);
`uvm_component_utils(i2c_driver)

virtual i2c_master_if vif;
txn dh;
//i2c_cfg cfg;

function new(string name = "i2c_driver", uvm_component parent);
super.new(name,parent);
endfunction

function void build_phase(uvm_phase phase);
super.build_phase(phase);
`uvm_info(get_type_name(),$sformatf($time,"build_phase = %t -i2c_driver"),UVM_LOW)

if(!(uvm_config_db#(virtual i2c_master_if)::get(this,"","vif",vif)))
    `uvm_fatal("Driver","ifi is not set")



endfunction

task run_phase(uvm_phase phase);
forever 
      begin
      wait(vif.rst==0);
      seq_item_port.get_next_item(req);
      drive_item(req);
      seq_item_port.item_done();
      
end
endtask
/*
task drive_item(txn dh);
@(vif.cb_drv)
vif.cb_drv.newd <= dh.newd;
vif.cb_drv.addr <= dh.addr;
vif.cb_drv.op <= dh.op;
vif.cb_drv.din <= dh.din;

//wait (vif.cb_drv.done ==1);
//@(vif.cb_drv);
//vif.cb_drv.newd <= 0;
//@(vif.cb_drv);


do begin 
        @(vif.cb_drv);

//$display($time," done=%b",vif.cb_drv.done);
  end while  (!vif.cb_drv.done == 1);
   
iendtask */

task drive_item(txn dh);
      // Wait until DUT is ready
      //dh.print();
     // $display("started send ing data");
  
  @(vif.cb_drv);
  // Drive transaction when done is high
  vif.cb_drv.addr <= dh.addr;
  vif.cb_drv.op   <= dh.op;
  vif.cb_drv.din  <= dh.din;
  vif.cb_drv.newd <= 1'b1;

  // Keep newd high for one clock
  @(vif.cb_drv);

  // Deassert newd
  vif.cb_drv.newd <= 1'b0;

 //$display("finished sending data");
  // Optional: wait until DUT becomes busy
 /* do begin
    @(vif.cb_drv);
  end while (vif.cb_drv.busy != 1'b1);
  */
 /*if(vif.rst==0) begin */
do begin
    @(vif.cb_drv);
    if(vif.rst == 1) begin break;
    end
  end while (vif.cb_drv.done != 1'b1);

 // $display($time,"reset in drv=%b",vif.rst);
//  if(vif.rst==0) wait (vif.cb_drv.done == 1'b1);
// $display("finished drive_tx data");
  endtask

endclass
