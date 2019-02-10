`uvm_analysis_imp_decl(_ref)
`uvm_analysis_imp_decl(_act)

class i2c_scoreboard extends uvm_scoreboard;
`uvm_component_utils(i2c_scoreboard)

uvm_analysis_imp_ref#(txn,i2c_scoreboard)master_imp;
uvm_analysis_imp_act#(txn,i2c_scoreboard)slave_imp;

txn ref_d;
txn act_d;
//bit flag=0;
txn ref_q[$];
txn act_q[$];
int intQ[$];
int temp[$];

//bit [7:0] ref_mem [bit [6:0]];



function new(string name = "i2c_scoreboard",uvm_component parent);
super.new(name,parent);
master_imp = new("master_imp",this);
slave_imp = new("slave_imp",this);
endfunction



function void build_phase(uvm_phase phase);
super.build_phase(phase);
endfunction

function void write_ref(txn t);
 //`uvm_info("SB_REF", "write_ref entered", UVM_LOW)
    ref_q.push_back(t);
    //$display("data got = %0h",t.dout);
    compare();
  endfunction

  // Actual transaction: addr, op, dout collected from SDA/SCL
  function void write_act(txn t);
 // `uvm_info("SB_ACT", "write_act entered", UVM_LOW)
    act_q.push_back(t);
    compare();
  endfunction

  function void compare();

//bit [7:0] exp_data;
    
      while (ref_q.size() > 0 && act_q.size() > 0) begin

        ref_d = ref_q.pop_front();
        act_d = act_q.pop_front();

      // WRITE operation only
        if ( ref_d.op == 1'b0) begin
            
            if ((ref_d.addr == act_d.addr) &&
                (ref_d.op   == act_d.op)   &&
                (ref_d.din  == act_d.din)) begin

               `uvm_info("SB",
                    $sformatf("WRITE PASS addr=%0h data=%0h expaddr = %0h expdata = %0h",
                      ref_d.addr, ref_d.din,act_d.addr,act_d.din),
                UVM_LOW)  

            end
            else begin

            `uvm_error("SB",
            $sformatf("WRITE FAIL exp_addr=%0h act_addr=%0h exp_op=%0b act_op=%0b exp_data=%0h act_data=%0h",
                      ref_d.addr, act_d.addr,
                      ref_d.op,   act_d.op,
                      ref_d.din,  act_d.din))

            end
        end
// =====================================================
    // READ REF LOGIC
    // =====================================================
    else if ( ref_d.op == 1'b1) begin

    //  if (ref_mem.exists(ref_d.addr)) begin

     //   exp_data = ref_mem[ref_d.addr];

       // intQ.push_back(act_d.dout);
        
           // if(intQ.size()>=2) begin
         //      act_d.dout=intQ.pop_front();
                

                if ((ref_d.addr == act_d.addr) &&
                (ref_d.op   == act_d.op)   &&
                (ref_d.dout   == act_d.dout)) begin

                $display($time,"addr = %p , op = %p , actual data = %p",ref_d.addr,ref_d.op,ref_d.dout);
            $display($time,"slave addr = %p ,slave op = %p ,slave dout = %p",act_d.addr,act_d.op,act_d.dout);
                //intQ.delete();
                `uvm_info("SB",
                $sformatf("READ PASS addr=%0h exp_data=%0h act_data=%0h",
                      ref_d.addr, ref_d.dout, act_d.dout),
                UVM_LOW) 

                end
                else begin

                `uvm_error("SB",
                $sformatf("READ FAIL exp_addr=%0h act_addr=%0h exp_op=%0b act_op=%0b exp_data=%0h act_data=%0h",
                      ref_d.addr, act_d.addr,
                      ref_d.op,   act_d.op,
                      ref_d.dout,   act_d.dout))
             
                end

            end
            
            else begin

            `uvm_error("SB",
            $sformatf("READ BEFORE WRITE addr=%0h act_data=%0h exp_data = %0h",
                    ref_d.addr, act_d.dout, ref_d.dout))
            
            end
   // end
   end 
    
  endfunction

endclass
