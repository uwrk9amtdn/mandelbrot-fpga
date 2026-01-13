// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb.h for the primary calling header

#include "Vtb__pch.h"
#include "Vtb__Syms.h"
#include "Vtb_ac701_adv7811_setup__Cz1.h"

VL_INLINE_OPT void Vtb_ac701_adv7811_setup__Cz1___nba_sequent__TOP__tb__DOT__ac701_adv7811_setup_i0__0(Vtb_ac701_adv7811_setup__Cz1* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+        Vtb_ac701_adv7811_setup__Cz1___nba_sequent__TOP__tb__DOT__ac701_adv7811_setup_i0__0\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Init
    CData/*7:0*/ __Vtask_i2c_send_op__26__wdata;
    __Vtask_i2c_send_op__26__wdata = 0;
    CData/*7:0*/ __Vtask_i2c_send_op__28__wdata;
    __Vtask_i2c_send_op__28__wdata = 0;
    SData/*15:0*/ __Vdly__pc;
    __Vdly__pc = 0;
    IData/*31:0*/ __Vdly__time_counter;
    __Vdly__time_counter = 0;
    CData/*2:0*/ __Vdly__call_stack_pos;
    __Vdly__call_stack_pos = 0;
    CData/*0:0*/ __Vdly__i2c_op_valid;
    __Vdly__i2c_op_valid = 0;
    CData/*0:0*/ __Vdly__i2c_wack_valid;
    __Vdly__i2c_wack_valid = 0;
    CData/*0:0*/ __Vdly__i2c_i0__DOT__rack;
    __Vdly__i2c_i0__DOT__rack = 0;
    CData/*7:0*/ __Vdly__i2c_i0__DOT__wdata;
    __Vdly__i2c_i0__DOT__wdata = 0;
    IData/*31:0*/ __Vdly__i2c_i0__DOT__state;
    __Vdly__i2c_i0__DOT__state = 0;
    CData/*0:0*/ __Vdly__i2c_i0__DOT__bit_op_valid;
    __Vdly__i2c_i0__DOT__bit_op_valid = 0;
    CData/*1:0*/ __Vdly__i2c_i0__DOT__bit_op_mode;
    __Vdly__i2c_i0__DOT__bit_op_mode = 0;
    CData/*2:0*/ __Vdly__i2c_i0__DOT__byte_counter;
    __Vdly__i2c_i0__DOT__byte_counter = 0;
    CData/*0:0*/ __Vdly__i2c_i0__DOT__bit_op_wdata;
    __Vdly__i2c_i0__DOT__bit_op_wdata = 0;
    CData/*0:0*/ __Vdly__i2c_wack;
    __Vdly__i2c_wack = 0;
    SData/*8:0*/ __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter;
    __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter = 0;
    IData/*31:0*/ __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state;
    __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state = 0;
    CData/*0:0*/ __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__wdata;
    __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__wdata = 0;
    CData/*1:0*/ __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i;
    __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i = 0;
    CData/*0:0*/ __VdlySet__args__v0;
    __VdlySet__args__v0 = 0;
    SData/*15:0*/ __VdlyVal__call_stack__v0;
    __VdlyVal__call_stack__v0 = 0;
    CData/*2:0*/ __VdlyDim0__call_stack__v0;
    __VdlyDim0__call_stack__v0 = 0;
    CData/*0:0*/ __VdlySet__args__v2;
    __VdlySet__args__v2 = 0;
    CData/*0:0*/ __VdlySet__args__v4;
    __VdlySet__args__v4 = 0;
    SData/*15:0*/ __VdlyVal__call_stack__v1;
    __VdlyVal__call_stack__v1 = 0;
    CData/*2:0*/ __VdlyDim0__call_stack__v1;
    __VdlyDim0__call_stack__v1 = 0;
    CData/*0:0*/ __VdlySet__args__v6;
    __VdlySet__args__v6 = 0;
    CData/*0:0*/ __VdlySet__args__v8;
    __VdlySet__args__v8 = 0;
    SData/*15:0*/ __VdlyVal__call_stack__v2;
    __VdlyVal__call_stack__v2 = 0;
    CData/*2:0*/ __VdlyDim0__call_stack__v2;
    __VdlyDim0__call_stack__v2 = 0;
    CData/*0:0*/ __VdlySet__args__v10;
    __VdlySet__args__v10 = 0;
    CData/*0:0*/ __VdlySet__args__v12;
    __VdlySet__args__v12 = 0;
    SData/*15:0*/ __VdlyVal__call_stack__v3;
    __VdlyVal__call_stack__v3 = 0;
    CData/*2:0*/ __VdlyDim0__call_stack__v3;
    __VdlyDim0__call_stack__v3 = 0;
    CData/*0:0*/ __VdlySet__args__v14;
    __VdlySet__args__v14 = 0;
    CData/*0:0*/ __VdlySet__args__v16;
    __VdlySet__args__v16 = 0;
    SData/*15:0*/ __VdlyVal__call_stack__v4;
    __VdlyVal__call_stack__v4 = 0;
    CData/*2:0*/ __VdlyDim0__call_stack__v4;
    __VdlyDim0__call_stack__v4 = 0;
    CData/*0:0*/ __VdlySet__args__v18;
    __VdlySet__args__v18 = 0;
    CData/*0:0*/ __VdlySet__args__v20;
    __VdlySet__args__v20 = 0;
    SData/*15:0*/ __VdlyVal__call_stack__v5;
    __VdlyVal__call_stack__v5 = 0;
    CData/*2:0*/ __VdlyDim0__call_stack__v5;
    __VdlyDim0__call_stack__v5 = 0;
    CData/*0:0*/ __VdlySet__args__v22;
    __VdlySet__args__v22 = 0;
    CData/*0:0*/ __VdlySet__args__v24;
    __VdlySet__args__v24 = 0;
    SData/*15:0*/ __VdlyVal__call_stack__v6;
    __VdlyVal__call_stack__v6 = 0;
    CData/*2:0*/ __VdlyDim0__call_stack__v6;
    __VdlyDim0__call_stack__v6 = 0;
    CData/*0:0*/ __VdlySet__args__v26;
    __VdlySet__args__v26 = 0;
    CData/*0:0*/ __VdlySet__args__v28;
    __VdlySet__args__v28 = 0;
    SData/*15:0*/ __VdlyVal__call_stack__v7;
    __VdlyVal__call_stack__v7 = 0;
    CData/*2:0*/ __VdlyDim0__call_stack__v7;
    __VdlyDim0__call_stack__v7 = 0;
    CData/*0:0*/ __VdlySet__args__v30;
    __VdlySet__args__v30 = 0;
    CData/*0:0*/ __VdlySet__args__v32;
    __VdlySet__args__v32 = 0;
    SData/*15:0*/ __VdlyVal__call_stack__v8;
    __VdlyVal__call_stack__v8 = 0;
    CData/*2:0*/ __VdlyDim0__call_stack__v8;
    __VdlyDim0__call_stack__v8 = 0;
    CData/*0:0*/ __VdlySet__args__v34;
    __VdlySet__args__v34 = 0;
    CData/*0:0*/ __VdlySet__args__v36;
    __VdlySet__args__v36 = 0;
    SData/*15:0*/ __VdlyVal__call_stack__v9;
    __VdlyVal__call_stack__v9 = 0;
    CData/*2:0*/ __VdlyDim0__call_stack__v9;
    __VdlyDim0__call_stack__v9 = 0;
    CData/*0:0*/ __VdlySet__args__v38;
    __VdlySet__args__v38 = 0;
    CData/*0:0*/ __VdlySet__args__v40;
    __VdlySet__args__v40 = 0;
    SData/*15:0*/ __VdlyVal__call_stack__v10;
    __VdlyVal__call_stack__v10 = 0;
    CData/*2:0*/ __VdlyDim0__call_stack__v10;
    __VdlyDim0__call_stack__v10 = 0;
    CData/*0:0*/ __VdlySet__args__v42;
    __VdlySet__args__v42 = 0;
    CData/*0:0*/ __VdlySet__args__v44;
    __VdlySet__args__v44 = 0;
    SData/*15:0*/ __VdlyVal__call_stack__v11;
    __VdlyVal__call_stack__v11 = 0;
    CData/*2:0*/ __VdlyDim0__call_stack__v11;
    __VdlyDim0__call_stack__v11 = 0;
    CData/*0:0*/ __VdlySet__args__v46;
    __VdlySet__args__v46 = 0;
    CData/*0:0*/ __VdlySet__args__v48;
    __VdlySet__args__v48 = 0;
    SData/*15:0*/ __VdlyVal__call_stack__v12;
    __VdlyVal__call_stack__v12 = 0;
    CData/*2:0*/ __VdlyDim0__call_stack__v12;
    __VdlyDim0__call_stack__v12 = 0;
    CData/*0:0*/ __VdlySet__args__v50;
    __VdlySet__args__v50 = 0;
    CData/*0:0*/ __VdlySet__args__v52;
    __VdlySet__args__v52 = 0;
    SData/*15:0*/ __VdlyVal__call_stack__v13;
    __VdlyVal__call_stack__v13 = 0;
    CData/*2:0*/ __VdlyDim0__call_stack__v13;
    __VdlyDim0__call_stack__v13 = 0;
    CData/*0:0*/ __VdlySet__args__v54;
    __VdlySet__args__v54 = 0;
    // Body
    __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter 
        = vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter;
    __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__wdata 
        = vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__wdata;
    __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i = vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i;
    __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state 
        = vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state;
    __Vdly__pc = vlSelfRef.__PVT__pc;
    __Vdly__time_counter = vlSelfRef.__PVT__time_counter;
    __Vdly__call_stack_pos = vlSelfRef.__PVT__call_stack_pos;
    __Vdly__i2c_op_valid = vlSelfRef.__PVT__i2c_op_valid;
    __VdlySet__args__v0 = 0U;
    __VdlySet__args__v2 = 0U;
    __VdlySet__args__v4 = 0U;
    __VdlySet__args__v6 = 0U;
    __VdlySet__args__v8 = 0U;
    __VdlySet__args__v10 = 0U;
    __VdlySet__args__v12 = 0U;
    __VdlySet__args__v14 = 0U;
    __VdlySet__args__v16 = 0U;
    __VdlySet__args__v18 = 0U;
    __VdlySet__args__v20 = 0U;
    __VdlySet__args__v22 = 0U;
    __VdlySet__args__v24 = 0U;
    __VdlySet__args__v26 = 0U;
    __VdlySet__args__v28 = 0U;
    __VdlySet__args__v30 = 0U;
    __VdlySet__args__v32 = 0U;
    __VdlySet__args__v34 = 0U;
    __VdlySet__args__v36 = 0U;
    __VdlySet__args__v38 = 0U;
    __VdlySet__args__v40 = 0U;
    __VdlySet__args__v42 = 0U;
    __VdlySet__args__v44 = 0U;
    __VdlySet__args__v46 = 0U;
    __VdlySet__args__v48 = 0U;
    __VdlySet__args__v50 = 0U;
    __VdlySet__args__v52 = 0U;
    __VdlySet__args__v54 = 0U;
    __Vdly__i2c_wack_valid = vlSelfRef.__PVT__i2c_wack_valid;
    __Vdly__i2c_i0__DOT__rack = vlSelfRef.__PVT__i2c_i0__DOT__rack;
    __Vdly__i2c_i0__DOT__wdata = vlSelfRef.__PVT__i2c_i0__DOT__wdata;
    __Vdly__i2c_i0__DOT__bit_op_valid = vlSelfRef.__PVT__i2c_i0__DOT__bit_op_valid;
    __Vdly__i2c_i0__DOT__bit_op_mode = vlSelfRef.__PVT__i2c_i0__DOT__bit_op_mode;
    __Vdly__i2c_i0__DOT__byte_counter = vlSelfRef.__PVT__i2c_i0__DOT__byte_counter;
    __Vdly__i2c_i0__DOT__bit_op_wdata = vlSelfRef.__PVT__i2c_i0__DOT__bit_op_wdata;
    __Vdly__i2c_wack = vlSelfRef.__PVT__i2c_wack;
    __Vdly__i2c_i0__DOT__state = vlSelfRef.__PVT__i2c_i0__DOT__state;
    __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter 
        = ((IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick)
            ? 0x1f3U : (0x1ffU & ((IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter) 
                                  - (IData)(1U))));
    vlSelfRef.__PVT__i2c_rdata_valid = 0U;
    __Vdly__i2c_wack_valid = 0U;
    if (((((((((0U == vlSelfRef.__PVT__i2c_i0__DOT__state) 
               | (1U == vlSelfRef.__PVT__i2c_i0__DOT__state)) 
              | (2U == vlSelfRef.__PVT__i2c_i0__DOT__state)) 
             | (3U == vlSelfRef.__PVT__i2c_i0__DOT__state)) 
            | (4U == vlSelfRef.__PVT__i2c_i0__DOT__state)) 
           | (5U == vlSelfRef.__PVT__i2c_i0__DOT__state)) 
          | (6U == vlSelfRef.__PVT__i2c_i0__DOT__state)) 
         | (7U == vlSelfRef.__PVT__i2c_i0__DOT__state))) {
        if ((0U == vlSelfRef.__PVT__i2c_i0__DOT__state)) {
            if (((IData)(vlSelfRef.__PVT__i2c_op_ready) 
                 & (IData)(vlSelfRef.__PVT__i2c_op_valid))) {
                __Vdly__i2c_i0__DOT__rack = vlSelfRef.__PVT__i2c_op_rack;
                __Vdly__i2c_i0__DOT__wdata = vlSelfRef.__PVT__i2c_op_wdata;
                __Vdly__i2c_i0__DOT__state = ((2U & (IData)(vlSelfRef.__PVT__i2c_op_mode))
                                               ? ((1U 
                                                   & (IData)(vlSelfRef.__PVT__i2c_op_mode))
                                                   ? 8U
                                                   : 5U)
                                               : ((1U 
                                                   & (IData)(vlSelfRef.__PVT__i2c_op_mode))
                                                   ? 2U
                                                   : 1U));
            }
        } else if ((1U == vlSelfRef.__PVT__i2c_i0__DOT__state)) {
            __Vdly__i2c_i0__DOT__bit_op_valid = 1U;
            __Vdly__i2c_i0__DOT__bit_op_mode = 0U;
            if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state) 
                 & (IData)(vlSelfRef.__PVT__i2c_i0__DOT__bit_op_valid))) {
                __Vdly__i2c_i0__DOT__bit_op_valid = 0U;
                __Vdly__i2c_i0__DOT__state = 0U;
            }
        } else if ((2U == vlSelfRef.__PVT__i2c_i0__DOT__state)) {
            __Vdly__i2c_i0__DOT__bit_op_valid = 1U;
            __Vdly__i2c_i0__DOT__bit_op_mode = 1U;
            if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state) 
                 & (IData)(vlSelfRef.__PVT__i2c_i0__DOT__bit_op_valid))) {
                __Vdly__i2c_i0__DOT__bit_op_valid = 0U;
                __Vdly__i2c_i0__DOT__state = 3U;
            }
        } else if ((3U == vlSelfRef.__PVT__i2c_i0__DOT__state)) {
            if (vlSelfRef.__PVT__i2c_i0__DOT__bit_rdata_valid) {
                vlSelfRef.__PVT__i2c_rdata = ((0xfeU 
                                               & (IData)(vlSelfRef.__PVT__i2c_rdata)) 
                                              | (IData)(vlSelfRef.__PVT__i2c_i0__DOT__bit_rdata));
                if ((7U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__byte_counter))) {
                    vlSelfRef.__PVT__i2c_rdata_valid = 1U;
                    __Vdly__i2c_i0__DOT__byte_counter = 0U;
                    __Vdly__i2c_i0__DOT__state = 4U;
                } else {
                    __Vdly__i2c_i0__DOT__byte_counter 
                        = (7U & ((IData)(1U) + (IData)(vlSelfRef.__PVT__i2c_i0__DOT__byte_counter)));
                    __Vdly__i2c_i0__DOT__state = 2U;
                }
            }
        } else if ((4U == vlSelfRef.__PVT__i2c_i0__DOT__state)) {
            __Vdly__i2c_i0__DOT__bit_op_valid = 1U;
            __Vdly__i2c_i0__DOT__bit_op_mode = 2U;
            __Vdly__i2c_i0__DOT__bit_op_wdata = (1U 
                                                 & (~ (IData)(vlSelfRef.__PVT__i2c_i0__DOT__rack)));
            if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state) 
                 & (IData)(vlSelfRef.__PVT__i2c_i0__DOT__bit_op_valid))) {
                __Vdly__i2c_i0__DOT__bit_op_valid = 0U;
                __Vdly__i2c_i0__DOT__state = 0U;
            }
        } else if ((5U == vlSelfRef.__PVT__i2c_i0__DOT__state)) {
            __Vdly__i2c_i0__DOT__bit_op_valid = 1U;
            __Vdly__i2c_i0__DOT__bit_op_mode = 2U;
            __Vdly__i2c_i0__DOT__bit_op_wdata = (1U 
                                                 & ((IData)(vlSelfRef.__PVT__i2c_i0__DOT__wdata) 
                                                    >> 7U));
            if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state) 
                 & (IData)(vlSelfRef.__PVT__i2c_i0__DOT__bit_op_valid))) {
                __Vdly__i2c_i0__DOT__wdata = (0xffU 
                                              & VL_SHIFTL_III(8,8,32, (IData)(vlSelfRef.__PVT__i2c_i0__DOT__wdata), 1U));
                __Vdly__i2c_i0__DOT__bit_op_valid = 0U;
                if ((7U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__byte_counter))) {
                    __Vdly__i2c_i0__DOT__byte_counter = 0U;
                    __Vdly__i2c_i0__DOT__state = 6U;
                } else {
                    __Vdly__i2c_i0__DOT__byte_counter 
                        = (7U & ((IData)(1U) + (IData)(vlSelfRef.__PVT__i2c_i0__DOT__byte_counter)));
                }
            }
        } else if ((6U == vlSelfRef.__PVT__i2c_i0__DOT__state)) {
            __Vdly__i2c_i0__DOT__bit_op_valid = 1U;
            __Vdly__i2c_i0__DOT__bit_op_mode = 1U;
            if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state) 
                 & (IData)(vlSelfRef.__PVT__i2c_i0__DOT__bit_op_valid))) {
                __Vdly__i2c_i0__DOT__bit_op_valid = 0U;
                __Vdly__i2c_i0__DOT__state = 7U;
            }
        } else if (vlSelfRef.__PVT__i2c_i0__DOT__bit_rdata_valid) {
            __Vdly__i2c_wack_valid = 1U;
            __Vdly__i2c_wack = (1U & (~ (IData)(vlSelfRef.__PVT__i2c_i0__DOT__bit_rdata)));
            __Vdly__i2c_i0__DOT__state = 0U;
        }
    } else if ((8U == vlSelfRef.__PVT__i2c_i0__DOT__state)) {
        __Vdly__i2c_i0__DOT__bit_op_valid = 1U;
        __Vdly__i2c_i0__DOT__bit_op_mode = 3U;
        if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state) 
             & (IData)(vlSelfRef.__PVT__i2c_i0__DOT__bit_op_valid))) {
            __Vdly__i2c_i0__DOT__bit_op_valid = 0U;
            __Vdly__i2c_i0__DOT__state = 0U;
        }
    }
    vlSelfRef.__PVT__i2c_i0__DOT__rack = __Vdly__i2c_i0__DOT__rack;
    vlSelfRef.__PVT__i2c_i0__DOT__wdata = __Vdly__i2c_i0__DOT__wdata;
    if (vlSymsp->TOP.tb__DOT__rst) {
        __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter = 0U;
        __Vdly__i2c_i0__DOT__bit_op_valid = 0U;
        __Vdly__i2c_i0__DOT__byte_counter = 0U;
        __Vdly__i2c_i0__DOT__state = 0U;
    }
    vlSelfRef.__PVT__i2c_i0__DOT__byte_counter = __Vdly__i2c_i0__DOT__byte_counter;
    vlSelfRef.__PVT__i2c_i0__DOT__bit_rdata_valid = 0U;
    if ((0U == vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state)) {
        if (((IData)(vlSelfRef.__PVT__i2c_i0__DOT__bit_op_ready) 
             & (IData)(vlSelfRef.__PVT__i2c_i0__DOT__bit_op_valid))) {
            __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state 
                = ((2U & (IData)(vlSelfRef.__PVT__i2c_i0__DOT__bit_op_mode))
                    ? ((1U & (IData)(vlSelfRef.__PVT__i2c_i0__DOT__bit_op_mode))
                        ? 4U : 3U) : ((1U & (IData)(vlSelfRef.__PVT__i2c_i0__DOT__bit_op_mode))
                                       ? 2U : 1U));
            __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__wdata 
                = vlSelfRef.__PVT__i2c_i0__DOT__bit_op_wdata;
        }
    } else if ((1U == vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state)) {
        if ((0U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter))) {
            if ((0U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                vlSelfRef.sda_o = 1U;
            } else if ((1U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                vlSelfRef.scl_o = 1U;
            } else if ((2U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                vlSelfRef.sda_o = 0U;
            } else if ((3U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                vlSelfRef.scl_o = 0U;
            }
        }
    } else if ((2U == vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state)) {
        if ((0U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter))) {
            if ((0U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                vlSelfRef.sda_o = 1U;
            } else if ((1U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                vlSelfRef.scl_o = 1U;
                vlSelfRef.__PVT__i2c_i0__DOT__bit_rdata 
                    = vlSelfRef.sda_i;
                vlSelfRef.__PVT__i2c_i0__DOT__bit_rdata_valid = 1U;
            } else if ((2U != (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                if ((3U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                    vlSelfRef.scl_o = 0U;
                }
            }
        }
    } else if ((3U == vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state)) {
        if ((0U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter))) {
            if ((0U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                vlSelfRef.sda_o = vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__wdata;
            } else if ((1U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                vlSelfRef.scl_o = 1U;
            } else if ((2U != (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                if ((3U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                    vlSelfRef.scl_o = 0U;
                }
            }
        }
    } else if ((4U == vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state)) {
        if ((0U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter))) {
            if ((0U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                vlSelfRef.sda_o = 0U;
            } else if ((1U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                vlSelfRef.scl_o = 1U;
            } else if ((2U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
                vlSelfRef.sda_o = 1U;
            }
        }
    }
    if (((0U != vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state) 
         & (0U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter)))) {
        if ((3U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i))) {
            __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state = 0U;
            __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i = 0U;
        } else {
            __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i 
                = (3U & ((IData)(1U) + (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i)));
        }
    }
    __Vdly__pc = (0xffffU & ((IData)(1U) + (IData)(vlSelfRef.__PVT__pc)));
    if ((0U != vlSelfRef.__PVT__time_counter)) {
        __Vdly__time_counter = (vlSelfRef.__PVT__time_counter 
                                - (IData)(1U));
    }
    if (((((((((0U == (IData)(vlSelfRef.__PVT__pc)) 
               | (1U == (IData)(vlSelfRef.__PVT__pc))) 
              | (2U == (IData)(vlSelfRef.__PVT__pc))) 
             | (3U == (IData)(vlSelfRef.__PVT__pc))) 
            | (4U == (IData)(vlSelfRef.__PVT__pc))) 
           | (0xaU == (IData)(vlSelfRef.__PVT__pc))) 
          | (0xbU == (IData)(vlSelfRef.__PVT__pc))) 
         | (0xcU == (IData)(vlSelfRef.__PVT__pc)))) {
        if ((0U == (IData)(vlSelfRef.__PVT__pc))) {
            __VdlySet__args__v0 = 1U;
            __VdlyVal__call_stack__v0 = (0xffffU & 
                                         ((IData)(1U) 
                                          + (IData)(vlSelfRef.__PVT__pc)));
            __VdlyDim0__call_stack__v0 = vlSelfRef.__PVT__call_stack_pos;
            __Vdly__call_stack_pos = (7U & ((IData)(1U) 
                                            + (IData)(vlSelfRef.__PVT__call_stack_pos)));
            __VdlySet__args__v2 = 1U;
            __Vdly__pc = 0x32U;
        } else if ((1U == (IData)(vlSelfRef.__PVT__pc))) {
            __VdlySet__args__v4 = 1U;
            __VdlyVal__call_stack__v1 = (0xffffU & 
                                         ((IData)(1U) 
                                          + (IData)(vlSelfRef.__PVT__pc)));
            __VdlyDim0__call_stack__v1 = vlSelfRef.__PVT__call_stack_pos;
            __Vdly__call_stack_pos = (7U & ((IData)(1U) 
                                            + (IData)(vlSelfRef.__PVT__call_stack_pos)));
            __VdlySet__args__v6 = 1U;
            __Vdly__pc = 0xaU;
        } else if ((2U == (IData)(vlSelfRef.__PVT__pc))) {
            __VdlySet__args__v8 = 1U;
            __VdlyVal__call_stack__v2 = (0xffffU & 
                                         ((IData)(1U) 
                                          + (IData)(vlSelfRef.__PVT__pc)));
            __VdlyDim0__call_stack__v2 = vlSelfRef.__PVT__call_stack_pos;
            __Vdly__call_stack_pos = (7U & ((IData)(1U) 
                                            + (IData)(vlSelfRef.__PVT__call_stack_pos)));
            __VdlySet__args__v10 = 1U;
            __Vdly__pc = 0x14U;
        } else if ((3U == (IData)(vlSelfRef.__PVT__pc))) {
            vlSelfRef.done = 1U;
        } else if ((4U == (IData)(vlSelfRef.__PVT__pc))) {
            __Vdly__pc = vlSelfRef.__PVT__pc;
        } else if ((0xaU == (IData)(vlSelfRef.__PVT__pc))) {
            __Vdly__pc = vlSelfRef.__PVT__pc;
            vlSelfRef.__PVT__i2c_op_mode = 0U;
            vlSelfRef.__PVT__i2c_op_wdata = 0U;
            vlSelfRef.__PVT__i2c_op_rack = 0U;
            __Vdly__i2c_op_valid = 1U;
            if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__state) 
                 & (IData)(vlSelfRef.__PVT__i2c_op_valid))) {
                __Vdly__pc = (0xffffU & ((IData)(1U) 
                                         + (IData)(vlSelfRef.__PVT__pc)));
                __Vdly__i2c_op_valid = 0U;
            }
        } else if ((0xbU == (IData)(vlSelfRef.__PVT__pc))) {
            __Vdly__pc = vlSelfRef.__PVT__pc;
            vlSelfRef.__PVT__i2c_op_mode = 2U;
            vlSelfRef.__PVT__i2c_op_wdata = 0xe8U;
            vlSelfRef.__PVT__i2c_op_rack = 0U;
            __Vdly__i2c_op_valid = 1U;
            if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__state) 
                 & (IData)(vlSelfRef.__PVT__i2c_op_valid))) {
                __Vdly__pc = (0xffffU & ((IData)(1U) 
                                         + (IData)(vlSelfRef.__PVT__pc)));
                __Vdly__i2c_op_valid = 0U;
            }
        } else {
            __Vdly__pc = vlSelfRef.__PVT__pc;
            if (vlSelfRef.__PVT__i2c_wack_valid) {
                __Vdly__pc = ((IData)(vlSelfRef.__PVT__i2c_wack)
                               ? (0xffffU & ((IData)(1U) 
                                             + (IData)(vlSelfRef.__PVT__pc)))
                               : 0x3cU);
            }
        }
    } else if (((((((((0xdU == (IData)(vlSelfRef.__PVT__pc)) 
                      | (0xeU == (IData)(vlSelfRef.__PVT__pc))) 
                     | (0xfU == (IData)(vlSelfRef.__PVT__pc))) 
                    | (0x10U == (IData)(vlSelfRef.__PVT__pc))) 
                   | (0x14U == (IData)(vlSelfRef.__PVT__pc))) 
                  | (0x15U == (IData)(vlSelfRef.__PVT__pc))) 
                 | (0x16U == (IData)(vlSelfRef.__PVT__pc))) 
                | (0x17U == (IData)(vlSelfRef.__PVT__pc)))) {
        if ((0xdU == (IData)(vlSelfRef.__PVT__pc))) {
            __Vdly__pc = vlSelfRef.__PVT__pc;
            vlSelfRef.__PVT__i2c_op_mode = 2U;
            vlSelfRef.__PVT__i2c_op_wdata = 0x20U;
            vlSelfRef.__PVT__i2c_op_rack = 0U;
            __Vdly__i2c_op_valid = 1U;
            if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__state) 
                 & (IData)(vlSelfRef.__PVT__i2c_op_valid))) {
                __Vdly__pc = (0xffffU & ((IData)(1U) 
                                         + (IData)(vlSelfRef.__PVT__pc)));
                __Vdly__i2c_op_valid = 0U;
            }
        } else if ((0xeU == (IData)(vlSelfRef.__PVT__pc))) {
            __Vdly__pc = vlSelfRef.__PVT__pc;
            if (vlSelfRef.__PVT__i2c_wack_valid) {
                __Vdly__pc = ((IData)(vlSelfRef.__PVT__i2c_wack)
                               ? (0xffffU & ((IData)(1U) 
                                             + (IData)(vlSelfRef.__PVT__pc)))
                               : 0x3cU);
            }
        } else if ((0xfU == (IData)(vlSelfRef.__PVT__pc))) {
            __Vdly__pc = vlSelfRef.__PVT__pc;
            vlSelfRef.__PVT__i2c_op_mode = 3U;
            vlSelfRef.__PVT__i2c_op_wdata = 0U;
            vlSelfRef.__PVT__i2c_op_rack = 0U;
            __Vdly__i2c_op_valid = 1U;
            if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__state) 
                 & (IData)(vlSelfRef.__PVT__i2c_op_valid))) {
                __Vdly__pc = (0xffffU & ((IData)(1U) 
                                         + (IData)(vlSelfRef.__PVT__pc)));
                __Vdly__i2c_op_valid = 0U;
            }
        } else if ((0x10U == (IData)(vlSelfRef.__PVT__pc))) {
            __Vdly__pc = vlSelfRef.__PVT__call_stack
                [(7U & ((IData)(vlSelfRef.__PVT__call_stack_pos) 
                        - (IData)(1U)))];
            __Vdly__call_stack_pos = (7U & ((IData)(vlSelfRef.__PVT__call_stack_pos) 
                                            - (IData)(1U)));
        } else if ((0x14U == (IData)(vlSelfRef.__PVT__pc))) {
            __VdlySet__args__v12 = 1U;
            __VdlyVal__call_stack__v3 = (0xffffU & 
                                         ((IData)(1U) 
                                          + (IData)(vlSelfRef.__PVT__pc)));
            __VdlyDim0__call_stack__v3 = vlSelfRef.__PVT__call_stack_pos;
            __Vdly__call_stack_pos = (7U & ((IData)(1U) 
                                            + (IData)(vlSelfRef.__PVT__call_stack_pos)));
            __VdlySet__args__v14 = 1U;
            __Vdly__pc = 0x28U;
        } else if ((0x15U == (IData)(vlSelfRef.__PVT__pc))) {
            __VdlySet__args__v16 = 1U;
            __VdlyVal__call_stack__v4 = (0xffffU & 
                                         ((IData)(1U) 
                                          + (IData)(vlSelfRef.__PVT__pc)));
            __VdlyDim0__call_stack__v4 = vlSelfRef.__PVT__call_stack_pos;
            __Vdly__call_stack_pos = (7U & ((IData)(1U) 
                                            + (IData)(vlSelfRef.__PVT__call_stack_pos)));
            __VdlySet__args__v18 = 1U;
            __Vdly__pc = 0x28U;
        } else if ((0x16U == (IData)(vlSelfRef.__PVT__pc))) {
            __VdlySet__args__v20 = 1U;
            __VdlyVal__call_stack__v5 = (0xffffU & 
                                         ((IData)(1U) 
                                          + (IData)(vlSelfRef.__PVT__pc)));
            __VdlyDim0__call_stack__v5 = vlSelfRef.__PVT__call_stack_pos;
            __Vdly__call_stack_pos = (7U & ((IData)(1U) 
                                            + (IData)(vlSelfRef.__PVT__call_stack_pos)));
            __VdlySet__args__v22 = 1U;
            __Vdly__pc = 0x28U;
        } else {
            __VdlySet__args__v24 = 1U;
            __VdlyVal__call_stack__v6 = (0xffffU & 
                                         ((IData)(1U) 
                                          + (IData)(vlSelfRef.__PVT__pc)));
            __VdlyDim0__call_stack__v6 = vlSelfRef.__PVT__call_stack_pos;
            __Vdly__call_stack_pos = (7U & ((IData)(1U) 
                                            + (IData)(vlSelfRef.__PVT__call_stack_pos)));
            __VdlySet__args__v26 = 1U;
            __Vdly__pc = 0x28U;
        }
    } else if (((((((((0x18U == (IData)(vlSelfRef.__PVT__pc)) 
                      | (0x19U == (IData)(vlSelfRef.__PVT__pc))) 
                     | (0x1aU == (IData)(vlSelfRef.__PVT__pc))) 
                    | (0x1bU == (IData)(vlSelfRef.__PVT__pc))) 
                   | (0x1cU == (IData)(vlSelfRef.__PVT__pc))) 
                  | (0x1dU == (IData)(vlSelfRef.__PVT__pc))) 
                 | (0x1eU == (IData)(vlSelfRef.__PVT__pc))) 
                | (0x1fU == (IData)(vlSelfRef.__PVT__pc)))) {
        if ((0x18U == (IData)(vlSelfRef.__PVT__pc))) {
            __VdlySet__args__v28 = 1U;
            __VdlyVal__call_stack__v7 = (0xffffU & 
                                         ((IData)(1U) 
                                          + (IData)(vlSelfRef.__PVT__pc)));
            __VdlyDim0__call_stack__v7 = vlSelfRef.__PVT__call_stack_pos;
            __Vdly__call_stack_pos = (7U & ((IData)(1U) 
                                            + (IData)(vlSelfRef.__PVT__call_stack_pos)));
            __VdlySet__args__v30 = 1U;
            __Vdly__pc = 0x28U;
        } else if ((0x19U == (IData)(vlSelfRef.__PVT__pc))) {
            __VdlySet__args__v32 = 1U;
            __VdlyVal__call_stack__v8 = (0xffffU & 
                                         ((IData)(1U) 
                                          + (IData)(vlSelfRef.__PVT__pc)));
            __VdlyDim0__call_stack__v8 = vlSelfRef.__PVT__call_stack_pos;
            __Vdly__call_stack_pos = (7U & ((IData)(1U) 
                                            + (IData)(vlSelfRef.__PVT__call_stack_pos)));
            __VdlySet__args__v34 = 1U;
            __Vdly__pc = 0x28U;
        } else if ((0x1aU == (IData)(vlSelfRef.__PVT__pc))) {
            __VdlySet__args__v36 = 1U;
            __VdlyVal__call_stack__v9 = (0xffffU & 
                                         ((IData)(1U) 
                                          + (IData)(vlSelfRef.__PVT__pc)));
            __VdlyDim0__call_stack__v9 = vlSelfRef.__PVT__call_stack_pos;
            __Vdly__call_stack_pos = (7U & ((IData)(1U) 
                                            + (IData)(vlSelfRef.__PVT__call_stack_pos)));
            __VdlySet__args__v38 = 1U;
            __Vdly__pc = 0x28U;
        } else if ((0x1bU == (IData)(vlSelfRef.__PVT__pc))) {
            __VdlySet__args__v40 = 1U;
            __VdlyVal__call_stack__v10 = (0xffffU & 
                                          ((IData)(1U) 
                                           + (IData)(vlSelfRef.__PVT__pc)));
            __VdlyDim0__call_stack__v10 = vlSelfRef.__PVT__call_stack_pos;
            __Vdly__call_stack_pos = (7U & ((IData)(1U) 
                                            + (IData)(vlSelfRef.__PVT__call_stack_pos)));
            __VdlySet__args__v42 = 1U;
            __Vdly__pc = 0x28U;
        } else if ((0x1cU == (IData)(vlSelfRef.__PVT__pc))) {
            __VdlySet__args__v44 = 1U;
            __VdlyVal__call_stack__v11 = (0xffffU & 
                                          ((IData)(1U) 
                                           + (IData)(vlSelfRef.__PVT__pc)));
            __VdlyDim0__call_stack__v11 = vlSelfRef.__PVT__call_stack_pos;
            __Vdly__call_stack_pos = (7U & ((IData)(1U) 
                                            + (IData)(vlSelfRef.__PVT__call_stack_pos)));
            __VdlySet__args__v46 = 1U;
            __Vdly__pc = 0x28U;
        } else if ((0x1dU == (IData)(vlSelfRef.__PVT__pc))) {
            __VdlySet__args__v48 = 1U;
            __VdlyVal__call_stack__v12 = (0xffffU & 
                                          ((IData)(1U) 
                                           + (IData)(vlSelfRef.__PVT__pc)));
            __VdlyDim0__call_stack__v12 = vlSelfRef.__PVT__call_stack_pos;
            __Vdly__call_stack_pos = (7U & ((IData)(1U) 
                                            + (IData)(vlSelfRef.__PVT__call_stack_pos)));
            __VdlySet__args__v50 = 1U;
            __Vdly__pc = 0x28U;
        } else if ((0x1eU == (IData)(vlSelfRef.__PVT__pc))) {
            __VdlySet__args__v52 = 1U;
            __VdlyVal__call_stack__v13 = (0xffffU & 
                                          ((IData)(1U) 
                                           + (IData)(vlSelfRef.__PVT__pc)));
            __VdlyDim0__call_stack__v13 = vlSelfRef.__PVT__call_stack_pos;
            __Vdly__call_stack_pos = (7U & ((IData)(1U) 
                                            + (IData)(vlSelfRef.__PVT__call_stack_pos)));
            __VdlySet__args__v54 = 1U;
            __Vdly__pc = 0x28U;
        } else {
            __Vdly__pc = vlSelfRef.__PVT__call_stack
                [(7U & ((IData)(vlSelfRef.__PVT__call_stack_pos) 
                        - (IData)(1U)))];
            __Vdly__call_stack_pos = (7U & ((IData)(vlSelfRef.__PVT__call_stack_pos) 
                                            - (IData)(1U)));
        }
    } else if (((((((((0x28U == (IData)(vlSelfRef.__PVT__pc)) 
                      | (0x29U == (IData)(vlSelfRef.__PVT__pc))) 
                     | (0x2aU == (IData)(vlSelfRef.__PVT__pc))) 
                    | (0x2bU == (IData)(vlSelfRef.__PVT__pc))) 
                   | (0x2cU == (IData)(vlSelfRef.__PVT__pc))) 
                  | (0x2dU == (IData)(vlSelfRef.__PVT__pc))) 
                 | (0x2eU == (IData)(vlSelfRef.__PVT__pc))) 
                | (0x2fU == (IData)(vlSelfRef.__PVT__pc)))) {
        if ((0x28U == (IData)(vlSelfRef.__PVT__pc))) {
            __Vdly__pc = vlSelfRef.__PVT__pc;
            vlSelfRef.__PVT__i2c_op_mode = 0U;
            vlSelfRef.__PVT__i2c_op_wdata = 0U;
            vlSelfRef.__PVT__i2c_op_rack = 0U;
            __Vdly__i2c_op_valid = 1U;
            if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__state) 
                 & (IData)(vlSelfRef.__PVT__i2c_op_valid))) {
                __Vdly__pc = (0xffffU & ((IData)(1U) 
                                         + (IData)(vlSelfRef.__PVT__pc)));
                __Vdly__i2c_op_valid = 0U;
            }
        } else if ((0x29U == (IData)(vlSelfRef.__PVT__pc))) {
            __Vdly__pc = vlSelfRef.__PVT__pc;
            vlSelfRef.__PVT__i2c_op_mode = 2U;
            vlSelfRef.__PVT__i2c_op_wdata = 0x72U;
            vlSelfRef.__PVT__i2c_op_rack = 0U;
            __Vdly__i2c_op_valid = 1U;
            if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__state) 
                 & (IData)(vlSelfRef.__PVT__i2c_op_valid))) {
                __Vdly__pc = (0xffffU & ((IData)(1U) 
                                         + (IData)(vlSelfRef.__PVT__pc)));
                __Vdly__i2c_op_valid = 0U;
            }
        } else if ((0x2aU == (IData)(vlSelfRef.__PVT__pc))) {
            __Vdly__pc = vlSelfRef.__PVT__pc;
            if (vlSelfRef.__PVT__i2c_wack_valid) {
                __Vdly__pc = ((IData)(vlSelfRef.__PVT__i2c_wack)
                               ? (0xffffU & ((IData)(1U) 
                                             + (IData)(vlSelfRef.__PVT__pc)))
                               : 0x3cU);
            }
        } else if ((0x2bU == (IData)(vlSelfRef.__PVT__pc))) {
            __Vtask_i2c_send_op__26__wdata = (0xffU 
                                              & vlSelfRef.__PVT__args
                                              [0U]);
            __Vdly__pc = vlSelfRef.__PVT__pc;
            vlSelfRef.__PVT__i2c_op_mode = 2U;
            vlSelfRef.__PVT__i2c_op_wdata = __Vtask_i2c_send_op__26__wdata;
            vlSelfRef.__PVT__i2c_op_rack = 0U;
            __Vdly__i2c_op_valid = 1U;
            if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__state) 
                 & (IData)(vlSelfRef.__PVT__i2c_op_valid))) {
                __Vdly__pc = (0xffffU & ((IData)(1U) 
                                         + (IData)(vlSelfRef.__PVT__pc)));
                __Vdly__i2c_op_valid = 0U;
            }
        } else if ((0x2cU == (IData)(vlSelfRef.__PVT__pc))) {
            __Vdly__pc = vlSelfRef.__PVT__pc;
            if (vlSelfRef.__PVT__i2c_wack_valid) {
                __Vdly__pc = ((IData)(vlSelfRef.__PVT__i2c_wack)
                               ? (0xffffU & ((IData)(1U) 
                                             + (IData)(vlSelfRef.__PVT__pc)))
                               : 0x3cU);
            }
        } else if ((0x2dU == (IData)(vlSelfRef.__PVT__pc))) {
            __Vtask_i2c_send_op__28__wdata = (0xffU 
                                              & vlSelfRef.__PVT__args
                                              [1U]);
            __Vdly__pc = vlSelfRef.__PVT__pc;
            vlSelfRef.__PVT__i2c_op_mode = 2U;
            vlSelfRef.__PVT__i2c_op_wdata = __Vtask_i2c_send_op__28__wdata;
            vlSelfRef.__PVT__i2c_op_rack = 0U;
            __Vdly__i2c_op_valid = 1U;
            if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__state) 
                 & (IData)(vlSelfRef.__PVT__i2c_op_valid))) {
                __Vdly__pc = (0xffffU & ((IData)(1U) 
                                         + (IData)(vlSelfRef.__PVT__pc)));
                __Vdly__i2c_op_valid = 0U;
            }
        } else if ((0x2eU == (IData)(vlSelfRef.__PVT__pc))) {
            __Vdly__pc = vlSelfRef.__PVT__pc;
            if (vlSelfRef.__PVT__i2c_wack_valid) {
                __Vdly__pc = ((IData)(vlSelfRef.__PVT__i2c_wack)
                               ? (0xffffU & ((IData)(1U) 
                                             + (IData)(vlSelfRef.__PVT__pc)))
                               : 0x3cU);
            }
        } else {
            __Vdly__pc = vlSelfRef.__PVT__pc;
            vlSelfRef.__PVT__i2c_op_mode = 3U;
            vlSelfRef.__PVT__i2c_op_wdata = 0U;
            vlSelfRef.__PVT__i2c_op_rack = 0U;
            __Vdly__i2c_op_valid = 1U;
            if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__state) 
                 & (IData)(vlSelfRef.__PVT__i2c_op_valid))) {
                __Vdly__pc = (0xffffU & ((IData)(1U) 
                                         + (IData)(vlSelfRef.__PVT__pc)));
                __Vdly__i2c_op_valid = 0U;
            }
        }
    } else if ((0x30U == (IData)(vlSelfRef.__PVT__pc))) {
        __Vdly__pc = vlSelfRef.__PVT__call_stack[(7U 
                                                  & ((IData)(vlSelfRef.__PVT__call_stack_pos) 
                                                     - (IData)(1U)))];
        __Vdly__call_stack_pos = (7U & ((IData)(vlSelfRef.__PVT__call_stack_pos) 
                                        - (IData)(1U)));
    } else if ((0x32U == (IData)(vlSelfRef.__PVT__pc))) {
        __Vdly__time_counter = vlSelfRef.__PVT__args
            [0U];
    } else if ((0x33U == (IData)(vlSelfRef.__PVT__pc))) {
        if ((0U == vlSelfRef.__PVT__time_counter)) {
            __Vdly__pc = vlSelfRef.__PVT__call_stack
                [(7U & ((IData)(vlSelfRef.__PVT__call_stack_pos) 
                        - (IData)(1U)))];
            __Vdly__call_stack_pos = (7U & ((IData)(vlSelfRef.__PVT__call_stack_pos) 
                                            - (IData)(1U)));
        } else {
            __Vdly__pc = vlSelfRef.__PVT__pc;
        }
    } else if ((0x3cU == (IData)(vlSelfRef.__PVT__pc))) {
        __Vdly__pc = vlSelfRef.__PVT__pc;
        vlSelfRef.__PVT__i2c_op_mode = 3U;
        vlSelfRef.__PVT__i2c_op_wdata = 0U;
        vlSelfRef.__PVT__i2c_op_rack = 0U;
        __Vdly__i2c_op_valid = 1U;
        if (((0U == vlSelfRef.__PVT__i2c_i0__DOT__state) 
             & (IData)(vlSelfRef.__PVT__i2c_op_valid))) {
            __Vdly__pc = (0xffffU & ((IData)(1U) + (IData)(vlSelfRef.__PVT__pc)));
            __Vdly__i2c_op_valid = 0U;
        }
    } else if ((0x3dU == (IData)(vlSelfRef.__PVT__pc))) {
        vlSelfRef.error = 1U;
    } else if ((0x3eU == (IData)(vlSelfRef.__PVT__pc))) {
        __Vdly__pc = vlSelfRef.__PVT__pc;
    }
    if (vlSymsp->TOP.tb__DOT__rst) {
        __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state = 0U;
        vlSelfRef.__PVT__i2c_i0__DOT__bit_rdata_valid = 0U;
        vlSelfRef.sda_o = 1U;
        vlSelfRef.scl_o = 1U;
        __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i = 0U;
        __Vdly__call_stack_pos = 0U;
        __Vdly__i2c_op_valid = 0U;
        vlSelfRef.error = 0U;
        vlSelfRef.done = 0U;
        __Vdly__pc = 0U;
        __Vdly__time_counter = 0U;
    }
    vlSelfRef.__PVT__i2c_i0__DOT__bit_op_mode = __Vdly__i2c_i0__DOT__bit_op_mode;
    vlSelfRef.__PVT__i2c_i0__DOT__bit_op_wdata = __Vdly__i2c_i0__DOT__bit_op_wdata;
    vlSelfRef.__PVT__i2c_i0__DOT__bit_op_valid = __Vdly__i2c_i0__DOT__bit_op_valid;
    vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__wdata 
        = __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__wdata;
    vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i 
        = __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i;
    vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state 
        = __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state;
    vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter 
        = __Vdly__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter;
    vlSelfRef.__PVT__i2c_wack_valid = __Vdly__i2c_wack_valid;
    vlSelfRef.__PVT__i2c_wack = __Vdly__i2c_wack;
    vlSelfRef.__PVT__pc = __Vdly__pc;
    vlSelfRef.__PVT__time_counter = __Vdly__time_counter;
    vlSelfRef.__PVT__call_stack_pos = __Vdly__call_stack_pos;
    vlSelfRef.__PVT__i2c_op_valid = __Vdly__i2c_op_valid;
    vlSelfRef.__PVT__i2c_i0__DOT__state = __Vdly__i2c_i0__DOT__state;
    if (__VdlySet__args__v0) {
        vlSelfRef.__PVT__args[0U] = 0x61a80U;
        vlSelfRef.__PVT__call_stack[__VdlyDim0__call_stack__v0] 
            = __VdlyVal__call_stack__v0;
        vlSelfRef.__PVT__args[1U] = 0U;
    }
    if (__VdlySet__args__v2) {
        vlSelfRef.__PVT__args[2U] = 0U;
        vlSelfRef.__PVT__args[3U] = 0U;
    }
    if (__VdlySet__args__v4) {
        vlSelfRef.__PVT__args[0U] = 0U;
        vlSelfRef.__PVT__call_stack[__VdlyDim0__call_stack__v1] 
            = __VdlyVal__call_stack__v1;
        vlSelfRef.__PVT__args[1U] = 0U;
    }
    if (__VdlySet__args__v6) {
        vlSelfRef.__PVT__args[2U] = 0U;
        vlSelfRef.__PVT__args[3U] = 0U;
    }
    if (__VdlySet__args__v8) {
        vlSelfRef.__PVT__args[0U] = 0U;
        vlSelfRef.__PVT__call_stack[__VdlyDim0__call_stack__v2] 
            = __VdlyVal__call_stack__v2;
        vlSelfRef.__PVT__args[1U] = 0U;
    }
    if (__VdlySet__args__v10) {
        vlSelfRef.__PVT__args[2U] = 0U;
        vlSelfRef.__PVT__args[3U] = 0U;
    }
    if (__VdlySet__args__v12) {
        vlSelfRef.__PVT__args[0U] = 0x41U;
        vlSelfRef.__PVT__call_stack[__VdlyDim0__call_stack__v3] 
            = __VdlyVal__call_stack__v3;
        vlSelfRef.__PVT__args[1U] = 0x10U;
    }
    if (__VdlySet__args__v14) {
        vlSelfRef.__PVT__args[2U] = 0U;
        vlSelfRef.__PVT__args[3U] = 0U;
    }
    if (__VdlySet__args__v16) {
        vlSelfRef.__PVT__args[0U] = 0x98U;
        vlSelfRef.__PVT__call_stack[__VdlyDim0__call_stack__v4] 
            = __VdlyVal__call_stack__v4;
        vlSelfRef.__PVT__args[1U] = 3U;
    }
    if (__VdlySet__args__v18) {
        vlSelfRef.__PVT__args[2U] = 0U;
        vlSelfRef.__PVT__args[3U] = 0U;
    }
    if (__VdlySet__args__v20) {
        vlSelfRef.__PVT__args[0U] = 0x9aU;
        vlSelfRef.__PVT__call_stack[__VdlyDim0__call_stack__v5] 
            = __VdlyVal__call_stack__v5;
        vlSelfRef.__PVT__args[1U] = 0xe0U;
    }
    if (__VdlySet__args__v22) {
        vlSelfRef.__PVT__args[2U] = 0U;
        vlSelfRef.__PVT__args[3U] = 0U;
    }
    if (__VdlySet__args__v24) {
        vlSelfRef.__PVT__args[0U] = 0x9cU;
        vlSelfRef.__PVT__call_stack[__VdlyDim0__call_stack__v6] 
            = __VdlyVal__call_stack__v6;
        vlSelfRef.__PVT__args[1U] = 0x30U;
    }
    if (__VdlySet__args__v26) {
        vlSelfRef.__PVT__args[2U] = 0U;
        vlSelfRef.__PVT__args[3U] = 0U;
    }
    if (__VdlySet__args__v28) {
        vlSelfRef.__PVT__args[0U] = 0x9dU;
        vlSelfRef.__PVT__call_stack[__VdlyDim0__call_stack__v7] 
            = __VdlyVal__call_stack__v7;
        vlSelfRef.__PVT__args[1U] = 0x61U;
    }
    if (__VdlySet__args__v30) {
        vlSelfRef.__PVT__args[2U] = 0U;
        vlSelfRef.__PVT__args[3U] = 0U;
    }
    if (__VdlySet__args__v32) {
        vlSelfRef.__PVT__args[0U] = 0xa2U;
        vlSelfRef.__PVT__call_stack[__VdlyDim0__call_stack__v8] 
            = __VdlyVal__call_stack__v8;
        vlSelfRef.__PVT__args[1U] = 0xa4U;
    }
    if (__VdlySet__args__v34) {
        vlSelfRef.__PVT__args[2U] = 0U;
        vlSelfRef.__PVT__args[3U] = 0U;
    }
    if (__VdlySet__args__v36) {
        vlSelfRef.__PVT__args[0U] = 0xa3U;
        vlSelfRef.__PVT__call_stack[__VdlyDim0__call_stack__v9] 
            = __VdlyVal__call_stack__v9;
        vlSelfRef.__PVT__args[1U] = 0xa4U;
    }
    if (__VdlySet__args__v38) {
        vlSelfRef.__PVT__args[2U] = 0U;
        vlSelfRef.__PVT__args[3U] = 0U;
    }
    if (__VdlySet__args__v40) {
        vlSelfRef.__PVT__args[0U] = 0xe0U;
        vlSelfRef.__PVT__call_stack[__VdlyDim0__call_stack__v10] 
            = __VdlyVal__call_stack__v10;
        vlSelfRef.__PVT__args[1U] = 0xd0U;
    }
    if (__VdlySet__args__v42) {
        vlSelfRef.__PVT__args[2U] = 0U;
        vlSelfRef.__PVT__args[3U] = 0U;
    }
    if (__VdlySet__args__v44) {
        vlSelfRef.__PVT__args[0U] = 0xf9U;
        vlSelfRef.__PVT__call_stack[__VdlyDim0__call_stack__v11] 
            = __VdlyVal__call_stack__v11;
        vlSelfRef.__PVT__args[1U] = 0U;
    }
    if (__VdlySet__args__v46) {
        vlSelfRef.__PVT__args[2U] = 0U;
        vlSelfRef.__PVT__args[3U] = 0U;
    }
    if (__VdlySet__args__v48) {
        vlSelfRef.__PVT__args[0U] = 0x16U;
        vlSelfRef.__PVT__call_stack[__VdlyDim0__call_stack__v12] 
            = __VdlyVal__call_stack__v12;
        vlSelfRef.__PVT__args[1U] = 0x30U;
    }
    if (__VdlySet__args__v50) {
        vlSelfRef.__PVT__args[2U] = 0U;
        vlSelfRef.__PVT__args[3U] = 0U;
    }
    if (__VdlySet__args__v52) {
        vlSelfRef.__PVT__args[0U] = 0x17U;
        vlSelfRef.__PVT__call_stack[__VdlyDim0__call_stack__v13] 
            = __VdlyVal__call_stack__v13;
        vlSelfRef.__PVT__args[1U] = 2U;
    }
    if (__VdlySet__args__v54) {
        vlSelfRef.__PVT__args[2U] = 0U;
        vlSelfRef.__PVT__args[3U] = 0U;
    }
    vlSelfRef.__PVT__i2c_i0__DOT__bit_op_ready = (0U 
                                                  == vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state);
    vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick 
        = (0U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter));
    vlSelfRef.__PVT__i2c_op_ready = (0U == vlSelfRef.__PVT__i2c_i0__DOT__state);
}
