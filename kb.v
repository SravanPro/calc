`timescale 1ns / 1ps

module keyboard #(
    parameter width = 8,
    parameter buttons = 16
)(
    input clock, reset,

    input  [buttons - 1 : 0] b,        
    // 0-9 : digits
    //10, 11, 12, 13 :  add, sub, mul , div
    //14, 15: left bracket, right bracket
    input  del,
    input  ptrLeft,
    input  ptrRight,
    input  eval,

    output reg [width-1:0] dataIn,
    output reg insert,
    output reg del_pulse,
    output reg ptrLeft_pulse,
    output reg ptrRight_pulse,
    output reg eval_pulse
);

    // operator tokens
    localparam OP_ADD = 8'hA0;
    localparam OP_SUB = 8'hA1;
    localparam OP_MUL = 8'hA2;
    localparam OP_DIV = 8'hA3;
    localparam OP_LB  = 8'hA4;
    localparam OP_RB  = 8'hA5;

    reg key_valid;
    reg [width-1:0] key_code;
    integer i;

    // Combinational Encoder (Same as before)
    always @(*) begin
        key_valid = 0;
        key_code  = 0;
        for (i = 0; i < buttons; i = i + 1) begin
            if (b[i] && !key_valid) begin  
                key_valid = 1;
                case (i)
                    0,1,2,3,4,5,6,7,8,9: key_code = i;
                    
                    10: key_code = OP_ADD;
                    11: key_code = OP_SUB;
                    12: key_code = OP_MUL;
                    13: key_code = OP_DIV;
                    
                    14: key_code = OP_LB;
                    15: key_code = OP_RB;
                endcase
            end
        end
    end

    // Sequential Block: CHANGED to "Pass-Through" logic
    always @(posedge clock) begin
        if (reset) begin
            insert <= 0;
            del_pulse <= 0;
            ptrLeft_pulse <= 0;
            ptrRight_pulse <= 0;
            eval_pulse <= 0;
            dataIn <= 0;
        end
        else begin
            // 1. DATA PATH
            // Just pass the key code whenever valid. 
            // The DS module decides *when* to latch it (on the rising edge of insert).
            if (key_valid) begin
                dataIn <= key_code;
            end

            // 2. CONTROL PATH
            // Remove the edge detection here (!prev). 
            // Just output HIGH if the button is pressed.
            // The DS module's internal edge detector will handle the "Write Once" logic.
            
            insert <= key_valid;       // Output High as long as key is held
            del_pulse <= del;          // Output High as long as del is held
            ptrLeft_pulse <= ptrLeft;  
            ptrRight_pulse <= ptrRight;
            eval_pulse <= eval;
        end
    end

endmodule