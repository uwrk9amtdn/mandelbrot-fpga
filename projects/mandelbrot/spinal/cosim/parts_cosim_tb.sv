// Cycle-exact co-simulation of the display-side SV modules against their SpinalHDL ports:
//   color_converter (+ linear_interpolator) vs sp_ColorConverter
//   display_driver (1080p, as in top.sv)     vs sp_DisplayDriver
// Same random inputs, outputs compared every cycle. Run with cosim/run_parts.sh.
module parts_cosim_tb;

    logic clk = 0;
    logic rst = 1;
    always #5 clk = ~clk;

    int errors = 0;

    // ============================================================ color converter
    logic [3:0]  start_index;
    logic        two_color;
    logic [23:0] colors [4];
    logic        s_valid = 0;
    logic [15:0] s_data;
    logic        m_ready = 0;

    axis_intf #(16, 0) ref_s ();
    axis_intf #(24, 0) ref_m ();
    assign ref_s.valid = s_valid;
    assign ref_s.data  = s_data;
    assign ref_m.ready = m_ready;

    color_converter ref_cc (
        .clk         (clk),
        .rst         (rst),
        .start_index (start_index),
        .two_color   (two_color),
        .color_0     (colors[0]),
        .color_1     (colors[1]),
        .color_2     (colors[2]),
        .color_3     (colors[3]),
        .s_axis_it   (ref_s),
        .m_axis_rgb  (ref_m)
    );

    logic        sp_s_ready, sp_m_valid;
    logic [23:0] sp_m_data;

    sp_ColorConverter sp_cc (
        .clk                   (clk),
        .rst                   (rst),
        .io_palette_startIndex (start_index),
        .io_palette_twoColor   (two_color),
        .io_palette_colors_0   (colors[0]),
        .io_palette_colors_1   (colors[1]),
        .io_palette_colors_2   (colors[2]),
        .io_palette_colors_3   (colors[3]),
        .io_s_valid            (s_valid),
        .io_s_ready            (sp_s_ready),
        .io_s_payload          (s_data),
        .io_m_valid            (sp_m_valid),
        .io_m_ready            (m_ready),
        .io_m_payload          (sp_m_data)
    );

    // ============================================================ display driver
    logic [23:0] rgb;
    logic [7:0]  ref_r, ref_g, ref_b, sp_r, sp_g, sp_b;
    logic        ref_hs, ref_vs, ref_de, sp_hs, sp_vs, sp_de, sp_in_vsync;

    display_driver #(
        .active_pixels_h (1920), .front_porch_h (88), .sync_width_h (44), .back_porch_h (148), .sync_polarity_h (1),
        .active_pixels_v (1080), .front_porch_v (4),  .sync_width_v (5),  .back_porch_v (36),  .sync_polarity_v (1)
    ) ref_dd (
        .clk (clk), .addr (), .x (), .y (), .rgb (rgb),
        .r (ref_r), .g (ref_g), .b (ref_b), .hsync (ref_hs), .vsync (ref_vs), .de (ref_de)
    );

    // The SV counters start from their initial values at time 0; the Spinal ones load the same
    // values in reset at the first edge, so the Spinal syncs lag by exactly one cycle.
    logic dd_rst = 1;
    logic ref_hs_d, ref_vs_d, ref_de_d;
    always @(posedge clk) {ref_hs_d, ref_vs_d, ref_de_d} <= {ref_hs, ref_vs, ref_de};
    sp_DisplayDriver sp_dd (
        .clk (clk), .rst (dd_rst), .io_rgb (rgb),
        .io_r (sp_r), .io_g (sp_g), .io_b (sp_b),
        .io_hsync (sp_hs), .io_vsync (sp_vs), .io_de (sp_de), .io_inVSync (sp_in_vsync)
    );

    // ============================================================ stimulus + checks
    int cc_out = 0;
    int frames = 0;
    logic prev_vs = 0;

    always @(posedge clk) begin
        if (!rst) begin
            if ({ref_s.ready, ref_m.valid} !== {sp_s_ready, sp_m_valid}
                || (ref_m.valid && ref_m.data !== sp_m_data)) begin
                if (errors < 10) $display("%t color_converter: ref ready=%b valid=%b data=%06x, spinal ready=%b valid=%b data=%06x",
                    $time, ref_s.ready, ref_m.valid, ref_m.data, sp_s_ready, sp_m_valid, sp_m_data);
                errors++;
            end
            if (ref_m.valid && m_ready) cc_out++;
        end
        if (!dd_rst) begin
            if ({ref_r, ref_g, ref_b, ref_hs_d, ref_vs_d, ref_de_d} !== {sp_r, sp_g, sp_b, sp_hs, sp_vs, sp_de}
                || sp_in_vsync !== ref_vs_d) begin
                if (errors < 10) $display("%t display_driver mismatch: ref hs=%b vs=%b de=%b, spinal hs=%b vs=%b de=%b",
                    $time, ref_hs_d, ref_vs_d, ref_de_d, sp_hs, sp_vs, sp_de);
                errors++;
            end
            if (ref_vs && !prev_vs) frames++;
            prev_vs <= ref_vs;
        end
    end

    initial begin
        start_index = 4;
        two_color   = 1;
        colors      = '{24'hff0000, 24'h00ff00, 24'h0000ff, 24'hffff00};
        s_data      = 0;
        rgb         = 0;

        @(negedge clk); dd_rst = 0;   // sp_DisplayDriver loaded its reset values on the first edge
        repeat (4) @(negedge clk);
        rst = 0;

        // two full frames (2200 x 1125 cycles each) with random color-converter traffic;
        // the palette changes (with a reset, like vsync in top.sv) every 50000 cycles
        while (frames < 3) begin
            @(negedge clk);
            s_valid = $urandom_range(0, 3) != 0;
            s_data  = ($urandom_range(0, 1) == 1) ? 16'($urandom) : 16'($urandom_range(0, 600));
            m_ready = $urandom_range(0, 3) != 0;
            rgb     = 24'($urandom);
            if ($urandom_range(0, 49999) == 0) begin
                rst         = 1;
                start_index = 4'($urandom);
                two_color   = 1'($urandom);
                foreach (colors[i]) colors[i] = 24'($urandom);
                repeat (3) @(negedge clk);
                rst = 0;
            end
        end

        if (errors == 0 && cc_out > 1000000)
            $display("PASS: color_converter %0d pixels and display_driver %0d frames identical", cc_out, frames);
        else
            $display("FAIL: %0d mismatches (%0d color_converter outputs, %0d frames)", errors, cc_out, frames);
        $finish;
    end

endmodule
