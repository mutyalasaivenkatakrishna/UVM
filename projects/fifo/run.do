vlog top.sv \
+incdir+C:/Users/SAI\ VENKATA\ KRISHNA/Downloads/uvm-1.2_RC8/uvm-1.2/src

vsim top -novopt \
-suppress 12110 \
-sv_lib C:/questasim64_10.7c/uvm-1.2/win64/uvm_dpi \


run -all

