`timescale 1ns / 1ps


module adder(
    input eval,
    output reg done,

    input signA, signB,
    input [33:0] mantA, mantB,
    input signed [6:0] expA, expB,

    output reg signRes
    output reg [33:0] mantReg,
    output reg [6:0] expRes
);



    // using the state system insteaod of the fragile RBpop, commaPOP registers
    typedef enum logic [2:0] {
        S_READ,     
        S_OP_POP,

        S_WAIT,

        S_DONE,
        S_IDLE
    } state_t;

    state_t state;




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




// ---------- ADD ----------
    reg addEval;
    wire addDone;
    wire addSignRes;
    wire [33:0] addMantRes;
    wire signed [6:0] addExpRes;
    adder add0 (
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
    subber sub0 (
        .eval(subEval),
        .done(subDone),
        .signA(signA),
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
    multiplier mul0 (
        .eval(mulEval),
        .done(mulDone),
        .signA(signA),
        .mantA(mantA),
        .expA(expA),
        .signB(signB),
        .mantB(mantB),
        .expB(expB),
        .signRes(mulSignRes),
        .mantRes(mulMantRes),
        .expRes(mulExpRes)
    );

    // ---------- DIV ----------
    reg divEval;
    wire divDone;
    wire divSignRes;
    wire [33:0] divMantRes;
    wire signed [6:0] divExpRes;
    divider div0 (
        .eval(divEval),
        .done(divDone),
        .signA(signA),
        .mantA(mantA),
        .expA(expA),
        .signB(signB),
        .mantB(mantB),
        .expB(expB),
        .signRes(divSignRes),
        .mantRes(divMantRes),
        .expRes(divExpRes)
    );

    // ---------- POW ----------
    reg powEval;
    wire powDone;
    wire powSignRes;
    wire [33:0] powMantRes;
    wire signed [6:0] powExpRes;
    power pow0 (
        .eval(powEval),
        .done(powDone),
        .signA(signA),
        .mantA(mantA),
        .expA(expA),
        .signB(signB),
        .mantB(mantB),
        .expB(expB),
        .signRes(powSignRes),
        .mantRes(powMantRes),
        .expRes(powExpRes)
    );

    // ---------- LOG ----------
    reg logEval;
    wire logDone;
    wire logSignRes;
    wire [33:0] logMantRes;
    wire signed [6:0] logExpRes;
    logarithm log0 (
        .eval(logEval),
        .done(logDone),
        .signA(signA),
        .mantA(mantA),
        .expA(expA),
        .signB(signB),
        .mantB(mantB),
        .expB(expB),
        .signRes(logSignRes),
        .mantRes(logMantRes),
        .expRes(logExpRes)
    );

    // ---------- EXP ----------
    reg expEval;
    wire expDone;
    wire expSignRes;
    wire [33:0] expMantRes;
    wire signed [6:0] expExpRes;
    exponential exp0 (
        .eval(expEval),
        .done(expDone),
        .signA(signA),
        .mantA(mantA),
        .expA(expA),
        .signRes(expSignRes),
        .mantRes(expMantRes),
        .expRes(expExpRes)
    );

    // ---------- LN ----------
    reg lnEval;
    wire lnDone;
    wire lnSignRes;
    wire [33:0] lnMantRes;
    wire signed [6:0] lnExpRes;
    naturalLog ln0 (
        .eval(lnEval),
        .done(lnDone),
        .signA(signA),
        .mantA(mantA),
        .expA(expA),
        .signRes(lnSignRes),
        .mantRes(lnMantRes),
        .expRes(lnExpRes)
    );

    // ---------- SIN ----------
    reg sinEval;
    wire sinDone;
    wire sinSignRes;
    wire [33:0] sinMantRes;
    wire signed [6:0] sinExpRes;
    sine sin0 (
        .eval(sinEval),
        .done(sinDone),
        .signA(signA),
        .mantA(mantA),
        .expA(expA),
        .signRes(sinSignRes),
        .mantRes(sinMantRes),
        .expRes(sinExpRes)
    );

    // ---------- COS ----------
    reg cosEval;
    wire cosDone;
    wire cosSignRes;
    wire [33:0] cosMantRes;
    wire signed [6:0] cosExpRes;
    cosine cos0 (
        .eval(cosEval),
        .done(cosDone),
        .signA(signA),
        .mantA(mantA),
        .expA(expA),
        .signRes(cosSignRes),
        .mantRes(cosMantRes),
        .expRes(cosExpRes)
    );

    // ---------- TAN ----------
    reg tanEval;
    wire tanDone;
    wire tanSignRes;
    wire [33:0] tanMantRes;
    wire signed [6:0] tanExpRes;
    tangent tan0 (
        .eval(tanEval),
        .done(tanDone),
        .signA(signA),
        .mantA(mantA),
        .expA(expA),
        .signRes(tanSignRes),
        .mantRes(tanMantRes),
        .expRes(tanExpRes)
    );

    //more to be added

    wire signRes;
    wire [33:0] mantRes;
    wire signed [6:0] expRes;

    assign {signRes, mantRes, expRes} =
        addDone ? {addSignRes, addMantRes, addExpRes} :
        subDone ? {subSignRes, subMantRes, subExpRes} :
        mulDone ? {mulSignRes, mulMantRes, mulExpRes} :
        divDone ? {divSignRes, divMantRes, divExpRes} :
        powDone ? {powSignRes, powMantRes, powExpRes} :
        logDone ? {logSignRes, logMantRes, logExpRes} :
        expDone ? {expSignRes, expMantRes, expExpRes} :
        lnDone  ? {lnSignRes, lnMantRes, lnExpRes} :
        sinDone ? {sinSignRes, sinMantRes, sinExpRes} :
        cosDone ? {cosSignRes, cosMantRes, cosExpRes} :
        tanDone ? {tanSignRes, tanMantRes, tanExpRes} :
        {1'b0, 34'b0, 7'b0}; // default safe zero


    // --- moduleDone using op-based select (safe) ---
    wire moduleDone = 
        (op[7:0] == 8'h2A) ? addDone :
        (op[7:0] == 8'h2B) ? subDone :
        (op[7:0] == 8'h2C) ? mulDone :
        (op[7:0] == 8'h2D) ? divDone :
        (op[7:0] == 8'hF2) ? powDone :
        (op[7:0] == 8'hF3) ? logDone :
        (op[7:0] == 8'hF0) ? expDone :
        (op[7:0] == 8'hF1) ? lnDone  :
        (op[7:0] == 8'hF4) ? sinDone :
        (op[7:0] == 8'hF5) ? cosDone :
        (op[7:0] == 8'hF6) ? tanDone :
        1'b0;

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

            
        end

        else begin

            // should i really be adding these here??
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


            //more to be added
            //make sure ot add the eval pulses of the unary functions as well..

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
                    if((

                        // + - * /
                        op[7:0] == 8'h2A ||
                        op[7:0] == 8'h2B ||
                        op[7:0] == 8'h2C ||
                        op[7:0] == 8'h2D ||

                        // pow(x,a) & log(x,a)
                        op[7:0] == 8'hF2 ||
                        op[7:0] == 8'hF3
                      
                        ) && stk >= 2) begin // +

                        signA <= stack[stk-1][41]; 
                        mantA <= stack[stk-1][40 : 7]; 
                        expA <= stack[stk-1][6 : 0];

                        signB <= stack[stk-2][41]; 
                        mantB <= stack[stk-2][40 : 7]; 
                        expB <= stack[stk-2][6 : 0];

                        stk <= stk - 2;

                             if(op[7:0] == 8'h2A) addEval <= 1;
                        else if(op[7:0] == 8'h2B) subEval <= 1;
                        else if(op[7:0] == 8'h2C) mulEval <= 1;
                        else if(op[7:0] == 8'h2D) divEval <= 1;
                        
                        else if(op[7:0] == 8'hF2) powEval <= 1;
                        else if(op[7:0] == 8'hF3) logEval <= 1;
                            
                        // more to be added

                        state <= S_WAIT;

                        //to be continued
                        
                    end

                    else if((

                        // e^x & ln(x)
                        op[7:0] == 8'hF0 ||
                        op[7:0] == 8'hF1 ||

                        //trig funcs
                        op[7:0] == 8'hF4 ||
                        op[7:0] == 8'hF5 ||
                        op[7:0] == 8'hF6
                      
                        ) && stk >= 1) begin // +

                        signA <= stack[stk-1][41]; 
                        mantA <= stack[stk-1][40 : 7]; 
                        expA <= stack[stk-1][6 : 0];

                        stk <= stk - 1;

                             if(op[7:0] == 8'hF0) expEval <= 1;
                        else if(op[7:0] == 8'hF1) lnEval <= 1;

                        else if(op[7:0] == 8'hF4) sinEval <= 1;
                        else if(op[7:0] == 8'hF5) cosEval <= 1;
                        else if(op[7:0] == 8'hF6) tanEval <= 1;

                        
                        // more to be added

                        state <= S_WAIT;
                        
                    end

                    else begin
                        state <= S_IDLE; // or error state
                    end

                end


                //maybe ill use this state for 1 input functions too, ill think about it
                S_WAIT: begin
                    if (moduleDone) begin
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
                    if (doConv) begin
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

