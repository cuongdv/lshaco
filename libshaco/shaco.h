#ifndef __shaco_h__
#define __shaco_h__

#include "shaco_malloc.h"
//#include "shaco_env.h"
//#include "shaco_log.h"
#include "shaco_context.h"

//#include <stdbool.h>
//#include <stdlib.h>
//#include <stdarg.h>
//#include <string.h>
//#include <assert.h>
//#include <stdio.h>
//#include <limits.h>

void shaco_init();
void shaco_fini();
void shaco_start();
void shaco_stop(const char* info);

void shaco_exit(const char* fmt, ...) 
#ifdef __GNUC__
__attribute__((format(printf, 1, 2)))
__attribute__((noreturn))
#endif
;
void shaco_callback(struct shaco_context *context, shaco_cb cb, void *ud);
void shaco_send(int dest, int source, int session, int type, const void *msg, int sz);
void shaco_send_local_directly(int dest, int source, int session, int type, const void *msg, int sz);
void shaco_backtrace();
void shaco_panic(const char* fmt, ...)
#ifdef __GNUC__
__attribute__((format(printf, 1, 2)))
__attribute__((noreturn))
#endif
;

#endif
