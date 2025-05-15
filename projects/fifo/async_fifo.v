module fifo(w_clk_i,r_clk_i,rst_i,wr_enable_i,rd_enable_i,wr_data_i,rd_data_o,empty_o,full_o,error_o);

parameter DEPTH=10;
parameter WIDTH=10;
parameter AD_W=$clog2(DEPTH);
input w_clk_i,r_clk_i,rst_i,rd_enable_i,wr_enable_i;
input [WIDTH-1:0]wr_data_i;
output reg full_o,error_o,empty_o;
output reg [WIDTH-1:0]rd_data_o;
reg [AD_W-1:0]rd_ptr;
reg [AD_W-1:0]wr_ptr;
reg [AD_W-1:0]rd_ptr_wr_clk;
reg [AD_W-1:0]wr_ptr_rd_clk;
reg wr_toggle_f;
reg rd_toggle_f;
reg wr_toggle_rd_clk;
reg rd_toggle_wr_clk;
integer i;
reg [WIDTH-1:0]fifo[DEPTH-1:0];

always@(posedge w_clk_i)begin
	if(rst_i==1) begin
		full_o=0;
		empty_o=1;
		error_o=0;
		rd_data_o=0;
		rd_ptr=0;
		wr_ptr=0;
		rd_toggle_f=0;
		wr_toggle_f=0;
		for(i=0;i<=DEPTH-1;i=i+1) begin
			fifo[i]=0;
		end
	end
	else begin
		if(wr_enable_i==1) begin
			if(full_o==0) begin
				error_o=0;
				fifo[wr_ptr]=wr_data_i;
				if(wr_ptr==DEPTH-1) begin
					wr_ptr=0;
					wr_toggle_f=~wr_toggle_f;
				end
				else begin
					wr_ptr=wr_ptr+1;
				end
			end
			else begin
				error_o=1;
			end
		end
	end	
end
always@(posedge r_clk_i) begin
	if(rst_i==1) begin

	end
	else begin
		if(rd_enable_i==1) begin
			if(empty_o==0) begin
				error_o=0;
				rd_data_o=fifo[rd_ptr];
				if(rd_ptr==DEPTH-1) begin
					rd_ptr=0;
					rd_toggle_f=~rd_toggle_f;
				end
				else begin
					rd_ptr=rd_ptr+1;
				end
			 end
			 else begin
				error_o=1;
	 		 end
		end
	end
end
always@(*) begin
	full_o=0;
	empty_o=0;
	if(wr_ptr_rd_clk==rd_ptr && wr_toggle_rd_clk==rd_toggle_f)begin
		empty_o=1;	
	end
	if(wr_ptr==rd_ptr_wr_clk && wr_toggle_f!=rd_toggle_wr_clk)begin
		full_o=1;	
	end

end
always@(posedge w_clk_i) begin
	rd_toggle_wr_clk<=rd_toggle_f;
	rd_ptr_wr_clk<=rd_ptr;
end
always@(posedge r_clk_i) begin
	wr_toggle_rd_clk<=wr_toggle_f;
	wr_ptr_rd_clk<=wr_ptr;
end

endmodule
