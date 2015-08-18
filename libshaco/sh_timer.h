#ifndef __sh_timer_h__
#define __sh_timer_h__

#include <stdint.h>

int sh_timer_max_timeout();
void sh_timer_dispatch_timeout();
void sh_timer_register(int handle, int session, int interval);
uint64_t sh_timer_start_time();
uint64_t sh_timer_now();
uint64_t sh_timer_time();

#endif
