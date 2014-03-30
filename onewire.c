/*
 * onewire.c -- trivial host and client that can use on or two 1-wire commands
 *
 * This file part of bprocessor project.
 *
 * Copyright (C) 2014 Nikolay Merinov <nikolay.merinov@member.fsf.org>
 *
 * This library is free software: you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation, either version 3 of the License, or
 * (at your option) any later version.
 *
 * This library is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU Lesser General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this library.  If not, see <http://www.gnu.org/licenses/>.
 */

#include "onewire.h"
#include "sysclock.h"

#include <libopencm3/stm32/rcc.h>
#include <libopencm3/stm32/gpio.h>


#define OW_READ_ROM    0x33

#if 0
#define OW_DIR_OUT gpio_mode_setup (GPIOA, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO5)
#define OW_DIR_IN  gpio_mode_setup (GPIOA, GPIO_MODE_INPUT,  GPIO_PUPD_NONE, GPIO5)
#else
#define OW_DIR_OUT GPIO_MODER(GPIOA) |=  (1<<10)
#define OW_DIR_IN  GPIO_MODER(GPIOA) &= ~(3<<10)
#endif

#define OW_OUT_LOW  gpio_clear (GPIOA, GPIO5)
#define OW_OUT_HIGH gpio_set   (GPIOA, GPIO5)

#define OW_GET_IN   gpio_get   (GPIOA, GPIO5)

void
ow_init (void)
{
  rcc_peripheral_enable_clock (&RCC_AHBENR, RCC_AHBENR_GPIOAEN);
  gpio_set_output_options (GPIOA, GPIO_OTYPE_OD, GPIO_OSPEED_40MHZ, GPIO5);
  OW_DIR_IN;
}

uint8_t
ow_reset (void)
{
  uint8_t result;

  OW_OUT_LOW;
  OW_DIR_OUT;
  delay_us (480);

  OW_DIR_IN;
  delay_us(65);

  result = OW_GET_IN;
  delay_us(480);

  /* After delay line must be high */
  if (OW_GET_IN == 0)
    {
      return 1;
    }

  return result;
}

uint8_t
ow_bit_io (uint8_t bit)
{
  uint8_t answer = 0;

  OW_DIR_OUT;
  if (bit == 0)			/* send 0 */
    {
      delay_us (60);
      OW_DIR_IN;
    }
  else				/* send 1 and, probably, read answer */
    {
      delay_us (2);
      OW_DIR_IN;

      delay_us (10);		/* in this place we can read answer */
      answer = (OW_GET_IN == 0) ? 0 : 1;
      delay_us (48);
    }
  delay_us (5);
  return answer;
}

uint64_t
ow_read_rom (void)
{
  int i;
  uint64_t result = 0, a = 0;
  for (i = 0; i < 8; i++)	/* send READ_ROM command */
    {
      ow_bit_io ((0x33 >> i) & 0x1);
    }

  for (i = 0; i < 64; i++)
    {
      a = ow_bit_io (1);
      result |= a << i;
    }
  OW_DIR_IN;

  return result;
}
