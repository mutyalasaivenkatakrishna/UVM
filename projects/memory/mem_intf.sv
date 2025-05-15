interface mem_intf(input reg clk,input reg rst);
logic write_read_enable,valid;
logic [`SZ-1:0]address;
logic [`WIDTH-1:0]wr_data;
logic [`WIDTH-1:0]rdata;
logic ready;

clocking mon_cb@(posedge clk);
default input #1;
input address,wr_data,write_read_enable,valid,ready,rdata;
endclocking

clocking drv_cb@(posedge clk);
default input #0 output #1;
output address,wr_data,write_read_enable,valid;
input rdata,ready;
endclocking

endinterface
