module lfsr #(
    parameter DATA_WIDTH = 4,
    parameter OUTPUT_WIDTH = 2
) (
    input  logic                     clk,
    input  logic                     rst_n,
    input  logic                     load,
    input  logic  [DATA_WIDTH-1:0]   data_in,
    output logic  [DATA_WIDTH-1:0]   data_out,
    output logic  [OUTPUT_WIDTH-1:0] rnd
);

    logic fb = 1'b0;

    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n)
            data_out <= '0;
        else if (load)
            //load seed
            data_out <= data_in;
        else
            //right shift with feedback
            data_out <= {fb, data_out[DATA_WIDTH-1:1]}; 
    end

    always_comb begin
        fb = data_out[0] ^ data_out[1];
    end

    assign rnd = data_out[OUTPUT_WIDTH-1:0];

endmodule