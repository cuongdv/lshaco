#include "shaco_handle.h"
#include "shaco_malloc.h"
#include "shaco_context.h"
#include "shaco_module.h"
#include "shaco_log.h"
#include <string.h>

struct namehandle {
    char *name;
    uint32_t handle;
};

static struct {
    int context_cap;
    int context_count;
    struct shaco_context **contexts;
    int handle_cap;
    int handle_count;
    struct namehandle *handles;
} *H = NULL;

uint32_t 
shaco_handle_query(const char *name) {
    int i;
    for (i=0; i<H->handle_count; ++i) {
        if (strcmp(name, H->handles[i].name) == 0)
            return H->handles[i].handle;
    }
    return 0;
}

uint32_t 
shaco_handle_register(struct shaco_context *ctx) {
    if (H->context_count == H->context_cap) {
        H->context_cap = H->context_cap*2;
        H->contexts = shaco_realloc(H->contexts, sizeof(H->contexts[0])*H->context_cap);
    }
    H->contexts[H->context_count++] = ctx;
    uint32_t handle = H->context_count;
    return handle;
}

void 
shaco_handle_unregister(struct shaco_context *ctx) {
    uint32_t handle = shaco_context_handle(ctx);
    if (handle > 0 && handle <= H->context_count) {
        H->contexts[handle-1] = NULL;
    }
}

struct shaco_context *
shaco_handle_context(uint32_t handle) {
    struct shaco_context *ctx;
    if (handle > 0 && handle <= H->context_count)
        ctx = H->contexts[handle-1];
    else
        ctx = NULL;
    if (ctx == NULL) {
        shaco_error(NULL,"Handle not found %x", handle);
    }
    return ctx;
}

void
shaco_handle_bindname(uint32_t handle, const char *name) {
    if (H->handle_count == H->handle_cap) {
        H->handle_cap = H->handle_cap*2;
        H->handles = shaco_realloc(H->handles, sizeof(H->handles[0]) * H->handle_cap);
    }
    struct namehandle *h = &H->handles[H->handle_count++];
    h->name = shaco_strdup(name);
    h->handle = handle;
}

void
shaco_handle_send(int dest, int source, int session, int type, const void *msg, int sz) {
    struct shaco_context *ctx = shaco_handle_context(dest);
    if (ctx) {
        shaco_context_send(ctx, source, session, type, msg, sz);
    } else {
        shaco_error(NULL,"Context no found: %0x->%0x session:%d type:%d sz:%d",
                source, dest, session, type, sz);
    }
}

void
shaco_handle_init() {
    H = shaco_malloc(sizeof(*H));
    H->context_cap = 1;
    H->context_count = 0;
    H->contexts = shaco_malloc(sizeof(H->contexts[0])*H->context_cap);
    H->handle_cap = 1;
    H->handle_count = 0;
    H->handles = shaco_malloc(sizeof(H->handles[0])*H->handle_cap);
}

void
shaco_handle_fini() {
    if (H == NULL)
        return;
    if (H->contexts) {
        int i;
        for (i=0; i<H->context_count; ++i) {
            shaco_context_free(H->contexts[i]);
        }
        shaco_free(H->contexts);
        H->contexts = NULL;
    }
    if (H->handles) {
        int i; 
        for (i=0; i<H->handle_count; ++i) {
            shaco_free(H->handles[i].name);
        }
        shaco_free(H->handles);
        H->handles = NULL;
    }
    shaco_free(H);
    H = NULL;
}
