#pragma once

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

} // namespace SPI_FLASH
