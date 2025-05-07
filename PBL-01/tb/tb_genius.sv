`timescale 1ns/1ps
import typedefs::*;

module tb_genius();
    // Parameters
    parameter CLK_PERIOD = 10; // 10ns = 100MHz
    parameter DATA_WIDTH = 4;
    
    // Input signals
    logic clk;
    logic rst_n;
    logic start;
    logic btn_green;
    logic btn_red;
    logic btn_blue;
    logic btn_yellow;
    gamemode_t gm_switch;
    difficulty_t diff_switch;
    velocity_t speed_switch;
    
    // Output signals
    logic win;
    logic lost;
    logic led_red;
    logic led_blue;
    logic led_green;
    logic led_yellow;
    
    //
    typedef enum logic [2:0] {
        ST_IDLE,
        ST_GEN,
        ST_SHOW_LEDS,
        ST_PLAYER_IN,
        ST_EVAL,
        ST_ADD_COLOR,
        ST_END
    } local_state_t;
        
    // Instanciation of DUT (Device Under Test)
    genius #(
        .DATA_WIDTH(DATA_WIDTH)
    ) dut (
        .clk(clk),
        .rst_n(rst_n),
        .start(start),
        .btn_green(btn_green),
        .btn_red(btn_red),
        .btn_blue(btn_blue),
        .btn_yellow(btn_yellow),
        .gm_switch(gm_switch),
        .diff_switch(diff_switch),
        .speed_switch(speed_switch),
        .win(win),
        .lost(lost),
        .led_red(led_red),
        .led_blue(led_blue),
        .led_green(led_green),
        .led_yellow(led_yellow)
    );
    
    // Clock generation
    always begin
        clk = 1'b0;
        #(CLK_PERIOD/2);
        clk = 1'b1;
        #(CLK_PERIOD/2);
    end
    
    // Task to simulate a button press
    task press_button(input color_t color);
        case (color)
            COLOR_GREEN: begin
                btn_green = 1'b1;
                btn_red = 1'b0;
                btn_blue = 1'b0;
                btn_yellow = 1'b0;
            end
            COLOR_RED: begin
                btn_green = 1'b0;
                btn_red = 1'b1;
                btn_blue = 1'b0;
                btn_yellow = 1'b0;
            end
            COLOR_BLUE: begin
                btn_green = 1'b0;
                btn_red = 1'b0;
                btn_blue = 1'b1;
                btn_yellow = 1'b0;
            end
            COLOR_YELLOW: begin
                btn_green = 1'b0;
                btn_red = 1'b0;
                btn_blue = 1'b0;
                btn_yellow = 1'b1;
            end
        endcase
        #(CLK_PERIOD*3);
        btn_green = 1'b0;
        btn_red = 1'b0;
        btn_blue = 1'b0;
        btn_yellow = 1'b0;
        #(CLK_PERIOD*3);
    endtask
    
    // Task to monitor the game sequence
    task monitor_sequence(input int len);
        $display("Monitoring game sequence up to index %0d", len-1);
        for (int i = 0; i < len; i++) begin
            $display("  Index %0d: Color %s", i, dut.game_seq[i].name());
        end
    endtask
    
    // Task for player to repeat the correct sequence
    task player_repeat_sequence(input int len);
        $display("Player repeating the correct sequence (length %0d)", len);
        for (int i = 0; i < len; i++) begin
            #(CLK_PERIOD*5);
            press_button(dut.game_seq[i]);
            $display("  Index %0d: Player pressed %s", i, dut.game_seq[i].name());
        end
    endtask
    
    // Task for player to add a new color to the sequence
    task player_add_color(input color_t new_color);
        $display("Player adding new color: %s", new_color.name());
        #(CLK_PERIOD*5);
        press_button(new_color);
    endtask
    
    // Task for player to make a mistake in the sequence
    task player_make_mistake(input int len, input int error_idx);
        $display("Player making mistake at index %0d (length %0d)", error_idx, len);
        for (int i = 0; i < len; i++) begin
            #(CLK_PERIOD*5);
            if (i == error_idx) begin
                // Determine a wrong button to press
                color_t wrong_color;
                do begin
                    wrong_color = color_t'($urandom % 4);
                end while (wrong_color == dut.game_seq[i]);
                
                press_button(wrong_color);
                $display("  Index %0d: Player pressed %s (ERROR - should be %s)", 
                         i, wrong_color.name(), dut.game_seq[i].name());
            end else begin
                press_button(dut.game_seq[i]);
                $display("  Index %0d: Player pressed %s", i, dut.game_seq[i].name());
            end
            
            // Stop if we've already made an error
            if (i == error_idx) break;
        end
    endtask
    
    // Wait for state change task
    task wait_for_state(input local_state_t expected_state);
        automatic int timeout = 0;
        while (dut.current_s != expected_state && timeout < 1000) begin
            #(CLK_PERIOD);
            timeout++;
        end
        
        if (timeout >= 1000)
            $display("ERROR: Timeout waiting for state %s", expected_state.name());
    endtask
    
    // Complete round in "Mando eu" mode
    task mando_eu_round(
        input int round_num,
        input color_t player2_add_color,
        input bit player1_makes_mistake = 1,
        input int mistake_idx = 0
    );
        $display("\n=== ROUND %0d ===", round_num);
        
        // Wait for player 1's turn to repeat the sequence
        wait_for_state(ST_PLAYER_IN);
        $display("Player 1's turn to repeat sequence");
        monitor_sequence(dut.len);
        
        if (player1_makes_mistake)
            player_make_mistake(dut.len, mistake_idx);
        else
            player_repeat_sequence(dut.len);
            
        // Check if game ended due to mistake
        if (player1_makes_mistake) begin
            wait_for_state(ST_END);
            return;
        end
        
        // Wait for player 2's turn to add a color
        wait_for_state(ST_ADD_COLOR);
        $display("Player 2's turn to add a color");
        player_add_color(player2_add_color);
        
        #(CLK_PERIOD*10); // Wait for state transitions
    endtask
    
    // Main test procedure
    initial begin
        // Initialization
        rst_n = 1'b0;
        start = 1'b0;
        btn_green = 1'b0;
        btn_red = 1'b0;
        btn_blue = 1'b0;
        btn_yellow = 1'b0;
        gm_switch = GAMEMODE_FOLLOW;       // Mando eu mode
        diff_switch = DIFF_EASY;       // Difficulty doesn't matter in Mando eu
        speed_switch = VELOCITY_SLOW;  // Speed doesn't matter in Mando eu
        
        // Reset
        #(CLK_PERIOD*5);
        rst_n = 1'b1;
        #(CLK_PERIOD*10);
        
        $display("\n=== TEST 1 ===");
        
        // Start game
        start = 1'b1;
        #(CLK_PERIOD*2);
        start = 1'b0;
        #(CLK_PERIOD*5);
        
        // Round 1
        repeat(8) begin
            wait_for_state(ST_PLAYER_IN);
            player_repeat_sequence(dut.len);
        end

        /*/ Check results
        #(CLK_PERIOD*10);
        if (lost && !win)
            $display("\nSUCCESS: Player 1 lost as expected!");
        else if (win && !lost)
            $display("\nSUCCESS: Player 2 won as expected!");
        else
            $display("\nERROR: Unexpected outcome: win=%b, lost=%b", win, lost);
        
        // Reset for another test
        #(CLK_PERIOD*20);
        rst_n = 1'b0;
        #(CLK_PERIOD*10);
        rst_n = 1'b1;
        #(CLK_PERIOD*10);
        
        $display("\n=== TEST 2: SUCCESSFUL LONG MANDO EU GAME (6 rounds) ===");
        
        // Start game
        start = 1'b1;
        #(CLK_PERIOD*2);
        start = 1'b0;
        #(CLK_PERIOD*5);
        
        // A sequence of 6 successful rounds
        mando_eu_round(1, COLOR_GREEN);
        mando_eu_round(2, COLOR_RED);
        mando_eu_round(3, COLOR_BLUE);
        mando_eu_round(4, COLOR_YELLOW);
        mando_eu_round(5, COLOR_GREEN);
        mando_eu_round(6, COLOR_RED);
        
        // Verify sequence length
        if (dut.len == 7)  // 1 initial + 6 added
            $display("\nSUCCESS: Sequence reached expected length of 7!");
        else
            $display("\nERROR: Unexpected sequence length: %0d", dut.len);
        
        */

        // Finish simulation
        #(CLK_PERIOD*500);
        $display("\nSimulation completed");
        $finish;
    end
    
    // State monitor
    always @(dut.current_s) begin
        local_state_t current_state = local_state_t'(dut.current_s);
        case (current_state)
            ST_IDLE:         $display("State: ST_IDLE");
            ST_GEN:          $display("State: ST_GEN");
            ST_SHOW_LEDS:    $display("State: ST_SHOW_LEDS");
            ST_PLAYER_IN:    $display("State: ST_PLAYER_IN");
            ST_EVAL:         $display("State: ST_EVAL");
            ST_ADD_COLOR: $display("State: ST_ADD_COLOR");
            ST_END:          $display("State: ST_END");
        endcase
    end
    
    // Player turn monitor
    always @(dut.player1_turn) begin
        if (local_state_t'(dut.current_s) != ST_IDLE)
            $display("Turn changed: Player %0d's turn", dut.player1_turn ? 1 : 2);
    end
    
    // Add color mode monitor
    always @(dut.add_color_mode) begin
        if (local_state_t'(dut.current_s) != ST_IDLE)
            $display("Add color mode: %s", dut.add_color_mode ? "ENABLED" : "DISABLED");
    end
    
    // LED monitor
    always @(posedge clk) begin
        if (led_green | led_red | led_blue | led_yellow)
            $display("LEDs: G=%b R=%b B=%b Y=%b", led_green, led_red, led_blue, led_yellow);
    end
endmodule