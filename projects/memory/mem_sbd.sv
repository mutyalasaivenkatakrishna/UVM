class mem_sbd extends uvm_scoreboard;
uvm_analysis_imp #(mem_tx,mem_sbd) imp_mem;
bit [`WIDTH-1:0] mem[int];
`uvm_component_utils(mem_sbd);
`NEW_COMP
function void build_phase(uvm_phase phase);
	imp_mem=new("imp_mem",this);
endfunction

function void write(mem_tx tx);
	if(tx.write_read_enable==1) begin
		mem[tx.address]=tx.wr_data;
		//$display("in sbd write address=%h,data=%h",tx.address,tx.wr_data);

	//	$display("memory=%p",mem);
	end
	else begin
	//	$display("in sbd write mem data=%b",mem[tx.address]);
	//	$display("in sbd read tx address=%b,tx data=%b",tx.address,tx.wr_data);
		if(tx.wr_data==mem[tx.address]) begin
		mem_common::num_matches++;
	//	$display("Data Matched");
		end
		else begin
			mem_common::num_mismatches++;
			`uvm_error("SBD",$psprintf("Write data doesn't match read data,sbd=%h,mem data=%h",mem[tx.address],tx.wr_data));
		end
	end
endfunction
endclass
