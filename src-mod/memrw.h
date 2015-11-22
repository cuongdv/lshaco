#ifndef __memrw_h__
#define __memrw_h__

#include <stdint.h>
#include <string.h>

struct memrw {
    char *begin;
    char *ptr;
    size_t sz;
};

#define RW_SPACE(rw) ((rw)->sz - ((rw)->ptr - (rw)->begin))
#define RW_EMPTY(rw) ((rw)->ptr == (rw)->begin)
#define RW_CUR(rw) ((rw)->ptr - (rw)->begin)

static inline void
memrw_init(struct memrw* rw, void *data, size_t sz) {
    rw->begin = (char *)data;
    rw->ptr = (char *)data;
    rw->sz = sz;
};

static inline int
memrw_write(struct memrw* rw, const void* data, size_t sz) {
    size_t space = rw->sz - (rw->ptr - rw->begin);
    if (space >= sz) {
        memcpy(rw->ptr, data, sz);
        rw->ptr += sz;
        return 0;
    }
    return 1;
}

static inline int
memrw_read(struct memrw* rw, void* data, size_t sz) {
    size_t space = rw->sz - (rw->ptr - rw->begin);
    if (space >= sz) {
        memcpy(data, rw->ptr, sz);
        rw->ptr += sz;
        return 0;
    }
    return 1;
}

static inline int
memrw_pos(struct memrw* rw, size_t sz) {
    size_t space = rw->sz - (rw->ptr - rw->begin);
    if (space >= sz) {
        rw->ptr += sz;
        return 0;
    }
    return 1;
}

//
static inline int
memrw_write_8(struct memrw *rw, uint8_t v) {
    return memrw_write(rw, &v, 1);
}
static inline int
memrw_write_16(struct memrw *rw, uint16_t v) {
    return memrw_write(rw, &v, 2);
}
static inline int
memrw_write_32(struct memrw *rw, uint32_t v) {
    return memrw_write(rw, &v, 4);
}

static inline int
memrw_read_8(struct memrw *rw, uint8_t *v) {
    return memrw_read(rw, v, 1);
}
static inline int
memrw_read_16(struct memrw *rw, uint16_t *v) {
    return memrw_read(rw, v, 2);
}
static inline int
memrw_read_32(struct memrw *rw, uint32_t *v) {
    return memrw_read(rw, v, 4);
}

#endif
