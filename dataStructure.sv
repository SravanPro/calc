`timescale 1ns / 1ps

module dataStructure 
    #(
        parameter depth = 20,
        parameter width = 8
     ) 
     (
        input clock, reset,
        input [width-1 : 0] dataIn,
        input insert, del,
        input ptrLeft, ptrRight,
        
        output reg [width-1 : 0] mem [depth-1 : 0],
        output [$clog2(depth+1)-1:0] sizeOut

    );
    
    // memory

    // regs
    reg insertPrevState   = 0;
    reg delPrevState      = 0;
    reg ptrLeftPrevState  = 0;
    reg ptrRightPrevState = 0;

    reg [$clog2(depth+1)-1:0] ptr  = 0;
    reg [$clog2(depth+1)-1:0] size = 0;

    
    // wires 
    wire doInsert   = insert  && !insertPrevState;
    wire doDelete   = del     && !delPrevState;
    wire doPtrLeft  = ptrLeft && !ptrLeftPrevState;
    wire doPtrRight = ptrRight && !ptrRightPrevState;
    

    assign sizeOut = size;

    

    
    integer i;

    always @(posedge clock) begin
        if (reset) begin
            for (i = 0; i < depth; i = i + 1) mem[i] <= 0;  
            ptr <= 0;
            size <= 0;
            insertPrevState  <= 0;
            delPrevState     <= 0;
            ptrLeftPrevState <= 0;
            ptrRightPrevState <= 0;
        end
        else begin
        
            // INSERT
            if (doInsert && size < depth) begin
                for (i = size; i > ptr; i = i - 1)
                    mem[i] <= mem[i - 1];
                mem[ptr] <= dataIn;
                ptr  <= ptr + 1;
                size <= size + 1;
            end 
                            
            // DELETE
            else if (doDelete && size > 0 && ptr > 0) begin
                
                // CASE A: Backspace in the middle of the list
                // We need to shift items left to fill the gap.
                if (ptr < size) begin
                    for (i = 0; i < depth - 1; i = i + 1) begin
                        // Shift data into the slot we are deleting (ptr-1)
                        // and everything following it.
                        if (i >= ptr - 1 && i < size - 1) begin
                            mem[i] <= mem[i + 1];
                        end
                    end
                end
                
                // CASE B: Backspace at the very end (ptr == size)
                // No shifting needed, but let's zero it out for clean waveforms
                else begin
                    mem[ptr-1] <= 0; 
                end

                // Update counters (Common for both cases)
                size <= size - 1;
                ptr  <= ptr - 1;
            end



       
            // PTR MOVE
            else if (doPtrLeft  && ptr > 0)    ptr <= ptr - 1;
            else if (doPtrRight && ptr < size) ptr <= ptr + 1;

            insertPrevState  <= insert;
            delPrevState     <= del;
            ptrLeftPrevState <= ptrLeft;
            ptrRightPrevState <= ptrRight;
        end
    end
   
endmodule
