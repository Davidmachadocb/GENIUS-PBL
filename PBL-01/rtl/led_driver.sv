import typedefs::*;

module led_driver (
    input logic enable,
    input color_t color,

    output logic led_red,
    output logic led_blue,
    output logic led_green,
    output logic led_yellow
);

    always_comb begin
            led_blue   = 1'b0;
            led_red    = 1'b0;
            led_green  = 1'b0;
            led_yellow = 1'b0;
            
        if(enable) begin
            case (color)
                COLOR_RED:    led_red    = 1'b1;
                COLOR_BLUE:   led_blue   = 1'b1;
                COLOR_GREEN:  led_green  = 1'b1;
                COLOR_YELLOW: led_yellow = 1'b1;
                default: ;        
            endcase
        end
    end

endmodule