#include "shaco.h"
#include "shaco_harbor.h"
#include "shaco_context.h"
#include "shaco_log.h"
#include <assert.h>

static struct shaco_context *H;

void
shaco_harbor_start(struct shaco_context *ctx) {
    assert(ctx);
    H = ctx;
}

int
shaco_harbor_isremote(int handle) {
    return 0; // todo
}

void
shaco_harbor_send(int dest, int source, int session, int type, const void *msg, int sz) {
    if (H) {
        struct shaco_remote_message rmsg;
        rmsg.dest = dest;
        rmsg.type = type;
        rmsg.msg = msg;
        rmsg.sz = sz;
        shaco_context_send(H, source, session, SHACO_TREMOTE, &rmsg, sizeof(rmsg));
    } else {
        shaco_error(NULL,"No harbor: %0x->%0x session:%d type:%d sz:%d", 
                source, dest, session, type, sz);
    }
}
