`timescale 1ns / 1ps

module postEval #(
    parameter depth    = 10,
    parameter newWidth = 44
)(
    input wire clock,
    input wire reset,
    input wire conv,

    input wire [$clog2(depth+1)-1:0] postfixSize,
    input wire [newWidth-1:0] postfix [depth-1:0],

    output reg [newWidth-1:0] answer,
    output reg done
);

    typedef enum logic [2:0] {
        S_READ,
        S_OP_POP,
        S_LAUNCH,
        S_WAIT,
        S_DONE,
        S_IDLE
    } state_t;

    state_t state;

    // Stack & index registers
    reg [newWidth-1:0] stack [depth-1:0];

    reg [$clog2(depth+1)-1:0] pof = 0;
    reg [$clog2(depth+1)-1:0] stk = 0;

    wire validTok = (pof < postfixSize);
    wire isConst  = validTok && (postfix[pof][newWidth-1 : newWidth-2] == 2'b00);

    // {2'b00, sign[41], mantissa[40:7], exp[6:0]}
    reg [newWidth-1:0] op;

    reg signA, signB;
    reg [33:0] mantA, mantB;
    reg signed [6:0] expA, expB;

    wire binaryOpPop = ((
                          op[7:0] == 8'h2A || op[7:0] == 8'h2B ||
                          op[7:0] == 8'h2C || op[7:0] == 8'h2D ||
                          op[7:0] == 8'hF2 || op[7:0] == 8'hF3
                        ) && stk >= 2);

    wire unaryOpPop = ((
                         op[7:0] == 8'hF0 || op[7:0] == 8'hF1 ||
                         op[7:0] == 8'hF4 || op[7:0] == 8'hF5 ||
                         op[7:0] == 8'hF6
                       ) && stk >= 1);

    reg error = 0;

    // Shared seq_multiplier + seq_divider
    // 4-way mux: exp(F0), ln(F1), pow(F2), log(F3)
    // postEval FSM serialises ops so only one is ever active.

    // per-core wires driving INTO the shared bus
    wire        exp_mul_start;
    wire [511:0] exp_mul_multiplicand, exp_mul_multiplier;
    wire        exp_div_start;
    wire [511:0] exp_div_dividend, exp_div_divisor;

    wire        ln_mul_start;
    wire [511:0] ln_mul_multiplicand, ln_mul_multiplier;
    wire        ln_div_start;
    wire [511:0] ln_div_dividend, ln_div_divisor;

    // log_core only needs div (ln_core handles mul internally)
    wire        log_div_start;
    wire [511:0] log_div_dividend, log_div_divisor;

    // pow_core only needs mul (ln/exp handle their own div/mul internally)
    wire        pow_mul_start;
    wire [511:0] pow_mul_multiplicand, pow_mul_multiplier;

    // pow_core div (for normalisation)
    wire        pow_div_start;
    wire [511:0] pow_div_dividend, pow_div_divisor;

    // sin_core
    wire        sin_mul_start, sin_div_start;
    wire [511:0] sin_mul_multiplicand, sin_mul_multiplier;
    wire [511:0] sin_div_dividend, sin_div_divisor;

    // cos_core
    wire        cos_mul_start, cos_div_start;
    wire [511:0] cos_mul_multiplicand, cos_mul_multiplier;
    wire [511:0] cos_div_dividend, cos_div_divisor;

    // tan_core (needs div for sin/cos step AND mul for scaling)
    wire        tan_div_start;
    wire [511:0] tan_div_dividend, tan_div_divisor;
    wire        tan_mul_start;
    wire [511:0] tan_mul_multiplicand, tan_mul_multiplier;

    // shared bus regs (driven by mux below)
    reg        seq_mul_start;
    reg [511:0] seq_mul_multiplicand, seq_mul_multiplier;
    reg        seq_div_start;
    reg [511:0] seq_div_dividend, seq_div_divisor;

    // shared outputs from seq modules - read by all cores, no conflict
    wire        seq_mul_done;
    wire [511:0] seq_mul_product;
    wire        seq_div_done;
    wire [511:0] seq_div_quotient;

    // 4-way mux
    always @(*) begin
        case (op[7:0])
            8'hF0: begin   // exp active
                seq_mul_start        = exp_mul_start;
                seq_mul_multiplicand = exp_mul_multiplicand;
                seq_mul_multiplier   = exp_mul_multiplier;
                seq_div_start        = exp_div_start;
                seq_div_dividend     = exp_div_dividend;
                seq_div_divisor      = exp_div_divisor;
            end
            8'hF1: begin   // ln active
                seq_mul_start        = ln_mul_start;
                seq_mul_multiplicand = ln_mul_multiplicand;
                seq_mul_multiplier   = ln_mul_multiplier;
                seq_div_start        = ln_div_start;
                seq_div_dividend     = ln_div_dividend;
                seq_div_divisor      = ln_div_divisor;
            end
            8'hF3: begin   // log active
                           // log calls ln internally; while ln is running,
                           // ln's mul/div wires are active.
                           // when log itself does lnx/lny div, log_div wins.
                seq_mul_start        = ln_mul_start;
                seq_mul_multiplicand = ln_mul_multiplicand;
                seq_mul_multiplier   = ln_mul_multiplier;
                seq_div_start        = log_div_start | ln_div_start;
                seq_div_dividend     = log_div_start ? log_div_dividend : ln_div_dividend;
                seq_div_divisor      = log_div_start ? log_div_divisor  : ln_div_divisor;
            end
            8'hF2: begin   // pow active
                           // pow calls ln then exp internally.
                           // while ln runs: ln's wires active.
                           // pow's own mul (y*lnx) step: pow_mul wins.
                           // pow's own norm div step: pow_div wins.
                           // while exp runs: exp's wires active.
                seq_mul_start        = pow_mul_start | ln_mul_start | exp_mul_start;
                seq_mul_multiplicand = pow_mul_start ? pow_mul_multiplicand :
                                       ln_mul_start  ? ln_mul_multiplicand  :
                                                       exp_mul_multiplicand;
                seq_mul_multiplier   = pow_mul_start ? pow_mul_multiplier :
                                       ln_mul_start  ? ln_mul_multiplier  :
                                                       exp_mul_multiplier;
                seq_div_start        = pow_div_start | ln_div_start | exp_div_start;
                seq_div_dividend     = pow_div_start ? pow_div_dividend :
                                       exp_div_start ? exp_div_dividend :
                                                       ln_div_dividend;
                seq_div_divisor      = pow_div_start ? pow_div_divisor :
                                       exp_div_start ? exp_div_divisor  :
                                                       ln_div_divisor;
            end
            8'hF4: begin   // sin active
                seq_mul_start        = sin_mul_start;
                seq_mul_multiplicand = sin_mul_multiplicand;
                seq_mul_multiplier   = sin_mul_multiplier;
                seq_div_start        = sin_div_start;
                seq_div_dividend     = sin_div_dividend;
                seq_div_divisor      = sin_div_divisor;
            end
            8'hF5: begin   // cos active
                seq_mul_start        = cos_mul_start;
                seq_mul_multiplicand = cos_mul_multiplicand;
                seq_mul_multiplier   = cos_mul_multiplier;
                seq_div_start        = cos_div_start;
                seq_div_dividend     = cos_div_dividend;
                seq_div_divisor      = cos_div_divisor;
            end
            8'hF6: begin   // tan active
                           // tan calls sin then cos internally
                           // while sin runs: sin wires active
                           // while cos runs: cos wires active
                           // tan own mul (scaling) step: tan_mul wins
                           // tan own div step: tan_div wins
                seq_mul_start        = tan_mul_start | sin_mul_start | cos_mul_start;
                seq_mul_multiplicand = tan_mul_start ? tan_mul_multiplicand :
                                       sin_mul_start ? sin_mul_multiplicand :
                                                       cos_mul_multiplicand;
                seq_mul_multiplier   = tan_mul_start ? tan_mul_multiplier :
                                       sin_mul_start ? sin_mul_multiplier :
                                                       cos_mul_multiplier;
                seq_div_start        = tan_div_start | sin_div_start | cos_div_start;
                seq_div_dividend     = tan_div_start ? tan_div_dividend :
                                       sin_div_start ? sin_div_dividend :
                                                       cos_div_dividend;
                seq_div_divisor      = tan_div_start ? tan_div_divisor :
                                       sin_div_start ? sin_div_divisor :
                                                       cos_div_divisor;
            end
            default: begin
                seq_mul_start        = 1'b0;
                seq_mul_multiplicand = 512'd0;
                seq_mul_multiplier   = 512'd0;
                seq_div_start        = 1'b0;
                seq_div_dividend     = 512'd0;
                seq_div_divisor      = 512'd0;
            end
        endcase
    end

    seq_multiplier #(.WIDTH(512)) seqmul0 (
        .clock(clock), .reset(reset),
        .start(seq_mul_start),
        .done(seq_mul_done),
        .multiplicand(seq_mul_multiplicand),
        .multiplier(seq_mul_multiplier),
        .product(seq_mul_product)
    );

    seq_divider #(.WIDTH(512)) seqdiv0 (
        .clock(clock), .reset(reset),
        .start(seq_div_start),
        .done(seq_div_done),
        .dividend(seq_div_dividend),
        .divisor(seq_div_divisor),
        .quotient(seq_div_quotient),
        .remainder_out()
    );

    // ln_core eval/input mux
    // driven by: postEval directly (lnEval) OR log_core OR pow_core
    reg        lnEval;
    wire       lnDone;
    wire       lnSignRes;
    wire [33:0] lnMantRes;
    wire signed [6:0] lnExpRes;

    // log_core -> ln_core wires
    wire        log_ln_eval;
    wire        log_ln_signA;
    wire [33:0] log_ln_mantA;
    wire signed [6:0] log_ln_expA;

    // pow_core -> ln_core wires
    wire        pow_ln_eval;
    wire        pow_ln_signA;
    wire [33:0] pow_ln_mantA;
    wire signed [6:0] pow_ln_expA;

    wire ln_eval_in  = lnEval | log_ln_eval | pow_ln_eval;
    wire ln_signA_in = lnEval      ? signA        :
                       log_ln_eval ? log_ln_signA :
                                     pow_ln_signA;
    wire [33:0]       ln_mantA_in = lnEval      ? mantA        :
                                    log_ln_eval ? log_ln_mantA :
                                                  pow_ln_mantA;
    wire signed [6:0] ln_expA_in  = lnEval      ? expA         :
                                    log_ln_eval ? log_ln_expA  :
                                                  pow_ln_expA;

    ln_core ln0 (
        .clock(clock), .reset(reset),
        .eval(ln_eval_in),
        .done(lnDone),
        .signA(ln_signA_in), .mantA(ln_mantA_in), .expA(ln_expA_in),
        .signRes(lnSignRes), .mantRes(lnMantRes), .expRes(lnExpRes),
        .div_start(ln_div_start),
        .div_dividend(ln_div_dividend),
        .div_divisor(ln_div_divisor),
        .div_done(seq_div_done),
        .div_quotient(seq_div_quotient),
        .mul_start(ln_mul_start),
        .mul_multiplicand(ln_mul_multiplicand),
        .mul_multiplier(ln_mul_multiplier),
        .mul_done(seq_mul_done),
        .mul_product(seq_mul_product)
    );

    // exp_core eval/input mux
    // driven by: postEval directly (expEval) OR pow_core
    reg        expEval;
    wire       expDone;
    wire       expSignRes;
    wire [33:0] expMantRes;
    wire signed [6:0] expExpRes;

    // pow_core -> exp_core wires
    wire        pow_exp_eval;
    wire        pow_exp_signA;
    wire [33:0] pow_exp_mantA;
    wire signed [6:0] pow_exp_expA;

    wire exp_eval_in  = expEval | pow_exp_eval;
    wire exp_signA_in = expEval ? signA       : pow_exp_signA;
    wire [33:0]       exp_mantA_in = expEval ? mantA       : pow_exp_mantA;
    wire signed [6:0] exp_expA_in  = expEval ? expA        : pow_exp_expA;

    exp_core exp0 (
        .clock(clock), .reset(reset),
        .eval(exp_eval_in),
        .done(expDone),
        .signA(exp_signA_in), .mantA(exp_mantA_in), .expA(exp_expA_in),
        .signRes(expSignRes), .mantRes(expMantRes), .expRes(expExpRes),
        .div_start(exp_div_start),
        .div_dividend(exp_div_dividend),
        .div_divisor(exp_div_divisor),
        .div_done(seq_div_done),
        .div_quotient(seq_div_quotient),
        .mul_start(exp_mul_start),
        .mul_multiplicand(exp_mul_multiplicand),
        .mul_multiplier(exp_mul_multiplier),
        .mul_done(seq_mul_done),
        .mul_product(seq_mul_product)
    );

    // log_core
    reg        logEval;
    wire       logDone;
    wire       logSignRes;
    wire [33:0] logMantRes;
    wire signed [6:0] logExpRes;

    log_core log0 (
        .clock(clock), .reset(reset),
        .eval(logEval), .done(logDone),
        .signA(signA), .mantA(mantA), .expA(expA),
        .signB(signB), .mantB(mantB), .expB(expB),
        .signRes(logSignRes), .mantRes(logMantRes), .expRes(logExpRes),
        .ln_eval(log_ln_eval),
        .ln_signA(log_ln_signA), .ln_mantA(log_ln_mantA), .ln_expA(log_ln_expA),
        .ln_done(lnDone),
        .ln_signRes(lnSignRes), .ln_mantRes(lnMantRes), .ln_expRes(lnExpRes),
        .div_start(log_div_start),
        .div_dividend(log_div_dividend),
        .div_divisor(log_div_divisor),
        .div_done(seq_div_done),
        .div_quotient(seq_div_quotient)
    );

    // pow_core
    reg        powEval;
    wire       powDone;
    wire       powSignRes;
    wire [33:0] powMantRes;
    wire signed [6:0] powExpRes;

    pow_core pow0 (
        .clock(clock), .reset(reset),
        .eval(powEval), .done(powDone),
        .signA(signA), .mantA(mantA), .expA(expA),
        .signB(signB), .mantB(mantB), .expB(expB),
        .signRes(powSignRes), .mantRes(powMantRes), .expRes(powExpRes),
        .ln_eval(pow_ln_eval),
        .ln_signA(pow_ln_signA), .ln_mantA(pow_ln_mantA), .ln_expA(pow_ln_expA),
        .ln_done(lnDone),
        .ln_signRes(lnSignRes), .ln_mantRes(lnMantRes), .ln_expRes(lnExpRes),
        .exp_eval(pow_exp_eval),
        .exp_signA(pow_exp_signA), .exp_mantA(pow_exp_mantA), .exp_expA(pow_exp_expA),
        .exp_done(expDone),
        .exp_signRes(expSignRes), .exp_mantRes(expMantRes), .exp_expRes(expExpRes),
        .mul_start(pow_mul_start),
        .mul_multiplicand(pow_mul_multiplicand),
        .mul_multiplier(pow_mul_multiplier),
        .mul_done(seq_mul_done),
        .mul_product(seq_mul_product),
        .div_start(pow_div_start),
        .div_dividend(pow_div_dividend),
        .div_divisor(pow_div_divisor),
        .div_done(seq_div_done),
        .div_quotient(seq_div_quotient)
    );

    // adder
    reg        addEval;
    wire       addDone;
    wire       addSignRes;
    wire [33:0] addMantRes;
    wire signed [6:0] addExpRes;

    adder add0 (
        .clock(clock), .reset(reset),
        .eval(addEval), .done(addDone),
        .signA(signA), .mantA(mantA), .expA(expA),
        .signB(signB), .mantB(mantB), .expB(expB),
        .signRes(addSignRes), .mantRes(addMantRes), .expRes(addExpRes)
    );

    // multiplier
    reg        mulEval;
    wire       mulDone;
    wire       mulSignRes;
    wire [33:0] mulMantRes;
    wire signed [6:0] mulExpRes;

    multiplier mul0 (
        .clock(clock), .reset(reset),
        .eval(mulEval), .done(mulDone),
        .signA(signA), .mantA(mantA), .expA(expA),
        .signB(signB), .mantB(mantB), .expB(expB),
        .signRes(mulSignRes), .mantRes(mulMantRes), .expRes(mulExpRes)
    );

    // divider
    reg        divEval;
    wire       divDone;
    wire       divSignRes;
    wire [33:0] divMantRes;
    wire signed [6:0] divExpRes;

    divider div0 (
        .clock(clock), .reset(reset),
        .eval(divEval), .done(divDone),
        .signA(signA), .mantA(mantA), .expA(expA),
        .signB(signB), .mantB(mantB), .expB(expB),
        .signRes(divSignRes), .mantRes(divMantRes), .expRes(divExpRes)
    );

    // sin_core
    reg        sinEval;
    wire       sinDone;
    wire       sinSignRes;
    wire [33:0] sinMantRes;
    wire signed [6:0] sinExpRes;

    // tan_core -> sin_core wires
    wire        tan_sin_eval;
    wire        tan_sin_signA;
    wire [33:0] tan_sin_mantA;
    wire signed [6:0] tan_sin_expA;

    wire sin_eval_in  = sinEval | tan_sin_eval;
    wire sin_signA_in = sinEval ? signA       : tan_sin_signA;
    wire [33:0]       sin_mantA_in = sinEval ? mantA       : tan_sin_mantA;
    wire signed [6:0] sin_expA_in  = sinEval ? expA        : tan_sin_expA;

    sin_core sin0 (
        .clock(clock), .reset(reset),
        .eval(sin_eval_in), .done(sinDone),
        .signA(sin_signA_in), .mantA(sin_mantA_in), .expA(sin_expA_in),
        .signRes(sinSignRes), .mantRes(sinMantRes), .expRes(sinExpRes),
        .div_start(sin_div_start),
        .div_dividend(sin_div_dividend),
        .div_divisor(sin_div_divisor),
        .div_done(seq_div_done),
        .div_quotient(seq_div_quotient),
        .mul_start(sin_mul_start),
        .mul_multiplicand(sin_mul_multiplicand),
        .mul_multiplier(sin_mul_multiplier),
        .mul_done(seq_mul_done),
        .mul_product(seq_mul_product)
    );

    // cos_core
    reg        cosEval;
    wire       cosDone;
    wire       cosSignRes;
    wire [33:0] cosMantRes;
    wire signed [6:0] cosExpRes;

    // tan_core -> cos_core wires
    wire        tan_cos_eval;
    wire        tan_cos_signA;
    wire [33:0] tan_cos_mantA;
    wire signed [6:0] tan_cos_expA;

    wire cos_eval_in  = cosEval | tan_cos_eval;
    wire cos_signA_in = cosEval ? signA       : tan_cos_signA;
    wire [33:0]       cos_mantA_in = cosEval ? mantA       : tan_cos_mantA;
    wire signed [6:0] cos_expA_in  = cosEval ? expA        : tan_cos_expA;

    cos_core cos0 (
        .clock(clock), .reset(reset),
        .eval(cos_eval_in), .done(cosDone),
        .signA(cos_signA_in), .mantA(cos_mantA_in), .expA(cos_expA_in),
        .signRes(cosSignRes), .mantRes(cosMantRes), .expRes(cosExpRes),
        .div_start(cos_div_start),
        .div_dividend(cos_div_dividend),
        .div_divisor(cos_div_divisor),
        .div_done(seq_div_done),
        .div_quotient(seq_div_quotient),
        .mul_start(cos_mul_start),
        .mul_multiplicand(cos_mul_multiplicand),
        .mul_multiplier(cos_mul_multiplier),
        .mul_done(seq_mul_done),
        .mul_product(seq_mul_product)
    );

    // tan_core
    reg        tanEval;
    wire       tanDone;
    wire       tanSignRes;
    wire [33:0] tanMantRes;
    wire signed [6:0] tanExpRes;

    tan_core tan0 (
        .clock(clock), .reset(reset),
        .eval(tanEval), .done(tanDone),
        .signA(signA), .mantA(mantA), .expA(expA),
        .signRes(tanSignRes), .mantRes(tanMantRes), .expRes(tanExpRes),
        .sin_eval(tan_sin_eval),
        .sin_signA(tan_sin_signA), .sin_mantA(tan_sin_mantA), .sin_expA(tan_sin_expA),
        .sin_done(sinDone),
        .sin_signRes(sinSignRes), .sin_mantRes(sinMantRes), .sin_expRes(sinExpRes),
        .cos_eval(tan_cos_eval),
        .cos_signA(tan_cos_signA), .cos_mantA(tan_cos_mantA), .cos_expA(tan_cos_expA),
        .cos_done(cosDone),
        .cos_signRes(cosSignRes), .cos_mantRes(cosMantRes), .cos_expRes(cosExpRes),
        .div_start(tan_div_start),
        .div_dividend(tan_div_dividend),
        .div_divisor(tan_div_divisor),
        .div_done(seq_div_done),
        .div_quotient(seq_div_quotient),
        .mul_start(tan_mul_start),
        .mul_multiplicand(tan_mul_multiplicand),
        .mul_multiplier(tan_mul_multiplier),
        .mul_done(seq_mul_done),
        .mul_product(seq_mul_product)
    );

    // Result mux - keyed by op, prevents wrong-module capture
    logic moduleDone;
    logic signRes;
    logic [33:0] mantRes;
    logic signed [6:0] expRes;

    always_comb begin
        moduleDone = 1'b0;
        signRes    = 1'b0;
        mantRes    = '0;
        expRes     = '0;

        unique case (op[7:0])
            8'h2A: begin moduleDone=addDone; signRes=addSignRes; mantRes=addMantRes; expRes=addExpRes; end
            8'h2B: begin moduleDone=addDone; signRes=addSignRes; mantRes=addMantRes; expRes=addExpRes; end
            8'h2C: begin moduleDone=mulDone; signRes=mulSignRes; mantRes=mulMantRes; expRes=mulExpRes; end
            8'h2D: begin moduleDone=divDone; signRes=divSignRes; mantRes=divMantRes; expRes=divExpRes; end
            8'hF2: begin moduleDone=powDone; signRes=powSignRes; mantRes=powMantRes; expRes=powExpRes; end
            8'hF3: begin moduleDone=logDone; signRes=logSignRes; mantRes=logMantRes; expRes=logExpRes; end
            8'hF0: begin moduleDone=expDone; signRes=expSignRes; mantRes=expMantRes; expRes=expExpRes; end
            8'hF1: begin moduleDone=lnDone;  signRes=lnSignRes;  mantRes=lnMantRes;  expRes=lnExpRes;  end
            8'hF4: begin moduleDone=sinDone; signRes=sinSignRes; mantRes=sinMantRes; expRes=sinExpRes; end
            8'hF5: begin moduleDone=cosDone; signRes=cosSignRes; mantRes=cosMantRes; expRes=cosExpRes; end
            8'hF6: begin moduleDone=tanDone; signRes=tanSignRes; mantRes=tanMantRes; expRes=tanExpRes; end
            default: begin end
        endcase
    end

    // Main FSM
    reg  convPrevState = 0;
    wire doConv = conv && !convPrevState;
    integer k;

    always @(posedge clock or posedge reset) begin

        done <= 0;

        if (reset) begin
            state <= S_IDLE;
            stk   <= 0;
            pof   <= 0;
            done  <= 0;
            convPrevState <= 1'b0;

            for (k = 0; k < depth; k = k + 1)
                stack[k] <= 0;

            op    <= 0;
            signA <= 0; signB <= 0;
            mantA <= 0; mantB <= 0;
            expA  <= 0; expB  <= 0;

            addEval <= 0; mulEval <= 0; divEval <= 0;
            powEval <= 0; logEval <= 0;
            expEval <= 0; lnEval  <= 0;
            sinEval <= 0; cosEval <= 0; tanEval <= 0;
            error   <= 0;
        end
        else begin

            // default: de-assert all eval pulses every cycle
            addEval <= 1'b0; mulEval <= 1'b0; divEval <= 1'b0;
            powEval <= 1'b0; logEval <= 1'b0;
            expEval <= 1'b0; lnEval  <= 1'b0;
            sinEval <= 1'b0; cosEval <= 1'b0; tanEval <= 1'b0;

            case (state)

                S_READ: begin
                    if (pof < postfixSize) begin
                        if (isConst) begin
                            stack[stk] <= postfix[pof];
                            stk <= stk + 1;
                            pof <= pof + 1;
                        end
                        else begin
                            op    <= postfix[pof];
                            pof   <= pof + 1;
                            state <= S_OP_POP;
                        end
                    end
                    else begin
                        state <= S_DONE;
                    end
                end

                S_OP_POP: begin
                    if (binaryOpPop) begin
                        // for subtraction, negate A (top of stack)
                        if (op[7:0] == 8'h2B)
                            signA <= ~stack[stk-1][41];
                        else
                            signA <= stack[stk-1][41];

                        mantA <= stack[stk-1][40:7];
                        expA  <= stack[stk-1][6:0];

                        signB <= stack[stk-2][41];
                        mantB <= stack[stk-2][40:7];
                        expB  <= stack[stk-2][6:0];

                        stk   <= stk - 2;
                        state <= S_LAUNCH;
                    end
                    else if (unaryOpPop) begin
                        signA <= stack[stk-1][41];
                        mantA <= stack[stk-1][40:7];
                        expA  <= stack[stk-1][6:0];
                        stk   <= stk - 1;
                        state <= S_LAUNCH;
                    end
                    else begin
                        state <= S_IDLE;
                    end
                end

                S_LAUNCH: begin
                    error <= 0;
                    $display("S_LAUNCH: op[7:0]=%0h", op[7:0]);

                    if      (op[7:0] == 8'h2A || op[7:0] == 8'h2B) begin addEval <= 1; $display("  -> addEval"); end
                    else if (op[7:0] == 8'h2C) begin mulEval <= 1; $display("  -> mulEval"); end
                    else if (op[7:0] == 8'h2D) begin divEval <= 1; $display("  -> divEval"); end
                    else if (op[7:0] == 8'hF2) begin powEval <= 1; $display("  -> powEval"); end
                    else if (op[7:0] == 8'hF3) begin logEval <= 1; $display("  -> logEval"); end
                    else if (op[7:0] == 8'hF0) begin expEval <= 1; $display("  -> expEval"); end
                    else if (op[7:0] == 8'hF1) begin lnEval  <= 1; $display("  -> lnEval");  end
                    else if (op[7:0] == 8'hF4) begin sinEval <= 1; $display("  -> sinEval"); end
                    else if (op[7:0] == 8'hF5) begin cosEval <= 1; $display("  -> cosEval"); end
                    else if (op[7:0] == 8'hF6) begin tanEval <= 1; $display("  -> tanEval"); end
                    else begin error <= 1; $display("  -> ERROR unknown op"); end

                    state <= S_WAIT;
                end

                S_WAIT: begin
                    if (error) state <= S_IDLE;
                    else if (moduleDone) begin
                        stack[stk] <= {2'b00, signRes, mantRes, expRes};
                        stk   <= stk + 1;
                        state <= S_READ;
                    end
                end

                S_DONE: begin
                    answer <= stack[stk-1];
                    done   <= 1;
                    state  <= S_IDLE;
                end

                S_IDLE: begin
                    done  <= 0;
                    error <= 0;
                    if (doConv) begin
                        error <= 0;
                        stk   <= 0;
                        pof   <= 0;
                        state <= S_READ;
                    end
                end

            endcase

            convPrevState <= conv;
        end
    end

endmodule