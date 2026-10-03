`timescale 1ns/1ps

module fft_top #(
    parameter int N = 1024
)(
    input  logic                 clk,
    input  logic                 rst_n,
    input  logic                 start,
    output logic                 done,
    output logic                 busy,

    // External sample memory write port
    input  logic                 ext_we,
    input  logic [$clog2(N)-1:0] ext_waddr,
    input  logic [31:0]          ext_wdata,

    // External sample memory read port
    input  logic [$clog2(N)-1:0] ext_raddr,
    output logic [31:0]          ext_rdata
);

    localparam int LOGN = $clog2(N);

    typedef enum logic [2:0] {
        T_IDLE,
        T_KICK,
        T_RUN,
        T_NEXT,
        T_DONE
    } tstate_t;

    tstate_t tstate, tnext;

    logic [3:0] stage_reg;
    logic [3:0] stage_next;

    logic stage_start;
    logic stage_done;
    logic stage_busy;

    // External ports into stage controller
    logic                 ctrl_ext_we;
    logic [$clog2(N)-1:0] ctrl_ext_waddr;
    logic [31:0]          ctrl_ext_wdata;
    logic [$clog2(N)-1:0] ctrl_ext_raddr;
    logic [31:0]          ctrl_ext_rdata;

    assign ext_rdata = ctrl_ext_rdata;

    // ------------------------------------------------------------
    // Stage controller instance
    // ------------------------------------------------------------
    fft_stage_core_controller #(
        .N(N)
    ) u_stage_ctrl (
        .clk      (clk),
        .rst_n    (rst_n),
        .start    (stage_start),
        .stage    (stage_reg),
        .done     (stage_done),
        .busy     (stage_busy),

        .ext_we   (ctrl_ext_we),
        .ext_waddr(ctrl_ext_waddr),
        .ext_wdata(ctrl_ext_wdata),
        .ext_raddr(ctrl_ext_raddr),
        .ext_rdata(ctrl_ext_rdata)
    );

    // ------------------------------------------------------------
    // External memory access policy
    // Allowed only when full FFT engine is idle
    // ------------------------------------------------------------
    assign ctrl_ext_we    = (tstate == T_IDLE) ? ext_we    : 1'b0;
    assign ctrl_ext_waddr = ext_waddr;
    assign ctrl_ext_wdata = ext_wdata;
    assign ctrl_ext_raddr = ext_raddr;

    // ------------------------------------------------------------
    // Combinational control
    // ------------------------------------------------------------
    always_comb begin
        tnext      = tstate;
        stage_next = stage_reg;

        stage_start = 1'b0;
        done        = 1'b0;
        busy        = (tstate != T_IDLE);

        case (tstate)
            T_IDLE: begin
                if (start) begin
                    tnext      = T_KICK;
                    stage_next = 4'd0;
                end
            end

            T_KICK: begin
                stage_start = 1'b1;
                tnext       = T_RUN;
            end

            T_RUN: begin
                if (stage_done)
                    tnext = T_NEXT;
            end

            T_NEXT: begin
                if (stage_reg == (LOGN-1)) begin
                    tnext = T_DONE;
                end
                else begin
                    stage_next = stage_reg + 1'b1;
                    tnext      = T_KICK;
                end
            end

            T_DONE: begin
                done  = 1'b1;
                tnext = T_IDLE;
            end

            default: begin
                tnext = T_IDLE;
            end
        endcase
    end

    // ------------------------------------------------------------
    // Sequential state / stage register
    // ------------------------------------------------------------
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            tstate    <= T_IDLE;
            stage_reg <= 4'd0;
        end
        else begin
            tstate    <= tnext;
            stage_reg <= stage_next;
        end
    end

endmodule