`timescale 1ns / 1ps
//  Computes  result = tan(x) = sin(x) / cos(x)

module tan_core (
    input  wire              clock,
    input  wire              reset,
    input  wire              eval,
    output reg               done,

    input  wire              signA,
    input  wire [33:0]       mantA,
    input  wire signed [6:0] expA,

    output reg               signRes,
    output reg  [33:0]       mantRes,
    output reg  signed [6:0] expRes,

    // sin_core interface
    output reg               sin_eval,
    output reg               sin_signA,
    output reg  [33:0]       sin_mantA,
    output reg  signed [6:0] sin_expA,
    input  wire              sin_done,
    input  wire              sin_signRes,
    input  wire [33:0]       sin_mantRes,
    input  wire signed [6:0] sin_expRes,

    // cos_core interface
    output reg               cos_eval,
    output reg               cos_signA,
    output reg  [33:0]       cos_mantA,
    output reg  signed [6:0] cos_expA,
    input  wire              cos_done,
    input  wire              cos_signRes,
    input  wire [33:0]       cos_mantRes,
    input  wire signed [6:0] cos_expRes,

    // seq_divider interface
    output reg               div_start,
    output reg  [511:0]      div_dividend,
    output reg  [511:0]      div_divisor,
    input  wire              div_done,
    input  wire [511:0]      div_quotient,

    // seq_multiplier interface (for sin_mant * SCALE scaling step)
    output reg               mul_start,
    output reg  [511:0]      mul_multiplicand,
    output reg  [511:0]      mul_multiplier,
    input  wire              mul_done,
    input  wire [511:0]      mul_product
);

    localparam [63:0] SCALE       = 64'd1_000_000_000_000_000;
    localparam [33:0] M_MAX       = 34'd17_179_869_183;
    localparam [33:0] M_MAX_DIV10 = 34'd1_717_986_918;

    typedef enum logic [3:0] {
        T_IDLE      = 4'd0,
        T_SIN       = 4'd1,
        T_SIN_WAIT  = 4'd2,
        T_COS       = 4'd3,
        T_COS_WAIT  = 4'd4,
        T_DIV_MUL   = 4'd5,   // seq_mul sin_mant * SCALE
        T_DIV_MUL_W = 4'd6,   // wait; then fire div
        T_DIV_WAIT  = 4'd7,
        T_NORMALIZE = 4'd8,
        T_NORM_DW   = 4'd9,
        T_DONE      = 4'd10
    } tstate_t;

    tstate_t state;

    reg              sin_sign;
    reg [33:0]       sin_mant;
    reg signed [6:0] sin_exp;

    reg              cos_sign;
    reg [33:0]       cos_mant;
    reg signed [6:0] cos_exp;

    // 84 bits is sufficient: sin_mant*SCALE/cos_mant max ~84 bits
    reg [83:0]        div_result;
    reg signed [31:0] rexp;

    wire [83:0] divres_x10 = (div_result << 3) + (div_result << 1);

    reg  evalPrev;
    wire doEval = eval && !evalPrev;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            state    <= T_IDLE;
            done     <= 1'b0;
            evalPrev <= 1'b0;

            sin_eval  <= 1'b0; sin_signA <= 1'b0;
            sin_mantA <= 34'd0; sin_expA <= 7'sd0;
            cos_eval  <= 1'b0; cos_signA <= 1'b0;
            cos_mantA <= 34'd0; cos_expA <= 7'sd0;

            div_start    <= 1'b0;
            div_dividend <= 512'd0;
            div_divisor  <= 512'd0;

            mul_start        <= 1'b0;
            mul_multiplicand <= 512'd0;
            mul_multiplier   <= 512'd0;

            sin_sign <= 1'b0; sin_mant <= 34'd0; sin_exp <= 7'sd0;
            cos_sign <= 1'b0; cos_mant <= 34'd0; cos_exp <= 7'sd0;

            div_result <= 84'd0;
            rexp       <= 32'sd0;

            signRes <= 1'b0;
            mantRes <= 34'd0;
            expRes  <= 7'sd0;
        end
        else begin
            evalPrev  <= eval;
            sin_eval  <= 1'b0;
            cos_eval  <= 1'b0;
            div_start <= 1'b0;
            mul_start <= 1'b0;
            done      <= 1'b0;

            case (state)

                T_IDLE: begin
                    if (doEval) state <= T_SIN;
                end

                // step 1: sin(x)
                T_SIN: begin
                    sin_signA <= signA;
                    sin_mantA <= mantA;
                    sin_expA  <= expA;
                    sin_eval  <= 1'b1;
                    state     <= T_SIN_WAIT;
                end

                T_SIN_WAIT: begin
                    if (sin_done) begin
                        sin_sign <= sin_signRes;
                        sin_mant <= sin_mantRes;
                        sin_exp  <= sin_expRes;
                        state    <= T_COS;
                    end
                end

                // step 2: cos(x)
                T_COS: begin
                    cos_signA <= signA;
                    cos_mantA <= mantA;
                    cos_expA  <= expA;
                    cos_eval  <= 1'b1;
                    state     <= T_COS_WAIT;
                end

                T_COS_WAIT: begin
                    if (cos_done) begin
                        cos_sign <= cos_signRes;
                        cos_mant <= cos_mantRes;
                        cos_exp  <= cos_expRes;
                        state    <= T_DIV_MUL;
                    end
                end

                // step 3a: scale numerator - sin_mant * SCALE via seq_mul
                T_DIV_MUL: begin
                    mul_multiplicand <= {478'd0, sin_mant};
                    mul_multiplier   <= {448'd0, SCALE};
                    mul_start        <= 1'b1;
                    state            <= T_DIV_MUL_W;
                end

                // step 3b: now fire seq_div scaled_sin / cos_mant
                T_DIV_MUL_W: begin
                    if (mul_done) begin
                        div_dividend <= mul_product;
                        div_divisor  <= {478'd0, cos_mant};
                        div_start    <= 1'b1;
                        rexp         <= $signed(sin_exp) - $signed(cos_exp) - 32'sd15;
                        signRes      <= sin_sign ^ cos_sign;
                        state        <= T_DIV_WAIT;
                    end
                end

                T_DIV_WAIT: begin
                    if (div_done) begin
                        div_result <= div_quotient[83:0];
                        state      <= T_NORMALIZE;
                    end
                end

                T_NORMALIZE: begin
                    if (div_result > {50'd0, M_MAX}) begin
                        div_dividend <= {428'd0, div_result};
                        div_divisor  <= 512'd10;
                        div_start    <= 1'b1;
                        rexp         <= rexp + 32'sd1;
                        state        <= T_NORM_DW;
                    end
                    else if (div_result != 84'd0 &&
                             div_result < {50'd0, M_MAX_DIV10}) begin
                        div_result <= divres_x10;
                        rexp       <= rexp - 32'sd1;
                    end
                    else begin
                        mantRes <= div_result[33:0];
                        expRes  <= rexp[6:0];
                        state   <= T_DONE;
                    end
                end

                T_NORM_DW: begin
                    if (div_done) begin
                        div_result <= div_quotient[83:0];
                        state      <= T_NORMALIZE;
                    end
                end

                T_DONE: begin
                    done  <= 1'b1;
                    state <= T_IDLE;
                end

                default: state <= T_IDLE;

            endcase
        end
    end

endmodule