#include <Vdisplay_driver.h>
#include <vgasim.h>

int main() {

    Vdisplay_driver dpy;
    vgasim vga;

    dpy.pixel_clk = 0;
    dpy.clk = 0;
    dpy.we = 0;
    dpy.eval();

    for (int i = 0; i < 640; i++) {
        for (int j = 0; j < 350; j++) {
            dpy.clk = 0;
            dpy.addr = j * 640 + i;


            if (0){

                bool b1 = ((i-200)*(i-200) + (j-175)*(j-175) < 10000);
                bool b2 = ((i-230)*(i-230) + (j-175)*(j-175) < 6000);
                dpy.rgb = 0xff0000ff;
                if (b1 && !b2) {
                    dpy.rgb = 0xffffffff;
                }

            }


            if (1){

                float z = .01f;
                int maxit = 500;
                float px = i / 640.0f * z - z/2.0f + -0.05;
                float py = j / 640.0f * z - z/2.0f + 0.6805;

                float zx = 0;
                float zy = 0;

                float zx_ = 0;
                float zy_ = 0;

                int it = 0;

                for (;it < maxit; it++) {
                    zx_ = zx*zx - zy*zy + px;
                    zy_ = 2*zx*zy + py;

                    if (zx_ * zx_ + zy_ * zy_ > 4.0f) {
                        break;
                    }

                    zx = zx_;
                    zy = zy_;
                }

                uint8_t q = 256.0f * it / (float)maxit;
                dpy.rgb = q + (q << 8) + (q << 16);
            }



            dpy.we = 1;
            dpy.eval();
            dpy.clk = 1;
            dpy.eval();
        }
    }

    dpy.clk = 0;
    dpy.we = 0;
    dpy.eval();

    while (1) {
        dpy.pixel_clk = 1;
        dpy.eval();

        vga.tick(dpy.r, dpy.g, dpy.b, dpy.hsync, dpy.vsync);

        dpy.pixel_clk = 0;
        dpy.eval();
    }


}