module i2c_wrapper #(
    parameter ADDR_WIDTH = 8,
    parameter DATA_WIDTH = 32
)(
    // APB Interface Signals
    input  logic                    pclk,
    input  logic                    presetn,
    input  logic [ADDR_WIDTH-1:0]   paddr,
    input  logic                    psel,
    input  logic                    penable,
    input  logic                    pwrite,
    input  logic [DATA_WIDTH-1:0]   pwdata,

    output logic [DATA_WIDTH-1:0]   prdata,
    output logic                    pready,
    output logic                    pslverr,

    // I2C Interface
    inout  wire                     sda,
    output wire                     scl
);
// Internal Signals
wire [3:0]  control_reg_wire;
wire mode_sel;
assign mode_sel = control_reg_wire[2];
wire [6:0]  wire_addr;
wire [31:0] wire_reg_addr;
wire [31:0] wire_tx_data;
wire [31:0] wire_rx_data;
wire         wire_busy;
wire         wire_done;
wire         wire_error;
// Register File
i2c_register #(
    .ADDR_WIDTH (ADDR_WIDTH),
    .DATA_WIDTH (DATA_WIDTH)
) i2c_reg (

    .pclk           (pclk),
    .presetn        (presetn),

    .paddr          (paddr),
    .psel           (psel),
    .penable        (penable),
    .pwrite         (pwrite),
    .pwdata         (pwdata),

    .prdata         (prdata),
    .pready         (pready),
    .pslverr        (pslverr),

    .control_reg    (control_reg_wire),

    .addr_reg       (wire_addr),

    .reg_addr_out   (wire_reg_addr),

    .data_in_reg    (wire_tx_data),

    .i2c_busy       (wire_busy),
    .i2c_done       (wire_done),
    .i2c_ack_err    (wire_error),
    .i2c_rx_data    (wire_rx_data)
);
// I2C Master
i2c_master i2c (
    .clk            (pclk),
    .rst            (~presetn),
    // Original control signals
    .newd           (control_reg_wire[0]),
    .op             (control_reg_wire[1]),
    .mode_sel(mode_sel),

    // Slave address
    .addr           (wire_addr),


    // Multi-byte ports
    .reg_addr       (wire_reg_addr),

    .din       (wire_tx_data),
    .dout         (wire_rx_data),


    // I2C pins
    .sda            (sda),
    .scl            (scl),

    // Status
    .busy           (wire_busy),
    .done           (wire_done),
    .ack_err        (wire_error)
);
endmodule
