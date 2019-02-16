#include "peripheral.h"

#define INVALID_SPI_BASE 0x31000000

int main()
{
    uint32_t read_data;

    mmio_write(INVALID_SPI_BASE + SPI_TX_ADDR, 0x55);
    read_data = mmio_read(INVALID_SPI_BASE + SPI_STATUS_ADDR);

    return 0;
}

