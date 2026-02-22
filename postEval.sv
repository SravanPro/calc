`timescale 1ns / 1ps


//i only took chatgpt help in cases where i had to put in guarding helpers, as they
// can prevent errors i couldnt have forseen, only possible with the help of chat

// identifier: 
// 00: number 
// 01: operator/func/bracket/etc




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


    // using the state system insteaod of the fragile RBpop, commaPOP registers
    typedef enum logic [1:0] {
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

    wire signRes;
    wire [33:0] mantRes;
    wire signed [6:0] expRes;
    


                        //      if(op[7:0] == 8'hF0) expEval <= 1;
                        // else if(op[7:0] == 8'hF1) lnEval <= 1;

                        // else if(op[7:0] == 8'hF4) sinEval <= 1;
                        // else if(op[7:0] == 8'hF5) cosEval <= 1;
                        // else if(op[7:0] == 8'hF6) tanEval <= 1;

                        //      if(op[7:0] == 8'h2A) addEval <= 1;
                        // else if(op[7:0] == 8'h2B) subEval <= 1;
                        // else if(op[7:0] == 8'h2C) mulEval <= 1;
                        // else if(op[7:0] == 8'h2D) divEval <= 1;
                        
                        // else if(op[7:0] == 8'hF2) powEval <= 1;
                        // else if(op[7:0] == 8'hF3) logEval <= 1;

    reg addEval;
    wire addDone;
    adder adder0(
        .eval(addEval),
        .done(addDone),

        .signA(signA),
        .mantA(mantA),
        .exp(expA),

        .signB(signB),
        .mantB(mantB),
        .exp(expB),

        .signRes(signRes),
        .mantRes(mantRes),
        .expRes(expRes)
    );

    reg subEval;
    wire subDone;
    subber subber0(
        .eval(subEval),
        .done(subDone),

        .signA(signA),
        .mantA(mantA),
        .exp(expA),

        .signB(signB),
        .mantB(mantB),
        .exp(expB),

        .signRes(signRes),
        .mantRes(mantRes),
        .expRes(expRes)
    );
    //more to be added

    wire moduleDone = addDone | subDone; //add more done wires
    // chat's apparently more safe version:
    // wire moduleDone =
    //     (op == ADD) ? addDone :
    //     (op == SUB) ? subDone :
    //     (op == POW) ? powDone :
    //     1'b0;
    





    reg convPrevState = 0;
    wire doConv = conv && !convPrevState;

    
    integer k;

    

    always @(posedge clock or posedge reset) begin

        done <= 0; //just for safety

        if (reset) begin

            state <= S_IDLE;

            stk   <= 0;
            pof   <= 0;

            done  <= 0;
            convPrevState <= 1'b0;

            for (k = 0; k < depth; k = k + 1) begin
                stack[k] <= 0;
                postfix[k] <= 0;
            end
            
        end


        else begin

            // should i really be adding these here??
            addEval <= 0;
            subEval <= 0;
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
                        op[7:0] == 8'hF3 ||
                      
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
                        op[7:0] == 8'hF6 ||
                      
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
                end

                //maybe ill use this state for 1 input functions too, ill think about it
                S_WAIT: begin
                    addEval <= 0;
                    subEval <= 0;
                    //more to be added
                    //make sure ot add the eval pulses of the unary functions as well..

                    if (moduleDone) begin
                        stack[stk] <= {2'b00, signRes, mantRes, expRes};
                        stk <= stk + 1;
                        state <= S_READ;
                    end
                end


                S_DONE: begin
                    
                    answer <= stack[0];
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