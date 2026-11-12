#!/usr/bin/env python3
"""Control the DE25-Nano mandelbrot over the FPGA UART (replaces the Xilinx VIO).

The board's USB-C port (USB-Blaster III) shows up as several serial ports; the FPGA UART is one of
them (on Linux usually the last /dev/ttyUSB*, on Windows a COMx). 115200 8N1.

  mandelbrot_ctl.py -p /dev/ttyUSB2 status
  mandelbrot_ctl.py -p COM5 view -0.743 0.131 0.01 --max-it 500
  mandelbrot_ctl.py -p COM5 palette --start 3 --colors 000764 206bcb edffff ffaa00
  mandelbrot_ctl.py -p COM5 interactive      # arrows pan, +/- zoom, [ ] max_it, r render, q quit
  mandelbrot_ctl.py -p COM5 raw "r 1"        # one protocol line

Protocol (typable in any terminal): "w AA DDDDDDDD" writes a register (reply OK),
"r AA" reads one (reply 8 hex digits), anything else replies "?".

Needs pyserial (pip install pyserial).
"""

import argparse
import sys

import serial

ID, STATUS, CONTROL = 0x00, 0x01, 0x02
CENTER_X, CENTER_Y, XY_STEP, MAX_IT = 0x03, 0x04, 0x05, 0x06
CC_START, CC_TWO, COLOR0 = 0x07, 0x08, 0x09
X_RES, Y_RES, FRAC, FRAMES = 0x10, 0x11, 0x12, 0x13
ID_VALUE = 0x4D414E44


class Board:
    def __init__(self, port, baud=115200):
        self.s = serial.Serial(port, baud, timeout=1.0)
        self.s.reset_input_buffer()
        self.s.write(b"\n")  # finish any half-typed line
        self.s.readline()
        if self.read(ID) != ID_VALUE:
            raise SystemExit(f"{port}: no mandelbrot design answering (wrong port or not configured?)")
        self.frac = self.read(FRAC)
        self.xres = self.read(X_RES)
        self.yres = self.read(Y_RES)

    def line(self, text):
        self.s.write(text.encode() + b"\n")
        reply = self.s.readline().decode(errors="replace").strip()
        if not reply:
            raise SystemExit(f"no reply to '{text}'")
        return reply

    def read(self, addr):
        r = self.line(f"r {addr:x}")
        if r == "?":
            raise SystemExit(f"read {addr:#x} rejected")
        return int(r, 16)

    def write(self, addr, value):
        if self.line(f"w {addr:x} {value & 0xFFFFFFFF:x}") != "OK":
            raise SystemExit(f"write {addr:#x} rejected")

    # fixed point (signed, `frac` fraction bits, sign-extended to 32 bits on read)
    def to_fix(self, v):
        return int(round(v * (1 << self.frac)))

    def from_fix(self, raw):
        if raw & 0x80000000:
            raw -= 1 << 32
        return raw / (1 << self.frac)

    def get_view(self):
        return (self.from_fix(self.read(CENTER_X)), self.from_fix(self.read(CENTER_Y)),
                self.from_fix(self.read(XY_STEP)), self.read(MAX_IT))

    def set_view(self, cx=None, cy=None, step=None, max_it=None, render=True):
        if cx is not None:
            self.write(CENTER_X, self.to_fix(cx))
        if cy is not None:
            self.write(CENTER_Y, self.to_fix(cy))
        if step is not None:
            raw = self.to_fix(step)
            if raw < 1:
                print(f"step {step} is below the resolution of {self.frac} fraction bits, using 1 LSB")
            self.write(XY_STEP, max(raw, 1))
        if max_it is not None:
            self.write(MAX_IT, max(1, min(max_it, 0xFFFF)))
        if render:
            self.write(CONTROL, 1)

    def status(self):
        s = self.read(STATUS)
        cx, cy, step, it = self.get_view()
        colors = " ".join(f"{self.read(COLOR0 + i):06x}" for i in range(4))
        print(f"memory calibrated : {bool(s & 1)}")
        print(f"HDMI set up       : {bool(s & 2)}{'  (I2C error!)' if s & 4 else ''}")
        print(f"underrun          : {bool(s & 8)} (in the last frame)")
        print(f"render pending    : {bool(s & 16)}")
        print(f"renders started   : {self.read(FRAMES)}")
        print(f"resolution        : {self.xres}x{self.yres}, {self.frac} fraction bits")
        print(f"view              : center ({cx:.10g}, {cy:.10g}), width {step * self.xres:.6g}, max_it {it}")
        print(f"palette           : start {self.read(CC_START)}, two-color {bool(self.read(CC_TWO))}, colors {colors}")


def interactive(b):
    """Arrow keys pan by 1/8 of the screen, +/- zoom 2x, [ ] max_it, r render, q quit."""
    if sys.platform == "win32":
        import msvcrt

        def key():
            c = msvcrt.getwch()
            if c in ("\x00", "\xe0"):
                return {"H": "up", "P": "down", "K": "left", "M": "right"}.get(msvcrt.getwch(), "")
            return c
        restore = lambda: None
    else:
        import termios
        import tty
        fd = sys.stdin.fileno()
        old = termios.tcgetattr(fd)
        tty.setcbreak(fd)
        restore = lambda: termios.tcsetattr(fd, termios.TCSADRAIN, old)

        def key():
            c = sys.stdin.read(1)
            if c == "\x1b" and sys.stdin.read(1) == "[":
                return {"A": "up", "B": "down", "D": "left", "C": "right"}.get(sys.stdin.read(1), "")
            return c

    print(interactive.__doc__)
    try:
        while True:
            cx, cy, step, it = b.get_view()
            print(f"\rcenter ({cx:.10g}, {cy:.10g})  width {step * b.xres:.4g}  max_it {it}      ", end="", flush=True)
            k = key()
            dx, dy = step * b.xres / 8, step * b.yres / 8
            if k == "q":
                break
            elif k == "left":
                b.set_view(cx=cx - dx)
            elif k == "right":
                b.set_view(cx=cx + dx)
            elif k == "up":
                b.set_view(cy=cy + dy)
            elif k == "down":
                b.set_view(cy=cy - dy)
            elif k in "+=":
                b.set_view(step=step / 2)
            elif k in "-_":
                b.set_view(step=step * 2)
            elif k == "]":
                b.set_view(max_it=int(it * 1.5) + 1)
            elif k == "[":
                b.set_view(max_it=int(it / 1.5))
            elif k == "r":
                b.write(CONTROL, 1)
    finally:
        restore()
        print()


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    p.add_argument("-p", "--port", required=True, help="serial port, e.g. /dev/ttyUSB2 or COM5")
    p.add_argument("-b", "--baud", type=int, default=115200)
    sub = p.add_subparsers(dest="cmd", required=True)
    sub.add_parser("status")
    v = sub.add_parser("view", help="set the view and render it")
    v.add_argument("cx", type=float)
    v.add_argument("cy", type=float)
    v.add_argument("width", type=float, help="width of the image in the complex plane")
    v.add_argument("--max-it", type=int)
    pal = sub.add_parser("palette")
    pal.add_argument("--start", type=int, help="iteration-count bit where the color index starts (0..15)")
    pal.add_argument("--two-color", type=int, choices=[0, 1])
    pal.add_argument("--colors", nargs=4, metavar="RRGGBB")
    sub.add_parser("render")
    sub.add_parser("interactive")
    r = sub.add_parser("raw")
    r.add_argument("line")
    a = p.parse_args()

    b = Board(a.port, a.baud)
    if a.cmd == "status":
        b.status()
    elif a.cmd == "view":
        b.set_view(a.cx, a.cy, a.width / b.xres, a.max_it)
    elif a.cmd == "palette":
        if a.start is not None:
            b.write(CC_START, a.start)
        if a.two_color is not None:
            b.write(CC_TWO, a.two_color)
        if a.colors:
            for i, c in enumerate(a.colors):
                b.write(COLOR0 + i, int(c, 16))
    elif a.cmd == "render":
        b.write(CONTROL, 1)
    elif a.cmd == "interactive":
        interactive(b)
    elif a.cmd == "raw":
        print(b.line(a.line))


if __name__ == "__main__":
    main()
