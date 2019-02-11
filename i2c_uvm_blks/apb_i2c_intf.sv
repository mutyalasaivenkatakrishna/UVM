    parameter ADDR_WIDTH=8;	      //address width
	parameter DATA_WIDTH=32;	      //data width

`include "uvm_macros.svh"
import uvm_pkg::*;
interface apb_i2c_intf(input bit clk,rst);
logic psel;						  //psel input which helps to select the particular slave
logic pwrite;
logic penable;					  //input enable enables the access phase.
logic [ADDR_WIDTH-1:0]paddr;	  //address input
logic [DATA_WIDTH-1:0]pwdata;	  //write data input
	
logic pslverr;				  //pslverr is 1 when address is out off range for the slave
logic pready;				  //handshaking single 
logic [DATA_WIDTH-1:0]prdata;
tri1			sda;
logic			scl;

// Internal signals
  logic sda_out;   // what YOU drive
  logic sda_oe;    // output enable
  logic sda_in;    // what YOU read


    clocking drv_cb @(posedge clk);
        default input #1 output #0;
        input pslverr;
        input pready;
        input prdata;
        output psel;
        output pwrite;
        output penable;
        output paddr;
        output pwdata;
    endclocking


    // Monitor Clocking block
    clocking mon_cb @(posedge clk);
        default input #1;
        input pslverr;
        input pready;
        input prdata;
        input psel;
        input pwrite;
        input penable;
        input paddr;
        input pwdata;
    endclocking

clocking cb_s_mon @(posedge clk);
    default input #1 output #1;
    input sda;
    input scl;
endclocking 

// Tri-state control
  assign sda    = (sda_oe) ? sda_out : 1'bz;
  assign sda_in = sda;

//modport mod_drv (clocking cb_drv);

//modport mod_mon (clocking cb_mon);

modport mod_s_mon (clocking cb_s_mon);

modport drv_m (clocking drv_cb );

/*
//assertions

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

//cov_7 : cover property(p_sda_stable_except_start_stop);

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


////////////////////////////////////////////////////////

// PENABLE should never assert without PSEL
    property p_penable_protocol;
        @(posedge clk) disable iff(!rst)
        penable |-> psel;
    endproperty

    assert property(p_penable_protocol)
    else begin
        
        `uvm_error("APB_PROTOCOL","PENABLE should never assert without PSEL")
    end


// SETUP -> ACCESS transition
    property p_setup_to_access;
        @(posedge clk) disable iff(!rst)
        (psel && !penable) |=> (psel && penable);
    endproperty

    assert property(p_setup_to_access)
    else begin
        `uvm_error("APB_PROTOCOL","Invalid SETUP to ACCESS transition")
    end

//address and data stability when psel and penable is high
    property p_access_phase_checks;
        @(posedge clk) disable iff(!rst)
        (psel && penable) |-> ( pready && $stable(paddr) && $stable(pwrite) 
        && (!pwrite || $stable(pwdata)) && (pwrite || !$isunknown(prdata)) && !$isunknown(pslverr) );
    endproperty
   
    assert property(p_access_phase_checks)
    else begin
        `uvm_error("APB_ACCESS_PHASE","ACCESS phase protocol violation detected")
    end

    // IDLE PHASE CHECK
    property p_idle_phase_check;
        @(posedge clk) disable iff(!rst)
        (!psel) |-> (!penable);
    endproperty

    assert property(p_idle_phase_check)
    else begin
        `uvm_error("APB_IDLE_PHASE", "PENABLE HIGH during IDLE state")
    end

    // WRITE TRANSFER CHECK
    property p_write_transfer;

        @(posedge clk)
        disable iff(!rst)

        (psel && !penable && pwrite) |=> (psel && penable && pwrite && pready);
    endproperty

    assert property(p_write_transfer)
    else begin
        `uvm_error("APB_WRITE_TRANSFER","Invalid APB WRITE transfer")
    end

    // READ TRANSFER CHECK
    property p_read_transfer;
        @(posedge clk) disable iff(!rst)
        (psel && !penable && !pwrite) |=> (psel && penable && !pwrite && pready);
    endproperty

    assert property(p_read_transfer)
    else begin
        `uvm_error("APB_READ_TRANSFER", "Invalid APB READ transfer")
    end

    // PSLVERR VALIDITY CHECK
    property p_pslverr_valid;
        @(posedge clk) disable iff(!rst)
        pslverr |-> (psel && penable && pready);
    endproperty

    assert property(p_pslverr_valid)
    else begin
        `uvm_error("APB_PSLVERR","PSLVERR asserted outside valid ACCESS")
    end
    
    //when psel and penable is high, psel, penable must be high until pready is high.

    property p_pready;
        @(posedge clk) disable iff(!rst)
        (psel && penable && !pready) |-> (psel && penable) until pready;
    endproperty

    assert property(p_pready)
    else begin
        `uvm_error("APB_PREADY","PSEL & PENABLE NOT HIGH UNTIL PREADY")
    end
*/
endinterface



 
  
