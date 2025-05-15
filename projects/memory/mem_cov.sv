class mem_cov extends uvm_subscriber#(mem_tx);
mem_tx tx;
event mem_cg_e;
`uvm_component_utils(mem_cov);
//1 covergroup 3 coverpoints 
covergroup mem_cg();
	CP_ADDR: coverpoint tx.address{
		option.auto_bin_max=3;
	}
	CP_WR_RD: coverpoint tx.write_read_enable{
				bins WR={1'b1};
				bins RD={1'b0};
	}
	CP_ADDR_X_WR_RD: cross CP_ADDR,CP_WR_RD;
endgroup

function new(string name,uvm_component parent);
	super.new(name,parent);
 	//mem_cg_e=new;
	mem_cg=new();
endfunction
//no need of run phase task

function void write(mem_tx t);
	this.tx=t;
	mem_cg.sample();
	//->mem_cg_e;
endfunction
endclass
