/*
 * sysclock.c -- mocroseconds delay
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

#include "sysclock.h"
#include <libopencm3/cm3/nvic.h>
#include <libopencm3/cm3/systick.h>

static volatile uint32_t systick_timer;

void systick_init (void)
{
  systick_set_clocksource(-1);	/* Processor as clock source */
  systick_set_reload (32);	/* Every 2us on HSI */
  systick_interrupt_enable();
}

void sys_tick_handler(void)
{
  if (systick_timer)
    systick_timer --;
}

void delay_us (uint32_t delay)
{
  systick_timer = (delay+1)/2;	/* ticks produces every 3 us */
  systick_counter_enable ();
  do {} while (systick_timer);
  systick_counter_disable ();  
}
