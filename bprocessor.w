%% bprocessor.w -- save and use iButton data with STM32L-DISCOVERY board

%% Copyright (C) 2014 Nikolay Merinov <nikolay.merinov@member.fsf.org>

%% This program is free software: you can redistribute it and/or modify
%% it under the terms of the GNU General Public License as published by
%% the Free Software Foundation, either version 3 of the License, or
%% (at your option) any later version.

%% This program is distributed in the hope that it will be useful,
%% but WITHOUT ANY WARRANTY; without even the implied warranty of
%% MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
%% GNU General Public License for more details.

%% You should have received a copy of the GNU General Public License
%% along with this program.  If not, see <http://www.gnu.org/licenses/>.

@* Device for working with iButtons.
This program runs at stm32l-discovery and can store iButton data from keys and
give it to iButton readers. For storing datas this program act as one wire host
device, for reading -- as one wire slave device. % TODO: slave?
STM32L-Discovery board in this task must work from battery CR2032 so program
must require as low power as possible. For this purpose program would work at
low power run mode and would enable {\tt stop} mode when we not reading or
writing data.
@ This program would use libopencm3 \.{<https://github.com/libopencm3/libopencm3>}
library. And work in three modes: read iButton data, write  iButton data and
stop mode. After start we go to read data mode with low power run processor mode.
For switching between stop mode and read mode we would use {\tt USER} button.
@c
@<Global definitions and enums@>@;
@<Include files@>@;
@<Predeclaration of functions@>@;
@<Functions@>@;
@#
int
main (int argc, char **argv)
{
  @<|main| variable declarations@>@;
  @<Disable all GPIO pins@>@;
  @<Configure one wire pins@>@;
  @<Configure |USER| button@>@;
  @<Configure screen@>@;
  @<Switch to lp-run mode@>@;

  while (1)
    {
      @<Take action depend on mode@>@;
      __asm__("nop"); 		/* Not optimize cycle out */
    }
}

@* Decrease power consumption.
First we disable all GPIOs for economy reasons.
All work wold go through \.{libopencm3} library.

@<Include...@>=
#include <libopencm3/stm32/rcc.h>
#include <libopencm3/stm32/gpio.h>

@ With next code  decrease power consumption from 1000uA to 640uA
@<Disable all GPIO...@>=
  rcc_peripheral_enable_clock(&RCC_AHBENR, RCC_AHBENR_GPIOAEN
  			      | RCC_AHBENR_GPIOBEN | RCC_AHBENR_GPIOCEN);
  gpio_mode_setup(GPIOA, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO_ALL);
  gpio_mode_setup(GPIOB, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO_ALL);
  gpio_mode_setup(GPIOC, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO_ALL);
  gpio_clear(GPIOA, GPIO_ALL);
  gpio_clear(GPIOB, GPIO_ALL);
  gpio_clear(GPIOC, GPIO_ALL);
  rcc_peripheral_disable_clock(&RCC_AHBENR, RCC_AHBENR_GPIOAEN
  			      | RCC_AHBENR_GPIOBEN | RCC_AHBENR_GPIOCEN);

@ Now configure switching to low power mode. According to documentation in
lp-run mode, the system frequency should not exceed f\_MSI range 1 (127KHZ).
Low power run mode can only be entered when VCORE is in range 2. In addition, the
dynamic voltage scaling must not be used when Low power run mode is selected.

To enter Low power run mode proceed as follows:

1. Each digital IP clock must be enabled or disabled by using the RCC_APBxENR and
RCC_AHBENR registers.

2. The frequency of the system clock must be decreased to not exceed the frequency of
f_MSI range1.

3. The regulator is forced in low power mode by software (LPRUN and LPSDSR bits set).

@<Include...@>=
#include <libopencm3/stm32/pwr.h>
#include <libopencm3/stm32/flash.h>

@ First of all decrease timers speed and disable power voltage detection.
This code decrease power consumption to 24uA.

@<Switch to lp...@>=
clock_scale_t myclock_config = { 0,0,0,
  FLASH_ACR_LATENCY_0WS,
  RCC_CFGR_HPRE_SYSCLK_DIV2,
  RCC_CFGR_PPRE1_HCLK_NODIV,
  RCC_CFGR_PPRE2_HCLK_NODIV,
  RANGE2,
  65536,
  65536,
  RCC_ICSCR_MSIRANGE_65KHZ,
};
rcc_clock_setup_msi(&myclock_config); //Power consumption now ~ 40uA
pwr_disable_power_voltage_detect(); //Now 24uA


@ Bot enabling lp-mode registers seems to not change power consumption

@<Switch to lp...@>=
PWR_CR |= PWR_CR_LPSDSR;
PWR_CR |= PWR_CR_LPRUN;

@* Enable LCD screen for information output.
Now we want to enable LCD screen and display on it something like ``Read..''.
For this purpose we must move all LCD GPIO pins to alternative mode
with alternative function 11.
LCD connected to PA1, PA2, PA3, PA8, PA9, PA10, PA15, PB3, PB4, PB5, PB8,
PB9, PB10, PB11, PB12, PB13, PB14, PB15, PC0, PC1, PC2, PC3, PC6, PC7, PC8,
PC9, PC10, PC11 pins. It's LDS's COM[0:3] and SEG[0:2,7:21,24:27,40:41].
@<Configure screen@>=
rcc_peripheral_enable_clock (&RCC_AHBENR, RCC_AHBENR_GPIOAEN
			     | RCC_AHBENR_GPIOBEN | RCC_AHBENR_GPIOCEN);
rcc_peripheral_enable_clock (&RCC_AHBLPENR, RCC_AHBLPENR_GPIOALPEN
			     | RCC_AHBLPENR_GPIOBLPEN | RCC_AHBLPENR_GPIOCLPEN);
gpio_mode_setup(GPIOA, GPIO_MODE_AF, GPIO_PUPD_NONE, GPIO1 | GPIO2 | GPIO3
		| GPIO8 | GPIO9 | GPIO10 | GPIO15);
gpio_mode_setup(GPIOB, GPIO_MODE_AF, GPIO_PUPD_NONE, GPIO3 | GPIO4 | GPIO5 | GPIO8
		| GPIO9 | GPIO10 | GPIO11 | GPIO12 | GPIO13 | GPIO14 | GPIO15);
gpio_mode_setup(GPIOC, GPIO_MODE_AF, GPIO_PUPD_NONE, GPIO0 | GPIO1 | GPIO2 | GPIO3
		| GPIO6 | GPIO7 | GPIO8 | GPIO9 | GPIO10 | GPIO11);

gpio_set_af (GPIOA, GPIO_AF11, GPIO1 | GPIO2 | GPIO3 | GPIO8 | GPIO9 | GPIO10
	     | GPIO15);
gpio_set_af (GPIOB, GPIO_AF11, GPIO3 | GPIO4 | GPIO5 | GPIO8 | GPIO9 | GPIO10
	     | GPIO11 | GPIO12 | GPIO13 | GPIO14 | GPIO15);
gpio_set_af (GPIOC, GPIO_AF11, GPIO0 | GPIO1 | GPIO2 | GPIO3 | GPIO6 | GPIO7
	     | GPIO8 | GPIO9 | GPIO10 | GPIO11);

@ LCD use not only ports. Also LCD screen use LCDCLK clock.
We would use LSI clock as LCDCLK source.

@<Configure screen@>=
rcc_peripheral_enable_clock (&RCC_APB1ENR, RCC_APB1ENR_PWREN | RCC_APB1ENR_LCDEN);
pwr_disable_backup_domain_write_protect ();
rcc_osc_on (LSE);
rcc_wait_for_osc_ready (LSE);
rcc_rtc_select_clock (RCC_CSR_RTCSEL_LSE);
RCC_CSR |= RCC_CSR_RTCEN;
pwr_enable_backup_domain_write_protect ();

@ Next step to enable LCD is configure LCD controller for 24/4 LCD screen by setting
|DUTY|, |BIAS| and |MUX_SEG| in |LCD_CR| register. We use COM[0:3] commons and
SEG[0:2,7:21,24:27,40:41] segments. So we must select |MUX_SEG == 1|, |DUTY == 1/4|.
Also let's set |BIAS == 1/3|.

@d LCD_CR MMIO32(LCD_BASE + 0x00)
@d LCD_CR_LCDEN (1 << 0)
@d LCD_CR_VSEL (1 << 1)
@d LCD_CR_DUTY_MASK (7 << 2)
@d LCD_CR_DUTY_1_2 (1 << 2)
@d LCD_CR_DUTY_1_3 (2 << 2)
@d LCD_CR_DUTY_1_4 (3 << 2)
@d LCD_CR_DUTY_1_8 (4 << 2)
@d LCD_CR_BIAS_MASK (3 << 5)
@d LCD_CR_BIAS_1_4 (0 << 5)
@d LCD_CR_BIAS_1_2 (1 << 5)
@d LCD_CR_BIAS_1_3 (2 << 5)
@d LCD_CR_MUX_SEG (1 << 7)

@<Configure screen@>=
LCD_CR |= LCD_CR_MUX_SEG | LCD_CR_DUTY_1_4 | LCD_CR_BIAS_1_3;

@ Now we would configure frame rate, contrast and other LCD optional features.
Let's use as rare update as possible. So prescaler |PS| would be equal $1$ and
divider |DIV| would be equal $1/31$. And let other values of |LCD_FCR| regiser
keep their default value.

@d LCD_FCR MMIO32(LCD_BASE + 0x04)
@d LCD_FCR_PS_MASK (0xF << 22)
@d LCD_FCR_DIV_MASK (0xF << 18)

@<Configure screen@>=
LCD_FCR |= LCD_FCR_DIV_MASK; // Set DIV to 1111 i.e. $1/31$
LCD_FCR &= ~LCD_FCR_PS_MASK; // Set PS to 0000 i.e. $1/1$

@ End at least enable LCD end write some data to screen

@d LCD_SR MMIO32(LCD_BASE + 0x08) 
@d LCD_SR_UDR (1 << 2)

@d LCD_RAM_BASE (LCD_BASE + 0x14)
@d LCD_RAM_COM0 MMIO64(LCD_RAM_BASE + 0x0)
@d LCD_RAM_COM1 MMIO64(LCD_RAM_BASE + 0x8)
@d LCD_RAM_COM2 MMIO64(LCD_RAM_BASE + 0x10)
@d LCD_RAM_COM3 MMIO64(LCD_RAM_BASE + 0x18)

@<Configure screen@>=
LCD_CR |= LCD_CR_LCDEN;
int i = 0xFFFF; do {--i;} while (i);
LCD_RAM_COM1 = 0xFFFF;
((char *) LCD_RAM_BASE)[0] = '\xff';
LCD_SR |= LCD_SR_UDR;