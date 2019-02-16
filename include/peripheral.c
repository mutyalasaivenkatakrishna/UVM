//==============================================================================
//========================================================
// File        : peripheral.c
//========================================================
// Company     : Kyros-Semi Pvt Ltd.
// Project     : Pinaka SoC Verification
// Description : API functions to write/read into/from peripherals
//
// Author      : Ganesh K S(ganesh.ks@kyros-semi.com)
// Created On  : 29-May-2026
//
// Copyright (c) 2026 Kyros-Semi Pvt Ltd
// Confidential Proprietary Information
//============================================================================== 

#include "peripheral.h"

//========================================================
//  COMMON MMIO FUNCTIONS
//========================================================
//uint32_t hdsk_from_sv_to_c=0;
void mmio_write(uint32_t addr, uint32_t data)
{
    *((volatile uint32_t *)addr) = data;
}

uint32_t mmio_read(uint32_t addr)
{
    return *((volatile uint32_t *)addr);
}

void send_handshake_to_sv()
{
    *((volatile uint32_t *)HANDSHAKE_ADDR)=HANDSHAKE_CODE;
}

uint32_t wait_for_handshake_from_sv()
{
    if(*((volatile uint32_t *)HANDSHAKE_ADDR)==0x7EA)
        return 1;
    else 
        return 0;
}

