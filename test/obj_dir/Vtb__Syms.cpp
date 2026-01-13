// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table implementation internals

#include "Vtb__pch.h"
#include "Vtb.h"
#include "Vtb___024root.h"
#include "Vtb_ac701_adv7811_setup__Cz1.h"
#include "Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg.h"

// FUNCTIONS
Vtb__Syms::~Vtb__Syms()
{
#ifdef VM_TRACE
    if (__Vm_dumping) _traceDumpClose();
#endif  // VM_TRACE
}

void Vtb__Syms::_traceDump() {
    const VerilatedLockGuard lock(__Vm_dumperMutex);
    __Vm_dumperp->dump(VL_TIME_Q());
}

void Vtb__Syms::_traceDumpOpen() {
    const VerilatedLockGuard lock(__Vm_dumperMutex);
    if (VL_UNLIKELY(!__Vm_dumperp)) {
        __Vm_dumperp = new VerilatedVcdC();
        __Vm_modelp->trace(__Vm_dumperp, 0, 0);
        std::string dumpfile = _vm_contextp__->dumpfileCheck();
        __Vm_dumperp->open(dumpfile.c_str());
        __Vm_dumping = true;
    }
}

void Vtb__Syms::_traceDumpClose() {
    const VerilatedLockGuard lock(__Vm_dumperMutex);
    __Vm_dumping = false;
    VL_DO_CLEAR(delete __Vm_dumperp, __Vm_dumperp = nullptr);
}

Vtb__Syms::Vtb__Syms(VerilatedContext* contextp, const char* namep, Vtb* modelp)
    : VerilatedSyms{contextp}
    // Setup internal state of the Syms class
    , __Vm_modelp{modelp}
    // Setup module instances
    , TOP{this, namep}
    , TOP__tb__DOT__ac701_adv7811_setup_i0{this, Verilated::catName(namep, "tb.ac701_adv7811_setup_i0")}
    , TOP__ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg{this, Verilated::catName(namep, "ac701_adv7811_setup__Cz1::__VDynScope_6__Vclpkg")}
{
        // Check resources
        Verilated::stackCheck(226);
    // Configure time unit / time precision
    _vm_contextp__->timeunit(-9);
    _vm_contextp__->timeprecision(-9);
    // Setup each module's pointers to their submodules
    TOP.__PVT__tb__DOT__ac701_adv7811_setup_i0 = &TOP__tb__DOT__ac701_adv7811_setup_i0;
    TOP.ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg = &TOP__ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg;
    // Setup each module's pointer back to symbol table (for public functions)
    TOP.__Vconfigure(true);
    TOP__tb__DOT__ac701_adv7811_setup_i0.__Vconfigure(true);
    TOP__ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg.__Vconfigure(true);
}
