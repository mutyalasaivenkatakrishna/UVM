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

cov_1 : cover property(p_start_to_first_ack);


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

cov_4 : cover property(p_no_repeated_start_before_stop);




property p_no_stop_before_first_ack;
  @(posedge clk) disable iff (rst)

  i2c_start |=> 
  (!($rose(sda_in) && scl)) throughout byte_with_ack;

endproperty

a_no_stop_before_first_ack:
assert property (p_no_stop_before_first_ack)
else
  $error("[%0t] I2C ASSERTION FAILED: SDA is changed while scl is high", $time);

cov_5 : cover property(p_no_stop_before_first_ack);



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

cov_6 : cover property(p_i2c_ack_nack_flow);



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


/*
sequence i2c_start_cond;
  $fell(sda) && scl;
endsequence

sequence i2c_stop_cond;
  $rose(sda) && scl;
endsequence
            
property i2c_count_based_check;
  int bit_cnt;

  @(posedge clk) disable iff (rst)

  // Detect START and initialize counter
  (i2c_start_cond, bit_cnt = 0)
  |->

  (
    // First byte: 8 data bits
    (
      @(negedge scl)
     // ##0 (scl == 1'b0, bit_cnt = bit_cnt + 1)
     $stable(sda) && scl
    )[*8]

    // 9th clock: ACK/NACK
    @(posedge scl)

    ##0
    (
      // NACK case: SDA = 1, then STOP should come
      (
        (sda == 1'b1)
        ##[0:$] i2c_stop_cond
      )

      or

      // ACK case: SDA = 0, next byte continues
      (
        (sda == 1'b0, bit_cnt = 0)

        // Next byte: 8 data bits
        ##0
        (
          ##[0:$] $fell(scl)
          ##0 (scl == 1'b0, bit_cnt = bit_cnt + 1)
        )[*8]

        // Next ACK/NACK
        ##[0:$] $fell(scl)

        // After this, STOP should come
        ##[0:$] i2c_stop_cond
      )
    )
  );

endproperty

assert property (i2c_count_based_check)
else
    $error($time,"i2c_protocol assertion failed");

*/
/*
////////////////////////////////////////////////////////////
// I2C PURE SVA ASSERTIONS
// No procedural block
// No timeout parameter
////////////////////////////////////////////////////////////

// START = SDA falling while SCL high
sequence s_i2c_start;
  $fell(sda_in) && scl;
endsequence

// STOP = SDA rising while SCL high
sequence s_i2c_stop;
  $rose(sda_in) && scl;
endsequence

// SCL falling edge
sequence s_scl_fall;
  $fell(scl);
endsequence

// One I2C byte = 8 SCL falling edges
sequence s_i2c_byte_done;
  $fell(scl)[=8];
endsequence

// ACK/NACK phase = next SCL falling edge after byte
// SDA should be known during ACK/NACK
sequence s_i2c_ack_phase;
  ##1 $fell(scl)[->1] ##0 !$isunknown(sda_in);
endsequence

////////////////////////////////////////////////////////////
// SDA DATA STABILITY
// SDA should not change while SCL is HIGH
// except START and STOP
////////////////////////////////////////////////////////////

property p_i2c_data_stable;
  @(posedge clk)
  disable iff (rst)

  (scl && $changed(sda_in)) |->
  (
    ($fell(sda_in) && scl) || ($rose(sda_in) && scl)
  );

endproperty

a_i2c_data_stable:
assert property (p_i2c_data_stable)
else
  $error("[%0t] I2C ASSERTION FAILED: SDA changed while SCL HIGH without START/STOP",
         $time);

  ////////////////////////////////////////////////////////////
// I2C SINGLE BYTE TRANSACTION CHECK
//
// START
// 8 SCL falling edges  -> address byte done
// next SCL falling edge -> address ACK/NACK
//
// if address NACK = 1:
//      STOP
//
// if address ACK = 0:
//      8 SCL falling edges  -> data byte done
//      next SCL falling edge -> data ACK/NACK
//      STOP
////////////////////////////////////////////////////////////

property p_i2c_start_addr_ack_data_ack_stop;
  @(posedge clk)
  disable iff (rst)

  s_i2c_start
  |->
  (
    ##1 s_i2c_byte_done
    ##0 s_i2c_ack_phase

    ##0
    (
      // Case 1: Address NACK, SDA = 1
      // Then transaction should go to STOP
      (
        (sda_in == 1'b1)
        ##[1:$] s_i2c_stop
      )

      or

      // Case 2: Address ACK, SDA = 0
      // Then continue data byte, ACK/NACK, then STOP
      (
        (sda_in == 1'b0)
        ##1 s_i2c_byte_done
        ##0 s_i2c_ack_phase
        ##[1:$] s_i2c_stop
      )
    )
  );

endproperty

a_i2c_start_addr_ack_data_ack_stop:
assert property (p_i2c_start_addr_ack_data_ack_stop)
else
  $error("[%0t] I2C ASSERTION FAILED: START/address ACK/data ACK/STOP flow violated",
         $time);



property p_scl_no_xz;
   @(posedge clk)
   disable iff(rst)

   !$isunknown(scl) &&  !$isunknown(sda);
endproperty

a_scl_no_xz:
assert property(p_scl_no_xz)
else
   $error("SCL contains X/Z"); 

*/





/*property p_start_cond;
      @(posedge clk)
      disable iff(rst)
      $fell(sda) && scl;
   endproperty

   a_start_cond:
   assert property(p_start_cond)
   else
       $error($time,"start failed"); */
/*
 property p_i2c_start_condition;
  @(posedge clk) disable iff (rst)
  $fell(sda_in) && (scl == 1'b1);
endproperty

cover property (p_i2c_start_condition);*/
 

/*
property p_i2c_start;
  @(posedge clk) disable iff (rst)

  1'b1 |->
    //  START condition:
    // SDA falling while SCL high is allowed only when bus is not active
    ((!($fell(sda_in) && scl)) || (!busy)); 
  ($fell(sda_in) && scl) |-> !busy;

        endproperty

assert property (p_i2c_start)
  else $error("I2C ASSERTION FAILED: START protocol violation");


    property p_i2c_noxz;
  @(posedge clk) disable iff (rst)

  1'b1 |->

    //  During active transfer, SDA/SCL should not be X/Z
    (busy && (!$isunknown(sda_in) && !$isunknown(scl))); 
     busy |-> (!$isunknown(sda_in) &&
              !$isunknown(scl));

    endproperty

assert property (p_i2c_noxz)
  else $error("I2C ASSERTION FAILED: X/Z protocol violation");



property p_i2c_data;
  @(posedge clk) disable iff (rst)

 // 1'b1 |->

    //  DATA stable rule:
    // During active transfer, if SCL is high, SDA should not change.
    !(busy && scl && $changed(sda_in) && !$rose(sda_in));
    
      endproperty

assert property (p_i2c_data)
  else $error("I2C ASSERTION FAILED: DATA protocol violation");

*/
 /*   
property p_i2c_ack;
  @(posedge clk) disable iff (rst)

 // 1'b1 |->

    //  ACK/NACK on 9th clock:
  //  i2c_active |-> ((scl_cnt == 4'd8) &&
     // (!$isunknown(sda_in)));   

   //  (busy && (scl_cnt == 4'd8) && scl)  |-> !$isunknown(sda);
   
    endproperty

assert property (p_i2c_ack)
   $display("ACK DETECTED at %0t", $time);
  else $error("I2C ASSERTION FAILED: ACK protocol violation");


property p_i2c_stop;
  @(posedge clk) disable iff (rst)

 // 1'b1 |->

    //  STOP condition:
    // STOP is SDA rising while SCL high.
    (!(i2c_active && $rose(sda_in) && scl) ||
      (i2c_active)); 
// i2c_active
 //  |-> !($rose(sda_in) && scl);
  (
      busy &&
      $rose(sda_in) &&
      scl
   )|-> (scl_cnt == 4'd0);

   endproperty
   
assert property (p_i2c_stop)
  else $error("I2C ASSERTION FAILED: STOP protocol violation");
*/

/*
property p_i2c_bus_idle;
  @(posedge clk) disable iff (rst)
  (!busy) |-> (sda_in == 1'b1 && scl == 1'b1);
endproperty */




//i2c_coverage: cover property (p_i2c_protocol_check)
//$display("coverage is passed");

  
/*assert property (p_i2c_bus_idle)
  else $error("[%0t] I2C ASSERTION FAILED: Bus not idle. SDA=%0b SCL=%0b",
              $time, sda_in, scl); */


endinterface



 
  
