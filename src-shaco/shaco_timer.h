#ifndef __shaco_timer_h__
#define __shaco_timer_h__

#include <stdint.h>

void shaco_timer_init();
void shaco_timer_fini();

int shaco_timer_max_timeout();
void shaco_timer_trigger();
void shaco_timer_register(uint32_t handle, int session, int interval);
uint64_t shaco_timer_start_time();
uint64_t shaco_timer_now();
uint64_t shaco_timer_time();

#endif
