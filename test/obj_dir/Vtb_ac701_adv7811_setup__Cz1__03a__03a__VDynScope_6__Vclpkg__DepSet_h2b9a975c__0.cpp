// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb.h for the primary calling header

#include "Vtb__pch.h"
#include "Vtb__Syms.h"
#include "Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg.h"

Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6::Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6(Vtb__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+  Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6::new\n"); );
    // Init
    _ctor_var_reset(vlSymsp);
}

void Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6::_ctor_var_reset(Vtb__Syms* __restrict vlSymsp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+  Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6::_ctor_var_reset\n"); );
    // Body
    (void)vlSymsp;  // Prevent unused variable warning
    __PVT__out = VL_RAND_RESET_I(8);
}
