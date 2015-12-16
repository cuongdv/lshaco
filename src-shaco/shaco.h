#ifndef __shaco_h__
#define __shaco_h__

#include "shaco_malloc.h"
#include "shaco_env.h"
#include "shaco_log.h"
#include "shaco_context.h"
#include "shaco_timer.h"
#include "shaco_handle.h"

struct shaco_context;

#define SHACO_TTEXT 1
#define SHACO_TLUA  2
#define SHACO_TMONITOR 3
#define SHACO_TLOG 4
#define SHACO_TCMD 5
#define SHACO_TRESPONSE 6
#define SHACO_TSOCKET 7
#define SHACO_TTIME 8
#define SHACO_TREMOTE 9
#define SHACO_DONT_COPY 0x80000000

typedef int (*shaco_cb)(
        struct shaco_context *ctx, 
        void *ud, 
        int source, 
        int session, 
        int type, 
        const void *msg, 
        int sz);

void shaco_init();
void shaco_fini();
void shaco_start();
void shaco_stop(const char* info);

uint32_t shaco_launch(struct shaco_context *ctx, const char *name);
void shaco_callback(struct shaco_context *context, shaco_cb cb, void *ud);
int  shaco_send(struct shaco_context *ctx, int dest, int session, int type, const void *msg, int sz);
const char *shaco_command(struct shaco_context *ctx, const char *name, const char *param);

void shaco_backtrace(struct shaco_context *ctx);
void shaco_panic(struct shaco_context *ctx, const char* fmt, ...)
#ifdef __GNUC__
__attribute__((format(printf, 2, 3)))
__attribute__((noreturn))
#endif
;
void shaco_exit(struct shaco_context *ctx, const char* fmt, ...) 
#ifdef __GNUC__
__attribute__((format(printf, 2, 3)))
__attribute__((noreturn))
#endif
;

#endif
