// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb.h for the primary calling header

#include "Vtb__pch.h"
#include "Vtb__Syms.h"
#include "Vtb___024root.h"

VlCoroutine Vtb___024root___eval_initial__TOP__Vtiming__0____Vfork_1__0(Vtb___024root* vlSelf);
VlCoroutine Vtb___024root___eval_initial__TOP__Vtiming__0____Vfork_1__1(Vtb___024root* vlSelf);
VlCoroutine Vtb___024root___eval_initial__TOP__Vtiming__0____Vfork_1__2(Vtb___024root* vlSelf);

VL_INLINE_OPT VlCoroutine Vtb___024root___eval_initial__TOP__Vtiming__0(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_initial__TOP__Vtiming__0\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSymsp->_vm_contextp__->dumpfile(std::string{"dump.vcd"});
    vlSymsp->_traceDumpOpen();
    vlSelfRef.tb__DOT__clk = 0U;
    vlSelfRef.tb__DOT__rst = 1U;
    vlSelfRef.__Vfork_1__sync.init(4U, nullptr);
    Vtb___024root___eval_initial__TOP__Vtiming__0____Vfork_1__0(vlSelf);
    Vtb___024root___eval_initial__TOP__Vtiming__0____Vfork_1__1(vlSelf);
    Vtb___024root___eval_initial__TOP__Vtiming__0____Vfork_1__2(vlSelf);
    vlSelfRef.__Vfork_1__sync.done("../tb.sv", 92);
    co_await vlSelfRef.__Vfork_1__sync.join(nullptr, 
                                            "../tb.sv", 
                                            88);
    co_return;
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vtb___024root___dump_triggers__act(Vtb___024root* vlSelf);
#endif  // VL_DEBUG

void Vtb___024root___eval_triggers__act(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_triggers__act\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSelfRef.__VactTriggered.set(0U, ((IData)(vlSelfRef.tb__DOT__clk) 
                                       & (~ (IData)(vlSelfRef.__Vtrigprevexpr___TOP__tb__DOT__clk__0))));
    vlSelfRef.__VactTriggered.set(1U, vlSelfRef.__VdlySched.awaitingCurrentTime());
    vlSelfRef.__Vtrigprevexpr___TOP__tb__DOT__clk__0 
        = vlSelfRef.tb__DOT__clk;
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vtb___024root___dump_triggers__act(vlSelf);
    }
#endif
}

void Vtb___024root___nba_sequent__TOP__0(Vtb___024root* vlSelf);
void Vtb_ac701_adv7811_setup__Cz1___nba_sequent__TOP__tb__DOT__ac701_adv7811_setup_i0__0(Vtb_ac701_adv7811_setup__Cz1* vlSelf);
void Vtb___024root___nba_sequent__TOP__1(Vtb___024root* vlSelf);

void Vtb___024root___eval_nba(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___eval_nba\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    if ((1ULL & vlSelfRef.__VnbaTriggered.word(0U))) {
        Vtb___024root___nba_sequent__TOP__0(vlSelf);
        vlSelfRef.__Vm_traceActivity[1U] = 1U;
        Vtb_ac701_adv7811_setup__Cz1___nba_sequent__TOP__tb__DOT__ac701_adv7811_setup_i0__0((&vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0));
        Vtb___024root___nba_sequent__TOP__1(vlSelf);
    }
}

VL_INLINE_OPT void Vtb___024root___nba_sequent__TOP__1(Vtb___024root* vlSelf) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root___nba_sequent__TOP__1\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.sda_i 
        = vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.sda_o;
}
