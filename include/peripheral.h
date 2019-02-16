//==============================================================================
//========================================================
// File        : peripheral.h
//========================================================
// Company     : Kyros-Semi Pvt Ltd.
// Project     : Pinaka SoC Verification
// Description : Header file
//
// Author      : Ganesh K S(ganesh.ks@kyros-semi.com)
// Created On  : 29-May-2026
//
// Copyright (c) 2026 Kyros-Semi Pvt Ltd
// Confidential Proprietary Information
//==============================================================================

#include <stdint.h>
#include <stdio.h>
#ifndef PERIPHERAL_H
#define PERIPHERAL_H

//=======================================================
//   Defines
//======================================================
//Handshake defines
#define HANDSHAKE_ADDR 0x0001FFF8
#define HANDSHAKE_CODE 0xC0FFEE

//I2C addresses
#define I2C_BASE_ADDR     0x00084000
#define I2C_CTRL_ADDR     0x00
#define I2C_SLAVE_ADDR    0x04
#define I2C_DATIN_ADDR    0x08
#define I2C_STATUS_ADDR   0x0c
#define I2C_DATOUT_ADDR   0x10

//SPI addresses
#define SPI_BASE_ADDR     0x00085000
#define SPI_CTRL_ADDR     0x00
#define SPI_TX_ADDR       0x04
#define SPI_STATUS_ADDR   0x08
#define SPI_RX_ADDR       0x0c

//UART addresses
#define UART_BASE_ADDR     0x00083000
#define UART_RBR_ADDR      0x00   
#define UART_THR_ADDR      0x00  
#define UART_DLL_ADDR      0x00   
#define UART_DLH_ADDR      0x04   
#define UART_FCR_ADDR      0x08
#define UART_LCR_ADDR      0x0C
#define UART_LSR_ADDR      0x14

// LSR bits
#define UART_LSR_DR        (1 << 0)  
#define UART_LSR_THRE      (1 << 5)  
#define UART_LSR_TEMT      (1 << 6)  

// LCR bits
#define UART_LCR_DLAB      (1 << 7)
#define UART_LCR_8BIT      0x03
//========================================================
//  Common MMIO APIs
//========================================================
void mmio_write(uint32_t addr, uint32_t data);
uint32_t mmio_read(uint32_t addr);
void send_handshake_to_sv();
uint32_t wait_for_handshake_from_sv();

#endif

