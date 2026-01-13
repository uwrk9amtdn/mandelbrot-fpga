// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb.h for the primary calling header

#include "Vtb__pch.h"
#include "Vtb___024root.h"

VlCoroutine Vtb___024root___eval_initial__TOP__Vtiming__0(Vtb___024root* vlSelf);

void Vtb___024root___eval_initial(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_initial\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vtb___024root___eval_initial__TOP__Vtiming__0(vlSelf);
    vlSelfRef.__Vtrigprevexpr___TOP__tb__DOT__clk__0 
        = vlSelfRef.tb__DOT__clk;
}

VL_INLINE_OPT VlCoroutine Vtb___024root___eval_initial__TOP__Vtiming__0____Vfork_1__2(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_initial__TOP__Vtiming__0____Vfork_1__2\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    co_await vlSelfRef.__VdlySched.delay(0x1312d00ULL, 
                                         nullptr, "../tb.sv", 
                                         91);
    VL_FINISH_MT("../tb.sv", 91, "");
    vlSelfRef.__Vfork_1__sync.done("../tb.sv", 91);
}

VL_INLINE_OPT VlCoroutine Vtb___024root___eval_initial__TOP__Vtiming__0____Vfork_1__1(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_initial__TOP__Vtiming__0____Vfork_1__1\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    co_await vlSelfRef.__VdlySched.delay(0x14ULL, nullptr, 
                                         "../tb.sv", 
                                         90);
    vlSelfRef.tb__DOT__rst = 0U;
    vlSelfRef.__Vfork_1__sync.done("../tb.sv", 90);
}

VL_INLINE_OPT VlCoroutine Vtb___024root___eval_initial__TOP__Vtiming__0____Vfork_1__0(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_initial__TOP__Vtiming__0____Vfork_1__0\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    while (1U) {
        co_await vlSelfRef.__VdlySched.delay(5ULL, 
                                             nullptr, 
                                             "../tb.sv", 
                                             89);
        vlSelfRef.tb__DOT__clk = (1U & (~ (IData)(vlSelfRef.tb__DOT__clk)));
    }
    vlSelfRef.__Vfork_1__sync.done("../tb.sv", 89);
}

void Vtb___024root___eval_act(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_act\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
}

VL_INLINE_OPT void Vtb___024root___nba_sequent__TOP__0(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___nba_sequent__TOP__0\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Init
    SData/*11:0*/ __Vdly__tb__DOT__display_driver_i0__DOT__line_counter_h;
    __Vdly__tb__DOT__display_driver_i0__DOT__line_counter_h = 0;
    SData/*10:0*/ __Vdly__tb__DOT__display_driver_i0__DOT__line_counter_v;
    __Vdly__tb__DOT__display_driver_i0__DOT__line_counter_v = 0;
    // Body
    __Vdly__tb__DOT__display_driver_i0__DOT__line_counter_h 
        = vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h;
    __Vdly__tb__DOT__display_driver_i0__DOT__line_counter_v 
        = vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v;
    if ((0x897U == (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h))) {
        __Vdly__tb__DOT__display_driver_i0__DOT__line_counter_h = 0U;
        __Vdly__tb__DOT__display_driver_i0__DOT__line_counter_v 
            = ((0x464U == (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v))
                ? 0U : (0x7ffU & ((IData)(1U) + (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v))));
    } else {
        __Vdly__tb__DOT__display_driver_i0__DOT__line_counter_h 
            = (0xfffU & ((IData)(1U) + (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h)));
    }
    vlSelfRef.tb__DOT__addr = (((0x77fU == (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h)) 
                                & (0x437U == (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v)))
                                ? 0U : ((IData)(1U) 
                                        + vlSelfRef.tb__DOT__addr));
    vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h 
        = __Vdly__tb__DOT__display_driver_i0__DOT__line_counter_h;
    vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v 
        = __Vdly__tb__DOT__display_driver_i0__DOT__line_counter_v;
}

void Vtb___024root___timing_resume(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___timing_resume\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((2ULL & vlSelfRef.__VactTriggered.word(0U))) {
        vlSelfRef.__VdlySched.resume();
    }
}

void Vtb___024root___eval_triggers__act(Vtb___024root* vlSelf);

bool Vtb___024root___eval_phase__act(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_phase__act\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Init
    VlTriggerVec<2> __VpreTriggered;
    CData/*0:0*/ __VactExecute;
    // Body
    Vtb___024root___eval_triggers__act(vlSelf);
    __VactExecute = vlSelfRef.__VactTriggered.any();
    if (__VactExecute) {
        __VpreTriggered.andNot(vlSelfRef.__VactTriggered, vlSelfRef.__VnbaTriggered);
        vlSelfRef.__VnbaTriggered.thisOr(vlSelfRef.__VactTriggered);
        Vtb___024root___timing_resume(vlSelf);
        Vtb___024root___eval_act(vlSelf);
    }
    return (__VactExecute);
}

void Vtb___024root___eval_nba(Vtb___024root* vlSelf);

bool Vtb___024root___eval_phase__nba(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_phase__nba\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Init
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = vlSelfRef.__VnbaTriggered.any();
    if (__VnbaExecute) {
        Vtb___024root___eval_nba(vlSelf);
        vlSelfRef.__VnbaTriggered.clear();
    }
    return (__VnbaExecute);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb___024root___dump_triggers__nba(Vtb___024root* vlSelf);
#endif  // VL_DEBUG
#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb___024root___dump_triggers__act(Vtb___024root* vlSelf);
#endif  // VL_DEBUG

void Vtb___024root___eval(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Init
    IData/*31:0*/ __VnbaIterCount;
    CData/*0:0*/ __VnbaContinue;
    // Body
    __VnbaIterCount = 0U;
    __VnbaContinue = 1U;
    while (__VnbaContinue) {
        if (VL_UNLIKELY((0x64U < __VnbaIterCount))) {
#ifdef VL_DEBUG
            Vtb___024root___dump_triggers__nba(vlSelf);
#endif
            VL_FATAL_MT("../tb.sv", 3, "", "NBA region did not converge.");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        __VnbaContinue = 0U;
        vlSelfRef.__VactIterCount = 0U;
        vlSelfRef.__VactContinue = 1U;
        while (vlSelfRef.__VactContinue) {
            if (VL_UNLIKELY((0x64U < vlSelfRef.__VactIterCount))) {
#ifdef VL_DEBUG
                Vtb___024root___dump_triggers__act(vlSelf);
#endif
                VL_FATAL_MT("../tb.sv", 3, "", "Active region did not converge.");
            }
            vlSelfRef.__VactIterCount = ((IData)(1U) 
                                         + vlSelfRef.__VactIterCount);
            vlSelfRef.__VactContinue = 0U;
            if (Vtb___024root___eval_phase__act(vlSelf)) {
                vlSelfRef.__VactContinue = 1U;
            }
        }
        if (Vtb___024root___eval_phase__nba(vlSelf)) {
            __VnbaContinue = 1U;
        }
    }
}

#ifdef VL_DEBUG
void Vtb___024root___eval_debug_assertions(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_debug_assertions\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
}
#endif  // VL_DEBUG
