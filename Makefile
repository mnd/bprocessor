all: bprocessor.c
	arm-none-eabi-gcc  -I /usr/local/arm-none-eabi/include/ -DSTM32L1 -mthumb -mcpu=cortex-m3 -msoft-float -mfix-cortex-m3-ldrd -fno-common -g -O0 -c -o bprocessor.o bprocessor.c
	arm-none-eabi-ld  -L/usr/local/arm-none-eabi/lib/ -L/usr/lib/arm-none-eabi/newlib/ -Tstm32l15xxb.ld -nostartfiles -o bprocessor.elf bprocessor.o -lopencm3_stm32l1
	arm-none-eabi-objcopy -Obinary bprocessor.elf bprocessor.bin

bprocessor.c : bprocessor.w
	ctangle $< || echo Ok!

install:
	st-flash write ./bprocessor.bin 0x8000000
