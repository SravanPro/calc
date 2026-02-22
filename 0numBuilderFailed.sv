`timescale 1ns / 1ps

module numBuilder #(
    parameter depth   = 10,
    parameter width = 8,
    parameter newWidth= 42
)(
    input clock, reset, eval,

    input [$clog2(depth)-1:0] size,
    input [width-1 : 0] memIn [depth-1 : 0],

    output reg [$clog2(depth)-1:0] newSize,
    output reg [newWidth-1 : 0] memOut [depth-1 : 0],
    


);

    reg evalPrevState = 0;
    wire doEval = eval && !evalPrevState;

    integer i = 0;


    ////////////////////////////////
    //new processed number
    reg sign = 0;
    reg [33 : 0] mantissa = 0;
    reg [6:0] exp = 0;
    reg [41 : 0] newNum = 0;
    ////////////////////////////////
    

    reg seenDot = 0;

    always @(posedge clock) begin
    
        if(reset) begin

            i = 0;

            for(i = 0; i < depth; i = i + 1)begin
                memOut[i] <= 0;
            end

            i = 0;
            evalPrevState <= 0;
            sign <= 0;
            mantissa <= 0;
            exp <= 0;
            seenDot <= 0;
        end

        else begin
            if(doEval) begin

                for(i = 0; i < size; i = i + 1) begin

                    sign <= 0;
                    mantissa <= 0;
                    exp <= 0;
                    seenDot <= 0;
                
                    //integer case
                    if(  (memIn[i][7:4]) == 4'b0000   ) begin

                        while((memIn[i][7:4]) == 4'b0000) begin
                            mantissa <= mantissa * 10 + memIn[i];
                            if(seenDot) exp <= exp - 1;
                            i = i+1;
                        end

                        memOut[size] <= {sign, mantissa, exp};
                        newSizesize <= newSizesize + 1;

                        i = i-1; //to negate the extra i increment caused by the for loop


                        
                    end

                    //decimal point case
                    else if((memIn[i]) == 8'hDD) seenDot <= 1;

                    //any other symbol
                    else begin
                        memOut[size] <= {36'b0,memIn[i]};
                        newSizesize <= newSizesize + 1; 
                    end

                end
            
            end 

            evalPrevState <= eval;
        end
    end




endmodule