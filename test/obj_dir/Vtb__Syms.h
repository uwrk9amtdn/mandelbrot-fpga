// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Symbol table internal header
//
// Internal details; most calling programs do not need this header,
// unless using verilator public meta comments.

#ifndef VERILATED_VTB__SYMS_H_
#define VERILATED_VTB__SYMS_H_  // guard

#include "verilated.h"
#include "verilated_vcd_c.h"

// INCLUDE MODEL CLASS

#include "Vtb.h"

// INCLUDE MODULE CLASSES
#include "Vtb___024root.h"
#include "Vtb_ac701_adv7811_setup__Cz1.h"
#include "Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg.h"

// SYMS CLASS (contains all model state)
class alignas(VL_CACHE_LINE_BYTES)Vtb__Syms final : public VerilatedSyms {
  public:
    // INTERNAL STATE
    Vtb* const __Vm_modelp;
    bool __Vm_dumping = false;  // Dumping is active
    VerilatedMutex __Vm_dumperMutex;  // Protect __Vm_dumperp
    VerilatedVcdC* __Vm_dumperp VL_GUARDED_BY(__Vm_dumperMutex) = nullptr;  /// Trace class for $dump*
    bool __Vm_activity = false;  ///< Used by trace routines to determine change occurred
    uint32_t __Vm_baseCode = 0;  ///< Used by trace routines when tracing multiple models
    VlDeleter __Vm_deleter;
    bool __Vm_didInit = false;

    // MODULE INSTANCE STATE
    Vtb___024root                  TOP;
    Vtb_ac701_adv7811_setup__Cz1   TOP__tb__DOT__ac701_adv7811_setup_i0;
    Vtb_ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg TOP__ac701_adv7811_setup__Cz1__03a__03a__VDynScope_6__Vclpkg;

    // CONSTRUCTORS
    Vtb__Syms(VerilatedContext* contextp, const char* namep, Vtb* modelp);
    ~Vtb__Syms();

    // METHODS
    const char* name() { return TOP.name(); }
    void _traceDump();
    void _traceDumpOpen();
    void _traceDumpClose();
};

#endif  // guard
