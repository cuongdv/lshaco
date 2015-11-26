#include "shaco_clusternode.h"
#include "shaco_context.h"
#include "shaco_malloc.h"
#include "shaco_handle.h"
#include "shaco_malloc.h"
#include "shaco_log.h"
#include "shaco.h"
#include <string.h>
#include <stdio.h>

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

static inline void 
shaco_msg_push(int dest, int source, int session, int type, const void *msg, int sz) {
    struct message *m = &Q->q[Q->tail];
    m->source = source;
    m->dest = dest;
    m->session = session;
    m->type = type;
    m->msg = msg;
    m->sz = sz;
    Q->tail ++;
    if (Q->tail == Q->cap) {
        Q->tail = 0;
    }
    if (Q->tail == Q->head) {
        int cap = Q->cap;
        Q->cap = Q->cap*2;
        Q->q = shaco_realloc(Q->q, sizeof(Q->q[0]) * Q->cap);
        int i;
        for (i=0; i<Q->tail; ++i) {
            Q->q[cap+i] = Q->q[i];
        }
        Q->tail = cap+Q->tail;
    }
}

static inline struct message *
shaco_msg_pop() {
    if (Q->head == Q->tail) {
        return NULL;
    }
    struct message *m = &Q->q[Q->head];
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
            shaco_free((void*)m->msg);
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
    Q->head = 0;
    Q->tail = 0;
    Q->q = shaco_malloc(sizeof(Q->q[0])*Q->cap);
}

void 
shaco_msg_dispatcher_fini() {
    if (Q) {
        shaco_free(Q->q);
        Q->q = NULL;
        shaco_free(Q);
        Q=NULL;
    }
}

void
shaco_send_local_directly(int dest, int source, int session, int type, const void *msg, int sz) {
    struct shaco_context *ctx = shaco_handle_context(dest);
    if (ctx) {
        shaco_context_send(ctx, source, session, type, msg, sz);
    } else {
        shaco_error("Context no found: %0x->%0x session:%d type:%d sz:%d",
                source, dest, session, type, sz);
    }
}

void
shaco_send(int dest, int source, int session, int type, const void *msg, int sz) {
    if (shaco_clusternode_isremote(dest)) {
        // todo malloc msg ?
        shaco_clusternode_send(dest, source, session, type, msg, sz);
    } else {
        if ((type & SHACO_DONT_COPY) ==0) {
            void *tmp = shaco_malloc(sz);
            memcpy(tmp, msg, sz);
            msg = tmp;
        } else {
            type &= ~SHACO_DONT_COPY;
        }
        shaco_msg_push(dest, source, session, type, msg, sz);
    }
}
