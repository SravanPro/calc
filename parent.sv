`timescale 1ns / 1ps

module parent #(
    parameter buttons = 27,


    parameter depth = 20,
    parameter width = 8,
    parameter newWidth = 44
    
)(
    input clock,
    input reset,

   input  [buttons - 1 : 0] b,
    input del,
    input ptrLeft,
    input ptrRight,
    input eval,
    
    // dummy output
    output  parentOut
    
);

    // keyboard → ds wires
    wire [width-1:0] dataIn;
    wire insert_pulse;
    wire del_pulse;
    wire ptrLeft_pulse;
    wire ptrRight_pulse;

    // keyboard -> numBuilder wires
    wire eval_pulse;

    //ds -> numBuilder wires
    wire [$clog2(depth+1)-1:0] sizeOut;
    wire [width-1 : 0] mem [depth-1 : 0];

    //numBuilder -> infixToPostfix wires
    wire [$clog2(depth+1)-1:0] newSize;
    wire [newWidth-1:0] memOut [depth-1:0];
    wire done; //pulse

    ///infixToPostfix ->  postfix evaluator wires
    wire [$clog2(depth+1)-1:0] postfixSize;
    wire [newWidth-1:0] postfix [depth-1:0];



    // keyboard instance
    keyboard #(
        .width(width),
        .buttons(buttons)
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
    dataStructure #(
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
        
        .mem(mem),
        .sizeOut(sizeOut)
    );

    // numBuilder instance
    numBuilder #(
        .depth(depth),
        .width(width),
        .newWidth(newWidth)
    ) nb (
        .clock(clock),
        .reset(reset),
        .eval(eval_pulse),

        .size(sizeOut),
        .memIn(mem),

        .newSize(newSize),
        .memOut(memOut),
        .done(done)

    );

    inToPost #(
        .depth(depth),
        .newWidth(newWidth)
    ) itp (
        .clock(clock),
        .reset(reset),
        .conv(done),

        .infixSize(newSize), // recieves the count of the no of elements in the stack
        .infix(memOut),

        
        .postfix(postfix),
        .postfixSize(postfixSize),
        
        .done(parentOut)

    );

endmodule
