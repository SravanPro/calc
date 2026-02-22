`timescale 1ns/1ps

module itpTB;

  localparam int BUTTONS  = 27;
  localparam int DEPTH    = 20;     // requested
  localparam int WIDTH    = 8;
  localparam int NEWWIDTH = 44;

  reg clock;
  reg reset;

  reg [BUTTONS-1:0] b;
  reg del;
  reg ptrLeft;
  reg ptrRight;
  reg eval;

  // DUT
  wire done;
  parent #(
    .buttons(BUTTONS),
    .depth(DEPTH),
    .width(WIDTH),
    .newWidth(NEWWIDTH)
  ) uut (
    .clock(clock),
    .reset(reset),
    .b(b),
    .del(del),
    .ptrLeft(ptrLeft),
    .ptrRight(ptrRight),
    .eval(eval),

    .parentOut(done)
  );

  // ---- Probe wires: DS mem[0..19] (8-bit) ----
  wire [WIDTH-1:0] mem0  = uut.mem[0];
  wire [WIDTH-1:0] mem1  = uut.mem[1];
  wire [WIDTH-1:0] mem2  = uut.mem[2];
  wire [WIDTH-1:0] mem3  = uut.mem[3];
  wire [WIDTH-1:0] mem4  = uut.mem[4];
  wire [WIDTH-1:0] mem5  = uut.mem[5];
  wire [WIDTH-1:0] mem6  = uut.mem[6];
  wire [WIDTH-1:0] mem7  = uut.mem[7];
  wire [WIDTH-1:0] mem8  = uut.mem[8];
  wire [WIDTH-1:0] mem9  = uut.mem[9];
  wire [WIDTH-1:0] mem10 = uut.mem[10];
  wire [WIDTH-1:0] mem11 = uut.mem[11];
  wire [WIDTH-1:0] mem12 = uut.mem[12];
  wire [WIDTH-1:0] mem13 = uut.mem[13];
  wire [WIDTH-1:0] mem14 = uut.mem[14];
  wire [WIDTH-1:0] mem15 = uut.mem[15];
  wire [WIDTH-1:0] mem16 = uut.mem[16];
  wire [WIDTH-1:0] mem17 = uut.mem[17];
  wire [WIDTH-1:0] mem18 = uut.mem[18];
  wire [WIDTH-1:0] mem19 = uut.mem[19];

  // ---- Probe wires: Builder memOut[0..19] (44-bit) ----
  wire [NEWWIDTH-1:0] memOut0  = uut.memOut[0];
  wire [NEWWIDTH-1:0] memOut1  = uut.memOut[1];
  wire [NEWWIDTH-1:0] memOut2  = uut.memOut[2];
  wire [NEWWIDTH-1:0] memOut3  = uut.memOut[3];
  wire [NEWWIDTH-1:0] memOut4  = uut.memOut[4];
  wire [NEWWIDTH-1:0] memOut5  = uut.memOut[5];
  wire [NEWWIDTH-1:0] memOut6  = uut.memOut[6];
  wire [NEWWIDTH-1:0] memOut7  = uut.memOut[7];
  wire [NEWWIDTH-1:0] memOut8  = uut.memOut[8];
  wire [NEWWIDTH-1:0] memOut9  = uut.memOut[9];
  wire [NEWWIDTH-1:0] memOut10 = uut.memOut[10];
  wire [NEWWIDTH-1:0] memOut11 = uut.memOut[11];
  wire [NEWWIDTH-1:0] memOut12 = uut.memOut[12];
  wire [NEWWIDTH-1:0] memOut13 = uut.memOut[13];
  wire [NEWWIDTH-1:0] memOut14 = uut.memOut[14];
  wire [NEWWIDTH-1:0] memOut15 = uut.memOut[15];
  wire [NEWWIDTH-1:0] memOut16 = uut.memOut[16];
  wire [NEWWIDTH-1:0] memOut17 = uut.memOut[17];
  wire [NEWWIDTH-1:0] memOut18 = uut.memOut[18];
  wire [NEWWIDTH-1:0] memOut19 = uut.memOut[19];


  // ---- Probe wires: postfix memOut[0..19] (42-bit) ----
  wire [NEWWIDTH-1:0] postfix0  = uut.postfix[0];
  wire [NEWWIDTH-1:0] postfix1  = uut.postfix[1];
  wire [NEWWIDTH-1:0] postfix2  = uut.postfix[2];
  wire [NEWWIDTH-1:0] postfix3  = uut.postfix[3];
  wire [NEWWIDTH-1:0] postfix4  = uut.postfix[4];
  wire [NEWWIDTH-1:0] postfix5  = uut.postfix[5];
  wire [NEWWIDTH-1:0] postfix6  = uut.postfix[6];
  wire [NEWWIDTH-1:0] postfix7  = uut.postfix[7];
  wire [NEWWIDTH-1:0] postfix8  = uut.postfix[8];
  wire [NEWWIDTH-1:0] postfix9  = uut.postfix[9];
  wire [NEWWIDTH-1:0] postfix10 = uut.postfix[10];
  wire [NEWWIDTH-1:0] postfix11 = uut.postfix[11];
  wire [NEWWIDTH-1:0] postfix12 = uut.postfix[12];
  wire [NEWWIDTH-1:0] postfix13 = uut.postfix[13];
  wire [NEWWIDTH-1:0] postfix14 = uut.postfix[14];
  wire [NEWWIDTH-1:0] postfix15 = uut.postfix[15];
  wire [NEWWIDTH-1:0] postfix16 = uut.postfix[16];
  wire [NEWWIDTH-1:0] postfix17 = uut.postfix[17];
  wire [NEWWIDTH-1:0] postfix18 = uut.postfix[18];
  wire [NEWWIDTH-1:0] postfix19 = uut.postfix[19];

  
  wire [$clog2(DEPTH+1)-1:0] newSize = uut.newSize;

  

  // clock
  initial clock = 1'b0;
  always #5 clock = ~clock;

  // press helpers (same style as before: press 2 clocks, release 2 clocks)
  task automatic press_b_button(input int idx);
    begin
      b = '0;
      b[idx] = 1'b1;
      repeat (2) @(posedge clock);

      b = '0;
      repeat (2) @(posedge clock);
    end
  endtask

  task automatic press_eval;
    begin
      eval = 1'b1;
      repeat (2) @(posedge clock);
      eval = 1'b0;
      repeat (2) @(posedge clock);
    end
  endtask

  // stimulus
  initial begin
    b = '0;
    del = 1'b0;
    ptrLeft = 1'b0;
    ptrRight = 1'b0;
    eval = 1'b0;

    reset = 1'b1;
    repeat (4) @(posedge clock);
    reset = 1'b0;
    repeat (2) @(posedge clock);

    // Expression tokens (19):
    // ( 83.2341 ) * sin( 4.32 * pi )
    //
    // button indices:
    // ( : 14
    // ) : 15
    // . : 16
    // * : 12
    // pi: 18
    // sin:24
    // digits: 0..9

    press_b_button(14); // (
    press_b_button(8);  // 8
    press_b_button(3);  // 3
    press_b_button(16); // .
    press_b_button(2);  // 2
    press_b_button(3);  // 3
    press_b_button(4);  // 4
    press_b_button(1);  // 1
    press_b_button(15); // )

    press_b_button(12); // *
    press_b_button(24); // sin
    press_b_button(14); // (

    press_b_button(4);  // 4
    press_b_button(16); // .
    press_b_button(3);  // 3
    press_b_button(2);  // 2

    press_b_button(12); // *
    press_b_button(18); // pi
    press_b_button(15); // )

    // run numBuilder
    press_eval();

    // wait for done
//    wait (done === 1'b1);
//    @(posedge clock);

    #1000;
    $finish;
  end

endmodule
