#include "uart.h"
#include "format.h"
#include "ddr.h"
#include "irq.h"

extern "C" void bl1_start();

static constexpr unsigned int FIBONACCI_COEF = 0x9E3779B9;
static constexpr unsigned int RANDOM_WALK_COEF = 0x26fcb789;

static constexpr unsigned int MEMORY_SIZE=32*1024*1024/4;
extern volatile unsigned int DDR_MEMORY[MEMORY_SIZE];

void bl1_start() {
    uart_send("Initializing memory\n");
    ddr_init();

    uart_send("Memory initialized\n");

    for( unsigned int i=0; i<MEMORY_SIZE; ++i ) {
        if( i%(1024*1024/4)==0 ) {
            uart_send("Filled ");
            print_hex(i/(1024*1024/4));
            uart_send(" MB\n");
        }

        unsigned int j = i; //(i*RANDOM_WALK_COEF) % MEMORY_SIZE;
        DDR_MEMORY[ j ] = j*FIBONACCI_COEF;
    }

    uart_send("Filled all memory. Beginning verify.\n");

    unsigned int num = 0;
    for( unsigned int i=0; i<MEMORY_SIZE; ++i ) {
        if( i%(1024*1024/4)==0 ) {
            uart_send("Verified ");
            print_hex(i/(1024*1024/4));
            uart_send(" MB\n");
        }

        unsigned int val=DDR_MEMORY[ i ];
        if( val != num ) {
            uart_send("Verification failed: Memory location ");
            print_hex(i*4);
            uart_send(" should have been ");
            print_hex(num);
            uart_send(". Instead it's ");
            print_hex(val);
            uart_send("\n");
        }

        num+=FIBONACCI_COEF;
    }

    uart_send("Verification complete\n");

    halt();

    uart_send("Post halt code reached");
}
