#ifndef __shaco_context_h__
#define __shaco_context_h__

struct shaco_context;

struct shaco_context *shaco_context_create(const char *name);
void shaco_context_free(struct shaco_context *ctx);
void shaco_context_send(struct shaco_context *ctx, int source, int session, int type, const void *msg, int sz);

#endif
