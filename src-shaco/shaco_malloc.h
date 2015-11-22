#ifndef __sh_malloc_h__
#define __sh_malloc_h__

#include <stdlib.h>

void *shaco_malloc(size_t size);
void *shaco_realloc(void *ptr, size_t size);
void *shaco_calloc(size_t nmemb, size_t size);
void  shaco_free(void *ptr);
char *shaco_strdup(const char *s);
void *shaco_lalloc(void *ud, void *ptr, size_t osize, size_t nsize);

size_t shaco_memory_used();
void  shaco_memory_stat();

#endif
