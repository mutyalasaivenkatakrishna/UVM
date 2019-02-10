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
// SEND ACK  (slave -> master)
//
// Entry : SCL high (last posedge from recv_byte).
// Uses NBA <= — time separation between negedge
// and posedge is sufficient for NBA to resolve.
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
// SEND BYTE  (slave -> master)
//
// Entry : SCL low.
//
// CRITICAL — uses BLOCKING assignment = for all
// sda_oe and sda_out drives.
//
// Why blocking and not NBA <=:
//   For bit[7]: drive happens, then @(posedge scl)
//   is in the SAME procedural sequence. NBA <= only
//   resolves at end of current time step — which is
//   the same time step as @(posedge scl). This means
//   sda_oe flips to 1 at the same delta as posedge,
//   and the interface assign:
//     assign sda = sda_oe ? sda_out : 1'bz
//   may not have propagated before master samples.
//   Result: master sees wrong SDA value for bit[7].
//
//   Blocking = takes effect immediately in current
//   time step before any subsequent statement.
//   So sda_oe=1 and sda_out=0 are stable before
//   @(posedge scl) is reached — master samples
//   correct SDA value. ?
//
//   For bits[6:0]: @(negedge scl) advances time,
//   then blocking drive, then @(posedge scl).
//   Full time separation — blocking guarantees
//   SDA is stable before posedge. ?
//
// Sequence:
//   sda_oe=x, sda_out=x  (blocking =, immediate) 
//   @(posedge scl)        master samples bit[7] ?
//   for i=6..0:
//     @(negedge scl)
//     sda_oe=x, sda_out=x (blocking =, immediate)
//     @(posedge scl)       master samples bit[i] ?
//   @(negedge scl)
//   sda_oe=0, sda_out=1   (blocking =, ACK slot)
//
// Exit : SCL low, sda_oe=0, sda_out=1.
//--------------------------------------------------

task send_byte(input bit [7:0] dout);

logic[7:0] temp_byte_out;
`uvm_info(get_type_name(),$sformatf("send byte dout=%b",dout),UVM_MEDIUM)

//--------------------------------------------------
// bit[7] — blocking = so SDA settles BEFORE
//          the subsequent @(posedge scl)
//--------------------------------------------------
if(dout[7] == 1'b0) begin
  vif.sda_out <= 1'b0;    // blocking — immediate
  vif.sda_oe  <= 1'b1;    // blocking — immediate
end
else begin
  vif.sda_out <= 1'b1;    // blocking — immediate
  vif.sda_oe  <= 1'b0;    // blocking — immediate
end
 temp_byte_out[7]=(vif.sda_oe) ? vif.sda_out : 1'b1;
    `uvm_info(get_type_name(),$sformatf("dout[7]=%b,temp_byte_out[7]=%b time =%t",dout[7],temp_byte_out[7],$time),UVM_MEDIUM)
// SDA is now fully stable. Master samples here.
@(posedge vif.scl);

//--------------------------------------------------
// bits[6:0] — @(negedge scl) gives time separation
//             so blocking = is used here too for
//             consistency and safety
//--------------------------------------------------
for(int i=6;i>=0;i--) begin

  @(negedge vif.scl);    // SCL low

  if(dout[i] == 1'b0) begin
    vif.sda_out = 1'b0;  // blocking — immediate
    vif.sda_oe  = 1'b1;  // blocking — immediate
  end
  else begin
    vif.sda_out = 1'b1;  // blocking — immediate
    vif.sda_oe  = 1'b0;  // blocking — immediate
  end

  // SDA stable. Master samples here.
    temp_byte_out[i]=(vif.sda_oe) ? vif.sda_out : 1'b1;
    `uvm_info(get_type_name(),$sformatf("dout[%0d]=%b,temp_byte_out[%0d]=%b",i,dout[i],i,temp_byte_out[i]),UVM_MEDIUM)
  @(posedge vif.scl);

end

//--------------------------------------------------
// All 8 bits sent. SCL high after bit[0] posedge.
// Wait for negedge — ACK slot opens.
// Release SDA — blocking = so immediately stable.
//--------------------------------------------------
@(negedge vif.scl);
    `uvm_info(get_type_name(),$sformatf("temp_byte out=%b",temp_byte_out),UVM_MEDIUM)

vif.sda_out = 1'b1;      // blocking — immediate
vif.sda_oe  = 1'b0;      // blocking — immediate

endtask

//--------------------------------------------------
// WAIT MASTER ACK  (master -> slave)
//
// Entry : SCL low, sda_oe=0 (slave released).
// @(posedge scl) — sample master ACK/NACK
// @(negedge scl) — close ACK slot
// Exit  : SCL low.
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
// Slave observes only — no SDA driving.
//
// @(posedge scl) — SCL rises, sample sda_at_rise
// fork:
//   sda_change_thread: SDA changes while SCL high
//     0->1 : STOP  -> is_stop=1
//     1->0 : RS    -> is_stop=1
//   scl_fall_thread: SCL falls before SDA changes
//     -> data bit, is_stop=0, bit7=sda_at_rise
// join_any + disable fork
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
      is_stop = 1;    // STOP  : 0->1
    else if(sda_before_change && !vif.sda_in)
      is_stop = 1;    // RS    : 1->0 unsupported
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

  wait_for_start();

  recv_byte(addr_byte);
  addr = addr_byte[7:1];
  rw   = addr_byte[0];

  if(addr_match(addr))
    send_ack(1);
  else begin
    send_ack(0);
    wait_for_stop();
    continue;
  end

  //--------------------------------------
  // WRITE
  //--------------------------------------
  
    recv_byte(reg_addr);
    send_ack(1);
    current_reg_addr[addr] = reg_addr;


  if(rw == 0) begin

    //recv_byte(reg_addr);
    //send_ack(1);

    //current_reg_addr[addr] = reg_addr;

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
      `uvm_info("SLAVE",$sformatf("WRITE Completed memory = %p ", mem_data),UVM_HIGH)

  end

  //--------------------------------------
  // READ
  //-------------------------------------

  else begin
    
    forever begin
      
      //recv_byte(reg_addr);
    /*
      if(!mem_data[addr].exists(current_reg_addr[addr]))
        mem_data[addr][current_reg_addr[addr]] = 8'h00;
*/
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
      `uvm_info("SLAVE",$sformatf("READ Completed"),UVM_HIGH)

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

