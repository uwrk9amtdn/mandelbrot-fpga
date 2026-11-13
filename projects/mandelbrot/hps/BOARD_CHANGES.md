# Changes made to the DE25-Nano's Linux system

Changes to the SD card image (`de25_nano_sdcard_console_v1.1`) outside `/home`, with how to undo
each. Keep this list current when the board's system is changed.

## 2026-11-13

### 1. Device tree: 16 MB of RAM reserved for the result buffers

- **File:** `socfpga_agilex5_de25_nano.dtb` on the boot partition (`/dev/mmcblk0p1`, FAT, not
  mounted by default: `sudo mount /dev/mmcblk0p1 /mnt`).
- **Change:** one node added under `/reserved-memory`, next to the existing `svcbuffer@0`:

  ```
  mandelbrot@bf000000 {
      reg = <0x00 0xbf000000 0x00 0x1000000>;
      no-map;
  };
  ```

  Made by decompiling the original with `dtc`, adding the node and compiling it again; the node is
  the only difference.
- **Effect:** Linux no longer uses 0xBF000000-0xBFFFFFFF (918 MB of RAM instead of 934), so the FPGA
  can write there through `f2sdram`, and `/dev/mem` can map it.
- **Original:** `socfpga_agilex5_de25_nano.dtb.orig` beside it on the boot partition, and a copy on
  the PC in `~/Desktop/fpga/de25nano/board_backup/`
  (sha256 `d9bd893f...be4d13`; the modified file is `55722d59...be4659`).
- **Undo:** copy the `.orig` file over the `.dtb` and reboot. If the board doesn't boot, do the same
  with the SD card in a PC.

### 2. Network: static address saved

- **File:** `/etc/NetworkManager/system-connections/board-static.nmconnection`, created with
  `nmcli con add type ethernet ifname eth0 con-name board-static ipv4.method manual
  ipv4.addresses 192.168.10.10/24 ipv6.method link-local connection.autoconnect yes
  connection.autoconnect-priority 10`.
- **Why:** 192.168.10.10 had been set by hand with `ip addr` and would have been lost at the reboot.
- **Undo:** `sudo nmcli con delete board-static`.

### Temporary (until reboot), undone

- Huge pages reserved through sysfs for `hugebuf_test` (one 32 MB page, two 2 MB pages), released
  again afterwards (`nr_hugepages` back to 0).
- The FPGA runs our bitstream (`make program-hps`, over JTAG): a power cycle brings back the GHRD
  from the QSPI flash.

## In the home folder (for completeness)

- `~/.ssh/authorized_keys`: the PC's `id_rsa.pub`, for logins without a password.
- `~/memtool`, `~/hugebuf_test`, `~/accel_test.py`: the test tools from this directory.
