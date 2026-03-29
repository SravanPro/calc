module mul10Count (
    input  wire [33:0] x,
    output wire [3:0]  nWire   // allowed ×10 count (with margin)
);
    // MAX = 2^34 - 1 = 17179869183
    localparam [33:0] T0  = 34'd17179869183; // k = 0
    localparam [33:0] T1  = 34'd1717986918;  // k = 1
    localparam [33:0] T2  = 34'd171798691;   // k = 2
    localparam [33:0] T3  = 34'd17179869;
    localparam [33:0] T4  = 34'd1717986;
    localparam [33:0] T5  = 34'd171798;
    localparam [33:0] T6  = 34'd17179;
    localparam [33:0] T7  = 34'd1717;
    localparam [33:0] T8  = 34'd171;
    localparam [33:0] T9  = 34'd17;
    localparam [33:0] T10 = 34'd1;

    wire [3:0] n_max;

    // Step 1: true maximum safe count
    assign n_max =
        (x <= T10) ? 4'd10 :
        (x <= T9 ) ? 4'd9  :
        (x <= T8 ) ? 4'd8  :
        (x <= T7 ) ? 4'd7  :
        (x <= T6 ) ? 4'd6  :
        (x <= T5 ) ? 4'd5  :
        (x <= T4 ) ? 4'd4  :
        (x <= T3 ) ? 4'd3  :
        (x <= T2 ) ? 4'd2  :
        (x <= T1 ) ? 4'd1  :
        (x <= T0 ) ? 4'd0  :
                     4'd0;

    // Step 2: apply safety margin = 1
    assign nWire = (n_max > 0) ? (n_max - 1'b1) : 4'd0;

endmodule
