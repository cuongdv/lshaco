#include "shaco_clusternode.h"
#include "shaco_context.h"

static struct shaco_context *H;

void
shaco_clusternode_start(struct shaco_context *ctx) {
    assert(ctx);
    H = ctx;
}

int
shaco_clusternode_isremote(int handle) {
    return 0; // todo
}

void
shaco_clusternode_send(int dest, int source, int session, int type, const void *msg, int sz) {
    struct shaco_remote_message rmsg;
    rmsg.dest = dest;
    rmsg.type = type;
    rmsg.msg = msg;
    rmsg.sz = sz;
    shaco_context_send(H, source, session, type, &rmsg, sizeof(rmsg));
}
