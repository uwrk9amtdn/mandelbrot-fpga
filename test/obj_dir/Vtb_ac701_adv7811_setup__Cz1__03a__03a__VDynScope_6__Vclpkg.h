// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design internal header
// See Vtb.h for the primary calling header

#ifndef VERILATED_VTB_AC701_ADV7811_SETUP__CZ1__03A__03A__VDYNSCOPE_6__VCLPKG_H_
#define VERILATED_VTB_AC701_ADV7811_SETUP__CZ1__03A__03A__VDYNSCOPE_6__VCLPKG_H_  // guard

#include "verilated.h"
#include "verilated_timing.h"


class Vtb__Syms;

class alignas(VL_CACHE_LINE_BYTES) Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg final : public VerilatedModule {
  public:

    // INTERNAL VARIABLES
    Vtb__Syms* const vlSymsp;

    // CONSTRUCTORS
    Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg(Vtb__Syms* symsp, const char* v__name);
    ~Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg();
    VL_UNCOPYABLE(Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg);

    // INTERNAL METHODS
    void __Vconfigure(bool first);
};


class Vtb__Syms;

class Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6 : public VlClass {
  public:

    // DESIGN SPECIFIC STATE
    CData/*7:0*/ __PVT__out;
  private:
    void _ctor_var_reset(Vtb__Syms* __restrict vlSymsp);
  public:
    Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6(Vtb__Syms* __restrict vlSymsp);
    std::string to_string() const;
    std::string to_string_middle() const;
    ~Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6();
};

std::string VL_TO_STRING(const VlClassRef<Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6>& obj);

#endif  // guard
