module i2c_master (
    input  logic        clk,
    input  logic        rst,
    input  logic        newd,
    input  logic [6:0]  addr,
    input  logic        op,         // 0=write, 1=read
    input  logic        mode_sel,   // 0=1-byte, 1=4-byte
    input  logic [7:0]  reg_addr,   // 8-bit register address
    inout  wire         sda,
    output logic        scl,
    input  logic [31:0] din,
    output logic [31:0] dout,
    output logic        busy,
    output logic        ack_err,
    output logic        done
);
 
    // -------------------------------------------------------
    // Clock divider: 40 MHz / 100 kHz I2C
    // 1 I2C bit = 400 sys clocks = 4 x 100-clock quarters
    // -------------------------------------------------------
    localparam int CLK_DIV1 = (40_000_000 / 100_000) / 4;  // 100
 
    localparam logic [8:0] CLK1 = 9'(CLK_DIV1     - 1);   //  99
    localparam logic [8:0] CLK2 = 9'(CLK_DIV1 * 2 - 1);   // 199
    localparam logic [8:0] CLK3 = 9'(CLK_DIV1 * 3 - 1);   // 299
    localparam logic [8:0] CLK4 = 9'(CLK_DIV1 * 4 - 1);   // 399
 
    // -------------------------------------------------------
    // Quarter-period pulse generator
    //   pulse 0 : SCL low  Q1
    //   pulse 1 : SCL low  Q2  <- drive SDA here
    //   pulse 2 : SCL high Q3  <- sample SDA here
    //   pulse 3 : SCL high Q4
    // -------------------------------------------------------
    reg [8:0] count1;
    reg [1:0] pulse;
 
    always_ff @(posedge clk) begin
        if (rst || !busy) begin
            pulse  <= 2'd0;
            count1 <= 9'd0;
        end else begin
            if      (count1 == CLK1) begin pulse <= 2'd1; count1 <= count1 + 9'd1; end
            else if (count1 == CLK2) begin pulse <= 2'd2; count1 <= count1 + 9'd1; end
            else if (count1 == CLK3) begin pulse <= 2'd3; count1 <= count1 + 9'd1; end
            else if (count1 == CLK4) begin pulse <= 2'd0; count1 <= 9'd0;          end
            else                          count1 <= count1 + 9'd1;
        end
    end
 
    // -------------------------------------------------------
    // SDA read-back: when master releases SDA (sda_en=0),
    // the bus is pulled high externally. Any 1'bz on SDA
    // is treated as logic 1 (pulled high by RPU).
    // Using this safe sampled version prevents X propagation
    // into rx_data shift register.
    // -------------------------------------------------------
    wire sda_in;
    assign sda_in = sda;
 
    // -------------------------------------------------------
    // FSM states
    //
    // WRITE: START->WR_SLVADDR(W)->ACK_SA->WR_REGADDR->ACK_RA
    //        ->WR_DATA->ACK_WR->[repeat for 4-byte]->STOP
    //
    // READ:  START->WR_SLVADDR(R)->ACK_SA->WR_REGADDR->ACK_RA
    //        ->RD_DATA->[MSTR_ACK->RD_DATA repeat]->MSTR_NACK->STOP
    // -------------------------------------------------------
    typedef enum logic [3:0] {
        IDLE      = 4'd0,
        START     = 4'd1,
        WR_SLVADDR= 4'd2,
        ACK_SA    = 4'd3,
        WR_REGADDR= 4'd4,
        ACK_RA    = 4'd5,
        WR_DATA   = 4'd6,
        ACK_WR    = 4'd7,
        RD_DATA   = 4'd8,
        MSTR_ACK  = 4'd9,
        MSTR_NACK = 4'd10,
        STOP      = 4'd11
    } state_t;
 
    state_t state;
 
    reg        scl_t;
    reg        sda_t;
    reg        sda_en;
    reg [3:0]  bitcount;
    reg [1:0]  byte_idx;
    reg [7:0]  sh_addr_w;   // {addr, 1'b0}
    reg [7:0]  sh_addr_r;   // {addr, 1'b1}
    reg [7:0]  sh_regaddr;
    reg [31:0] sh_tx;
    reg [31:0] rx_data;
    reg [31:0] dout_r;      // registered output - only updates on read complete
    reg        r_ack;
 
    // -------------------------------------------------------
    // TX byte mux
    // -------------------------------------------------------
    wire [7:0] tx_byte;
    assign tx_byte = (mode_sel == 1'b0) ? sh_tx[31:24]   :
                     (byte_idx == 2'd0) ? sh_tx[31:24]  :
                     (byte_idx == 2'd1) ? sh_tx[23:16]  :
                     (byte_idx == 2'd2) ? sh_tx[15:8]   :
                                          sh_tx[7:0];
 
    // Last byte flag
    wire last_byte;
    assign last_byte = (mode_sel == 1'b0) ? (byte_idx == 2'd0)
                                          : (byte_idx == 2'd3);
 
    // -------------------------------------------------------
    // Main FSM
    // -------------------------------------------------------
    always_ff @(posedge clk) begin
        if (rst) begin
            state      <= IDLE;
            scl_t      <= 1'b1;
            sda_t      <= 1'b1;
            sda_en     <= 1'b0;
            bitcount   <= 4'd0;
            byte_idx   <= 2'd0;
            sh_addr_w  <= 8'd0;
            sh_addr_r  <= 8'd0;
            sh_regaddr <= 8'd0;
            sh_tx      <= 32'd0;
            rx_data    <= 32'd0;
            dout_r     <= 32'd0;
            r_ack      <= 1'b0;
            busy       <= 1'b0;
            ack_err    <= 1'b0;
            done       <= 1'b0;
        end else begin
            case (state)
 
                // -------------------------------------------
                // IDLE: wait for new transaction
                // -------------------------------------------
                IDLE: begin
                    done    <= 1'b0;
                    ack_err <= 1'b0;
                    scl_t   <= 1'b1;
                    sda_t   <= 1'b1;
                    sda_en  <= 1'b0;
                    if (newd) begin
                        sh_addr_w  <= {addr, 1'b0};
                        sh_addr_r  <= {addr, 1'b1};
                        sh_regaddr <= reg_addr;
                        sh_tx      <= din;
                        rx_data    <= 32'd0;
                        byte_idx   <= 2'd0;
                        bitcount   <= 4'd0;
                        busy       <= 1'b1;
                        state      <= START;
                    end else begin
                        busy <= 1'b0;
                    end
                end
 
                // -------------------------------------------
                // START: SDA falls while SCL is high
                // -------------------------------------------
                START: begin
                    sda_en <= 1'b1;
                    case (pulse)
                        2'd0: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                        2'd1: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                        2'd2: begin scl_t <= 1'b1; sda_t <= 1'b0; end  // START
                        2'd3: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                        default: ;
                    endcase
                    if (count1 == CLK4) begin
                        scl_t    <= 1'b0;
                        bitcount <= 4'd0;
                        state    <= WR_SLVADDR;
                    end
                end
 
                // -------------------------------------------
                // WR_SLVADDR: 8-bit slave address + R/W bit
                //   op=0  ->  addr|W  (bit0 = 0)
                //   op=1  ->  addr|R  (bit0 = 1)
                // -------------------------------------------
                WR_SLVADDR: begin
                    sda_en <= 1'b1;
                    if (bitcount <= 4'd7) begin
                        case (pulse)
                            2'd0: begin scl_t <= 1'b0; end
                            2'd1: begin
                                scl_t <= 1'b0;
                                sda_t <= (op == 1'b0)
                                         ? sh_addr_w[7 - bitcount[2:0]]
                                         : sh_addr_r[7 - bitcount[2:0]];
                            end
                            2'd2: begin scl_t <= 1'b1; end
                            2'd3: begin scl_t <= 1'b1; end
                            default: ;
                        endcase
                        if (count1 == CLK4) begin
                            scl_t    <= 1'b0;
                            bitcount <= bitcount + 4'd1;
                        end
                    end else begin
                        bitcount <= 4'd0;
                        sda_en   <= 1'b0;   // release for slave ACK
                        state    <= ACK_SA;
                    end
                end
 
                // -------------------------------------------
                // ACK_SA: receive slave ACK after address byte
                // -------------------------------------------
                ACK_SA: begin
                    sda_en <= 1'b0;
                    case (pulse)
                        2'd0: begin scl_t <= 1'b0; end
                        2'd1: begin scl_t <= 1'b0; end
                        2'd2: begin scl_t <= 1'b1; r_ack <= sda_in; end  // sample
                        2'd3: begin scl_t <= 1'b1; end
                        default: ;
                    endcase
                    if (count1 == CLK4) begin
                        scl_t <= 1'b0;
                        if (r_ack == 1'b0) begin        // ACK = SDA low
                            bitcount <= 4'd0;
                            sda_en   <= 1'b1;
                            state    <= WR_REGADDR;
                        end else begin                  // NACK -> abort
                            ack_err <= 1'b1;
                            sda_en  <= 1'b1;
                            state   <= STOP;
                        end
                    end
                end
 
                // -------------------------------------------
                // WR_REGADDR: 8-bit register address
                // Applies to both read and write transactions
                // Slave latches this as its internal pointer
                // -------------------------------------------
                WR_REGADDR: begin
                    sda_en <= 1'b1;
                    if (bitcount <= 4'd7) begin
                        case (pulse)
                            2'd0: begin scl_t <= 1'b0; end
                            2'd1: begin
                                scl_t <= 1'b0;
                                sda_t <= sh_regaddr[7 - bitcount[2:0]];
                            end
                            2'd2: begin scl_t <= 1'b1; end
                            2'd3: begin scl_t <= 1'b1; end
                            default: ;
                        endcase
                        if (count1 == CLK4) begin
                            scl_t    <= 1'b0;
                            bitcount <= bitcount + 4'd1;
                        end
                    end else begin
                        bitcount <= 4'd0;
                        sda_en   <= 1'b0;   // release for slave ACK
                        state    <= ACK_RA;
                    end
                end
 
                // -------------------------------------------
                // ACK_RA: receive slave ACK after reg address
                //   op=0  ->  WR_DATA  (write path)
                //   op=1  ->  RD_DATA  (read path)
                // -------------------------------------------
                ACK_RA: begin
                    sda_en <= 1'b0;
                    case (pulse)
                        2'd0: begin scl_t <= 1'b0; end
                        2'd1: begin scl_t <= 1'b0; end
                        2'd2: begin scl_t <= 1'b1; r_ack <= sda_in; end  // sample
                        2'd3: begin scl_t <= 1'b1; end
                        default: ;
                    endcase
                    if (count1 == CLK4) begin
                        scl_t    <= 1'b0;
                        bitcount <= 4'd0;
                        if (r_ack == 1'b0) begin
                            if (op == 1'b0) begin
                                sda_en <= 1'b1;
                                state  <= WR_DATA;   // WRITE path
                            end else begin
                                sda_en <= 1'b0;      // release SDA for slave
                                state  <= RD_DATA;   // READ path
                            end
                        end else begin
                            ack_err <= 1'b1;
                            sda_en  <= 1'b1;
                            state   <= STOP;
                        end
                    end
                end
 
                // -------------------------------------------
                // WR_DATA: send one data byte, MSB first
                // -------------------------------------------
                WR_DATA: begin
                    sda_en <= 1'b1;
                    if (bitcount <= 4'd7) begin
                        case (pulse)
                            2'd0: begin scl_t <= 1'b0; end
                            2'd1: begin
                                scl_t <= 1'b0;
                                sda_t <= tx_byte[7 - bitcount[2:0]];
                            end
                            2'd2: begin scl_t <= 1'b1; end
                            2'd3: begin scl_t <= 1'b1; end
                            default: ;
                        endcase
                        if (count1 == CLK4) begin
                            scl_t    <= 1'b0;
                            bitcount <= bitcount + 4'd1;
                        end
                    end else begin
                        bitcount <= 4'd0;
                        sda_en   <= 1'b0;   // release for slave ACK
                        state    <= ACK_WR;
                    end
                end
 
                // -------------------------------------------
                // ACK_WR: receive slave ACK after write byte
                //   last byte   ->  STOP
                //   more bytes  ->  byte_idx++ -> WR_DATA
                // -------------------------------------------
                ACK_WR: begin
                    sda_en <= 1'b0;
                    case (pulse)
                        2'd0: begin scl_t <= 1'b0; end
                        2'd1: begin scl_t <= 1'b0; end
                        2'd2: begin scl_t <= 1'b1; r_ack <= sda_in; end  // sample
                        2'd3: begin scl_t <= 1'b1; end
                        default: ;
                    endcase
                    if (count1 == CLK4) begin
                        scl_t <= 1'b0;
                        if (r_ack == 1'b0) begin
                            if (last_byte) begin
                                sda_en <= 1'b1;
                                state  <= STOP;         // all bytes sent
                            end else begin
                                byte_idx <= byte_idx + 2'd1;
                                bitcount <= 4'd0;
                                sda_en   <= 1'b1;
                                state    <= WR_DATA;    // next byte
                            end
                        end else begin
                            ack_err <= 1'b1;
                            sda_en  <= 1'b1;
                            state   <= STOP;
                        end
                    end
                end
 
                // -------------------------------------------
                // RD_DATA: clock in one byte from slave, MSB first
                //   master holds SCL low between bits
                //   slave drives SDA; master samples at pulse 2
                // -------------------------------------------
                RD_DATA: begin
                    sda_en <= 1'b0;     // master releases SDA; slave drives
                    if (bitcount <= 4'd7) begin
                        case (pulse)
                            2'd0: begin scl_t <= 1'b0; end
                            2'd1: begin scl_t <= 1'b0; end
                            2'd2: begin
    scl_t <= 1'b1;

    if (count1 == CLK3) begin
/*
        $display("[%0t] SAMPLE bit=%0d byte=%0d sda=%b",
                 $time,
                 bitcount,
                 byte_idx,
                 sda_in);
*/
        if(mode_sel == 1'b0)
            rx_data[7:0] <= {rx_data[6:0], sda_in};
        else begin
            case(byte_idx)
                2'd0: rx_data[31:24] <= {rx_data[30:24], sda_in};
                2'd1: rx_data[23:16] <= {rx_data[22:16], sda_in};
                2'd2: rx_data[15:8]  <= {rx_data[14:8],  sda_in};
                2'd3: rx_data[7:0]   <= {rx_data[6:0],   sda_in};
                default: ;
            endcase
        end

    end
end
                                                       2'd3: begin scl_t <= 1'b1; end
                            default: ;
                        endcase
                        if (count1 == CLK4) begin
                            scl_t    <= 1'b0;
                            bitcount <= bitcount + 4'd1;
                        end
                    end else begin
                        // Byte complete
                        bitcount <= 4'd0;
                        sda_en   <= 1'b1;
                        state    <= last_byte ? MSTR_NACK : MSTR_ACK;
                    end
                end
 
                // -------------------------------------------
                // MSTR_ACK: master sends ACK (SDA=0) between
                //           multi-byte reads; then next byte
                // -------------------------------------------
                MSTR_ACK: begin
                    sda_en <= 1'b1;
                    case (pulse)
                        2'd0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                        2'd1: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                        2'd2: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                        2'd3: begin scl_t <= 1'b1; sda_t <= 1'b0; end
                        default: ;
                    endcase
                    if (count1 == CLK4) begin
                        scl_t    <= 1'b0;
                        byte_idx <= byte_idx + 2'd1;
                        bitcount <= 4'd0;
                        sda_en   <= 1'b0;
                        state    <= RD_DATA;
                    end
                end
 
                // -------------------------------------------
                // MSTR_NACK: master sends NACK (SDA=1) after
                //            last read byte -> then STOP
                // -------------------------------------------
                MSTR_NACK: begin
                    sda_en <= 1'b1;
                    case (pulse)
                        2'd0: begin scl_t <= 1'b0; sda_t <= 1'b1; end
                        2'd1: begin scl_t <= 1'b0; sda_t <= 1'b1; end
                        2'd2: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                        2'd3: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                        default: ;
                    endcase
                    if (count1 == CLK4) begin
                        // Latch final rx_data into dout register
                        // before transitioning to STOP
                        /*
$display("[%0t] FINAL rx_data=%h dout_r=%h",
         $time,
         rx_data, dout_r);
$display("[%0t] LATCHING rx_data=%h into dout_r",
         $time,
         rx_data);
*/
                        dout_r <= rx_data;
                        scl_t  <= 1'b0;
                        sda_t  <= 1'b0;   // pre-drive low for clean STOP transition
                        sda_en <= 1'b1;
                        state  <= STOP;
                    end
                end
 
                // -------------------------------------------
                // STOP: SDA rises while SCL is high
                // -------------------------------------------
                STOP: begin
                    sda_en <= 1'b1;
                    case (pulse)
                        2'd0: begin scl_t <= 1'b0; sda_t <= 1'b0; end
                        2'd1: begin scl_t <= 1'b1; sda_t <= 1'b0; end  // SCL rises first
                        2'd2: begin scl_t <= 1'b1; sda_t <= 1'b1; end  // SDA rises -> STOP
                        2'd3: begin scl_t <= 1'b1; sda_t <= 1'b1; end
                        default: ;
                    endcase
                    if (count1 == CLK4) begin
                        scl_t  <= 1'b1;
                        sda_t  <= 1'b1;
                        sda_en <= 1'b0;
                        busy   <= 1'b0;
                        done   <= 1'b1;
                        state  <= IDLE;
                    end
                end
 
                default: state <= IDLE;
 
            endcase
        end
    end
 
    // -------------------------------------------------------
    // Tri-state SDA driver
    //   sda_en=1 & sda_t=0  ->  pull SDA low
    //   sda_en=1 & sda_t=1  ->  high-Z (external RPU pulls high)
    //   sda_en=0             ->  high-Z (slave may drive freely)
    // -------------------------------------------------------
    assign sda  = (sda_en && (sda_t == 1'b0)) ? 1'b0 : 1'bz;
    assign scl  = scl_t;
 
    // dout is registered and only updates when a read completes
    // (latched in MSTR_NACK). This prevents X/glitch on the
    // APB read bus between transactions.
    assign dout = dout_r;
 
endmodule
 
