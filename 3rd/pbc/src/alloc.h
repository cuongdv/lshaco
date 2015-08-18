#ifndef PROTOBUF_C_ALLOC_H
#define PROTOBUF_C_ALLOC_H

#include <stdlib.h>
#include <string.h>

#ifdef USE_SHACO_MALLOC

void *sh_malloc(size_t size);
void *sh_realloc(void *ptr, size_t size);
void  sh_free(void *ptr);

#define _pbcM_malloc    sh_malloc
#define _pbcM_free      sh_free
#define _pbcM_realloc   sh_realloc

#else
void * _pbcM_malloc(size_t sz);
void _pbcM_free(void *p);
void * _pbcM_realloc(void *p, size_t sz);
#endif

void _pbcM_memory();

struct heap;

struct heap * _pbcH_new(int pagesize);
void _pbcH_delete(struct heap *);
void* _pbcH_alloc(struct heap *, int size);

#define HMALLOC(size) ((h) ? _pbcH_alloc(h, size) : _pbcM_malloc(size))

#define malloc _pbcM_malloc
#define free _pbcM_free
#define realloc _pbcM_realloc
#define memory _pbcM_memory

#ifdef _WIN32

#include <malloc.h>

#endif

#ifdef _MSC_VER

#define alloca _alloca

#endif

#endif
