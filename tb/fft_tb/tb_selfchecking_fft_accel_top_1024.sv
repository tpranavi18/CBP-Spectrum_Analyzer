`timescale 1ns/1ps

module tb_selfchecking_fft_accel_top_1024;

    localparam integer N           = 1024;
    localparam integer AXI_ADDR_W  = 16;
    localparam integer AXI_DATA_W  = 32;
    localparam integer AXI_ID_W    = 4;
    localparam integer BYTES_PER_WORD = 4;

    // AXI-Lite register map from fft_ctrl_axil
    localparam logic [AXI_ADDR_W-1:0] CTRL_ADDR   = 16'h0000;
    localparam logic [AXI_ADDR_W-1:0] STATUS_ADDR = 16'h0004;
    localparam logic [AXI_ADDR_W-1:0] MEM_BASE = 16'h1000;
    logic                     clk;
    logic                     rst_n;
    logic                     irq;

    // ------------------------------------------------------------
    // AXI4-Lite control interface
    // ------------------------------------------------------------
    logic [AXI_ADDR_W-1:0]    S_AXIL_AWADDR;
    logic                     S_AXIL_AWVALID;
    logic                     S_AXIL_AWREADY;

    logic [AXI_DATA_W-1:0]    S_AXIL_WDATA;
    logic [AXI_DATA_W/8-1:0]  S_AXIL_WSTRB;
    logic                     S_AXIL_WVALID;
    logic                     S_AXIL_WREADY;

    logic [1:0]               S_AXIL_BRESP;
    logic                     S_AXIL_BVALID;
    logic                     S_AXIL_BREADY;

    logic [AXI_ADDR_W-1:0]    S_AXIL_ARADDR;
    logic                     S_AXIL_ARVALID;
    logic                     S_AXIL_ARREADY;

    logic [AXI_DATA_W-1:0]    S_AXIL_RDATA;
    logic [1:0]               S_AXIL_RRESP;
    logic                     S_AXIL_RVALID;
    logic                     S_AXIL_RREADY;

    // ------------------------------------------------------------
    // AXI4 memory-window interface
    // ------------------------------------------------------------
    logic [AXI_ID_W-1:0]      S_AXI_AWID;
    logic [AXI_ADDR_W-1:0]    S_AXI_AWADDR;
    logic [7:0]               S_AXI_AWLEN;
    logic [2:0]               S_AXI_AWSIZE;
    logic [1:0]               S_AXI_AWBURST;
    logic                     S_AXI_AWVALID;
    logic                     S_AXI_AWREADY;

    logic [AXI_DATA_W-1:0]    S_AXI_WDATA;
    logic [AXI_DATA_W/8-1:0]  S_AXI_WSTRB;
    logic                     S_AXI_WLAST;
    logic                     S_AXI_WVALID;
    logic                     S_AXI_WREADY;

    logic [AXI_ID_W-1:0]      S_AXI_BID;
    logic [1:0]               S_AXI_BRESP;
    logic                     S_AXI_BVALID;
    logic                     S_AXI_BREADY;

    logic [AXI_ID_W-1:0]      S_AXI_ARID;
    logic [AXI_ADDR_W-1:0]    S_AXI_ARADDR;
    logic [7:0]               S_AXI_ARLEN;
    logic [2:0]               S_AXI_ARSIZE;
    logic [1:0]               S_AXI_ARBURST;
    logic                     S_AXI_ARVALID;
    logic                     S_AXI_ARREADY;

    logic [AXI_ID_W-1:0]      S_AXI_RID;
    logic [AXI_DATA_W-1:0]    S_AXI_RDATA;
    logic [1:0]               S_AXI_RRESP;
    logic                     S_AXI_RLAST;
    logic                     S_AXI_RVALID;
    logic                     S_AXI_RREADY;

    // ------------------------------------------------------------
    // file vars / scoreboard
    // ------------------------------------------------------------
    integer i;
    integer mismatches;
    integer fd_cmp;
    integer exact_match;
    integer within_tol1;
    integer within_tol2;
    integer within_tol3;
    integer over_tol3;
    integer abs_re_err;
    integer abs_im_err;
    integer max_err;
    integer fd_report;

    integer fd;
    integer rc;
    int unsigned r, ii;
    logic signed [15:0] in_real [0:N-1];
    logic signed [15:0] in_imag [0:N-1];

    integer fd2;
    integer rc2;
    int index;
    int unsigned real_res, imag_res;
    logic signed [15:0] ref_real [0:N-1];
    logic signed [15:0] ref_imag [0:N-1];

    logic signed [15:0] dut_real [0:N-1];
    logic signed [15:0] dut_imag [0:N-1];

    logic signed [15:0] re, im;
    logic [31:0]        status_reg;
    logic [31:0]        rd_word;

    // ------------------------------------------------------------
    // DUT
    // ------------------------------------------------------------
    fft_accel_top #(
        .N          (N),
        .AXI_ADDR_W (AXI_ADDR_W),
        .AXI_DATA_W (AXI_DATA_W),
        .AXI_ID_W   (AXI_ID_W)
    ) dut (
        .clk            (clk),
        .rst_n          (rst_n),
        .irq            (irq),

        .S_AXIL_AWADDR  (S_AXIL_AWADDR),
        .S_AXIL_AWVALID (S_AXIL_AWVALID),
        .S_AXIL_AWREADY (S_AXIL_AWREADY),

        .S_AXIL_WDATA   (S_AXIL_WDATA),
        .S_AXIL_WSTRB   (S_AXIL_WSTRB),
        .S_AXIL_WVALID  (S_AXIL_WVALID),
        .S_AXIL_WREADY  (S_AXIL_WREADY),

        .S_AXIL_BRESP   (S_AXIL_BRESP),
        .S_AXIL_BVALID  (S_AXIL_BVALID),
        .S_AXIL_BREADY  (S_AXIL_BREADY),

        .S_AXIL_ARADDR  (S_AXIL_ARADDR),
        .S_AXIL_ARVALID (S_AXIL_ARVALID),
        .S_AXIL_ARREADY (S_AXIL_ARREADY),

        .S_AXIL_RDATA   (S_AXIL_RDATA),
        .S_AXIL_RRESP   (S_AXIL_RRESP),
        .S_AXIL_RVALID  (S_AXIL_RVALID),
        .S_AXIL_RREADY  (S_AXIL_RREADY),

        .S_AXI_AWID     (S_AXI_AWID),
        .S_AXI_AWADDR   (S_AXI_AWADDR),
        .S_AXI_AWLEN    (S_AXI_AWLEN),
        .S_AXI_AWSIZE   (S_AXI_AWSIZE),
        .S_AXI_AWBURST  (S_AXI_AWBURST),
        .S_AXI_AWVALID  (S_AXI_AWVALID),
        .S_AXI_AWREADY  (S_AXI_AWREADY),

        .S_AXI_WDATA    (S_AXI_WDATA),
        .S_AXI_WSTRB    (S_AXI_WSTRB),
        .S_AXI_WLAST    (S_AXI_WLAST),
        .S_AXI_WVALID   (S_AXI_WVALID),
        .S_AXI_WREADY   (S_AXI_WREADY),

        .S_AXI_BID      (S_AXI_BID),
        .S_AXI_BRESP    (S_AXI_BRESP),
        .S_AXI_BVALID   (S_AXI_BVALID),
        .S_AXI_BREADY   (S_AXI_BREADY),

        .S_AXI_ARID     (S_AXI_ARID),
        .S_AXI_ARADDR   (S_AXI_ARADDR),
        .S_AXI_ARLEN    (S_AXI_ARLEN),
        .S_AXI_ARSIZE   (S_AXI_ARSIZE),
        .S_AXI_ARBURST  (S_AXI_ARBURST),
        .S_AXI_ARVALID  (S_AXI_ARVALID),
        .S_AXI_ARREADY  (S_AXI_ARREADY),

        .S_AXI_RID      (S_AXI_RID),
        .S_AXI_RDATA    (S_AXI_RDATA),
        .S_AXI_RRESP    (S_AXI_RRESP),
        .S_AXI_RLAST    (S_AXI_RLAST),
        .S_AXI_RVALID   (S_AXI_RVALID),
        .S_AXI_RREADY   (S_AXI_RREADY)
    );

    // 100 MHz clock
    always #5 clk = ~clk;

    // ------------------------------------------------------------
    // AXI-Lite write
    // ------------------------------------------------------------
task automatic axil_write(
    input logic [AXI_ADDR_W-1:0] addr,
    input logic [AXI_DATA_W-1:0] data
);
    integer timeout;
begin
    @(negedge clk);
    S_AXIL_AWADDR  = addr;
    S_AXIL_AWVALID = 1'b1;
    S_AXIL_WDATA   = data;
    S_AXIL_WSTRB   = 4'hF;
    S_AXIL_WVALID  = 1'b1;
    S_AXIL_BREADY  = 1'b1;

    timeout = 0;
    while (!(S_AXIL_AWREADY && S_AXIL_WREADY)) begin
        @(posedge clk);
        timeout = timeout + 1;
        if (timeout > 1000) begin
            $display("ERROR: AXI-Lite write handshake timeout addr=0x%0h time=%0t", addr, $time);
            $finish;
        end
    end

    @(negedge clk);
    S_AXIL_AWVALID = 1'b0;
    S_AXIL_WVALID  = 1'b0;

    timeout = 0;
    while (!S_AXIL_BVALID) begin
        @(posedge clk);
        timeout = timeout + 1;
        if (timeout > 1000) begin
            $display("ERROR: AXI-Lite BVALID timeout addr=0x%0h time=%0t", addr, $time);
            $finish;
        end
    end

    @(negedge clk);
    S_AXIL_BREADY = 1'b0;
end
endtask

    // ------------------------------------------------------------
    // AXI-Lite read
    // ------------------------------------------------------------
task automatic axil_read(
    input  logic [AXI_ADDR_W-1:0] addr,
    output logic [AXI_DATA_W-1:0] data
);
    integer timeout;
begin
    @(negedge clk);
    S_AXIL_ARADDR  = addr;
    S_AXIL_ARVALID = 1'b1;
    S_AXIL_RREADY  = 1'b1;

    timeout = 0;
    while (!S_AXIL_ARREADY) begin
        @(posedge clk);
        timeout = timeout + 1;
        if (timeout > 1000) begin
            $display("ERROR: AXI-Lite read handshake timeout addr=0x%0h time=%0t", addr, $time);
            $finish;
        end
    end

    @(negedge clk);
    S_AXIL_ARVALID = 1'b0;

    timeout = 0;
    while (!S_AXIL_RVALID) begin
        @(posedge clk);
        timeout = timeout + 1;
        if (timeout > 1000) begin
            $display("ERROR: AXI-Lite RVALID timeout addr=0x%0h time=%0t", addr, $time);
            $finish;
        end
    end

    data = S_AXIL_RDATA;

    @(negedge clk);
    S_AXIL_RREADY = 1'b0;
end
endtask
    // ------------------------------------------------------------
    // AXI4 memory single-beat write
    // ------------------------------------------------------------
task automatic axi_mem_write_word(
    input int addr_word,
    input logic [31:0] data
);
    logic [AXI_ADDR_W-1:0] byte_addr;
    integer timeout;
begin
    byte_addr = MEM_BASE + addr_word*4;

    // drive request
    @(negedge clk);
    S_AXI_AWID    = '0;
    S_AXI_AWADDR  = byte_addr;
    S_AXI_AWLEN   = 8'd0;
    S_AXI_AWSIZE  = 3'd2;    // 4 bytes
    S_AXI_AWBURST = 2'b01;   // INCR
    S_AXI_AWVALID = 1'b1;

    S_AXI_WDATA   = data;
    S_AXI_WSTRB   = 4'hF;
    S_AXI_WLAST   = 1'b1;
    S_AXI_WVALID  = 1'b1;

    S_AXI_BREADY  = 1'b1;

    // wait for AW handshake
    timeout = 0;
    while (!(S_AXI_AWVALID && S_AXI_AWREADY)) begin
        @(posedge clk);
        timeout = timeout + 1;
        if (timeout > 1000) begin
            $display("ERROR: AXI write AW handshake timeout at addr_word=%0d addr=0x%0h time=%0t",
                     addr_word, byte_addr, $time);
            $finish;
        end
    end

    @(negedge clk);
    S_AXI_AWVALID = 1'b0;

    // wait for W handshake
    timeout = 0;
    while (!(S_AXI_WVALID && S_AXI_WREADY)) begin
        @(posedge clk);
        timeout = timeout + 1;
        if (timeout > 1000) begin
            $display("ERROR: AXI write W handshake timeout at addr_word=%0d addr=0x%0h time=%0t",
                     addr_word, byte_addr, $time);
            $finish;
        end
    end

    @(negedge clk);
    S_AXI_WVALID = 1'b0;
    S_AXI_WLAST  = 1'b0;

    // wait for B response
    timeout = 0;
    while (!S_AXI_BVALID) begin
        @(posedge clk);
        timeout = timeout + 1;
        if (timeout > 1000) begin
            $display("ERROR: AXI write BVALID timeout at addr_word=%0d addr=0x%0h time=%0t",
                     addr_word, byte_addr, $time);
            $finish;
        end
    end

    @(negedge clk);
    S_AXI_BREADY = 1'b0;
end
endtask

    // ------------------------------------------------------------
    // AXI4 memory single-beat read
    // ------------------------------------------------------------
task automatic axi_mem_read_word(
    input  int addr_word,
    output logic [31:0] data
);
    logic [AXI_ADDR_W-1:0] byte_addr;
    integer timeout;
begin
    byte_addr = MEM_BASE + addr_word*4;

    @(negedge clk);
    S_AXI_ARID    = '0;
    S_AXI_ARADDR  = byte_addr;
    S_AXI_ARLEN   = 8'd0;
    S_AXI_ARSIZE  = 3'd2;    // 4 bytes
    S_AXI_ARBURST = 2'b01;   // INCR
    S_AXI_ARVALID = 1'b1;
    S_AXI_RREADY  = 1'b1;

    // wait for AR handshake
    timeout = 0;
    while (!(S_AXI_ARVALID && S_AXI_ARREADY)) begin
        @(posedge clk);
        timeout = timeout + 1;
        if (timeout > 1000) begin
            $display("ERROR: AXI read AR handshake timeout at addr_word=%0d addr=0x%0h time=%0t",
                     addr_word, byte_addr, $time);
            $finish;
        end
    end

    @(negedge clk);
    S_AXI_ARVALID = 1'b0;

    // wait for RVALID
    timeout = 0;
    while (!S_AXI_RVALID) begin
        @(posedge clk);
        timeout = timeout + 1;
        if (timeout > 1000) begin
            $display("ERROR: AXI read RVALID timeout at addr_word=%0d addr=0x%0h time=%0t",
                     addr_word, byte_addr, $time);
            $finish;
        end
    end

    data = S_AXI_RDATA;

    @(negedge clk);
    S_AXI_RREADY = 1'b0;
end
endtask

    initial begin
        clk = 0;
        rst_n = 0;

        S_AXIL_AWADDR  = '0;
        S_AXIL_AWVALID = 0;
        S_AXIL_WDATA   = '0;
        S_AXIL_WSTRB   = '0;
        S_AXIL_WVALID  = 0;
        S_AXIL_BREADY  = 0;
        S_AXIL_ARADDR  = '0;
        S_AXIL_ARVALID = 0;
        S_AXIL_RREADY  = 0;

        S_AXI_AWID     = '0;
        S_AXI_AWADDR   = '0;
        S_AXI_AWLEN    = '0;
        S_AXI_AWSIZE   = '0;
        S_AXI_AWBURST  = '0;
        S_AXI_AWVALID  = 0;
        S_AXI_WDATA    = '0;
        S_AXI_WSTRB    = '0;
        S_AXI_WLAST    = 0;
        S_AXI_WVALID   = 0;
        S_AXI_BREADY   = 0;
        S_AXI_ARID     = '0;
        S_AXI_ARADDR   = '0;
        S_AXI_ARLEN    = '0;
        S_AXI_ARSIZE   = '0;
        S_AXI_ARBURST  = '0;
        S_AXI_ARVALID  = 0;
        S_AXI_RREADY   = 0;

        mismatches  = 0;
        exact_match = 0;
        within_tol1 = 0;
        within_tol2 = 0;
        within_tol3 = 0;
        over_tol3   = 0;
        max_err     = 0;

        // reset
        #20;
        rst_n = 1;
        #20;
        $display("After reset: AWREADY=%0b WREADY=%0b ARREADY=%0b irq=%0b time=%0t",
         S_AXI_AWREADY, S_AXI_WREADY, S_AXI_ARREADY, irq, $time);

        // --------------------------------------------------------
        // Read input file
        // format: <real_hex> <imag_hex>
        // --------------------------------------------------------
        fd = $fopen("mixed_1024_input.txt", "r");
        if (fd == 0) begin
            $display("ERROR: cannot open input file");
            $finish;
        end

        for (i = 0; i < N; i = i + 1) begin
            rc = $fscanf(fd, "%h %h\n", r, ii);
            if (rc != 2) begin
                $display("ERROR: parse error in input file at line %0d", i);
                $finish;
            end
            in_real[i] = r[15:0];
            in_imag[i] = ii[15:0];
        end
        $fclose(fd);

        // --------------------------------------------------------
        // Read reference file
        // format: <index_dec> <real_hex> <imag_hex>
        // --------------------------------------------------------
        fd2 = $fopen("cmodel_fft_out_mixed_1024.txt", "r");
        if (fd2 == 0) begin
            $display("ERROR: cannot open reference file");
            $finish;
        end

        for (i = 0; i < N; i = i + 1) begin
            rc2 = $fscanf(fd2, "%d %h %h\n", index, real_res, imag_res);
            if (rc2 != 3) begin
                $display("ERROR: parse error in reference file at line %0d", i);
                $finish;
            end

            if (index != i) begin
                $display("ERROR: reference index mismatch at line %0d: got %0d", i, index);
                $finish;
            end

            ref_real[i] = real_res[15:0];
            ref_imag[i] = imag_res[15:0];
        end
        $fclose(fd2);

        // --------------------------------------------------------
        // AXI memory write input samples
        // --------------------------------------------------------
        $display("AXI MEMORY IMAGE BEFORE FFT:");
        for (i = 0; i < N; i = i + 1) begin
            axi_mem_write_word(i, {in_real[i], in_imag[i]});
            $display("MEM[%0d] = %0d + j%0d", i, in_real[i], in_imag[i]);
        end

        // --------------------------------------------------------
        // Start FFT
        // CTRL[0] = 1
        // --------------------------------------------------------
        $display("[%0t] ctrl start write", $time);
        axil_write(CTRL_ADDR, 32'h0000_0001);
        $display("[%0t] ctrl start write done", $time);

        // --------------------------------------------------------
        // Poll STATUS until done_sticky = 1
        // STATUS[0] = done_sticky
        // STATUS[1] = fft_busy
        // --------------------------------------------------------
        $display("[%0t] polling status", $time);
        do begin
            #20;
            axil_read(STATUS_ADDR, status_reg);
            $display("[%0t] status = 0x%08h", $time, status_reg);
        end while (status_reg[0] == 1'b0);

        #20;

        // --------------------------------------------------------
        // Read FFT output back
        // --------------------------------------------------------
        $display("[%0t] burst read start", $time);
        for (i = 0; i < N; i = i + 1) begin
            axi_mem_read_word(i, rd_word);
            dut_real[i] = rd_word[31:16];
            dut_imag[i] = rd_word[15:0];
        end
        $display("[%0t] burst read done", $time);

        // --------------------------------------------------------
        // Comparison report generation
        // --------------------------------------------------------
        fd_cmp = $fopen("fft_comparison.txt","w");
        if (fd_cmp == 0) begin
            $display("ERROR: cannot open comparison output file");
            $finish;
        end

        $display("");
        $display("AXI SYSTEM FFT OUTPUTS:");
        for (i = 0; i < N; i = i + 1) begin
            re = dut_real[i];
            im = dut_imag[i];

            $display("MEM[%0d] = %0d + j%0d", i, re, im);

            abs_re_err = re - ref_real[i];
            if (abs_re_err < 0) abs_re_err = -abs_re_err;

            abs_im_err = im - ref_imag[i];
            if (abs_im_err < 0) abs_im_err = -abs_im_err;

            if (abs_re_err > max_err) max_err = abs_re_err;
            if (abs_im_err > max_err) max_err = abs_im_err;

            if ((abs_re_err == 0) && (abs_im_err == 0))
                exact_match = exact_match + 1;

            if ((abs_re_err <= 1) && (abs_im_err <= 1))
                within_tol1 = within_tol1 + 1;

            if ((abs_re_err <= 2) && (abs_im_err <= 2))
                within_tol2 = within_tol2 + 1;

            if ((abs_re_err <= 3) && (abs_im_err <= 3))
                within_tol3 = within_tol3 + 1;
            else
                over_tol3 = over_tol3 + 1;

            if ((abs_re_err > 3) || (abs_im_err > 3)) begin
                mismatches = mismatches + 1;
                $display("MISMATCH at %0d: got 0x%04h%04h expected 0x%04h%04h",
                         i, re[15:0], im[15:0], ref_real[i][15:0], ref_imag[i][15:0]);
                $fdisplay(fd_cmp, "MISMATCH [%0d] DUT=(%0d,%0d) REF=(%0d,%0d)",
                          i, re, im, ref_real[i], ref_imag[i]);
            end
            else begin
                $fdisplay(fd_cmp, "MATCH [%0d] DUT=(%0d,%0d) REF=(%0d,%0d)",
                          i, re, im, ref_real[i], ref_imag[i]);
            end
        end

        $fclose(fd_cmp);

        if (mismatches == 0)
            $display("PASS: DUT matches reference for all %0d bins", N);
        else
            $display("FAIL: %0d mismatches found", mismatches);

        fd_report = $fopen("fft_summary_report.txt", "w");
        if (fd_report == 0) begin
            $display("ERROR: cannot open report file");
            $finish;
        end

        $fdisplay(fd_report, "==========================================");
        $fdisplay(fd_report, "FFT 1024 Simulation Summary Report");
        $fdisplay(fd_report, "==========================================");
        $fdisplay(fd_report, "Total bins                : %0d", N);
        $fdisplay(fd_report, "Exact matches             : %0d", exact_match);
        $fdisplay(fd_report, "Within +/-1 tolerance     : %0d", within_tol1);
        $fdisplay(fd_report, "Within +/-2 tolerance     : %0d", within_tol2);
        $fdisplay(fd_report, "Within +/-3 tolerance     : %0d", within_tol3);
        $fdisplay(fd_report, "Outside +/-3 tolerance    : %0d", over_tol3);
        $fdisplay(fd_report, "Reported mismatches       : %0d", mismatches);
        $fdisplay(fd_report, "Maximum absolute error    : %0d", max_err);
        $fdisplay(fd_report, "");

        if (mismatches == 0)
            $fdisplay(fd_report, "Overall Result            : PASS");
        else
            $fdisplay(fd_report, "Overall Result            : FAIL");

        $fdisplay(fd_report, "==========================================");
        $fclose(fd_report);

        $display("Done.");
        $finish;
    end

endmodule