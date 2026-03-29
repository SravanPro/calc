`timescale 1ns / 1ps

module decoder(
    input  wire [4:0]  in, // Active Low Inputs
    output reg  [31:0] out   // Active High Outputs
);

    always @(*) begin
        // Set all outputs to 0 first (default state)
        out = 32'b0;
        
        // Invert the active-low input to get the binary index
        out[~in] = 1'b1;
    end

endmodule
