#include "shaco_harbor.h"
#include "shaco_context.h"
#include "shaco_malloc.h"
#include "shaco_log.h"
#include "shaco.h"
#include <string.h>
#include <stdio.h>
#include <stdbool.h>

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
    int tail = Q->tail;
    while (true) {
        struct message *m = shaco_msg_pop();
        if (m) {
            const void *msg = m->msg;
            shaco_handle_send(m->dest, m->source, m->session, m->type, m->msg, m->sz);
            shaco_free((void*)msg);
            if (Q->head == tail)
                break;
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

int
shaco_send(struct shaco_context *ctx, int dest, int session, int type, const void *msg, int sz) {
    uint32_t source = shaco_context_handle(ctx);
    if (shaco_harbor_isremote(dest)) {
        bool free;
        if (type & SHACO_DONT_COPY) {
            type &= ~SHACO_DONT_COPY;
            free = true;
        } else
            free = false;
        int ret = shaco_harbor_send(dest, source, session, type, msg, sz);
        if (free) {
            shaco_free((void*)msg);
        }
        return ret;
    } else {
        if (type & SHACO_DONT_COPY) {
            type &= ~SHACO_DONT_COPY;
        } else {
            void *tmp = shaco_malloc(sz);
            memcpy(tmp, msg, sz);
            msg = tmp;
        }
        shaco_msg_push(dest, source, session, type, msg, sz);
        return 0;
    }
}
