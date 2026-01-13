// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vtb.h for the primary calling header

#include "Vtb__pch.h"
#include "Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg.h"

Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6::~Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6() {
    VL_DEBUG_IF(VL_DBG_MSGF("+  Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6::~\n"); );
}

std::string VL_TO_STRING(const VlClassRef<Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6>& obj) {
    VL_DEBUG_IF(VL_DBG_MSGF("+  Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6::VL_TO_STRING\n"); );
    // Body
    return (obj ? obj->to_string() : "null");
}

std::string Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6::to_string() const {
    VL_DEBUG_IF(VL_DBG_MSGF("+  Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6::to_string\n"); );
    // Body
    return ("'{"s + to_string_middle() + "}");
}

std::string Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6::to_string_middle() const {
    VL_DEBUG_IF(VL_DBG_MSGF("+  Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6::to_string_middle\n"); );
    // Body
    std::string out;
    out += "out:" + VL_TO_STRING(__PVT__out);
    return out;
}
