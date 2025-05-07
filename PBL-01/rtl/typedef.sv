package typedefs;
    
    typedef enum logic [1:0] {
        COLOR_GREEN  = 2'b00,
        COLOR_RED    = 2'b01,
        COLOR_BLUE   = 2'b10,
        COLOR_YELLOW = 2'b11
    } color_t;

    typedef enum logic [1:0] {
        DIFF_EASY = 2'b00,
        DIFF_MEDIUM = 2'b01,
        DIFF_HARD = 2'b10
    } difficulty_t;

    typedef enum logic [0:0] {
        VELOCITY_SLOW = 1'b0,
        VELOCITY_FAST = 1'b1
    } velocity_t;

    typedef enum logic [0:0] {
        GAMEMODE_FOLLOW = 1'b0,
        GAMEMODE_ME     = 1'b1
    } gamemode_t;

    typedef enum logic [2:0] {
        ST_IDLE,
        ST_GEN,
        ST_SHOW_LEDS,
        ST_PLAYER_IN,
        ST_EVAL,
        ST_ADD_COLOR,
        ST_END
    } state_t;

endpackage