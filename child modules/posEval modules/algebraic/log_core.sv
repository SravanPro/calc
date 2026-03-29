`timescale 1ns / 1ps

// log_core: computes log_y(x) = ln(x) / ln(y)
// signA/mantA/expA = x (the number)
// signB/mantB/expB = y (the base)

module log_core (
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

    // seq_divider interface (for lnx / lny step only)
    output reg               div_start,
    output reg  [511:0]      div_dividend,
    output reg  [511:0]      div_divisor,
    input  wire              div_done,
    input  wire [511:0]      div_quotient
);

    localparam [33:0] M_MAX       = 34'd17_179_869_183;
    localparam [33:0] M_MAX_DIV10 = 34'd1_717_986_918;
    localparam [63:0] SCALE       = 64'd1_000_000_000_000_000;

    typedef enum logic [3:0] {
        S_IDLE      = 4'd0,
        S_LNX       = 4'd1,
        S_LNX_WAIT  = 4'd2,
        S_LNY       = 4'd3,
        S_LNY_WAIT  = 4'd4,
        S_DIV       = 4'd5,
        S_DIV_WAIT  = 4'd6,
        S_NORMALIZE = 4'd7,
        S_NORM_DW   = 4'd8,
        S_DONE      = 4'd9
    } state_t;

    state_t state;

    reg              lnx_sign;
    reg [33:0]       lnx_mant;
    reg signed [6:0] lnx_exp;

    reg              lny_sign;
    reg [33:0]       lny_mant;
    reg signed [6:0] lny_exp;

    // div_result holds lnx_mant * SCALE / lny_mant
    // max = 17_179_869_183 * 10^15 / 1 ~ 84 bits
    reg [83:0]        div_result;
    reg signed [31:0] rexp;

    wire [83:0] divres_x10 = (div_result << 3) + (div_result << 1);

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

            div_start    <= 1'b0;
            div_dividend <= 512'd0;
            div_divisor  <= 512'd0;

            lnx_sign <= 1'b0; lnx_mant <= 34'd0; lnx_exp <= 7'sd0;
            lny_sign <= 1'b0; lny_mant <= 34'd0; lny_exp <= 7'sd0;

            div_result <= 84'd0;
            rexp       <= 32'sd0;

            signRes <= 1'b0;
            mantRes <= 34'd0;
            expRes  <= 7'sd0;
        end
        else begin
            evalPrev  <= eval;
            ln_eval   <= 1'b0;
            div_start <= 1'b0;
            done      <= 1'b0;

            case (state)

                S_IDLE: begin
                    if (doEval) state <= S_LNX;
                end

                // step 1: compute ln(x) - x is B (deeper in stack)
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
                        state    <= S_LNY;
                    end
                end

                // step 2: compute ln(y) - y (base) is A (top of stack)
                S_LNY: begin
                    ln_signA <= signA;
                    ln_mantA <= mantA;
                    ln_expA  <= expA;
                    ln_eval  <= 1'b1;
                    state    <= S_LNY_WAIT;
                end

                S_LNY_WAIT: begin
                    if (ln_done) begin
                        lny_sign <= ln_signRes;
                        lny_mant <= ln_mantRes;
                        lny_exp  <= ln_expRes;
                        state    <= S_DIV;
                    end
                end

                // step 3: lnx / lny
                // scale lnx_mant by SCALE (10^15) before dividing so the
                // integer quotient carries 15 decimal digits of precision
                // true result = quotient * 10^( lnx_exp - lny_exp - 15 )
                S_DIV: begin
                    div_dividend <= {448'd0, lnx_mant} * {448'd0, SCALE};
                    div_divisor  <= {478'd0, lny_mant};
                    div_start    <= 1'b1;
                    rexp         <= $signed(lnx_exp) - $signed(lny_exp) - 32'sd15;
                    signRes      <= lnx_sign ^ lny_sign;
                    state        <= S_DIV_WAIT;
                end

                S_DIV_WAIT: begin
                    if (div_done) begin
                        div_result <= div_quotient[83:0];
                        state      <= S_NORMALIZE;
                    end
                end

                // normalise into [ M_MAX_DIV10, M_MAX ]
                S_NORMALIZE: begin
                    if (div_result > {50'd0, M_MAX}) begin
                        div_dividend <= {428'd0, div_result};
                        div_divisor  <= 512'd10;
                        div_start    <= 1'b1;
                        rexp         <= rexp + 32'sd1;
                        state        <= S_NORM_DW;
                    end
                    else if (div_result != 84'd0 &&
                             div_result < {50'd0, M_MAX_DIV10}) begin
                        div_result <= divres_x10;
                        rexp       <= rexp - 32'sd1;
                    end
                    else begin
                        mantRes <= div_result[33:0];
                        expRes  <= rexp[6:0];
                        state   <= S_DONE;
                    end
                end

                S_NORM_DW: begin
                    if (div_done) begin
                        div_result <= div_quotient[83:0];
                        state      <= S_NORMALIZE;
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