`timescale 1ns / 1ps

//  Computes  result = ln( mantA * 10^expA )
//
//  Every multiplication and every division is offloaded to
//  external seq_multiplier and seq_divider modules.
//
//  Algorithm:
//    1. f_s  = mantA * SCALE                          (MUL)
//    2. Binary range-reduce f_s into [SCALE,2*SCALE)  (shifts only)
//    3. u_s  = (f_s-SCALE)*SCALE / (f_s+SCALE)        (MUL, DIV)
//    4. u2_s = u_s*u_s / SCALE                        (MUL, DIV)
//    5. Artanh series  NTERMS=24:
//         cur_pow  = cur_pow * u2_s / SCALE           (MUL, DIV)
//         term     = cur_pow / (2n+1)                 (DIV)
//         sum     += term
//    6. p_ln2   = |p|    * LN2_S  (then apply sign)  (MUL)
//       ea_ln10 = |expA| * LN10_S (then apply sign)  (MUL)
//    7. result  = 2*sum + p_ln2 + ea_ln10             (shifts + adds)
//    8. Sign extraction, normalise.
//
//  result*10 in normalise = (result<<3)+(result<<1)   - zero cost.
//  2*n+1 denominator      = 8-bit addition            - zero cost.
module ln_core (
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
    localparam [63:0]  LN10_S      = 64'd2_302_585_092_994_046;
    localparam [33:0]  M_MAX       = 34'd17_179_869_183;
    localparam [33:0]  M_MAX_DIV10 = 34'd1_717_986_918;
    localparam integer NTERMS      = 24;

    
    //  State encoding  (5 bits for 26 states)
    
    localparam [4:0]
        S_IDLE       = 5'd0,
        S_INIT_MW    = 5'd1,   // wait MUL: mantA*SCALE -> f_s
        S_BINRED     = 5'd2,   // shift f_s into [SCALE, 2*SCALE)
        S_U_NUM_MUL  = 5'd3,   // MUL: (f_s-SCALE)*SCALE -> u_num
        S_U_NUM_MW   = 5'd4,   // wait
        S_U_DIV      = 5'd5,   // DIV: u_num / (f_s+SCALE) -> u_s
        S_U_DIV_W    = 5'd6,   // wait
        S_U2_MUL     = 5'd7,   // MUL: u_s*u_s -> u2_prod
        S_U2_MW      = 5'd8,   // wait; immediately issue DIV
        S_U2_DW      = 5'd9,   // wait DIV/SCALE -> u2_s; init series
        S_SER_MUL    = 5'd10,  // MUL: cur_pow*u2_s  [x NTERMS]
        S_SER_MW     = 5'd11,  // wait; immediately issue DIV/SCALE
        S_SER_D3W    = 5'd12,  // wait DIV/SCALE -> new cur_pow; issue DIV/(2n+1)
        S_SER_D4W    = 5'd13,  // wait DIV/(2n+1) -> term; accum; n++
        S_CMB_MUL1   = 5'd14,  // MUL: |p|*LN2_S
        S_CMB_MW1    = 5'd15,  // wait; apply sign of p
        S_CMB_MUL2   = 5'd16,  // MUL: |expA|*LN10_S
        S_CMB_MW2    = 5'd17,  // wait; apply sign of expA
        S_COMBINE    = 5'd18,  // result = 2*sum + p_ln2 + ea_ln10
        S_SIGN       = 5'd19,  // extract sign; abs
        S_NORMALIZE  = 5'd20,  // scale mantissa
        S_NORM_DW    = 5'd21,  // wait DIV/10
        S_DONE       = 5'd22;

    reg [4:0] state;

    
    //  Data registers
    
    reg [255:0]        f_s;
    reg [255:0]        u_num_r;
    reg [255:0]        u_s;
    reg [255:0]        u2_s;
    reg [255:0]        cur_pow;
    reg [255:0]        artanh_sum;
    reg signed [255:0] p_ln2;
    reg signed [255:0] ea_ln10;
    reg signed [255:0] result_s;
    reg signed [31:0]  rexp;
    reg signed [15:0]  p;
    reg signed [6:0]   expA_lat;
    reg [7:0]          n;

    reg  evalPrev;
    wire doEval = eval && !evalPrev;

    // 2*SCALE threshold (shift - no multiplier)
    wire [255:0] TWO_SCALE = {191'd0, SCALE, 1'b0};

    // result * 10 via shift-add (no multiplier)
    wire [255:0] result_x10 = (result_s[255:0] << 3) + (result_s[255:0] << 1);

    
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
            f_s              <= 256'd0;
            u_num_r          <= 256'd0;
            u_s              <= 256'd0;
            u2_s             <= 256'd0;
            cur_pow          <= 256'd0;
            artanh_sum       <= 256'd0;
            p_ln2            <= 256'sd0;
            ea_ln10          <= 256'sd0;
            result_s         <= 256'sd0;
            rexp             <= 32'sd0;
            p                <= 16'sd0;
            expA_lat         <= 7'sd0;
            n                <= 8'd0;
        end else begin
            evalPrev  <= eval;
            div_start <= 1'b0;
            mul_start <= 1'b0;

            case (state)

            // Launch first multiply immediately on eval 
            S_IDLE: begin
                done <= 1'b0;
                if (doEval) begin
                    p                <= 16'sd0;
                    expA_lat         <= expA;
                    mul_multiplicand <= {478'd0, mantA};
                    mul_multiplier   <= {448'd0, SCALE};
                    mul_start        <= 1'b1;
                    state            <= S_INIT_MW;
                end
            end

            S_INIT_MW: begin
                if (mul_done) begin
                    f_s   <= mul_product[255:0];
                    state <= S_BINRED;
                end
            end

            // Binary range-reduce: shift only, zero cost 
            S_BINRED: begin
                if (f_s >= {192'd0, TWO_SCALE}) begin
                    f_s <= f_s >> 1;
                    p   <= p + 16'sd1;
                end else if (f_s < {192'd0, SCALE} && f_s != 256'd0) begin
                    f_s <= f_s << 1;
                    p   <= p - 16'sd1;
                end else begin
                    state <= S_U_NUM_MUL;
                end
            end

            // u numerator = (f_s - SCALE) * SCALE 
            S_U_NUM_MUL: begin
                mul_multiplicand <= {256'd0, f_s - {192'd0, SCALE}};
                mul_multiplier   <= {448'd0, SCALE};
                mul_start        <= 1'b1;
                state            <= S_U_NUM_MW;
            end

            S_U_NUM_MW: begin
                if (mul_done) begin
                    u_num_r <= mul_product[255:0];
                    state   <= S_U_DIV;
                end
            end

            // u_s = u_num / (f_s + SCALE) 
            // denominator is a plain add - no multiply needed
            S_U_DIV: begin
                div_dividend <= {256'd0, u_num_r};
                div_divisor  <= {256'd0, f_s + {192'd0, SCALE}};
                div_start    <= 1'b1;
                state        <= S_U_DIV_W;
            end

            S_U_DIV_W: begin
                if (div_done) begin
                    u_s   <= div_quotient[255:0];
                    state <= S_U2_MUL;
                end
            end

            // u2_s = (u_s * u_s) / SCALE 
            S_U2_MUL: begin
                mul_multiplicand <= {256'd0, u_s};
                mul_multiplier   <= {256'd0, u_s};
                mul_start        <= 1'b1;
                state            <= S_U2_MW;
            end

            // Pipe straight into divider the moment mul finishes
            S_U2_MW: begin
                if (mul_done) begin
                    div_dividend <= mul_product;
                    div_divisor  <= {448'd0, SCALE};
                    div_start    <= 1'b1;
                    state        <= S_U2_DW;
                end
            end

            S_U2_DW: begin
                if (div_done) begin
                    u2_s       <= div_quotient[255:0];
                    cur_pow    <= u_s;     // term_0 = u^1 / 1 = u_s
                    artanh_sum <= u_s;
                    n          <= 8'd1;
                    state      <= S_SER_MUL;
                end
            end

            // Artanh series  n = 1..NTERMS-1 
            S_SER_MUL: begin
                if (n < NTERMS) begin
                    mul_multiplicand <= {256'd0, cur_pow};
                    mul_multiplier   <= {256'd0, u2_s};
                    mul_start        <= 1'b1;
                    state            <= S_SER_MW;
                end else begin
                    state <= S_CMB_MUL1;
                end
            end

            // Pipe straight into divider
            S_SER_MW: begin
                if (mul_done) begin
                    div_dividend <= mul_product;
                    div_divisor  <= {448'd0, SCALE};
                    div_start    <= 1'b1;
                    state        <= S_SER_D3W;
                end
            end

            // Wait for /SCALE; latch new cur_pow; immediately issue /(2n+1)
            S_SER_D3W: begin
                if (div_done) begin
                    cur_pow      <= div_quotient[255:0];
                    div_dividend <= {256'd0, div_quotient[255:0]};
                    div_divisor  <= {504'd0, (8'd2 * n + 8'd1)};
                    div_start    <= 1'b1;
                    state        <= S_SER_D4W;
                end
            end

            S_SER_D4W: begin
                if (div_done) begin
                    artanh_sum <= artanh_sum + div_quotient[255:0];
                    n          <= n + 8'd1;
                    state      <= S_SER_MUL;
                end
            end

            // p * LN2_S (unsigned magnitude, sign applied after) 
            S_CMB_MUL1: begin
                mul_multiplicand <= p[15] ? {496'd0, -p} : {496'd0, p};
                mul_multiplier   <= {448'd0, LN2_S};
                mul_start        <= 1'b1;
                state            <= S_CMB_MW1;
            end

            S_CMB_MW1: begin
                if (mul_done) begin
                    p_ln2 <= p[15] ? -$signed({256'd0, mul_product[255:0]})
                                   :  $signed({256'd0, mul_product[255:0]});
                    state <= S_CMB_MUL2;
                end
            end

            // expA * LN10_S 
            S_CMB_MUL2: begin
                mul_multiplicand <= expA_lat[6] ? {505'd0, -expA_lat}
                                                : {505'd0, expA_lat};
                mul_multiplier   <= {448'd0, LN10_S};
                mul_start        <= 1'b1;
                state            <= S_CMB_MW2;
            end

            S_CMB_MW2: begin
                if (mul_done) begin
                    ea_ln10 <= expA_lat[6] ? -$signed({256'd0, mul_product[255:0]})
                                           :  $signed({256'd0, mul_product[255:0]});
                    state   <= S_COMBINE;
                end
            end

            // Pure addition: no mul/div 
            S_COMBINE: begin
                result_s <= ($signed({256'd0, artanh_sum}) <<< 1)
                           + p_ln2
                           + ea_ln10;
                rexp  <= -32'sd15;
                state <= S_SIGN;
            end

            S_SIGN: begin
                if (result_s < 0) begin
                    signRes  <= 1'b1;
                    result_s <= -result_s;
                end else begin
                    signRes <= 1'b0;
                end
                state <= S_NORMALIZE;
            end

            // Normalise: x10 via shift-add, /10 via divider 
            S_NORMALIZE: begin
                if (result_s[255:0] > {222'd0, M_MAX}) begin
                    div_dividend <= {256'd0, result_s[255:0]};
                    div_divisor  <= 512'd10;
                    div_start    <= 1'b1;
                    rexp         <= rexp + 32'sd1;
                    state        <= S_NORM_DW;
                end else if (result_s != 0 &&
                             result_s[255:0] < {222'd0, M_MAX_DIV10}) begin
                    result_s <= $signed({256'd0, result_x10});
                    rexp     <= rexp - 32'sd1;
                end else begin
                    mantRes <= result_s[33:0];
                    expRes  <= rexp[6:0];
                    state   <= S_DONE;
                end
            end

            S_NORM_DW: begin
                if (div_done) begin
                    result_s <= $signed({256'd0, div_quotient[255:0]});
                    state    <= S_NORMALIZE;
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