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

struct spi_command {
    uint8_t bytes[34];
} __attribute__((aligned(16)))__;

void read_id(Commands cmd, size_t size) {
    spi_command spi_cmd, spi_result;

    spi_cmd.bytes[0] = static_cast<uint8_t>(cmd);

    SPI::start_transaction( &spi_cmd, 1, 0, &spi_result, size );
    SPI::wait_transaction();
    SPI::postprocess_buffer( &spi_result, size );
    for( int i=0; i<size; ++i ) {
        uart_send(" ");
        print_hex(spi_result.bytes[i]);
    }
    uart_send("\n");
}

void init_flash() {
    // Dummy first op. Because "hardware does not have bugs, just idiocyncracies" was too long.
    spi_command spi_cmd, spi_result;
    
    SPI::interface_rescue();

    set_config( SPI::Config::Single );
    spi_cmd.bytes[0] = static_cast<uint8_t>(Commands::WriteEnable);
    SPI::start_transaction( &spi_cmd, 1, 0, nullptr, 0 );
    SPI::wait_transaction();

    spi_cmd.bytes[0] = static_cast<uint8_t>(Commands::WriteEnhancedVolatileConfRegister);
    spi_cmd.bytes[1] = 0xff; // Quad I/O, single rate, default driver strength
    SPI::start_transaction( &spi_cmd, 2, 0, nullptr, 0 );
    SPI::wait_transaction();

    uart_send("ReadId returned:");
    read_id(Commands::ReadId, 20);

    uart_send("ReadId returned:");
    read_id(Commands::ReadId, 34);

    spi_cmd.bytes[0] = static_cast<uint8_t>(Commands::WriteEnable);
    SPI::start_transaction( &spi_cmd, 1, 0, nullptr, 0 );
    SPI::wait_transaction();

    spi_cmd.bytes[0] = static_cast<uint8_t>(Commands::WriteEnhancedVolatileConfRegister);
    spi_cmd.bytes[1] = 0x3f; // Quad I/O, single rate, default driver strength
    SPI::start_transaction( &spi_cmd, 2, 0, nullptr, 0 );
    SPI::wait_transaction();

    set_config( SPI::Config::Quad );

    uart_send("Quad ReadId returned:");
    read_id(Commands::MultiplIOReadId, 20);

    uart_send("Quad ReadId returned:");
    read_id(Commands::MultiplIOReadId, 34);

}

} // namespace SPI_FLASH
