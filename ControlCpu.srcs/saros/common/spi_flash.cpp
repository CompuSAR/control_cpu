#include "spi_flash.h"

#include "spi.h"
#include "uart.h"
#include "format.h"

namespace SPI_FLASH {

enum class Commands : uint8_t {
    // Software reset operations
    ResetEnable                                 = 0x66,
    ResetMemory                                 = 0x99,

    // Read ID operations
    ReadId                                      = 0x9e,
    ReadId2                                     = 0x9f,
    MultiplIOReadId                             = 0xaf,
    ReadSerialFlashDiscoveryParameters          = 0x5a,

    // Read memory operations
    Read                                        = 0x03,
    FastRead                                    = 0x0b,
    DualOutputFastRead                          = 0x3b,
    DualIOFastRead                              = 0xbb,
    QuadOutputFastRead                          = 0x6b,
    QuadIOFastRead                              = 0xeb,
    DtrFastRead                                 = 0x0d,
    DtrDualOutputFastRead                       = 0x3d,
    DtrDualIOFastRead                           = 0xbd,
    DtrQuadOutputFastRead                       = 0x6d,
    DtrQuadIOFastRead                           = 0xed,
    QuadIOWordRead                              = 0xe7,

    // Write operations
    WriteEnable                                 = 0x06,
    WriteDisable                                = 0x04,

    // Read register operations
    ReadStatusRegister                          = 0x05,
    ReadFlagStatusRegister                      = 0x70,
    ReadNVConfRegister                          = 0xb5,
    ReadVolatileConfRegister                    = 0x85,
    ReadEnhancedVolatileConfRegister            = 0x65,
    ReadGeneralPurposeReadRegister              = 0x96,

    // Write register operations
    WriteStatusRegister                         = 0x01,
    WriteNVconfRegister                         = 0xb1,
    WriteVolatileConfRegister                   = 0x81,
    WriteEnhancedVolatileConfRegister           = 0x61,

    // Clear flag status register
    ClearFlagStatusRegister                     = 0x50,

    // Program operations
    PageProgram                                 = 0x02,
    DualInputFastProgram                        = 0xa2,
    ExtendedDualInputFastProgram                = 0xd2,
    QuadInputFastProgram                        = 0x32,
    ExtendedQuadInputFastProgram                = 0x38,

    // Erase operations
    SubsectorErase32K                           = 0x52,
    SubsectorErase4K                            = 0x20,
    SectorErase64K                              = 0xd8,
    BulkErase                                   = 0xc7,
    BulkErase2                                  = 0x60,

    // Quad protocol operations
    EnterQuadIOMode                             = 0x35,
    ResetQuadIOMode                             = 0xf5,

    // Advanced function interface operations
    InterfaceActivation                         = 0x9b,
    CyclicRedundancyCheck                       = 0x9b,
    CyclicRedundancyCheck2                      = 0x27,
};


void init_flash() {
    // Dummy first op. Because "hardware does not have bugs, just idiocyncracies" was too long.
    struct spi_command {
        union { uint8_t bytes[4]; uint32_t word; } buffer[8];
    } __attribute__((aligned(16)))__;

    spi_command spi_cmd, spi_result;
    
    SPI::interface_rescue();

    spi_cmd.buffer[0].bytes[0] = static_cast<uint8_t>(SPI_FLASH::Commands::ReadId);
    //rsfd.buffer[0] = static_cast<uint8_t>(SPI_FLASH::Commands::PageProgram);

    set_config( SPI::Config::Single );
    SPI::start_transaction( &spi_cmd, 1, 0, &spi_result, 16 );
    SPI::wait_transaction();
    SPI::postprocess_buffer( &spi_result, 16 );

    uart_send("Dummy ReadId op returned:");
    for( int i=0; i<4; ++i ) {
        for( int j=0; j<4; ++j ) {
            uart_send(" ");
            print_hex(spi_result.buffer[i].bytes[j]);
        }
    }
    uart_send("\n");

    SPI::start_transaction( &spi_cmd, 1, 0, &spi_result, 16 );
    SPI::wait_transaction();
    SPI::postprocess_buffer( &spi_result, 16 );

    uart_send("Second ReadId returned:");
    for( int i=0; i<4; ++i ) {
        for( int j=0; j<4; ++j ) {
            uart_send(" ");
            print_hex(spi_result.buffer[i].bytes[j]);
        }
    }
    uart_send("\n");

    spi_cmd.buffer[0].bytes[0] = static_cast<uint8_t>(Commands::WriteEnable);
    SPI::start_transaction( &spi_cmd, 1, 0, nullptr, 0 );
    SPI::wait_transaction();

    spi_cmd.buffer[0].bytes[0] = static_cast<uint8_t>(Commands::WriteEnhancedVolatileConfRegister);
    spi_cmd.buffer[0].bytes[1] = 0x3f; // Quad I/O, single rate, default driver strength
    SPI::start_transaction( &spi_cmd, 2, 0, nullptr, 0 );
    SPI::wait_transaction();

    set_config( SPI::Config::Quad );
    spi_cmd.buffer[0].bytes[0] = static_cast<uint8_t>(SPI_FLASH::Commands::MultiplIOReadId);
    SPI::start_transaction( &spi_cmd, 1, 0, &spi_result, 16 );
    SPI::wait_transaction();
    SPI::postprocess_buffer( &spi_result, 16 );

    uart_send("Quad ReadId returned:");
    for( int i=0; i<4; ++i ) {
        for( int j=0; j<4; ++j ) {
            uart_send(" ");
            print_hex(spi_result.buffer[i].bytes[j]);
        }
    }
    uart_send("\n");


#if 0
    //set_config( Config::Quad );
    while(true) {
        rsfd_result.buffer[0]=0x62801b11;
        rsfd_result.buffer[1]=0x7c495b0a;
        rsfd_result.buffer[2]=0xc764059d;
        rsfd_result.buffer[3]=0x779121ed;
        rsfd_result.buffer[4]=0x99fdd077;
        start_transaction( &rsfd, 4, 0, &rsfd_result, 17/*sizeof(spi_command::buffer)*/ );
        wait_transaction();
        sleep_ns(20000000);
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
        postprocess_buffer( &rsfd_result, 17 );
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
        rsfd.buffer[0] += 256;
    }

    uart_send("RSFD command results\n");
    for( int i=0; i<20; ++i ) {
        print_hex(rsfd_result.buffer[i]);
        uart_send(" ");
    }
#endif
}

} // namespace SPI_FLASH
