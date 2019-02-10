module i2c_master (
    input           clk,
    input           rst,
    // -- original ports (UNCHANGED) ------------------------------------------
    input           newd,           // 1-cycle start pulse
    input           op,             // 0 = write, 1 = read
    input  [6:0]    addr,           // 7-bit slave address
    input  [7:0]    din,            // single-byte TX data (din32[7:0] alias)
    output [7:0]    dout,           // single-byte RX data (dout32[31:24])
    // -- new multi-byte ports -------------------------------------------------
    input  [31:0]   reg_addr,       // register address, MSB first
    input  [1:0]    reg_addr_bytes, // number of reg-addr bytes - 1  (0=1B…3=4B)
    input  [1:0]    data_bytes,     // number of data bytes - 1      (0=1B…3=4B)
    input  [31:0]   din32,          // multi-byte TX data, MSB first
    output [31:0]   dout32,         // multi-byte RX data, MSB first
    // -- I2C lines ------------------------------------------------------------
    inout           sda,
    output          scl,
    // -- status ---------------------------------------------------------------
    output reg      busy,
    output reg      done,
    output reg      ack_err
);

// -- single-byte aliases ------------------------------------------------------
// dout maps the first (and only) byte received, stored at dout32[31:24].
reg [31:0] dout32_r;
assign dout   = dout32_r[31:24];
assign dout32 = dout32_r;

// -- tri-state SDA -------------------------------------------------------------
reg scl_r, sda_r, sda_en;
assign scl = scl_r;
assign sda = sda_en ? sda_r : 1'bz;

// -- address bytes -------------------------------------------------------------
wire [7:0] addr_w = {addr, 1'b0};   // write frame
wire [7:0] addr_r_byte = {addr, 1'b1};   // read  frame

// -- internal registers --------------------------------------------------------

reg [7:0]  rx_shift;        // bit-shift buffer during READ_DATA

reg        newd_lat;        // latched start; cleared on FSM departure from IDLE
reg        ack_sample;

reg [2:0]  bitcnt;          // 0-7, counts bits within a byte
reg [1:0]  reg_bytecnt;     // counts reg-addr bytes sent   (0 … reg_addr_bytes)
reg [1:0]  data_bytecnt;    // counts data bytes transferred(0 … data_bytes)

// 4-phase sub-clock per SCL period: 0=setup, 1=SCL-rise, 2=SCL-fall, 3=end
reg [3:0]  pulse;
reg [15:0] clk_div;
localparam CLK_DIV_MAX = 16'd99;   // SCL period = 4 × 100 × Tclk

// -- states --------------------------------------------------------------------
localparam [3:0]
    IDLE           = 4'd0,
    START          = 4'd1,
    SEND_ADDR_W    = 4'd2,
    ACK_ADDR_W     = 4'd3,
    SEND_REG       = 4'd4,
    ACK_REG        = 4'd5,
    REPEATED_START = 4'd6,
    SEND_ADDR_R    = 4'd7,
    ACK_ADDR_R     = 4'd8,
    WRITE_DATA     = 4'd9,
    READ_DATA      = 4'd10,
    ACK_DATA       = 4'd11,
    STOP           = 4'd12;

reg [3:0] state;

// -------------------------------------------------------------------------------
// 1.  Free-running 4-phase clock divider
// -------------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        pulse   <= 0;
        clk_div <= 0;
    end else begin
        if (clk_div == CLK_DIV_MAX) begin
            clk_div <= 0;
            pulse   <= (pulse == 3) ? 0 : pulse + 1;
        end else
            clk_div <= clk_div + 1;
    end
end

// -------------------------------------------------------------------------------
// 2.  newd latch  – capture the 1-cycle pulse; hold until FSM leaves IDLE
// -------------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst)
        newd_lat <= 0;
    else if (newd)
        newd_lat <= 1;                // arm on pulse
    else if (state == IDLE && newd_lat && pulse == 3)
        newd_lat <= 0;                // clear once FSM actually departs
end

// -------------------------------------------------------------------------------
// 3.  Byte-selector helpers (MSB-first ordering)
//     _bytes field encodes (total - 1).
//     byte index 0 = most-significant active byte.
// -------------------------------------------------------------------------------
//  Example reg_addr_bytes=1 (2 bytes):
//    reg_bytecnt=0 ? send ra[15:8]   (shift = 1-0 = 1)
//    reg_bytecnt=1 ? send ra[7:0]    (shift = 1-1 = 0)
function [7:0] byte_of;
    input [1:0] total_m1;  // _bytes field
    input [1:0] idx;       // current byte index
    input [31:0] word;
    reg [1:0] sh;
    begin
        sh = total_m1 - idx;
        case (sh)
            2'd3: byte_of = word[31:24];
            2'd2: byte_of = word[23:16];
            2'd1: byte_of = word[15:8];
            2'd0: byte_of = word[7:0];
        endcase
    end
endfunction

wire [7:0] cur_reg_byte  = byte_of(reg_addr_bytes, reg_bytecnt,  reg_addr);
wire [7:0] cur_data_byte = byte_of(data_bytes,     data_bytecnt, din32);

// -------------------------------------------------------------------------------
// 4.  Counters  (bit, reg-byte, data-byte)
//     All updates happen at pulse==3 so they are ready before the next pulse==0.
// -------------------------------------------------------------------------------
always @(posedge clk or posedge rst) begin
    if (rst) begin
        bitcnt       <= 0;
        reg_bytecnt  <= 0;
        data_bytecnt <= 0;
    end else begin
        // -- bit counter  (increments every SCL period in bit-shift states) --
        if (pulse == 3 && (state == SEND_ADDR_W || state == SEND_ADDR_R ||
                           state == SEND_REG    || state == WRITE_DATA  ||
                           state == READ_DATA))
            bitcnt <= (bitcnt == 7) ? 0 : bitcnt + 1;

        // -- reg-byte counter  (one up per successful ACK_REG) ---------------
        if (state == ACK_REG && pulse == 3 && !ack_sample)
            reg_bytecnt <= reg_bytecnt + 1;

        // -- data-byte counter  (one up per ACK_DATA) ------------------------
        if (state == ACK_DATA && pulse == 3)
            data_bytecnt <= data_bytecnt + 1;

        // -- reset all on STOP exit -------------------------------------------
        if (state == STOP && pulse == 3) begin
            bitcnt       <= 0;
            reg_bytecnt  <= 0;
            data_bytecnt <= 0;
        end
    end
end

// 5.  FSM  (state + outputs combined; Mealy on pulse)
always @(posedge clk or posedge rst) begin
    if (rst) begin
        state       <= IDLE;
        scl_r       <= 1;
        sda_r       <= 1;
        sda_en      <= 0;
        busy        <= 0;
        done        <= 0;
        ack_err     <= 0;
        ack_sample  <= 0;
        dout32_r    <= 0;
        rx_shift    <= 0;
    end else begin
        case (state)

        // -- IDLE -------------------------------------------------------------
        // Wait for newd_lat at a pulse==3 boundary so the FSM always enters
        // START cleanly at the top of a new SCL sub-cycle.
        IDLE: begin
            scl_r   <= 1;
            sda_r   <= 1;
            sda_en  <= 0;
            busy    <= 0;
            done    <= 0;
            ack_err <= 0;
            if (newd_lat && pulse == 3)
                state <= START;
        end

        // -- START condition: SDA falls while SCL high ---------------------
        START: begin
            busy <= 1;
            case (pulse)
                0: begin scl_r <= 1; sda_r <= 1; sda_en <= 1; end
                1: begin sda_r <= 0;  end   // SDA falls, SCL still high
                2: begin scl_r <= 0;  end   // pull SCL low to begin first bit
                3: state <= SEND_ADDR_W;
            endcase
        end

        // -- send 8-bit slave address + W ---------------------------------
        SEND_ADDR_W: begin
            case (pulse)
                0: begin scl_r <= 0; sda_r <= addr_w[7 - bitcnt]; sda_en <= 1; end
                1: begin scl_r <= 1; end
                2: begin scl_r <= 0; end
                3: if (bitcnt == 7) state <= ACK_ADDR_W;
            endcase
        end

        // -- slave ACK after address+W ------------------------------------
        ACK_ADDR_W: begin
            case (pulse)
                0: begin scl_r <= 0; sda_en <= 0; end
                1: begin scl_r <= 1; ack_sample <= sda; end
                2: begin scl_r <= 0; end
                3: begin ack_err <= ack_sample;
                if (ack_sample)
        state <= STOP;
    else
        state <= SEND_REG;
end
            endcase
        end

        // -- send one register-address byte --------------------------------
        SEND_REG: begin
            case (pulse)
                0: begin scl_r <= 0; sda_r <= cur_reg_byte[7 - bitcnt]; sda_en <= 1; end
                1: begin scl_r <= 1; end
                2: begin scl_r <= 0; end
                3: if (bitcnt == 7) state <= ACK_REG;
            endcase
        end

        // -- slave ACK after register-address byte ------------------------
        ACK_REG: begin
            case (pulse)
                0: begin scl_r <= 0; sda_en <= 0; end
                1: begin scl_r <= 1; ack_sample <= sda; end
                2: begin scl_r <= 0; end
                3: begin

    ack_err <= ack_sample;

    if (ack_sample)
        state <= STOP;
    else if (reg_bytecnt == reg_addr_bytes)
        state <= op ? REPEATED_START : WRITE_DATA;
    else
        state <= SEND_REG;

end
            endcase
        end

        // -- repeated START for read transactions -------------------------
        REPEATED_START: begin
            case (pulse)
                0: begin scl_r <= 1; sda_r <= 1; sda_en <= 1; end
                1: begin sda_r <= 0; end   // SDA falls while SCL high
                2: begin scl_r <= 0; end
                3: state <= SEND_ADDR_R;
            endcase
        end

        // -- send 8-bit slave address + R ---------------------------------
        SEND_ADDR_R: begin
            case (pulse)
                0: begin scl_r <= 0; sda_r <= addr_r_byte[7 - bitcnt]; sda_en <= 1; end
                1: begin scl_r <= 1; end
                2: begin scl_r <= 0; end
                3: if (bitcnt == 7) state <= ACK_ADDR_R;
            endcase
        end

        // -- slave ACK after address+R -------------------------------------
        ACK_ADDR_R: begin
            case (pulse)
                0: begin scl_r <= 0; sda_en <= 0; end
                1: begin scl_r <= 1; ack_sample <= sda; end
                2: begin scl_r <= 0; end
                3: begin

    ack_err <= ack_sample;

    if (ack_sample)
        state <= STOP;
    else
        state <= READ_DATA;

end
            endcase
        end

        // -- write one data byte -------------------------------------------
        WRITE_DATA: begin
            case (pulse)
                0: begin scl_r <= 0; sda_r <= cur_data_byte[7 - bitcnt]; sda_en <= 1; end
                1: begin scl_r <= 1; end
                2: begin scl_r <= 0; end
                3: if (bitcnt == 7) state <= ACK_DATA;
            endcase
        end

        // -- read one data byte --------------------------------------------
        // Sample SDA on rising SCL edge (pulse==1).
        // After all 8 bits collected (bitcnt==7, pulse==3) store the byte
        // into the correct dout32 slot, then move to ACK_DATA.
        READ_DATA: begin
            case (pulse)
                0: begin scl_r <= 0; sda_en <= 0; end
                1: begin
                    scl_r <= 1;
                    rx_shift[7 - bitcnt] <= sda;   // sample bit
                end
                2: begin scl_r <= 0; end
                3: begin
                    if (bitcnt == 7) begin
                        // store completed byte MSB-first into dout32_r
                        case (data_bytecnt)
                            2'd0: dout32_r[31:24] <= {rx_shift[7:1], sda};
                            2'd1: dout32_r[23:16] <= {rx_shift[7:1], sda};
                            2'd2: dout32_r[15:8]  <= {rx_shift[7:1], sda};
                            2'd3: dout32_r[7:0]   <= {rx_shift[7:1], sda};
                        endcase
                        state <= ACK_DATA;
                    end
                end
            endcase
        end

        // -- ACK / NACK after each data byte -------------------------------
        // READ  path: master drives ACK(0) for more bytes, NACK(1) on last.
        //             Last byte = when data_bytecnt == data_bytes at entry.
        // WRITE path: slave drives ACK; master samples and records ack_err.
        ACK_DATA: begin
            if (op) begin
                // -- READ path ---------------------------------------------
                case (pulse)
                    0: begin
                        scl_r  <= 0;
                        // NACK on last byte (data_bytecnt hasn't incremented yet)
                        sda_r  <= (data_bytecnt == data_bytes) ? 1'b1 : 1'b0;
                        sda_en <= 1;
                    end
                    1: begin scl_r <= 1; end
                    2: begin scl_r <= 0; end
                    3: begin
                        // data_bytecnt is about to be incremented (see counter block).
                        // Use pre-increment value to decide next state.
                        if (data_bytecnt == data_bytes)
                            state <= STOP;
                        else
                            state <= READ_DATA;
                    end
                endcase
            end else begin
                // -- WRITE path --------------------------------------------
                case (pulse)
                    0: begin scl_r <= 0; sda_en <= 0; end
                    1: begin scl_r <= 1; ack_sample <= sda; end
                    2: begin scl_r <= 0; end
                    3: begin

    ack_err <= ack_sample;

    if (ack_sample || data_bytecnt == data_bytes)
        state <= STOP;
    else
        state <= WRITE_DATA;

end
                endcase
            end
        end

        // -- STOP condition: SDA rises while SCL high ----------------------
        STOP: begin
            case (pulse)
                0: begin scl_r <= 0; sda_r <= 0; sda_en <= 1; end
                1: begin scl_r <= 1; end         // SCL high first
                2: begin sda_r <= 1; end         // then SDA rises
                3: begin
                    busy <= 0;
                    done <= 1;
                    state <= IDLE;
                end
            endcase
        end

        default: state <= IDLE;
        endcase
    end
end

endmodule
