/*
class i2c_slave_model extends uvm_component;

`uvm_component_utils(i2c_slave_model)

virtual apb_i2c_intf vif;

apb_tx tx; i2c_cfg cfg;

uvm_analysis_port #(apb_tx) i2c_slv;

//--------------------------------------------------
// Two-dimensional flat byte-addressable memory
// First  key = slave address  [6:0]
// Second key = register address [7:0]
// Each value = one data byte  [7:0]
//
// mem_data[slave_addr][reg_addr]
//
// Each slave address has a completely independent
// register space. A write to slave 0x50 reg 0x10
// never affects slave 0x60 reg 0x10.
//--------------------------------------------------
bit [7:0] mem_data[bit [6:0]][bit [7:0]];

// Per-slave register pointer.
// Set by register-address byte in a write.
// Auto-increments during multi-byte write/read.
// Persists across transactions for standalone reads.
bit [7:0] current_reg_addr[bit [6:0]];

function new(string name="i2c_slave_model",uvm_component parent);
  super.new(name,parent);
endfunction

//--------------------------------------------------
// BUILD PHASE
//--------------------------------------------------

function void build_phase(uvm_phase phase);

super.build_phase(phase);

i2c_slv = new("i2c_slv",this);

tx = apb_tx::type_id::create("tx");

if(!uvm_config_db#(virtual apb_i2c_intf)::get(this,"","vif",vif))
  `uvm_fatal("SLAVE","vif not set")

if(!uvm_config_db#(i2c_cfg)::get(this,"","cfg",cfg))
  `uvm_fatal("SLAVE","cfg not found")

endfunction

//--------------------------------------------------
// START DETECT
// SDA falls while SCL is high
//--------------------------------------------------

task wait_for_start();

bit prev;
prev = vif.sda_in;

forever begin
  @(vif.sda_in or vif.scl);
  if(vif.scl && prev && !vif.sda_in)
    break;
  prev = vif.sda_in;
end

endtask

//--------------------------------------------------
// STOP DETECT
// SDA rises while SCL is high
//--------------------------------------------------

task wait_for_stop();

bit prev;
prev = vif.sda_in;

forever begin
  @(vif.sda_in or vif.scl);
  if(vif.scl && !prev && vif.sda_in)
    break;
  prev = vif.sda_in;
end

endtask

//--------------------------------------------------
// ADDRESS MATCH
//--------------------------------------------------

function bit addr_match(bit [6:0] addr);

foreach(cfg.addr[i]) begin
  if(addr == cfg.addr[i])
    return 1;
end
return 0;

endfunction

//--------------------------------------------------
// RECEIVE BYTE
// Entry: SCL low, master driving bit[7] on SDA.
// Samples SDA on each of 8 rising SCL edges.
//--------------------------------------------------

task recv_byte(output bit [7:0] din);

for(int i=7;i>=0;i--) begin
  @(posedge vif.scl);
  din[i] = vif.sda_in;
end

endtask

//--------------------------------------------------
// RECEIVE BYTE CONTINUING
// check_stop_after_ack consumed the posedge for
// bit[7]. Caller passes that sampled value as msb.
// This task collects the remaining 7 bits only.
//--------------------------------------------------

task recv_byte_cont(input  bit       msb,
                    output bit [7:0] din);

din[7] = msb;

for(int i=6;i>=0;i--) begin
  @(posedge vif.scl);
  din[i] = vif.sda_in;
end

endtask

//--------------------------------------------------
// SEND ACK
// Entry : last data posedge seen by caller.
// Drives SDA low (ACK) or releases (NACK).
// Exit  : SCL low, SDA released.
//--------------------------------------------------

task send_ack(bit ack);

@(negedge vif.scl);

if(ack) begin
  vif.sda_out <= 1'b0;
  vif.sda_oe  <= 1'b1;
end
else begin
  vif.sda_oe  <= 1'b0;
end

@(posedge vif.scl);
@(negedge vif.scl);

vif.sda_oe <= 1'b0;

endtask

//--------------------------------------------------
// SEND BYTE
//--------------------------------------------------

task send_byte(input bit [7:0] dout);

`uvm_info(get_type_name(),$sformatf("dout=%b",dout),UVM_LOW)
for(int i=7;i>=0;i--) begin
  @(negedge vif.scl);
  if(dout[i] == 0) begin
    vif.sda_out <= 1'b0;
    vif.sda_oe  <= 1'b1;
  end
  else begin
    vif.sda_oe <= 1'b0;
  end
  @(posedge vif.scl);
end

@(negedge vif.scl);
vif.sda_oe <= 1'b0;

`uvm_info(get_type_name(),$sformatf("read byte complete dout=%b",dout),UVM_LOW)
endtask

//--------------------------------------------------
// MASTER ACK/NACK
// ACK  = SDA 0 while SCL high
// NACK = SDA 1 while SCL high
//--------------------------------------------------

task wait_master_ack(output bit nack);

@(posedge vif.scl);
nack = vif.sda_in;
@(negedge vif.scl);

endtask

//--------------------------------------------------
// CHECK STOP AFTER ACK
//
// Entry : send_ack() just completed its final
//         @(negedge scl). SCL is LOW. SDA released.
//
// This is the ONLY legal window to detect STOP
// on I2C — after the ACK clock, before the next
// data bit.
//
// Algorithm:
//   Step 1 — wait for posedge SCL.
//             Immediately sample SDA ? sda_at_rise.
//             This is bit[7] of the next byte if
//             data is coming, or SDA=0 if STOP is
//             being set up (master holds SDA low
//             through ACK and releases it only after
//             SCL goes high).
//
//   Step 2 — fork two threads:
//
//     sda_change_thread:
//       Captures SDA level before waiting
//       (sda_before_change = vif.sda_in, read
//       immediately after fork while SCL is still
//       high and SDA is stable).
//       Then waits for @(vif.sda_in).
//       Checks transition direction:
//         0?1 : genuine STOP  ? is_stop=1
//         1?0 : repeated START (not supported)
//               ? is_stop=1, end transaction
//         other: conservative ? is_stop=1
//
//     scl_fall_thread:
//       Waits for @(negedge vif.scl).
//       SCL fell before SDA changed ? data bit.
//       is_stop=0, bit7=sda_at_rise.
//
//   join_any + disable fork.
//
// Why bytes with MSB=1 do NOT false-trigger STOP:
//   Master drives SDA=1 before SCL rises.
//   sda_at_rise=1. SDA stays 1 (stable data).
//   No SDA transition occurs ? sda_change_thread
//   never fires ? scl_fall_thread wins ? data.
//
// Why STOP is correctly detected:
//   Master holds SDA=0 through ACK, SCL rises,
//   sda_at_rise=0, then master releases SDA?1
//   while SCL still high ? sda_change_thread fires,
//   sda_before_change=0, vif.sda_in=1 ? confirmed
//   0?1 edge ? is_stop=1.
//
// Outputs:
//   is_stop — 1 = STOP or RS detected, end transfer
//   bit7    — valid only when is_stop=0
//             = bit[7] of the incoming data byte
//--------------------------------------------------

task check_stop_after_ack(output bit is_stop,
                           output bit bit7);

bit sda_at_rise;
bit sda_before_change;

is_stop = 0;
bit7    = 0;

// Step 1: wait for SCL to rise, sample SDA immediately
@(posedge vif.scl);
sda_at_rise = vif.sda_in;

// Step 2: race SDA-change vs SCL-fall
fork : detect_stop_or_data

  begin : sda_change_thread
    // Read SDA now — SCL is high, SDA is stable.
    // This is the pre-transition level needed for
    // direction check after @(vif.sda_in) fires.
    sda_before_change = vif.sda_in;

    @(vif.sda_in);

    if(!sda_before_change && vif.sda_in) begin
      // Confirmed STOP: SDA 0?1 while SCL=1
      is_stop = 1;
    end
    else if(sda_before_change && !vif.sda_in) begin
      // Repeated START: SDA 1?0 while SCL=1
      // Not supported — end transaction cleanly
      is_stop = 1;
    end
    else begin
      // Unexpected glitch — treat conservatively
      is_stop = 1;
    end
  end

  begin : scl_fall_thread
    @(negedge vif.scl);
    // SCL fell before SDA changed — normal data bit
    is_stop = 0;
    bit7    = sda_at_rise;
  end

join_any
disable fork;

endtask

//--------------------------------------------------
// MAIN I2C LOOP
//--------------------------------------------------

task run();

bit [7:0] addr_byte;
bit [6:0] addr;
bit       rw;
bit [7:0] reg_addr;
bit [7:0] din;
bit       is_stop;
bit       bit7;

vif.sda_oe  <= 1'b0;
vif.sda_out <= 1'b0;

// Initialise register pointer for every slave
// address this model is configured to respond to
foreach(cfg.addr[i])
  current_reg_addr[cfg.addr[i]] = 8'h00;

forever begin

  //--------------------------------------
  // START
  //--------------------------------------

  wait_for_start();

  //--------------------------------------
  // ADDRESS + RW
  //--------------------------------------

  recv_byte(addr_byte);

  addr = addr_byte[7:1];
  rw   = addr_byte[0];

  //--------------------------------------
  // ADDRESS CHECK
  //--------------------------------------

  if(addr_match(addr))
    send_ack(1);
  else begin
    send_ack(0);
    wait_for_stop();
    continue;
  end

  //--------------------------------------
  // WRITE OPERATION
  //
  // Protocol:
  //   START ADDR+W ACK REG ACK D0 ACK D1 ACK ... STOP
  //
  // Memory behaviour:
  //   D0 ? mem_data[addr][reg_addr]
  //   D1 ? mem_data[addr][reg_addr+1]
  //   ...
  //   Only bytes actually received are written.
  //   All other addresses in all slave spaces
  //   are completely untouched.
  //--------------------------------------

  if(rw == 0) begin

    //------------------------------------
    // REGISTER ADDRESS BYTE
    //------------------------------------

    recv_byte(reg_addr);
    send_ack(1);

    // Set this slave's register pointer
    current_reg_addr[addr] = reg_addr;

    //------------------------------------
    // VARIABLE LENGTH DATA BYTES
    //
    // check_stop_after_ack detects STOP via
    // confirmed SDA 0?1 edge while SCL=1.
    // No fork races on data bytes — bytes
    // with MSB=1 handled correctly because
    // stable SDA=1 produces no transition.
    //------------------------------------

    forever begin

      check_stop_after_ack(is_stop, bit7);

      if(is_stop)
        break;

      // bit[7] captured in check_stop_after_ack
      // collect remaining 7 bits
      recv_byte_cont(bit7, din);

      // Write to this slave's space only
      mem_data[addr][current_reg_addr[addr]] = din;

      `uvm_info("SLAVE",
        $sformatf("WRITE slave=0x%02h reg=0x%02h data=0x%02h",
                  addr,
                  current_reg_addr[addr],
                  din), UVM_LOW)

      send_ack(1);

      // Advance this slave's pointer only
      current_reg_addr[addr]++;

    end
    // STOP already consumed inside check_stop_after_ack
    // wait_for_stop() intentionally not called here

  end

  //--------------------------------------
  // READ OPERATION
  //
  // Protocol (standalone — no repeated start):
  //   START ADDR+R ACK D0 ACK D1 ACK ... NACK STOP
  //
  // Reads sequentially from this slave's space
  // starting at current_reg_addr[addr] which was
  // set by the last write to this slave address.
  // Each byte sent advances this slave's pointer.
  // Addresses never written return 0x00.
  //--------------------------------------

  else begin

    bit nack;

    forever begin

      // Initialise unwritten register to 0x00
      // inside this slave's space only
      if(!mem_data[addr].exists(current_reg_addr[addr]))
        mem_data[addr][current_reg_addr[addr]] = 8'h00;

      send_byte(mem_data[addr][current_reg_addr[addr]]);

      `uvm_info("SLAVE",
        $sformatf("READ  slave=0x%02h reg=0x%02h data=0x%02h",
                  addr,
                  current_reg_addr[addr],
                  mem_data[addr][current_reg_addr[addr]]), UVM_LOW)

      wait_master_ack(nack);
      $display($time," nack=%b",nack);
      // Advance this slave's pointer
      current_reg_addr[addr]++;

      if(nack)
        break;

    end

    wait_for_stop();

  end

end

endtask

//--------------------------------------------------
// RUN PHASE
//--------------------------------------------------

task run_phase(uvm_phase phase);

super.run_phase(phase);

$display("before mem=%p",mem_data);
run();
$display("after mem=%p",mem_data);
endtask

endclass
*/
/*
class i2c_slave_model extends uvm_component;

`uvm_component_utils(i2c_slave_model)

virtual apb_i2c_intf vif;

apb_tx tx; i2c_cfg cfg;

uvm_analysis_port #(apb_tx) i2c_slv;

bit [7:0] mem_data[bit [6:0]][bit [7:0]];
bit [7:0] current_reg_addr[bit [6:0]];

function new(string name="i2c_slave_model",uvm_component parent);
  super.new(name,parent);
endfunction

//--------------------------------------------------
// BUILD PHASE
//--------------------------------------------------

function void build_phase(uvm_phase phase);

super.build_phase(phase);

i2c_slv = new("i2c_slv",this);
tx      = apb_tx::type_id::create("tx");

if(!uvm_config_db#(virtual apb_i2c_intf)::get(this,"","vif",vif))
  `uvm_fatal("SLAVE","vif not set")

if(!uvm_config_db#(i2c_cfg)::get(this,"","cfg",cfg))
  `uvm_fatal("SLAVE","cfg not found")

endfunction

//--------------------------------------------------
// DRIVE SDA — only callable while SCL is low
// Uses blocking assign so SDA is settled before
// the next posedge SCL in the caller.
//--------------------------------------------------

task drive_sda(input bit val);
  vif.sda_oe  = 1'b1;
  vif.sda_out = val;
endtask

task release_sda();
  vif.sda_oe  = 1'b0;
  vif.sda_out = 1'b1;
endtask

//--------------------------------------------------
// START DETECT
//--------------------------------------------------

task wait_for_start();

bit prev;
prev = vif.sda_in;

forever begin
  @(vif.sda_in or vif.scl);
  if(vif.scl && prev && !vif.sda_in)
    break;
  prev = vif.sda_in;
end

endtask

//--------------------------------------------------
// STOP DETECT
//--------------------------------------------------

task wait_for_stop();

bit prev;
prev = vif.sda_in;

forever begin
  @(vif.sda_in or vif.scl);
  if(vif.scl && !prev && vif.sda_in) begin
    //@(negedge vif.scl);
    break;
  end  
  prev = vif.sda_in;
end

endtask

//--------------------------------------------------
// ADDRESS MATCH
//--------------------------------------------------

function bit addr_match(bit [6:0] addr);

foreach(cfg.addr[i])
  if(addr == cfg.addr[i])
    return 1;
return 0;

endfunction

//--------------------------------------------------
// RECEIVE BYTE
// Entry : SCL low, master driving SDA.
// Exit  : SCL high (last posedge seen).
//--------------------------------------------------

task recv_byte(output bit [7:0] din);

for(int i=7;i>=0;i--) begin
  @(posedge vif.scl);
  din[i] = vif.sda_in;
end

endtask

//--------------------------------------------------
// RECEIVE BYTE CONTINUING
// bit[7] already sampled by check_stop_after_ack.
// Collects bits[6:0] only.
// Exit : SCL high (last posedge seen).
//--------------------------------------------------

task recv_byte_cont(input  bit       msb,
                    output bit [7:0] din);

din[7] = msb;
for(int i=6;i>=0;i--) begin
  @(posedge vif.scl);
  din[i] = vif.sda_in;
end

endtask

//--------------------------------------------------
// SEND ACK  (slave ? master)
//
// Entry : SCL high (last recv posedge seen).
// Sequence:
//   negedge SCL ? SCL low  ? drive SDA=0 (ACK)
//   posedge SCL ? SCL high ? master sees ACK
//   negedge SCL ? SCL low  ? slave releases SDA
//                             BUT does NOT call
//                             release_sda() here.
//                             Caller is responsible
//                             for SDA after this point.
//
// Exit : SCL low. SDA still driven low from ACK.
//        Caller MUST immediately drive or release
//        SDA in the same SCL-low window.
//
// Why no release_sda() at end:
//   The exit negedge is the SAME window where the
//   caller needs to drive bit[7] (send_byte) or
//   set up for STOP check (check_stop_after_ack).
//   Releasing here and driving in caller both happen
//   at the same sim-time — last write wins, causing
//   SDA glitch. Instead, caller takes full ownership
//   of SDA from this negedge onward.
//--------------------------------------------------

task send_ack(bit ack);

@(negedge vif.scl);
// SCL low — drive ACK or NACK
if(ack)
  drive_sda(1'b0);
else
  release_sda();

@(posedge vif.scl);
// SCL high — master samples ACK

@(negedge vif.scl);
// SCL low — ACK slot closed
// Intentionally NO release_sda() here.
// Caller owns SDA from this point.

endtask

//--------------------------------------------------
// SEND BYTE  (slave ? master)
//
// Entry : SCL low. Caller has NOT touched SDA yet
//         in this SCL-low window.
//         (send_ack left SDA driven low from ACK;
//          or wait_master_ack exited on negedge)
//
// Immediately drives bit[7] on entry — no extra
// @(negedge scl) wait — because we are already
// in the correct SCL-low window.
//
// Per-bit sequence:
//   drive_sda(bit[i])  — SCL low, blocking ?
//   @(posedge scl)     — master samples, SDA stable
//   @(negedge scl)     — next bit window
//   (for i=0: negedge handled separately below)
//
// After bit[0] posedge:
//   @(negedge scl)     — ACK slot opens, SCL low
//   release_sda()      — slave releases, master drives ACK
//
// Exit: SCL low, SDA released.
//--------------------------------------------------

task send_byte(input bit [7:0] dout);

for(int i=7;i>=0;i--) begin

  //------------------------------------------------
  // SCL is low here — drive SDA immediately.
  // Blocking assign settles SDA before posedge SCL.
  //------------------------------------------------
  if(dout[i] == 1'b0)
    drive_sda(1'b0);
  else
    release_sda();
  //------------------------------------------------

  // Master samples here — SDA must be stable
  @(posedge vif.scl);

  // Move to next bit window — skip for last bit
  if(i != 0)
    @(negedge vif.scl);

end

// bit[0] posedge done — wait for ACK slot to open
@(negedge vif.scl);

// SCL low — release SDA for master to drive ACK
release_sda();

endtask

//--------------------------------------------------
// WAIT MASTER ACK
//
// Entry : SCL low, SDA released by send_byte.
//         Master is settling SDA for ACK/NACK.
// Exit  : SCL low (negedge seen after ACK posedge).
//--------------------------------------------------

task wait_master_ack(output bit nack);

@(posedge vif.scl);
nack = vif.sda_in;    // 0=ACK  1=NACK
@(negedge vif.scl);

endtask

//--------------------------------------------------
// CHECK STOP AFTER ACK
//
// Entry : send_ack() just exited.
//         SCL low. SDA still driven low (ACK level).
//         Slave must release SDA FIRST so master
//         can drive it, then we observe.
//
// Sequence:
//   release_sda()       — SCL low, slave releases ?
//   @(posedge scl)      — SCL rises
//   sample sda_at_rise  — bit[7] of next byte OR
//                         0 if STOP setup
//   fork:
//     sda_change_thread — SDA changes while SCL high
//       0?1 : STOP  ? is_stop=1
//       1?0 : RS    ? is_stop=1
//     scl_fall_thread   — SCL falls before SDA changes
//       ? data bit, is_stop=0, bit7=sda_at_rise
//   join_any + disable fork
//
// Exit:
//   is_stop=1 : STOP consumed, transaction ends.
//   is_stop=0 : SCL low (scl_fall_thread won).
//               bit7 = bit[7] of next data byte.
//               Caller proceeds to recv_byte_cont.
//--------------------------------------------------

task check_stop_after_ack(output bit is_stop,
                           output bit bit7);

bit sda_at_rise;
bit sda_before_change;

is_stop = 0;
bit7    = 0;

//----------------------------------------------------
// Release SDA now — SCL is low.
// send_ack left SDA driven low (ACK).
// Master cannot drive SDA while slave holds it.
// We must release here so master can:
//   a) drive bit[7]=0/1 of next byte, OR
//   b) raise SDA for STOP after SCL goes high.
//----------------------------------------------------
release_sda();

// Wait for SCL to rise
@(posedge vif.scl);

// SCL is high — sample SDA immediately
// This is bit[7] of next byte (if data)
// or 0 still (if master is setting up STOP —
// master raises SDA AFTER SCL goes high for STOP)
sda_at_rise = vif.sda_in;

// Race: does SDA change (STOP/RS) or SCL fall (data)?
fork : detect_stop_or_data

  begin : sda_change_thread
    sda_before_change = vif.sda_in;
    @(vif.sda_in);
    // SDA changed while SCL was high
    if(!sda_before_change && vif.sda_in)
      is_stop = 1;    // STOP  : 0?1 confirmed
    else if(sda_before_change && !vif.sda_in)
      is_stop = 1;    // RS    : 1?0 unsupported
    else
      is_stop = 1;    // Glitch: conservative
  end

  begin : scl_fall_thread
    @(negedge vif.scl);
    // SCL fell before SDA changed ? data bit
    is_stop = 0;
    bit7    = sda_at_rise;
  end

join_any
disable fork;

endtask

//--------------------------------------------------
// MAIN I2C LOOP
//--------------------------------------------------

task run();

bit [7:0] addr_byte;
bit [6:0] addr;
bit       rw;
bit [7:0] reg_addr;
bit [7:0] din;
bit       is_stop;
bit       bit7;
bit       nack;

// Blocking init
vif.sda_oe  = 1'b0;
vif.sda_out = 1'b1;

foreach(cfg.addr[i])
  current_reg_addr[cfg.addr[i]] = 8'h00;

forever begin

  //--------------------------------------
  // START
  //--------------------------------------

  wait_for_start();

  //--------------------------------------
  // ADDRESS + RW  (master drives)
  //--------------------------------------

  recv_byte(addr_byte);

  addr = addr_byte[7:1];
  rw   = addr_byte[0];

  //--------------------------------------
  // ADDRESS CHECK
  //--------------------------------------

  if(addr_match(addr))
    send_ack(1);
  else begin
    // send_ack exits SCL low, SDA driven low.
    // release here before waiting for stop.
    release_sda();
    wait_for_stop();
    continue;
  end

  //--------------------------------------
  // WRITE OPERATION
  //--------------------------------------

  if(rw == 0) begin

    // send_ack exited SCL low, SDA driven low.
    // recv_byte waits for posedge SCL — master
    // will drive SDA for reg_addr byte.
    // release SDA first so master can drive.
    release_sda();

    recv_byte(reg_addr);
    send_ack(1);

    current_reg_addr[addr] = reg_addr;

    forever begin

      // check_stop_after_ack releases SDA internally
      // before observing — correct SCL-low window.
      check_stop_after_ack(is_stop, bit7);

      if(is_stop)
        break;

      recv_byte_cont(bit7, din);

      mem_data[addr][current_reg_addr[addr]] = din;

      `uvm_info("SLAVE",
        $sformatf("WRITE slave=0x%02h reg=0x%02h data=0x%02h",
                  addr, current_reg_addr[addr], din),
        UVM_HIGH)

      send_ack(1);

      current_reg_addr[addr]++;

    end

  end

  //--------------------------------------
  // READ OPERATION
  //
  // send_ack(1) for address exits:
  //   SCL low, SDA still driven low (ACK).
  // send_byte entry: SCL low, drives bit[7]
  //   immediately — takes ownership of SDA
  //   in the same SCL-low window.
  //   No conflict because send_ack did NOT
  //   call release_sda() on exit.
  //
  // wait_master_ack exits:
  //   SCL low, SDA released by send_byte.
  // send_byte entry: SCL low, drives bit[7]
  //   immediately — same clean window.
  //--------------------------------------

  else begin

    forever begin

      if(!mem_data[addr].exists(current_reg_addr[addr]))
        mem_data[addr][current_reg_addr[addr]] = 8'h00;

      // SCL low on entry — bit[7] driven immediately
      send_byte(mem_data[addr][current_reg_addr[addr]]);

      `uvm_info("SLAVE",
        $sformatf("READ  slave=0x%02h reg=0x%02h data=0x%02h",
                  addr, current_reg_addr[addr],
                  mem_data[addr][current_reg_addr[addr]]),
        UVM_LOW)

      wait_master_ack(nack);

      current_reg_addr[addr]++;

      if(nack)
        break;

    end

    wait_for_stop();

  end

end

endtask

//--------------------------------------------------
// RUN PHASE
//--------------------------------------------------

task run_phase(uvm_phase phase);

super.run_phase(phase);

run();

endtask

endclass
*/

/*
class i2c_slave_model extends uvm_component;

`uvm_component_utils(i2c_slave_model)

virtual apb_i2c_intf vif;

apb_tx tx; i2c_cfg cfg;

uvm_analysis_port #(apb_tx) i2c_slv;

//--------------------------------------------------
// Two-dimensional flat byte-addressable memory
// mem_data[slave_addr][reg_addr] = data_byte
// Each slave address has completely independent
// register space.
//--------------------------------------------------
bit [7:0] mem_data[bit [6:0]][bit [7:0]];

// Per-slave register pointer.
// Set by register-address byte in a write.
// Auto-increments during multi-byte write/read.
// Persists across transactions for standalone reads.
bit [7:0] current_reg_addr[bit [6:0]];

function new(string name="i2c_slave_model",uvm_component parent);
  super.new(name,parent);
endfunction

//--------------------------------------------------
// BUILD PHASE
//--------------------------------------------------

function void build_phase(uvm_phase phase);

super.build_phase(phase);

i2c_slv = new("i2c_slv",this);

tx = apb_tx::type_id::create("tx");

if(!uvm_config_db#(virtual apb_i2c_intf)::get(this,"","vif",vif))
  `uvm_fatal("SLAVE","vif not set")

if(!uvm_config_db#(i2c_cfg)::get(this,"","cfg",cfg))
  `uvm_fatal("SLAVE","cfg not found")

endfunction

//--------------------------------------------------
// START DETECT
// SDA falls while SCL is high
//--------------------------------------------------

task wait_for_start();

bit prev;
prev = vif.sda_in;

forever begin
  @(vif.sda_in or vif.scl);
  if(vif.scl == 1 && prev == 1 && vif.sda_in == 0)
    break;
  prev = vif.sda_in;
end

endtask

//--------------------------------------------------
// STOP DETECT
// SDA rises while SCL is high
//--------------------------------------------------

task wait_for_stop();

bit prev;
prev = vif.sda_in;

forever begin
  @(vif.sda_in or vif.scl);
  if(vif.scl == 1 && prev == 0 && vif.sda_in == 1)
    break;
  prev = vif.sda_in;
end

endtask

//--------------------------------------------------
// ADDRESS MATCH
//--------------------------------------------------

function bit addr_match(bit [6:0] addr);

foreach(cfg.addr[i]) begin
  if(addr == cfg.addr[i])
    return 1;
end
return 0;

endfunction

//--------------------------------------------------
// RECEIVE BYTE
// Entry : SCL low, master driving SDA.
// Samples on each of 8 posedge SCL.
// Exit  : SCL high (last posedge seen).
//--------------------------------------------------

task recv_byte(output bit [7:0] din);

for(int i=7;i>=0;i--) begin
  @(posedge vif.scl);
  din[i] = vif.sda_in;
end

endtask

//--------------------------------------------------
// SEND ACK  (slave ? master)
//
// Taken directly from working single-byte code.
// Uses non-blocking <= exactly as working code does.
//
// Entry : SCL high (last posedge from recv_byte).
// @(negedge scl) — SCL goes low
// drive SDA      — NBA <= schedules update,
//                  SDA settles before next posedge
// @(posedge scl) — master samples ACK
// @(negedge scl) — ACK slot closes, SCL low
// release SDA    — NBA <=
//
// Exit : SCL low, SDA released.
//--------------------------------------------------

task send_ack(bit ack);

@(negedge vif.scl);

if(ack) begin
  vif.sda_out <= 1'b0;
  vif.sda_oe  <= 1'b1;
end
else begin
  vif.sda_oe  <= 1'b0;
end

@(posedge vif.scl);
@(negedge vif.scl);

vif.sda_oe <= 1'b0;

endtask

//--------------------------------------------------
// SEND BYTE  (slave ? master)
//
// Taken directly from working single-byte code.
//
// Key insight from working code:
//   bit[7] is driven BEFORE the loop starts —
//   not inside @(negedge scl). This means bit[7]
//   is driven in the same SCL-low window that the
//   caller (send_ack or wait_master_ack) left us
//   in. No extra negedge wait before first bit.
//
//   Loop then runs from bit[6] down to 0:
//     @(negedge scl) — SCL falls
//     drive SDA      — NBA <= during low window
//     @(posedge scl) — master samples
//
// After bit[0] posedge:
//   @(negedge scl)   — ACK slot opens
//   release SDA      — NBA <=
//
// Exit : SCL low, SDA released.
//--------------------------------------------------

task send_byte(input bit [7:0] dout);

// Drive bit[7] immediately — SCL is already low
// on entry. NBA schedules before next posedge.
if(dout[7] == 1'b0) begin
  vif.sda_out <= 1'b0;
  vif.sda_oe  <= 1'b1;
end
else begin
  vif.sda_oe <= 1'b0;
end

// Loop bit[6] down to bit[0]
for(int i=6;i>=0;i--) begin

  @(negedge vif.scl);   // SCL falls — bit window opens

  if(dout[i] == 1'b0) begin
    vif.sda_out <= 1'b0;
    vif.sda_oe  <= 1'b1;
  end
  else begin
    vif.sda_oe <= 1'b0;
  end

  @(posedge vif.scl);   // master samples this bit

end

// bit[0] posedge done — open ACK slot
@(negedge vif.scl);
vif.sda_oe <= 1'b0;     // release SDA for master ACK

endtask

//--------------------------------------------------
// WAIT MASTER ACK  (master ? slave)
//
// Taken from working single-byte code.
// Entry : SCL low, SDA released.
// Samples SDA on posedge SCL.
// Exit  : SCL low (negedge after posedge).
//--------------------------------------------------

task wait_master_ack(output bit nack);

@(posedge vif.scl);
nack = vif.sda_in;      // 0=ACK  1=NACK
@(negedge vif.scl);

endtask

//--------------------------------------------------
// CHECK STOP AFTER ACK
//
// Entry : send_ack() just completed.
//         SCL low, SDA released (sda_oe=0).
//
// Called only in write path after each data ACK.
// Slave observes bus only — no SDA driving here.
//
// I2C STOP : SDA 0?1 while SCL=1
// I2C RS   : SDA 1?0 while SCL=1 (unsupported)
// Data     : SCL falls before SDA changes
//
// Uses same fork pattern — no hardcoded delays,
// no level-sensitive waits. Pure edge detection.
//
// sda_at_rise : sampled immediately after posedge
//               SCL — this is bit[7] if data comes,
//               or 0 if STOP being set up.
//
// sda_change_thread : captures SDA before @sda_in,
//                     checks direction after change.
// scl_fall_thread   : SCL fell first ? data bit.
//
// Bytes with MSB=1: SDA=1 stable, no transition,
//   scl_fall_thread wins correctly.
//
// Exit is_stop=0 : SCL low (scl_fall won).
//                  bit7 = bit[7] of next byte.
// Exit is_stop=1 : STOP consumed.
//--------------------------------------------------

task check_stop_after_ack(output bit is_stop,
                           output bit bit7);

bit sda_at_rise;
bit sda_before_change;

is_stop = 0;
bit7    = 0;

@(posedge vif.scl);
sda_at_rise = vif.sda_in;

fork : detect_stop_or_data

  begin : sda_change_thread
    sda_before_change = vif.sda_in;
    @(vif.sda_in);
    if(!sda_before_change && vif.sda_in)
      is_stop = 1;      // STOP  : 0?1
    else if(sda_before_change && !vif.sda_in)
      is_stop = 1;      // RS    : 1?0 unsupported
    else
      is_stop = 1;      // Glitch: conservative
  end

  begin : scl_fall_thread
    @(negedge vif.scl);
    is_stop = 0;
    bit7    = sda_at_rise;
  end

join_any
disable fork;

endtask

//--------------------------------------------------
// RECEIVE BYTE CONTINUING
//
// Used after check_stop_after_ack returns is_stop=0.
// check_stop_after_ack consumed posedge for bit[7].
// bit[7] already sampled and passed as msb.
// This task collects bits[6:0] only.
// Exit : SCL high (last posedge seen).
//--------------------------------------------------

task recv_byte_cont(input  bit       msb,
                    output bit [7:0] din);

din[7] = msb;

for(int i=6;i>=0;i--) begin
  @(posedge vif.scl);
  din[i] = vif.sda_in;
end

endtask

//--------------------------------------------------
// MAIN I2C LOOP
//--------------------------------------------------

task run();

bit [7:0] addr_byte;
bit [6:0] addr;
bit       rw;
bit [7:0] reg_addr;
bit [7:0] din;
bit       is_stop;
bit       bit7;
bit       nack;

vif.sda_oe  = 1'b0;
vif.sda_out = 1'b0;

// Initialise per-slave register pointers
foreach(cfg.addr[i])
  current_reg_addr[cfg.addr[i]] = 8'h00;

forever begin

  //--------------------------------------
  // START
  //--------------------------------------

  wait_for_start();

  //--------------------------------------
  // ADDRESS + RW  (master drives)
  //--------------------------------------

  recv_byte(addr_byte);

  addr = addr_byte[7:1];
  rw   = addr_byte[0];

  //--------------------------------------
  // ADDRESS CHECK
  //--------------------------------------

  if(addr_match(addr))
    send_ack(1);
  else begin
    send_ack(0);
    wait_for_stop();
    continue;
  end

  //--------------------------------------
  // WRITE OPERATION
  //
  // START ADDR+W ACK REG ACK D0 ACK D1 ACK ... STOP
  //
  // send_ack exits: SCL low, sda_oe=0.
  // Master drives reg_addr byte.
  // recv_byte waits posedge — correct entry. ?
  //
  // After reg_addr ACK:
  //   check_stop_after_ack observes bus.
  //   If data: recv_byte_cont collects bits[6:0].
  //   send_ack drives ACK — NBA <=, SCL low. ?
  //   Loop repeats until STOP seen.
  //--------------------------------------

  if(rw == 0) begin

    // Receive register address byte
    recv_byte(reg_addr);
    send_ack(1);

    current_reg_addr[addr] = reg_addr;

    forever begin

      // Observe only — no SDA driving in here
      check_stop_after_ack(is_stop, bit7);

      if(is_stop)
        break;

      // bit[7] already captured — get bits[6:0]
      recv_byte_cont(bit7, din);

      mem_data[addr][current_reg_addr[addr]] = din;

      `uvm_info("SLAVE",
        $sformatf("WRITE slave=0x%02h reg=0x%02h data=0x%02h",
                  addr, current_reg_addr[addr], din),
        UVM_LOW)

      send_ack(1);

      current_reg_addr[addr]++;

    end
    // STOP consumed inside check_stop_after_ack

  end

  //--------------------------------------
  // READ OPERATION
  //
  // START ADDR+R ACK D0 M-ACK D1 M-ACK ... M-NACK STOP
  //
  // send_ack(1) for address exits:
  //   SCL low, sda_oe=0 (NBA flushed). ?
  //   send_byte drives bit[7] immediately — same
  //   SCL-low window, no extra negedge wait.
  //   NBA for bit[7] schedules before next posedge.
  //   SDA settles during low — not on edge. ?
  //
  // wait_master_ack exits on @(negedge scl):
  //   SCL low. ?
  //   Next send_byte drives bit[7] immediately. ?
  //
  // NBA <= used throughout send_byte and send_ack
  // ensures SDA transitions happen during SCL-low
  // period — identical to working single-byte code.
  //--------------------------------------

  else begin

    forever begin

      if(!mem_data[addr].exists(current_reg_addr[addr]))
        mem_data[addr][current_reg_addr[addr]] = 8'h00;

      // SCL low on entry — bit[7] driven immediately
      send_byte(mem_data[addr][current_reg_addr[addr]]);

      `uvm_info("SLAVE",
        $sformatf("READ  slave=0x%02h reg=0x%02h data=0x%02h",
                  addr, current_reg_addr[addr],
                  mem_data[addr][current_reg_addr[addr]]),
        UVM_LOW)

      // SCL low, sda_oe=0 — sample master ACK/NACK
      wait_master_ack(nack);

      current_reg_addr[addr]++;

      if(nack)
        break;

    end

    wait_for_stop();

  end

end

endtask

//--------------------------------------------------
// RUN PHASE
//--------------------------------------------------

task run_phase(uvm_phase phase);

super.run_phase(phase);

run();

endtask

endclass
*/

class i2c_slave_model extends uvm_component;

`uvm_component_utils(i2c_slave_model)

virtual apb_i2c_intf vif;

apb_tx tx; i2c_cfg cfg;

uvm_analysis_port #(apb_tx) i2c_slv;

bit [7:0] mem_data[bit [6:0]][bit [7:0]];
bit [7:0] current_reg_addr[bit [6:0]];

function new(string name="i2c_slave_model",uvm_component parent);
  super.new(name,parent);
endfunction

//--------------------------------------------------
// BUILD PHASE
//--------------------------------------------------

function void build_phase(uvm_phase phase);

super.build_phase(phase);

i2c_slv = new("i2c_slv",this);
tx      = apb_tx::type_id::create("tx");

if(!uvm_config_db#(virtual apb_i2c_intf)::get(this,"","vif",vif))
  `uvm_fatal("SLAVE","vif not set")

if(!uvm_config_db#(i2c_cfg)::get(this,"","cfg",cfg))
  `uvm_fatal("SLAVE","cfg not found")

endfunction

//--------------------------------------------------
// START DETECT
//--------------------------------------------------

task wait_for_start();

bit prev;
prev = vif.sda_in;

forever begin
  @(vif.sda_in or vif.scl);
  if(vif.scl == 1 && prev == 1 && vif.sda_in == 0)
    break;
  prev = vif.sda_in;
end

endtask

//--------------------------------------------------
// STOP DETECT
//--------------------------------------------------

task wait_for_stop();

bit prev;
prev = vif.sda_in;

forever begin
  @(vif.sda_in or vif.scl);
  if(vif.scl == 1 && prev == 0 && vif.sda_in == 1)
    break;
  prev = vif.sda_in;
end

endtask

//--------------------------------------------------
// ADDRESS MATCH
//--------------------------------------------------

function bit addr_match(bit [6:0] addr);

foreach(cfg.addr[i]) begin
  if(addr == cfg.addr[i])
    return 1;
end
return 0;

endfunction

//--------------------------------------------------
// RECEIVE BYTE
// Entry : SCL low, master driving SDA.
// Exit  : SCL high (last posedge seen).
//--------------------------------------------------

task recv_byte(output bit [7:0] din);

for(int i=7;i>=0;i--) begin
  @(posedge vif.scl);
  din[i] = vif.sda_in;
end

endtask

//--------------------------------------------------
// RECEIVE BYTE CONTINUING
// bit[7] already captured by check_stop_after_ack.
// Collects bits[6:0] only.
// Exit : SCL high (last posedge seen).
//--------------------------------------------------

task recv_byte_cont(input  bit       msb,
                    output bit [7:0] din);

din[7] = msb;

for(int i=6;i>=0;i--) begin
  @(posedge vif.scl);
  din[i] = vif.sda_in;
end

endtask

//--------------------------------------------------
// SEND ACK  (slave ? master)
//
// Entry : SCL high (last posedge from recv_byte).
//
// @(negedge scl) ? SCL low
//   NBA <= drives SDA — settled before posedge ?
// @(posedge scl) ? master samples ACK
// @(negedge scl) ? SCL low — ACK slot closes
//   NBA <= releases SDA
//
// Exit : SCL low, sda_oe=0, sda_out=1.
//--------------------------------------------------

task send_ack(bit ack);

@(negedge vif.scl);

if(ack) begin
  vif.sda_out <= 1'b0;
  vif.sda_oe  <= 1'b1;
end
else begin
  vif.sda_out <= 1'b1;
  vif.sda_oe  <= 1'b0;
end

@(posedge vif.scl);
@(negedge vif.scl);

vif.sda_out <= 1'b1;
vif.sda_oe  <= 1'b0;

endtask

//--------------------------------------------------
// SEND BYTE  (slave ? master)
//
// Entry : SCL low.
//   First call : send_ack exits on negedge ? low ?
//   Subsequent : wait_master_ack exits on negedge ?
//
// Sequence:
//   Drive bit[7] via NBA <=  — SCL low, settled ?
//   @(posedge scl)           — master samples bit[7]
//   for i=6 downto 0:
//     @(negedge scl)         — SCL low
//     Drive bit[i] via NBA<= — settled before posedge?
//     @(posedge scl)         — master samples bit[i]
//   @(negedge scl)           — ACK slot opens
//   Release SDA via NBA <=   — SCL low ?
//
// sda_out explicitly set in BOTH branches so
// sda_out always reflects the intended value.
// sda_oe explicitly set in BOTH branches.
//
// Exit : SCL low, sda_oe=0, sda_out=1.
//--------------------------------------------------
/*
task send_byte(input bit [7:0] dout);
   logic[7:0] temp_byte_out;
  `uvm_info(get_type_name(),$sformatf("send byte dout=%b",dout),UVM_MEDIUM)
    if(dout[7] == 0) begin
      vif.sda_out <= 0;
      vif.sda_oe  <= 1;
    end
    else begin
      vif.sda_oe <= 0;
    end

    temp_byte_out[7]=(vif.sda_oe) ? vif.sda_out : 1'b1;
    `uvm_info(get_type_name(),$sformatf("dout[7]=%b,temp_byte_out[7]=%b",dout[7],temp_byte_out[7]),UVM_MEDIUM)

    for(int i=6;i>=0;i--) begin
      @(negedge vif.scl);
      if(dout[i] == 0) begin
        vif.sda_out <= 0;
        vif.sda_oe  <= 1;
      end
      else begin
        vif.sda_oe <= 0;
      end
      temp_byte_out[i]=(vif.sda_oe) ? vif.sda_out : 1'b1;
    `uvm_info(get_type_name(),$sformatf("dout[%0d]=%b,temp_byte_out[%0d]=%b",i,dout[i],i,temp_byte_out[i]),UVM_MEDIUM)
      @(posedge vif.scl);
    end
    @(negedge vif.scl);
    vif.sda_oe <= 0;
    `uvm_info(get_type_name(),$sformatf("temp_byte out=%b",temp_byte_out),UVM_MEDIUM)
  endtask

 */ 
  

//********************

task send_byte(input bit [7:0] dout);

//----------------------------------------------------
// bit[7] — drive immediately, SCL already low
//----------------------------------------------------
logic[7:0] temp_byte_out;
`uvm_info(get_type_name(),$sformatf("send byte dout=%b",dout),UVM_MEDIUM)
if(dout[7] == 1'b0) begin
  vif.sda_out <= 1'b0;
  vif.sda_oe  <= 1'b1;
end
else begin
  vif.sda_out <= 1'b1;  // explicit — not left from prev
  vif.sda_oe  <= 1'b0;
end
    temp_byte_out[7]=(vif.sda_oe) ? vif.sda_out : 1'b1;
    `uvm_info(get_type_name(),$sformatf("dout[7]=%b,temp_byte_out[7]=%b",dout[7],temp_byte_out[7]),UVM_MEDIUM)

// Explicit posedge for bit[7] — master samples here
@(posedge vif.scl);

//----------------------------------------------------
// bits[6:0] — each driven on negedge then sampled
//----------------------------------------------------
for(int i=6;i>=0;i--) begin

  @(negedge vif.scl);    // SCL low — safe to drive SDA

  if(dout[i] == 1'b0) begin
    vif.sda_out <= 1'b0;
    vif.sda_oe  <= 1'b1;
  end
  else begin
    vif.sda_out <= 1'b1;  // explicit
    vif.sda_oe  <= 1'b0;
  end
      temp_byte_out[i]=(vif.sda_oe) ? vif.sda_out : 1'b1;
    `uvm_info(get_type_name(),$sformatf("dout[%0d]=%b,temp_byte_out[%0d]=%b",i,dout[i],i,temp_byte_out[i]),UVM_MEDIUM)

  @(posedge vif.scl);    // master samples bit[i]

end

//----------------------------------------------------
// All 8 bits sent. SCL is high after bit[0] posedge.
// Wait for negedge — opens ACK slot.
// Release SDA so master can drive ACK or NACK.
//----------------------------------------------------
@(negedge vif.scl);
    `uvm_info(get_type_name(),$sformatf("temp_byte out=%b",temp_byte_out),UVM_MEDIUM)

vif.sda_out <= 1'b1;     // explicit release
vif.sda_oe  <= 1'b0;

endtask

//--------------------------------------------------
// WAIT MASTER ACK  (master ? slave)
//
// Entry : SCL low, sda_oe=0 (slave released).
//         NBA from send_byte ACK release has
//         resolved before this posedge arrives.
//
// @(posedge scl) — sample master ACK/NACK
// @(negedge scl) — close ACK slot
//
// Exit : SCL low.
//--------------------------------------------------

task wait_master_ack(output bit nack);

@(posedge vif.scl);
nack = vif.sda_in;    // 0=ACK  1=NACK
@(negedge vif.scl);

endtask

//--------------------------------------------------
// CHECK STOP AFTER ACK
//
// Entry : send_ack() completed.
//         SCL low, sda_oe=0, sda_out=1.
//
// Slave observes only — no SDA driving.
//
// @(posedge scl) — SCL rises
//   sample sda_at_rise ? bit[7] of next byte
//   or 0 if STOP being set up
//
// fork:
//   sda_change_thread:
//     capture sda_before_change
//     @(vif.sda_in) — wait for SDA change
//     0?1 : STOP    ? is_stop=1
//     1?0 : RS      ? is_stop=1
//   scl_fall_thread:
//     @(negedge scl) — SCL fell before SDA changed
//     ? data bit, is_stop=0, bit7=sda_at_rise
// join_any + disable fork
//
// MSB=1 bytes: SDA=1 stable ? no transition ?
//              scl_fall wins ?
// STOP: SDA=0 at rise ? master releases ? 0?1
//       while SCL high ? sda_change wins ?
//
// Exit is_stop=0 : SCL low. bit7 valid.
// Exit is_stop=1 : STOP consumed.
//--------------------------------------------------

task check_stop_after_ack(output bit is_stop,
                           output bit bit7);

bit sda_at_rise;
bit sda_before_change;

is_stop = 0;
bit7    = 0;

@(posedge vif.scl);
sda_at_rise = vif.sda_in;

fork : detect_stop_or_data

  begin : sda_change_thread
    sda_before_change = vif.sda_in;
    @(vif.sda_in);
    if(!sda_before_change && vif.sda_in)
      is_stop = 1;    // STOP  : 0?1
    else if(sda_before_change && !vif.sda_in)
      is_stop = 1;    // RS    : 1?0 unsupported
    else
      is_stop = 1;    // Glitch: conservative
  end

  begin : scl_fall_thread
    @(negedge vif.scl);
    is_stop = 0;
    bit7    = sda_at_rise;
  end

join_any
disable fork;

endtask

//--------------------------------------------------
// MAIN I2C LOOP
//--------------------------------------------------

task run();

bit [7:0] addr_byte;
bit [6:0] addr;
bit       rw;
bit [7:0] reg_addr;
bit [7:0] din;
bit       is_stop;
bit       bit7;
bit       nack;

vif.sda_oe  = 1'b0;
vif.sda_out = 1'b1;

foreach(cfg.addr[i])
  current_reg_addr[cfg.addr[i]] = 8'h00;

forever begin

  //--------------------------------------
  // START
  //--------------------------------------

  wait_for_start();

  //--------------------------------------
  // ADDRESS + RW
  //--------------------------------------

  recv_byte(addr_byte);

  addr = addr_byte[7:1];
  rw   = addr_byte[0];

  //--------------------------------------
  // ADDRESS CHECK
  //--------------------------------------

  if(addr_match(addr))
    send_ack(1);
  else begin
    send_ack(0);
    wait_for_stop();
    continue;
  end

  //--------------------------------------
  // WRITE OPERATION
  //--------------------------------------

  if(rw == 0) begin

    recv_byte(reg_addr);
    send_ack(1);

    current_reg_addr[addr] = reg_addr;

    forever begin

      check_stop_after_ack(is_stop, bit7);

      if(is_stop)
        break;

      recv_byte_cont(bit7, din);

      mem_data[addr][current_reg_addr[addr]] = din;

      `uvm_info("SLAVE",
        $sformatf("WRITE slave=0x%02h reg=0x%02h data=0x%02h",
                  addr, current_reg_addr[addr], din),
        UVM_HIGH)

      send_ack(1);

      current_reg_addr[addr]++;

    end

  end

  //--------------------------------------
  // READ OPERATION
  //--------------------------------------

  else begin

    forever begin

      if(!mem_data[addr].exists(current_reg_addr[addr]))
        mem_data[addr][current_reg_addr[addr]] = 8'h00;

      send_byte(mem_data[addr][current_reg_addr[addr]]);

      `uvm_info("SLAVE",
        $sformatf("READ  slave=0x%02h reg=0x%02h data=0x%02h",
                  addr, current_reg_addr[addr],
                  mem_data[addr][current_reg_addr[addr]]),
        UVM_HIGH)

      wait_master_ack(nack);

      current_reg_addr[addr]++;

      if(nack)
        break;

    end

    wait_for_stop();

  end

end

endtask

//--------------------------------------------------
// RUN PHASE
//--------------------------------------------------

task run_phase(uvm_phase phase);

super.run_phase(phase);

run();

endtask

endclass
