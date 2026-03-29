`timescale 1ns / 1ps

module clockDivider (
    input wire clockIn,
    input wire reset,
    output reg clock
);

    reg [5:0] counter;   // counts 0-63

    always @(posedge clockIn or posedge reset) begin
        if (reset) begin
            counter <= 6'd0;
            clock <= 1'b0;
        end else begin
            if (counter == 6'd31) begin
                counter <= 6'd0;
                clock <= ~clock;   // toggle → divide by 64
            end else begin
                counter <= counter + 1'b1;
            end
        end
    end

endmodule