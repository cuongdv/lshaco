#ifndef __shaco_context_h__
#define __shaco_context_h__

//#define MODULE_INVALID -1
//#define MODULE_SELF ((s)->dl.content)
//#define MODULE_NAME ((s)->unique_name)
//#define MODULE_ID ((s)->moduleid)

struct shaco_module;
struct shaco_context;

typedef int (*shaco_cb)(struct shaco_context *ctx, int source, int session, int type, const void *msg, int sz);

struct shaco_context {
    struct shaco_module *module;
    int  context_id;
    void *udata;
    void *instance;
    shaco_cb cb;
};

struct shaco_context *shaco_context_create(const char *name);
void shaco_context_send(struct shaco_context *ctx, int source, int session, int type, const void *msg, int sz);

#endif
