#include "ddr.h"
#include "format.h"
#include "irq.h"
#include "spi.h"
#include "spi_flash.h"
#include "uart.h"

extern "C" void bl1_start();

static constexpr unsigned int FIBONACCI_COEF = 0x9E3779B9;
static constexpr unsigned int RANDOM_WALK_COEF = 0x26fcb789;

static constexpr unsigned int MEMORY_SIZE=(256*1024*1024 - 32*1024)/4;
extern volatile unsigned int DDR_MEMORY[MEMORY_SIZE];

void bl1_start() {
    uart_send("\nInitializing memory\n");
    ddr_init();

    uart_send("Memory initialized. Initializing SPI flash\n");

    struct spi_command {
        uint32_t buffer[20];
    } __attribute__((aligned(16)))__;

    spi_command rsfd, rsfd_result;
    rsfd.buffer[0] = static_cast<uint8_t>(SPI_FLASH::Commands::ReadId);
    //rsfd.buffer[0] = static_cast<uint8_t>(SPI_FLASH::Commands::PageProgram);
    rsfd.buffer[1] = 0;
    rsfd.buffer[2] = 0;
    rsfd.buffer[3] = 0;

    //SPI::set_config( SPI::Config::Quad );
    SPI::set_config( SPI::Config::Single );
    while(true) {
        rsfd_result.buffer[0]=0x62801b11;
        rsfd_result.buffer[1]=0x7c495b0a;
        rsfd_result.buffer[2]=0xc764059d;
        rsfd_result.buffer[3]=0x779121ed;
        rsfd_result.buffer[4]=0x99fdd077;
        SPI::start_transaction( &rsfd, 1, 0, &rsfd_result, 3/*sizeof(spi_command::buffer)*/ );
        SPI::wait_transaction();
        print_hex(rsfd_result.buffer[0]);
        uart_send("\n");
        print_hex(rsfd_result.buffer[1]);
        uart_send("\n");
        print_hex(rsfd_result.buffer[2]);
        uart_send("\n");
        print_hex(rsfd_result.buffer[3]);
        uart_send("\n");
        print_hex(rsfd_result.buffer[4]);
        uart_send("\n->\n");
        SPI::postprocess_buffer( &rsfd_result, 3 );
        print_hex(rsfd_result.buffer[0]);
        uart_send("\n");
        print_hex(rsfd_result.buffer[1]);
        uart_send("\n");
        print_hex(rsfd_result.buffer[2]);
        uart_send("\n");
        print_hex(rsfd_result.buffer[3]);
        uart_send("\n");
        print_hex(rsfd_result.buffer[4]);
        uart_send("\n--\n\n");
        sleep_ns(1'000'000'000);
    }

    uart_send("RSFD command results\n");
    for( int i=0; i<20; ++i ) {
        print_hex(rsfd_result.buffer[i]);
        uart_send(" ");
    }
    /*
    SPI::set_config( SPI::Config::ESPI, 0 );
    SPI::start_transaction( &write_enhanced_register, 2, nullptr, 0 );
    SPI::wait_transaction();
    SPI::interface_rescue();
    SPI::set_config( SPI::Config::ESPI, 0 );
    SPI::start_transaction( &write_enhanced_register, 2, nullptr, 0 );
    */
    SPI::start_transaction( (const void *)0x80000000, 0, 33, nullptr, 0 );
#if 0
    uint32_t offset = 0;

    uint32_t total_failures = 0;
    uint32_t cycle = 0;
    while(true) {
        uint32_t num_failures = 0;

        for( unsigned int i=0; i<MEMORY_SIZE; ++i ) {
            if( i%(1024*1024/4)==0 ) {
                uart_send("W");
            }

            unsigned int j = i; //(i*RANDOM_WALK_COEF) % MEMORY_SIZE;
            unsigned int val = (j+offset)*FIBONACCI_COEF;
            DDR_MEMORY[ j ] = val;
            unsigned int readback = DDR_MEMORY[ j ];
            if( val!=readback ) {
                uart_send("\nVerify after read failed at ");
                print_hex(j*4);
                uart_send(": wrote ");
                print_hex(val);
                uart_send(", read back ");
                print_hex(readback);
                uart_send(", reread ");
                print_hex(DDR_MEMORY[ j ]);
                uart_send("\n");

                num_failures++;
            }
        }

        uart_send("\nFilled all memory. Beginning verify.\n");

        unsigned int num = offset*FIBONACCI_COEF;
        for( unsigned int i=0; i<MEMORY_SIZE; ++i ) {
            if( i%(1024*1024/4)==0 ) {
                uart_send("V");
            }

            unsigned int val=DDR_MEMORY[ i ];
            if( val != num ) {
                unsigned int cacheline[4];
                for( int j=0; j<4; ++j )
                    cacheline[j] = DDR_MEMORY[ (i&0xfffffffc) + j ];
                uart_send("\nVerification failed: Memory location ");
                print_hex(i*4);
                uart_send(" should have been ");
                print_hex(num);
                uart_send(". Instead it's ");
                print_hex(val);
                uart_send(". Whole cacheline: ");
                print_hex(cacheline[0]);
                for( int j=1; j<4; ++j ) {
                    uart_send(" ");
                    print_hex(cacheline[j]);
                }
                uart_send(". Reread returns ");
                val = DDR_MEMORY[ (i+1024*1024) % MEMORY_SIZE ]; // Clear cache
                print_hex(DDR_MEMORY[i]);
                uart_send("\n");

                num_failures++;
            }

            num+=FIBONACCI_COEF;
        }

        total_failures += num_failures;

        uart_send("\nVerification cycle ");
        print_hex(++cycle);
        uart_send(" complete with ");
        print_hex(num_failures);
        uart_send(" new failures and ");
        print_hex(total_failures);
        uart_send(" total failures\n");

        offset += 0x54d52cb9;
    }
#endif

    halt();

    uart_send("Post halt code reached");
}
