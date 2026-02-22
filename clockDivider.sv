module clockDivider #(parameter n = 7)(
    input clockIn, reset,
    output clockOut
);

    reg count [n-1 : 0];
    assign clockOut = count[n-1];
    always @(posedge clockIn or posedge reset) begin
        if(reset) begin
            count <= 0;
        end
        else begin
            count <= count + 1;
        end
    end
endmodule
