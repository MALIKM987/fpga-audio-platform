`timescale 1ns/1ps

// Sanity test for audio_tx_top:
// checks that I2S clocks toggle and serial data is driven.
module audio_tx_top_tb;

    reg clk = 1'b0;
    reg rst = 1'b1;

    wire bclk;
    wire lrck;
    wire sdata;

    reg prev_bclk;
    reg prev_lrck;
    reg prev_sdata;
    integer bclk_toggle_count;
    integer lrck_toggle_count;
    integer sdata_toggle_count;
    integer sdata_known_count;
    integer errors;

    audio_tx_top dut (
        .clk(clk),
        .rst(rst),
        .bclk(bclk),
        .lrck(lrck),
        .sdata(sdata)
    );

    always #18.5 clk = ~clk; // ~27 MHz

    always @(posedge clk) begin
        if (rst) begin
            prev_bclk <= bclk;
            prev_lrck <= lrck;
            prev_sdata <= sdata;
        end else begin
            if (bclk !== prev_bclk)
                bclk_toggle_count = bclk_toggle_count + 1;
            if (lrck !== prev_lrck)
                lrck_toggle_count = lrck_toggle_count + 1;
            if (sdata !== prev_sdata)
                sdata_toggle_count = sdata_toggle_count + 1;
            if ((sdata === 1'b0) || (sdata === 1'b1))
                sdata_known_count = sdata_known_count + 1;

            prev_bclk <= bclk;
            prev_lrck <= lrck;
            prev_sdata <= sdata;
        end
    end

    initial begin
        errors = 0;
        bclk_toggle_count = 0;
        lrck_toggle_count = 0;
        sdata_toggle_count = 0;
        sdata_known_count = 0;
        prev_bclk = 1'b0;
        prev_lrck = 1'b0;
        prev_sdata = 1'b0;

        #200;
        rst = 1'b0;

        #2000000;

        if (bclk_toggle_count < 10) begin
            $display("FAIL: bclk did not toggle enough, count=%0d", bclk_toggle_count);
            errors = errors + 1;
        end

        if (lrck_toggle_count < 2) begin
            $display("FAIL: lrck did not toggle enough, count=%0d", lrck_toggle_count);
            errors = errors + 1;
        end

        if (sdata_known_count < 10) begin
            $display("FAIL: sdata was not actively driven, known_count=%0d", sdata_known_count);
            errors = errors + 1;
        end

        if (sdata_toggle_count == 0)
            $display("INFO: sdata stayed constant but was driven during the check window");

        if (errors == 0)
            $display("PASS: audio_tx_top_tb");
        else
            $display("FAIL: audio_tx_top_tb errors=%0d", errors);

        $finish;
    end

endmodule
