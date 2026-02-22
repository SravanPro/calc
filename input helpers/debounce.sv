`timescale 1ns / 1ps

module debounce #(
    parameter integer WIDTH        = 32,          // number of inputs
    parameter integer CLK_FREQ     = 50_000_000,   // Hz
    parameter integer DEBOUNCE_MS  = 10            // milliseconds
)(
    input  wire                 clk,
    input  wire                 rst,
    input  wire [WIDTH-1:0]     raw,
    output reg  [WIDTH-1:0]     debounced
);

    // ------------------------------------------------------------
    // Timing
    // ------------------------------------------------------------
    localparam integer TICKS      = (CLK_FREQ / 1000) * DEBOUNCE_MS;
    localparam integer TICK_WIDTH = $clog2(TICKS);

    reg [TICK_WIDTH-1:0] tick_cnt;
    wire tick;

    always @(posedge clk or posedge rst) begin
        if (rst)
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
    reg [WIDTH-1:0] sync_0, sync_1;

    always @(posedge clk) begin
        sync_0 <= raw;
        sync_1 <= sync_0;
    end

    // ------------------------------------------------------------
    // Debounce logic
    // ------------------------------------------------------------
    reg [WIDTH-1:0] stable_sample;

    always @(posedge clk or posedge rst) begin
        if (rst) begin
            debounced     <= {WIDTH{1'b0}};
            stable_sample <= {WIDTH{1'b0}};
        end else if (tick) begin
            debounced     <= (sync_1 == stable_sample) ? sync_1 : debounced;
            stable_sample <= sync_1;
        end
    end

endmodule