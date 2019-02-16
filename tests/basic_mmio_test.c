//==============================================================================
//========================================================
// File        : basic_mmio_test.c
//========================================================
// Company     : Kyros-Semi Pvt Ltd.
// Project     : Pinaka SoC Verification
// Description :Basic test to check peripheral connecivity
// 
// Author      : Ganesh K S(ganesh.ks@kyros-semi.com)
// Created On  : 29-May-2026
//
// Copyright (c) 2026 Kyros-Semi Pvt Ltd
// Confidential Proprietary Information
//==============================================================================


#include "peripheral.h"

int main()

{
    uint32_t write_data, read_data;
    uint32_t tx_data = 0xA5;
    uint32_t rx_data;
    uint32_t handshake_from_sv_to_c=0;
    //uint32_t handshake_from_sv_to_c=0;
    
    //Wait for handshake
    while(handshake_from_sv_to_c==0)
    {
          handshake_from_sv_to_c = wait_for_handshake_from_sv();
    }


            
    //I2C write
    mmio_write(I2C_BASE_ADDR+I2C_SLAVE_ADDR,0x50 );//writing slave addr
    mmio_write(I2C_BASE_ADDR+I2C_DATIN_ADDR, 0xA);//writing ino datain
    mmio_write(I2C_BASE_ADDR+I2C_CTRL_ADDR, 0x1);//writing into control reg
    read_data=mmio_read(I2C_BASE_ADDR+I2C_STATUS_ADDR);//reading status register
    //printf("Read data from I2C status register is %x\n",read_data);
    //mmio_write(I2C_BASE_ADDR+I2C_STATUS_ADDR, read_data);
    
    
    //SPI write
    mmio_write(SPI_BASE_ADDR+SPI_TX_ADDR, 0x87651055);//loading into TX
    mmio_write(SPI_BASE_ADDR+SPI_CTRL_ADDR, 0x3);//writing into control reg
    read_data=mmio_read(SPI_BASE_ADDR+SPI_STATUS_ADDR);
   // printf("Read data from SPI status register is %x\n",read_data);
   //
    //--------- UART initialization----------

    mmio_write(UART_BASE_ADDR + UART_LCR_ADDR, UART_LCR_DLAB);

    mmio_write(UART_BASE_ADDR + UART_DLL_ADDR, 0x1B);  // DLL = 27
    mmio_write(UART_BASE_ADDR + UART_DLH_ADDR, 0x00);  // DLH = 0

    mmio_write(UART_BASE_ADDR + UART_LCR_ADDR, UART_LCR_8BIT);

    mmio_write(UART_BASE_ADDR + UART_FCR_ADDR, 0x00);

    // ------------UART TX test------------------
    //wait for handshake from sv
    
    //Send handshake to SV
    send_handshake_to_sv();

    do {
        read_data = mmio_read(UART_BASE_ADDR + UART_LSR_ADDR);
    } while ((read_data & UART_LSR_THRE) == 0);

    mmio_write(UART_BASE_ADDR + UART_THR_ADDR, tx_data);

    do {
        read_data = mmio_read(UART_BASE_ADDR + UART_LSR_ADDR);
    } while ((read_data & UART_LSR_TEMT) == 0);

    //----------- UART RX test------------------------
    do {
        read_data = mmio_read(UART_BASE_ADDR + UART_LSR_ADDR);
    } while ((read_data & UART_LSR_DR) == 0);

    rx_data = mmio_read(UART_BASE_ADDR + UART_RBR_ADDR);

    read_data = mmio_read(UART_BASE_ADDR + UART_LSR_ADDR);

    

}


