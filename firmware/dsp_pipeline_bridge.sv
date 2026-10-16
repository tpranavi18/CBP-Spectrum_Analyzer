// ============================================================================
// File: dsp_pipeline_bridge.sv
// Module: dsp_pipeline_bridge
// Project: CBP Spectrum Analyzer SoC Integration
// Location: /home/student/Documents/CBP-Spectrum_Analyzer/firmware/dsp_pipeline_bridge.sv
//
// Description:
//   Project-owned hardware integration component that bridges the architectural
//   gaps between:
//     1. ADC Controller (discrete sample handshake) -> FIR Filter (AXI4-Stream)
//     2. FIR Filter (AXI4-Stream output) -> FFT Accelerator (Memory-Mapped BRAM)
//
//   Provides autonomous hardware streaming and DMA transfer over the SoC AXI
//   Interconnect, enabling complete end-to-end DSP pipeline execution:
//     Analog/Digital ADC Sample -> FIR Filtering -> FFT Transformation -> CPU Bins.
// ============================================================================

`timescale 1ns/1ps

module dsp_pipeline_bridge #(
    parameter int ADC_WIDTH  = 12,
    parameter int FIR_WIDTH  = 16,
    parameter int ACC_WIDTH  = 40,
    parameter int FFT_POINTS = 1024,
    parameter int ID_WIDTH   = 8
)(
    input  logic                    clk,
    input  logic                    rst_n,

    // Control and Status
    input  logic                    start_pipeline,
    output logic                    pipeline_busy,
    output logic                    pipeline_done,

    // ------------------------------------------------------------------------
    // Stage 1: ADC Controller Handshake Interface
    // ------------------------------------------------------------------------
    input  logic [ADC_WIDTH-1:0]    adc_sample_in,
    input  logic                    adc_sample_valid,
    output logic                    adc_sample_ack,

    // ------------------------------------------------------------------------
    // Stage 2: FIR Filter AXI4-Stream Input Interface
    // ------------------------------------------------------------------------
    output logic                    fir_s_axis_tvalid,
    input  logic                    fir_s_axis_tready,
    output logic [FIR_WIDTH-1:0]    fir_s_axis_tdata,

    // ------------------------------------------------------------------------
    // Stage 3: FIR Filter AXI4-Stream Output Interface
    // ------------------------------------------------------------------------
    input  logic                    fir_m_axis_tvalid,
    output logic                    fir_m_axis_tready,
    input  logic [ACC_WIDTH-1:0]    fir_m_axis_tdata,

    // ------------------------------------------------------------------------
    // Stage 4: AXI4 Master DMA Interface to FFT BRAM (Slave 6: 0x4000_A000)
    //          and FFT Start Control (Slave 5: 0x4000_8000)
    // ------------------------------------------------------------------------
    output logic [ID_WIDTH-1:0]     m_axi_awid,
    output logic [31:0]             m_axi_awaddr,
    output logic [7:0]              m_axi_awlen,
    output logic [2:0]              m_axi_awsize,
    output logic [1:0]              m_axi_awburst,
    output logic                    m_axi_awvalid,
    input  logic                    m_axi_awready,

    output logic [31:0]             m_axi_wdata,
    output logic [3:0]              m_axi_wstrb,
    output logic                    m_axi_wlast,
    output logic                    m_axi_wvalid,
    input  logic                    m_axi_wready,

    input  logic [ID_WIDTH-1:0]     m_axi_bid,
    input  logic [1:0]              m_axi_bresp,
    input  logic                    m_axi_bvalid,
    output logic                    m_axi_bready,

    // Read interface (unused for DMA store, tied off)
    output logic [ID_WIDTH-1:0]     m_axi_arid,
    output logic [31:0]             m_axi_araddr,
    output logic [7:0]              m_axi_arlen,
    output logic [2:0]              m_axi_arsize,
    output logic [1:0]              m_axi_arburst,
    output logic                    m_axi_arvalid,
    input  logic                    m_axi_arready,
    input  logic [ID_WIDTH-1:0]     m_axi_rid,
    input  logic [31:0]             m_axi_rdata,
    input  logic [1:0]              m_axi_rresp,
    input  logic                    m_axi_rlast,
    input  logic                    m_axi_rvalid,
    output logic                    m_axi_rready,

    // ------------------------------------------------------------------------
    // Diagnostics & Observable Metrics
    // ------------------------------------------------------------------------
    output logic [15:0]             adc_samples_captured,
    output logic [15:0]             fir_samples_delivered,
    output logic [15:0]             fft_words_stored
);

    // Static AXI Read Channel tie-offs
    assign m_axi_arid    = '0;
    assign m_axi_araddr  = '0;
    assign m_axi_arlen   = '0;
    assign m_axi_arsize  = 3'b010;
    assign m_axi_arburst = 2'b01;
    assign m_axi_arvalid = 1'b0;
    assign m_axi_rready  = 1'b1;

    // Static AXI Write Channel configuration
    assign m_axi_awid    = 8'hA1;
    assign m_axi_awlen   = 8'h00; // Single transfers
    assign m_axi_awsize  = 3'b010; // 32-bit (4 bytes)
    assign m_axi_awburst = 2'b01; // INCR
    assign m_axi_wstrb   = 4'hF;   // All 4 bytes active
    assign m_axi_wlast   = 1'b1;   // Single-beat bursts

    // ========================================================================
    // Internal FSM States
    // ========================================================================
    typedef enum logic [2:0] {
        ST_IDLE             = 3'd0,
        ST_PIPE_RUNNING     = 3'd1,
        ST_WRITE_FFT_START  = 3'd2,
        ST_WAIT_FFT_START_B = 3'd3,
        ST_WAIT_FFT_COMPL   = 3'd4,
        ST_DONE             = 3'd5
    } bridge_state_t;

    bridge_state_t state;

    // Internal FIFO for ADC to FIR stream adaptation
    logic [ADC_WIDTH-1:0] adc_skid_data;
    logic                 adc_skid_valid;

    // Internal FIFO for FIR to FFT DMA transfer
    logic [31:0]          fir_dma_fifo [0:15];
    logic [3:0]           dma_wr_ptr;
    logic [3:0]           dma_rd_ptr;
    logic [4:0]           dma_count;

    wire dma_fifo_full  = (dma_count == 5'd16);
    wire dma_fifo_empty = (dma_count == 5'd0);

    // ------------------------------------------------------------------------
    // Stage 1: ADC Controller -> FIR AXI-Stream Adapter
    // ------------------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            adc_skid_valid       <= 1'b0;
            adc_skid_data        <= '0;
            adc_samples_captured <= '0;
            adc_sample_ack       <= 1'b0;
        end else if (state == ST_PIPE_RUNNING) begin
            adc_sample_ack <= 1'b0;

            // Capture new sample from ADC interface
            if (adc_sample_valid && (!adc_skid_valid || (fir_s_axis_tvalid && fir_s_axis_tready))) begin
                adc_skid_data        <= adc_sample_in;
                adc_skid_valid       <= 1'b1;
                adc_sample_ack       <= 1'b1;
                adc_samples_captured <= adc_samples_captured + 1'b1;
            end else if (fir_s_axis_tvalid && fir_s_axis_tready) begin
                adc_skid_valid <= 1'b0;
            end
        end else begin
            adc_skid_valid <= 1'b0;
            adc_sample_ack <= 1'b0;
        end
    end

    // Map 12-bit ADC unsigned range [0..4095] to 16-bit signed Q1.15 stream
    // Scaling: (adc_sample - 2048) <<< 4 produces signed values around zero.
    wire signed [15:0] adc_scaled_signed = { {4{adc_skid_data[11]}}, adc_skid_data } <<< 4;

    assign fir_s_axis_tvalid = adc_skid_valid && (state == ST_PIPE_RUNNING);
    assign fir_s_axis_tdata  = adc_scaled_signed;

    // ------------------------------------------------------------------------
    // Stage 2: FIR AXI-Stream Output -> DMA Buffer
    // ------------------------------------------------------------------------
    assign fir_m_axis_tready = (state == ST_PIPE_RUNNING) && !dma_fifo_full;

    // Extract 16-bit Q1.15 real part from 40-bit accumulator: bits [31:16]
    wire [15:0] fir_out_q15 = fir_m_axis_tdata[31:16];
    // Pack into 32-bit complex format: {Real[15:0], Imag[15:0]=0}
    wire [31:0] complex_fft_word = {fir_out_q15, 16'h0000};

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            dma_wr_ptr            <= '0;
            dma_rd_ptr            <= '0;
            dma_count             <= '0;
            fir_samples_delivered <= '0;
        end else begin
            // Push from FIR stream
            if (fir_m_axis_tvalid && fir_m_axis_tready) begin
                fir_dma_fifo[dma_wr_ptr] <= complex_fft_word;
                dma_wr_ptr               <= dma_wr_ptr + 1'b1;
                fir_samples_delivered    <= fir_samples_delivered + 1'b1;
                if (!(m_axi_wvalid && m_axi_wready)) begin
                    dma_count <= dma_count + 1'b1;
                end
            end
            // Pop to AXI Write Channel
            else if (m_axi_wvalid && m_axi_wready) begin
                dma_rd_ptr <= dma_rd_ptr + 1'b1;
                dma_count  <= dma_count - 1'b1;
            end
        end
    end

    // ------------------------------------------------------------------------
    // Stage 3: AXI Master DMA Engine into FFT BRAM (0x4000_A000)
    // ------------------------------------------------------------------------
    logic [15:0] word_idx;
    logic        aw_done, w_done;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            state            <= ST_IDLE;
            word_idx         <= '0;
            fft_words_stored <= '0;
            m_axi_awaddr     <= '0;
            m_axi_awvalid    <= 1'b0;
            m_axi_wdata      <= '0;
            m_axi_wvalid     <= 1'b0;
            m_axi_bready     <= 1'b0;
            aw_done          <= 1'b0;
            w_done           <= 1'b0;
            pipeline_busy    <= 1'b0;
            pipeline_done    <= 1'b0;
        end else begin
            case (state)
                ST_IDLE: begin
                    pipeline_done <= 1'b0;
                    if (start_pipeline) begin
                        state            <= ST_PIPE_RUNNING;
                        pipeline_busy    <= 1'b1;
                        word_idx         <= '0;
                        fft_words_stored <= '0;
                        aw_done          <= 1'b0;
                        w_done           <= 1'b0;
                    end
                end

                ST_PIPE_RUNNING: begin
                    // When DMA buffer has data and write transaction not in flight:
                    if (!dma_fifo_empty && !m_axi_awvalid && !m_axi_wvalid && !aw_done && !w_done) begin
                        m_axi_awaddr  <= 32'h4000_A000 + (word_idx << 2);
                        m_axi_awvalid <= 1'b1;
                        m_axi_wdata   <= fir_dma_fifo[dma_rd_ptr];
                        m_axi_wvalid  <= 1'b1;
                        m_axi_bready  <= 1'b1;
                    end

                    // Address write handshake
                    if (m_axi_awvalid && m_axi_awready) begin
                        m_axi_awvalid <= 1'b0;
                        aw_done       <= 1'b1;
                    end

                    // Data write handshake
                    if (m_axi_wvalid && m_axi_wready) begin
                        m_axi_wvalid <= 1'b0;
                        w_done       <= 1'b1;
                    end

                    // Response handshake
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready     <= 1'b0;
                        aw_done          <= 1'b0;
                        w_done           <= 1'b0;
                        fft_words_stored <= fft_words_stored + 1'b1;
                        word_idx         <= word_idx + 1'b1;

                        // Check if batch is completed
                        if (word_idx + 1'b1 >= 16'd32) begin
                            state <= ST_WRITE_FFT_START;
                        end
                    end
                end

                // Issue FFT Start Pulse to 0x4000_8000
                ST_WRITE_FFT_START: begin
                    m_axi_awaddr  <= 32'h4000_8000;
                    m_axi_awvalid <= 1'b1;
                    m_axi_wdata   <= 32'h0000_0001; // START = 1
                    m_axi_wvalid  <= 1'b1;
                    m_axi_bready  <= 1'b1;
                    state         <= ST_WAIT_FFT_START_B;
                end

                ST_WAIT_FFT_START_B: begin
                    if (m_axi_awvalid && m_axi_awready) m_axi_awvalid <= 1'b0;
                    if (m_axi_wvalid && m_axi_wready)   m_axi_wvalid  <= 1'b0;
                    if (m_axi_bvalid && m_axi_bready) begin
                        m_axi_bready <= 1'b0;
                        state        <= ST_DONE;
                    end
                end

                ST_DONE: begin
                    pipeline_busy <= 1'b0;
                    pipeline_done <= 1'b1;
                    if (!start_pipeline) begin
                        state <= ST_IDLE;
                    end
                end

                default: state <= ST_IDLE;
            endcase
        end
    end

endmodule
