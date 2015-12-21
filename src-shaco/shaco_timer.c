#include "shaco.h"
#include "shaco_malloc.h"
#include <time.h>
#include <stdlib.h>
#include <string.h>
#include <stdbool.h>
#include <unistd.h>
#include <stdio.h>

#if defined(__APPLE__)
#include <sys/time.h>
#endif

struct time_node {
    uint32_t handle;
    int session;
    int interval;
    uint64_t expire;
};

struct time_heap {
    int cap;
    int sz;
    struct time_node *p;
};

static void 
time_push(struct time_heap *h, struct time_node *n) {
    if (h->sz == h->cap) {
        if (h->cap == 0)
            h->cap = 1;
        else
            h->cap *= 2; 
        h->p = shaco_realloc(h->p, sizeof(h->p[0]) * h->cap);
    }
    int pos = h->sz;
    while (pos>0) {
        int up = (pos-1)/2;
        if (n->expire < h->p[up].expire)
            h->p[pos] = h->p[up];
        else break;
        pos=up;
    }
    h->p[pos] = *n;
    h->sz++;     
}

static void
time_pop(struct time_heap *h, struct time_node* n) {
    *n = h->p[0];
    int last = --h->sz;
    if (last > 0) {
        uint64_t down = h->p[last--].expire;
        int i = 0;
        int child = 1;
        while (child <= last) {
            if (child < last)
                if (h->p[child].expire > h->p[child+1].expire)
                    child++;
            if (down >= h->p[child].expire)
                h->p[i] = h->p[child];
            else break;
            i = child;
            child = i*2+1;
        }
        h->p[i] = h->p[last+1];
    }
}

struct sh_timer {
    uint64_t start_time;
    uint64_t machine_start_time;
    uint64_t machine_elapsed_time;
    bool dirty;
    struct time_heap h;
};

static struct sh_timer* T = NULL;

static uint64_t
_now() {
#if !defined(__APPLE__)
    struct timespec ti;
    clock_gettime(CLOCK_REALTIME, &ti);
    return (uint64_t)ti.tv_sec * 1000 + (uint64_t)ti.tv_nsec / 1000000;
#else
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)tv.tv_sec * 1000 + (uint64_t)tv.tv_usec / 1000;
#endif
}

static uint64_t
_elapsed() {
#if !defined(__APPLE__)
    struct timespec ti;
    clock_gettime(CLOCK_MONOTONIC_RAW, &ti);
    return (uint64_t)ti.tv_sec * 1000 + (uint64_t)ti.tv_nsec / 1000000;
#else
    struct timeval tv;
    gettimeofday(&tv, NULL);
    return (uint64_t)tv.tv_sec * 1000 + (uint64_t)tv.tv_usec / 1000;
#endif
}

static void
_elapsed_time() {
    if (T->dirty) {
        T->dirty = false;
        T->machine_elapsed_time = _elapsed();
    }
}

uint64_t
shaco_timer_start_time() {
    return T->start_time;
}

uint64_t 
shaco_timer_now() {
    _elapsed_time();
    return T->machine_start_time + T->machine_elapsed_time;
}

uint64_t 
shaco_timer_time() {
    return T->machine_start_time + _elapsed();
}

int
shaco_timer_max_timeout() {
    T->machine_elapsed_time = _elapsed(); 
    T->dirty = true;
    
    struct time_heap *h = &T->h;
    if (h->sz > 0) {
        uint64_t expire = h->p[0].expire;
        return expire > T->machine_elapsed_time ?
            expire - T->machine_elapsed_time : 0;
    } else {
        return -1;
    }
}

void
shaco_timer_trigger() {
    //T->dirty = true;
    _elapsed_time();
    
    struct time_heap *h = &T->h;
    while (h->sz) {
        if (h->p[0].expire <= T->machine_elapsed_time) {
            struct time_node n;
            time_pop(h, &n);
            shaco_handle_send(n.handle, 0, n.session, SHACO_TTIME, NULL, 0);
        } else {
            break;
        }
    }
}

void
shaco_timer_register(uint32_t handle, int session, int interval) {
    struct time_node n;
    n.handle = handle;
    n.session = session;
    n.interval = interval;
    n.expire = T->machine_elapsed_time + interval;
    time_push(&T->h, &n);
}

void
shaco_timer_init() {
    T = shaco_malloc(sizeof(*T));
    memset(T, 0, sizeof(*T));
    T->dirty = true;
    T->start_time = _now();
    T->machine_elapsed_time = _elapsed(); 
    T->machine_start_time = T->start_time - T->machine_elapsed_time;
    memset(&T->h, 0, sizeof(T->h));
}

void 
shaco_timer_fini() {
    if (T) {
        if (T->h.p) {
            shaco_free(T->h.p);
            T->h.p = NULL;
        }
        shaco_free(T);
        T = NULL;
    }
}
