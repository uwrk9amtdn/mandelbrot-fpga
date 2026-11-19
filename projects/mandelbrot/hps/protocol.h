// Wire protocol between the PC application and the board, version 1: the C side of
// pc/mandelbrot/protocol.py (PC_APP_PLAN.md, section 2). TCP, binary, little-endian (the HPS is
// little-endian too, so the structs are sent as they are).
#pragma once
#include <stdint.h>

#define PROTO_VERSION 1
#define PROTO_PORT 5150
#define PROTO_MAGIC "MBRT"
#define PROTO_MAX_PAYLOAD (16u << 20)

#define COUNT_UNRESOLVED 0xFFFFFFFFu // reached max_it
#define COUNT_INTERIOR 0xFFFFFFFEu   // proven interior; the |z|^2 word holds u32 k, the proof's iteration
#define MAX_MAX_IT 0xFFFFFFFDu

// Feature bits (INFO); bits 0-2 are also request flags (TILE_REQ).
#define FLAG_PERIODICITY (1u << 0)
#define FLAG_CARDIOID (1u << 1)
#define FLAG_LZ4 (1u << 2)
#define FEATURE_BOARD_STATUS (1u << 3) // STATUS_REQ / STATUS; not a request flag
#define REQUEST_FLAGS (FLAG_PERIODICITY | FLAG_CARDIOID | FLAG_LZ4)

enum { ENCODING_RAW = 0, ENCODING_LZ4 = 1 };
enum { STATUS_COMPLETE = 0, STATUS_ABORTED = 1 };

enum msg_type {
    MSG_HELLO = 1,
    MSG_INFO = 2,
    MSG_TILE_REQ = 3,
    MSG_TILE = 4,
    MSG_CANCEL = 5,
    MSG_ERROR = 6,
    MSG_PING = 7,
    MSG_PONG = 8,
    MSG_STATUS_REQ = 9,
    MSG_STATUS = 10,
};

enum err_code {
    ERR_VERSION = 1,
    ERR_TILE_SIZE = 2,
    ERR_MAX_IT = 3,
    ERR_FLAGS = 4,
    ERR_BUSY = 5,
    ERR_REQUEST_ID = 6,
    ERR_COORDINATE = 7,
    ERR_MESSAGE = 8,
};

#define PACKED __attribute__((packed))

struct PACKED msg_header {
    char magic[4];
    uint16_t type;
    uint16_t flags;
    uint32_t length; // payload bytes
    uint32_t reserved;
};

struct PACKED msg_info {
    uint16_t version, w, f, n_cores;
    uint32_t clock_khz;
    uint16_t max_tile_width, max_tile_height, max_in_flight, features;
    uint32_t max_max_it, bailout_r2, arith_id;
};

// Followed by x0, y0, step: ceil(W/32) u32 words each, low word first, sign-extended.
struct PACKED msg_tile_req {
    uint32_t request_id;
    uint16_t width, height;
    uint32_t max_it, flags;
};

// Followed by the data: the counts (u32 per pixel, row-major), then |z|^2 at escape (f32).
struct PACKED msg_tile {
    uint32_t request_id;
    uint16_t width, height;
    uint8_t encoding, status;
    uint8_t pad[2];
    uint32_t raw_size;
    uint64_t iterations, total_iterations, total_cycles;
};

struct PACKED msg_cancel { // followed by count u32 request ids; count 0 cancels everything
    uint16_t count;
    uint8_t pad[2];
};

struct PACKED msg_error { // followed by text_length bytes of UTF-8
    uint32_t request_id;
    uint16_t code, text_length;
};

struct PACKED msg_status {
    int16_t fpga_temp, board_temp; // °C
    uint16_t fan_rpm;
    uint16_t flags; // bit 0: the readings are valid
};

_Static_assert(sizeof(struct msg_header) == 16, "header");
_Static_assert(sizeof(struct msg_info) == 32, "INFO");
_Static_assert(sizeof(struct msg_tile_req) == 16, "TILE_REQ");
_Static_assert(sizeof(struct msg_tile) == 40, "TILE");
_Static_assert(sizeof(struct msg_status) == 8, "STATUS");
