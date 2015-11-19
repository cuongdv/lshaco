#include "shaco_handle.h"
#include "shaco_malloc.h"

struct namehandle {
    const char *name;
    uint32_t handle;
};

static struct {
    int context_cap;
    int context_count;
    struct shaco_context *contexts;
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
    return -1;
}

int 
shaco_handle_register(struct shaco_context *context) {
    if (H->context_count == H->context_cap) {
        H->context_cap = H->context_cap==0 ? 1 : H->context_cap*2;
        H->contexts = shaco_realloc(H->contexts, sizeof(H->contexts[0])*H->context_cap);
    }
    H->contexts[H->context_count++] = context;
    uint32_t handle = H->context_count;
    shaco_handle_bindname(handle, context->name);
    return handle;
}

void
shaco_handle_bindname(uint32_t handle, const char *name) {
    if (H->handle_count == H->handle_cap) {
        H->handle_cap = H->handle_cap == 0 ? 1 : H->handle_cap*2;
        H->handles = shaco_realloc(H->handles, sizeof(H->handles[0]) * H->handle_cap);
    }
    struct namehandle *h = &H->handles[H->handle_count++];
    h->name = shaco_strdup(name);
    h->handle = handle;
}

void
shaco_handle_init() {
    H = shaco_malloc(sizeof(*H));
    memset(H, 0, sizeof(*H));
}

void
shaco_handle_fini() {
    if (H == NULL)
        return;
    if (H->contexts) {
        free(H->contexts);
        H->contexts = NULL;
    }
    if (H->handles) {
        free(H->handles);
        H->handles = NULL;
    }
    free(H);
    H = NULL;
}
