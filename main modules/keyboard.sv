`timescale 1ns / 1ps

module keyboard #(
    parameter width = 8,
    parameter buttons = 27
)(
    input clock, reset,

    input  [buttons - 1 : 0] b,     
    
    //(outdated)
    // 0-9 : digits
    //10, 11, 12, 13 :  add, sub, mul , div
    //14, 15: left bracket, right bracket
    
    // 16: decimal point
    // 17: e
    // 18: pi
    
    // 19: e^x
    //20: log x (base e)
    
    //21:  pow(x, a)
    //22:  log(x, a)
    
    //23: sin
    //24: cos
    //25: tan

    
    
    
    
    
    
    
    input del,
    input ptrLeft,
    input ptrRight,
    input jump,
    input eval,

    output reg [width-1:0] dataIn,
    output reg insert,
    output reg del_pulse,
    output reg ptrLeft_pulse,
    output reg ptrRight_pulse,
    output reg eval_pulse
);

// digits
localparam OP_0 = 8'h00;
localparam OP_1 = 8'h01;
localparam OP_2 = 8'h02;
localparam OP_3 = 8'h03;
localparam OP_4 = 8'h04;
localparam OP_5 = 8'h05;
localparam OP_6 = 8'h06;
localparam OP_7 = 8'h07;
localparam OP_8 = 8'h08;
localparam OP_9 = 8'h09;

// basic operators
localparam OP_ADD = 8'h2A;
localparam OP_SUB = 8'h2B;
localparam OP_MUL = 8'h2C;
localparam OP_DIV = 8'h2D;

// brackets
localparam OP_LB  = 8'h1E;
localparam OP_RB  = 8'h1F;

// additional symbols
localparam OP_DECIMAL = 8'hDD;   // .
localparam OP_COMMA = 8'hDC;   // ,

localparam OP_E       = 8'hC0;   // constant e
localparam OP_PI      = 8'hC1;   // constant pi

// functions
localparam OP_EXP     = 8'hF0;   // e^x
localparam OP_LN      = 8'hF1;   // log(x) base e

localparam OP_POW     = 8'hF2;   // pow(x, a)
localparam OP_LOG     = 8'hF3;   // log(x, a)

localparam OP_SIN     = 8'hF4;   // sin(x)
localparam OP_COS     = 8'hF5;   // cos(x)
localparam OP_TAN     = 8'hF6;   // tan(x)



//misc-----------------------------------------
localparam OP_CSC     = 8'hF7;   // csc(x)
localparam OP_SEC     = 8'hF8;   // sec(x)
localparam OP_COT     = 8'hF9;   // cot(x)
localparam OP_ASIN    = 8'hFA;   // arcsin(x)
localparam OP_ACOS    = 8'hFB;   // arccos(x)
localparam OP_ATAN    = 8'hFC;   // arctan(x)

    

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
                    // digits
                    0,1,2,3,4,5,6,7,8,9: key_code = i;
                
                    // basic operators
                    10: key_code = OP_ADD;
                    11: key_code = OP_SUB;
                    12: key_code = OP_MUL;
                    13: key_code = OP_DIV;
                
                    // brackets
                    14: key_code = OP_LB;
                    15: key_code = OP_RB;
                
                    // decimal point
                    16: key_code = OP_DECIMAL;
                    17: key_code = OP_COMMA;
                
                    // constants
                    18: key_code = OP_E;
                    19: key_code = OP_PI;
                
                    // functions
                    20: key_code = OP_EXP;
                    21: key_code = OP_LN;
                    22: key_code = OP_POW;
                    23: key_code = OP_LOG;
                    24: key_code = OP_SIN;
                    25: key_code = OP_COS;
                    26: key_code = OP_TAN;
                
                    // misc (if used later)
                    27: key_code = OP_CSC;
                    28: key_code = OP_SEC;
                    29: key_code = OP_COT;
                    30: key_code = OP_ASIN;
                    31: key_code = OP_ACOS;
                    32: key_code = OP_ATAN;

                    
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