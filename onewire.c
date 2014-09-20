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
#define OW_HOST_DIR_OUT gpio_mode_setup (GPIOA, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO5)
#define OW_HOST_DIR_IN  gpio_mode_setup (GPIOA, GPIO_MODE_INPUT,  GPIO_PUPD_NONE, GPIO5)
#else
#define OW_HOST_DIR_OUT GPIO_MODER(GPIOA) |=  (1<<10)
#define OW_HOST_DIR_IN  GPIO_MODER(GPIOA) &= ~(3<<10)
#endif

#define OW_HOST_OUT_LOW  gpio_clear (GPIOA, GPIO5)
#define OW_HOST_OUT_HIGH gpio_set   (GPIOA, GPIO5)

#define OW_HOST_GET_IN   gpio_get   (GPIOA, GPIO5)

void
ow_host_init (void)
{
  rcc_peripheral_enable_clock (&RCC_AHBENR, RCC_AHBENR_GPIOAEN);
  gpio_set_output_options (GPIOA, GPIO_OTYPE_OD, GPIO_OSPEED_40MHZ, GPIO5);
  OW_HOST_DIR_IN;
}

uint8_t
ow_host_reset (void)
{
  uint8_t result;

  OW_HOST_OUT_LOW;
  OW_HOST_DIR_OUT;
  delay_us (480);

  OW_HOST_DIR_IN;
  delay_us(65);

  result = OW_HOST_GET_IN;
  delay_us(480);

  /* After delay line must be high */
  if (OW_HOST_GET_IN == 0)
    {
      return 1;
    }

  return result;
}

uint8_t
ow_host_bit_io (uint8_t bit)
{
  uint8_t answer = 0;

  OW_HOST_DIR_OUT;
  if (bit == 0)			/* send 0 */
    {
      delay_us (60);
      OW_HOST_DIR_IN;
    }
  else				/* send 1 and, probably, read answer */
    {
      delay_us (2);
      OW_HOST_DIR_IN;

      delay_us (10);		/* in this place we can read answer */
      answer = (OW_HOST_GET_IN == 0) ? 0 : 1;
      delay_us (48);
    }
  delay_us (5);
  return answer;
}

uint64_t
ow_host_read_rom (void)
{
  int i;
  uint64_t result = 0, a = 0;
  for (i = 0; i < 8; i++)	/* send READ_ROM command */
    {
      ow_host_bit_io ((OW_READ_ROM >> i) & 0x1);
    }

  for (i = 0; i < 64; i++)
    {
      a = ow_host_bit_io (1);
      result |= a << i;
    }
  OW_HOST_DIR_IN;

  return result;
}

#if 0
#define OW_CLIENT_DIR_OUT gpio_mode_setup (GPIOA, GPIO_MODE_OUTPUT, GPIO_PUPD_NONE, GPIO11)
#define OW_CLIENT_DIR_IN  gpio_mode_setup (GPIOA, GPIO_MODE_INPUT,  GPIO_PUPD_NONE, GPIO11)
#else
#define OW_CLIENT_DIR_OUT GPIO_MODER(GPIOA) |=  (1<<22)
#define OW_CLIENT_DIR_IN  GPIO_MODER(GPIOA) &= ~(3<<22)
#endif

#define OW_CLIENT_OUT_LOW  gpio_clear (GPIOA, GPIO11)
#define OW_CLIENT_OUT_HIGH gpio_set   (GPIOA, GPIO11)

#define OW_CLIENT_GET_IN   gpio_get   (GPIOA, GPIO11)

void
ow_client_init (void)
{
  rcc_peripheral_enable_clock (&RCC_AHBENR, RCC_AHBENR_GPIOAEN);
  gpio_set_output_options (GPIOA, GPIO_OTYPE_OD, GPIO_OSPEED_40MHZ, GPIO11);
  OW_CLIENT_DIR_IN;
}

/* After ow_client_wait_reset we always return GPIO_A port 11 to DIR_IN state */
inline void
ow_client_wait_reset ()
{
  OW_CLIENT_DIR_IN;
  do {} while (OW_CLIENT_GET_IN == 0); /* Wait until host stops to send any signal */
  while (1)
    {
      do {} while (OW_CLIENT_GET_IN != 0); /* Wait to reset pulse beginnigng */
      /* Now we must test if it's really reset pulse.
       Reset signal longs at least 480 microseconds, so sample it twite: */
      delay_us (120);
      if (OW_CLIENT_GET_IN != 0) continue; /* after 120+epsilon useconds signals was up. Restart reset waiting */
      delay_us (120);
      if (OW_CLIENT_GET_IN != 0) continue; /* after 240+2*epsilon useconds signals was up. Restart reset waiting */
      do {} while (OW_CLIENT_GET_IN == 0); /* Ok, it's reset signal. Wait until it ends */
      break;
    }
  delay_us (15);	      /* we must low power after 15-60 useconds delay */
  OW_CLIENT_OUT_LOW;
  OW_CLIENT_DIR_OUT;
  delay_us (120);		/*  on 60-240 useconds to show our presence. */
  OW_CLIENT_DIR_IN;
  return;
}

inline uint8_t
ow_client_bit_io (uint8_t bit)
{
  uint8_t answer = 0;
  OW_CLIENT_DIR_IN;
  do {} while (OW_CLIENT_GET_IN != 0); /* Message starts when we get one peak. */
  if (bit == 0)
    {
      OW_CLIENT_OUT_LOW;
      OW_CLIENT_DIR_OUT;
      delay_us (30); /* host samples after 15 useconds after peak. We must up signal before 60 useconds after peak */
      OW_CLIENT_DIR_IN;
    }
  else
    {
      delay_us (20); /* Host low power on, at least, 60 us. So after 20 we must get answer */
      answer = (OW_CLIENT_GET_IN == 0) ? 0 : 1;
      do {} while (OW_CLIENT_GET_IN == 0); /* Wait end of reciving */
    }
  return answer;
}

inline uint8_t
ow_client_get_byte ()
{
  int i;
  uint8_t answer = 0;
  for (i = 0; i < 8; i++)
    {
      answer >>= 1;
      do {} while (OW_CLIENT_GET_IN != 0); /* Message starts when we get one peak. */
      delay_us (20); /* Host low power on, at least, 60 us. So after 20 we must get answer */
      answer |= (OW_CLIENT_GET_IN == 0) ? 0 : 0x80;
      do {} while (OW_CLIENT_GET_IN == 0); /* Wait end of reciving */
    }
  return answer;
}

inline uint8_t
ow_client_send_8_bytes (uint64_t rom)
{
  int i;
  for (i = 0; i < 64; i++)
    {
      do {} while (OW_CLIENT_GET_IN != 0); /* Wait for bit request */
      if (rom & 1)		/* send 1 */
	{
	  do {} while (OW_CLIENT_GET_IN == 0); /* Wait until bit request stops and go to next bit request*/
	}
      else			/* send 0 */
	{
	  OW_CLIENT_OUT_LOW;
	  OW_CLIENT_DIR_OUT;
	  delay_us (30); /* host samples after 15 useconds after peak. We must up signal before 60 useconds after peak */
	  OW_CLIENT_DIR_IN;
	}
      rom >>= 1;
    }
}

uint8_t
ow_client_send_rom (uint64_t rom)
{
  int i;
  uint8_t command, bit;

  do
    {
      ow_client_wait_reset ();
      command = ow_client_get_byte ();
    }
  while (command != OW_READ_ROM);
  ow_client_send_8_bytes (rom);

  return command;
}


#if 0
uint8_t
ow_client_send_rom (uint64_t rom)
{
  int i;
  uint8_t command, bit;

  ow_client_wait_reset ();

  for (i = 0; i < 8; i++)
    {
      bit = ow_client_bit_io (1); /* read byte or send 1 */
      command |= bit << i;
    }

  if (command != OW_READ_ROM)
    {
      return command;			/* Only READ_ROM realised */
    }

  for (i = 0; i < 64; i++)
    {
      ow_client_bit_io ((rom >> i) & 1);
    }

  return command;
}
#endif
