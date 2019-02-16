#include "peripheral.h"

#define SPI_STATUS_BUSY 0x1

uint32_t rand32_local(uint32_t seed)
{
    return (seed * 1103515245u) + 12345u;
}

int main()
{
    uint32_t tx_data;
    uint32_t status;
    uint32_t rx_data;
    uint32_t seed_local;

    seed_local = 0x12345678;
    tx_data = rand32_local(seed_local);

    if (tx_data == 0)
        tx_data = 0xA5A55A5A;

    mmio_write(SPI_BASE_ADDR + SPI_TX_ADDR, tx_data);

    mmio_write(SPI_BASE_ADDR + SPI_CTRL_ADDR, 0x01);

    do {
        status = mmio_read(SPI_BASE_ADDR + SPI_STATUS_ADDR);
    } while(status & SPI_STATUS_BUSY);

    rx_data = mmio_read(SPI_BASE_ADDR + SPI_RX_ADDR);

    return 0;
}

