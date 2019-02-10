module apb_i2c_top;

`include "uvm_macros.svh"

import uvm_pkg::*;
import i2c_test_pkg::*;

bit clk;
bit rst;

initial begin
    clk=0;
 forever #5 clk = ~clk;
end

initial begin
rst = 1'b0;
repeat(2) @(posedge clk);
rst = 1'b1;
/*
repeat(2) @(posedge clk);
rst = 1'b0;
repeat(1) @(posedge clk);
rst = 1'b1;
*/
end

apb_i2c_intf ifi (clk,rst);

i2c_wrapper DUT (
                .pclk(clk),
                .presetn(rst),
                .paddr(ifi.paddr),
                .psel(ifi.psel),
                .penable(ifi.penable),
                .pwrite(ifi.pwrite),
                .pwdata(ifi.pwdata),
                .prdata(ifi.prdata),
                .pready(ifi.pready),
                .pslverr(ifi.pslverr),
               // .sda(ifi.sda),
                .scl(ifi.scl),
                .sda_in (ifi.sda_so),
                .sda_out(ifi.sda_si)
                );


initial begin
uvm_config_db#(virtual apb_i2c_intf)::set(null,"*","vif",ifi);
end


initial begin
run_test();
end

initial begin
    $shm_open("apb_i2c.shm");
    $shm_probe("ACTMF");    
end

endmodule
