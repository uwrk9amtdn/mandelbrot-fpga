module mandelbrot(
    input clk,

    // pixel clock domain
    input        pixel_clk, // 148.5 MHz
    output [7:0] r,
    output [7:0] g,
    output [7:0] b,
    output       hsync,
    output       vsync
);

    reg         we;
    reg  [31:0] addr;
    reg  [23:0] rgb;
    wire        sync;

    display_driver #(
        .active_pixels_h (1920),
        .front_porch_h   (88),
        .sync_width_h    (44),
        .back_porch_h    (148),

        .active_pixels_v (1080),
        .front_porch_v   (4),
        .sync_width_v    (5),
        .back_porch_v    (36)
    ) dpy (
        .clk  (clk),
        .we   (we),
        .addr (addr),
        .rgb  (rgb),
        .sync (sync),

        .pixel_clk (pixel_clk), // 148.5 MHz
        .r         (r),
        .g         (g),
        .b         (b),
        .hsync     (hsync),
        .vsync     (vsync)
    );

    typedef enum tstate {WAIT_SYNC, UPDATE} state;

    reg [$clog2(dpy.active_pixels_h)-1:0] px;
    reg [$clog2(dpy.active_pixels_v)-1:0] py;

    always_ff @(posedge clk) begin
        case (state);
            WAIT_SYNC: begin
                px   <= 0;
                py   <= 0;
                addr <= 0;
                if (sync) state <= UPDATE;
            end

            UPDATE: begin

            end
        endcase
    end

endmodule