#include "shaco_clusternode.h"
#include "sahco_context.h"
#include "shaco_malloc.h"

#define SHACO_MSG_BATCH 10

#define INIT_CAP 8

struct message {
    int source;
    int dest;
    int session;
    int type;
    const void *msg;
    int sz;
};

static struct {
    int cap;
    int sz;
    int head;
    int tail;
    struct message *q;
} *Q = NULL;

void 
shaco_msg_push(int dest, int source, int session, int type, const void *msg, int sz) {
    if (Q->sz == Q->cap) {
        Q->cap = Q->cap*2;
        Q->q = shaco_realloc(Q->q, sizeof(Q->q[0]) * Q->cap);
    }
    if (Q->tail == Q->cap) {
        Q->tail = 0;
    }
    struct message *m = Q->q[Q->tail++];
    m->source = source;
    m->dest = dest;
    m->session = session;
    m->type = type;
    m->msg = msg;
    m->sz = sz;
    Q->sz ++;
}

static inline struct message *
shaco_msg_pop() {
    if (Q->head == Q->tail) {
        return NULL;
    }
    struct message *m =  Q->q[Q->head];
    Q->head ++;
    if (Q->head == Q->cap) {
        Q->head = 0;
    }
    return m;
}

void
shaco_msg_dispatch() {
    int i;
    for (i=0; i<SHACO_MSG_BATCH; ++i) {
        struct message *m = shaco_msg_pop();
        if (m) {
            shaco_send_local_directly(m->dest, m->source, m->session, m->type, m->msg, m->sz);
        } else break;
    }
}

int
shaco_msg_empty() {
    return Q->tail == Q->head;
}

void 
shaco_msg_dispatcher_init() {
    Q = shaco_malloc(sizeof(*Q));
    memset(Q, 0, sizeof(*Q));
    Q->cap = INIT_CAP;
    Q->sz = 0;
    Q->head = 0;
    Q->tail = 0;
    Q->q = shaco_malloc(sizeof(Q->q[0])*Q->cap);
}

void 
shaco_msg_dispatcher_fini() {
    if (Q) {
        if (Q->q)
            free(Q->q);
        free(Q);
        Q=NULL;
    }
}

void
shaco_send_local_directly(int dest, int source, int session, int type, const void *msg, int sz) {
    struct shaco_context *ctx = shaco_handle_context(dest);
    if (ctx) {
        shaco_context_send(ctx, source, session, type, msg, sz);
    } else {
        // todo log
    }
}

void
shaco_send(int dest, int source, int session, int type, const void *msg, int sz)  {
    if (shaco_clusternode_isremote(dest)) {
        shaco_clusternode_send(dest, source, session, type, msg, sz);
    } else {
        shaco_msg_push(dest, source, session type, msg, sz);
    }
}
