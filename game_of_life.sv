module game_of_life(
    input clk,

    // pixel clock domain
    input        pixel_clk,
    output [7:0] r,
    output [7:0] g,
    output [7:0] b,
    output       hsync,
    output       vsync
);




    display_driver #(
        .active_pixels_h (640),
        .front_porch_h   (16),
        .sync_width_h    (96),
        .back_porch_h    (48),

        .active_pixels_v (350),
        .front_porch_v   (37),
        .sync_width_v    (2),
        .back_porch_v    (60)
    ) dpy (
        .clk  (clk),
        .we   (),
        .addr (),
        .rgb  (),
        .sync (),

        .pixel_clk (pixel_clk),
        .r         (r),
        .g         (g),
        .b         (b),
        .hsync     (hsync),
        .vsync     (vsync)
    );

endmodule