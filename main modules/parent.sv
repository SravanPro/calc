`timescale 1ns / 1ps

module parent #(

    
    parameter buttons = 27,
    parameter page = 16, // for the SPI interface
    parameter depth = 32,
    parameter width = 8,
    parameter newWidth = 44,

    parameter freq     = 50000000,   // Hz
    parameter debounceTime  = 10            // milliseconds
    
)(
    input clock, reset,
    input [4:0] encodedRawInput,
    
    //postfix evaluator -> parent output
    output done,
    output sclk,
    output mosi,
    output cs,

    output [3:0] testBits
    
);

    wire [buttons-1:0] b;
    wire del;
    wire ptrLeft;
    wire ptrRight;
    wire jump;
    wire eval;


    //debouncer -> decoder wires
    wire [4:0] encodedDebouncedInput;

    // decoder -> keyboard wires
    wire [31:0] decodedOutput;
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

// 1..9 straight
assign b[1] = decodedOutput[1];
assign b[2] = decodedOutput[2];
assign b[3] = decodedOutput[3];
assign b[4] = decodedOutput[4];
assign b[5] = decodedOutput[5];
assign b[6] = decodedOutput[6];
assign b[7] = decodedOutput[7];
assign b[8] = decodedOutput[8];
assign b[9] = decodedOutput[9];

// specials
assign b[0]  = decodedOutput[10];
assign b[19] = decodedOutput[11];

// “12 to 18, 13 to 16, 14 10, 15 11, 16 17, 17 12, 18 13, 19 14, 20 15, 21 23”
assign b[18] = decodedOutput[12];
assign b[16] = decodedOutput[13];
assign b[10] = decodedOutput[14];
assign b[11] = decodedOutput[15];
assign b[17] = decodedOutput[16];
assign b[12] = decodedOutput[17];
assign b[13] = decodedOutput[18];
assign b[14] = decodedOutput[19];
assign b[15] = decodedOutput[20];
assign b[23] = decodedOutput[21];

// “22 ptrLeft, 23 ptrRight”
assign ptrLeft  = decodedOutput[22];
assign ptrRight = decodedOutput[23];

// “24 22, 25 24, 26 25, 27 26”
assign b[22] = decodedOutput[24];
assign b[24] = decodedOutput[25];
assign b[25] = decodedOutput[26];
assign b[26] = decodedOutput[27];

// “28 jump, 29 del, 30 eval, 31 reset”
assign jump  = decodedOutput[28];
assign del   = decodedOutput[29];
assign eval  = decodedOutput[30];

assign b[20] = 1'b0;
assign b[21] = 1'b0;
////////////////////////////////////////////////////////////////////////////////////////////////////




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

    //postfix evaluator -> spi
    wire [newWidth-1:0] answer;
    assign testBits = answer[15:12];



    //debouncer Instance
    debouncer #(
        .width(5),
        .freq(freq),
        .debounceTime(debounceTime)
    ) deb(
        .clock(clock),
        .reset(reset),
        .raw(encodedRawInput),
        .debounced(encodedDebouncedInput)
    );

    // decoder Instance
    decoder dec(
        .in(encodedDebouncedInput),
        .out(decodedOutput)
    );

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
