module fft_ifft_accel_stub #(
    parameter integer FFT_N      = 512,
    parameter integer DATA_WIDTH = 16
)(
    input  wire clk,
    input  wire rst,
    input  wire start,
    input  wire inverse,
    input  wire signed [DATA_WIDTH-1:0] sample_in_real,
    input  wire signed [DATA_WIDTH-1:0] sample_in_imag,
    input  wire sample_in_valid,
    output wire sample_in_ready,
    output reg  signed [DATA_WIDTH-1:0] sample_out_real,
    output reg  signed [DATA_WIDTH-1:0] sample_out_imag,
    output reg  sample_out_valid,
    output reg  busy,
    output reg  done
);

    function integer clog2;
        input integer value;
        integer tmp;
        begin
            tmp = value - 1;
            for (clog2 = 0; tmp > 0; clog2 = clog2 + 1)
                tmp = tmp >> 1;

            if (clog2 == 0)
                clog2 = 1;
        end
    endfunction

    localparam integer COUNT_WIDTH = clog2(FFT_N);

    reg [COUNT_WIDTH-1:0] sample_count;
    reg inverse_mode;

    assign sample_in_ready = busy;

    // TODO: replace this stub with real sequential radix-2 FFT/IFFT accelerator.
    // Current behavior is a frame-limited passthrough with ready/valid handshaking.
    always @(posedge clk) begin
        if (rst) begin
            sample_out_real  <= {DATA_WIDTH{1'b0}};
            sample_out_imag  <= {DATA_WIDTH{1'b0}};
            sample_out_valid <= 1'b0;
            busy             <= 1'b0;
            done             <= 1'b0;
            sample_count     <= {COUNT_WIDTH{1'b0}};
            inverse_mode     <= 1'b0;
        end else begin
            sample_out_valid <= 1'b0;
            done             <= 1'b0;

            if (!busy) begin
                if (start) begin
                    busy         <= 1'b1;
                    sample_count <= {COUNT_WIDTH{1'b0}};
                    inverse_mode <= inverse;
                end
            end else if (sample_in_valid) begin
                sample_out_real  <= sample_in_real;
                sample_out_imag  <= sample_in_imag;
                sample_out_valid <= 1'b1;

                if (sample_count == FFT_N - 1) begin
                    busy         <= 1'b0;
                    done         <= 1'b1;
                    sample_count <= {COUNT_WIDTH{1'b0}};
                end else begin
                    sample_count <= sample_count + 1'b1;
                end
            end
        end
    end

endmodule
