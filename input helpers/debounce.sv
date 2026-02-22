`timescale 1ns / 1ps

module debouncer #(
    parameter width        = 5,          // number of inputs
    parameter freq     = 50000000,   // Hz
    parameter debounceTime  = 10            // milliseconds
)(
    input  wire                 clock,
    input  wire                 reset,
    input  wire [width-1:0]     raw,
    output reg  [width-1:0]     debounced
);

    // ------------------------------------------------------------
    // Timing
    // ------------------------------------------------------------
    localparam integer TICKS      = (freq / 1000) * debounceTime;
    localparam integer TICK_WIDTH = $clog2(TICKS);

    reg [TICK_WIDTH-1:0] tick_cnt;
    wire tick;

    always @(posedge clock or posedge reset) begin
        if (reset)
            tick_cnt <= 0;
        else if (tick_cnt == TICKS - 1)
            tick_cnt <= 0;
        else
            tick_cnt <= tick_cnt + 1;
    end

    assign tick = (tick_cnt == TICKS - 1);

    // ------------------------------------------------------------
    // Synchronizer
    // ------------------------------------------------------------
    reg [width-1:0] sync_0, sync_1;

    always @(posedge clock) begin
        sync_0 <= raw;
        sync_1 <= sync_0;
    end

    // ------------------------------------------------------------
    // Debounce logic
    // ------------------------------------------------------------
    reg [width-1:0] stable_sample;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            debounced     <= {width{1'b1}};
            stable_sample <= {width{1'b1}};
        end else if (tick) begin
            debounced     <= (sync_1 == stable_sample) ? sync_1 : debounced;
            stable_sample <= sync_1;
        end
    end

endmodule