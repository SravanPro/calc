`timescale 1ns / 1ps

// pow_core: computes x^y = exp( y * ln(x) )
// signA/mantA/expA = x (base)
// signB/mantB/expB = y (exponent)

module pow_core (
    input  wire              clock,
    input  wire              reset,
    input  wire              eval,
    output reg               done,

    input  wire              signA,
    input  wire [33:0]       mantA,
    input  wire signed [6:0] expA,

    input  wire              signB,
    input  wire [33:0]       mantB,
    input  wire signed [6:0] expB,

    output reg               signRes,
    output reg  [33:0]       mantRes,
    output reg  signed [6:0] expRes,

    // ln_core interface
    output reg               ln_eval,
    output reg               ln_signA,
    output reg  [33:0]       ln_mantA,
    output reg  signed [6:0] ln_expA,
    input  wire              ln_done,
    input  wire              ln_signRes,
    input  wire [33:0]       ln_mantRes,
    input  wire signed [6:0] ln_expRes,

    // exp_core interface
    output reg               exp_eval,
    output reg               exp_signA,
    output reg  [33:0]       exp_mantA,
    output reg  signed [6:0] exp_expA,
    input  wire              exp_done,
    input  wire              exp_signRes,
    input  wire [33:0]       exp_mantRes,
    input  wire signed [6:0] exp_expRes,

    // seq_multiplier interface (for y * lnx step only)
    output reg               mul_start,
    output reg  [511:0]      mul_multiplicand,
    output reg  [511:0]      mul_multiplier,
    input  wire              mul_done,
    input  wire [511:0]      mul_product,

    // seq_divider interface (for normalisation only)
    output reg               div_start,
    output reg  [511:0]      div_dividend,
    output reg  [511:0]      div_divisor,
    input  wire              div_done,
    input  wire [511:0]      div_quotient
);

    localparam [33:0] M_MAX       = 34'd17_179_869_183;
    localparam [33:0] M_MAX_DIV10 = 34'd1_717_986_918;

    typedef enum logic [3:0] {
        S_IDLE      = 4'd0,
        S_LNX       = 4'd1,
        S_LNX_WAIT  = 4'd2,
        S_MUL       = 4'd3,
        S_MUL_WAIT  = 4'd4,
        S_NORMALIZE = 4'd5,
        S_NORM_DW   = 4'd6,
        S_EXP       = 4'd7,
        S_EXP_WAIT  = 4'd8,
        S_DONE      = 4'd9
    } state_t;

    state_t state;

    reg              lnx_sign;
    reg [33:0]       lnx_mant;
    reg signed [6:0] lnx_exp;

    // y * lnx intermediate
    // max value = 17_179_869_183 * 17_179_869_183 ~ 2.95e20, fits in 72 bits
    reg              ylnx_sign;
    reg [71:0]       ylnx_raw;
    reg signed [31:0] ylnx_exp_wide;

    wire [71:0] ylnx_x10 = (ylnx_raw << 3) + (ylnx_raw << 1);

    reg  evalPrev;
    wire doEval = eval && !evalPrev;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            state    <= S_IDLE;
            done     <= 1'b0;
            evalPrev <= 1'b0;

            ln_eval  <= 1'b0;
            ln_signA <= 1'b0;
            ln_mantA <= 34'd0;
            ln_expA  <= 7'sd0;

            exp_eval  <= 1'b0;
            exp_signA <= 1'b0;
            exp_mantA <= 34'd0;
            exp_expA  <= 7'sd0;

            mul_start        <= 1'b0;
            mul_multiplicand <= 512'd0;
            mul_multiplier   <= 512'd0;

            div_start    <= 1'b0;
            div_dividend <= 512'd0;
            div_divisor  <= 512'd0;

            lnx_sign <= 1'b0; lnx_mant <= 34'd0; lnx_exp <= 7'sd0;

            ylnx_sign     <= 1'b0;
            ylnx_raw      <= 72'd0;
            ylnx_exp_wide <= 32'sd0;

            signRes <= 1'b0;
            mantRes <= 34'd0;
            expRes  <= 7'sd0;
        end
        else begin
            evalPrev  <= eval;
            ln_eval   <= 1'b0;
            exp_eval  <= 1'b0;
            mul_start <= 1'b0;
            div_start <= 1'b0;
            done      <= 1'b0;

            case (state)

                S_IDLE: begin
                    if (doEval) state <= S_LNX;
                end

                // step 1: ln(x) - x (base) is B (deeper in stack)
                S_LNX: begin
                    ln_signA <= signB;
                    ln_mantA <= mantB;
                    ln_expA  <= expB;
                    ln_eval  <= 1'b1;
                    state    <= S_LNX_WAIT;
                end

                S_LNX_WAIT: begin
                    if (ln_done) begin
                        lnx_sign <= ln_signRes;
                        lnx_mant <= ln_mantRes;
                        lnx_exp  <= ln_expRes;
                        state    <= S_MUL;
                    end
                end

                // step 2: y * ln(x)
                // y (exponent) is A (top of stack)
                // mantissa multiply: mantA * lnx_mant
                // exponent sum:      expA  + lnx_exp
                // sign xor:          signA ^ lnx_sign
                S_MUL: begin
                    mul_multiplicand <= {478'd0, mantA};
                    mul_multiplier   <= {478'd0, lnx_mant};
                    mul_start        <= 1'b1;
                    ylnx_sign        <= signA ^ lnx_sign;
                    ylnx_exp_wide    <= $signed(expA) + $signed(lnx_exp);
                    state            <= S_MUL_WAIT;
                end

                S_MUL_WAIT: begin
                    if (mul_done) begin
                        ylnx_raw <= mul_product[71:0];
                        state    <= S_NORMALIZE;
                    end
                end

                // step 3: normalise y*lnx into [ M_MAX_DIV10, M_MAX ]
                // use seq_divider for /10, shift-add for *10
                S_NORMALIZE: begin
                    if (ylnx_raw > {38'd0, M_MAX}) begin
                        div_dividend  <= {440'd0, ylnx_raw};
                        div_divisor   <= 512'd10;
                        div_start     <= 1'b1;
                        ylnx_exp_wide <= ylnx_exp_wide + 32'sd1;
                        state         <= S_NORM_DW;
                    end
                    else if (ylnx_raw != 72'd0 &&
                             ylnx_raw < {38'd0, M_MAX_DIV10}) begin
                        ylnx_raw      <= ylnx_x10;
                        ylnx_exp_wide <= ylnx_exp_wide - 32'sd1;
                    end
                    else begin
                        state <= S_EXP;
                    end
                end

                S_NORM_DW: begin
                    if (div_done) begin
                        ylnx_raw <= div_quotient[71:0];
                        state    <= S_NORMALIZE;
                    end
                end

                // step 4: exp( y * ln(x) )
                S_EXP: begin
                    exp_signA <= ylnx_sign;
                    exp_mantA <= ylnx_raw[33:0];
                    exp_expA  <= ylnx_exp_wide[6:0];
                    exp_eval  <= 1'b1;
                    state     <= S_EXP_WAIT;
                end

                S_EXP_WAIT: begin
                    if (exp_done) begin
                        signRes <= exp_signRes;
                        mantRes <= exp_mantRes;
                        expRes  <= exp_expRes;
                        state   <= S_DONE;
                    end
                end

                S_DONE: begin
                    done  <= 1'b1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;

            endcase
        end
    end

endmodule