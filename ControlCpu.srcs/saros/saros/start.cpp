#include "uart.h"
#include "irq.h"
#include "csr.h"
#include "format.h"

extern unsigned char HEAP_START[];

extern "C"
void trap_handler() {
    uart_send("USER TRAP!!!!\n");

    halt();
}

extern "C"
int _start() {
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


    uart_send("mstatus: ");
    print_hex( csr_read(CSR::mstatus) );
    uart_send(" mie: ");
    print_hex( csr_read(CSR::mie) );
    csr_write(CSR::mie, 0xffffffff);
    uart_send(" mie again: ");
    print_hex( csr_read(CSR::mie) );
    uart_send("\n");

    print_hex( csr_read_write(CSR::mie, 0) );
    uart_send(" ");
    print_hex( csr_read_write(CSR::mie, 0xffffffff) );
    uart_send(" ");
    print_hex( csr_read(CSR::mie) );
    uart_send("\n");

    auto trap = reinterpret_cast<uintptr_t>(trap_handler);
    uart_send("Trap handler: ");
    print_hex(trap);
    csr_write(CSR::mtvec, trap );
    uart_send(" mtvec: ");
    print_hex( csr_read(CSR::mtvec) );
    uart_send("\n");

    csr_write(CSR::mstatus, 0);
    uart_send("mstatus: ");
    print_hex( csr_read(CSR::mstatus) );
    uart_send("\n");

    halt();
}
