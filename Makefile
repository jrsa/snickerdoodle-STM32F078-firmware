# mostly copied from https://gitlab.com/jrsa/030

TARGET = sd_platform

DEBUG = 1

ROOT ?= .
TARGET_DIR ?= .

DEBUG = 1
OPT = -O0
BUILD_DIR = $(ROOT)/build/$(TARGET)/

TARGET_BIN = $(BUILD_DIR)/$(TARGET).bin

# debug probe configuration
BMP ?= /dev/ttyBmpGdb

# stm32 sdk paths
# CUBE ?= $(ROOT)/STM32CubeF0 # not using cube for now
CMSIS = Drivers/CMSIS
HAL = Drivers/STM32F0xx_HAL_Driver
USB_CORE = Middlewares/ST/STM32_USB_Device_Library/Core
USB_CDC = Middlewares/ST/STM32_USB_Device_Library/Class/CDC
USB_MSC = Middlewares/ST/STM32_USB_Device_Library/Class/MSC
ST_DIST = $(CMSIS)/Device/ST/STM32F0xx

# chip specific defines
# DEVICE = STM32F072VB
C_DEFS = -DSTM32F078xx -DUSE_HAL_DRIVER

LDSCRIPT = sd_platform.ld

C_SOURCES = Src/usb_device.c \
		 	Src/stm32f0xx_hal_msp.c \
			Src/usbd_desc.c \
			Src/usbd_conf.c \
			Src/main.c \
			Src/sd_platform.c \
			Src/sd_i2c.c \
			Src/sd_spi.c \
			Src/sd_spi_bridge.c \
			Src/sd_usbd_cdc_if.c \
			Src/sd_interrupt.c \
			Src/sd_buffer.c \
			Src/sd_led.c \
			Src/sd_led_pattern.c \
			Src/sd_uart.c \
			Src/sd_button.c \
			Src/sd_pwm.c \
			Src/sd_gpio.c \
			Src/sd_tim.c \
			Src/sd_adc.c \
			Src/sd_dac.c

C_SOURCES += $(ST_DIST)/Source/Templates/system_stm32f0xx.c 
C_SOURCES += \
	$(HAL)/Src/stm32f0xx_hal.c \
	$(HAL)/Src/stm32f0xx_hal_adc.c \
	$(HAL)/Src/stm32f0xx_hal_adc_ex.c \
	$(HAL)/Src/stm32f0xx_hal_cortex.c \
	$(HAL)/Src/stm32f0xx_hal_i2c.c \
	$(HAL)/Src/stm32f0xx_hal_i2c_ex.c \
	$(HAL)/Src/stm32f0xx_hal_pcd.c \
	$(HAL)/Src/stm32f0xx_hal_pcd_ex.c \
	$(HAL)/Src/stm32f0xx_hal_pwr.c \
	$(HAL)/Src/stm32f0xx_hal_rcc.c \
	$(HAL)/Src/stm32f0xx_hal_rcc_ex.c \
	$(HAL)/Src/stm32f0xx_hal_spi.c \
	$(HAL)/Src/stm32f0xx_hal_tim.c \
	$(HAL)/Src/stm32f0xx_hal_tim_ex.c \
	$(HAL)/Src/stm32f0xx_hal_uart.c \
	$(HAL)/Src/stm32f0xx_hal_gpio.c

C_SOURCES += \
	$(USB_CORE)/Src/usbd_core.c \
	$(USB_CORE)/Src/usbd_ioreq.c \
	$(USB_CORE)/Src/usbd_ctlreq.c \
	$(USB_CDC)/Src/usbd_cdc.c

ASM_SOURCES += $(ST_DIST)/Source/Templates/gcc/startup_stm32f078xx.s

# toolchain
BINPATH = /usr/bin
PREFIX = arm-none-eabi-
CC = $(BINPATH)/$(PREFIX)gcc
AS = $(BINPATH)/$(PREFIX)gcc -x assembler-with-cpp
CP = $(BINPATH)/$(PREFIX)objcopy
AR = $(BINPATH)/$(PREFIX)ar
SZ = $(BINPATH)/$(PREFIX)size
HEX = $(CP) -O ihex
BIN = $(CP) -O binary -S
DB = $(BINPATH)/$(PREFIX)gdb

CPU = -mcpu=cortex-m0

C_INCLUDES += -I$(ROOT)/Inc -I$(ST_DIST)/Include -I$(CMSIS)/Include -I$(HAL)/Inc -I$(HAL)/Inc/Legacy -I$(USB_CORE)/Inc -I$(USB_CDC)/Inc -I$(USB_MSC)/Inc

MCU = $(CPU) -mthumb $(FPU) $(FLOAT-ABI)
ASFLAGS = $(MCU) $(AS_DEFS) $(AS_INCLUDES) $(OPT) -Wall -fdata-sections -ffunction-sections
CFLAGS = $(MCU) $(C_DEFS) $(C_INCLUDES) $(OPT) -Wfatal-errors -Wall -fdata-sections -ffunction-sections -std=c99

ifeq ($(DEBUG), 1)
CFLAGS += -g3 -gdwarf-2
endif

CFLAGS += -MMD -MP -MF"$(@:%.o=%.d)" -MT"$(@:%.o=%.d)"


LIBS = -lc -lm -lnosys 
LDFLAGS = $(MCU) -specs=nano.specs -T$(LDSCRIPT) $(LIBS) -Wl,-Map=$(BUILD_DIR)/$(TARGET).map,--cref -Wl,--gc-sections

all: $(BUILD_DIR)/$(TARGET).elf $(BUILD_DIR)/$(TARGET).hex $(BUILD_DIR)/$(TARGET).bin

OBJECTS = $(addprefix $(BUILD_DIR)/,$(notdir $(C_SOURCES:.c=.o)))
vpath %.c $(sort $(dir $(C_SOURCES)))
OBJECTS += $(addprefix $(BUILD_DIR)/,$(notdir $(ASM_SOURCES:.s=.o)))
vpath %.s $(sort $(dir $(ASM_SOURCES))) 

$(BUILD_DIR)/%.o: %.c | $(BUILD_DIR) 
	$(CC) -c $(CFLAGS) -Wa,-a,-ad,-alms=$(BUILD_DIR)/$(notdir $(<:.c=.lst)) $< -o $@

$(BUILD_DIR)/%.o: %.s | $(BUILD_DIR)
	$(AS) -c $(CFLAGS) $< -o $@

$(BUILD_DIR)/$(TARGET).elf: $(OBJECTS)
	$(CC) $(OBJECTS) $(LDFLAGS) -o $@
	$(SZ) $@

$(BUILD_DIR)/%.hex: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	$(HEX) $< $@
	
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	$(BIN) $< $@	

$(BUILD_DIR):
	mkdir -p $@		

clean:
	-rm -fR $(BUILD_DIR)

# start gdb, connect to blackmagic probe, re-flash firmware
flash: $(BUILD_DIR)/$(TARGET).elf
	$(DB)   -iex "target extended-remote $(BMP)" \
		    -ex "monitor connect_rst enable" \
	        -ex "monitor swd_scan" \
			-ex "attach 1" \
			-ex "load" \
			$<

# start gdb, connect to blackmagic probe, DONT re-flash firmware (gdb output may not be valid if firmware is out of date)
dbg: $(BUILD_DIR)/$(TARGET).elf
	$(DB)   -iex "target extended-remote $(BMP)" \
		    -ex "monitor connect_rst enable" \
	        -ex "monitor swd_scan" \
			-ex "attach 1" \
			$<
