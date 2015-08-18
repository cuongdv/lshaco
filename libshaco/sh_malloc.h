#ifndef __sh_malloc_h__
#define __sh_malloc_h__

#include <stdlib.h>

void *sh_malloc(size_t size);
void *sh_realloc(void *ptr, size_t size);
void *sh_calloc(size_t nmemb, size_t size);
void  sh_free(void *ptr);
char *sh_strdup(const char *s);
void *sh_lalloc(void *ud, void *ptr, size_t osize, size_t nsize);

size_t sh_memory_used();
void  sh_memory_stat();

#endif
