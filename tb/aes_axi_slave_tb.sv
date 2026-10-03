`timescale 1ns/1ps

module aes_axi_slave_tb;

    //========================================================
    // PARAMETERS
    //========================================================

    parameter DATA_WIDTH = 32;
    parameter ADDR_WIDTH = 32;

    parameter CIPHER_BASE_ADDR     = 32'h0000_0000;
    parameter INV_CIPHER_BASE_ADDR = 32'h0000_0100;


    //========================================================
    // CLOCK AND RESET
    //========================================================

    reg S_AXI_ACLK;
    reg S_AXI_ARESETN;


    //========================================================
    // AXI WRITE ADDRESS CHANNEL
    //========================================================

    reg  [ADDR_WIDTH-1:0] S_AXI_AWADDR;
    reg                   S_AXI_AWVALID;
    wire                  S_AXI_AWREADY;


    //========================================================
    // AXI WRITE DATA CHANNEL
    //========================================================

    reg  [DATA_WIDTH-1:0] S_AXI_WDATA;
    reg  [(DATA_WIDTH/8)-1:0] S_AXI_WSTRB;
    reg                   S_AXI_WVALID;
    wire                  S_AXI_WREADY;


    //========================================================
    // AXI WRITE RESPONSE CHANNEL
    //========================================================

    wire [1:0] S_AXI_BRESP;
    wire       S_AXI_BVALID;
    reg        S_AXI_BREADY;


    //========================================================
    // AXI READ ADDRESS CHANNEL
    //========================================================

    reg  [ADDR_WIDTH-1:0] S_AXI_ARADDR;
    reg                   S_AXI_ARVALID;
    wire                  S_AXI_ARREADY;


    //========================================================
    // AXI READ DATA CHANNEL
    //========================================================

    wire [DATA_WIDTH-1:0] S_AXI_RDATA;
    wire [1:0]            S_AXI_RRESP;
    wire                  S_AXI_RVALID;
    reg                   S_AXI_RREADY;


    //========================================================
    // DUT
    //========================================================

    aes_axi_slave #(
        .C_S_AXI_DATA_WIDTH   (DATA_WIDTH),
        .C_S_AXI_ADDR_WIDTH   (ADDR_WIDTH),
        .CIPHER_BASE_ADDR     (CIPHER_BASE_ADDR),
        .INV_CIPHER_BASE_ADDR (INV_CIPHER_BASE_ADDR)
    )
    dut (
        .S_AXI_ACLK     (S_AXI_ACLK),
        .S_AXI_ARESETN  (S_AXI_ARESETN),

        .S_AXI_AWADDR   (S_AXI_AWADDR),
        .S_AXI_AWVALID  (S_AXI_AWVALID),
        .S_AXI_AWREADY  (S_AXI_AWREADY),

        .S_AXI_WDATA    (S_AXI_WDATA),
        .S_AXI_WSTRB    (S_AXI_WSTRB),
        .S_AXI_WVALID   (S_AXI_WVALID),
        .S_AXI_WREADY   (S_AXI_WREADY),

        .S_AXI_BRESP    (S_AXI_BRESP),
        .S_AXI_BVALID   (S_AXI_BVALID),
        .S_AXI_BREADY   (S_AXI_BREADY),

        .S_AXI_ARADDR   (S_AXI_ARADDR),
        .S_AXI_ARVALID  (S_AXI_ARVALID),
        .S_AXI_ARREADY  (S_AXI_ARREADY),

        .S_AXI_RDATA    (S_AXI_RDATA),
        .S_AXI_RRESP    (S_AXI_RRESP),
        .S_AXI_RVALID   (S_AXI_RVALID),
        .S_AXI_RREADY   (S_AXI_RREADY)
    );


    //========================================================
    // CLOCK
    // 10 ns period = 100 MHz
    //========================================================

    initial begin

        S_AXI_ACLK = 1'b0;

        forever #5 S_AXI_ACLK = ~S_AXI_ACLK;

    end


    //========================================================
    // AXI WRITE TASK
    //
    // Holds AWVALID and WVALID until their respective
    // handshakes occur.
    //========================================================

    task axi_write;

        input [31:0] address;
        input [31:0] data;

        reg aw_done;
        reg w_done;

        begin

            $display("");
            $display("[AXI WRITE] Address = 0x%08h  Data = 0x%08h",
                     address, data);


            aw_done = 1'b0;
            w_done  = 1'b0;


            //================================================
            // DRIVE WRITE TRANSACTION
            //================================================

            @(posedge S_AXI_ACLK);

            S_AXI_AWADDR  <= address;
            S_AXI_AWVALID <= 1'b1;

            S_AXI_WDATA   <= data;
            S_AXI_WSTRB   <= 4'b1111;
            S_AXI_WVALID  <= 1'b1;

            S_AXI_BREADY  <= 1'b1;


            //================================================
            // WAIT FOR BOTH AW AND W HANDSHAKES
            //================================================

            while (!aw_done || !w_done) begin

                @(posedge S_AXI_ACLK);

                if (S_AXI_AWVALID && S_AXI_AWREADY) begin

                    S_AXI_AWVALID <= 1'b0;
                    aw_done       = 1'b1;

                end

                if (S_AXI_WVALID && S_AXI_WREADY) begin

                    S_AXI_WVALID <= 1'b0;
                    w_done       = 1'b1;

                end

            end


            //================================================
            // WAIT FOR WRITE RESPONSE
            //================================================

            wait (S_AXI_BVALID);

            if (S_AXI_BRESP !== 2'b00) begin

                $display("[ERROR] AXI WRITE RESPONSE = %b",
                         S_AXI_BRESP);

                $finish;

            end

            else begin

                $display("[AXI WRITE] Response = OKAY");

            end


            //================================================
            // COMPLETE RESPONSE HANDSHAKE
            //================================================

            @(posedge S_AXI_ACLK);

            S_AXI_BREADY <= 1'b0;

        end

    endtask


    //========================================================
    // AXI READ TASK
    //========================================================

    task axi_read;

        input  [31:0] address;
        output [31:0] data;

        begin

            $display("");
            $display("[AXI READ ] Address = 0x%08h", address);


            //================================================
            // DRIVE READ ADDRESS
            //================================================

            @(posedge S_AXI_ACLK);

            S_AXI_ARADDR  <= address;
            S_AXI_ARVALID <= 1'b1;

            S_AXI_RREADY  <= 1'b1;


            //================================================
            // WAIT FOR READ ADDRESS HANDSHAKE
            //================================================

            while (S_AXI_ARVALID) begin

                @(posedge S_AXI_ACLK);

                if (S_AXI_ARVALID && S_AXI_ARREADY) begin

                    S_AXI_ARVALID <= 1'b0;

                end

            end


            //================================================
            // WAIT FOR READ DATA
            //================================================

            wait (S_AXI_RVALID);

            if (S_AXI_RRESP !== 2'b00) begin

                $display("[ERROR] AXI READ RESPONSE = %b",
                         S_AXI_RRESP);

                $finish;

            end


            data = S_AXI_RDATA;

            $display("[AXI READ ] Data     = 0x%08h", data);
            $display("[AXI READ ] Response = OKAY");


            //================================================
            // COMPLETE READ HANDSHAKE
            //================================================

            @(posedge S_AXI_ACLK);

            S_AXI_RREADY <= 1'b0;

        end

    endtask


    //========================================================
    // TEST VARIABLES
    //========================================================

    reg [31:0] read_data;

    reg [127:0] expected_ciphertext;
    reg [127:0] actual_ciphertext;

    reg [127:0] expected_plaintext;
    reg [127:0] actual_plaintext;

    integer poll_count;


    //========================================================
    // MAIN TEST
    //========================================================

    initial begin

        //====================================================
        // INITIAL VALUES
        //====================================================

        S_AXI_ARESETN = 1'b0;

        S_AXI_AWADDR  = 32'h0000_0000;
        S_AXI_AWVALID = 1'b0;

        S_AXI_WDATA   = 32'h0000_0000;
        S_AXI_WSTRB   = 4'b0000;
        S_AXI_WVALID  = 1'b0;

        S_AXI_BREADY  = 1'b0;

        S_AXI_ARADDR  = 32'h0000_0000;
        S_AXI_ARVALID = 1'b0;

        S_AXI_RREADY  = 1'b0;


        //====================================================
        // TEST HEADER
        //====================================================

        $display("");
        $display("============================================================");
        $display("              AES AXI SLAVE TESTBENCH");
        $display("============================================================");
        $display(" AXI Data Width : %0d bits", DATA_WIDTH);
        $display(" AXI Addr Width : %0d bits", ADDR_WIDTH);
        $display(" Cipher Base    : 0x%08h", CIPHER_BASE_ADDR);
        $display(" Inverse Base   : 0x%08h", INV_CIPHER_BASE_ADDR);
        $display("============================================================");
        $display("");


        //====================================================
        // RESET
        //====================================================

        $display("[%0t] Applying reset...", $time);

        repeat (5) @(posedge S_AXI_ACLK);

        S_AXI_ARESETN = 1'b1;

        repeat (2) @(posedge S_AXI_ACLK);

        $display("[%0t] Reset released.", $time);
        $display("");


        //====================================================
        // TEST 1 : NORMAL AES ENCRYPTION
        //====================================================

        $display("");
        $display("============================================================");
        $display("             TEST 1 : NORMAL AES ENCRYPTION");
        $display("============================================================");


        //====================================================
        // TEST VECTOR
        //
        // KEY:
        // 123456789abcdef123456789abcdef12
        //
        // PLAINTEXT:
        // f34481ec3cc627bacd5dc3fb08f273e6
        //
        // EXPECTED:
        // 12d02f12826a0eb5b860d33dea61428c
        //====================================================

        expected_ciphertext =
            128'h12d02f12826a0eb5b860d33dea61428c;


        $display("");
        $display("NORMAL AES TEST VECTOR");
        $display("----------------------");
        $display("Key       = 123456789abcdef123456789abcdef12");
        $display("Plaintext = f34481ec3cc627bacd5dc3fb08f273e6");
        $display("Expected  = 12d02f12826a0eb5b860d33dea61428c");
        $display("");


        //====================================================
        // WRITE KEY
        //
        // KEY[127:0] = {KEY3,KEY2,KEY1,KEY0}
        //====================================================

        $display("Writing Normal AES Key...");

        axi_write(
            CIPHER_BASE_ADDR + 32'h04,
            32'habcdef12
        );

        axi_write(
            CIPHER_BASE_ADDR + 32'h08,
            32'h23456789
        );

        axi_write(
            CIPHER_BASE_ADDR + 32'h0C,
            32'h9abcdef1
        );

        axi_write(
            CIPHER_BASE_ADDR + 32'h10,
            32'h12345678
        );


        //====================================================
        // WRITE PLAINTEXT
        //====================================================

        $display("");
        $display("Writing Normal AES Plaintext...");

        axi_write(
            CIPHER_BASE_ADDR + 32'h14,
            32'h08f273e6
        );

        axi_write(
            CIPHER_BASE_ADDR + 32'h18,
            32'hcd5dc3fb
        );

        axi_write(
            CIPHER_BASE_ADDR + 32'h1C,
            32'h3cc627ba
        );

        axi_write(
            CIPHER_BASE_ADDR + 32'h20,
            32'hf34481ec
        );


        //====================================================
        // VERIFY REGISTER VALUES BEFORE START
        //====================================================

        $display("");
        $display("============================================================");
        $display("       VERIFYING NORMAL AES REGISTERS");
        $display("============================================================");

        axi_read(
            CIPHER_BASE_ADDR + 32'h04,
            read_data
        );
        $display("KEY0 READBACK = 0x%08h", read_data);

        if (read_data !== 32'habcdef12) begin
            $display("[ERROR] KEY0 mismatch!");
            $finish;
        end


        axi_read(
            CIPHER_BASE_ADDR + 32'h08,
            read_data
        );
        $display("KEY1 READBACK = 0x%08h", read_data);

        if (read_data !== 32'h23456789) begin
            $display("[ERROR] KEY1 mismatch!");
            $finish;
        end


        axi_read(
            CIPHER_BASE_ADDR + 32'h0C,
            read_data
        );
        $display("KEY2 READBACK = 0x%08h", read_data);

        if (read_data !== 32'h9abcdef1) begin
            $display("[ERROR] KEY2 mismatch!");
            $finish;
        end


        axi_read(
            CIPHER_BASE_ADDR + 32'h10,
            read_data
        );
        $display("KEY3 READBACK = 0x%08h", read_data);

        if (read_data !== 32'h12345678) begin
            $display("[ERROR] KEY3 mismatch!");
            $finish;
        end


        axi_read(
            CIPHER_BASE_ADDR + 32'h14,
            read_data
        );
        $display("TIN0 READBACK = 0x%08h", read_data);

        if (read_data !== 32'h08f273e6) begin
            $display("[ERROR] TIN0 mismatch!");
            $finish;
        end


        axi_read(
            CIPHER_BASE_ADDR + 32'h18,
            read_data
        );
        $display("TIN1 READBACK = 0x%08h", read_data);

        if (read_data !== 32'hcd5dc3fb) begin
            $display("[ERROR] TIN1 mismatch!");
            $finish;
        end


        axi_read(
            CIPHER_BASE_ADDR + 32'h1C,
            read_data
        );
        $display("TIN2 READBACK = 0x%08h", read_data);

        if (read_data !== 32'h3cc627ba) begin
            $display("[ERROR] TIN2 mismatch!");
            $finish;
        end


        axi_read(
            CIPHER_BASE_ADDR + 32'h20,
            read_data
        );
        $display("TIN3 READBACK = 0x%08h", read_data);

        if (read_data !== 32'hf34481ec) begin
            $display("[ERROR] TIN3 mismatch!");
            $finish;
        end


        $display("");
        $display("NORMAL AES REGISTER READBACK : PASS");
        $display("============================================================");
        $display("");


        //====================================================
        // START NORMAL AES
        //====================================================

        $display("Starting Normal AES Encryption...");
        $display("Writing CIPHER_CSR = 0x00000001");
        $display("CSR[0] = LD");


        axi_write(
            CIPHER_BASE_ADDR + 32'h00,
            32'h0000_0001
        );


        //====================================================
        // POLL DONE
        //
        // CSR[31] = DONE
        //====================================================

        $display("");
        $display("Polling CIPHER_CSR[31] = DONE...");

        poll_count = 0;

        do begin

            axi_read(
                CIPHER_BASE_ADDR + 32'h00,
                read_data
            );

            poll_count = poll_count + 1;

            $display("[NORMAL] Poll %0d : CSR = 0x%08h  DONE = %b",
                     poll_count,
                     read_data,
                     read_data[31]);

            if (poll_count > 100) begin

                $display("");
                $display("[ERROR] NORMAL AES DONE TIMEOUT");
                $display("CSR = 0x%08h", read_data);
                $finish;

            end

        end while (read_data[31] !== 1'b1);


        $display("");
        $display("[NORMAL] DONE detected!");
        $display("[NORMAL] Total status polls = %0d", poll_count);


        //====================================================
        // READ CIPHERTEXT
        //====================================================

        $display("");
        $display("Reading Normal AES Output Registers...");


        axi_read(
            CIPHER_BASE_ADDR + 32'h24,
            read_data
        );
        actual_ciphertext[31:0] = read_data;


        axi_read(
            CIPHER_BASE_ADDR + 32'h28,
            read_data
        );
        actual_ciphertext[63:32] = read_data;


        axi_read(
            CIPHER_BASE_ADDR + 32'h2C,
            read_data
        );
        actual_ciphertext[95:64] = read_data;


        axi_read(
            CIPHER_BASE_ADDR + 32'h30,
            read_data
        );
        actual_ciphertext[127:96] = read_data;


        //====================================================
        // DISPLAY NORMAL RESULT
        //====================================================

        $display("");
        $display("------------------------------------------------------------");
        $display("NORMAL AES RESULT");
        $display("------------------------------------------------------------");

        $display("Expected Ciphertext : %032h",
                 expected_ciphertext);

        $display("Actual Ciphertext   : %032h",
                 actual_ciphertext);

        $display("------------------------------------------------------------");


        //====================================================
        // CHECK NORMAL RESULT
        //====================================================

        if (actual_ciphertext === expected_ciphertext) begin

            $display("PASS : NORMAL AES ENCRYPTION");

        end

        else begin

            $display("FAIL : NORMAL AES ENCRYPTION");
            $display("Expected = %032h", expected_ciphertext);
            $display("Got      = %032h", actual_ciphertext);

            $finish;

        end


        //====================================================
        // TEST 2 : INVERSE AES DECRYPTION
        //====================================================

        $display("");
        $display("");
        $display("============================================================");
        $display("             TEST 2 : INVERSE AES DECRYPTION");
        $display("============================================================");


        expected_plaintext =
            128'hf34481ec3cc627bacd5dc3fb08f273e6;


        $display("");
        $display("INVERSE AES TEST VECTOR");
        $display("-----------------------");
        $display("Key        = 123456789abcdef123456789abcdef12");
        $display("Ciphertext = 12d02f12826a0eb5b860d33dea61428c");
        $display("Expected   = f34481ec3cc627bacd5dc3fb08f273e6");
        $display("");


        //====================================================
        // WRITE INVERSE KEY
        //====================================================

        $display("Writing Inverse AES Key...");

        axi_write(
            INV_CIPHER_BASE_ADDR + 32'h04,
            32'habcdef12
        );

        axi_write(
            INV_CIPHER_BASE_ADDR + 32'h08,
            32'h23456789
        );

        axi_write(
            INV_CIPHER_BASE_ADDR + 32'h0C,
            32'h9abcdef1
        );

        axi_write(
            INV_CIPHER_BASE_ADDR + 32'h10,
            32'h12345678
        );


        //====================================================
        // WRITE CIPHERTEXT
        //
        // {INV_TIN3,INV_TIN2,INV_TIN1,INV_TIN0}
        // =
        // 12d02f12826a0eb5b860d33dea61428c
        //====================================================

        $display("");
        $display("Writing Inverse AES Ciphertext...");

        axi_write(
            INV_CIPHER_BASE_ADDR + 32'h14,
            32'hea61_428c
        );

        axi_write(
            INV_CIPHER_BASE_ADDR + 32'h18,
            32'hb860_d33d
        );

        axi_write(
            INV_CIPHER_BASE_ADDR + 32'h1C,
            32'h826a_0eb5
        );

        axi_write(
            INV_CIPHER_BASE_ADDR + 32'h20,
            32'h12d0_2f12
        );


        //====================================================
        // VERIFY INVERSE REGISTERS
        //====================================================

        $display("");
        $display("============================================================");
        $display("       VERIFYING INVERSE AES REGISTERS");
        $display("============================================================");

        axi_read(
            INV_CIPHER_BASE_ADDR + 32'h04,
            read_data
        );
        $display("INV KEY0 READBACK = 0x%08h", read_data);


        axi_read(
            INV_CIPHER_BASE_ADDR + 32'h08,
            read_data
        );
        $display("INV KEY1 READBACK = 0x%08h", read_data);


        axi_read(
            INV_CIPHER_BASE_ADDR + 32'h0C,
            read_data
        );
        $display("INV KEY2 READBACK = 0x%08h", read_data);


        axi_read(
            INV_CIPHER_BASE_ADDR + 32'h10,
            read_data
        );
        $display("INV KEY3 READBACK = 0x%08h", read_data);


        axi_read(
            INV_CIPHER_BASE_ADDR + 32'h14,
            read_data
        );
        $display("INV TIN0 READBACK = 0x%08h", read_data);


        axi_read(
            INV_CIPHER_BASE_ADDR + 32'h18,
            read_data
        );
        $display("INV TIN1 READBACK = 0x%08h", read_data);


        axi_read(
            INV_CIPHER_BASE_ADDR + 32'h1C,
            read_data
        );
        $display("INV TIN2 READBACK = 0x%08h", read_data);


        axi_read(
            INV_CIPHER_BASE_ADDR + 32'h20,
            read_data
        );
        $display("INV TIN3 READBACK = 0x%08h", read_data);


        $display("============================================================");
        $display("");


        //====================================================
        // START INVERSE KEY LOAD
        //
        // CSR[1] = KLD
        //====================================================

        $display("");
        $display("Starting Inverse AES Key Loading...");
        $display("Writing INV_CIPHER_CSR = 0x00000002");
        $display("CSR[1] = KLD");


        axi_write(
            INV_CIPHER_BASE_ADDR + 32'h00,
            32'h0000_0002
        );


        //====================================================
        // POLL KDONE
        //
        // CSR[30] = KDONE
        //====================================================

        $display("");
        $display("Polling INV_CIPHER_CSR[30] = KDONE...");

        poll_count = 0;

        do begin

            axi_read(
                INV_CIPHER_BASE_ADDR + 32'h00,
                read_data
            );

            poll_count = poll_count + 1;

            $display("[INVERSE KEY] Poll %0d : CSR = 0x%08h  KDONE = %b",
                     poll_count,
                     read_data,
                     read_data[30]);

            if (poll_count > 100) begin

                $display("");
                $display("[ERROR] INVERSE AES KDONE TIMEOUT");
                $display("CSR = 0x%08h", read_data);
                $finish;

            end

        end while (read_data[30] !== 1'b1);


        $display("");
        $display("[INVERSE KEY] KDONE detected!");
        $display("[INVERSE KEY] Total status polls = %0d", poll_count);


        //====================================================
        // START INVERSE DECRYPTION
        //
        // CSR[0] = LD
        //====================================================

        $display("");
        $display("Starting Inverse AES Decryption...");
        $display("Writing INV_CIPHER_CSR = 0x00000001");
        $display("CSR[0] = LD");


        axi_write(
            INV_CIPHER_BASE_ADDR + 32'h00,
            32'h0000_0001
        );


        //====================================================
        // POLL DONE
        //
        // CSR[31] = DONE
        //====================================================

        $display("");
        $display("Polling INV_CIPHER_CSR[31] = DONE...");

        poll_count = 0;

        do begin

            axi_read(
                INV_CIPHER_BASE_ADDR + 32'h00,
                read_data
            );

            poll_count = poll_count + 1;

            $display("[INVERSE] Poll %0d : CSR = 0x%08h  DONE = %b  KDONE = %b",
                     poll_count,
                     read_data,
                     read_data[31],
                     read_data[30]);

            if (poll_count > 100) begin

                $display("");
                $display("[ERROR] INVERSE AES DONE TIMEOUT");
                $display("CSR = 0x%08h", read_data);
                $finish;

            end

        end while (read_data[31] !== 1'b1);


        $display("");
        $display("[INVERSE] DONE detected!");
        $display("[INVERSE] Total status polls = %0d", poll_count);


        //====================================================
        // READ PLAINTEXT
        //====================================================

        $display("");
        $display("Reading Inverse AES Output Registers...");


        axi_read(
            INV_CIPHER_BASE_ADDR + 32'h24,
            read_data
        );
        actual_plaintext[31:0] = read_data;


        axi_read(
            INV_CIPHER_BASE_ADDR + 32'h28,
            read_data
        );
        actual_plaintext[63:32] = read_data;


        axi_read(
            INV_CIPHER_BASE_ADDR + 32'h2C,
            read_data
        );
        actual_plaintext[95:64] = read_data;


        axi_read(
            INV_CIPHER_BASE_ADDR + 32'h30,
            read_data
        );
        actual_plaintext[127:96] = read_data;


        //====================================================
        // DISPLAY INVERSE RESULT
        //====================================================

        $display("");
        $display("------------------------------------------------------------");
        $display("INVERSE AES RESULT");
        $display("------------------------------------------------------------");

        $display("Expected Plaintext : %032h",
                 expected_plaintext);

        $display("Actual Plaintext   : %032h",
                 actual_plaintext);

        $display("------------------------------------------------------------");


        //====================================================
        // CHECK INVERSE RESULT
        //====================================================

        if (actual_plaintext === expected_plaintext) begin

            $display("PASS : INVERSE AES DECRYPTION");

        end

        else begin

            $display("FAIL : INVERSE AES DECRYPTION");
            $display("Expected = %032h", expected_plaintext);
            $display("Got      = %032h", actual_plaintext);

            $finish;

        end


        //====================================================
        // FINAL RESULT
        //====================================================

        $display("");
        $display("");
        $display("============================================================");
        $display("                  ALL TESTS PASSED");
        $display("============================================================");
        $display(" Normal AES Encryption : PASS");
        $display(" Inverse AES Decryption: PASS");
        $display(" AXI Register Access   : PASS");
        $display(" AXI Read/Write        : PASS");
        $display("============================================================");
        $display("              AES AXI IP VERIFICATION PASSED");
        $display("============================================================");
        $display("");


        #100;

        $finish;

    end


    //========================================================
    // INTERNAL AES DEBUG MONITOR
    //========================================================

    always @(posedge S_AXI_ACLK) begin

        if (S_AXI_ARESETN) begin

            if (dut.cipher_ld) begin

                $display("");
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display("[%0t] DEBUG: cipher_ld ASSERTED", $time);
                $display("       cipher_key     = %032h", dut.cipher_key);
                $display("       cipher_text_in = %032h", dut.cipher_text_in);
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display("");

            end


            if (dut.cipher_done) begin

                $display("");
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display("[%0t] DEBUG: cipher_done ASSERTED", $time);
                $display("       cipher_text_out = %032h", dut.cipher_text_out);
                $display("       status          = %b", dut.cipher_done_status);
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display("");

            end


            if (dut.inv_kld) begin

                $display("");
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display("[%0t] DEBUG: inv_kld ASSERTED", $time);
                $display("       inv_key = %032h", dut.inv_key);
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display("");

            end


            if (dut.inv_ld) begin

                $display("");
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display("[%0t] DEBUG: inv_ld ASSERTED", $time);
                $display("       inv_key     = %032h", dut.inv_key);
                $display("       inv_text_in = %032h", dut.inv_text_in);
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display("");

            end


            if (dut.inv_done) begin

                $display("");
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display("[%0t] DEBUG: inv_done ASSERTED", $time);
                $display("       inv_text_out = %032h", dut.inv_text_out);
                $display("!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!");
                $display("");

            end

        end

    end


    //========================================================
    // TIMEOUT WATCHDOG
    //========================================================

    initial begin

        #100000;

        $display("");
        $display("============================================================");
        $display("                    TESTBENCH TIMEOUT");
        $display("============================================================");
        $display("");

        $finish;

    end


    //========================================================
    // WAVEFORM DUMP
    //========================================================

    initial begin

        $dumpfile("aes_axi_slave.vcd");
        $dumpvars(0, aes_axi_slave_tb);

    end


    //========================================================
    // AXI CHANNEL MONITOR
    //========================================================

    always @(posedge S_AXI_ACLK) begin

        if (S_AXI_ARESETN) begin

            if (S_AXI_AWVALID && S_AXI_AWREADY) begin

                $display("[%0t] AXI AW HANDSHAKE : AWADDR = 0x%08h",
                         $time,
                         S_AXI_AWADDR);

            end


            if (S_AXI_WVALID && S_AXI_WREADY) begin

                $display("[%0t] AXI W  HANDSHAKE : WDATA  = 0x%08h  WSTRB = %b",
                         $time,
                         S_AXI_WDATA,
                         S_AXI_WSTRB);

            end


            if (S_AXI_BVALID && S_AXI_BREADY) begin

                $display("[%0t] AXI B  HANDSHAKE : BRESP = %b",
                         $time,
                         S_AXI_BRESP);

            end


            if (S_AXI_ARVALID && S_AXI_ARREADY) begin

                $display("[%0t] AXI AR HANDSHAKE : ARADDR = 0x%08h",
                         $time,
                         S_AXI_ARADDR);

            end


            if (S_AXI_RVALID && S_AXI_RREADY) begin

                $display("[%0t] AXI R  HANDSHAKE : RDATA = 0x%08h  RRESP = %b",
                         $time,
                         S_AXI_RDATA,
                         S_AXI_RRESP);

            end

        end

    end


initial begin
$fsdbDumpfile("dump.fsdb");
$fsdbDumpvars("+all");
$fsdbDumpSVA;
$fsdbDumpMDA;
end

endmodule
