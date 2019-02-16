#include "peripheral.h"

int main()
{
    uint32_t ctrl;
    uint32_t tx;
    uint32_t status;
    uint32_t rx;

    ctrl   = mmio_read(SPI_BASE_ADDR + SPI_CTRL_ADDR);
    tx     = mmio_read(SPI_BASE_ADDR + SPI_TX_ADDR);
    status = mmio_read(SPI_BASE_ADDR + SPI_STATUS_ADDR);
    rx     = mmio_read(SPI_BASE_ADDR + SPI_RX_ADDR);

    return 0;
}

