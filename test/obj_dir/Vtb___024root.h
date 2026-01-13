// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtb.h for the primary calling header

#ifndef VERILATED_VTB___024ROOT_H_
#define VERILATED_VTB___024ROOT_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"
class Vtb_ac701_adv7811_setup__Cz1;
class Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg;


class Vtb__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vtb___024root final : public VerilatedModule {
  public:
    // CELLS
    Vtb_ac701_adv7811_setup__Cz1* __PVT__tb__DOT__ac701_adv7811_setup_i0;
    Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg* ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg;

    // DESIGN SPECIFIC STATE
    CData/*0:0*/ tb__DOT__clk;
    CData/*0:0*/ tb__DOT__rst;
    CData/*0:0*/ __VstlFirstIteration;
    CData/*0:0*/ __Vtrigprevexpr___TOP__tb__DOT__clk__0;
    CData/*0:0*/ __VactContinue;
    SData/*11:0*/ tb__DOT__display_driver_i0__DOT__line_counter_h;
    SData/*10:0*/ tb__DOT__display_driver_i0__DOT__line_counter_v;
    IData/*31:0*/ tb__DOT__addr;
    IData/*31:0*/ __VactIterCount;
    VlUnpacked<CData/*0:0*/, 2> __Vm_traceActivity;
    VlDelayScheduler __VdlySched;
    VlForkSync __Vfork_1__sync;
    VlTriggerVec<1> __VstlTriggered;
    VlTriggerVec<2> __VactTriggered;
    VlTriggerVec<2> __VnbaTriggered;

    // INTERNAL VARIABLES
    Vtb__Syms* const vlSymsp;

    // CONSTRUCTORS
    Vtb___024root(Vtb__Syms* symsp, const char* v__name);
    ~Vtb___024root();
    VL_UNCOPYABLE(Vtb___024root);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


#endif  // guard
