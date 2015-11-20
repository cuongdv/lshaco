#ifndef __shaco_context_h__
#define __shaco_context_h__

#include <stdint.h>
//#define MODULE_INVALID -1
//#define MODULE_SELF ((s)->dl.content)
//#define MODULE_NAME ((s)->unique_name)
//#define MODULE_ID ((s)->moduleid)
//#define MT_SYS  0
#define MT_TEXT 1
#define MT_UM   2
#define MT_MONITOR 3
#define MT_LOG 4
#define MT_CMD 5
#define MT_RET 6
#define MT_SOCKET 7
#define MT_TIME 8

struct shaco_module;
struct shaco_context;

typedef int (*shaco_cb)(struct shaco_context *ctx, int source, int session, int type, const void *msg, int sz);

struct shaco_context {
    struct shaco_module *module;
    uint32_t handle;
    void *udata;
    void *instance;
    shaco_cb cb;
};

struct shaco_context *shaco_context_create(const char *name);
void shaco_context_send(struct shaco_context *ctx, int source, int session, int type, const void *msg, int sz);

#endif
