module display_driver #(
    parameter active_pixels_h = 800,
    parameter front_porch_h   = 40,
    parameter sync_width_h    = 128,
    parameter back_porch_h    = 88,
    parameter sync_polarity_h = 1,

    parameter active_pixels_v = 600,
    parameter front_porch_v   = 1,
    parameter sync_width_v    = 4,
    parameter back_porch_v    = 23,
    parameter sync_polarity_v = 1
) (
    input             clk,
    output reg [31:0] addr,
    output reg [31:0] x,
    output reg [31:0] y,
    input      [23:0] rgb,

    output reg [7:0]  r,
    output reg [7:0]  g,
    output reg [7:0]  b,
    output reg        hsync,
    output reg        vsync,
    output reg        de
);

    localparam total_lines_h = active_pixels_h + front_porch_h + sync_width_h + back_porch_h;
    localparam total_lines_v = active_pixels_v + front_porch_v + sync_width_v + back_porch_v;

    localparam sync_start_h = active_pixels_h + front_porch_h;
    localparam sync_start_v = active_pixels_v + front_porch_v;

    localparam sync_end_h = active_pixels_h + front_porch_h + sync_width_h;
    localparam sync_end_v = active_pixels_v + front_porch_v + sync_width_v;

    reg [$clog2(total_lines_h)-1:0] line_counter_h = sync_end_h;
    reg [$clog2(total_lines_v)-1:0] line_counter_v = sync_end_v;

    // verilator lint_off WIDTHEXPAND
    assign x       = line_counter_h;
    assign y       = line_counter_v;
    assign r       = rgb[16+:8];
    assign g       = rgb[8+:8];
    assign b       = rgb[0+:8];
    assign hsync   = ~sync_polarity_h ^ (line_counter_h >= sync_start_h && line_counter_h < sync_end_h);
    assign vsync   = ~sync_polarity_v ^ (line_counter_v >= sync_start_v && line_counter_v < sync_end_v);
    assign de      = line_counter_h < active_pixels_h && line_counter_v < active_pixels_v;

    always @(posedge clk) begin
        line_counter_h <= (line_counter_h == total_lines_h-1) ? 0 : line_counter_h + 1;
        if (line_counter_h == total_lines_h-1) line_counter_v <= (line_counter_v == total_lines_v-1) ? 0 : line_counter_v + 1;
        addr <= (line_counter_h == active_pixels_h-1 && line_counter_v == active_pixels_v-1) ? 0 : addr + 1;
    end

endmodule