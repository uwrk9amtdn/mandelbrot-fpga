// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb.h for the primary calling header

#include "Vtb__pch.h"
#include "Vtb_ac701_adv7811_setup__Cz1.h"

VL_ATTR_COLD void Vtb_ac701_adv7811_setup__Cz1___eval_static__TOP__tb__DOT__ac701_adv7811_setup_i0(Vtb_ac701_adv7811_setup__Cz1* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+        Vtb_ac701_adv7811_setup__Cz1___eval_static__TOP__tb__DOT__ac701_adv7811_setup_i0\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.error = 0U;
    vlSelfRef.done = 0U;
    vlSelfRef.__PVT__pc = 0U;
    vlSelfRef.__PVT__time_counter = 0U;
    vlSelfRef.__PVT__call_stack_pos = 0U;
    vlSelfRef.__PVT__i2c_op_valid = 0U;
    vlSelfRef.__PVT__i2c_i0__DOT__bit_op_valid = 0U;
    vlSelfRef.__PVT__i2c_i0__DOT__byte_counter = 0U;
    vlSelfRef.__PVT__i2c_i0__DOT__state = 0U;
    vlSelfRef.__PVT__i2c_i0__DOT__bit_rdata_valid = 0U;
    vlSelfRef.sda_o = 0U;
    vlSelfRef.scl_o = 0U;
    vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state = 0U;
    vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter = 0U;
    vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i = 0U;
}

VL_ATTR_COLD void Vtb_ac701_adv7811_setup__Cz1___stl_sequent__TOP__tb__DOT__ac701_adv7811_setup_i0__0(Vtb_ac701_adv7811_setup__Cz1* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+        Vtb_ac701_adv7811_setup__Cz1___stl_sequent__TOP__tb__DOT__ac701_adv7811_setup_i0__0\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__PVT__i2c_op_ready = (0U == vlSelfRef.__PVT__i2c_i0__DOT__state);
    vlSelfRef.__PVT__i2c_i0__DOT__bit_op_ready = (0U 
                                                  == vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state);
    vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick 
        = (0U == (IData)(vlSelfRef.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter));
}

VL_ATTR_COLD void Vtb_ac701_adv7811_setup__Cz1___ctor_var_reset(Vtb_ac701_adv7811_setup__Cz1* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+        Vtb_ac701_adv7811_setup__Cz1___ctor_var_reset\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelf->clk = VL_RAND_RESET_I(1);
    vlSelf->rst = VL_RAND_RESET_I(1);
    vlSelf->error = VL_RAND_RESET_I(1);
    vlSelf->done = VL_RAND_RESET_I(1);
    vlSelf->sda_i = VL_RAND_RESET_I(1);
    vlSelf->sda_o = VL_RAND_RESET_I(1);
    vlSelf->scl_i = VL_RAND_RESET_I(1);
    vlSelf->scl_o = VL_RAND_RESET_I(1);
    vlSelf->__PVT__pc = VL_RAND_RESET_I(16);
    vlSelf->__PVT__time_counter = VL_RAND_RESET_I(32);
    for (int __Vi0 = 0; __Vi0 < 8; ++__Vi0) {
        vlSelf->__PVT__call_stack[__Vi0] = VL_RAND_RESET_I(16);
    }
    vlSelf->__PVT__call_stack_pos = VL_RAND_RESET_I(3);
    for (int __Vi0 = 0; __Vi0 < 4; ++__Vi0) {
        vlSelf->__PVT__args[__Vi0] = VL_RAND_RESET_I(32);
    }
    vlSelf->__PVT__i2c_op_ready = VL_RAND_RESET_I(1);
    vlSelf->__PVT__i2c_op_valid = VL_RAND_RESET_I(1);
    vlSelf->__PVT__i2c_op_mode = VL_RAND_RESET_I(2);
    vlSelf->__PVT__i2c_op_wdata = VL_RAND_RESET_I(8);
    vlSelf->__PVT__i2c_op_rack = VL_RAND_RESET_I(1);
    vlSelf->__PVT__i2c_rdata = VL_RAND_RESET_I(8);
    vlSelf->__PVT__i2c_rdata_valid = VL_RAND_RESET_I(1);
    vlSelf->__PVT__i2c_wack = VL_RAND_RESET_I(1);
    vlSelf->__PVT__i2c_wack_valid = VL_RAND_RESET_I(1);
    vlSelf->__PVT__i2c_i0__DOT__bit_op_ready = VL_RAND_RESET_I(1);
    vlSelf->__PVT__i2c_i0__DOT__bit_op_valid = VL_RAND_RESET_I(1);
    vlSelf->__PVT__i2c_i0__DOT__bit_op_mode = VL_RAND_RESET_I(2);
    vlSelf->__PVT__i2c_i0__DOT__bit_op_wdata = VL_RAND_RESET_I(1);
    vlSelf->__PVT__i2c_i0__DOT__bit_rdata = VL_RAND_RESET_I(1);
    vlSelf->__PVT__i2c_i0__DOT__bit_rdata_valid = VL_RAND_RESET_I(1);
    vlSelf->__PVT__i2c_i0__DOT__wdata = VL_RAND_RESET_I(8);
    vlSelf->__PVT__i2c_i0__DOT__rack = VL_RAND_RESET_I(1);
    vlSelf->__PVT__i2c_i0__DOT__byte_counter = VL_RAND_RESET_I(3);
    vlSelf->__PVT__i2c_i0__DOT__state = 0;
    vlSelf->__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state = 0;
    vlSelf->__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter = VL_RAND_RESET_I(9);
    vlSelf->__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__wdata = VL_RAND_RESET_I(1);
    vlSelf->__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i = VL_RAND_RESET_I(2);
    vlSelf->__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick = VL_RAND_RESET_I(1);
}
