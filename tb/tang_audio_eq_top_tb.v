`timescale 1ns/1ps

// Sanity test for tang_audio_eq_top:
// checks I2S activity, heartbeat, channel LED switching and known I2S data.
module tang_audio_eq_top_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;
    reg btn_vol_up = 1'b0;
    reg btn_vol_down = 1'b0;
    reg btn_bass_up = 1'b0;
    reg btn_bass_down = 1'b0;
    reg btn_mid_up = 1'b0;
    reg btn_mid_down = 1'b0;
    reg btn_treble_up = 1'b0;
    reg btn_treble_down = 1'b0;
    reg btn_channel_select = 1'b0;

    wire I2S_BCLK;
    wire I2S_LRCK;
    wire I2S_DIN;
    wire PA_SD;
    wire led_heartbeat;
    wire led_left_active;
    wire led_right_active;
    wire led_clip;

    reg prev_bclk;
    reg prev_lrck;
    reg prev_heartbeat;
    integer bclk_toggle_count;
    integer lrck_toggle_count;
    integer heartbeat_toggle_count;
    integer din_known_count;
    integer errors;
    integer k;

    tang_audio_eq_top #(
        .CLK_HZ(4000000),
        .BUTTON_DEBOUNCE_MS(0),
        .BUTTON_ACTIVE_LEVEL(1'b1),
        .HEARTBEAT_BIT(4)
    ) dut (
        .clk(clk),
        .rst(rst),
        .btn_vol_up(btn_vol_up),
        .btn_vol_down(btn_vol_down),
        .btn_bass_up(btn_bass_up),
        .btn_bass_down(btn_bass_down),
        .btn_mid_up(btn_mid_up),
        .btn_mid_down(btn_mid_down),
        .btn_treble_up(btn_treble_up),
        .btn_treble_down(btn_treble_down),
        .btn_channel_select(btn_channel_select),
        .I2S_BCLK(I2S_BCLK),
        .I2S_LRCK(I2S_LRCK),
        .I2S_DIN(I2S_DIN),
        .PA_SD(PA_SD),
        .led_heartbeat(led_heartbeat),
        .led_left_active(led_left_active),
        .led_right_active(led_right_active),
        .led_clip(led_clip)
    );

    always #5 clk = ~clk;

    always @(posedge clk) begin
        #1;
        if (rst) begin
            prev_bclk <= I2S_BCLK;
            prev_lrck <= I2S_LRCK;
            prev_heartbeat <= led_heartbeat;
        end else begin
            if (I2S_BCLK !== prev_bclk)
                bclk_toggle_count = bclk_toggle_count + 1;
            if (I2S_LRCK !== prev_lrck)
                lrck_toggle_count = lrck_toggle_count + 1;
            if (led_heartbeat !== prev_heartbeat)
                heartbeat_toggle_count = heartbeat_toggle_count + 1;
            if ((I2S_DIN === 1'b0) || (I2S_DIN === 1'b1))
                din_known_count = din_known_count + 1;

            prev_bclk <= I2S_BCLK;
            prev_lrck <= I2S_LRCK;
            prev_heartbeat <= led_heartbeat;
        end
    end

    task set_button;
        input integer button_id;
        input value;
        begin
            case (button_id)
                0: btn_channel_select = value;
                1: btn_bass_up = value;
                2: btn_mid_up = value;
                3: btn_treble_up = value;
                4: btn_vol_up = value;
                default: begin
                    btn_channel_select = btn_channel_select;
                end
            endcase
        end
    endtask

    task press_button;
        input integer button_id;
        begin
            @(negedge clk);
            set_button(button_id, 1'b1);
            repeat (8) @(negedge clk);
            set_button(button_id, 1'b0);
            repeat (8) @(negedge clk);
        end
    endtask

    initial begin
        errors = 0;
        bclk_toggle_count = 0;
        lrck_toggle_count = 0;
        heartbeat_toggle_count = 0;
        din_known_count = 0;
        prev_bclk = 1'b0;
        prev_lrck = 1'b0;
        prev_heartbeat = 1'b0;

        repeat (10) @(negedge clk);
        rst = 1'b0;
        repeat (100) @(negedge clk);

        if (PA_SD !== 1'b1) begin
            $display("FAIL: PA_SD is not enabled");
            errors = errors + 1;
        end
        if (led_left_active !== 1'b1 || led_right_active !== 1'b0) begin
            $display("FAIL: default active channel LEDs are wrong L=%0b R=%0b",
                     led_left_active, led_right_active);
            errors = errors + 1;
        end

        press_button(0);
        if (led_left_active !== 1'b0 || led_right_active !== 1'b1) begin
            $display("FAIL: channel select did not switch LEDs L=%0b R=%0b",
                     led_left_active, led_right_active);
            errors = errors + 1;
        end

        press_button(1);
        press_button(2);
        press_button(3);
        press_button(4);

        for (k = 0; k < 300; k = k + 1) begin
            @(posedge clk);
            #1;
            if (I2S_DIN !== 1'b0 && I2S_DIN !== 1'b1) begin
                $display("FAIL: I2S_DIN became X/Z");
                errors = errors + 1;
            end
            if (led_clip !== 1'b0 && led_clip !== 1'b1) begin
                $display("FAIL: led_clip became X/Z");
                errors = errors + 1;
            end
        end

        if (bclk_toggle_count < 20) begin
            $display("FAIL: BCLK did not toggle enough count=%0d", bclk_toggle_count);
            errors = errors + 1;
        end
        if (lrck_toggle_count < 2) begin
            $display("FAIL: LRCK did not toggle enough count=%0d", lrck_toggle_count);
            errors = errors + 1;
        end
        if (heartbeat_toggle_count < 2) begin
            $display("FAIL: heartbeat did not toggle enough count=%0d", heartbeat_toggle_count);
            errors = errors + 1;
        end
        if (din_known_count < 20) begin
            $display("FAIL: I2S_DIN was not actively driven count=%0d", din_known_count);
            errors = errors + 1;
        end

        if (errors == 0)
            $display("PASS: tang_audio_eq_top_tb");
        else
            $display("FAIL: tang_audio_eq_top_tb errors=%0d", errors);

        $finish;
    end

endmodule
