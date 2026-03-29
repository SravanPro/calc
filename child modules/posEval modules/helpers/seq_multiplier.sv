`timescale 1ns / 1ps

//  Sequential shift-and-add multiplier.
//  Computes:  product = multiplicand * multiplier  (unsigned)

//  Implementation: standard LSB-first shift-and-add.
//    Each cycle, if the current LSB of the working multiplier
//    is 1, add multiplicand<<0 (the running partial sum
//    already accounts for positional weight via the shift).
//    Shift multiplicand left and multiplier right each cycle.
module seq_multiplier #(
    parameter WIDTH = 512
)(
    input  wire             clock,
    input  wire             reset,

    input  wire             start,
    output reg              done,

    input  wire [WIDTH-1:0] multiplicand,
    input  wire [WIDTH-1:0] multiplier,
    output reg  [WIDTH-1:0] product
);

    reg [WIDTH-1:0] A;       // shifted multiplicand
    reg [WIDTH-1:0] B;       // shifted-right multiplier
    reg [WIDTH-1:0] P;       // accumulating product
    reg [9:0]       cnt;
    reg             busy;

    always @(posedge clock or posedge reset) begin
        if (reset) begin
            done    <= 1'b0;
            busy    <= 1'b0;
            product <= {WIDTH{1'b0}};
            A       <= {WIDTH{1'b0}};
            B       <= {WIDTH{1'b0}};
            P       <= {WIDTH{1'b0}};
            cnt     <= 10'd0;
        end else begin
            done <= 1'b0;

            if (start && !busy) begin
                A    <= multiplicand;
                B    <= multiplier;
                P    <= {WIDTH{1'b0}};
                cnt  <= WIDTH[9:0];
                busy <= 1'b1;
            end else if (busy) begin
                if (cnt > 10'd0) begin
                    // If current LSB of B is 1, add current A into accumulator
                    if (B[0])
                        P <= P + A;
                    A   <= A << 1;   // shift multiplicand left (weight doubles)
                    B   <= B >> 1;   // shift multiplier right (expose next bit)
                    cnt <= cnt - 10'd1;
                end else begin
                    product <= P;
                    done    <= 1'b1;
                    busy    <= 1'b0;
                end
            end
        end
    end

endmodule