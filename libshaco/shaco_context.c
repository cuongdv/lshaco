#include "shaco_context.h"
#include "shaco_module.h"

struct shaco_context *
shaco_context_create(const char *name) {
    struct shaco_module *dl = shaco_module_query(name);
    if (dl == NULL) {
        sh_error("Context create failed, no module `%s`", name);
        return NULL;
    }
    struct shaco_context *ctx = shaco_malloc(sizeof(*ctx));
    ctx->module = dl;
    ctx->udata = NULL;
    ctx->instance = shaco_module_instance_create(dl);
    ctx->context_id = shaco_handle_register(ctx);
    shaco_module_instance_init(dl);
    return ctx;
}

void 
shaco_context_send(struct shaco_context *ctx, int source, int session, int type, const void *msg, int sz) {
    int result = context->cb(ctx, source, session, type, msg, sz);
    // todo check result
}

void 
shaco_callback(struct shaco_context *context, shaco_cb cb, void *ud) {
    context->cb = cb;
    context->udata = ud;
}
