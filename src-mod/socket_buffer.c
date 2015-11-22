#include "socket_buffer.h"
#include "shaco_malloc.h"
#include <stdlib.h>
#include <stdint.h>
#include <string.h>
#include <assert.h>

struct buffer_node {
    char *p;
    int sz;
    struct buffer_node *next;
};

void
sb_init(struct socket_buffer *sb) {
    memset(sb, 0, sizeof(*sb));
    sb->header = -1;
}

void
sb_fini(struct socket_buffer *sb) {
    struct buffer_node *tmp; 
    while (sb->head) {
        tmp = sb->head;
        sb->head = sb->head->next;
        shaco_free(tmp->p);
        shaco_free(tmp);
    }
}

void
sb_push(struct socket_buffer *sb, void *buf, int sz) {
    struct buffer_node *node = shaco_malloc(sizeof(*node));
    node->p = buf;
    node->sz = sz;
    node->next = NULL;
    if (sb->head == NULL) {
        sb->head = node;
        sb->tail = node;
    } else {
        assert(sb->tail);
        sb->tail->next = node;
        sb->tail = node;
    }
    sb->size += sz;
}

static void *
pushpack(struct socket_buffer *sb, 
         struct buffer_node *node, int end, int n) {
    char *pack = shaco_malloc(n);
    char *p = pack;
    int offset = sb->offset;
    int diff;
    struct buffer_node *current = sb->head; 
    while (current != node) {
        diff = current->sz-offset;
        memcpy(p, current->p+offset, diff); p += diff;
        current = current->next;
        offset = 0;
    }
    diff = end-offset;
    memcpy(p, current->p+offset, diff); p += diff;
    assert(p-pack == n);
    return pack;
}

static void
freebuffer(struct socket_buffer *sb, 
           struct buffer_node *node, int end) {
    sb->size += sb->offset;
    struct buffer_node *tmp;
    for (;;) {
        if (sb->head == node) {
            if (node->sz == end) {
                sb->head = sb->head->next;
                sb->size -= node->sz;
                sb->offset = 0;
                shaco_free(node->p);
                shaco_free(node);
            } else {
                sb->size -= end;
                sb->offset = end;
            }
            return;
        } else {
            tmp = sb->head;
            sb->head = sb->head->next;
            sb->size -= tmp->sz;
            shaco_free(tmp->p);
            shaco_free(tmp);
        }
    }
}

static int
readhead(struct socket_buffer *sb, int n) {
    if (sb->size < n) return -1;
    uint32_t head = 0;
    struct buffer_node *current = sb->head;
    int offset = sb->offset;
    int i=0, o;
    while (current) {
        for (o=offset; o<current->sz; ++o) {
            head |= ((uint8_t*)current->p)[o]<<(i++*8);
            if (i>=n) {
                freebuffer(sb, current, o+1);
                return head;
            }
        }
        current = current->next;
        offset = 0;
    }
    return -1;
}

static void *
readn(struct socket_buffer *sb, int n) {
    if (sb->size < n) return NULL;
    struct buffer_node *current = sb->head;
    int offset = sb->offset;
    int sz = 0;
    while (current) {
        sz += current->sz-offset;
        if (sz >= n) {
            int end = current->sz-(sz-n);
            void *p = pushpack(sb, current, end, n);
            freebuffer(sb, current, end);
            return p;
        }
        current = current->next;
        offset = 0;
    }
    return NULL;
}

int
sb_pop(struct socket_buffer *sb, struct socket_pack *sp) {
    if (sb->header == -1) {
        sb->header = readhead(sb, 2);
        if (sb->header == -1)
            return 1;
    }
    sp->p = readn(sb, sb->header);
    if (sp->p) {
        sp->sz = sb->header;
        sb->header = -1;
        return 0;
    } else return 1;
}
