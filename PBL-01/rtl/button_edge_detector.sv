module button_edge_detector (
    input logic clk,
    input logic rst_n,
    input logic btn_green,
    input logic btn_red,
    input logic btn_blue,
    input logic btn_yellow,
    output logic btn_green_edge,
    output logic btn_red_edge,
    output logic btn_blue_edge,
    output logic btn_yellow_edge
);

    // Previous values
    logic btn_green_prev, btn_red_prev, btn_blue_prev, btn_yellow_prev;

    // Register previous button states
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            btn_green_prev <= 1'b0;
            btn_red_prev <= 1'b0;
            btn_blue_prev <= 1'b0;
            btn_yellow_prev <= 1'b0;
        end else begin
            btn_green_prev <= btn_green;
            btn_red_prev <= btn_red;
            btn_blue_prev <= btn_blue;
            btn_yellow_prev <= btn_yellow;
        end
    end

    // Edge detection - output high only on rising edge (when current is 1 and previous was 0)
    assign btn_green_edge = btn_green & ~btn_green_prev;
    assign btn_red_edge = btn_red & ~btn_red_prev;
    assign btn_blue_edge = btn_blue & ~btn_blue_prev;
    assign btn_yellow_edge = btn_yellow & ~btn_yellow_prev;

endmodule