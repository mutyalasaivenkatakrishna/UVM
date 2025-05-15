`define WIDTH 2

`define DEPTH 8
`define SZ $clog2(`DEPTH)

`define NEW_COMP \
function new(string name,uvm_component parent);\
	super.new(name,parent);\
endfunction

`define NEW_OBJ \
function new(string name="");\
	super.new(name);\
endfunction
class mem_common;
static int num_matches;
static int num_mismatches;
static int total_tx_count=5;
endclass
