#ifndef __shaco_context_h__
#define __shaco_context_h__

#include <stdint.h>

struct shaco_context;

uint32_t shaco_context_create(const char *name, const char *args);
void shaco_context_free(struct shaco_context *ctx);
uint32_t shaco_context_handle(struct shaco_context *ctx);
int  shaco_context_send(struct shaco_context *ctx, int source, int session, int type, const void *msg, int sz);

#endif
