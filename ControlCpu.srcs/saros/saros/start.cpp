#include "uart.h"
#include "irq.h"
#include "format.h"

#include "csr.h"

extern unsigned char HEAP_START[];

void int_handler() __attribute__ ((interrupt ("machine")));

extern uint32_t zero();

extern "C"
int _start() {
    uart_send("Second stage!\n");

    CSR::write_csr(CSR::mtvec, reinterpret_cast<uint32_t>(int_handler));
    CSR::write_csr(CSR::mie, (1<<12) - 1);
    uart_send("Interrupt vector installed\n");

    uint32_t csr;
    asm volatile("csrr %0, mcycle" : "=r"(csr));
    print_hex( csr );
    uart_send("\n");
    asm volatile("csrr %0, mcycle" : "=r"(csr));
    print_hex( csr );
    uart_send("\n");

    halt();

    return 0;
}

void int_handler()
{
    uart_send("Interrupt caught\nCause: ");
    print_hex(CSR::read_csr(CSR::mcause));
    uart_send("\nIP: ");
    print_hex(CSR::read_csr(CSR::mip));
    uart_send("\nPC: ");
    print_hex(CSR::read_csr(CSR::mepc));
    uart_send("\nBad addr: ");
    print_hex(CSR::read_csr(CSR::mtval));
    uart_send("\n");

    halt();
}
