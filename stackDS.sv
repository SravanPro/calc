module stack #(
    parameter width = 44,
    parameter depth = 30

)(
    input wire clock, reset,
    input wire [width-1 : 0] dataIn,
    
    input wire push,pop,

    output reg [width-1 : 0] dataOut,
    output wire empty, full,
    output wire [width-1 : 0] top

);
    
    // "i" acts as count, not as index.
    reg [$clog2(depth+1)-1:0] i;

    assign empty = (i == 0);
    assign full  = (i == $clog2(depth+1)'(depth));
    
    
    reg [width-1 : 0] mem [depth-1 : 0];

    assign top = mem[i-1];

    always @(posedge clock or posedge reset) begin

        if(reset) begin
            //for(k = 0; k<depth; k++) mem[k] <= '0; commented out since in stack, everything above pointer is dont care
            dataOut <= 0;

            i <= 0;
        end

        else begin

            if(push && !pop && i < depth) begin
                mem[i] <= dataIn;
                i <= i+1;
                
            end

            else if(pop && !push && i>0) begin
                i <= i-1;
                dataOut <= mem[i-1];
            end 

        end
    end
endmodule