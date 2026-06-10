module fft_control_regs #(
    parameter integer ADDR_WIDTH = 4,
    parameter integer DATA_WIDTH = 32,
    parameter integer GAIN_WIDTH = 16
) (
    input  wire                              clk,
    input  wire                              rst,

    input  wire                              wr_en,
    input  wire [ADDR_WIDTH-1:0]             wr_addr,
    input  wire [DATA_WIDTH-1:0]             wr_data,

    input  wire                              rd_en,
    input  wire [ADDR_WIDTH-1:0]             rd_addr,
    output reg  [DATA_WIDTH-1:0]             rd_data,

    input  wire                              pipeline_busy,
    input  wire                              pipeline_done,
    input  wire                              pipeline_overflow,
    input  wire                              pipeline_error,

    output reg                               start_pulse,
    output reg                               bypass_enable,
    output reg                               spectral_enable,

    output reg  signed [GAIN_WIDTH-1:0]      bass_gain,
    output reg  signed [GAIN_WIDTH-1:0]      mid_gain,
    output reg  signed [GAIN_WIDTH-1:0]      treble_gain,

    output reg  [DATA_WIDTH-1:0]             test_select
);

    localparam [ADDR_WIDTH-1:0] CONTROL_REG     = 4'h0;
    localparam [ADDR_WIDTH-1:0] STATUS_REG      = 4'h1;
    localparam [ADDR_WIDTH-1:0] BASS_GAIN_REG   = 4'h2;
    localparam [ADDR_WIDTH-1:0] MID_GAIN_REG    = 4'h3;
    localparam [ADDR_WIDTH-1:0] TREBLE_GAIN_REG = 4'h4;
    localparam [ADDR_WIDTH-1:0] TEST_SELECT_REG = 4'h5;
    localparam [ADDR_WIDTH-1:0] DEBUG_REG       = 4'h6;

    localparam [DATA_WIDTH-1:0] DEBUG_VERSION   = 32'h00010000;
    localparam signed [GAIN_WIDTH-1:0] UNITY_GAIN = 16'sd16384;

    reg done_latched;
    reg overflow_latched;
    reg error_latched;

    always @(posedge clk) begin
        if (rst) begin
            rd_data          <= {DATA_WIDTH{1'b0}};
            start_pulse      <= 1'b0;
            bypass_enable    <= 1'b0;
            spectral_enable  <= 1'b1;
            bass_gain        <= UNITY_GAIN;
            mid_gain         <= UNITY_GAIN;
            treble_gain      <= UNITY_GAIN;
            test_select      <= {DATA_WIDTH{1'b0}};
            done_latched     <= 1'b0;
            overflow_latched <= 1'b0;
            error_latched    <= 1'b0;
        end else begin
            start_pulse <= 1'b0;

            if (pipeline_done) begin
                done_latched <= 1'b1;
            end

            if (pipeline_overflow) begin
                overflow_latched <= 1'b1;
            end

            if (pipeline_error) begin
                error_latched <= 1'b1;
            end

            if (wr_en) begin
                case (wr_addr)
                    CONTROL_REG: begin
                        if (wr_data[0]) begin
                            start_pulse <= 1'b1;
                        end

                        bypass_enable   <= wr_data[1];
                        spectral_enable <= wr_data[2];

                        if (wr_data[3]) begin
                            done_latched     <= 1'b0;
                            overflow_latched <= 1'b0;
                            error_latched    <= 1'b0;
                        end
                    end

                    BASS_GAIN_REG: begin
                        bass_gain <= wr_data[GAIN_WIDTH-1:0];
                    end

                    MID_GAIN_REG: begin
                        mid_gain <= wr_data[GAIN_WIDTH-1:0];
                    end

                    TREBLE_GAIN_REG: begin
                        treble_gain <= wr_data[GAIN_WIDTH-1:0];
                    end

                    TEST_SELECT_REG: begin
                        test_select <= wr_data;
                    end

                    default: begin
                    end
                endcase
            end

            if (rd_en) begin
                case (rd_addr)
                    CONTROL_REG: begin
                        rd_data <= {{(DATA_WIDTH-4){1'b0}},
                                    1'b0,
                                    spectral_enable,
                                    bypass_enable,
                                    1'b0};
                    end

                    STATUS_REG: begin
                        rd_data <= {{(DATA_WIDTH-4){1'b0}},
                                    error_latched,
                                    overflow_latched,
                                    done_latched,
                                    pipeline_busy};
                    end

                    BASS_GAIN_REG: begin
                        rd_data <= {{(DATA_WIDTH-GAIN_WIDTH){1'b0}}, bass_gain};
                    end

                    MID_GAIN_REG: begin
                        rd_data <= {{(DATA_WIDTH-GAIN_WIDTH){1'b0}}, mid_gain};
                    end

                    TREBLE_GAIN_REG: begin
                        rd_data <= {{(DATA_WIDTH-GAIN_WIDTH){1'b0}}, treble_gain};
                    end

                    TEST_SELECT_REG: begin
                        rd_data <= test_select;
                    end

                    DEBUG_REG: begin
                        rd_data <= DEBUG_VERSION;
                    end

                    default: begin
                        rd_data <= {DATA_WIDTH{1'b0}};
                    end
                endcase
            end
        end
    end

endmodule
