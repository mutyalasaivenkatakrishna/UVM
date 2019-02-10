module i2c_register #(
parameter ADDR_WIDTH = 8,
parameter DATA_WIDTH = 32
)(
// APB Interface
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

// Outputs to I2C Master
output logic [1:0]              control_reg,
output logic [6:0]              addr_reg,
output logic [31:0]             reg_addr_out,
output logic [31:0]             data_in_reg,
output logic [1:0]              reg_addr_bytes,
output logic [1:0]              data_bytes,

// Inputs from I2C Master
input  logic                    i2c_busy,
input  logic                    i2c_done,
input  logic                    i2c_ack_err,
input  logic [31:0]             i2c_rx_data
);

//--------------------------------------------------
// Address Map
//--------------------------------------------------

localparam CONTROL  = 8'h00;
localparam ADDR     = 8'h04;
localparam REG_ADDR = 8'h08;
localparam DATA_IN  = 8'h0C;
localparam DATA_OUT = 8'h10;
localparam STATUS   = 8'h14;
localparam BYTE_CFG = 8'h18;

//--------------------------------------------------
// Internal Registers
//--------------------------------------------------

logic [31:0] slave_addr_reg;
logic [31:0] reg_addr_reg;
logic [31:0] data_reg;
logic [31:0] byte_cfg_reg;

logic write_en;
logic read_en;
logic access_en;

logic addr_valid;
logic write_to_ro;

//--------------------------------------------------
// APB Control
//--------------------------------------------------

assign write_en  = psel & penable & pwrite;
assign read_en   = psel & ~pwrite;
assign access_en = psel & penable;

assign pready = 1'b1;

//--------------------------------------------------
// Address Decode
//--------------------------------------------------

always_comb begin
    case (paddr)
        CONTROL,
        ADDR,
        REG_ADDR,
        DATA_IN,
        DATA_OUT,
        STATUS,
        BYTE_CFG : addr_valid = 1'b1;

        default  : addr_valid = 1'b0;
    endcase
end

//--------------------------------------------------
// APB Error Response
//--------------------------------------------------

assign write_to_ro =
    write_en &&
    ((paddr == STATUS) || (paddr == DATA_OUT));

assign pslverr =
    access_en &&
    (~addr_valid || write_to_ro);

//--------------------------------------------------
// Register Writes
//--------------------------------------------------

always_ff @(posedge pclk or negedge presetn) begin

    if (!presetn) begin

        control_reg    <= 2'b00;
        slave_addr_reg <= 32'd0;
        reg_addr_reg   <= 32'd0;
        data_reg       <= 32'd0;
        byte_cfg_reg   <= 32'd0;

    end
    else begin

        if (write_en && addr_valid) begin

            case (paddr)

                CONTROL  : control_reg    <= pwdata[1:0];

                ADDR     : slave_addr_reg <= pwdata;

                REG_ADDR : reg_addr_reg   <= pwdata;

                DATA_IN  : data_reg       <= pwdata;

                BYTE_CFG : byte_cfg_reg   <= pwdata;

                default  : ;

            endcase

        end

        // Auto clear START bit
        if (control_reg[0])
            control_reg[0] <= 1'b0;

    end

end

//--------------------------------------------------
// Outputs to I2C Master
//--------------------------------------------------

assign addr_reg       = slave_addr_reg[6:0];

assign reg_addr_out   = reg_addr_reg;

assign data_in_reg    = data_reg;

assign reg_addr_bytes = byte_cfg_reg[1:0];

assign data_bytes     = byte_cfg_reg[3:2];

//--------------------------------------------------
// Read Logic
//--------------------------------------------------

always_comb begin

    prdata = '0;

    if (read_en && addr_valid) begin

        case (paddr)

            CONTROL :
                prdata = {30'd0, control_reg};

            ADDR :
                prdata = slave_addr_reg;

            REG_ADDR :
                prdata = reg_addr_reg;

            DATA_IN :
                prdata = data_reg;

            DATA_OUT :
                prdata = i2c_rx_data;

            STATUS :
                prdata = {29'd0,
                          i2c_ack_err,
                          i2c_done,
                          i2c_busy};

            BYTE_CFG :
                prdata = byte_cfg_reg;

            default :
                prdata = '0;

        endcase
    end
end
endmodule

