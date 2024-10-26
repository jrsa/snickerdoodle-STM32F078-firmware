# mostly copied from https://gitlab.com/jrsa/030

TARGET = hello

C_SOURCES := $(wildcard $(ROOT)/Src/*.c)

ROOT ?= .
TARGET_DIR ?= .

DEBUG = 1
OPT = -Og
BUILD_DIR = $(ROOT)/build/$(TARGET)/

TARGET_BIN = $(BUILD_DIR)/$(TARGET).bin

# stm32 sdk paths
CUBE ?= $(ROOT)/STM32CubeF0
CMSIS = $(CUBE)/Drivers/CMSIS
ST_DIST = $(CMSIS)/Device/ST/STM32F0xx

# chip specific defines
# DEVICE = STM32F072VB
C_DEFS = -DSTM32F072xB

LDSCRIPT = $(CUBE)/Projects/STM32F072RB-Nucleo/Templates_LL/SW4STM32/STM32F072RB-Discovery/STM32F072RBTx_FLASH.ld

C_SOURCES += $(ST_DIST)/Source/Templates/system_stm32f0xx.c 
ASM_SOURCES += $(ST_DIST)/Source/Templates/gcc/startup_stm32f072xb.s

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

C_INCLUDES += -I$(ROOT)/Inc -I$(ST_DIST)/Include -I$(CMSIS)/Include

MCU = $(CPU) -mthumb $(FPU) $(FLOAT-ABI)
ASFLAGS = $(MCU) $(AS_DEFS) $(AS_INCLUDES) $(OPT) -Wall -fdata-sections -ffunction-sections
CFLAGS = $(MCU) $(C_DEFS) $(C_INCLUDES) $(OPT) -Wall -fdata-sections -ffunction-sections -std=c99

ifeq ($(DEBUG), 1)
CFLAGS += -g -gdwarf-2
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
	@$(CC) -c $(CFLAGS) -Wa,-a,-ad,-alms=$(BUILD_DIR)/$(notdir $(<:.c=.lst)) $< -o $@
	@echo "[CC]\t $<"

$(BUILD_DIR)/%.o: %.s | $(BUILD_DIR)
	@$(AS) -c $(CFLAGS) $< -o $@
	@echo "[AS]\t $<"

$(BUILD_DIR)/$(TARGET).elf: $(OBJECTS)
	@$(CC) $(OBJECTS) $(LDFLAGS) -o $@
	@echo "[LD]\t $^: $@\n"
	@$(SZ) $@

$(BUILD_DIR)/%.hex: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	@$(HEX) $< $@
	@echo "[OBJCOPY]\t$< -> $@"
	
$(BUILD_DIR)/%.bin: $(BUILD_DIR)/%.elf | $(BUILD_DIR)
	@$(BIN) $< $@	
	@echo "[OBJCOPY]\t$< -> $@"

$(BUILD_DIR):
	mkdir -p $@		

clean:
	-rm -fR $(BUILD_DIR)

# st-link flashing
flash: $(TARGET_BIN)
	st-flash erase
	st-flash write $(TARGET_BIN) 0x8000000
	st-flash reset

.PHONY: debug_server
debug_server:
	st-util

dbg: $(TARGET_ELF)
	$(DB) --eval-command="target remote localhost:4242" $(TARGET_ELF)

