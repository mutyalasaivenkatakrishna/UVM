class apb_i2c_env extends uvm_component;
    `uvm_component_utils(apb_i2c_env)

    i2c_slave_agent s_agent;
    apb_agent apb_agt;
    apb_i2c_sbd sbd;
    apb_i2c_cov cov_f;

    function new(string name = "apb_i2c_env",uvm_component parent);
        super.new(name,parent);
    endfunction

    function void build_phase(uvm_phase phase);
        super.build_phase(phase);
        s_agent = i2c_slave_agent::type_id::create("s_agent",this);
        apb_agt = apb_agent::type_id::create("apb_agent",this);
        sbd = apb_i2c_sbd::type_id::create("sbd",this);
        cov_f = apb_i2c_cov::type_id::create("cov_f",this);
    endfunction

    function void connect_phase(uvm_phase phase);
        super.connect_phase(phase);
        apb_agt.mon.ap_port.connect(sbd.apb);
        s_agent.i2c_slv_mon.i2c_slv_mon_port.connect(sbd.i2c);
    endfunction

endclass
