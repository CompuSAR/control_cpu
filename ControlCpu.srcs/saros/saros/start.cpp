#include "uart.h"
#include "irq.h"
#include "csr.h"
#include "format.h"

extern unsigned char HEAP_START[];

extern "C"
int _start() {
    irq_init();

    uart_send("Second stage!\n");
    uart_send("Vendor Id: ");
    print_hex( csr_read(CSR::mvendorid) );
    uart_send(" Arch Id: ");
    print_hex( csr_read(CSR::marchid) );
    uart_send(" Implementation Id: ");
    print_hex( csr_read(CSR::mimpid) );
    uart_send(" Hardware thread Id: ");
    print_hex( csr_read(CSR::mhartid) );
    uart_send("\n");

    halt();
}
