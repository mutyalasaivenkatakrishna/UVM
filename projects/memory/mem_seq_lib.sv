class mem_base_seq extends uvm_sequence#(mem_tx);
`NEW_OBJ
uvm_phase phase;
	task pre_body();
		phase=get_starting_phase();
		if(phase!=null)begin
			phase.raise_objection(this);
			phase.phase_done.set_drain_time(this,100);
		end
	endtask
	task post_body();
		if(phase!=null)begin
			phase.drop_objection(this);
		end
	endtask
endclass

class mem_wr_rd_seq extends mem_base_seq;
mem_tx tx;
`uvm_object_utils(mem_wr_rd_seq)
mem_tx txQ[$];
uvm_phase phase;
`NEW_OBJ
task body();
int count;
phase=get_starting_phase();
phase.raise_objection(this);
uvm_resource_db#(int)::read_by_name("GLOBAL","COUNT",count,null);
repeat(count) begin
	`uvm_do_with(req,{req.write_read_enable==1'b1;});
	//$display("in seqlib writr");
	$cast(tx,req);
	txQ.push_back(tx);
end
//req=new();
	//req.randomize() with(wr_rd==1'b1;);
	//mbox.put(req);
repeat(count) begin
	tx=txQ.pop_front();
	`uvm_do_with(req,{req.write_read_enable==1'b0 ; req.address==tx.address;});
	//$display("in seqlib read");
	end
	phase.drop_objection(this);
endtask
endclass
