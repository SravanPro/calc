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

    input wire [$clog2(depth+1)-1:0] infixSize,
    input wire [newWidth-1:0] infix [depth-1:0],

    output reg [$clog2(depth+1)-1:0] postfixSize,
    output reg [newWidth-1:0] postfix [depth-1:0],

    output reg done //pulse

);

    reg [width-1 : 0] dataIn,
    reg push,pop;

    wire [width-1 : 0] dataOut, top,
    wire empty, full

    stackDS stack(
        .clock(clock),
        .reset(reset),

        .dataIn(dataIn),
        .dataOut(.dataOut),
        .top(top),

        .push(push),
        .pop(pop),

        .empty(empty),
        .full(full)
    )

    reg [$clog2(depth+1)-1:0] i = 0; // for infix mem
    reg [$clog2(depth+1)-1:0] j = 0; // for postfix mem

    wire isConst = (infix[i][depth-1 : depth-2] == 2'b00);
    wire isFunc = (infix[i][7:4] == 4'hF);
    wire isLB = (infix[i][7:0] == 8'h1E);
    wire isRB = (infix[i][7:0] == 8'h1F);


    reg convPrevState = 0;
    wire doConv = conv && !convPrevState;

    
    reg RBpop = 0;

    always @(posedge clock or posedge reset) begin
        if(reset) begin

            i <= 0
            j <= 0;

            
        end

        else begin
            push <= 0;
            pop <= 0;


            if(RBpop == 0) begin

                if(isConst) begin
                    push <= 0;
                    pop <= 0;

                    postfix[j] <= infix[i];
                    j <= j+1;
                end

                else if(isFunc || isLB) begin
                    push <= 1;
                    pop <= 0;

                    dataIn <= infix[i];
                end

                else if(isRB) begin
                    RBpop <= 1;
                end

            end

            else if(RBpop == 1) begin
                if(dataOut != 8'h1E) begin //if the latest popped value is not the left bracket.
                    push <= 0;
                    pop <= 1;
                    postfix[j] <= top;
                end

                else if(dataOut == 8'h1E) begin
                    
                end

                // if(top != 8'h1E) begin //if the top of stack is not the left bracket.
                //     push <= 0;
                //     pop <= 1;

                //     postfix[j] <= top;
                //     j <= j+1;
                // end

                // else if(dataOut == 8'h1E) begin
                    
                // end

                
            end

            


            




            i = i+1;
            convPrevState <= conv;
        end

    end


endmodule