# Cross-build for the HPS (aarch64 Linux). Static, because the board has no compiler and its
# glibc version is not known. Arch: pacman -S aarch64-linux-gnu-gcc
CC = aarch64-linux-gnu-gcc
CFLAGS = -O2 -Wall -Wextra -static
BOARD ?= terasic@192.168.10.10

PROGS = memtool hugebuf_test mandelbrotd

all: $(PROGS)

%: %.c
	$(CC) $(CFLAGS) -o $@ $<

mandelbrotd: mandelbrotd.c protocol.h

install: $(PROGS)
	scp $(PROGS) accel_test.py $(BOARD):

clean:
	rm -f $(PROGS)

.PHONY: all install clean
