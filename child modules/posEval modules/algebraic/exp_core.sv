`timescale 1ns / 1ps

//  Computes  result = e^( mantA * 10^expA )
//
//  Every multiplication and every division is offloaded to
//  external seq_multiplier and seq_divider modules.
//
//  Algorithm:
//    1. fixedX = mantA * SCALE                        (MUL)
//    2. Absorb expA: ×10 via shift-add, ÷10 via DIV
//    3. k = floor(fixedX / LN2_S)                    (DIV)
//    4. r_s = fixedX - k*LN2_S                       (MUL then sub)
//    5. Taylor e^r_s, NTERMS=28:
//         term_{n+1} = term_n * r_s / denom_r        (MUL then DIV)
//         denom_r += SCALE each iter  (replaces SCALE*(n+1) multiply)
//    6. e^x = e^r_s * 2^k  via k left-shifts         (free)
//    7. If negative input: result = SCALE_SQ / result (DIV)
//    8. Normalise: ×10 via shift-add, ÷10 via DIV
//
//  Replacements for every original * :
//    mantA*SCALE        -> MUL (S_IDLE -> S_INIT_MW)
//    fixedX*10          -> (fixedX<<3)+(fixedX<<1)   shift-add
//    k_val*LN2_S        -> MUL (S_RR2_MUL -> S_RR2_MW)
//    cur_term*r_s wire  -> MUL (S_TAYLOR_MUL -> S_TAYLOR_MW)
//    SCALE*(n+1) wire   -> denom_r register, += SCALE each iteration
//    result*10          -> (result<<3)+(result<<1)   shift-add

module exp_core (
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

    
    //  Divider interface
    
    output reg               div_start,
    output reg  [511:0]      div_dividend,
    output reg  [511:0]      div_divisor,
    input  wire              div_done,
    input  wire [511:0]      div_quotient,

   
    //  Multiplier interface
   
    output reg               mul_start,
    output reg  [511:0]      mul_multiplicand,
    output reg  [511:0]      mul_multiplier,
    input  wire              mul_done,
    input  wire [511:0]      mul_product
);

    
    //  Constants
    
    localparam [63:0]  SCALE       = 64'd1_000_000_000_000_000;
    localparam [63:0]  LN2_S       = 64'd693_147_180_559_945;
    localparam [33:0]  M_MAX       = 34'd17_179_869_183;
    localparam [33:0]  M_MAX_DIV10 = 34'd1_717_986_918;
    // SCALE^2 = 10^30; hex: python f"{10**30:032x}"
    localparam [127:0] SCALE_SQ    = 128'h0000000c9f2c9cd04674edea40000000;
    localparam integer NTERMS      = 28;

    
    //  State encoding
    
    localparam [4:0]
        S_IDLE        = 5'd0,
        S_INIT_MW     = 5'd1,   // wait MUL: mantA*SCALE -> fixedX
        S_CONVERT     = 5'd2,   // absorb expA (shift-add ×10 or DIV ÷10)
        S_CONV_DIVW   = 5'd3,   // wait DIV/10 -> fixedX; loop
        S_RR1         = 5'd4,   // DIV fixedX/LN2_S -> k_val
        S_RR1_WAIT    = 5'd5,   // wait DIV
        S_RR2_MUL     = 5'd6,   // MUL k_val*LN2_S -> kln2
        S_RR2_MW      = 5'd7,   // wait MUL; r_s = fixedX - kln2; init Taylor
        S_TAYLOR_MUL  = 5'd8,   // MUL cur_term*r_s  [×NTERMS]
        S_TAYLOR_MW   = 5'd9,   // wait MUL; immediately issue DIV
        S_TAYLOR_W    = 5'd10,  // wait DIV; accum+=term; denom_r+=SCALE; n++
        S_POW2        = 5'd11,  // result<<=1 k times
        S_INVERT      = 5'd12,  // DIV SCALE_SQ/result  (negative input)
        S_INVERT_W    = 5'd13,  // wait DIV
        S_NORMALIZE   = 5'd14,  // scale result into [M_MAX/10, M_MAX]
        S_NORM_DIVW   = 5'd15,  // wait DIV/10
        S_DONE        = 5'd16;

    reg [4:0] state;

 
    //  Data registers
   
    reg [127:0]       fixedX;
    reg [127:0]       r_s;
    reg [15:0]        k_val;
    reg [255:0]       cur_term;
    reg [255:0]       accum;
    reg [511:0]       result;
    reg [63:0]        denom_r;    // running Taylor denominator; += SCALE each iter
    reg signed [31:0] rexp;
    reg signed [7:0]  erem;
    reg [15:0]        kcnt;
    reg [4:0]         n;
    reg               negInput;

    reg  evalPrev;
    wire doEval = eval && !evalPrev;

    // ×10 via shift-add - no multiplier
    wire [127:0] fixedX_x10 = (fixedX << 3) + (fixedX << 1);
    wire [511:0] result_x10 = (result << 3) + (result << 1);

   
    //  State machine
  
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            state            <= S_IDLE;
            done             <= 1'b0;
            signRes          <= 1'b0;
            mantRes          <= 34'd0;
            expRes           <= 7'sd0;
            evalPrev         <= 1'b0;
            div_start        <= 1'b0;
            mul_start        <= 1'b0;
            div_dividend     <= 512'd0;
            div_divisor      <= 512'd0;
            mul_multiplicand <= 512'd0;
            mul_multiplier   <= 512'd0;
            fixedX           <= 128'd0;
            r_s              <= 128'd0;
            k_val            <= 16'd0;
            cur_term         <= 256'd0;
            accum            <= 256'd0;
            result           <= 512'd0;
            denom_r          <= 64'd0;
            rexp             <= 32'sd0;
            erem             <= 8'sd0;
            kcnt             <= 16'd0;
            n                <= 5'd0;
            negInput         <= 1'b0;
        end else begin
            evalPrev  <= eval;
            div_start <= 1'b0;
            mul_start <= 1'b0;

            case (state)

          
            //  On eval, immediately kick off MUL mantA * SCALE
            
            S_IDLE: begin
                done <= 1'b0;
                if (doEval) begin
                    signRes          <= 1'b0;
                    negInput         <= signA;
                    erem             <= $signed(expA);
                    mul_multiplicand <= {478'd0, mantA};
                    mul_multiplier   <= {448'd0, SCALE};
                    mul_start        <= 1'b1;
                    state            <= S_INIT_MW;
                end
            end

            S_INIT_MW: begin
                if (mul_done) begin
                    fixedX <= mul_product[127:0];
                    state  <= S_CONVERT;
                end
            end

        
            //  Absorb expA into fixedX.
            //  erem > 0: ×10 = shift-add, free, one cycle each.
            //  erem < 0: ÷10 via divider.
        
            S_CONVERT: begin
                if ($signed(erem) > 8'sd0) begin
                    fixedX <= fixedX_x10;
                    erem   <= erem - 8'sd1;
                end else if ($signed(erem) < 8'sd0) begin
                    div_dividend <= {384'd0, fixedX};
                    div_divisor  <= 512'd10;
                    div_start    <= 1'b1;
                    erem         <= erem + 8'sd1;
                    state        <= S_CONV_DIVW;
                end else begin
                    state <= S_RR1;
                end
            end

            S_CONV_DIVW: begin
                if (div_done) begin
                    fixedX <= div_quotient[127:0];
                    state  <= S_CONVERT;
                end
            end

        
            //  Range reduction step 1: k = floor(fixedX / LN2_S)
           
            S_RR1: begin
                div_dividend <= {384'd0, fixedX};
                div_divisor  <= {448'd0, LN2_S};
                div_start    <= 1'b1;
                state        <= S_RR1_WAIT;
            end

            S_RR1_WAIT: begin
                if (div_done) begin
                    k_val <= div_quotient[15:0];
                    state <= S_RR2_MUL;
                end
            end

           
            //  Range reduction step 2: r_s = fixedX - k*LN2_S
            //  MUL k_val * LN2_S first.
           
            S_RR2_MUL: begin
                mul_multiplicand <= {496'd0, k_val};
                mul_multiplier   <= {448'd0, LN2_S};
                mul_start        <= 1'b1;
                state            <= S_RR2_MW;
            end

            S_RR2_MW: begin
                if (mul_done) begin
                    r_s      <= fixedX - mul_product[127:0];
                    cur_term <= {192'd0, SCALE};
                    accum    <= {192'd0, SCALE};
                    denom_r  <= SCALE;        // denom for n=0: SCALE*(0+1) = SCALE
                    n        <= 5'd0;
                    state    <= S_TAYLOR_MUL;
                end
            end

            //  Taylor series: NTERMS=28 iterations.
            //    term_{n+1} = term_n * r_s / denom_r
            //    denom_r starts at SCALE, increments by SCALE each iter
            //    so denom_r = SCALE*(n+1) without any multiply.
            //
            //  S_TAYLOR_MUL : issue MUL cur_term * r_s
            //  S_TAYLOR_MW  : wait MUL; pipe product straight into DIV
            //  S_TAYLOR_W   : wait DIV; latch new cur_term; accum; advance
            S_TAYLOR_MUL: begin
                if (n < NTERMS) begin
                    mul_multiplicand <= {256'd0, cur_term};
                    mul_multiplier   <= {384'd0, r_s};
                    mul_start        <= 1'b1;
                    state            <= S_TAYLOR_MW;
                end else begin
                    result <= {256'd0, accum};
                    rexp   <= -32'sd15;
                    kcnt   <= k_val;
                    state  <= S_POW2;
                end
            end

            // Pipe straight into divider the moment mul finishes
            S_TAYLOR_MW: begin
                if (mul_done) begin
                    div_dividend <= mul_product;
                    div_divisor  <= {448'd0, denom_r};
                    div_start    <= 1'b1;
                    state        <= S_TAYLOR_W;
                end
            end

            S_TAYLOR_W: begin
                if (div_done) begin
                    cur_term <= div_quotient[255:0];
                    accum    <= accum + div_quotient[255:0];
                    denom_r  <= denom_r + SCALE;   // advance: SCALE*(n+2)
                    n        <= n + 5'd1;
                    state    <= S_TAYLOR_MUL;
                end
            end

            //  e^x = e^r * 2^k : k left-shifts, one per cycle.
            S_POW2: begin
                if (kcnt > 16'd0) begin
                    result <= result << 1;
                    kcnt   <= kcnt - 16'd1;
                end else begin
                    state <= negInput ? S_INVERT : S_NORMALIZE;
                end
            end

            //  Negative input: e^(-|x|) = SCALE_SQ / result
            S_INVERT: begin
                div_dividend <= {384'd0, SCALE_SQ};
                div_divisor  <= result;
                div_start    <= 1'b1;
                state        <= S_INVERT_W;
            end

            S_INVERT_W: begin
                if (div_done) begin
                    result <= div_quotient;
                    state  <= S_NORMALIZE;
                end
            end

            //  Normalise into [M_MAX/10, M_MAX].
            //  ×10 via shift-add; ÷10 via divider.
            S_NORMALIZE: begin
                if (result > {478'd0, M_MAX}) begin
                    div_dividend <= result;
                    div_divisor  <= 512'd10;
                    div_start    <= 1'b1;
                    rexp         <= rexp + 32'sd1;
                    state        <= S_NORM_DIVW;
                end else if (result != 512'd0 &&
                             result < {478'd0, M_MAX_DIV10}) begin
                    result <= result_x10;
                    rexp   <= rexp - 32'sd1;
                end else begin
                    mantRes <= result[33:0];
                    expRes  <= rexp[6:0];
                    state   <= S_DONE;
                end
            end

            S_NORM_DIVW: begin
                if (div_done) begin
                    result <= div_quotient;
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