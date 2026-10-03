`timescale 1ns/1ps

module fir_dsp #(
    parameter DATA_WIDTH = 16,
    parameter COEFF_WIDTH = 16,
    parameter ACC_WIDTH = 40,
    parameter NUM_TAPS = 32
)(
    input clk,
    input rst_n,

    input [DATA_WIDTH-1:0] sample0,
    input [DATA_WIDTH-1:0] sample1,
    input [DATA_WIDTH-1:0] sample2,
    input [DATA_WIDTH-1:0] sample3,
    input [DATA_WIDTH-1:0] sample4,
    input [DATA_WIDTH-1:0] sample5,
    input [DATA_WIDTH-1:0] sample6,
    input [DATA_WIDTH-1:0] sample7,
    input [DATA_WIDTH-1:0] sample8,
    input [DATA_WIDTH-1:0] sample9,
    input [DATA_WIDTH-1:0] sample10,
    input [DATA_WIDTH-1:0] sample11,
    input [DATA_WIDTH-1:0] sample12,
    input [DATA_WIDTH-1:0] sample13,
    input [DATA_WIDTH-1:0] sample14,
    input [DATA_WIDTH-1:0] sample15,
    input [DATA_WIDTH-1:0] sample16,
    input [DATA_WIDTH-1:0] sample17,
    input [DATA_WIDTH-1:0] sample18,
    input [DATA_WIDTH-1:0] sample19,
    input [DATA_WIDTH-1:0] sample20,
    input [DATA_WIDTH-1:0] sample21,
    input [DATA_WIDTH-1:0] sample22,
    input [DATA_WIDTH-1:0] sample23,
    input [DATA_WIDTH-1:0] sample24,
    input [DATA_WIDTH-1:0] sample25,
    input [DATA_WIDTH-1:0] sample26,
    input [DATA_WIDTH-1:0] sample27,
    input [DATA_WIDTH-1:0] sample28,
    input [DATA_WIDTH-1:0] sample29,
    input [DATA_WIDTH-1:0] sample30,
    input [DATA_WIDTH-1:0] sample31,

    input samples_valid,
    output samples_ready,

    input [COEFF_WIDTH*NUM_TAPS-1:0] coeff_packed,

    output reg [ACC_WIDTH-1:0] result,
    output reg result_valid,
    input result_ready,

    output output_fifo_empty
);

    wire signed [DATA_WIDTH-1:0] samples [0:31];
    wire signed [COEFF_WIDTH-1:0] coeffs [0:31];

    reg signed [ACC_WIDTH-1:0] products [0:31];
    reg signed [ACC_WIDTH-1:0] sum_stage1 [0:15];
    reg signed [ACC_WIDTH-1:0] sum_stage2 [0:7];
    reg signed [ACC_WIDTH-1:0] sum_stage3 [0:3];
    reg signed [ACC_WIDTH-1:0] sum_stage4 [0:1];
    reg signed [ACC_WIDTH-1:0] final_sum;

    reg valid_stage1;
    reg valid_stage2;
    reg valid_stage3;
    reg valid_stage4;
    reg valid_stage5;

    assign samples[0] = sample0;
    assign samples[1] = sample1;
    assign samples[2] = sample2;
    assign samples[3] = sample3;
    assign samples[4] = sample4;
    assign samples[5] = sample5;
    assign samples[6] = sample6;
    assign samples[7] = sample7;
    assign samples[8] = sample8;
    assign samples[9] = sample9;
    assign samples[10] = sample10;
    assign samples[11] = sample11;
    assign samples[12] = sample12;
    assign samples[13] = sample13;
    assign samples[14] = sample14;
    assign samples[15] = sample15;
    assign samples[16] = sample16;
    assign samples[17] = sample17;
    assign samples[18] = sample18;
    assign samples[19] = sample19;
    assign samples[20] = sample20;
    assign samples[21] = sample21;
    assign samples[22] = sample22;
    assign samples[23] = sample23;
    assign samples[24] = sample24;
    assign samples[25] = sample25;
    assign samples[26] = sample26;
    assign samples[27] = sample27;
    assign samples[28] = sample28;
    assign samples[29] = sample29;
    assign samples[30] = sample30;
    assign samples[31] = sample31;

    genvar g;
    generate
        for (g = 0; g < NUM_TAPS; g = g + 1) begin : COEFF_UNPACK
            assign coeffs[g] = coeff_packed[g*COEFF_WIDTH +: COEFF_WIDTH];
        end
    endgenerate

    // The whole pipeline is an elastic unit.  If its output is blocked, every
    // stage holds its data so no result can be overwritten.
    wire pipeline_advance = !result_valid || result_ready;

    assign samples_ready = pipeline_advance;
    assign output_fifo_empty = !result_valid;

    integer i;

    always @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            valid_stage1 <= 1'b0;
            valid_stage2 <= 1'b0;
            valid_stage3 <= 1'b0;
            valid_stage4 <= 1'b0;
            valid_stage5 <= 1'b0;

            result_valid <= 1'b0;
            result <= {ACC_WIDTH{1'b0}};
            final_sum <= {ACC_WIDTH{1'b0}};
            
            for (i = 0; i < 32; i = i + 1)
                products[i] <= {ACC_WIDTH{1'b0}};
            
            for (i = 0; i < 16; i = i + 1)
                sum_stage1[i] <= {ACC_WIDTH{1'b0}};
            
            for (i = 0; i < 8; i = i + 1)
                sum_stage2[i] <= {ACC_WIDTH{1'b0}};
            
            for (i = 0; i < 4; i = i + 1)
                sum_stage3[i] <= {ACC_WIDTH{1'b0}};
            
            for (i = 0; i < 2; i = i + 1)
                sum_stage4[i] <= {ACC_WIDTH{1'b0}};

        end else if (pipeline_advance) begin

            // Stage 1: 32 multipliers
            valid_stage1 <= samples_valid;

            if (samples_valid) begin
                for (i = 0; i < 32; i = i + 1)
                    products[i] <= samples[i] * coeffs[i];
            end

            // Stage 2: 32 -> 16
            valid_stage2 <= valid_stage1;

            if (valid_stage1) begin
                for (i = 0; i < 16; i = i + 1)
                    sum_stage1[i] <= products[2*i] + products[2*i+1];
            end

            // Stage 3: 16 -> 8
            valid_stage3 <= valid_stage2;

            if (valid_stage2) begin
                for (i = 0; i < 8; i = i + 1)
                    sum_stage2[i] <= sum_stage1[2*i] + sum_stage1[2*i+1];
            end

            // Stage 4: 8 -> 4
            valid_stage4 <= valid_stage3;

            if (valid_stage3) begin
                for (i = 0; i < 4; i = i + 1)
                    sum_stage3[i] <= sum_stage2[2*i] + sum_stage2[2*i+1];
            end

            // Stage 5: 4 -> 2
            valid_stage5 <= valid_stage4;

            if (valid_stage4) begin
                sum_stage4[0] <= sum_stage3[0] + sum_stage3[1];
                sum_stage4[1] <= sum_stage3[2] + sum_stage3[3];
            end

            // Stage 6: 2 -> 1
            result_valid <= valid_stage5;

            if (valid_stage5) begin
                final_sum <= sum_stage4[0] + sum_stage4[1];
                result <= sum_stage4[0] + sum_stage4[1];
            end
        end
    end

endmodule
