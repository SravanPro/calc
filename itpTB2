`timescale 1ns/1ps

module itpTB2;

  localparam int BUTTONS  = 27;
  localparam int DEPTH    = 40;     // changed to 40
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

  // ---- Probe wires: DS mem[0..39] (8-bit) ----
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
  wire [WIDTH-1:0] mem20 = uut.mem[20];
  wire [WIDTH-1:0] mem21 = uut.mem[21];
  wire [WIDTH-1:0] mem22 = uut.mem[22];
  wire [WIDTH-1:0] mem23 = uut.mem[23];
  wire [WIDTH-1:0] mem24 = uut.mem[24];
  wire [WIDTH-1:0] mem25 = uut.mem[25];
  wire [WIDTH-1:0] mem26 = uut.mem[26];
  wire [WIDTH-1:0] mem27 = uut.mem[27];
  wire [WIDTH-1:0] mem28 = uut.mem[28];
  wire [WIDTH-1:0] mem29 = uut.mem[29];
  wire [WIDTH-1:0] mem30 = uut.mem[30];
  wire [WIDTH-1:0] mem31 = uut.mem[31];
  wire [WIDTH-1:0] mem32 = uut.mem[32];
  wire [WIDTH-1:0] mem33 = uut.mem[33];
  wire [WIDTH-1:0] mem34 = uut.mem[34];
  wire [WIDTH-1:0] mem35 = uut.mem[35];
  wire [WIDTH-1:0] mem36 = uut.mem[36];
  wire [WIDTH-1:0] mem37 = uut.mem[37];
  wire [WIDTH-1:0] mem38 = uut.mem[38];
  wire [WIDTH-1:0] mem39 = uut.mem[39];

  // ---- Probe wires: Builder memOut[0..39] (44-bit) ----
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
  wire [NEWWIDTH-1:0] memOut20 = uut.memOut[20];
  wire [NEWWIDTH-1:0] memOut21 = uut.memOut[21];
  wire [NEWWIDTH-1:0] memOut22 = uut.memOut[22];
  wire [NEWWIDTH-1:0] memOut23 = uut.memOut[23];
  wire [NEWWIDTH-1:0] memOut24 = uut.memOut[24];
  wire [NEWWIDTH-1:0] memOut25 = uut.memOut[25];
  wire [NEWWIDTH-1:0] memOut26 = uut.memOut[26];
  wire [NEWWIDTH-1:0] memOut27 = uut.memOut[27];
  wire [NEWWIDTH-1:0] memOut28 = uut.memOut[28];
  wire [NEWWIDTH-1:0] memOut29 = uut.memOut[29];
  wire [NEWWIDTH-1:0] memOut30 = uut.memOut[30];
  wire [NEWWIDTH-1:0] memOut31 = uut.memOut[31];
  wire [NEWWIDTH-1:0] memOut32 = uut.memOut[32];
  wire [NEWWIDTH-1:0] memOut33 = uut.memOut[33];
  wire [NEWWIDTH-1:0] memOut34 = uut.memOut[34];
  wire [NEWWIDTH-1:0] memOut35 = uut.memOut[35];
  wire [NEWWIDTH-1:0] memOut36 = uut.memOut[36];
  wire [NEWWIDTH-1:0] memOut37 = uut.memOut[37];
  wire [NEWWIDTH-1:0] memOut38 = uut.memOut[38];
  wire [NEWWIDTH-1:0] memOut39 = uut.memOut[39];

  // ---- Probe wires: postfix[0..39] (44-bit) ----
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
  wire [NEWWIDTH-1:0] postfix20 = uut.postfix[20];
  wire [NEWWIDTH-1:0] postfix21 = uut.postfix[21];
  wire [NEWWIDTH-1:0] postfix22 = uut.postfix[22];
  wire [NEWWIDTH-1:0] postfix23 = uut.postfix[23];
  wire [NEWWIDTH-1:0] postfix24 = uut.postfix[24];
  wire [NEWWIDTH-1:0] postfix25 = uut.postfix[25];
  wire [NEWWIDTH-1:0] postfix26 = uut.postfix[26];
  wire [NEWWIDTH-1:0] postfix27 = uut.postfix[27];
  wire [NEWWIDTH-1:0] postfix28 = uut.postfix[28];
  wire [NEWWIDTH-1:0] postfix29 = uut.postfix[29];
  wire [NEWWIDTH-1:0] postfix30 = uut.postfix[30];
  wire [NEWWIDTH-1:0] postfix31 = uut.postfix[31];
  wire [NEWWIDTH-1:0] postfix32 = uut.postfix[32];
  wire [NEWWIDTH-1:0] postfix33 = uut.postfix[33];
  wire [NEWWIDTH-1:0] postfix34 = uut.postfix[34];
  wire [NEWWIDTH-1:0] postfix35 = uut.postfix[35];
  wire [NEWWIDTH-1:0] postfix36 = uut.postfix[36];
  wire [NEWWIDTH-1:0] postfix37 = uut.postfix[37];
  wire [NEWWIDTH-1:0] postfix38 = uut.postfix[38];
  wire [NEWWIDTH-1:0] postfix39 = uut.postfix[39];

  wire [$clog2(DEPTH+1)-1:0] newSize = uut.newSize;

  // clock
  initial clock = 1'b0;
  always #5 clock = ~clock;

  // press helpers (press 2 clocks, release 2 clocks)
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

    // Expression:
    // 4223.419 - sin(3 * exp( tan(7 - pi/2) , log(4.154, e) ))

    press_b_button(4);  // 4
    press_b_button(2);  // 2
    press_b_button(2);  // 2
    press_b_button(3);  // 3
    press_b_button(16); // .
    press_b_button(4);  // 4
    press_b_button(1);  // 1
    press_b_button(9);  // 9

    press_b_button(11); // -
    press_b_button(24); // sin
    press_b_button(14); // (

    press_b_button(3);  // 3
    press_b_button(12); // *

    press_b_button(20); // exp
    press_b_button(14); // (

    press_b_button(26); // tan
    press_b_button(14); // (

    press_b_button(7);  // 7
    press_b_button(11); // -
    press_b_button(19); // pi
    press_b_button(13); // /
    press_b_button(2);  // 2
    press_b_button(15); // )

    press_b_button(17); // ,
    press_b_button(23); // log
    press_b_button(14); // (

    press_b_button(4);  // 4
    press_b_button(16); // .
    press_b_button(1);  // 1
    press_b_button(5);  // 5
    press_b_button(4);  // 4

    press_b_button(17); // ,
    press_b_button(18); // e
    press_b_button(15); // )

    press_b_button(15); // ) closes exp(
    press_b_button(15); // ) closes sin(

    // run numBuilder
    press_eval();

    #1000;
    $finish;
  end

endmodule
