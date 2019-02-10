class txn extends uvm_sequence_item;

rand bit newd;
rand bit [6:0]addr;
rand bit op;
rand bit [7:0]din;
     bit done;
     bit sda;
     bit scl;
     bit busy;
     bit ack_err;
     bit [7:0]dout;
   //  rand bit ctrl;

/*constraint ctrl_op{if(ctrl)
    op == 1;
    else
     op == 0;}*/

`uvm_object_utils_begin(txn)
`uvm_field_int(newd,UVM_ALL_ON)
`uvm_field_int(addr,UVM_ALL_ON)
`uvm_field_int(op,UVM_ALL_ON)
`uvm_field_int(din,UVM_ALL_ON)
`uvm_field_int(done,UVM_ALL_ON)
`uvm_field_int(sda,UVM_ALL_ON)
`uvm_field_int(scl,UVM_ALL_ON)
`uvm_field_int(dout,UVM_ALL_ON)
`uvm_field_int(ack_err,UVM_ALL_ON)
`uvm_field_int(busy,UVM_ALL_ON)
`uvm_object_utils_end

function new(string name = "txn");
super.new(name);
endfunction

constraint cond_c {din inside {[0:255]};}
/*constraint addr_range{addr inside {
    7'h10, 7'h20, 7'h30, 7'h40, 7'h50,
    7'h60, 7'h70, 7'h15, 7'h25, 7'h35, 7'h00,7'h7F
    }; 
} */

//constraint cond_op{op dist {0 :/20, 1 :/80};}

/*constraint cond_wr{
    if(op == 1)
        din == 8'h00;
    } */

endclass
