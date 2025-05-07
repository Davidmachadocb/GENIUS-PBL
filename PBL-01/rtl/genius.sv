import typedefs::*;

module genius #(
    parameter DATA_WIDTH = 4
)(
    // basic signals
    input  logic clk,
    input  logic rst_n,

    // player input
    input  logic start,
    input  logic btn_green,
    input  logic btn_red,
    input  logic btn_blue,
    input  logic btn_yellow,

    // game configs
    input  gamemode_t   gm_switch,
    input  difficulty_t diff_switch,
    input  velocity_t   speed_switch,

    // win flag
    output logic win,
    output logic lost,

    // Leds
    output logic led_red,
    output logic led_blue,
    output logic led_green,
    output logic led_yellow
);

    state_t current_s, next_s, previous_s;

    // Random number generator
    logic load_seed;
    logic [DATA_WIDTH-1:0] seed = 4'b1001;
    logic [1:0] rnd;

    lfsr #(.DATA_WIDTH(DATA_WIDTH)) rng (
        .clk    (clk),
        .rst_n  (rst_n),
        .load   (load_seed),
        .data_in(seed),
        .rnd    (rnd)
    );

    // Counter for led
    logic flag_counter;
    logic crtl_rst;
    logic [1:0] led_state;   // 0=LED on, 1=LED off (pause)
    counter #(.COUNTER_WIDTH(5)) clock_counter (
        .clk    (clk),
        .rst_n  (crtl_rst),
        .flag   (flag_counter)
    );

    // Sequences of both player and game/adversary
    color_t game_seq   [0:31];
    color_t player_seq [0:31];

    logic [4:0] idx;         // index for player
    logic [4:0] idx_leds;    // index for show leds
    logic [4:0] len;         // current sequence length/score
    logic [4:0] diff_count;  // length based on difficulty

    // Mando eu
    logic player1_turn;
    logic player2_turn;      
    logic add_color_mode;

    logic player1_win;
    logic player2_win;

    // Edge-detected button signals
    logic btn_green_edge, btn_red_edge, btn_blue_edge, btn_yellow_edge;

    // LED driver signals
    logic led_enable;
    color_t led_color;

    // LED driver instance
    led_driver led_controller (
        .enable     (led_enable),
        .color      (led_color),
        .led_red    (led_red),
        .led_blue   (led_blue),
        .led_green  (led_green),
        .led_yellow (led_yellow)
    );

    //edge detector
    button_edge_detector button_detector (
        .clk            (clk),
        .rst_n          (rst_n),
        .btn_green      (btn_green),
        .btn_red        (btn_red),
        .btn_blue       (btn_blue),
        .btn_yellow     (btn_yellow),
        .btn_green_edge (btn_green_edge),
        .btn_red_edge   (btn_red_edge),
        .btn_blue_edge  (btn_blue_edge),
        .btn_yellow_edge(btn_yellow_edge)
    );

    // SEQUENTIAL LOGIC
    always_ff @(posedge clk or negedge rst_n) begin
        if (!rst_n) begin
            current_s       <= ST_IDLE;
            previous_s      <= ST_IDLE;
            idx             <= '0;
            len             <= '0;
            diff_count      <= 6'd0;
            player1_turn    <= 1'b1;
            player2_turn    <= 1'b0;
            add_color_mode  <= 1'b0;
            player1_win     <= 1'b0;
            player2_win     <= 1'b0;
            idx_leds        <= 'b0;
            led_state       <= 2'd0;
            load_seed       <= 1'b1;
            led_enable      <= 1'b0;
            led_color       <= COLOR_RED;
            
            // Initialize counter reset
            crtl_rst    <= 1'b0;
        end else begin
            previous_s  <= current_s;
            current_s   <= next_s;

            case (current_s)
                ST_IDLE: begin
                    load_seed       <= 1'b0;
                    win             <= 1'b0;
                    lost            <= 1'b0;
                    player1_turn    <= 1'b1;
                    player2_turn    <= 1'b0;
                    add_color_mode  <= 1'b0;
                    player1_win     <= 1'b0;
                    player2_win     <= 1'b0;
                    led_state       <= 2'd0;
                    
                    // Reset all LEDs using LED driver
                    led_enable      <= 1'b0;
                    
                    // Set difficulty
                    case (diff_switch)
                        DIFF_EASY:   diff_count <= 6'd8;
                        DIFF_MEDIUM: diff_count <= 6'd16;
                        DIFF_HARD:   diff_count <= 6'd32;
                    endcase
                    
                    // 
                    if (gm_switch == GAMEMODE_ME) begin
                        len <= 3'd0;
                    end
                end

                ST_GEN: begin
                    // Reset all LEDs using LED driver
                    led_enable <= 1'b0;
                    
                    if (gm_switch == GAMEMODE_ME && len == 0) begin
                        game_seq[0] <= color_t'(rnd);
                        len <= 6'd1;
                    end else if (gm_switch == GAMEMODE_FOLLOW) begin
                        game_seq[len] <= color_t'(rnd);
                        len <= len + 1;
                    end

                    idx       <= 1'b0;
                    idx_leds  <= 1'b0;
                    led_state <= 2'd0;
                    crtl_rst  <= 1'b1;
                end

                ST_SHOW_LEDS: begin
                    // Default: all LEDs off
                    led_enable <= 1'b0;
                    crtl_rst <= 1'b1;

                    if (idx_leds < len) begin
                        case (led_state)
                            2'd0: begin // LED ON state
                                led_enable <= 1'b1;
                                led_color <= game_seq[idx_leds];

                                // If counter flag is high, move to LED OFF state
                                if (flag_counter) begin
                                    led_state <= 2'd1;
                                    crtl_rst <= 1'b0;  // Reset counter
                                end
                            end
                            
                            2'd1: begin //(pause between colors)
                                led_enable <= 1'b0;
                                if (flag_counter) begin
                                    idx_leds    <= idx_leds + 1'b1;
                                    led_state   <= 2'd0;
                                    crtl_rst    <= 1'b0;
                                end
                            end
                            
                            default: led_state <= 2'd0;
                        endcase
                    end
                end

                ST_PLAYER_IN: begin
                    // Reset all LEDs using LED driver
                    led_enable <= 1'b0;
                    crtl_rst   <= 1'b0;
                    
                    if (previous_s != ST_PLAYER_IN) idx <= 0;   // Reset player index

                    if (idx < len) begin
                        if (btn_blue_edge) begin   
                            player_seq[idx] <= COLOR_BLUE;
                            led_enable <= 1'b1;
                            led_color <= COLOR_BLUE;     
                        end    
                        else if (btn_green_edge) begin
                            player_seq[idx] <= COLOR_GREEN;
                            led_enable <= 1'b1;
                            led_color <= COLOR_GREEN;
                        end
                        else if (btn_red_edge) begin    
                            player_seq[idx] <= COLOR_RED;
                            led_enable <= 1'b1;
                            led_color <= COLOR_RED;
                        end
                        else if (btn_yellow_edge) begin
                            player_seq[idx] <= COLOR_YELLOW;
                            led_enable <= 1'b1;
                            led_color <= COLOR_YELLOW;
                        end
                        
                        // Increment index
                        if (btn_blue_edge | btn_green_edge | btn_red_edge | btn_yellow_edge) begin
                            idx <= idx + 1;
                        end
                    end
                end

                ST_EVAL: begin
                    // Turn off all LEDs
                    led_enable <= 1'b0;
                    idx <= '0;
                    
                    //"Mando eu" toggle player turn
                    if (gm_switch == GAMEMODE_ME && !lost) begin
                        player1_turn <= !player1_turn;
                        player2_turn <= !player2_turn;
                        add_color_mode <= 1'b1;
                    end
                end

                ST_ADD_COLOR: begin
                    // Reset all LEDs using LED driver
                    led_enable <= 1'b0;

                    //FIX: REMOVE THE ADD_COLOR_MODE?? TEST IT OUT

                    if (add_color_mode && idx == 0) begin
                        if (btn_blue_edge) begin   
                            game_seq[len] <= COLOR_BLUE;
                            led_enable <= 1'b1;
                            led_color <= COLOR_BLUE;
                            idx <= idx + 1;
                            len <= len + 1;
                            add_color_mode <= 1'b0; 
                        end    
                        else if (btn_green_edge) begin
                            game_seq[len] <= COLOR_GREEN;
                            led_enable <= 1'b1;
                            led_color <= COLOR_GREEN;
                            idx <= idx + 1;
                            len <= len + 1;
                            add_color_mode <= 1'b0; 
                        end
                        else if (btn_red_edge) begin    
                            game_seq[len] <= COLOR_RED;
                            led_enable <= 1'b1;
                            led_color <= COLOR_RED;
                            idx <= idx + 1;
                            len <= len + 1;
                            add_color_mode <= 1'b0; 
                        end
                        else if (btn_yellow_edge) begin
                            game_seq[len] <= COLOR_YELLOW;
                            led_enable <= 1'b1;
                            led_color <= COLOR_YELLOW;
                            idx <= idx + 1;
                            len <= len + 1;
                            add_color_mode <= 1'b0; 
                        end
                    end
                    
                    if (btn_blue_edge | btn_green_edge | btn_red_edge | btn_yellow_edge) begin
                        player1_turn <= !player1_turn;
                        player2_turn <= !player2_turn;
                    end
                end

                ST_END: begin
                    if(gm_switch == GAMEMODE_ME) begin
                        if (player1_win)
                            win <= 1'b1;
                        else if (player2_win)
                            lost <= 1'b1;
                    end
                end

            endcase
        end
    end

    // COMBINATIONAL LOGIC
    always_comb begin
        next_s = current_s;

        case (current_s)
            ST_IDLE: begin
                if (start)
                    next_s = ST_GEN;
            end

            ST_GEN: begin
                next_s = ST_SHOW_LEDS;
            end

            ST_SHOW_LEDS: begin
                if (idx_leds >= len) begin
                    next_s = ST_PLAYER_IN;
                end
            end

            ST_PLAYER_IN: begin
                if (idx > 0 && player_seq[idx-1] != game_seq[idx-1]) begin // Check if mistake
                    next_s = ST_END;
                    if (gm_switch == GAMEMODE_ME) begin
                        if (player1_turn)
                            player2_win = 1'b1;
                        else
                            player1_win = 1'b1;
                    end else begin
                        lost = 1'b1;
                    end
                end 
                else if (idx == len) begin
                    next_s = ST_EVAL;
                end
            end

            ST_EVAL: begin
                if (!lost) begin
                    if (gm_switch == GAMEMODE_FOLLOW) begin
                        if (len >= diff_count) begin
                            win = 1'b1;
                            next_s = ST_END;
                        end else begin
                            next_s = ST_GEN; // Continue adding colors
                        end
                    end else begin
                        if (len >= 32) begin
                            next_s = ST_END;
                            win = 1'b1; // FIX THIS
                        end else begin
                            next_s = ST_ADD_COLOR;
                        end
                    end
                end else begin
                    next_s = ST_END; // Game over
                end
            end

            ST_ADD_COLOR: begin
                if (idx > 0) begin
                    next_s = ST_PLAYER_IN;
                end
            end

            ST_END: begin
                if (start)
                    next_s = ST_IDLE; // Reset game when start pressed
            end
        endcase
    end

endmodule