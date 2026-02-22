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



    // stack like ds
    reg [newWidth-1 : 0] stack [depth-1 : 0];

    
    reg [$clog2(depth+1)-1:0] inf = 0; // for infix mem
    reg [$clog2(depth+1)-1:0] pof = 0; // for postfix mem
    reg [$clog2(depth+1)-1:0] stk = 0; // for stack mem
    reg [$clog2(depth+1)-1:0] i = 0; // for iteration through anything

    assign postfixSize = pof;


    wire isConst = (infix[inf][newWidth-1 : newWidth-2] == 2'b00);
    wire isFunc = (infix[inf][7:4] == 4'hF);
    wire isLB = (infix[inf][7:0] == 8'h1E);
    wire isRB = (infix[inf][7:0] == 8'h1F);


    reg convPrevState = 0;
    wire doConv = conv && !convPrevState;

    
    reg RBpop = 0;

    always @(posedge clock or posedge reset) begin
        if(reset) begin

    

            
        end

        else begin


            if(inf < infixSize) begin //infix top is incremented at the end of the loop

                if(isConst && !RBpop) begin
                    postfix[pof] <= infix[inf];
                    pof <= pof+1;
                    inf <= inf+1;
                end

                else if((isFunc || isLB) && !RBpop) begin
                    stack[stk] <= infix[inf];
                    stk <= stk+1;
                    inf <= inf+1;
                end

                else if(isRB && !RBpop) begin
                    
                    RBpop <= 1;
                    inf <= inf+1;
                end

                else if(RBpop)begin

                    //index is stk-1 
                    // stk is continuoulsy changing,
                    // -1 coz stk gives count, not index.

                    if(stack[stk-1][7:0] != 8'h1E) begin // if not a left bracket

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

                        RBpop <= 0;
                    end

                    
                end
                
            end
            convPrevState <= conv;
        end

    end


endmodule

