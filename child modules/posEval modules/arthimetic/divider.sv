`timescale 1ns / 1ps

// adder was so tough coz we did 3 things:
// exponent normalization (2 cases, enough or not)
// + - sign cases
// brute add, normalization

// mul will be easier coz for result:
// mant is normalized brute mult, exp is sum, sign is xor of inptut sums 
module divider(
    input clock, reset,

    input eval,
    output reg done,

    input signA, signB,
    input [33:0] mantA, mantB,
    input signed [6:0] expA, expB,

    output reg signRes,
    output reg [33:0] mantRes,
    output reg signed [6:0] expRes
);

    // in division,  the mantX is made 74 bits

    localparam [73:0] M_MAX = 74'd17179869183;
    localparam [39:0] SCALING_FACTOR = 40'd1000000000000; 

    reg signX = 0;
    reg signY = 0;
    reg [33:0] mantX = 0;
    reg [73:0] mantY = 0;
    reg signed [6:0] expX = 0;
    reg signed [6:0] expY = 0;

    //intermediate non normalized Sum and Exponents
    reg signDiv; //actually dont need this, but writing anyway to group these 3 
    reg [73:0] mantDiv; 
    reg signed [6:0] expDiv; 
    

    


    typedef enum logic [1:0] {
    S_IDLE          = 2'd0,
    S_EVAL          = 2'd1,
    S_FINALIZATION  = 2'd2,
    S_DONE          = 2'd3
    } state_t;
    state_t state;

    reg evalPrevState = 0;
    wire doEval = eval && !evalPrevState;

    integer k;

    always @(posedge clock or posedge reset) begin
        
        done <= 0; //just for safety

        if (reset) begin
            // FSM / handshake
            state <= S_IDLE;
            done <= 1'b0;
            evalPrevState <= 1'b0;

            // intermediate result regs
            signDiv <= 1'b0;
            mantDiv <= 74'd0;
            expDiv  <= '0;

            // outputs
            signRes <= 1'b0;
            mantRes <= 34'd0;
            expRes  <= '0;
            

            // latched operands
            signX <= 1'b0;  signY <= 1'b0;
            mantX <= 34'd0; mantY <= 74'd0;
            expX  <= '0;    expY  <= '0;



        end

        else begin

            case (state)

                S_IDLE: begin
                    done <= 0;
                    if (doEval) begin
                                                  
                        signY <= signB;
                        mantY <= {{40'd0, mantB} * {34'b0,SCALING_FACTOR}};
                        expY  <= expB - 7'sd12;

                        signX <= signA;
                        mantX <= mantA;
                        expX  <= expA;

                        state <= S_EVAL;
                    end
                end  
                
                S_EVAL: begin 

                    signDiv <= signX ^ signY;
                    mantDiv <= mantY / mantX;
                    expDiv <= expY - expX;
                    
                    state <= S_FINALIZATION;   
                end



                S_FINALIZATION: begin // Normalizing hte intermediate regs (mant & exp)
  
                    if (mantDiv > M_MAX) begin

                        mantDiv <= mantDiv / 10;
                        expDiv <= expDiv + 1;
                    end

                    else begin

                        signRes <= signDiv;
                        mantRes <= mantDiv[33 : 0];
                        expRes <= expDiv;
                        
                        state <= S_DONE;
                    end

                end

                S_DONE: begin

                    done <= 1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;

            endcase

            evalPrevState <= eval;
        end

    end


endmodule

