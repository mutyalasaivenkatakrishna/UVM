module i2c_block;

`include "uvm_macros.svh"

import uvm_pkg::*;
import i2c_test_pkg::*;

bit clk;
bit rst;

always #5 clk = ~clk;

initial begin
rst = 1'b1;
repeat(2) @(posedge clk);
rst = 1'b0;
//@(posedge clk);
//rst = 1'b1;
//repeat(2)@(posedge clk);
//rst = 1'b0;  

end 



i2c_master_if ifi (clk,rst);

i2c_master DUT (
                .clk(clk),
                .rst(rst),
                .newd(ifi.newd),
                .addr(ifi.addr),
                .op(ifi.op),
                .din(ifi.din),
                .dout(ifi.dout),
                .done(ifi.done),
                .sda(ifi.sda),
                .scl(ifi.scl),
                .busy(ifi.busy),
                .ack_err(ifi.ack_err)

                );


initial begin
uvm_config_db#(virtual i2c_master_if)::set(null,"*","vif",ifi);
end


initial begin
run_test();
end 

initial begin
   //ifi.scl = 0;
 /*  #51500;
   force ifi.sda = 1;
   #20;
   release ifi.sda; 

    #38850;
    force ifi.sda = 1'bz;
    #20;
    release ifi.sda; */
                    
  /*  #72500;
    force ifi.sda = 1'b1;
    #20;
    release ifi.sda; */
end

initial begin
    $shm_open("i2c_waveform.shm");
    $shm_probe("ACTMF");    
end

endmodule
