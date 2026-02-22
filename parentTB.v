`timescale 1ns / 1ps

module parentTB    #(
        parameter depth = 5,
        parameter width = 8
     ) ;

    // clock + reset
    reg clock = 0;
    reg reset = 1;

    // keyboard inputs
    reg [15:0] b;
    reg del;
    reg ptrLeft;
    reg ptrRight;
    reg eval;
    
    //output: memory
    wire [width-1 : 0] mem [depth-1 : 0];
    
    

    // clock generation
    always #5 clock = ~clock;   // 100 MHz

    // DUT
    parent #(
        .depth(5),   // <<< forced depth = 5
        .width(8)
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
    
    
    




    // helpers
    task press_key(input integer idx);
    begin
        b = 16'b0;
        b[idx] = 1'b1;
        @(posedge clock);
        b = 16'b0;
        @(posedge clock);
    end
    endtask

    task pulse_del;
    begin
        del = 1;
        @(posedge clock);
        del = 0;
        @(posedge clock);
    end
    endtask

    task pulse_ptrLeft;
    begin
        ptrLeft = 1;
        @(posedge clock);
        ptrLeft = 0;
        @(posedge clock);
    end
    endtask

    initial begin
        // init
        b        = 0;
        del      = 0;
        ptrLeft  = 0;
        ptrRight = 0;
        eval     = 0;

        // reset
        repeat (2) @(posedge clock);
        reset = 0;

        // ----------------------------------
        // Insert: 5 + 8 / 9
        // ----------------------------------

        press_key(5);    // 5
        press_key(10);   // +
        press_key(8);    // 8
        press_key(13);   // /
        press_key(9);    // 9

        // ----------------------------------
        // Move pointer back to 8
        // expression: [5][+][8][/][9]
        // ptr is at end → move left twice
        // ----------------------------------

        pulse_ptrLeft;   // from 9 → /
        pulse_ptrLeft;   // from / → 8

        // ----------------------------------
        // Delete the 8
        // ----------------------------------

        pulse_del;

        // ----------------------------------
        // Insert 3
        // ----------------------------------

        press_key(3);

        // done
        #50;
        $finish;
    end

endmodule
