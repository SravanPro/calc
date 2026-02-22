`timescale 1ns / 1ps

module parent #(

    
    parameter buttons = 27,
    parameter page = 16, // for the SPI interface
    parameter depth = 32,
    parameter width = 8,
    parameter newWidth = 44
    
)(
    input clock,
    input reset,

    input  [buttons - 1 : 0] b,
    input del,
    input ptrLeft,
    input ptrRight,
    input jump,
    input eval,
    
    //postfix evaluator -> parent output

    output sclk,
    output mosi,
    output cs
    
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
    wire [$clog2(depth+1)-1:0] ptrOut;
    wire [width-1 : 0] mem [depth-1 : 0];

    //numBuilder -> infixToPostfix wires
    wire [$clog2(depth+1)-1:0] newSize;
    wire [newWidth-1:0] memOut [depth-1:0];
    wire done1; //pulse

    ///infixToPostfix ->  postfix evaluator wires
    wire [$clog2(depth+1)-1:0] postfixSize;
    wire [newWidth-1:0] postfix [depth-1:0];
    wire done2;

    //postfix evaluator -> parent output
    // declared in parent module's output


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
        .jump(jump),
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
        .sizeOut(sizeOut),
        .ptrOut(ptrOut)
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
        .done(done1)

    );

    inToPost #(
        .depth(depth),
        .newWidth(newWidth)
    ) itp (
        .clock(clock),
        .reset(reset),
        .conv(done1),

        .infixSize(newSize), // recieves the count of the no of elements in the stack
        .infix(memOut),

        
        .postfix(postfix),
        .postfixSize(postfixSize),
        
        .done(done2)

    );

    postEval #(
        .depth(depth),
        .newWidth(newWidth)
    ) pev (
        .clock(clock),
        .reset(reset),
        .conv(done2),
        
        .postfix(postfix),
        .postfixSize(postfixSize),

        .answer(answer),
        
        .done(done)

    );

    spiInterface#(
        
        .buttons(buttons) ,
        .page(page) ,
        .depth(depth) ,
        .width(width) ,
        .newWidth(newWidth) 
    ) spi (
        .clock(clock),
        .reset(reset),
        .jump(jump),
        .answer(answer),
        .mem(mem),
        .sizeOut(sizeOut),
        .ptrOut(ptrOut),
        .sclk(sclk),
        .mosi(mosi),
        .cs(cs)


    );
endmodule
