`timescale 1ns / 1ps

module parent #(
    parameter depth = 20,
    parameter width = 8,
    parameter buttons = 26
)(
    input clock,
    input reset,

   input  [buttons - 1 : 0] b,
    input del,
    input ptrLeft,
    input ptrRight,
    input eval,
    
    
    output wire [width-1 : 0] mem [depth-1 : 0]
);

    // keyboard → ds wires
    wire [width-1:0] dataIn;
    wire insert_pulse;
    wire del_pulse;
    wire ptrLeft_pulse;
    wire ptrRight_pulse;
    wire eval_pulse;

    // keyboard instance
    keyboard #(
        .width(width)
    ) kb (
        .clock(clock),
        .reset(reset),
        .b(b),
        .del(del),
        .ptrLeft(ptrLeft),
        .ptrRight(ptrRight),
        .eval(eval),
        .dataIn(dataIn),
        .insert(insert_pulse),
        .del_pulse(del_pulse),
        .ptrLeft_pulse(ptrLeft_pulse),
        .ptrRight_pulse(ptrRight_pulse),
        .eval_pulse(eval_pulse)
    );

    // data structure instance
    ds #(
        .depth(depth),
        .width(width)
    ) ds (
        .clock(clock),
        .reset(reset),
        .dataIn(dataIn),
        .insert(insert_pulse),
        .del(del_pulse),
        .ptrLeft(ptrLeft_pulse),
        .ptrRight(ptrRight_pulse),
        
        .mem(mem)
    );

endmodule
