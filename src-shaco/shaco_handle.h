#ifndef __shaco_handle_h__
#define __shaco_handle_h__

#include <stdint.h>

struct shaco_context;

void shaco_handle_init();
void shaco_handle_fini();

uint32_t shaco_handle_register(struct shaco_context *ctx);
void shaco_handle_unregister(struct shaco_context *ctx);
struct shaco_context *shaco_handle_context(uint32_t handle);
uint32_t shaco_handle_query(const char *name);
void shaco_handle_bindname(uint32_t handle, const char *name);
void shaco_handle_send(int dest, int source, int session, int type, const void *msg, int sz);

#endif
