class i2c_slave_agent extends uvm_agent;
    `uvm_component_utils(i2c_slave_agent)

    i2c_slave_model slave_model;
    i2c_slv_monitor i2c_slv_mon;

    function new(string name = "i2c_slave_agent",uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        slave_model = i2c_slave_model::type_id::create("slave_model",this);
        i2c_slv_mon = i2c_slv_monitor::type_id::create("i2c_slv_mon",this);
    endfunction


endclass

