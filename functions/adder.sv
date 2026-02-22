`timescale 1ns / 1ps

// multiply by 10: y = (x << 3) + (x << 1);
module adder(
    input clock, reset,

    input eval,
    output reg done,

    input signA, signB,
    input [33:0] mantA, mantB,
    input signed [6:0] expA, expB,

    output reg signRes,
    output reg [33:0] mantRes,
    output reg signed  [6:0] expRes
);


    localparam [34:0] M_MAX = 35'd17179869183;
    reg signL = 0;
    reg signS = 0;
    reg [33:0] mantL = 0;
    reg [33:0] mantS = 0;
    reg signed [6:0] expL = 0;
    reg signed [6:0] expS = 0;

    //intermediate non normalized Sum and Exponents
    
    reg signSum; //actually dont need this, but writing anyway to group these 3 
    reg [34:0] mantSum; 
    reg signed [6:0] expSum; 
    

    

    reg [6:0] n;
    reg [6:0] d;

    reg [6:0] nTemp;
    reg [6:0] dTemp;
    reg [6:0] dnTemp;


    wire [3:0] nWire;
    mul10Count mul10(
        .x(mantL),
        .nWire(nWire)
    );

    typedef enum logic [2:0] {
    S_IDLE          = 3'd0,
    S_FIND_ND       = 3'd1,
    S_CASE          = 3'd2,
    S_CASE_A        = 3'd3,
    S_CASE_B        = 3'd4,
    S_EVAL          = 3'd5,
    S_FINALIZATION  = 3'd6,
    S_DONE          = 3'd7
    } state_t;
    state_t state;

    reg evalPrevState = 0;
    wire doEval = eval && !evalPrevState;

    integer k;

    always @(posedge clock or posedge reset) begin
        
        done <= 0; //just for safety

        if (reset) begin
            // FSM / handshake
            state         <= S_IDLE;
            done          <= 1'b0;
            evalPrevState <= 1'b0;

            // outputs
            signRes <= 1'b0;
            mantRes <= 34'd0;
            expRes  <= '0;

            // latched operands
            signL <= 1'b0;  signS <= 1'b0;
            mantL <= 34'd0; mantS <= 34'd0;
            expL  <= '0;    expS  <= '0;

            // alignment counters / temps
            n     <= 7'd0;
            d     <= 7'd0;
            nTemp <= 7'd0;
            dTemp <= 7'd0;
            dnTemp<= 7'd0;

            // intermediate result regs
            signSum <= 1'b0;
            mantSum <= 35'd0;
            expSum  <= '0;
        end

        else begin

            case (state)


                //added this module so that i can actually get a pulse
                S_IDLE: begin
                    done <= 0;
                    if (doEval) begin

                        if(expA > expB) begin
                            {signL, mantL, expL} <= {signA, mantA, expA};
                            {signS, mantS, expS} <= {signB, mantB, expB};
                        end

                        else if(expA <= expB) begin
                            {signS, mantS, expS} <= {signA, mantA, expA};
                            {signL, mantL, expL} <= {signB, mantB, expB};
                        end


                        state <= S_FIND_ND;
                    end
                end  
                
                S_FIND_ND: begin
                    n <= {3'b000, nWire};
                    d <= expL - expS;
                    state <= S_CASE;

                end

                S_CASE: begin //chooe between case A or case B

                    if(n >= d) begin

                        dTemp <= d;

                        state <= S_CASE_A;
                    end
                    
                    else begin

                        nTemp <= n;
                        dnTemp <= d-n;

                        state <= S_CASE_B;
                    end
                end


                //case a: n>=d, so do (mantissa X 10)&(exp--) on large:  (d times)
                S_CASE_A: begin 

                    if(dTemp > 0) begin
                        mantL <= mantL * 10; 
                        expL <= expL - 1;
                        dTemp <= dTemp - 1;
                    end

                    else begin

                        state <= S_EVAL;
                    end
                end

                S_CASE_B: begin
                    if(nTemp > 0) begin
                        mantL <= mantL * 10; 
                        expL <= expL - 1;
                        nTemp <= nTemp - 1;
                    end

                    if(dnTemp > 0) begin
                        mantS <= mantS / 10; 
                        expS <= expS + 1;
                        dnTemp <= dnTemp - 1;
                    end

                    if(nTemp == 0 && dnTemp == 0) begin
                        state <= S_EVAL;
                    end
                end


                // since exponents are notmalized, we can just look at sign and mantissa to see which number is bigger
                S_EVAL: begin 

                    if(signL == 0 && signS == 0) begin //both positive, simple add, signSum is +v
                   
                        signSum <= 0; // since both are +ve, result also positive
                        mantSum <= {1'b0, mantL} + {1'b0 ,mantS};
                        expSum <= expL; // since normalization is done, dosent matter which exponent you give it
                    end

                    else if(signL == 1 && signS == 1) begin // Both S & L is -ve
                        signSum <= 1; // since both are +ve, result also positive
                        mantSum <= {1'b0, mantL} + {1'b0, mantS};
                        expSum <= expL; // since normalization is done, dosent matter which exponent you give it
                    end

                    else if(signL == 0 && signS == 1) begin // L is +ve, S is -ve


                        if(mantL > mantS) begin //if +ve's magnitude is larger:

                            signSum <= 0; 
                            mantSum <= {1'b0, mantL} - {1'b0, mantS};
                            expSum <= expL;
                        end

                        else if(mantL < mantS) begin //if -ve's magnitude is larger:
                            
                            signSum <= 1; 
                            mantSum <= {1'b0, mantS} - {1'b0, mantL};  
                            expSum <= expL;
                        end

                        else if(mantL == mantS) begin // if both have equal magnitude
                            
                            signSum <= 0; 
                            mantSum <= 0; 
                            expSum <= 0;    //if diff is 0, make exp 0 too coz why not
                        end


                    end

                    else if(signL == 1 && signS == 0) begin // L is -ve, S is +ve


                        if(mantL > mantS) begin //if -ve's magnitude is larger:

                            signSum <= 1; 
                            mantSum <= {1'b0, mantL} - {1'b0, mantS};
                            expSum <= expL;
                        end

                        else if(mantL < mantS) begin //if +ve's magnitude is larger:
                            
                            signSum <= 0; 
                            mantSum <= {1'b0, mantS} - {1'b0, mantL};  
                            expSum <= expL;
                        end

                        else if(mantL == mantS) begin // if both have equal magnitude
                            
                            signSum <= 0; 
                            mantSum <= 0; 
                            expSum <= 0;    //if diff is 0, make exp 0 too coz why not
                        end


                    end

                    
                    state <= S_FINALIZATION;   
                end



                S_FINALIZATION: begin // Normalizing hte intermediate regs (mant & exp)
  
                    if (mantSum > M_MAX) begin

                        mantSum <= mantSum / 10;
                        expSum <= expSum + 1;
                    end

                    else begin

                        signRes <= signSum;
                        mantRes <= mantSum[33 : 0];
                        expRes <= expSum;
                        
                        state <= S_DONE;
                    end

                end

                S_DONE: begin // Normalizing hte intermediate regs (mant & exp)

                    done <= 1;
                    state <= S_IDLE;
                end

                default: state <= S_IDLE;

            endcase

            evalPrevState <= eval;
        end

    end


endmodule

