interface i2c_master_if(input bit clk,rst);
logic	[6:0]   addr;
logic   [7:0]   din;
logic   [7:0]   dout;
logic			op;
logic			newd;
logic			done;
logic           busy;
logic           ack_err;
tri1			sda;
logic			scl;

// Internal signals
  logic sda_out;   // what YOU drive
  logic sda_oe;    // output enable
  logic sda_in;    // what YOU read


default clocking cb @(posedge clk);
  endclocking

clocking cb_drv @(posedge clk);
default input #1 output #1;
output newd;
output addr;
output op;
output din;
input done;
inout sda;
input scl;
input dout;
input busy;
input ack_err;

endclocking

clocking cb_mon @(posedge clk);
default input #1 output #1;
input newd;
input addr;
input op;
input din;
input done;
input sda;
input scl;
input dout;
input busy;
input ack_err;

endclocking

clocking cb_s_mon @(posedge clk);
default input #1 output #1;
input sda;
input scl;
input addr;
input din;
input dout;
input op;
input newd;
input done;
endclocking 

// Tri-state control
  assign sda    = (sda_oe) ? sda_out : 1'bz;
  assign sda_in = sda;

modport mod_drv (clocking cb_drv);

modport mod_mon (clocking cb_mon);

modport mod_s_mon (clocking cb_s_mon);

//modport mod_slave (clocking cb_slave);


////////////////////////////////////////////////////////////
// I2C BASIC SEQUENCES
////////////////////////////////////////////////////////////

sequence i2c_start;
  $fell(sda_in) && scl;
endsequence

sequence i2c_stop;
  $rose(sda_in) && scl;
endsequence



// 8 data/address bits + 1 ACK/NACK bit
sequence byte_with_ack;
  $fell(scl)[->9];
endsequence

sequence byte_ack0;
  $fell(scl)[->9] ##0 (sda_in == 1'b0);
endsequence

sequence byte_ack1;
  $fell(scl)[->9] ##0 (sda_in == 1'b1);
endsequence

sequence byte_ack_valid;
  $fell(scl)[->9] ##0 (sda_in inside {1'b0, 1'b1});
endsequence




property p_start_to_first_ack;
  @(posedge clk) disable iff (rst)

  i2c_start |-> byte_ack_valid;

endproperty

a_start_to_first_ack:
assert property (p_start_to_first_ack)
else
  $error("[%0t] I2C ASSERTION FAILED: START not followed by 8 bits + ACK/NACK", $time);

//cov_1 : cover property(p_start_to_first_ack);


property p_ack0_continue_next_byte;
  @(posedge clk) disable iff (rst)

  i2c_start ##0 byte_ack0 |-> ##1 byte_ack_valid;

endproperty

a_ack0_continue_next_byte:
assert property (p_ack0_continue_next_byte)
else
  $error("[%0t] I2C ASSERTION FAILED: ACK=0 not followed by next byte", $time);

cov_2 : cover property(p_ack0_continue_next_byte);


property p_second_byte_ack_to_stop;
  @(posedge clk) disable iff (rst)

  i2c_start
  ##0 byte_ack0
  ##1 byte_ack_valid
  |-> ##[1:$] i2c_stop;

endproperty

a_second_byte_ack_to_stop:
assert property (p_second_byte_ack_to_stop)
else
  $error("[%0t] I2C ASSERTION FAILED: Second byte ACK/NACK not followed by STOP", $time);

cov_3 : cover property(p_second_byte_ack_to_stop);




property p_no_repeated_start_before_stop;
  @(posedge clk) disable iff (rst)

  i2c_start |=> 
  (!($fell(sda_in) && scl)) until_with i2c_stop;

endproperty

a_no_repeated_start_before_stop:
assert property (p_no_repeated_start_before_stop)
else
  $error("[%0t] I2C ASSERTION FAILED: Illegal repeated START before STOP", $time);

//cov_4 : cover property(p_no_repeated_start_before_stop);




property p_no_stop_before_first_ack;
  @(posedge clk) disable iff (rst)

  i2c_start |=> 
  (!($rose(sda_in) && scl)) throughout byte_with_ack;

endproperty

a_no_stop_before_first_ack:
assert property (p_no_stop_before_first_ack)
else
  $error("[%0t] I2C ASSERTION FAILED: SDA is changed while scl is high", $time);

//cov_5 : cover property(p_no_stop_before_first_ack);



property p_i2c_ack_nack_flow;
  @(posedge clk) disable iff (rst)

  (
    (byte_ack0 |-> ##[1:$] byte_with_ack)
    and
    (byte_ack1 |-> ##[1:$] i2c_stop)
  );

endproperty

a_i2c_ack_nack_flow:
assert property (p_i2c_ack_nack_flow)
else
  $error("[%0t] I2C ASSERTION FAILED: ACK/NACK flow violation",
         $time);

//cov_6 : cover property(p_i2c_ack_nack_flow);



property p_sda_stable_except_start_stop;
  @(posedge clk) disable iff (rst)

  (scl && $changed(sda_in)) |->
  (
    ($fell(sda_in) && scl) || ($rose(sda_in) && scl)
  );

endproperty

a_sda_stable_except_start_stop:
assert property (p_sda_stable_except_start_stop)
else
  $error("[%0t] I2C ASSERTION FAILED: SDA changed while SCL HIGH without START/STOP", $time);

cov_7 : cover property(p_sda_stable_except_start_stop);

property no_unknown_xorz;
@(posedge clk) disable iff (rst)

i2c_start |->
  (
    (!$isunknown(sda_in) && !$isunknown(scl))
    until_with
    i2c_stop);
endproperty

no_z_or_x_in_trans :
assert property (no_unknown_xorz)
else
    $error("[%0t] I2C ASSERTION FAILED: SDA/SCL is found to be unknown", $time);

cov_8 : cover property(no_unknown_xorz);


endinterface



 
  
