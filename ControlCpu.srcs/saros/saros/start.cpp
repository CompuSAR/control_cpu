#include "uart.h"
#include "irq.h"
#include "csr.h"
#include "format.h"

extern unsigned char HEAP_START[];

/*
extern "C"
void trap_handler() {
    uart_send("USER TRAP!!!!\ncause: ");
    print_hex( csr_read_write(CSR::mcause, 0) );
    uart_send(" pc: ");
    print_hex( csr_read(CSR::mepc) );
    uart_send(" mstatus: ");
    print_hex( csr_read(CSR::mstatus) );
    uart_send(" mie: ");
    print_hex( csr_read(CSR::mie) );
    uart_send(" mip: ");
    print_hex( csr_read(CSR::mip) );
    uart_send("\n");

    reset_timer_cycles();

    halt();
}
*/

extern "C"
int _start() {
    init_irq();

    uart_send("Second stage!\n");

    halt();
}
