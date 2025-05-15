
class mem_mon extends uvm_monitor;
uvm_analysis_port#(mem_tx) ap_port;
virtual mem_intf vif;
mem_tx tx;
`uvm_component_utils(mem_mon);
function new(string name,uvm_component parent);
	super.new(name,parent);
	ap_port=new("ap_port",this);
endfunction


function void build_phase(uvm_phase phase);
//	vif=mem_common::vif;
	uvm_resource_db#(virtual mem_intf)::read_by_name("GLOBAL","APB_VIF",vif,this);
endfunction

task run_phase(uvm_phase phase);
forever begin 
	@(vif.mon_cb);
	if(vif.mon_cb.valid && vif.mon_cb.ready) begin
	tx=new();
	tx.address=vif.mon_cb.address;
	tx.write_read_enable=vif.mon_cb.write_read_enable;
	tx.wr_data=vif.mon_cb.write_read_enable?vif.mon_cb.wr_data:vif.mon_cb.rdata;
//	mem_common::mon2cov_mbox.put(tx);
//	mem_common::mon2ref_mbox.put(tx);
ap_port.write(tx);
//tx.print("printing monitor collected tx");


	end
end
endtask
endclass
