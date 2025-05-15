interface fifo_intf(input w_clk_i,r_clk_i,rst_i);

bit rd_enable_i,wr_enable_i;
bit [`WIDTH-1:0]wr_data_i;
bit full_o,error_o,empty_o;
bit [`WIDTH-1:0]rd_data_o;

clocking mon_cb @(posedge clk);
	default input #1;
	input rd_data_o,full_o,error_o,empty_o,wr_data_i,rd_enable_i,wr_enable_i;
endclocking

clocking drv_cb @(posedge clk);
	default input #0 output #1;
	input rd_enable_i,wr_enable_i,wr_data_i;
	output full_o,error_o,empty_o,rd_data_o;
endclocking
endinterface
