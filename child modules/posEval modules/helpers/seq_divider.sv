`timescale 1ns / 1ps

//  Sequential binary long-division (restoring shift-subtract).
//  Computes:  quotient     = floor(dividend / divisor)
//             remainder_out = dividend % divisor
module seq_divider #(
    parameter WIDTH = 512          // dividend / divisor / quotient width
)(
    input clock, reset,

    // Control
    input start,         // 1-cycle pulse to begin
    output reg done,          // 1-cycle pulse when finished

    // Data
    input  [WIDTH-1:0] dividend,
    input  [WIDTH-1:0] divisor,
    output reg  [WIDTH-1:0] quotient,
    output reg  [WIDTH-1:0] remainder_out
);

    //  Internal registers
    reg [WIDTH-1:0] D;          // latched divisor
    reg [WIDTH-1:0] dvd_work;   // dividend shifted left each cycle
    reg [WIDTH-1:0] R;          // partial remainder (fits in WIDTH bits)
    reg [WIDTH-1:0] Q;          // quotient accumulator
    reg [9:0] cnt;        // counts down from WIDTH to 0
    reg  busy;

    //  Combinational: shift partial remainder left and
    //  bring in the next dividend bit.
    //  R_shift is WIDTH+1 bits to detect whether the result
    //  of the subtraction is negative (borrow in MSB).
    wire [WIDTH:0] R_shift = {R, dvd_work[WIDTH-1]};   // shift left 1, bring in bit
    wire [WIDTH:0] R_sub = R_shift - {1'b0, D};      // tentative subtract

    //  Sequential logic
    always @(posedge clock or posedge reset) begin
        if (reset) begin
            done          <= 1'b0;
            busy          <= 1'b0;
            quotient      <= {WIDTH{1'b0}};
            remainder_out <= {WIDTH{1'b0}};
            D             <= {WIDTH{1'b0}};
            dvd_work      <= {WIDTH{1'b0}};
            R             <= {WIDTH{1'b0}};
            Q             <= {WIDTH{1'b0}};
            cnt           <= 10'd0;
        end else begin
            done <= 1'b0;                   // default: not done

            if (start && !busy) begin
                // Latch inputs and begin computation
                D        <= divisor;
                dvd_work <= dividend;
                R        <= {WIDTH{1'b0}};
                Q        <= {WIDTH{1'b0}};
                cnt      <= WIDTH[9:0];    
                busy     <= 1'b1;
            end else if (busy) begin
                if (cnt > 10'd0) begin
                    // One restoring-division step 
                    // If R_shift >= D (no borrow in MSB of R_sub):
                    //   accept the subtraction, quotient bit = 1
                    // else:
                    //   keep R_shift, quotient bit = 0
                    if (!R_sub[WIDTH]) begin
                        R <= R_sub[WIDTH-1:0];
                        Q <= {Q[WIDTH-2:0], 1'b1};
                    end else begin
                        R <= R_shift[WIDTH-1:0];
                        Q <= {Q[WIDTH-2:0], 1'b0};
                    end
                    dvd_work <= {dvd_work[WIDTH-2:0], 1'b0};   // shift dividend
                    cnt      <= cnt - 10'd1;
                end else begin
                    // All WIDTH bits processed 
                    quotient      <= Q;
                    remainder_out <= R;
                    done          <= 1'b1;
                    busy          <= 1'b0;
                end
            end
        end
    end

endmodule