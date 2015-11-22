#ifndef __shaco_h__
#define __shaco_h__

#include "shaco_malloc.h"
#include "shaco_env.h"
#include "shaco_log.h"
#include "shaco_context.h"
#include "shaco_timer.h"

struct shaco_context;

#define SHACO_TTEXT 1
#define SHACO_TUM   2
#define SHACO_TMONITOR 3
#define SHACO_TLOG 4
#define SHACO_TCMD 5
#define SHACO_TRET 6
#define SHACO_TSOCKET 7
#define SHACO_TTIME 8

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
const char *shaco_command(struct shaco_context *ctx, const char *name, const char *param);
void shaco_backtrace();
void shaco_panic(const char* fmt, ...)
#ifdef __GNUC__
__attribute__((format(printf, 1, 2)))
__attribute__((noreturn))
#endif
;

#endif
