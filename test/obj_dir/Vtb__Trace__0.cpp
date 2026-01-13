// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals
#include "verilated_vcd_c.h"
#include "Vtb__Syms.h"


void Vtb___024root__trace_chg_0_sub_0(Vtb___024root* vlSelf, VerilatedVcd::Buffer* bufp);

void Vtb___024root__trace_chg_0(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root__trace_chg_0\n"); );
    // Init
    Vtb___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb___024root*>(voidSelf);
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    if (VL_UNLIKELY(!vlSymsp->__Vm_activity)) return;
    // Body
    Vtb___024root__trace_chg_0_sub_0((&vlSymsp->TOP), bufp);
}

void Vtb___024root__trace_chg_0_sub_0(Vtb___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root__trace_chg_0_sub_0\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode + 1);
    // Body
    if (VL_UNLIKELY(vlSelfRef.__Vm_traceActivity[1U])) {
        bufp->chgBit(oldp+0,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.sda_o));
        bufp->chgBit(oldp+1,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.scl_o));
        bufp->chgBit(oldp+2,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.error));
        bufp->chgBit(oldp+3,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.done));
        bufp->chgIData(oldp+4,(vlSelfRef.tb__DOT__addr),32);
        bufp->chgIData(oldp+5,(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h),32);
        bufp->chgIData(oldp+6,(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v),32);
        bufp->chgIData(oldp+7,(((0x3fU < (0x7fU & (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h)))
                                 ? 0xff0000U : 0xff00U)),24);
        bufp->chgCData(oldp+8,(((0x3fU < (0x7fU & (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h)))
                                 ? 0xffU : 0U)),8);
        bufp->chgCData(oldp+9,(((0x3fU < (0x7fU & (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h)))
                                 ? 0U : 0xffU)),8);
        bufp->chgBit(oldp+10,(((0x7d8U <= (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h)) 
                               & (0x804U > (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h)))));
        bufp->chgBit(oldp+11,(((0x43cU <= (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v)) 
                               & (0x441U > (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v)))));
        bufp->chgBit(oldp+12,(((0x780U > (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h)) 
                               & (0x438U > (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v)))));
        bufp->chgSData(oldp+13,(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h),12);
        bufp->chgSData(oldp+14,(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v),11);
        bufp->chgSData(oldp+15,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__pc),16);
        bufp->chgIData(oldp+16,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__time_counter),32);
        bufp->chgSData(oldp+17,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[0]),16);
        bufp->chgSData(oldp+18,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[1]),16);
        bufp->chgSData(oldp+19,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[2]),16);
        bufp->chgSData(oldp+20,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[3]),16);
        bufp->chgSData(oldp+21,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[4]),16);
        bufp->chgSData(oldp+22,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[5]),16);
        bufp->chgSData(oldp+23,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[6]),16);
        bufp->chgSData(oldp+24,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[7]),16);
        bufp->chgCData(oldp+25,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack_pos),3);
        bufp->chgIData(oldp+26,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__args[0]),32);
        bufp->chgIData(oldp+27,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__args[1]),32);
        bufp->chgIData(oldp+28,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__args[2]),32);
        bufp->chgIData(oldp+29,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__args[3]),32);
        bufp->chgBit(oldp+30,((0U == vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__state)));
        bufp->chgBit(oldp+31,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_op_valid));
        bufp->chgCData(oldp+32,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_op_mode),2);
        bufp->chgCData(oldp+33,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_op_wdata),8);
        bufp->chgBit(oldp+34,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_op_rack));
        bufp->chgCData(oldp+35,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_rdata),8);
        bufp->chgBit(oldp+36,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_rdata_valid));
        bufp->chgBit(oldp+37,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_wack));
        bufp->chgBit(oldp+38,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_wack_valid));
        bufp->chgBit(oldp+39,((0U == vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state)));
        bufp->chgBit(oldp+40,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__bit_op_valid));
        bufp->chgCData(oldp+41,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__bit_op_mode),2);
        bufp->chgBit(oldp+42,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__bit_op_wdata));
        bufp->chgBit(oldp+43,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__bit_rdata));
        bufp->chgBit(oldp+44,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__bit_rdata_valid));
        bufp->chgCData(oldp+45,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__wdata),8);
        bufp->chgBit(oldp+46,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__rack));
        bufp->chgCData(oldp+47,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__byte_counter),3);
        bufp->chgIData(oldp+48,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__state),32);
        bufp->chgIData(oldp+49,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state),32);
        bufp->chgSData(oldp+50,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter),9);
        bufp->chgBit(oldp+51,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__wdata));
        bufp->chgCData(oldp+52,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i),2);
        bufp->chgBit(oldp+53,((0U == (IData)(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter))));
    }
    bufp->chgBit(oldp+54,(vlSelfRef.tb__DOT__clk));
    bufp->chgBit(oldp+55,(vlSelfRef.tb__DOT__rst));
}

void Vtb___024root__trace_cleanup(void* voidSelf, VerilatedVcd* /*unused*/) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root__trace_cleanup\n"); );
    // Init
    Vtb___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb___024root*>(voidSelf);
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    // Body
    vlSymsp->__Vm_activity = false;
    vlSymsp->TOP.__Vm_traceActivity[0U] = 0U;
    vlSymsp->TOP.__Vm_traceActivity[1U] = 0U;
}
