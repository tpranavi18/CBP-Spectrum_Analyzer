`timescale 1ns/1ps

module fir_axi_lite #(
    parameter COEFF_WIDTH = 16,
    parameter NUM_TAPS = 32
)(
    input clk,
    input rst_n,

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

    output reg enable,
    output reg load_pulse,

    input input_fifo_full,
    input input_fifo_empty,
    input output_fifo_full,
    input output_fifo_empty,

    output [COEFF_WIDTH*NUM_TAPS-1:0] coeff_packed
);

    reg enable_reg;
    reg load_coeffs_reg;
    reg [COEFF_WIDTH-1:0] coeff_reg [0:NUM_TAPS-1];
    reg [COEFF_WIDTH-1:0] active_coeff_reg [0:NUM_TAPS-1];

    integer i;

    // Direct output assignment
    always @(*) begin
        enable = enable_reg;
        load_pulse = load_coeffs_reg;
    end

    // AXI Write Channel
    reg [31:0] write_addr_reg;
    reg [31:0] write_data_reg;
    reg [3:0] write_strb_reg;
    reg aw_captured;
    reg w_captured;
    reg bvalid_reg;

    assign s_axi_awready = !aw_captured && !bvalid_reg;
    assign s_axi_wready = !w_captured && !bvalid_reg;
    assign s_axi_bvalid = bvalid_reg;
    assign s_axi_bresp = 2'b00;

    wire aw_handshake = s_axi_awvalid && s_axi_awready;
    wire w_handshake = s_axi_wvalid && s_axi_wready;

    wire write_fire = (aw_captured || aw_handshake) &&
                      (w_captured || w_handshake) &&
                      !bvalid_reg;

    // Select either a previously captured channel or the value handshaking now.
    wire [31:0] write_addr = aw_captured ? write_addr_reg : s_axi_awaddr;
    wire [31:0] write_data = w_captured  ? write_data_reg : s_axi_wdata;
    wire [3:0] write_strb = w_captured ? write_strb_reg : s_axi_wstrb;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            write_addr_reg <= 0;
            write_data_reg <= 0;
            write_strb_reg <= 0;
            aw_captured <= 1'b0;
            w_captured <= 1'b0;
            bvalid_reg <= 1'b0;
        end else begin
            if (aw_handshake) begin
                write_addr_reg <= s_axi_awaddr;
                aw_captured <= 1'b1;
            end

            if (w_handshake) begin
                write_data_reg <= s_axi_wdata;
                write_strb_reg <= s_axi_wstrb;
                w_captured <= 1'b1;
            end

            if (write_fire) begin
                bvalid_reg <= 1'b1;
                aw_captured <= 1'b0;
                w_captured <= 1'b0;
            end

            if (bvalid_reg && s_axi_bready)
                bvalid_reg <= 1'b0;
        end
    end

    // Write decode
    wire write_control = write_fire && (write_addr == 32'h00000000);
    wire write_load = write_fire && (write_addr == 32'h00000004);
    wire write_coeff = write_fire &&
                       (write_addr >= 32'h00000010) &&
                       (write_addr < (32'h00000010 + NUM_TAPS*4));

    // Control and coefficient register updates
    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            enable_reg <= 1'b0;
            load_coeffs_reg <= 1'b0;
            for (i = 0; i < NUM_TAPS; i = i + 1) begin
                coeff_reg[i] <= {COEFF_WIDTH{1'b0}};
                active_coeff_reg[i] <= {COEFF_WIDTH{1'b0}};
            end
        end else begin
            load_coeffs_reg <= 1'b0;

            if (write_control) begin
                if (write_strb[0])
                    enable_reg <= write_data[0];
            end

            if (write_load) begin
                load_coeffs_reg <= 1'b1;
                for (i = 0; i < NUM_TAPS; i = i + 1)
                    active_coeff_reg[i] <= coeff_reg[i];
            end

            if (write_coeff) begin
                if (write_strb[0])
                    coeff_reg[(write_addr - 32'h00000010) >> 2][7:0] <= write_data[7:0];
                if (COEFF_WIDTH > 8 && write_strb[1])
                    coeff_reg[(write_addr - 32'h00000010) >> 2][15:8] <= write_data[15:8];
            end
        end
    end

    // AXI Read Channel
    reg [31:0] read_addr_reg;
    reg read_pending;
    reg rvalid_reg;

    assign s_axi_arready = !read_pending && !rvalid_reg;
    assign s_axi_rvalid = rvalid_reg;
    assign s_axi_rresp = 2'b00;

    wire ar_handshake = s_axi_arvalid && s_axi_arready;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            read_addr_reg <= 0;
            read_pending <= 1'b0;
            rvalid_reg <= 1'b0;
        end else begin
            if (ar_handshake) begin
                read_addr_reg <= s_axi_araddr;
                read_pending <= 1'b1;
            end

            if (read_pending) begin
                read_pending <= 1'b0;
                rvalid_reg <= 1'b1;
            end

            if (rvalid_reg && s_axi_rready)
                rvalid_reg <= 1'b0;
        end
    end

    // Read Data Mux
    reg [31:0] read_data_mux;

    always @(*) begin
        case (read_addr_reg)
            32'h00000000: read_data_mux = {31'b0, enable_reg};
            32'h00000004: read_data_mux = {31'b0, load_coeffs_reg};
            32'h00000008: read_data_mux = {
                28'b0,
                output_fifo_empty,
                output_fifo_full,
                input_fifo_empty,
                input_fifo_full
            };
            default: begin
                if (read_addr_reg >= 32'h00000010 &&
                    read_addr_reg < (32'h00000010 + NUM_TAPS*4)) begin
                    read_data_mux = {{(32-COEFF_WIDTH){1'b0}}, coeff_reg[(read_addr_reg - 32'h00000010) >> 2]};
                end else begin
                    read_data_mux = 0;
                end
            end
        endcase
    end

    assign s_axi_rdata = read_data_mux;

    // Pack Coefficients
    genvar g;
    generate
        for (g = 0; g < NUM_TAPS; g = g + 1) begin : PACK_COEFF
            assign coeff_packed[g*COEFF_WIDTH +: COEFF_WIDTH] = active_coeff_reg[g];
        end
    endgenerate

endmodule
