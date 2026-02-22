`timescale 1ns / 1ps

module parentTB #(
        parameter depth   = 10,
        parameter width   = 8,
        parameter buttons = 26
     );

    // clock + reset
    reg clock = 0;
    reg reset = 1;

    // keyboard inputs
    reg  [buttons-1:0] b;
    reg del;
    reg ptrLeft;
    reg ptrRight;
    reg eval;

    // output memory
    wire [width-1:0] mem [depth-1:0];

    // clock generation
    always #5 clock = ~clock;

    // DUT
    parent #(
        .depth(depth),
        .width(width),
        .buttons(buttons)
    ) parentDut (
        .clock(clock),
        .reset(reset),
        .b(b),
        .del(del),
        .ptrLeft(ptrLeft),
        .ptrRight(ptrRight),
        .eval(eval),
        .mem(mem)
    );

    // --------------------------------------------------
    // helpers
    // --------------------------------------------------
    task press_key(input integer idx);
    begin
        b = '0;
        b[idx] = 1'b1;
        @(posedge clock);
        b = '0;
        @(posedge clock);
    end
    endtask

    initial begin
        // init
        b        = '0;
        del      = 0;
        ptrLeft  = 0;
        ptrRight = 0;
        eval     = 0;

        // reset
        repeat (2) @(posedge clock);
        reset = 0;

        // ----------------------------------
        // Insert: pi * tan(sin(34))
        // ----------------------------------

        press_key(18);   // pi
        press_key(12);   // *
        press_key(25);   // tan
        press_key(14);   // (
        press_key(23);   // sin
        press_key(14);   // (
        press_key(3);    // 3
        press_key(4);    // 4
        press_key(15);   // )
        press_key(15);   // )

        // done
        #1;
        $finish;
    end

endmodule
