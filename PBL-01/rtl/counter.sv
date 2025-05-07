module counter #(
    parameter COUNTER_WIDTH = 5  // Increased width for longer timing
) (
    input logic clk,
    input logic rst_n,
    output logic flag
);
    logic [COUNTER_WIDTH-1:0] c;
    // Define a longer count value for better visibility
    // For real hardware, adjust based on clock frequency
    always_ff @(posedge clk or negedge rst_n) begin
        if(!rst_n) begin
            c <= 'b0;
            flag <= 1'b0;
        end else begin
            if(c >= 5) begin
                flag <= 1'b1;
                c <= 'b0;
            end else begin
                c <= c + 1'b1;
                flag <= 1'b0;  // Only pulse flag high for one clock cycle
            end
        end
    end
endmodule