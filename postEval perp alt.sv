`timescale 1ns / 1ps


module postEval #(
    parameter depth = 10,
    parameter newWidth = 44 
)(
    input wire clock,
    input wire reset,
    input wire conv,

    input wire [$clog2(depth+1)-1:0] postfixSize,
    input wire [newWidth-1:0] postfix [depth-1:0],

    output reg [newWidth-1:0] answer,

    output reg done //pulse

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


    // Registers & Wires
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    // stack like ds
    reg [newWidth-1 : 0] stack [depth-1 : 0];
    
    reg [$clog2(depth+1)-1:0] pof = 0; // for postfix mem
    reg [$clog2(depth+1)-1:0] stk = 0; // for stack mem



    wire validTok = (pof < postfixSize);
    wire isConst = validTok && (postfix[pof][newWidth-1 : newWidth-2] == 2'b00);


    // {2'b00, sign, mantissa, exp};
    // [43 : 42]: misc, lite
    // [41] : sign
    // [40 : 7] : mantissa
    // [6 : 0] : exponent

    reg [newWidth-1:0] op;

    reg signA, signB = 0;
    reg [33:0] mantA, mantB = 0;
    reg signed [6:0] expA, expB = 0;

    wire binaryOpPop = ((   // + - * /
                            op[7:0] == 8'h2A ||
                            op[7:0] == 8'h2B ||
                            op[7:0] == 8'h2C ||
                            op[7:0] == 8'h2D ||

                            // pow(x,a) & log(x,a)
                            op[7:0] == 8'hF2 ||
                            op[7:0] == 8'hF3
                        
                            ) && stk >= 2);

    wire unaryOpPop = ((    // e^x & ln(x)
                            op[7:0] == 8'hF0 ||
                            op[7:0] == 8'hF1 ||

                            //trig funcs
                            op[7:0] == 8'hF4 ||
                            op[7:0] == 8'hF5 ||
                            op[7:0] == 8'hF6
                        
                            ) && stk >= 1);

    reg error = 0;
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    
    // Function Modules
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // ---------- ADD ----------
    reg addEval;
    wire addDone;
    wire addSignRes;
    wire [33:0] addMantRes;
    wire signed [6:0] addExpRes;
    adder add0 (
        .clock(clock),
        .reset(reset),

        .eval(addEval),
        .done(addDone),
        .signA(signA),
        .mantA(mantA),
        .expA(expA),
        .signB(signB),
        .mantB(mantB),
        .expB(expB),
        .signRes(addSignRes),
        .mantRes(addMantRes),
        .expRes(addExpRes)
    );

    // ---------- SUB ----------
    reg subEval;
    wire subDone;
    wire subSignRes;
    wire [33:0] subMantRes;
    wire signed [6:0] subExpRes;
    adder add1 (

        .clock(clock),
        .reset(reset),
        
        .eval(subEval),
        .done(subDone),
        .signA(~signA),
        .mantA(mantA),
        .expA(expA),
        .signB(signB),
        .mantB(mantB),
        .expB(expB),
        .signRes(subSignRes),
        .mantRes(subMantRes),
        .expRes(subExpRes)
    );

    // ---------- MUL ----------
    reg mulEval;
    wire mulDone;
    wire mulSignRes;
    wire [33:0] mulMantRes;
    wire signed [6:0] mulExpRes;
    // multiplier mul0 (

    //     .clock(clock),
    //     .reset(reset),

    //     .eval(mulEval),
    //     .done(mulDone),
    //     .signA(signA),
    //     .mantA(mantA),
    //     .expA(expA),
    //     .signB(signB),
    //     .mantB(mantB),
    //     .expB(expB),
    //     .signRes(mulSignRes),
    //     .mantRes(mulMantRes),
    //     .expRes(mulExpRes)
    // );

    // ---------- DIV ----------
    reg divEval;
    wire divDone;
    wire divSignRes;
    wire [33:0] divMantRes;
    wire signed [6:0] divExpRes;
    // divider div0 (

    //     .clock(clock),
    //     .reset(reset),

    //     .eval(divEval),
    //     .done(divDone),
    //     .signA(signA),
    //     .mantA(mantA),
    //     .expA(expA),
    //     .signB(signB),
    //     .mantB(mantB),
    //     .expB(expB),
    //     .signRes(divSignRes),
    //     .mantRes(divMantRes),
    //     .expRes(divExpRes)
    // );

    // ---------- POW ----------
    reg powEval;
    wire powDone;
    wire powSignRes;
    wire [33:0] powMantRes;
    wire signed [6:0] powExpRes;
    // power pow0 (

    //     .clock(clock),
    //     .reset(reset),

    //     .eval(powEval),
    //     .done(powDone),
    //     .signA(signA),
    //     .mantA(mantA),
    //     .expA(expA),
    //     .signB(signB),
    //     .mantB(mantB),
    //     .expB(expB),
    //     .signRes(powSignRes),
    //     .mantRes(powMantRes),
    //     .expRes(powExpRes)
    // );

    // ---------- LOG ----------
    reg logEval;
    wire logDone;
    wire logSignRes;
    wire [33:0] logMantRes;
    wire signed [6:0] logExpRes;
    // logarithm log0 (

    //     .clock(clock),
    //     .reset(reset),

    //     .eval(logEval),
    //     .done(logDone),
    //     .signA(signA),
    //     .mantA(mantA),
    //     .expA(expA),
    //     .signB(signB),
    //     .mantB(mantB),
    //     .expB(expB),
    //     .signRes(logSignRes),
    //     .mantRes(logMantRes),
    //     .expRes(logExpRes)
    // );

    // ---------- EXP ----------
    reg expEval;
    wire expDone;
    wire expSignRes;
    wire [33:0] expMantRes;
    wire signed [6:0] expExpRes;
    // exponential exp0 (

    //     .clock(clock),
    //     .reset(reset),

    //     .eval(expEval),
    //     .done(expDone),
    //     .signA(signA),
    //     .mantA(mantA),
    //     .expA(expA),
    //     .signRes(expSignRes),
    //     .mantRes(expMantRes),
    //     .expRes(expExpRes)
    // );

    // ---------- LN ----------
    reg lnEval;
    wire lnDone;
    wire lnSignRes;
    wire [33:0] lnMantRes;
    wire signed [6:0] lnExpRes;
    // naturalLog ln0 (

    //     .clock(clock),
    //     .reset(reset),

    //     .eval(lnEval),
    //     .done(lnDone),
    //     .signA(signA),
    //     .mantA(mantA),
    //     .expA(expA),
    //     .signRes(lnSignRes),
    //     .mantRes(lnMantRes),
    //     .expRes(lnExpRes)
    // );

    // ---------- SIN ----------
    reg sinEval;
    wire sinDone;
    wire sinSignRes;
    wire [33:0] sinMantRes;
    wire signed [6:0] sinExpRes;
    // sine sin0 (

    //     .clock(clock),
    //     .reset(reset),

    //     .eval(sinEval),
    //     .done(sinDone),
    //     .signA(signA),
    //     .mantA(mantA),
    //     .expA(expA),
    //     .signRes(sinSignRes),
    //     .mantRes(sinMantRes),
    //     .expRes(sinExpRes)
    // );

    // ---------- COS ----------
    reg cosEval;
    wire cosDone;
    wire cosSignRes;
    wire [33:0] cosMantRes;
    wire signed [6:0] cosExpRes;
    // cosine cos0 (

    //     .clock(clock),
    //     .reset(reset),
        
    //     .eval(cosEval),
    //     .done(cosDone),
    //     .signA(signA),
    //     .mantA(mantA),
    //     .expA(expA),
    //     .signRes(cosSignRes),
    //     .mantRes(cosMantRes),
    //     .expRes(cosExpRes)
    // );

    // ---------- TAN ----------
    reg tanEval;
    wire tanDone;
    wire tanSignRes;
    wire [33:0] tanMantRes;
    wire signed [6:0] tanExpRes;

    // tangent tan0 (

    //     .clock(clock),
    //     .reset(reset),

    //     .eval(tanEval),
    //     .done(tanDone),
    //     .signA(signA),
    //     .mantA(mantA),
    //     .expA(expA),
    //     .signRes(tanSignRes),
    //     .mantRes(tanMantRes),
    //     .expRes(tanExpRes)
    // );

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

    // Done signal & Result registers Interfacing
///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
    //perp's suggestion
    // Selected result + done, keyed ONLY by op (prevents wrong-module capture)
    logic moduleDone;
    logic signRes;
    logic [33:0] mantRes;
    logic signed [6:0] expRes;

    always_comb begin
    // defaults prevent inferred latches
    moduleDone = 1'b0;
    signRes    = 1'b0;
    mantRes    = '0;
    expRes     = '0;

    unique case (op[7:0])
        8'h2A: begin moduleDone=addDone; signRes=addSignRes; mantRes=addMantRes; expRes=addExpRes; end
        8'h2B: begin moduleDone=subDone; signRes=subSignRes; mantRes=subMantRes; expRes=subExpRes; end
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

///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



    reg convPrevState = 0;
    wire doConv = conv && !convPrevState;
    integer k;


    always @(posedge clock or posedge reset) begin

        done <= 0; //just for safety
        if (reset) begin

            state <= S_IDLE;

            stk <= 0;
            pof <= 0;

            done <= 0;
            convPrevState <= 1'b0;

            for (k = 0; k < depth; k = k + 1) begin
                stack[k] <= 0;
            end

            op <= 0;

            signA <= 0;
            signB <= 0;
            mantA <= 0;
            mantB <= 0;
            expA <= 0;
            expB <= 0;

            addEval <= 0;
            subEval <= 0;
            mulEval <= 0;
            divEval <= 0;
            powEval <= 0;
            logEval <= 0;

            expEval <= 0;
            lnEval <= 0;
            sinEval <= 0;
            cosEval <= 0;
            tanEval <= 0;

            error <= 0;

            
        end

        else begin

        //resetting eval pins
            addEval <= 1'b0;
            subEval <= 1'b0;
            mulEval <= 1'b0;
            divEval <= 1'b0;
            powEval <= 1'b0;
            logEval <= 1'b0;

            expEval <= 1'b0;
            lnEval <= 1'b0;
            sinEval <= 1'b0;
            cosEval <= 1'b0;
            tanEval <= 1'b0;
        //

            case (state)

                S_READ: begin
                    if(pof < postfixSize) begin //infix top is incremented at the end of the loop

                        if (isConst) begin
                            stack[stk] <= postfix[pof];

                            stk <= stk + 1;
                            pof <= pof + 1;
                        end
                        
                        else begin

                            op <= postfix[pof]; //storing the operator in reg
                            pof <= pof + 1;

                            state <= S_OP_POP;
                            
                        end

                    end
                    else begin //pof >= postfixSize : Conversion is done 
                        state <= S_DONE;
                    end

                end




                S_OP_POP: begin
                    if(binaryOpPop) begin // +

                        signA <= stack[stk-1][41]; 
                        mantA <= stack[stk-1][40 : 7]; 
                        expA <= stack[stk-1][6 : 0];

                        signB <= stack[stk-2][41]; 
                        mantB <= stack[stk-2][40 : 7]; 
                        expB <= stack[stk-2][6 : 0];

                        stk <= stk - 2;     
                        
                        state <= S_LAUNCH;
                    end

                    else if(unaryOpPop) begin // +

                        signA <= stack[stk-1][41]; 
                        mantA <= stack[stk-1][40 : 7]; 
                        expA <= stack[stk-1][6 : 0];

                        stk <= stk - 1; 
                        
                        state <= S_LAUNCH;
                    end

                    else begin
                        state <= S_IDLE; // or error state
                    end

                end





                S_LAUNCH: begin

                    error <= 0;
                    // + - * /
                    if(op[7:0] == 8'h2A) addEval <= 1;
                    else if(op[7:0] == 8'h2B) subEval <= 1;
                    else if(op[7:0] == 8'h2C) mulEval <= 1;
                    else if(op[7:0] == 8'h2D) divEval <= 1;
                    
                    // pow log
                    else if(op[7:0] == 8'hF2) powEval <= 1;
                    else if(op[7:0] == 8'hF3) logEval <= 1;

                    // exp ln
                    else if(op[7:0] == 8'hF0) expEval <= 1;
                    else if(op[7:0] == 8'hF1) lnEval <= 1;

                    // trig
                    else if(op[7:0] == 8'hF4) sinEval <= 1;
                    else if(op[7:0] == 8'hF5) cosEval <= 1;
                    else if(op[7:0] == 8'hF6) tanEval <= 1;
                    
                    // failure:
                    else error <= 1;

                    state <= S_WAIT;
                    

                end


                S_WAIT: begin

                    if(error) state <= S_IDLE;

                    else if(moduleDone) begin
                        stack[stk] <= {2'b00, signRes, mantRes, expRes};
                        stk <= stk + 1;
                        state <= S_READ;
                    end

                    
                end

                S_DONE: begin
                    
                    answer <= stack[stk-1];
                    done  <= 1;    
                    state <= S_IDLE;   
                    
                end
          
                //added this module so that i can actually get a pulse
                S_IDLE: begin
                    done <= 0;
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