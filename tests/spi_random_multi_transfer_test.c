#include "peripheral.h"

#define SPI_STATUS_BUSY 0x1

int main()
{
    uint32_t status;
    uint32_t rx_data;

    // Mode0: START=1, CPHA=0, CPOL=0
    mmio_write(SPI_BASE_ADDR + SPI_TX_ADDR, 0x55);
    mmio_write(SPI_BASE_ADDR + SPI_CTRL_ADDR, 0x01);
    do {
        status = mmio_read(SPI_BASE_ADDR + SPI_STATUS_ADDR);
    } while (status & SPI_STATUS_BUSY);
    rx_data = mmio_read(SPI_BASE_ADDR + SPI_RX_ADDR);

    // Mode1: START=1, CPHA=1, CPOL=0
    mmio_write(SPI_BASE_ADDR + SPI_TX_ADDR, 0xA5);
    mmio_write(SPI_BASE_ADDR + SPI_CTRL_ADDR, 0x03);
    do {
        status = mmio_read(SPI_BASE_ADDR + SPI_STATUS_ADDR);
    } while (status & SPI_STATUS_BUSY);
    rx_data = mmio_read(SPI_BASE_ADDR + SPI_RX_ADDR);

    // Mode2: START=1, CPHA=0, CPOL=1
    mmio_write(SPI_BASE_ADDR + SPI_TX_ADDR, 0x5A);
    mmio_write(SPI_BASE_ADDR + SPI_CTRL_ADDR, 0x05);
    do {
        status = mmio_read(SPI_BASE_ADDR + SPI_STATUS_ADDR);
    } while (status & SPI_STATUS_BUSY);
    rx_data = mmio_read(SPI_BASE_ADDR + SPI_RX_ADDR);

    // Mode3: START=1, CPHA=1, CPOL=1
    mmio_write(SPI_BASE_ADDR + SPI_TX_ADDR, 0xFF);
    mmio_write(SPI_BASE_ADDR + SPI_CTRL_ADDR, 0x07);
    do {
        status = mmio_read(SPI_BASE_ADDR + SPI_STATUS_ADDR);
    } while (status & SPI_STATUS_BUSY);
    rx_data = mmio_read(SPI_BASE_ADDR + SPI_RX_ADDR);

    return 0;
}

