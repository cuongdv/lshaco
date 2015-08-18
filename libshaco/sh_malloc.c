#include "sh_malloc.h"
#include "sh_log.h"
#include "jemalloc.h"
#include "sh.h"
#include <stdio.h>
#include <string.h>

#ifdef HAVE_MALLOC
#define PREFIX_SIZE 0
#define malloc  je_malloc
#define realloc je_realloc
#define free    je_free
#define calloc  je_calloc

static inline size_t
malloc_usable_size(void *ptr) {
    return je_malloc_usable_size(ptr);
}

#else
#define PREFIX_SIZE sizeof(size_t)

static inline size_t
malloc_usable_size(void *ptr) {
    return *(size_t*)ptr;
}
#endif

static size_t _used_memory = 0;

static inline void
_oom(size_t size) {
    sh_error("Out of memory trying to malloc %zu bytes", size);
    sh_panic("Exit due to out of memory");
}

void *
sh_malloc(size_t size) {
    void *ptr = malloc(size+PREFIX_SIZE);
    if (ptr == NULL) {
        _oom(size);
    }
#ifdef HAVE_MALLOC
    _used_memory += malloc_usable_size(ptr);
    return ptr;
#else
    *(size_t*)ptr = size;
    _used_memory += size+PREFIX_SIZE;
    return (char*)ptr+PREFIX_SIZE;
#endif
}

void *
sh_realloc(void *ptr, size_t size) {
    if (ptr == NULL) {
        return sh_malloc(size);
    }
#ifndef HAVE_MALLOC
    ptr = (char*)ptr-PREFIX_SIZE;
#endif
    _used_memory -= malloc_usable_size(ptr);
    void *newptr = realloc(ptr, size+PREFIX_SIZE);
    if (newptr == NULL) {
        _oom(size);
    }
#ifdef HAVE_MALLOC
    _used_memory += malloc_usable_size(newptr);
    return newptr;
#else
    *(size_t*)newptr = size;
    _used_memory += size;
    return (char*)newptr+PREFIX_SIZE;
#endif
}

void *
sh_calloc(size_t nmemb, size_t size) {
    void *ptr = calloc(nmemb, size+PREFIX_SIZE);
    if (ptr == NULL) {
        _oom(nmemb*size);
    }
#ifdef HAVE_MALLOC
    _used_memory += malloc_usable_size(ptr);
    return ptr;
#else
    *(size_t*)ptr = size;
    _used_memory += size+PREFIX_SIZE;
    return (char*)ptr+PREFIX_SIZE;
#endif
}

void  
sh_free(void *ptr) {
    if (ptr == NULL) return;
#ifdef HAVE_MALLOC
    _used_memory -= malloc_usable_size(ptr);
#else
    ptr = (char*)ptr-PREFIX_SIZE;
    _used_memory -= malloc_usable_size(ptr)+PREFIX_SIZE;
#endif
    free(ptr);
}

char *
sh_strdup(const char *s) {
    size_t l = strlen(s)+1;
    char *p = sh_malloc(l);
    memcpy(p, s, l);
    return p;
}

void *
sh_lalloc(void *ud, void *ptr, size_t osize, size_t nsize) {
    (void)ud; (void) osize;
    if (nsize == 0) {
        sh_free(ptr);
        return NULL;
    } else {
        return sh_realloc(ptr, nsize);
    }
}

//
size_t
sh_memory_used() {
    return _used_memory;
}

static void
write_cb(void *opaque, const char *buf) {
    FILE *f = opaque;
    fwrite(buf, strlen(buf), 1, f);
}

void
sh_memory_stat() {
    FILE *f = fopen("./memory.stat", "w");
    if (f == NULL) {
        je_malloc_stats_print(0,0,0);
    } else {
        je_malloc_stats_print(write_cb, f, 0);
        fclose(f);
    }
}
