`timescale 1ns / 1ps
//  Computes  result = cos( mantA * 10^expA )   [radians]
//
module cos_core (
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

    output reg               div_start,
    output reg  [511:0]      div_dividend,
    output reg  [511:0]      div_divisor,
    input  wire              div_done,
    input  wire [511:0]      div_quotient,

    output reg               mul_start,
    output reg  [511:0]      mul_multiplicand,
    output reg  [511:0]      mul_multiplier,
    input  wire              mul_done,
    input  wire [511:0]      mul_product
);

    localparam [63:0]  SCALE        = 64'd1_000_000_000_000_000;
    localparam [63:0]  TWO_PI_S     = 64'd6_283_185_307_179_586;
    localparam [63:0]  PI_S         = 64'd3_141_592_653_589_793;
    localparam [63:0]  PI_OVER_2_S  = 64'd1_570_796_326_794_897;
    localparam [63:0]  THREE_PI_2_S = 64'd4_712_388_980_384_690;
    localparam [33:0]  M_MAX        = 34'd17_179_869_183;
    localparam [33:0]  M_MAX_DIV10  = 34'd1_717_986_918;
    localparam [4:0]   NTERMS       = 5'd15;

    typedef enum logic [4:0] {
        S_IDLE       = 5'd0,
        S_INIT_MW    = 5'd1,
        S_CONVERT    = 5'd2,
        S_CONV_DW    = 5'd3,
        S_RR_DIV     = 5'd4,
        S_RR_DIV_W   = 5'd5,
        S_RR_MUL_W   = 5'd6,
        S_QUADRANT   = 5'd7,
        S_XR2_MUL    = 5'd8,
        S_XR2_MW     = 5'd9,
        S_DENOM_MUL  = 5'd10,
        S_DENOM_MW   = 5'd11,
        S_DENOM_MW2  = 5'd12,
        S_TAYLOR_MUL = 5'd13,
        S_TAYLOR_MW  = 5'd14,
        S_TAYLOR_DW1 = 5'd15,
        S_TAYLOR_DW2 = 5'd16,
        S_NORMALIZE  = 5'd17,
        S_NORM_DW    = 5'd18,
        S_DONE       = 5'd19
    } state_t;

    state_t state;

    reg [95:0]        fixedX;
    reg [95:0]        xr;           // 96-bit reduced angle
    reg [191:0]       xr2;          // xr*xr, NOT divided by SCALE
    reg [191:0]       cur_term;
    reg [191:0]       accum;
    reg [191:0]       result;
    reg [191:0]       denom_scaled;
    reg signed [31:0] rexp;
    reg signed [7:0]  erem;
    reg [7:0]         da, db;
    reg [4:0]         n;
    reg               signFlip;
    reg               evalPrev;
    wire doEval = eval && !evalPrev;

    wire [95:0]  fixedX_x10 = (fixedX << 3) + (fixedX << 1);
    wire [191:0] result_x10 = (result  << 3) + (result  << 1);

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            state            <= S_IDLE;
            done             <= 1'b0;
            evalPrev         <= 1'b0;
            div_start        <= 1'b0;
            mul_start        <= 1'b0;
            fixedX           <= 96'd0;
            xr               <= 96'd0;
            xr2              <= 192'd0;
            cur_term         <= 192'd0;
            accum            <= 192'd0;
            result           <= 192'd0;
            denom_scaled     <= 192'd0;
            rexp             <= 32'sd0;
            erem             <= 8'sd0;
            da               <= 8'd0;
            db               <= 8'd0;
            n                <= 5'd0;
            signFlip         <= 1'b0;
            signRes          <= 1'b0;
            mantRes          <= 34'd0;
            expRes           <= 7'sd0;
            div_dividend     <= 512'd0;
            div_divisor      <= 512'd0;
            mul_multiplicand <= 512'd0;
            mul_multiplier   <= 512'd0;
        end
        else begin
            evalPrev  <= eval;
            div_start <= 1'b0;
            mul_start <= 1'b0;

            case (state)

            //  Idle: cos is even so input sign is irrelevant
            S_IDLE: begin
                done <= 1'b0;
                if (doEval) begin
                    signFlip         <= 1'b0;
                    erem             <= $signed(expA);
                    mul_multiplicand <= {478'd0, mantA};
                    mul_multiplier   <= {448'd0, SCALE};
                    mul_start        <= 1'b1;
                    state            <= S_INIT_MW;
                end
            end

            S_INIT_MW: begin
                if (mul_done) begin
                    fixedX <= mul_product[95:0];
                    state  <= S_CONVERT;
                end
            end

            //  Absorb expA
            S_CONVERT: begin
                if ($signed(erem) > 8'sd0) begin
                    fixedX <= fixedX_x10;
                    erem   <= erem - 8'sd1;
                end
                else if ($signed(erem) < 8'sd0) begin
                    div_dividend <= {416'd0, fixedX};
                    div_divisor  <= 512'd10;
                    div_start    <= 1'b1;
                    erem         <= erem + 8'sd1;
                    state        <= S_CONV_DW;
                end
                else state <= S_RR_DIV;
            end

            S_CONV_DW: begin
                if (div_done) begin
                    fixedX <= div_quotient[95:0];
                    state  <= S_CONVERT;
                end
            end

            //  Range-reduce to [0, 2pi)
            S_RR_DIV: begin
                div_dividend <= {416'd0, fixedX};
                div_divisor  <= {448'd0, TWO_PI_S};
                div_start    <= 1'b1;
                state        <= S_RR_DIV_W;
            end

            S_RR_DIV_W: begin
                if (div_done) begin
                    mul_multiplicand <= div_quotient;
                    mul_multiplier   <= {448'd0, TWO_PI_S};
                    mul_start        <= 1'b1;
                    state            <= S_RR_MUL_W;
                end
            end

            // full 96-bit subtraction
            S_RR_MUL_W: begin
                if (mul_done) begin
                    xr    <= fixedX - mul_product[95:0];
                    state <= S_QUADRANT;
                end
            end

            //  Quadrant reduction for cos (all comparisons 96-bit)
            //  [0,   pi/2]: +cos(xr)
            //  [pi/2,  pi]: -cos(pi - xr)
            //  [pi, 3pi/2]: -cos(xr - pi)
            //  [3pi/2,2pi]: +cos(2pi - xr)
            S_QUADRANT: begin
                if (xr <= {32'd0, PI_OVER_2_S}) begin
                    state <= S_XR2_MUL;
                end
                else if (xr <= {32'd0, PI_S}) begin
                    xr       <= {32'd0, PI_S} - xr;
                    signFlip <= ~signFlip;
                    state    <= S_XR2_MUL;
                end
                else if (xr <= {32'd0, THREE_PI_2_S}) begin
                    xr       <= xr - {32'd0, PI_S};
                    signFlip <= ~signFlip;
                    state    <= S_XR2_MUL;
                end
                else begin
                    xr    <= {32'd0, TWO_PI_S} - xr;
                    state <= S_XR2_MUL;
                end
            end

            //  xr2 = xr * xr  (NOT divided by SCALE)
            S_XR2_MUL: begin
                mul_multiplicand <= {416'd0, xr};
                mul_multiplier   <= {416'd0, xr};
                mul_start        <= 1'b1;
                state            <= S_XR2_MW;
            end

            S_XR2_MW: begin
                if (mul_done) begin
                    xr2      <= mul_product[191:0];
                    // cos first term = 1.0 = SCALE in fixed-point
                    cur_term <= {128'd0, SCALE};
                    accum    <= {128'd0, SCALE};
                    // first denom: da=1, db=2  (2*1-1=1, 2*1=2)
                    da    <= 8'd1;
                    db    <= 8'd2;
                    n     <= 5'd1;
                    state <= S_DENOM_MUL;
                end
            end

            //  denom_scaled = da * db * SCALE
            S_DENOM_MUL: begin
                if (n < NTERMS) begin
                    mul_multiplicand <= {504'd0, da};
                    mul_multiplier   <= {504'd0, db};
                    mul_start        <= 1'b1;
                    state            <= S_DENOM_MW;
                end
                else begin
                    result <= accum;
                    rexp   <= -32'sd15;
                    state  <= S_NORMALIZE;
                end
            end

            S_DENOM_MW: begin
                if (mul_done) begin
                    mul_multiplicand <= mul_product;
                    mul_multiplier   <= {448'd0, SCALE};
                    mul_start        <= 1'b1;
                    state            <= S_DENOM_MW2;
                end
            end

            S_DENOM_MW2: begin
                if (mul_done) begin
                    denom_scaled <= mul_product[191:0];
                    state        <= S_TAYLOR_MUL;
                end
            end

            //  Taylor term:
            //    new_cur = cur_term * xr2 / SCALE / denom_scaled
            S_TAYLOR_MUL: begin
                mul_multiplicand <= {320'd0, cur_term};
                mul_multiplier   <= {320'd0, xr2};
                mul_start        <= 1'b1;
                state            <= S_TAYLOR_MW;
            end

            S_TAYLOR_MW: begin
                if (mul_done) begin
                    div_dividend <= mul_product;
                    div_divisor  <= {448'd0, SCALE};
                    div_start    <= 1'b1;
                    state        <= S_TAYLOR_DW1;
                end
            end

            S_TAYLOR_DW1: begin
                if (div_done) begin
                    div_dividend <= div_quotient;
                    div_divisor  <= {320'd0, denom_scaled};
                    div_start    <= 1'b1;
                    state        <= S_TAYLOR_DW2;
                end
            end

            S_TAYLOR_DW2: begin
                if (div_done) begin
                    cur_term <= div_quotient[191:0];
                    // n=1 (odd): subtract x^2/2!  n=2 (even): add x^4/4!
                    if (n[0])
                        accum <= accum - div_quotient[191:0];
                    else
                        accum <= accum + div_quotient[191:0];
                    da    <= da + 8'd2;
                    db    <= db + 8'd2;
                    n     <= n + 5'd1;
                    state <= S_DENOM_MUL;
                end
            end

            //  Normalise into [M_MAX_DIV10, M_MAX]
            S_NORMALIZE: begin
                if (result > {158'd0, M_MAX}) begin
                    div_dividend <= {320'd0, result};
                    div_divisor  <= 512'd10;
                    div_start    <= 1'b1;
                    rexp         <= rexp + 32'sd1;
                    state        <= S_NORM_DW;
                end
                else if (result != 192'd0 &&
                         result < {158'd0, M_MAX_DIV10}) begin
                    result <= result_x10;
                    rexp   <= rexp - 32'sd1;
                end
                else begin
                    signRes <= signFlip;
                    mantRes <= result[33:0];
                    expRes  <= rexp[6:0];
                    state   <= S_DONE;
                end
            end

            S_NORM_DW: begin
                if (div_done) begin
                    result <= div_quotient[191:0];
                    state  <= S_NORMALIZE;
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