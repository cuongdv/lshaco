#ifndef __shaco_h__
#define __shaco_h__

#include "shaco_malloc.h"
#include "shaco_env.h"
#include "shaco_log.h"

struct shaco_context;

#define MT_TEXT 1
#define MT_UM   2
#define MT_MONITOR 3
#define MT_LOG 4
#define MT_CMD 5
#define MT_RET 6
#define MT_SOCKET 7
#define MT_TIME 8

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

typedef int (*shaco_cb)(struct shaco_context *ctx, void *ud, int source, int session, int type, const void *msg, int sz);
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
