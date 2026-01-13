// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Tracing implementation internals
#include "verilated_vcd_c.h"
#include "Vtb__Syms.h"


VL_ATTR_COLD void Vtb___024root__trace_init_sub__TOP__tb__DOT__ac701_adv7811_setup_i0__0(Vtb___024root* vlSelf, VerilatedVcd* tracep);

VL_ATTR_COLD void Vtb___024root__trace_init_sub__TOP__0(Vtb___024root* vlSelf, VerilatedVcd* tracep) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root__trace_init_sub__TOP__0\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Init
    const int c = vlSymsp->__Vm_baseCode;
    // Body
    tracep->pushPrefix("tb", VerilatedTracePrefixType::SCOPE_MODULE);
    tracep->declBit(c+1,0,"sda",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+2,0,"scl",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+55,0,"clk",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+56,0,"rst",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+1,0,"sda_i",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+1,0,"sda_o",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+2,0,"scl_i",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+2,0,"scl_o",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+3,0,"error",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+4,0,"done",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->pushPrefix("ac701_adv7811_setup_i0", VerilatedTracePrefixType::SCOPE_MODULE);
    Vtb___024root__trace_init_sub__TOP__tb__DOT__ac701_adv7811_setup_i0__0(vlSelf, tracep);
    tracep->popPrefix();
    tracep->declBus(c+5,0,"addr",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+6,0,"x",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+7,0,"y",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+8,0,"rgb",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 23,0);
    tracep->declBus(c+9,0,"r",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 7,0);
    tracep->declBus(c+10,0,"g",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 7,0);
    tracep->declBus(c+57,0,"b",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 7,0);
    tracep->declBit(c+11,0,"hsync",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+12,0,"vsync",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+13,0,"de",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->pushPrefix("display_driver_i0", VerilatedTracePrefixType::SCOPE_MODULE);
    tracep->declBus(c+58,0,"active_pixels_h",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+59,0,"front_porch_h",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+60,0,"sync_width_h",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+61,0,"back_porch_h",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+62,0,"sync_polarity_h",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+63,0,"active_pixels_v",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+64,0,"front_porch_v",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+65,0,"sync_width_v",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+66,0,"back_porch_v",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+62,0,"sync_polarity_v",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBit(c+55,0,"clk",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBus(c+5,0,"addr",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+6,0,"x",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+7,0,"y",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+8,0,"rgb",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 23,0);
    tracep->declBus(c+9,0,"r",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 7,0);
    tracep->declBus(c+10,0,"g",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 7,0);
    tracep->declBus(c+57,0,"b",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 7,0);
    tracep->declBit(c+11,0,"hsync",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+12,0,"vsync",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+13,0,"de",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBus(c+67,0,"total_lines_h",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+68,0,"total_lines_v",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+69,0,"sync_start_h",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+70,0,"sync_start_v",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+71,0,"sync_end_h",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+72,0,"sync_end_v",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+14,0,"line_counter_h",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1, 11,0);
    tracep->declBus(c+15,0,"line_counter_v",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1, 10,0);
    tracep->popPrefix();
    tracep->popPrefix();
}

VL_ATTR_COLD void Vtb___024root__trace_init_sub__TOP__tb__DOT__ac701_adv7811_setup_i0__0(Vtb___024root* vlSelf, VerilatedVcd* tracep) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root__trace_init_sub__TOP__tb__DOT__ac701_adv7811_setup_i0__0\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Init
    const int c = vlSymsp->__Vm_baseCode;
    // Body
    tracep->declDouble(c+73,0,"CLK_FREQ",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::DOUBLE, false,-1);
    tracep->declDouble(c+75,0,"SCL_FREQ",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::DOUBLE, false,-1);
    tracep->declBit(c+55,0,"clk",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+56,0,"rst",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+3,0,"error",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+4,0,"done",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+1,0,"sda_i",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+1,0,"sda_o",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+2,0,"scl_i",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+2,0,"scl_o",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBus(c+16,0,"pc",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1, 15,0);
    tracep->declBus(c+17,0,"time_counter",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->pushPrefix("call_stack", VerilatedTracePrefixType::ARRAY_UNPACKED);
    for (int i = 0; i < 8; ++i) {
        tracep->declBus(c+18+i*1,0,"",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, true,(i+0), 15,0);
    }
    tracep->popPrefix();
    tracep->declBus(c+26,0,"call_stack_pos",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1, 2,0);
    tracep->pushPrefix("args", VerilatedTracePrefixType::ARRAY_UNPACKED);
    for (int i = 0; i < 4; ++i) {
        tracep->declBus(c+27+i*1,0,"",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, true,(i+0), 31,0);
    }
    tracep->popPrefix();
    tracep->declBit(c+31,0,"i2c_op_ready",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+32,0,"i2c_op_valid",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBus(c+33,0,"i2c_op_mode",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1, 1,0);
    tracep->declBus(c+34,0,"i2c_op_wdata",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1, 7,0);
    tracep->declBit(c+35,0,"i2c_op_rack",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBus(c+36,0,"i2c_rdata",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 7,0);
    tracep->declBit(c+37,0,"i2c_rdata_valid",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+38,0,"i2c_wack",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+39,0,"i2c_wack_valid",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBus(c+77,0,"ADV7811_I2C_ADDR",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 6,0);
    tracep->declBus(c+78,0,"PCA9548_I2C_ADDR",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 6,0);
    tracep->declBus(c+79,0,"SLEEP_DURATION",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+80,0,"SETUP_BUS_SWITCH",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+81,0,"SETUP_ADV7811",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+82,0,"WRITE_REG",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+83,0,"SLEEP",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+84,0,"I2C_ERROR",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->pushPrefix("i2c_i0", VerilatedTracePrefixType::SCOPE_MODULE);
    tracep->declDouble(c+73,0,"CLK_FREQ",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::DOUBLE, false,-1);
    tracep->declDouble(c+75,0,"SCL_FREQ",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::DOUBLE, false,-1);
    tracep->declBit(c+55,0,"clk",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+56,0,"rst",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+31,0,"op_ready",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+32,0,"op_valid",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBus(c+33,0,"op_mode",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 1,0);
    tracep->declBus(c+34,0,"op_wdata",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 7,0);
    tracep->declBit(c+35,0,"op_rack",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBus(c+36,0,"rdata",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 7,0);
    tracep->declBit(c+37,0,"rdata_valid",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+38,0,"wack",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+39,0,"wack_valid",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+1,0,"sda_i",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+1,0,"sda_o",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+2,0,"scl_i",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+2,0,"scl_o",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+40,0,"bit_op_ready",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+41,0,"bit_op_valid",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBus(c+42,0,"bit_op_mode",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1, 1,0);
    tracep->declBit(c+43,0,"bit_op_wdata",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+44,0,"bit_rdata",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+45,0,"bit_rdata_valid",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBus(c+46,0,"wdata",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1, 7,0);
    tracep->declBit(c+47,0,"rack",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBus(c+48,0,"byte_counter",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1, 2,0);
    tracep->declBus(c+49,0,"state",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::INT, false,-1, 31,0);
    tracep->pushPrefix("i2c_bit_ctrl_i0", VerilatedTracePrefixType::SCOPE_MODULE);
    tracep->declDouble(c+73,0,"CLK_FREQ",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::DOUBLE, false,-1);
    tracep->declDouble(c+75,0,"SCL_FREQ",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::DOUBLE, false,-1);
    tracep->declBit(c+55,0,"clk",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+56,0,"rst",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+40,0,"op_ready",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+41,0,"op_valid",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBus(c+42,0,"op_mode",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1, 1,0);
    tracep->declBit(c+43,0,"op_wdata",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+44,0,"rdata",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+45,0,"rdata_valid",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+1,0,"sda_i",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+1,0,"sda_o",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+2,0,"scl_i",-1, VerilatedTraceSigDirection::INPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBit(c+2,0,"scl_o",-1, VerilatedTraceSigDirection::OUTPUT, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBus(c+85,0,"TICK_COUNT",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::PARAMETER, VerilatedTraceSigType::LOGIC, false,-1, 31,0);
    tracep->declBus(c+50,0,"state",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::INT, false,-1, 31,0);
    tracep->declBus(c+51,0,"tick_counter",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1, 8,0);
    tracep->declBit(c+52,0,"wdata",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->declBus(c+53,0,"i",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::VAR, VerilatedTraceSigType::LOGIC, false,-1, 1,0);
    tracep->declBit(c+54,0,"tick",-1, VerilatedTraceSigDirection::NONE, VerilatedTraceSigKind::WIRE, VerilatedTraceSigType::LOGIC, false,-1);
    tracep->popPrefix();
    tracep->popPrefix();
}

VL_ATTR_COLD void Vtb___024root__trace_init_top(Vtb___024root* vlSelf, VerilatedVcd* tracep) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root__trace_init_top\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    Vtb___024root__trace_init_sub__TOP__0(vlSelf, tracep);
}

VL_ATTR_COLD void Vtb___024root__trace_const_0(void* voidSelf, VerilatedVcd::Buffer* bufp);
VL_ATTR_COLD void Vtb___024root__trace_full_0(void* voidSelf, VerilatedVcd::Buffer* bufp);
void Vtb___024root__trace_chg_0(void* voidSelf, VerilatedVcd::Buffer* bufp);
void Vtb___024root__trace_cleanup(void* voidSelf, VerilatedVcd* /*unused*/);

VL_ATTR_COLD void Vtb___024root__trace_register(Vtb___024root* vlSelf, VerilatedVcd* tracep) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root__trace_register\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Body
    tracep->addConstCb(&Vtb___024root__trace_const_0, 0U, vlSelf);
    tracep->addFullCb(&Vtb___024root__trace_full_0, 0U, vlSelf);
    tracep->addChgCb(&Vtb___024root__trace_chg_0, 0U, vlSelf);
    tracep->addCleanupCb(&Vtb___024root__trace_cleanup, vlSelf);
}

VL_ATTR_COLD void Vtb___024root__trace_const_0_sub_0(Vtb___024root* vlSelf, VerilatedVcd::Buffer* bufp);

VL_ATTR_COLD void Vtb___024root__trace_const_0(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root__trace_const_0\n"); );
    // Init
    Vtb___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb___024root*>(voidSelf);
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    // Body
    Vtb___024root__trace_const_0_sub_0((&vlSymsp->TOP), bufp);
}

VL_ATTR_COLD void Vtb___024root__trace_const_0_sub_0(Vtb___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root__trace_const_0_sub_0\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode);
    // Body
    bufp->fullCData(oldp+57,(0U),8);
    bufp->fullIData(oldp+58,(0x780U),32);
    bufp->fullIData(oldp+59,(0x58U),32);
    bufp->fullIData(oldp+60,(0x2cU),32);
    bufp->fullIData(oldp+61,(0x94U),32);
    bufp->fullIData(oldp+62,(1U),32);
    bufp->fullIData(oldp+63,(0x438U),32);
    bufp->fullIData(oldp+64,(4U),32);
    bufp->fullIData(oldp+65,(5U),32);
    bufp->fullIData(oldp+66,(0x24U),32);
    bufp->fullIData(oldp+67,(0x898U),32);
    bufp->fullIData(oldp+68,(0x465U),32);
    bufp->fullIData(oldp+69,(0x7d8U),32);
    bufp->fullIData(oldp+70,(0x43cU),32);
    bufp->fullIData(oldp+71,(0x804U),32);
    bufp->fullIData(oldp+72,(0x441U),32);
    bufp->fullDouble(oldp+73,(2.00000000000000000e+08));
    bufp->fullDouble(oldp+75,(1.00000000000000000e+05));
    bufp->fullCData(oldp+77,(0x39U),7);
    bufp->fullCData(oldp+78,(0x74U),7);
    bufp->fullIData(oldp+79,(0x61a80U),32);
    bufp->fullIData(oldp+80,(0xaU),32);
    bufp->fullIData(oldp+81,(0x14U),32);
    bufp->fullIData(oldp+82,(0x28U),32);
    bufp->fullIData(oldp+83,(0x32U),32);
    bufp->fullIData(oldp+84,(0x3cU),32);
    bufp->fullIData(oldp+85,(0x1f4U),32);
}

VL_ATTR_COLD void Vtb___024root__trace_full_0_sub_0(Vtb___024root* vlSelf, VerilatedVcd::Buffer* bufp);

VL_ATTR_COLD void Vtb___024root__trace_full_0(void* voidSelf, VerilatedVcd::Buffer* bufp) {
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root__trace_full_0\n"); );
    // Init
    Vtb___024root* const __restrict vlSelf VL_ATTR_UNUSED = static_cast<Vtb___024root*>(voidSelf);
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    // Body
    Vtb___024root__trace_full_0_sub_0((&vlSymsp->TOP), bufp);
}

VL_ATTR_COLD void Vtb___024root__trace_full_0_sub_0(Vtb___024root* vlSelf, VerilatedVcd::Buffer* bufp) {
    (void)vlSelf;  // Prevent unused variable warning
    Vtb__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vtb___024root__trace_full_0_sub_0\n"); );
    auto &vlSelfRef = std::ref(*vlSelf).get();
    // Init
    uint32_t* const oldp VL_ATTR_UNUSED = bufp->oldp(vlSymsp->__Vm_baseCode);
    // Body
    bufp->fullBit(oldp+1,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.sda_o));
    bufp->fullBit(oldp+2,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.scl_o));
    bufp->fullBit(oldp+3,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.error));
    bufp->fullBit(oldp+4,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.done));
    bufp->fullIData(oldp+5,(vlSelfRef.tb__DOT__addr),32);
    bufp->fullIData(oldp+6,(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h),32);
    bufp->fullIData(oldp+7,(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v),32);
    bufp->fullIData(oldp+8,(((0x3fU < (0x7fU & (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h)))
                              ? 0xff0000U : 0xff00U)),24);
    bufp->fullCData(oldp+9,(((0x3fU < (0x7fU & (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h)))
                              ? 0xffU : 0U)),8);
    bufp->fullCData(oldp+10,(((0x3fU < (0x7fU & (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h)))
                               ? 0U : 0xffU)),8);
    bufp->fullBit(oldp+11,(((0x7d8U <= (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h)) 
                            & (0x804U > (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h)))));
    bufp->fullBit(oldp+12,(((0x43cU <= (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v)) 
                            & (0x441U > (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v)))));
    bufp->fullBit(oldp+13,(((0x780U > (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h)) 
                            & (0x438U > (IData)(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v)))));
    bufp->fullSData(oldp+14,(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_h),12);
    bufp->fullSData(oldp+15,(vlSelfRef.tb__DOT__display_driver_i0__DOT__line_counter_v),11);
    bufp->fullSData(oldp+16,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__pc),16);
    bufp->fullIData(oldp+17,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__time_counter),32);
    bufp->fullSData(oldp+18,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[0]),16);
    bufp->fullSData(oldp+19,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[1]),16);
    bufp->fullSData(oldp+20,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[2]),16);
    bufp->fullSData(oldp+21,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[3]),16);
    bufp->fullSData(oldp+22,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[4]),16);
    bufp->fullSData(oldp+23,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[5]),16);
    bufp->fullSData(oldp+24,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[6]),16);
    bufp->fullSData(oldp+25,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack[7]),16);
    bufp->fullCData(oldp+26,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__call_stack_pos),3);
    bufp->fullIData(oldp+27,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__args[0]),32);
    bufp->fullIData(oldp+28,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__args[1]),32);
    bufp->fullIData(oldp+29,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__args[2]),32);
    bufp->fullIData(oldp+30,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__args[3]),32);
    bufp->fullBit(oldp+31,((0U == vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__state)));
    bufp->fullBit(oldp+32,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_op_valid));
    bufp->fullCData(oldp+33,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_op_mode),2);
    bufp->fullCData(oldp+34,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_op_wdata),8);
    bufp->fullBit(oldp+35,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_op_rack));
    bufp->fullCData(oldp+36,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_rdata),8);
    bufp->fullBit(oldp+37,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_rdata_valid));
    bufp->fullBit(oldp+38,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_wack));
    bufp->fullBit(oldp+39,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_wack_valid));
    bufp->fullBit(oldp+40,((0U == vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state)));
    bufp->fullBit(oldp+41,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__bit_op_valid));
    bufp->fullCData(oldp+42,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__bit_op_mode),2);
    bufp->fullBit(oldp+43,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__bit_op_wdata));
    bufp->fullBit(oldp+44,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__bit_rdata));
    bufp->fullBit(oldp+45,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__bit_rdata_valid));
    bufp->fullCData(oldp+46,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__wdata),8);
    bufp->fullBit(oldp+47,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__rack));
    bufp->fullCData(oldp+48,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__byte_counter),3);
    bufp->fullIData(oldp+49,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__state),32);
    bufp->fullIData(oldp+50,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__state),32);
    bufp->fullSData(oldp+51,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter),9);
    bufp->fullBit(oldp+52,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__wdata));
    bufp->fullCData(oldp+53,(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__i),2);
    bufp->fullBit(oldp+54,((0U == (IData)(vlSymsp->TOP__tb__DOT__ac701_adv7811_setup_i0.__PVT__i2c_i0__DOT__i2c_bit_ctrl_i0__DOT__tick_counter))));
    bufp->fullBit(oldp+55,(vlSelfRef.tb__DOT__clk));
    bufp->fullBit(oldp+56,(vlSelfRef.tb__DOT__rst));
}
