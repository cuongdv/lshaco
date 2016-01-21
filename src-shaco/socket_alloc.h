#ifndef __socket_alloc_h__
#define __socket_alloc_h__

#include <stdlib.h>
void *shaco_malloc(size_t size);
void *shaco_realloc(void *ptr, size_t size);
void *shaco_calloc(size_t nmemb, size_t size);
void  shaco_free(void *ptr);
#define malloc  shaco_malloc
#define realloc shaco_realloc
#define calloc  shaco_calloc
#define free    shaco_free

#endif
