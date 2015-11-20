#include "shaco_context.h"
#include "shaco_malloc.h"
#include "shaco_module.h"
#include "shaco_handle.h"
#include "shaco_log.h"
#include <stdlib.h>

struct shaco_context *
shaco_context_create(const char *name) {
    struct shaco_module *dl = shaco_module_query(name);
    if (dl == NULL) {
        shaco_error("Context create failed, no module `%s`", name);
        return NULL;
    }
    struct shaco_context *ctx = shaco_malloc(sizeof(*ctx));
    ctx->module = dl;
    ctx->udata = NULL;
    ctx->cb = NULL;
    ctx->instance = shaco_module_instance_create(dl);
    ctx->handle = shaco_handle_register(ctx);
    if (ctx->module->init) {
        ctx->module->init(ctx, NULL); // todo NULL -> args
    }
    return ctx;
}

void 
shaco_context_send(struct shaco_context *ctx, int source, int session, int type, const void *msg, int sz) {
    int result = ctx->cb(ctx, source, session, type, msg, sz);
    if (result !=0 ) {
        shaco_error(
        "Context callback fail:%d : %0x->%s:%0x session:%d type:%d sz:%d", 
        result, source, ctx->module->name, ctx->handle, session, type, sz);
    }
}

void 
shaco_callback(struct shaco_context *ctx, shaco_cb cb, void *ud) {
    ctx->cb = cb;
    ctx->udata = ud;
}
