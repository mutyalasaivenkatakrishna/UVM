class mem_drv extends uvm_driver#(mem_tx);
virtual mem_intf vif;
mem_tx tx;
`uvm_component_utils(mem_drv);
`NEW_COMP

function void build_phase(uvm_phase phase);
//	vif=mem_common::vif;
	uvm_resource_db#(virtual mem_intf)::read_by_name("GLOBAL","APB_VIF",vif,this);
endfunction

task run_phase(uvm_phase phase);
forever begin 
	seq_item_port.get_next_item(req);
	drive_tx(req);
	seq_item_port.item_done();
end
endtask

	task drive_tx(mem_tx tx);
	@(posedge vif.drv_cb)
	vif.drv_cb.address<=tx.address;
	if(tx.write_read_enable==1) vif.drv_cb.wr_data<=tx.wr_data; //write tnx
	else vif.drv_cb.wr_data<=0;
	vif.drv_cb.write_read_enable<=tx.write_read_enable;
	vif.drv_cb.valid<=1;
	wait(vif.drv_cb.ready==1);
//	tx.print();
	@(posedge vif.drv_cb)
	vif.drv_cb.address<=0;
	vif.drv_cb.wr_data<=0;
	vif.drv_cb.write_read_enable<=0;
	vif.drv_cb.valid<=0;
		
	endtask
endclass
