`timescale 1ns/1ps

module fft_stage_core_controller #(
    parameter int N = 1024
)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 start,
    input  logic [3:0]           stage,
    output logic                 done,
    output logic                 busy,

    // External sample memory access, only valid when full FFT is idle
    input  logic                 ext_we,
    input  logic [$clog2(N)-1:0] ext_waddr,
    input  logic [31:0]          ext_wdata,

    input  logic [$clog2(N)-1:0] ext_raddr,
    output logic [31:0]          ext_rdata
);

    localparam int AW    = $clog2(N);
    localparam int TW_AW = $clog2(N/2);

    typedef enum logic [2:0] {
        S_IDLE,
        S_KICK,
        S_RUN,
        S_DONE
    } state_t;

    state_t state, next_state;

    // Tracks whether BRAM currently holds FFT-output ordering.
    // When software loads fresh samples, they are stored in bit-reversed
    // locations for the DIT flow, so external reads must also bit-reverse
    // until a full FFT run completes. After a run completes, BRAM contents
    // are already in natural order and should be read back directly.
    logic data_is_fft_output;

    function automatic [AW-1:0] bitrev(input [AW-1:0] x);
        integer i;
        begin
            for (i = 0; i < AW; i = i + 1)
                bitrev[i] = x[AW-1-i];
        end
    endfunction

    // ------------------------------------------------------------
    // Memory interface signals
    // ------------------------------------------------------------
    logic          mem_en_a, mem_we_a;
    logic [AW-1:0] mem_addr_a;
    logic [31:0]   mem_din_a;
    logic [31:0]   mem_dout_a;

    logic          mem_en_b, mem_we_b;
    logic [AW-1:0] mem_addr_b;
    logic [31:0]   mem_din_b;
    logic [31:0]   mem_dout_b;

    // ------------------------------------------------------------
    // Stage-core handshake
    // ------------------------------------------------------------
    logic core_start;
    logic core_done;
    logic core_busy;

    // ------------------------------------------------------------
    // Stage-core RAM-side signals
    // ------------------------------------------------------------
    logic [AW-1:0] rd_addr_a;
    logic [AW-1:0] rd_addr_b;
    logic [31:0]   rd_data_a;
    logic [31:0]   rd_data_b;

    logic          wr_en_a;
    logic          wr_en_b;
    logic [AW-1:0] wr_addr_a;
    logic [AW-1:0] wr_addr_b;
    logic [31:0]   wr_data_a;
    logic [31:0]   wr_data_b;

    // ------------------------------------------------------------
    // Twiddle ROM
    // ------------------------------------------------------------
    logic [TW_AW-1:0] tw_addr;
    logic [31:0]      tw_data;

    twiddle_rom #(
        .N(N/2)
    ) u_twiddle_rom (
        .clk    (clk),
        .tw_addr(tw_addr),
        .tw_data(tw_data)
    );

    // ------------------------------------------------------------
    // FFT stage core
    // ------------------------------------------------------------
    fft_stage_core #(
        .N(N)
    ) u_stage_core (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (core_start),
        .stage    (stage),
        .done     (core_done),
        .busy     (core_busy),

        .rd_addr_a(rd_addr_a),
        .rd_addr_b(rd_addr_b),
        .rd_data_a(rd_data_a),
        .rd_data_b(rd_data_b),

        .wr_en_a  (wr_en_a),
        .wr_en_b  (wr_en_b),
        .wr_addr_a(wr_addr_a),
        .wr_addr_b(wr_addr_b),
        .wr_data_a(wr_data_a),
        .wr_data_b(wr_data_b),

        .tw_addr  (tw_addr),
        .tw_data  (tw_data)
    );

    // ------------------------------------------------------------
    // Sample memory instance
    // ------------------------------------------------------------
    
     
    bram_memeory#(
    .N(N),
    .DATA_W(32),
    .AW(AW)
    ) u_sample_mem (
        .clk   (clk),

        .en_a  (mem_en_a),
        .we_a  (mem_we_a),
        .addr_a(mem_addr_a),
        .din_a (mem_din_a),
        .dout_a(mem_dout_a),

        .en_b  (mem_en_b),
        .we_b  (mem_we_b),
        .addr_b(mem_addr_b),
        .din_b (mem_din_b),
        .dout_b(mem_dout_b)
    );

    // ------------------------------------------------------------
    // FSM
    // ------------------------------------------------------------
    always_comb begin
        next_state = state;
        core_start = 1'b0;
        done       = 1'b0;
        busy       = (state != S_IDLE);

        case (state)
            S_IDLE: begin
                if (start)
                    next_state = S_KICK;
            end

            S_KICK: begin
                core_start = 1'b1;
                next_state = S_RUN;
            end

            S_RUN: begin
                if (core_done)
                    next_state = S_DONE;
            end

            S_DONE: begin
                done       = 1'b1;
                next_state = S_IDLE;
            end

            default: begin
                next_state = S_IDLE;
            end
        endcase
    end

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state <= S_IDLE;
            data_is_fft_output <= 1'b0;
        end
        else begin
            state <= next_state;

            if ((state == S_IDLE) && ext_we)
                data_is_fft_output <= 1'b0;
            else if (state == S_DONE)
                data_is_fft_output <= 1'b1;
        end
    end

    // ------------------------------------------------------------
    // Port muxing
    //
    // IDLE:
    //   Port A = external access
    //   Port B = unused
    //
    // RUN:
    //   READ phase handled by stage_core internal timing
    //   WRITE phase handled by wr_en_a / wr_en_b
    // ------------------------------------------------------------
    always_comb begin
        mem_en_a   = 1'b0;
        mem_we_a   = 1'b0;
        mem_addr_a = '0;
        mem_din_a  = '0;

        mem_en_b   = 1'b0;
        mem_we_b   = 1'b0;
        mem_addr_b = '0;
        mem_din_b  = '0;

        ext_rdata = mem_dout_a;

        case (state)
            S_IDLE: begin
                mem_en_a   = 1'b1;
                mem_we_a   = ext_we;
                mem_addr_a = ext_we
                           ? bitrev(ext_waddr)
                           : (data_is_fft_output ? ext_raddr : bitrev(ext_raddr));
                mem_din_a  = ext_wdata;
            end

            S_RUN: begin
                mem_en_a = 1'b1;
                mem_en_b = 1'b1;

                if (wr_en_a || wr_en_b) begin
                    mem_we_a   = wr_en_a;
                    mem_addr_a = wr_addr_a;
                    mem_din_a  = wr_data_a;

                    mem_we_b   = wr_en_b;
                    mem_addr_b = wr_addr_b;
                    mem_din_b  = wr_data_b;
                end
                else begin
                    mem_we_a   = 1'b0;
                    mem_addr_a = rd_addr_a;

                    mem_we_b   = 1'b0;
                    mem_addr_b = rd_addr_b;
                end
            end

            default: begin
            end
        endcase
    end

    // ------------------------------------------------------------
    // Feed synchronous read data to stage core
    // ------------------------------------------------------------
    assign rd_data_a = mem_dout_a;
    assign rd_data_b = mem_dout_b;

endmodule
