`timescale 1ns/1ps

module fir_top #(
    parameter DATA_WIDTH = 16,
    parameter COEFF_WIDTH = 16,
    parameter ACC_WIDTH = 40,
    parameter NUM_TAPS = 32,
    parameter FIFO_DEPTH = 16
)(
    input clk,
    input rst_n,

    // AXI4-Stream Input
    input s_axis_tvalid,
    output s_axis_tready,
    input [DATA_WIDTH-1:0] s_axis_tdata,

    // AXI4-Stream Output
    output m_axis_tvalid,
    input m_axis_tready,
    output [ACC_WIDTH-1:0] m_axis_tdata,

    // AXI4-Lite Control
    input [31:0] s_axi_awaddr,
    input s_axi_awvalid,
    output s_axi_awready,

    input [31:0] s_axi_wdata,
    input [3:0] s_axi_wstrb,
    input s_axi_wvalid,
    output s_axi_wready,

    output s_axi_bvalid,
    output [1:0] s_axi_bresp,
    input s_axi_bready,

    input [31:0] s_axi_araddr,
    input s_axi_arvalid,
    output s_axi_arready,

    output [31:0] s_axi_rdata,
    output s_axi_rvalid,
    output [1:0] s_axi_rresp,
    input s_axi_rready,

    // Status outputs
    output input_fifo_full,
    output input_fifo_empty,
    output output_fifo_empty
);

    // Control signals
    wire enable;
    wire [COEFF_WIDTH*NUM_TAPS-1:0] coeff_packed;
    
    // Input FIFO signals
    wire [DATA_WIDTH-1:0] fifo_in_data;
    wire fifo_in_valid;
    wire fifo_in_ready;
    
    // Delay line signals
    reg [DATA_WIDTH-1:0] delay [0:NUM_TAPS-1];
    wire [DATA_WIDTH-1:0] sample0, sample1, sample2, sample3;
    wire [DATA_WIDTH-1:0] sample4, sample5, sample6, sample7;
    wire [DATA_WIDTH-1:0] sample8, sample9, sample10, sample11;
    wire [DATA_WIDTH-1:0] sample12, sample13, sample14, sample15;
    wire [DATA_WIDTH-1:0] sample16, sample17, sample18, sample19;
    wire [DATA_WIDTH-1:0] sample20, sample21, sample22, sample23;
    wire [DATA_WIDTH-1:0] sample24, sample25, sample26, sample27;
    wire [DATA_WIDTH-1:0] sample28, sample29, sample30, sample31;
    
    // DSP signals
    wire [ACC_WIDTH-1:0] dsp_result;
    wire dsp_result_valid;
    wire dsp_result_ready;
    wire dsp_samples_ready;
    wire input_fifo_s_ready;
    wire output_fifo_full;
    wire input_fifo_full_int;
    wire input_fifo_empty_int;
    wire output_fifo_empty_int;
    
    integer i;

    // AXI4-Lite Control Interface
    fir_axi_lite #(
        .COEFF_WIDTH(COEFF_WIDTH),
        .NUM_TAPS(NUM_TAPS)
    ) u_axi_lite (
        .clk(clk),
        .rst_n(rst_n),

        .s_axi_awaddr(s_axi_awaddr),
        .s_axi_awvalid(s_axi_awvalid),
        .s_axi_awready(s_axi_awready),

        .s_axi_wdata(s_axi_wdata),
        .s_axi_wstrb(s_axi_wstrb),
        .s_axi_wvalid(s_axi_wvalid),
        .s_axi_wready(s_axi_wready),

        .s_axi_bvalid(s_axi_bvalid),
        .s_axi_bresp(s_axi_bresp),
        .s_axi_bready(s_axi_bready),

        .s_axi_araddr(s_axi_araddr),
        .s_axi_arvalid(s_axi_arvalid),
        .s_axi_arready(s_axi_arready),

        .s_axi_rdata(s_axi_rdata),
        .s_axi_rvalid(s_axi_rvalid),
        .s_axi_rresp(s_axi_rresp),
        .s_axi_rready(s_axi_rready),

        .enable(enable),
        .load_pulse(),

        .input_fifo_full(input_fifo_full),
        .input_fifo_empty(input_fifo_empty),
        .output_fifo_full(output_fifo_full),
        .output_fifo_empty(output_fifo_empty),

        .coeff_packed(coeff_packed)
    );

    // Input FIFO
    axis_fifo #(
        .DATA_WIDTH(DATA_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_input_fifo (
        .clk(clk),
        .rst_n(rst_n),
        
        .s_axis_tvalid(s_axis_tvalid && enable),
        .s_axis_tready(input_fifo_s_ready),
        .s_axis_tdata(s_axis_tdata),
        
        .m_axis_tvalid(fifo_in_valid),
        .m_axis_tready(fifo_in_ready),
        .m_axis_tdata(fifo_in_data),
        .full(input_fifo_full_int),
        .empty(input_fifo_empty_int)
    );
    
    assign s_axis_tready = enable && input_fifo_s_ready;
    assign input_fifo_full = input_fifo_full_int;
    assign input_fifo_empty = input_fifo_empty_int;

    // Delay Line
    wire samples_valid = fifo_in_valid && enable;
    wire samples_ready = dsp_samples_ready;
    
    assign fifo_in_ready = enable && samples_ready;
    
    // Include the currently accepted sample in the current dot product.
    assign sample0  = fifo_in_data;
    assign sample1  = delay[0];
    assign sample2  = delay[1];
    assign sample3  = delay[2];
    assign sample4  = delay[3];
    assign sample5  = delay[4];
    assign sample6  = delay[5];
    assign sample7  = delay[6];
    assign sample8  = delay[7];
    assign sample9  = delay[8];
    assign sample10 = delay[9];
    assign sample11 = delay[10];
    assign sample12 = delay[11];
    assign sample13 = delay[12];
    assign sample14 = delay[13];
    assign sample15 = delay[14];
    assign sample16 = delay[15];
    assign sample17 = delay[16];
    assign sample18 = delay[17];
    assign sample19 = delay[18];
    assign sample20 = delay[19];
    assign sample21 = delay[20];
    assign sample22 = delay[21];
    assign sample23 = delay[22];
    assign sample24 = delay[23];
    assign sample25 = delay[24];
    assign sample26 = delay[25];
    assign sample27 = delay[26];
    assign sample28 = delay[27];
    assign sample29 = delay[28];
    assign sample30 = delay[29];
    assign sample31 = delay[30];
    
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            for (i = 0; i < NUM_TAPS; i = i + 1)
                delay[i] <= 0;
        end
        else if (samples_valid && samples_ready) begin
            delay[0] <= fifo_in_data;
            for (i = 1; i < NUM_TAPS; i = i + 1)
                delay[i] <= delay[i-1];
        end
    end

    // DSP
    fir_dsp #(
        .DATA_WIDTH(DATA_WIDTH),
        .COEFF_WIDTH(COEFF_WIDTH),
        .ACC_WIDTH(ACC_WIDTH),
        .NUM_TAPS(NUM_TAPS)
    ) u_fir_dsp (
        .clk(clk),
        .rst_n(rst_n),
        
        .sample0(sample0),
        .sample1(sample1),
        .sample2(sample2),
        .sample3(sample3),
        .sample4(sample4),
        .sample5(sample5),
        .sample6(sample6),
        .sample7(sample7),
        .sample8(sample8),
        .sample9(sample9),
        .sample10(sample10),
        .sample11(sample11),
        .sample12(sample12),
        .sample13(sample13),
        .sample14(sample14),
        .sample15(sample15),
        .sample16(sample16),
        .sample17(sample17),
        .sample18(sample18),
        .sample19(sample19),
        .sample20(sample20),
        .sample21(sample21),
        .sample22(sample22),
        .sample23(sample23),
        .sample24(sample24),
        .sample25(sample25),
        .sample26(sample26),
        .sample27(sample27),
        .sample28(sample28),
        .sample29(sample29),
        .sample30(sample30),
        .sample31(sample31),
        
        .samples_valid(samples_valid),
        .samples_ready(dsp_samples_ready),
        .coeff_packed(coeff_packed),
        
        .result(dsp_result),
        .result_valid(dsp_result_valid),
        .result_ready(dsp_result_ready),
        
        .output_fifo_empty()
    );

    // Output FIFO
    axis_fifo #(
        .DATA_WIDTH(ACC_WIDTH),
        .FIFO_DEPTH(FIFO_DEPTH)
    ) u_output_fifo (
        .clk(clk),
        .rst_n(rst_n),
        
        .s_axis_tvalid(dsp_result_valid),
        .s_axis_tready(dsp_result_ready),
        .s_axis_tdata(dsp_result),
        
        .m_axis_tvalid(m_axis_tvalid),
        .m_axis_tready(m_axis_tready),
        .m_axis_tdata(m_axis_tdata),
        .full(output_fifo_full),
        .empty(output_fifo_empty_int)
    );
    
    assign output_fifo_empty = output_fifo_empty_int;

endmodule
