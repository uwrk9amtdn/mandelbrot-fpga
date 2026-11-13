# Cross-build for the HPS (aarch64 Linux). Static, because the board has no compiler and its
# glibc version is not known. Arch: pacman -S aarch64-linux-gnu-gcc
CC = aarch64-linux-gnu-gcc
CFLAGS = -O2 -Wall -Wextra -static
BOARD ?= terasic@de25nano

memtool: memtool.c
	$(CC) $(CFLAGS) -o $@ $<

install: memtool
	scp memtool $(BOARD):

clean:
	rm -f memtool

.PHONY: install clean
