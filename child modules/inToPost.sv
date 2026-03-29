`timescale 1ns / 1ps


//i only took chatgpt help in cases where i had to put in guarding helpers, as they
// can prevent errors i couldnt have forseen, only possible with the help of chat

// identifier: 
// 00: number 
// 01: operator/func/bracket/etc




module inToPost #(
    parameter depth = 10,
    parameter newWidth = 44 
)(
    input wire clock,
    input wire reset,
    input wire conv,

    input wire [$clog2(depth+1)-1:0] infixSize, // recieves the count of the no of elements in the stack
    input wire [newWidth-1:0] infix [depth-1:0],

    output wire [$clog2(depth+1)-1:0] postfixSize,
    output reg [newWidth-1:0] postfix [depth-1:0],

    output reg done //pulse

);

    // using the state system insteaod of the fragile RBpop, commaPOP registers
    typedef enum logic [2:0] {
        S_READ,     // reading infix tokens
        S_RB_POP,   // popping until '('
        S_DC_POP,
        S_OP_POP,
        S_DONE,
        S_IDLE
    } state_t;

    state_t state;


// these 2 are for finding the precedence of operators
    localparam [newWidth-1:0]
        ADD = 8'h01,
        SUB = 8'h02,
        MUL = 8'h03,
        DIV = 8'h04;
        function automatic [1:0] precedence(input [newWidth-1:0] tok);
            if (tok[7:4] != 4'h2) precedence = 0;
            else if (tok[3:0] == 4'hC || tok[3:0] == 4'hD) precedence = 2; // * /
            else precedence = 1; // + -
        endfunction



    // stack like ds
    reg [newWidth-1 : 0] stack [depth-1 : 0];

    
    reg [$clog2(depth+1)-1:0] inf = 0; // for infix mem
    reg [$clog2(depth+1)-1:0] pof = 0; // for postfix mem
    reg [$clog2(depth+1)-1:0] stk = 0; // for stack mem

    assign postfixSize = pof;


    wire validTok = (inf < infixSize);

    wire isConst = validTok && (infix[inf][newWidth-1 : newWidth-2] == 2'b00);
    wire isFunc = validTok && (infix[inf][7:4] == 4'hF);
    wire isLB = validTok && (infix[inf][7:0] == 8'h1E);
    wire isRB = validTok && (infix[inf][7:0] == 8'h1F);
    wire isDC = validTok && (infix[inf][7:0] == 8'hDC);
    wire isOp = validTok && (infix[inf][7:4] == 4'h2);


        


    reg convPrevState = 0;
    wire doConv = conv && !convPrevState;

    
            integer k;

    

    always @(posedge clock or posedge reset) begin

        done <= 0; //just for safety

        if (reset) begin
            state <= S_IDLE;
            inf   <= 0;
            stk   <= 0;
            pof   <= 0;
            done  <= 0;
            convPrevState <= 1'b0;

            for (k = 0; k < depth; k = k + 1) begin
            postfix[k] <= '0;
            stack[k]   <= '0;
            end


        end


        else begin

            case (state)

                S_READ: begin

                    if(inf < infixSize) begin //infix top is incremented at the end of the loop

                        if (isConst) begin
                            postfix[pof] <= infix[inf];
                            pof <= pof + 1;
                            inf <= inf + 1;
                        end
                        
                        else if(isFunc || isLB) begin
                            stack[stk] <= infix[inf];
                            stk <= stk+1;
                            inf <= inf+1;
                        end

                        else if(isRB) begin
                            state <= S_RB_POP;
                            inf <= inf + 1;
                        end

                        else if(isDC) begin
                            state <= S_DC_POP;
                            inf <= inf + 1;
                        end

                        else if (isOp) begin
                            state <= S_OP_POP;
                            // inf not incremented coz whether or not to increment is decided later in the logic
                        end

                    end

                    else begin //inf >= infixSize : Conversion is done 
                        state <= S_DONE;
                    end

                end

                S_RB_POP: begin

                    // we have encountered RB, now dealing with either LB or not LB
                    //index is stk-1 
                    // stk is continuoulsy changing,
                    // -1 coz stk gives count, not index.


                    if (stk == 0) begin
                        // syntax error or unexpected ')'
                        state <= S_READ; // or S_ERROR later
                    end

                    else if(stack[stk-1][7:0] != 8'h1E) begin // if not a left bracket

                        postfix[pof] <= stack[stk-1];
                        stk <= stk - 1;
                        pof <= pof + 1;
                    end 

                    else if(stack[stk-1][7:0] == 8'h1E) begin // if we have found LB
                        if(stk >= 2 && stack[stk-2][7:4] == 4'hF) begin // if a function precedes the LB
                            
                            postfix[pof] <= stack[stk-2]; //poppig and returning the function
                            stk <= stk - 2; // 2 coz LB and funciton are both popped
                            pof <= pof + 1; // 1 coz only function is popped to output

                        end

                        else begin // if a function dosen't precede the LB
                            stk <= stk - 1; // 1 coz only LB is popped and discarded
                        end

                        // now that the LB is found, we can exit
                        state <= S_READ; 

                    end

                    
                end
            

                S_DC_POP: begin

                    // we have encountered comma, now dealing with either LB or not LB
                    if (stk == 0) begin
                        state <= S_READ; // safety exit
                    end

                    else if(stack[stk-1][7:0] != 8'h1E) begin // if not a left bracket

                        postfix[pof] <= stack[stk-1];
                        stk <= stk - 1;
                        pof <= pof + 1;
                    end 

                    else if(stack[stk-1][7:0] == 8'h1E) begin // if we have found LB

                        //after LB is found, we can leave
                        state <= S_READ; 

                    end 
                end

                S_OP_POP: begin
                    if(stk > 0 &&
                       (stack[stk-1][7:4] == 4'hF || 
                       (stack[stk-1][7:4] == 4'h2 &&
                       precedence(stack[stk-1]) >= precedence(infix[inf])))
                    ) begin

                        postfix[pof] <= stack[stk-1];
                        stk <= stk - 1;
                        pof <= pof + 1;

                    end

                    else begin
                        stack[stk] <= infix[inf];
                        stk <= stk+1;
                        inf <= inf+1;
                        state <= S_READ; //added this after sim bug
                    end
                end

                S_DONE: begin
                    // flushing is done here
                    if (stk > 0) begin
                        // flush stack to postfix
                        postfix[pof] <= stack[stk-1];
                        stk <= stk - 1;
                        pof <= pof + 1;
                    end
                    else begin
                        done  <= 1;    
                        state <= S_IDLE;   
                    end
                end


                //added this module so that i can actually get a pulse
                S_IDLE: begin
                    done <= 0;
                    if (doConv) begin
                        inf   <= 0;
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