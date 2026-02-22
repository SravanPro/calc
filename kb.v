`timescale 1ns / 1ps

module keyboard #(
    parameter width = 8
)(
    input clock, reset,

    input  [15:0] b,        // 0-9 digits 10:+ 11:- 12:* 13:/ 14:( 15:)
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

    reg [15:0] b_prev;
    reg del_prev, ptrLeft_prev, ptrRight_prev, eval_prev;

    reg key_valid;
    reg [width-1:0] key_code;

    integer i;

    // combinational encoder
    always @(*) begin
        key_valid = 0;      //"Is any key pressed right now (after encoding)?"
        key_code  = 0;  

        for (i = 0; i < 16; i = i + 1) begin
            if (b[i] && !key_valid) begin  //First pressed key wins
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

    // edge detect + pulse gen
    always @(posedge clock) begin
        if (reset) begin
            insert <= 0;
            del_pulse <= 0;
            ptrLeft_pulse <= 0;
            ptrRight_pulse <= 0;
            eval_pulse <= 0;

            b_prev <= 0;
            del_prev <= 0;
            ptrLeft_prev <= 0;
            ptrRight_prev <= 0;
            eval_prev <= 0;
        end
        else begin
            insert <= 0;
            del_pulse <= 0;
            ptrLeft_pulse <= 0;
            ptrRight_pulse <= 0;
            eval_pulse <= 0;
                                        //OR all bits of b_prev, checks if no key was pressed in the previous cycle
            if (key_valid && !(|b_prev)) begin
                dataIn <= key_code;
                insert <= 1;
            end

            if (del && !del_prev)           del_pulse <= 1;
            if (ptrLeft && !ptrLeft_prev)   ptrLeft_pulse <= 1;
            if (ptrRight && !ptrRight_prev) ptrRight_pulse <= 1;
            if (eval && !eval_prev)         eval_pulse <= 1;

            b_prev <= b;
            del_prev <= del;
            ptrLeft_prev <= ptrLeft;
            ptrRight_prev <= ptrRight;
            eval_prev <= eval;
        end
    end

endmodule
