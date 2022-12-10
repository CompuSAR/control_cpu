#include <gpio.h>

static volatile uint32_t *gpio_base = reinterpret_cast<uint32_t *>(0xc002'0000);

uint32_t read_gpio(size_t gpio_num) {
    return gpio_base[gpio_num];
}
