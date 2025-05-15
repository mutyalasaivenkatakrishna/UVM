class fifo_agent extends uvm_agent;

`uvm_component_utils(fifo_agent)

fifo_sqr sqr;
fifo_drv drv;
fifo_mon mon;
fifo_cov cov;

function new(string name, uvm_component parent);
	super.new(name,parent);
endfunction


function void build_phase(uvm_phase phase);
	sqr=fifo_sqr::type_id::create("sqr",this);
	drv=fifo_drv::type_id::create("drv",this);
	mon=fifo_mon::type_id::create("mon",this);
	cov=fifo_cov::type_id::create("cov",this);
endfunction
endclass
