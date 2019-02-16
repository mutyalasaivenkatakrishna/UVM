#include "peripheral.h"

#define SPI_STATUS_BUSY 0x1
#define NUM_TRANSFERS   100

uint32_t rand32_local(uint32_t seed)
{
    return (seed * 1103515245u) + 12345u;
}

uint32_t mode_cfg_only(uint32_t mode)
{
    if (mode == 0) return 0x00; // CPHA=0 CPOL=0
    if (mode == 1) return 0x02; // CPHA=1 CPOL=0
    if (mode == 2) return 0x04; // CPHA=0 CPOL=1
    return 0x06;                // CPHA=1 CPOL=1
}

uint32_t mode_start(uint32_t mode)
{
    if (mode == 0) return 0x01; // START + mode0
    if (mode == 1) return 0x03; // START + mode1
    if (mode == 2) return 0x05; // START + mode2
    return 0x07;                // START + mode3
}

void delay_small()
{
    volatile int d;
    for (d = 0; d < 30; d++);
}

int main()
{
    uint32_t seed = 0x12345678;
    uint32_t tx_data;
    uint32_t rx_data;
    uint32_t status;
    uint32_t mode;

    for (int i = 0; i < NUM_TRANSFERS; i++)
    {
        seed = rand32_local(seed);
        tx_data = seed;

        seed = rand32_local(seed);
        mode = (seed >> 16) & 0x3;   // use upper bits, not seed[1:0]

        // Program CPOL/CPHA first, START=0
        mmio_write(SPI_BASE_ADDR + SPI_CTRL_ADDR, mode_cfg_only(mode));
        delay_small();

        // Write TX data
        mmio_write(SPI_BASE_ADDR + SPI_TX_ADDR, tx_data);
        delay_small();

        // Start transfer with same mode
        mmio_write(SPI_BASE_ADDR + SPI_CTRL_ADDR, mode_start(mode));

        do {
            status = mmio_read(SPI_BASE_ADDR + SPI_STATUS_ADDR);
        } while (status & SPI_STATUS_BUSY);

        rx_data = mmio_read(SPI_BASE_ADDR + SPI_RX_ADDR);
        delay_small();
    }

    return 0;
}

