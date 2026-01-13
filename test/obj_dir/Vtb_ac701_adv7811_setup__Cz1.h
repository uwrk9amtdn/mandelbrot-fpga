// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtb.h for the primary calling header

#ifndef VERILATED_VTB_AC701_ADV7811_SETUP__CZ1_H_
#define VERILATED_VTB_AC701_ADV7811_SETUP__CZ1_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"


class Vtb__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vtb_ac701_adv7811_setup__Cz1 final : public VerilatedModule {
  public:

    // DESIGN SPECIFIC STATE
    VL_IN8(clk,0,0);
    VL_IN8(rst,0,0);
    VL_OUT8(error,0,0);
    VL_OUT8(done,0,0);
    VL_IN8(sda_i,0,0);
    VL_OUT8(sda_o,0,0);
    VL_IN8(scl_i,0,0);
    VL_OUT8(scl_o,0,0);
    CData/*2:0*/ __PVT__call_stack_pos;
    CData/*0:0*/ __PVT__i2c_op_ready;
    CData/*0:0*/ __PVT__i2c_op_valid;
    CData/*1:0*/ __PVT__i2c_op_mode;
    CData/*7:0*/ __PVT__i2c_op_wdata;
    CData/*0:0*/ __PVT__i2c_op_rack;
    CData/*7:0*/ __PVT__i2c_rdata;
    CData/*0:0*/ __PVT__i2c_rdata_valid;
    CData/*0:0*/ __PVT__i2c_wack;
    CData/*0:0*/ __PVT__i2c_wack_valid;
    CData/*0:0*/ __PVT__i2c_i0__DOT__bit_op_ready;
    CData/*0:0*/ __PVT__i2c_i0__DOT__bit_op_valid;
    CData/*1:0*/ __PVT__i2c_i0__DOT__bit_op_mode;
    CData/*0:0*/ __PVT__i2c_i0__DOT__bit_op_wdata;
    CData/*0:0*/ __PVT__i2c_i0__DOT__bit_rdata;
    CData/*0:0*/ __PVT__i2c_i0__DOT__bit_rdata_valid;
    CData/*7:0*/ __PVT__i2c_i0__DOT__wdata;
    CData/*0:0*/ __PVT__i2c_i0__DOT__rack;
    CData/*2:0*/ __PVT__i2c_i0__DOT__byte_counter;
    CData/*0:0*/ __PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__wdata;
    CData/*1:0*/ __PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i;
    CData/*0:0*/ __PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick;
    SData/*15:0*/ __PVT__pc;
    SData/*8:0*/ __PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter;
    IData/*31:0*/ __PVT__time_counter;
    IData/*31:0*/ __PVT__i2c_i0__DOT__state;
    IData/*31:0*/ __PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state;
    VlUnpacked<SData/*15:0*/, 8> __PVT__call_stack;
    VlUnpacked<IData/*31:0*/, 4> __PVT__args;

    // INTERNAL VARIABLES
    Vtb__Syms* const vlSymsp;

    // CONSTRUCTORS
    Vtb_ac701_adv7811_setup__Cz1(Vtb__Syms* symsp, const char* v__name);
    ~Vtb_ac701_adv7811_setup__Cz1();
    VL_UNCOPYABLE(Vtb_ac701_adv7811_setup__Cz1);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
