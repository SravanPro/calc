`timescale 1ns / 1ps

module spiInterface 
    #(
        parameter buttons = 27,
        parameter page = 16,
        parameter depth = 32,
        parameter width = 8,
        parameter newWidth = 44
    )(

        // global inputs
        input clock, reset,

        // inputs from keyboard
        input jump,
        input [newWidth-1:0] answer,
        input [width-1 : 0] mem [depth-1 : 0],
        input [$clog2(depth+1)-1:0] sizeOut, //6 bits wide if depth is 32
        input [$clog2(depth+1)-1:0] ptrOut,  //6 bits wide if depth is 32

        //outputs
        // to send:
        // ptr info, 
        output reg sclk,
        output reg mosi,
        output reg cs
    );

    typedef enum logic [2:0] {
        
   
        
        S_FIRST,
        S_SECOND,
        S_POINTERS,
        S_LAST,
        S_DONE        
    } state_t;

    state_t state;






    wire jumpUpdate = jump;
    reg jumpUpdatePrevState;
    wire doJumpUpdate = jumpUpdate & ~jumpUpdatePrevState;

    reg currPage;

    // on arduino side, everything above size will be blank, junk values
    wire [7:0] size = {2'b00, sizeOut};
    // this is so that the arduino can display a pointer.
    wire [7:0] ptr = {2'b00, ptrOut};

    wire [47:0] last = {3'b0, currPage, answer};


    
    // Which byte in mem are we currently sending?
    reg [4:0] byteIndex; // 0 -> 31

    // Which bit of that byte are we currently sending?
    reg [2:0] bitIndex;  // 7-> 0

    // clock divider
    reg [7:0] clockDivider; 
    parameter CLK_DIV_MAX = 50; // Adjust this: 50 = 1MHz SPI if Clock is 100MHz (approx)


    reg [7:0] frameDelay;

    reg ptrPhase; // 0 = size, 1 = ptr
    reg [5:0] lastBitIndex; // 0 to 47



    always @(posedge clock or posedge reset) begin


        if (reset) begin
        // SPI pins to safe idle
            cs <= 1'b1;
            sclk <= 1'b0;
            mosi <= 1'b0;

            // FSM
            state <= S_FIRST;

            // Page / edge detect
            currPage <= 1'b0;
            jumpUpdatePrevState <= 1'b0;

            // Counters
            byteIndex <= 5'd0;
            bitIndex <= 3'd7;
            clockDivider <= 8'd0;
            frameDelay <= 0;
            ptrPhase <= 0;  
            lastBitIndex <= 0;

        end
                
        else begin

            if(doJumpUpdate) begin
                currPage <= ~currPage;
            end

            if (clockDivider < CLK_DIV_MAX) begin
                clockDivider <= clockDivider + 1;
            end 

            else begin
                clockDivider <= 0;

                case(state)

                    S_FIRST: begin

                        sclk <= 0;    
                        cs <= 0;   
                        bitIndex <= 7;        // MSB first
                        clockDivider <= 0;    // Reset timer


                        if (currPage == 0) begin
                            byteIndex <= 0;   
                            mosi <= mem[0][7];
                        end
                        else begin
                            byteIndex <= 16;  
                            mosi <= mem[16][7];
                        end


                        state <= S_SECOND;
                        
                    end

                    S_SECOND: begin
                                        
                        // Toggle the SPI Clock
                        sclk <= ~sclk; 
                        
                        if (sclk == 1) begin // falling edge 
                            // This is when we change the data for the next bit.
                            
                            // LOGIC: Move to next bit
                            if (bitIndex == 0) begin
                                bitIndex <= 7; // Reset bit counter
                                
                                // Check if we finished the page (16 bytes)
                                if (byteIndex == 15 || byteIndex == 31) begin
                                    state <= S_POINTERS; 
                                    mosi <= size[7]; 
                                    ptrPhase <= 0;
                                end 
                                else begin
                                    byteIndex <= byteIndex + 1; // Next byte
                                    mosi <= mem[byteIndex + 1][7]; 
                                end
                            end 
                            
                            else begin
                                bitIndex <= bitIndex - 1; // Next bit
                                mosi <= mem[byteIndex][bitIndex - 1];
                            end

                        end


                    end

                    S_POINTERS: begin
                         sclk <= ~sclk;

                         if (sclk == 1) begin // falling edge
                            if (bitIndex == 0) begin
                                bitIndex <= 7;

                                if (ptrPhase == 0) begin
                                    // Finished SIZE, now setup PTR
                                    ptrPhase <= 1;
                                    mosi <= ptr[7]; 
                                end 
                                
                                else begin
                                    // Finished PTR, now go to ANSWER state
                                    state <= S_LAST;
                                    lastBitIndex <= 47; // Start at MSB of the 48-bit 'last'
                                    mosi <= last[47];
                                end
                            end else begin
                                bitIndex <= bitIndex - 1;
                                if (ptrPhase == 0) mosi <= size[bitIndex - 1];
                                else mosi <= ptr[bitIndex - 1];
                            end
                         end
                    end

                    S_LAST: begin
                        sclk <= ~sclk;
                        if (sclk == 1) begin // falling edge
                            if (lastBitIndex == 0) begin
                                // Entire 48-bit sequence sent
                                state <= S_DONE;
                                mosi <= 0;
                            end else begin
                                lastBitIndex <= lastBitIndex - 1;
                                mosi <= last[lastBitIndex - 1]; // Shift out the 48-bit 'last' wire
                            end
                        end
                    end

                    S_DONE: begin

                        if (frameDelay < 8'd200) begin  // Wait ~200 slow-ticks
                            frameDelay <= frameDelay + 1;
                        end 
                        
                        else begin
                            frameDelay <= 0;      // Reset for next time
                            state <= S_FIRST;     // Go restart
                        end  
                        cs <= 1;      // Stop talking
                        sclk<= 0;
                    end

                    default: begin
                        state <= S_FIRST;  
                        cs<=1; 
                        sclk<=0;
                        mosi <= 0;
                    end
                    
                endcase

            end
            
            
        end

        jumpUpdatePrevState <= jumpUpdate;
    end
endmodule
