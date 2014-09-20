all: bprocessor.c lcd.c lcd.h
	arm-none-eabi-gcc  -I /usr/local/arm-none-eabi/include/ -DSTM32L1 -mthumb -mcpu=cortex-m3 -msoft-float -mfix-cortex-m3-ldrd -fno-common -ffunction-sections -fdata-sections -g -O2 -c -o bprocessor.o bprocessor.c
	arm-none-eabi-gcc  -I /usr/local/arm-none-eabi/include/ -DSTM32L1 -mthumb -mcpu=cortex-m3 -msoft-float -mfix-cortex-m3-ldrd -fno-common -ffunction-sections -fdata-sections -g -O2 -c -o lcd.o lcd.c
	arm-none-eabi-gcc  -I /usr/local/arm-none-eabi/include/ -DSTM32L1 -mthumb -mcpu=cortex-m3 -msoft-float -mfix-cortex-m3-ldrd -fno-common -ffunction-sections -fdata-sections -g -O2 -c -o sysclock.o sysclock.c
	arm-none-eabi-gcc  -I /usr/local/arm-none-eabi/include/ -DSTM32L1 -mthumb -mcpu=cortex-m3 -msoft-float -mfix-cortex-m3-ldrd -fno-common -ffunction-sections -fdata-sections -g -O2 -c -o onewire.o onewire.c
	arm-none-eabi-gcc --static  -L/usr/local/arm-none-eabi/lib/ -Tstm32l15xxb.ld -nostartfiles -mthumb -mcpu=cortex-m3 -msoft-float -mfix-cortex-m3-ldrd  lcd.o sysclock.o onewire.o bprocessor.o -Wl,--start-group -lopencm3_stm32l1 -lc -Wl,--end-group -o bprocessor.elf
	arm-none-eabi-objcopy -Obinary bprocessor.elf bprocessor.bin

install:
	st-flash write ./bprocessor.bin 0x8000000

# arm-none-eabi-gcc --static -nostartfiles -L../../../../../libopencm3//lib -T../../../../../libopencm3//lib/stm32/l1/stm32l15xxb.ld -Wl,-Map=lcd-hello.map -Wl,--gc-sections -mthumb -mcpu=cortex-m3 -msoft-float -mfix-cortex-m3-ldrd lcd-hello.o -lopencm3_stm32l1 -Wl,--start-group -lc -lgcc -lnosys -Wl,--end-group -o lcd-hello.elf
