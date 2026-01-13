// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb.h for the primary calling header

#include "Vtb__pch.h"
#include "Vtb__Syms.h"
#include "Vtb___024root.h"

VL_ATTR_COLD void Vtb___024root___eval_static__TOP(Vtb___024root* vlSelf);
VL_ATTR_COLD void Vtb___024root____Vm_traceActivitySetAll(Vtb___024root* vlSelf);
VL_ATTR_COLD void Vtb_ac701_adv7811_setup__Cz1___eval_static__TOP__tb__DOT__ac701_adv7811_setup_i0(Vtb_ac701_adv7811_setup__Cz1* vlSelf);

VL_ATTR_COLD void Vtb___024root___eval_static(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_static\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vtb___024root___eval_static__TOP(vlSelf);
    Vtb___024root____Vm_traceActivitySetAll(vlSelf);
    Vtb_ac701_adv7811_setup__Cz1___eval_static__TOP__tb__DOT__ac701_adv7811_setup_i0((&vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0));
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb___024root___dump_triggers__stl(Vtb___024root* vlSelf);
#endif  // VL_DEBUG

VL_ATTR_COLD void Vtb___024root___eval_triggers__stl(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_triggers__stl\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VstlTriggered.set(0U, (IData)(vlSelfRef.__VstlFirstIteration));
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb___024root___dump_triggers__stl(vlSelf);
    }
#endif
}

void Vtb___024root___nba_sequent__TOP__1(Vtb___024root* vlSelf);
VL_ATTR_COLD void Vtb_ac701_adv7811_setup__Cz1___stl_sequent__TOP__tb__DOT__ac701_adv7811_setup_i0__0(Vtb_ac701_adv7811_setup__Cz1* vlSelf);

VL_ATTR_COLD void Vtb___024root___eval_stl(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_stl\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VstlTriggered.word(0U))) {
        Vtb___024root___nba_sequent__TOP__1(vlSelf);
        Vtb_ac701_adv7811_setup__Cz1___stl_sequent__TOP__tb__DOT__ac701_adv7811_setup_i0__0((&vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0));
    }
}
